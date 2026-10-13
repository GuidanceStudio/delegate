install_home() {
    export HOME="$TMP/home"
    mkdir -p "$HOME/.claude"
    cat > "$HOME/.claude/settings.json" <<'JSON'
{
  "model": "x",
  "hooks": {
    "UserPromptSubmit": [
      { "hooks": [ { "type": "command", "command": "/opt/other-hook.sh" } ] }
    ]
  }
}
JSON
}

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
