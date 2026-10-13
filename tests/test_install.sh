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

codex_hook_commands() { jq -r '[.hooks.UserPromptSubmit[].hooks[].command] | join(",")' "$HOME/.codex/hooks.json"; }

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
    "$ROOT/install.sh" --target claude >/dev/null || fail "install failed" || return 1
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

test_target_codex_places_skill_agent_and_hook() {
    export HOME="$TMP/home"
    "$ROOT/install.sh" --target codex >/dev/null || fail "codex install failed" || return 1
    [ -x "$HOME/.codex/skills/delegate/bin/delegate" ] || fail "codex skill not installed" || return 1
    [ -f "$HOME/.codex/skills/delegate/SKILL.md" ] || fail "codex SKILL.md not installed" || return 1
    [ -f "$HOME/.config/opencode/agents/delegate-executor.md" ] || fail "agent not installed for codex" || return 1
    assert_eq "$(codex_hook_commands)" "$HOME/.codex/skills/delegate/bin/delegate hook"
}

test_codex_second_install_is_byte_identical_and_preserves_hooks() {
    export HOME="$TMP/home"
    mkdir -p "$HOME/.codex"
    cat > "$HOME/.codex/hooks.json" <<'JSON'
{
  "other": "y",
  "hooks": {
    "UserPromptSubmit": [
      { "hooks": [ { "type": "command", "command": "/opt/other-hook.sh" } ] }
    ]
  }
}
JSON
    "$ROOT/install.sh" --target codex >/dev/null || fail "first codex install failed" || return 1
    assert_eq "$(codex_hook_commands)" "/opt/other-hook.sh,$HOME/.codex/skills/delegate/bin/delegate hook" || return 1
    assert_eq "$(jq -r .other "$HOME/.codex/hooks.json")" "y" || return 1
    cp "$HOME/.codex/hooks.json" "$TMP/codex-first.json"
    "$ROOT/install.sh" --target codex >/dev/null || fail "second codex install failed" || return 1
    cmp -s "$TMP/codex-first.json" "$HOME/.codex/hooks.json" || fail "hooks.json changed on the second run"
}

test_default_install_targets_both_present_assistants() {
    export HOME="$TMP/home"
    mkdir -p "$HOME/.claude" "$HOME/.codex"
    "$ROOT/install.sh" >/dev/null || fail "install failed" || return 1
    [ -x "$HOME/.claude/skills/delegate/bin/delegate" ] || fail "claude skill not installed" || return 1
    [ -x "$HOME/.codex/skills/delegate/bin/delegate" ] || fail "codex skill not installed" || return 1
    assert_eq "$(hook_commands)" "$HOME/.claude/skills/delegate/bin/delegate hook" || return 1
    assert_eq "$(codex_hook_commands)" "$HOME/.codex/skills/delegate/bin/delegate hook"
}

test_default_install_skips_a_missing_assistant() {
    export HOME="$TMP/home"
    mkdir -p "$HOME/.codex"
    "$ROOT/install.sh" >/dev/null || fail "install failed" || return 1
    [ -x "$HOME/.codex/skills/delegate/bin/delegate" ] || fail "codex skill not installed" || return 1
    [ ! -e "$HOME/.claude" ] || fail "claude directory was created"
}

test_install_without_target_and_no_assistants_fails() {
    export HOME="$TMP/home"
    local out rc
    out="$("$ROOT/install.sh" 2>&1)"; rc=$?
    assert_eq "$rc" "2" || return 1
    assert_contains "$out" "--target"
}

test_check_target_codex_reports_per_target() {
    export HOME="$TMP/home"
    local out rc
    out="$("$ROOT/install.sh" --check --target codex 2>&1)"; rc=$?
    assert_eq "$rc" "1" || return 1
    assert_contains "$out" "codex skill: missing" || return 1
    assert_contains "$out" "codex hook: missing" || return 1
    assert_contains "$out" "agent:" || return 1
    [ ! -e "$HOME/.codex/skills/delegate" ] || fail "--check installed something" || return 1
    "$ROOT/install.sh" --target codex >/dev/null || fail "codex install failed" || return 1
    out="$("$ROOT/install.sh" --check --target codex 2>&1)"; rc=$?
    assert_eq "$rc" "0" || return 1
    assert_contains "$out" "codex skill: installed" || return 1
    assert_contains "$out" "codex hook: installed"
}

test_codex_install_mentions_review_approval() {
    export HOME="$TMP/home"
    local out
    out="$("$ROOT/install.sh" --target codex 2>&1)" || fail "codex install failed" || return 1
    assert_contains "$out" "review"
}

test_force_combines_with_target() {
    export HOME="$TMP/home"
    "$ROOT/install.sh" --target codex >/dev/null || fail "install failed" || return 1
    echo "local edit" >> "$HOME/.codex/skills/delegate/SKILL.md"
    "$ROOT/install.sh" --force --target codex >/dev/null || fail "--force --target failed" || return 1
    ! grep -q "local edit" "$HOME/.codex/skills/delegate/SKILL.md" || fail "--force did not overwrite"
}
