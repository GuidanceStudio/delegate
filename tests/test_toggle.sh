test_status_off_by_default() {
    assert_eq "$("$DELEGATE" status)" "off"
}

test_on_binds_the_session_only() {
    "$DELEGATE" on >/dev/null
    assert_eq "$("$DELEGATE" status)" "on (session)" || return 1
    assert_eq "$(CLAUDE_CODE_SESSION_ID=sess-2 "$DELEGATE" status)" "off"
}

test_on_project_binds_every_session_in_the_repo() {
    mkdir sub && cd sub
    "$DELEGATE" on --project >/dev/null
    [ -f ../.claude/delegate.on ] || fail "flag not at the git root" || return 1
    assert_eq "$(CLAUDE_CODE_SESSION_ID=sess-2 "$DELEGATE" status)" "on (project)"
}

test_status_reports_both_levels() {
    "$DELEGATE" on >/dev/null
    "$DELEGATE" on --project >/dev/null
    assert_eq "$("$DELEGATE" status)" "on (session, project)"
}

test_off_clears_both_levels() {
    "$DELEGATE" on >/dev/null
    "$DELEGATE" on --project >/dev/null
    "$DELEGATE" off >/dev/null
    assert_eq "$("$DELEGATE" status)" "off" || return 1
    [ ! -e .claude/delegate.on ] || fail "project flag left behind"
}

test_on_without_session_id_is_refused() {
    local out rc
    out="$(CLAUDE_CODE_SESSION_ID= "$DELEGATE" on 2>&1)"; rc=$?
    [ "$rc" -ne 0 ] || fail "exit 0 without a session id" || return 1
    assert_contains "$out" "--project"
}

test_unknown_command_prints_usage() {
    local out rc
    out="$("$DELEGATE" frobnicate 2>&1)"; rc=$?
    [ "$rc" -eq 2 ] || fail "exit $rc, expected 2" || return 1
    assert_contains "$out" "usage: delegate"
}

test_on_write_failure_does_not_report_success() {
    printf 'not a directory' > "$TMP/blocked"
    local rc
    DELEGATE_STATE_DIR="$TMP/blocked/state" "$DELEGATE" on >/dev/null 2>&1; rc=$?
    assert_eq "$rc" 1
}
