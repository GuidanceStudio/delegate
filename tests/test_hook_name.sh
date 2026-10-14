# Tests for naming the delegate hook (statusMessage "delegate: mode reminder"),
# so Codex does not list it as "Unnamed hook". Claude and Codex hosts.
NAME="delegate: mode reminder"

# Local Codex home setup: a pre-existing hook plus unrelated keys, kept small
# and self-contained instead of sourcing test_codex.sh.
name_codex_home() {
    install_home
    mkdir -p "$HOME/.codex"
    printf '%s\n' '{"description":"existing","hooks":{"UserPromptSubmit":[{"hooks":[{"type":"command","command":"/opt/codex-hook.sh"}]}],"Stop":[]}}' > "$HOME/.codex/hooks.json"
}

claude_settings() { printf '%s' "$HOME/.claude/settings.json"; }
codex_hooks() { printf '%s' "$HOME/.codex/hooks.json"; }
claude_delegate_cmd() { printf '%s' "$HOME/.claude/skills/delegate/bin/delegate hook"; }
codex_delegate_cmd() { printf '%s' "$HOME/.codex/skills/delegate/bin/delegate hook"; }

# The delegate entry carries exactly the expected name.
assert_delegate_named() {
    local file="$1" cmd="$2"
    jq -e --arg c "$cmd" --arg n "$NAME" \
        '([.hooks.UserPromptSubmit[].hooks[] | select(.command == $c) | .statusMessage] == [$n])' \
        "$file" >/dev/null || fail "delegate hook is not named [$NAME]" || return 1
}

# No entry other than the delegate hook has a statusMessage.
assert_other_hooks_unnamed() {
    local file="$1" cmd="$2"
    assert_eq "$(jq --arg c "$cmd" '[.hooks.UserPromptSubmit[].hooks[] | select(.command != $c) | select(has("statusMessage"))] | length' "$file")" "0" || return 1
}

# Drops statusMessage everywhere, simulating a hook written by an older install.
strip_status_messages() {
    local file="$1" tmp
    tmp="$TMP/$(basename "$file").stripped"
    jq 'del(.hooks.UserPromptSubmit[].hooks[].statusMessage)' "$file" > "$tmp" && mv "$tmp" "$file"
}

# --- Claude ---

test_claude_install_names_the_delegate_hook() {
    install_home
    "$ROOT/install.sh" >/dev/null || fail "install failed" || return 1
    assert_delegate_named "$(claude_settings)" "$(claude_delegate_cmd)" || return 1
    assert_other_hooks_unnamed "$(claude_settings)" "$(claude_delegate_cmd)" || return 1
    assert_eq "$(jq -r '[.hooks.UserPromptSubmit[].hooks[].command] | join(",")' "$(claude_settings)")" "/opt/other-hook.sh,$(claude_delegate_cmd)"
}

test_claude_unnamed_hook_is_named_without_duplication() {
    install_home
    "$ROOT/install.sh" >/dev/null || fail "install failed" || return 1
    local cmd; cmd="$(claude_delegate_cmd)"
    strip_status_messages "$(claude_settings)"
    assert_eq "$(jq '[.hooks.UserPromptSubmit[].hooks[] | select(has("statusMessage"))] | length' "$(claude_settings)")" "0" || fail "strip failed" || return 1
    "$ROOT/install.sh" >/dev/null || fail "reinstall failed" || return 1
    jq -e --arg c "$cmd" '[.hooks.UserPromptSubmit[].hooks[] | select(.command == $c)] | length == 1' "$(claude_settings)" >/dev/null || fail "expected exactly one delegate hook entry" || return 1
    assert_delegate_named "$(claude_settings)" "$cmd" || return 1
    assert_other_hooks_unnamed "$(claude_settings)" "$cmd" || return 1
    assert_eq "$(jq -r '[.hooks.UserPromptSubmit[].hooks[].command] | join(",")' "$(claude_settings)")" "/opt/other-hook.sh,$cmd" || return 1
    assert_eq "$(jq -r .model "$(claude_settings)")" "x"
}

test_claude_second_install_is_byte_identical() {
    install_home
    "$ROOT/install.sh" >/dev/null || fail "install failed" || return 1
    cp "$(claude_settings)" "$TMP/claude-first.json"
    "$ROOT/install.sh" >/dev/null || fail "second install failed" || return 1
    cmp -s "$TMP/claude-first.json" "$(claude_settings)" || fail "settings.json changed on the second run"
}

