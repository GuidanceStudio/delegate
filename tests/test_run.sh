# A fake opencode on PATH: records its arguments, edits the repo, emits JSON events.
fake_opencode() {
    mkdir -p "$TMP/bin"
    cat > "$TMP/bin/opencode" <<'FAKE'
#!/usr/bin/env bash
printf '%s\n' "$@" > "$FAKE_ARGS"
echo "made by the executor" > hello.txt
text="${FAKE_TEXT:-done}"
printf '{"type":"step_start","sessionID":"ses_fake1","part":{}}\n'
jq -cn --arg t "$text" '{type:"text",sessionID:"ses_fake1",part:{type:"text",text:$t}}'
printf '{"type":"step_finish","sessionID":"ses_fake1","part":{"cost":0.0125,"tokens":{"input":1000,"output":200}}}\n'
exit "${FAKE_EXIT:-0}"
FAKE
    chmod +x "$TMP/bin/opencode"
    export PATH="$TMP/bin:$PATH" FAKE_ARGS="$TMP/args"
    echo "Create hello.txt" > "$TMP/brief.md"
}

test_run_returns_report_changes_and_check() {
    fake_opencode
    local out rc
    out="$("$DELEGATE" run --check "test -f hello.txt" "$TMP/brief.md")"; rc=$?
    assert_eq "$rc" "0" || return 1
    assert_contains "$out" "session: ses_fake1" || return 1
    assert_contains "$out" "done" || return 1
    assert_contains "$out" "?? hello.txt" || return 1
    assert_contains "$out" "check exit: 0" || return 1
    assert_contains "$out" "cost: \$0.0125"
}

test_failing_check_fails_even_when_executor_claims_success() {
    fake_opencode
    local out rc
    out="$(FAKE_TEXT="All tests pass." "$DELEGATE" run --check "echo boom; exit 3" "$TMP/brief.md")"; rc=$?
    assert_eq "$rc" "3" || return 1
    assert_contains "$out" "check exit: 3" || return 1
    assert_contains "$out" "boom"
}

test_brief_reaches_the_executor_with_its_agent() {
    fake_opencode
    "$DELEGATE" run --check true "$TMP/brief.md" >/dev/null
    grep -qx "Create hello.txt" "$TMP/args" || fail "brief not passed" || return 1
    grep -A1 -x -- "--agent" "$TMP/args" | grep -qx "delegate-executor" || fail "agent not selected"
}

test_resume_continues_the_given_session() {
    fake_opencode
    "$DELEGATE" run --check true --resume ses_abc "$TMP/brief.md" >/dev/null
    grep -A1 -x -- "--session" "$TMP/args" | grep -qx "ses_abc" || fail "session not resumed"
}

test_model_comes_from_the_agent_unless_overridden() {
    fake_opencode
    "$DELEGATE" run --check true "$TMP/brief.md" >/dev/null
    ! grep -qx -- "--model" "$TMP/args" || fail "--model passed without an override" || return 1
    DELEGATE_MODEL=prov/other "$DELEGATE" run --check true "$TMP/brief.md" >/dev/null
    grep -A1 -x -- "--model" "$TMP/args" | grep -qx "prov/other" || fail "override not passed"
}

test_executor_runs_at_the_git_root() {
    fake_opencode
    mkdir sub && cd sub
    "$DELEGATE" run --check "test -f hello.txt" "$TMP/brief.md" >/dev/null || fail "check did not run at the root" || return 1
    grep -A1 -x -- "--dir" "$TMP/args" | grep -qx "$TMP/repo" || fail "--dir is not the git root"
}

test_report_is_truncated() {
    fake_opencode
    local long out
    long="$(printf 'x%.0s' $(seq 1 500))END"
    out="$(FAKE_TEXT="$long" DELEGATE_MAX_CHARS=100 "$DELEGATE" run --check true "$TMP/brief.md")"
    case "$out" in *END*) fail "report not truncated"; return 1;; esac
    assert_contains "$out" "[truncated, 503 chars"
}

test_full_log_is_kept() {
    fake_opencode
    local out log
    out="$("$DELEGATE" run --check true "$TMP/brief.md")"
    log="$(sed -n 's/^log: //p' <<<"$out")"
    [ -f "$log" ] || fail "no log at [$log]" || return 1
    assert_eq "$(wc -l < "$log" | tr -d ' ')" "3"
}

test_executor_failure_is_reported_and_check_still_runs() {
    fake_opencode
    local out
    out="$(FAKE_EXIT=1 "$DELEGATE" run --check true "$TMP/brief.md")"
    assert_contains "$out" "executor exit: 1" || return 1
    assert_contains "$out" "check exit: 0"
}

test_run_requires_check_and_brief() {
    fake_opencode
    local out rc
    out="$("$DELEGATE" run "$TMP/brief.md" 2>&1)"; rc=$?
    assert_eq "$rc" "2" || return 1
    assert_contains "$out" "--check" || return 1
    out="$("$DELEGATE" run --check true "$TMP/missing.md" 2>&1)"; rc=$?
    assert_eq "$rc" "2" || return 1
    assert_contains "$out" "missing.md"
}
