# Switching delegate mode on needs opencode on PATH; setup may proceed without it.

test_on_refused_without_opencode() {
    local out rc
    out="$(PATH="$(path_without_opencode)" "$DELEGATE" on 2>&1)"; rc=$?
    [ "$rc" -eq 1 ] || fail "exit $rc, expected 1" || return 1
    assert_contains "$out" "opencode" || return 1
    assert_eq "$("$DELEGATE" status)" "off"
}

test_on_project_refused_without_opencode() {
    local out rc
    out="$(PATH="$(path_without_opencode)" "$DELEGATE" on --project 2>&1)"; rc=$?
    [ "$rc" -eq 1 ] || fail "exit $rc, expected 1" || return 1
    assert_contains "$out" "opencode" || return 1
    [ ! -e .claude/delegate.on ] || fail "project flag was created"
}

test_setup_warns_without_opencode() {
    export HOME="$TMP/home"
    local out rc
    place_skill claude
    out="$(PATH="$(path_without_opencode)" "$HOME/.claude/skills/delegate/bin/delegate" setup --target claude 2>&1)"; rc=$?
    assert_eq "$rc" "0" || return 1
    assert_contains "$out" "opencode" || return 1
    grep -qi "warning" <<<"$out" || fail "no warning about missing opencode" || return 1
    [ -f "$HOME/.config/opencode/agents/delegate-executor.md" ] || fail "agent was not installed"
}

test_setup_silent_about_opencode_when_present() {
    export HOME="$TMP/home"
    local out rc
    place_skill claude
    out="$("$HOME/.claude/skills/delegate/bin/delegate" setup --target claude 2>&1)"; rc=$?
    assert_eq "$rc" "0" || return 1
    ! grep -qi "warning" <<<"$out" || fail "warning emitted although opencode is present"
}
