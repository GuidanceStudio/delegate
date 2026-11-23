hook_commands() { jq -r '[.hooks.UserPromptSubmit[].hooks[].command] | join(",")' "$HOME/.claude/settings.json"; }

test_setup_places_agent_and_hook() {
    install_home
    run_setup claude >/dev/null || fail "setup failed" || return 1
    [ -f "$HOME/.config/opencode/agents/delegate-executor.md" ] || fail "agent not installed" || return 1
    assert_eq "$(hook_commands)" "/opt/other-hook.sh,$HOME/.claude/skills/delegate/bin/delegate hook" || return 1
    assert_eq "$(jq -r .model "$HOME/.claude/settings.json")" "x"
}

test_second_setup_leaves_settings_identical() {
    install_home
    run_setup claude >/dev/null
    cp "$HOME/.claude/settings.json" "$TMP/first.json"
    run_setup claude >/dev/null || fail "second setup failed" || return 1
    cmp -s "$TMP/first.json" "$HOME/.claude/settings.json" || fail "settings.json changed on the second run"
}

test_setup_creates_missing_settings() {
    export HOME="$TMP/home"
    mkdir -p "$HOME/.claude"
    run_setup claude >/dev/null || fail "setup failed" || return 1
    assert_eq "$(hook_commands)" "$HOME/.claude/skills/delegate/bin/delegate hook"
}

test_check_reports_state_without_writing() {
    install_home
    local out rc
    out="$(run_setup claude --check 2>&1)"; rc=$?
    assert_eq "$rc" "1" || return 1
    assert_contains "$out" "claude hook: missing" || return 1
    assert_contains "$out" "agent: missing" || return 1
    [ ! -e "$HOME/.config/opencode/agents/delegate-executor.md" ] || fail "--check installed the agent" || return 1
    cmp -s <(jq -S . "$HOME/.claude/settings.json") <(printf '%s\n' '{"model":"x","hooks":{"UserPromptSubmit":[{"hooks":[{"type":"command","command":"/opt/other-hook.sh"}]}]}}' | jq -S .) || fail "--check wrote settings" || return 1
    run_setup claude >/dev/null
    out="$(run_setup claude --check 2>&1)"; rc=$?
    assert_eq "$rc" "0" || return 1
    assert_contains "$out" "hook: installed" || return 1
    assert_contains "$out" "agent: installed"
}

test_check_reports_a_changed_agent_as_differs() {
    install_home
    run_setup claude >/dev/null
    echo "local edit" >> "$HOME/.config/opencode/agents/delegate-executor.md"
    local out rc
    out="$(run_setup claude --check 2>&1)"; rc=$?
    assert_eq "$rc" "1" || return 1
    assert_contains "$out" "agent: differs"
}

test_all_target_sets_up_both_hosts_and_preserves_settings() {
    install_home
    place_skill codex || return 1
    run_setup claude --target all >/dev/null || return 1
    assert_eq "$(jq -r .model "$HOME/.claude/settings.json")" x || return 1
    run_setup claude --target all --check >/dev/null || return 1
    assert_eq "$(jq -r '.hooks.UserPromptSubmit[-1].hooks[0].command' "$HOME/.codex/hooks.json")" "$HOME/.codex/skills/delegate/bin/delegate hook" || return 1
    cp "$HOME/.codex/hooks.json" "$TMP/codex-hooks.json"
    cp "$HOME/.claude/settings.json" "$TMP/claude-hooks.json"
    run_setup claude --target all >/dev/null || return 1
    cmp -s "$TMP/codex-hooks.json" "$HOME/.codex/hooks.json" || return 1
    cmp -s "$TMP/claude-hooks.json" "$HOME/.claude/settings.json"
}

test_target_option_selects_host_and_conflicts_are_rejected() {
    install_home
    run_setup codex --target codex >/dev/null || return 1
    run_setup codex --target codex --check >/dev/null || return 1
    [ ! -e "$HOME/.claude/skills" ] || fail "Claude skill appeared" || return 1
    ! run_setup codex --target codex --target all >/dev/null 2>&1 || fail "conflicting targets accepted"
}

test_all_target_validates_every_hook_before_changing_anything() {
    install_home
    place_skill codex || return 1
    printf 'invalid json' > "$HOME/.codex/hooks.json"
    cp "$HOME/.claude/settings.json" "$TMP/claude-before.json"
    ! run_setup claude --target all >/dev/null 2>&1 || fail "invalid Codex hooks accepted" || return 1
    cmp -s "$TMP/claude-before.json" "$HOME/.claude/settings.json" || fail "Claude settings changed before validation" || return 1
    assert_eq "$(cat "$HOME/.codex/hooks.json")" "invalid json" || return 1
    [ ! -e "$HOME/.config/opencode/agents/delegate-executor.md" ] || fail "agent written before validation"
}

test_setup_from_an_uninstalled_source_is_refused() {
    install_home
    local out rc
    out="$("$ROOT/delegate/bin/delegate" setup 2>&1)"; rc=$?
    assert_eq "$rc" 1 || return 1
    assert_contains "$out" "installed skill" || return 1
    [ ! -e "$HOME/.config/opencode/agents/delegate-executor.md" ] || fail "agent written by a refused setup" || return 1
    assert_eq "$(hook_commands)" "/opt/other-hook.sh" || return 1
    DELEGATE_HOST=claude "$ROOT/delegate/bin/delegate" setup >/dev/null 2>&1 || fail "explicit DELEGATE_HOST refused" || return 1
    assert_eq "$(hook_commands)" "/opt/other-hook.sh,$ROOT/delegate/bin/delegate hook"
}

test_default_target_is_the_host_of_the_installed_copy() {
    export HOME="$TMP/home"
    mkdir -p "$HOME/.claude" "$HOME/.codex"
    run_setup codex >/dev/null || fail "setup failed" || return 1
    [ -f "$HOME/.codex/hooks.json" ] || fail "Codex hook missing" || return 1
    [ ! -e "$HOME/.claude/settings.json" ] || fail "Claude settings written by a Codex setup"
}
