hook_commands() { jq -r '[.hooks.UserPromptSubmit[].hooks[].command] | join(",")' "$HOME/.claude/settings.json"; }

test_install_places_skill_agent_and_hook() {
    install_home
    "$ROOT/install.sh" >/dev/null || fail "install failed" || return 1
    [ -x "$HOME/.claude/skills/delegate/bin/delegate" ] || fail "script not installed" || return 1
    [ -f "$HOME/.claude/skills/delegate/SKILL.md" ] || fail "skill not installed" || return 1
    [ -f "$HOME/.config/opencode/agents/delegate-executor.md" ] || fail "agent not installed" || return 1
    assert_eq "$(hook_commands)" "/opt/other-hook.sh,$HOME/.claude/skills/delegate/bin/delegate hook" || return 1
    assert_eq "$(jq -r .model "$HOME/.claude/settings.json")" "x"
}

test_second_install_leaves_settings_identical() {
    install_home
    "$ROOT/install.sh" >/dev/null
    cp "$HOME/.claude/settings.json" "$TMP/first.json"
    "$ROOT/install.sh" >/dev/null || fail "second install failed" || return 1
    cmp -s "$TMP/first.json" "$HOME/.claude/settings.json" || fail "settings.json changed on the second run"
}

test_install_creates_missing_settings() {
    export HOME="$TMP/home"
    mkdir -p "$HOME/.claude"
    "$ROOT/install.sh" >/dev/null || fail "install failed" || return 1
    assert_eq "$(hook_commands)" "$HOME/.claude/skills/delegate/bin/delegate hook"
}

test_locally_modified_copy_needs_force() {
    install_home
    "$ROOT/install.sh" >/dev/null
    echo "local edit" >> "$HOME/.claude/skills/delegate/SKILL.md"
    local out rc
    out="$("$ROOT/install.sh" 2>&1)"; rc=$?
    [ "$rc" -ne 0 ] || fail "overwrote a modified copy without --force" || return 1
    assert_contains "$out" "--force" || return 1
    grep -q "local edit" "$HOME/.claude/skills/delegate/SKILL.md" || fail "modified copy was touched" || return 1
    "$ROOT/install.sh" --force >/dev/null || fail "--force failed" || return 1
    ! grep -q "local edit" "$HOME/.claude/skills/delegate/SKILL.md" || fail "--force did not overwrite"
}

test_check_reports_state_without_writing() {
    install_home
    local out rc
    out="$("$ROOT/install.sh" --check 2>&1)"; rc=$?
    assert_eq "$rc" "1" || return 1
    assert_contains "$out" "skill: missing" || return 1
    [ ! -e "$HOME/.claude/skills/delegate" ] || fail "--check installed something" || return 1
    "$ROOT/install.sh" >/dev/null
    out="$("$ROOT/install.sh" --check 2>&1)"; rc=$?
    assert_eq "$rc" "0" || return 1
    assert_contains "$out" "hook: installed"
}

test_all_target_installs_both_hosts_and_preserves_settings() {
    install_home
    "$ROOT/install.sh" --target all >/dev/null || return 1
    [ -x "$HOME/.claude/skills/delegate/bin/delegate" ] || fail "Claude skill missing" || return 1
    [ -x "$HOME/.codex/skills/delegate/bin/delegate" ] || fail "Codex skill missing" || return 1
    assert_eq "$(jq -r .model "$HOME/.claude/settings.json")" x || return 1
    "$ROOT/install.sh" --target all --check >/dev/null || return 1
    cp "$HOME/.codex/hooks.json" "$TMP/codex-hooks.json"
    cp "$HOME/.claude/settings.json" "$TMP/claude-hooks.json"
    "$ROOT/install.sh" --target all >/dev/null || return 1
    cmp -s "$TMP/codex-hooks.json" "$HOME/.codex/hooks.json" || return 1
    cmp -s "$TMP/claude-hooks.json" "$HOME/.claude/settings.json"
}

test_target_codex_is_an_alias_for_codex_flag() {
    install_home
    "$ROOT/install.sh" --target codex >/dev/null || return 1
    "$ROOT/install.sh" --codex --check >/dev/null || return 1
    ! "$ROOT/install.sh" --codex --target all >/dev/null 2>&1 || fail "conflicting targets accepted"
}

test_all_target_validates_every_hook_before_installing_anything() {
    install_home
    mkdir -p "$HOME/.codex"
    printf 'invalid json' > "$HOME/.codex/hooks.json"
    ! "$ROOT/install.sh" --target all --force >/dev/null 2>&1 || fail "invalid Codex hooks accepted" || return 1
    [ ! -e "$HOME/.claude/skills/delegate" ] || fail "Claude was partially installed" || return 1
    [ ! -e "$HOME/.config/opencode/agents/delegate-executor.md" ] || fail "agent was partially installed"
}

test_default_install_targets_every_assistant_home_that_exists() {
    install_home
    mkdir -p "$HOME/.codex"
    "$ROOT/install.sh" >/dev/null || fail "install failed" || return 1
    [ -x "$HOME/.claude/skills/delegate/bin/delegate" ] || fail "Claude skill missing" || return 1
    [ -x "$HOME/.codex/skills/delegate/bin/delegate" ] || fail "Codex skill missing" || return 1
    [ -f "$HOME/.config/opencode/agents/delegate-executor.md" ] || fail "agent missing"
}

test_default_install_with_only_codex_leaves_claude_alone() {
    export HOME="$TMP/home"
    mkdir -p "$HOME/.codex"
    "$ROOT/install.sh" >/dev/null || fail "install failed" || return 1
    [ -x "$HOME/.codex/skills/delegate/bin/delegate" ] || fail "Codex skill missing" || return 1
    [ ! -e "$HOME/.claude" ] || fail "created a Claude home when none existed"
}

test_default_install_without_any_assistant_home_fails_with_a_hint() {
    export HOME="$TMP/home"
    local out rc
    out="$("$ROOT/install.sh" 2>&1)"; rc=$?
    assert_eq "$rc" 2 || return 1
    assert_contains "$out" "--target"
}
