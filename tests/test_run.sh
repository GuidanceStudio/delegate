# A fake opencode on PATH: records its arguments, edits the repo, emits JSON events.
fake_opencode() {
    mkdir -p "$TMP/bin"
    cat > "$TMP/bin/opencode" <<'FAKE'
#!/usr/bin/env bash
printf '%s\n' "$@" > "$FAKE_ARGS"
printf '%s' "${OPENCODE_CONFIG_CONTENT:-}" > "$FAKE_CONFIG"
[ -t 0 ] || cat > /dev/null
if [ -n "${FAKE_ERROR:-}" ]; then
    jq -cn --arg message "$FAKE_ERROR" '{type:"error",sessionID:"ses_fake1",error:{name:"APIError",data:{message:$message}}}'
    exit "${FAKE_EXIT:-0}"
fi
echo "made by the executor" > hello.txt
text="${FAKE_TEXT:-done}"
printf '{"type":"step_start","sessionID":"ses_fake1","part":{}}\n'
jq -cn --arg t "$text" '{type:"text",sessionID:"ses_fake1",part:{type:"text",text:$t}}'
printf '{"type":"step_finish","sessionID":"ses_fake1","part":{"cost":%s,"tokens":{"input":1000,"output":200}}}\n' "${FAKE_COST:-0.0125}"
exit "${FAKE_EXIT:-0}"
FAKE
    chmod +x "$TMP/bin/opencode"
    export PATH="$TMP/bin:$PATH" FAKE_ARGS="$TMP/args" FAKE_CONFIG="$TMP/opencode_config.json"
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

test_run_defaults_to_deepseek_high_and_model_override_gets_its_own_effort() {
    fake_opencode
    "$DELEGATE" run --check true "$TMP/brief.md" >/dev/null
    grep -A1 -x -- "--model" "$TMP/args" | grep -qx "openrouter/deepseek/deepseek-v4.1-flash-1017" || fail "default model missing" || return 1
    grep -A1 -x -- "--variant" "$TMP/args" | grep -qx high || fail "default effort missing" || return 1
    DELEGATE_MODEL=openrouter/z-ai/glm-5.3-flash "$DELEGATE" run --check true "$TMP/brief.md" >/dev/null || return 1
    grep -A1 -x -- "--model" "$TMP/args" | grep -qx "openrouter/z-ai/glm-5.3-flash" || fail "override not passed" || return 1
    grep -A1 -x -- "--variant" "$TMP/args" | grep -qx high || fail "old GLM effort leaked to override"
}

test_executor_runs_at_the_git_root() {
    fake_opencode
    mkdir sub && touch sub/keep && git add sub/keep && cd sub
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
    local out rc
    out="$(FAKE_EXIT=7 "$DELEGATE" run --check true "$TMP/brief.md")"; rc=$?
    assert_eq "$rc" 7 || return 1
    assert_contains "$out" "executor exit: 7" || return 1
    assert_contains "$out" "check exit: 0"
}

test_provider_rejection_is_reported_even_when_opencode_exits_zero() {
    fake_opencode
    local out rc
    out="$(FAKE_ERROR='coreweave/nvfp4 unavailable' "$DELEGATE" run --check true "$TMP/brief.md")"; rc=$?
    assert_eq "$rc" 1 || return 1
    assert_contains "$out" 'executor error: coreweave/nvfp4 unavailable' || return 1
    assert_contains "$out" 'check exit: 0'
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

test_executor_does_not_wait_on_an_open_stdin() {
    fake_opencode
    local rc
    timeout 3 "$DELEGATE" run --check true "$TMP/brief.md" < <(sleep 3) >/dev/null; rc=$?
    assert_eq "$rc" "0"
}

test_cost_is_rounded() {
    fake_opencode
    local out
    out="$(FAKE_COST=0.0033137279999999997 "$DELEGATE" run --check true "$TMP/brief.md")"
    assert_contains "$out" "cost: \$0.0033  "
}

test_saved_model_and_effort_are_used_by_later_runs() {
    fake_opencode
    "$DELEGATE" model openrouter/deepseek/deepseek-v4.1-flash-1017 max >/dev/null || return 1
    "$DELEGATE" run --check true "$TMP/brief.md" >/dev/null || return 1
    grep -A1 -x -- --model "$TMP/args" | grep -qx openrouter/deepseek/deepseek-v4.1-flash-1017 || return 1
    grep -A1 -x -- --variant "$TMP/args" | grep -qx max
}

test_glm_routing_preserves_unrelated_inline_config_and_does_not_leak() {
    fake_opencode
    "$DELEGATE" model openrouter/z-ai/glm-5.3-flash max >/dev/null || return 1
    "$DELEGATE" provider coreweave/nvfp4 >/dev/null || return 1
    local base='{"agent":{"delegate-executor":{"temperature":0.2}},"instructions":["notes.md"]}'
    OPENCODE_CONFIG_CONTENT="$base" "$DELEGATE" run --check true "$TMP/brief.md" >/dev/null || return 1
    jq -e '.instructions == ["notes.md"] and .agent["delegate-executor"].temperature == 0.2
        and .agent["delegate-executor"].provider.order == ["coreweave/nvfp4"]
        and .agent["delegate-executor"].provider.only == ["coreweave/nvfp4"]' "$FAKE_CONFIG" >/dev/null || return 1
    OPENCODE_CONFIG_CONTENT="$base" DELEGATE_MODEL=openrouter/deepseek/deepseek-v4.1-flash-1017 "$DELEGATE" run --check true "$TMP/brief.md" >/dev/null || return 1
    jq -e '.instructions == ["notes.md"] and .agent["delegate-executor"].provider == null' "$FAKE_CONFIG" >/dev/null
}

test_auto_routing_preserves_personal_settings_even_for_glm() {
    fake_opencode
    local base='{"agent":{"delegate-executor":{"provider":{"order":["personal"],"only":["personal"],"allow_fallbacks":true},"temperature":0.2}},"instructions":["notes.md"]}'
    local out
    out="$(OPENCODE_CONFIG_CONTENT="$base" "$DELEGATE" run --check true "$TMP/brief.md")" || return 1
    assert_contains "$out" 'provider: auto' || return 1
    assert_eq "$(cat "$FAKE_CONFIG")" "$base" || return 1
    "$DELEGATE" provider coreweave/nvfp4 >/dev/null || return 1
    OPENCODE_CONFIG_CONTENT="$base" "$DELEGATE" run --check true "$TMP/brief.md" >/dev/null || return 1
    jq -e '.agent["delegate-executor"].provider.only == ["coreweave/nvfp4"]' "$FAKE_CONFIG" >/dev/null || return 1
    "$DELEGATE" provider auto >/dev/null || return 1
    OPENCODE_CONFIG_CONTENT="$base" "$DELEGATE" run --check true "$TMP/brief.md" >/dev/null || return 1
    assert_eq "$(cat "$FAKE_CONFIG")" "$base"
}

test_runs_use_the_effective_models_own_endpoint() {
    fake_opencode
    "$DELEGATE" model openrouter/z-ai/glm-5.3-flash max >/dev/null || return 1
    "$DELEGATE" provider coreweave/nvfp4 >/dev/null || return 1
    DELEGATE_MODEL=openrouter/deepseek/deepseek-v4.1-flash-1017 "$DELEGATE" provider deepinfra/turbo >/dev/null || return 1
    local base='{"agent":{"delegate-executor":{"provider":{"ignore":["excluded"],"order":["personal"]},"temperature":0.2}},"instructions":["notes.md"]}'
    local out
    out="$(OPENCODE_CONFIG_CONTENT="$base" DELEGATE_MODEL=openrouter/deepseek/deepseek-v4.1-flash-1017 "$DELEGATE" run --check true "$TMP/brief.md")" || return 1
    assert_contains "$out" 'provider: deepinfra/turbo' || return 1
    jq -e '.agent["delegate-executor"].provider == {
        ignore: ["excluded"], order: ["deepinfra/turbo"], only: ["deepinfra/turbo"],
        allow_fallbacks: false, require_parameters: true
    } and .instructions == ["notes.md"] and .agent["delegate-executor"].temperature == 0.2' "$FAKE_CONFIG" >/dev/null || return 1
    "$DELEGATE" run --check true "$TMP/brief.md" >/dev/null || return 1
    jq -e '.agent["delegate-executor"].provider.only == ["coreweave/nvfp4"]' "$FAKE_CONFIG" >/dev/null
}

test_default_does_not_inject_coreweave() {
    fake_opencode
    "$DELEGATE" run --check true "$TMP/brief.md" >/dev/null || return 1
    assert_eq "$(cat "$FAKE_CONFIG")" '{}'
}

test_invalid_saved_endpoint_is_refused_before_execution() {
    fake_opencode
    printf 'model=openrouter/z-ai/glm-5.3-flash\nprovider.openrouter/z-ai/glm-5.3-flash=bad value\n' > "$DELEGATE_CONFIG"
    local out rc
    out="$("$DELEGATE" run --check true "$TMP/brief.md" 2>&1)"; rc=$?
    assert_eq "$rc" 1 || return 1
    assert_contains "$out" 'invalid saved OpenRouter endpoint' || return 1
    [ ! -f "$FAKE_ARGS" ] || fail 'executor ran with invalid endpoint'
}

test_check_failure_keeps_its_code_even_when_executor_also_fails() {
    fake_opencode
    local rc
    FAKE_EXIT=7 "$DELEGATE" run --check 'exit 3' "$TMP/brief.md" >/dev/null; rc=$?
    assert_eq "$rc" 3
}

test_invalid_inline_config_is_refused_before_execution() {
    fake_opencode
    local rc
    OPENCODE_CONFIG_CONTENT='not json' "$DELEGATE" run --check true "$TMP/brief.md" >/dev/null 2>&1; rc=$?
    assert_eq "$rc" 2 || return 1
    [ ! -f "$FAKE_ARGS" ] || fail "executor ran with invalid config"
}

test_run_missing_option_value_fails_without_hanging() {
    local rc
    timeout 2 "$DELEGATE" run --check >/dev/null 2>&1; rc=$?
    assert_eq "$rc" 2
}
