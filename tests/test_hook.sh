hook_input() { printf '{"session_id":"%s","cwd":"%s","prompt":"x"}' "$1" "$2"; }

test_hook_silent_when_off() {
    local out
    out="$(hook_input sess-1 "$PWD" | "$DELEGATE" hook)" || fail "non-zero exit" || return 1
    assert_eq "$out" ""
}

test_hook_reminds_when_session_on() {
    "$DELEGATE" on >/dev/null
    local out
    out="$(cd / && hook_input sess-1 "$TMP/repo" | CLAUDE_CODE_SESSION_ID= "$DELEGATE" hook)"
    assert_contains "$out" "delegate mode is ON (session)" || return 1
    assert_contains "$out" "delegate run"
}

test_hook_reads_the_session_from_stdin() {
    "$DELEGATE" on >/dev/null
    local out
    out="$(hook_input sess-2 "$PWD" | "$DELEGATE" hook)"
    assert_eq "$out" ""
}

test_hook_reminds_when_project_on() {
    "$DELEGATE" on --project >/dev/null
    local out
    out="$(cd / && hook_input sess-9 "$TMP/repo" | "$DELEGATE" hook)"
    assert_contains "$out" "delegate mode is ON (project)"
}

test_hook_survives_malformed_stdin() {
    "$DELEGATE" on --project >/dev/null
    local out
    out="$(echo 'not json' | "$DELEGATE" hook)" || fail "non-zero exit on bad input" || return 1
    assert_eq "$out" ""
}