test_claude_check_reports_unnamed_hook_as_differs() {
    install_home
    "$ROOT/install.sh" >/dev/null || fail "install failed" || return 1
    strip_status_messages "$(claude_settings)"
    local out rc
    out="$("$ROOT/install.sh" --check 2>&1)"; rc=$?
    [ "$rc" -ne 0 ] || fail "check exited 0 for an unnamed delegate hook" || return 1
    assert_contains "$out" "hook: differs" || return 1
    "$ROOT/install.sh" >/dev/null || fail "reinstall failed" || return 1
    out="$("$ROOT/install.sh" --check 2>&1)"; rc=$?
    assert_eq "$rc" "0" || return 1
    assert_contains "$out" "hook: installed"
}

# --- Codex ---

test_codex_install_names_the_delegate_hook() {
    name_codex_home
    env -u CODEX_HOME "$ROOT/install.sh" --codex >/dev/null || fail "Codex install failed" || return 1
    assert_delegate_named "$(codex_hooks)" "$(codex_delegate_cmd)" || return 1
    assert_other_hooks_unnamed "$(codex_hooks)" "$(codex_delegate_cmd)" || return 1
    assert_eq "$(jq -r '[.hooks.UserPromptSubmit[].hooks[].command] | join(",")' "$(codex_hooks)")" "/opt/codex-hook.sh,$(codex_delegate_cmd)"
}

test_codex_unnamed_hook_is_named_without_duplication() {
    name_codex_home
    env -u CODEX_HOME "$ROOT/install.sh" --codex >/dev/null || fail "Codex install failed" || return 1
    local cmd; cmd="$(codex_delegate_cmd)"
    strip_status_messages "$(codex_hooks)"
    assert_eq "$(jq '[.hooks.UserPromptSubmit[].hooks[] | select(has("statusMessage"))] | length' "$(codex_hooks)")" "0" || fail "strip failed" || return 1
    env -u CODEX_HOME "$ROOT/install.sh" --codex >/dev/null || fail "Codex reinstall failed" || return 1
    jq -e --arg c "$cmd" '[.hooks.UserPromptSubmit[].hooks[] | select(.command == $c)] | length == 1' "$(codex_hooks)" >/dev/null || fail "expected exactly one delegate hook entry" || return 1
    assert_delegate_named "$(codex_hooks)" "$cmd" || return 1
    assert_other_hooks_unnamed "$(codex_hooks)" "$cmd" || return 1
    assert_eq "$(jq -r '[.hooks.UserPromptSubmit[].hooks[].command] | join(",")' "$(codex_hooks)")" "/opt/codex-hook.sh,$cmd" || return 1
    assert_eq "$(jq -r .description "$(codex_hooks)")" "existing" || return 1
    jq -e '.hooks.Stop == []' "$(codex_hooks)" >/dev/null || return 1
}

test_codex_second_install_is_byte_identical() {
    name_codex_home
    env -u CODEX_HOME "$ROOT/install.sh" --codex >/dev/null || fail "Codex install failed" || return 1
    cp "$(codex_hooks)" "$TMP/codex-first.json"
    env -u CODEX_HOME "$ROOT/install.sh" --codex >/dev/null || fail "second Codex install failed" || return 1
    cmp -s "$TMP/codex-first.json" "$(codex_hooks)" || fail "hooks.json changed on the second run"
}

test_codex_check_reports_unnamed_hook_as_differs() {
    name_codex_home
    env -u CODEX_HOME "$ROOT/install.sh" --codex >/dev/null || fail "Codex install failed" || return 1
    strip_status_messages "$(codex_hooks)"
    local out rc
    out="$(env -u CODEX_HOME "$ROOT/install.sh" --codex --check 2>&1)"; rc=$?
    [ "$rc" -ne 0 ] || fail "check exited 0 for an unnamed delegate hook" || return 1
    assert_contains "$out" "hook: differs" || return 1
    env -u CODEX_HOME "$ROOT/install.sh" --codex >/dev/null || fail "Codex reinstall failed" || return 1
    out="$(env -u CODEX_HOME "$ROOT/install.sh" --codex --check 2>&1)"; rc=$?
    assert_eq "$rc" "0" || return 1
    assert_contains "$out" "hook: installed"
}
