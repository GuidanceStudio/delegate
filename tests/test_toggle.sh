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
    [ -f ../.delegate.on ] || fail "flag not at the git root" || return 1
    assert_eq "$(CLAUDE_CODE_SESSION_ID=sess-2 "$DELEGATE" status)" "on (project)"
}

test_on_uses_the_codex_thread_id() {
    CLAUDE_CODE_SESSION_ID= CODEX_THREAD_ID=codex-7 "$DELEGATE" on >/dev/null || return 1
    [ -f "$DELEGATE_STATE_DIR/codex-7" ] || fail "no flag for the codex thread" || return 1
    assert_eq "$(CLAUDE_CODE_SESSION_ID= CODEX_THREAD_ID=codex-7 "$DELEGATE" status)" "on (session)"
}

test_default_state_dir_is_under_xdg_state_home() {
    export HOME="$TMP/home"
    unset DELEGATE_STATE_DIR
    XDG_STATE_HOME="$TMP/xdg" "$DELEGATE" on >/dev/null || return 1
    [ -f "$TMP/xdg/delegate/sess-1" ] || fail "session flag not under XDG_STATE_HOME" || return 1
    assert_eq "$(XDG_STATE_HOME="$TMP/xdg" "$DELEGATE" status)" "on (session)"
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
    [ ! -e .delegate.on ] || fail "project flag left behind"
}

test_on_without_session_id_is_refused() {
    local out rc
    out="$(CLAUDE_CODE_SESSION_ID= CODEX_THREAD_ID= "$DELEGATE" on 2>&1)"; rc=$?
    [ "$rc" -ne 0 ] || fail "exit 0 without a session id" || return 1
    assert_contains "$out" "--project"
}

test_unknown_command_prints_usage() {
    local out rc
    out="$("$DELEGATE" frobnicate 2>&1)"; rc=$?
    [ "$rc" -eq 2 ] || fail "exit $rc, expected 2" || return 1
    assert_contains "$out" "usage: delegate"
}
