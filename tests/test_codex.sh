codex_install_home() {
    install_home
    mkdir -p "$HOME/.codex"
    printf '%s\n' '{"description":"existing","hooks":{"UserPromptSubmit":[{"hooks":[{"type":"command","command":"/opt/codex-hook.sh"}]}],"Stop":[]}}' > "$HOME/.codex/hooks.json"
}

codex_hook_commands() {
    jq -r '[.hooks.UserPromptSubmit[].hooks[].command] | join(",")' "${CODEX_HOME:-$HOME/.codex}/hooks.json"
}

test_codex_installs_skill_agent_and_hook_without_changing_claude() {
    codex_install_home
    cp "$HOME/.claude/settings.json" "$TMP/claude-before.json"
    local out
    out="$(env -u CODEX_HOME "$ROOT/install.sh" --codex)" || fail "Codex installation failed" || return 1
    [ -x "$HOME/.codex/skills/delegate/bin/delegate" ] || fail "Codex script missing" || return 1
    [ -f "$HOME/.config/opencode/agents/delegate-executor.md" ] || fail "executor missing" || return 1
    assert_eq "$(codex_hook_commands)" "/opt/codex-hook.sh,$HOME/.codex/skills/delegate/bin/delegate hook" || return 1
    assert_eq "$(jq -r .description "$HOME/.codex/hooks.json")" existing || return 1
    jq -e '.hooks.Stop == []' "$HOME/.codex/hooks.json" >/dev/null || return 1
    cmp -s "$TMP/claude-before.json" "$HOME/.claude/settings.json" || fail "Claude settings changed" || return 1
    assert_contains "$out" /hooks
}

test_codex_install_is_idempotent_and_options_work_in_either_order() {
    codex_install_home
    env -u CODEX_HOME "$ROOT/install.sh" --codex >/dev/null || return 1
    cp "$HOME/.codex/hooks.json" "$TMP/codex-before.json"
    env -u CODEX_HOME "$ROOT/install.sh" --codex >/dev/null || return 1
    cmp -s "$TMP/codex-before.json" "$HOME/.codex/hooks.json" || fail "Codex hooks changed on reinstall" || return 1
    env -u CODEX_HOME "$ROOT/install.sh" --codex --check >/dev/null || return 1
    env -u CODEX_HOME "$ROOT/install.sh" --check --codex >/dev/null || return 1
    printf '\nlocal edit\n' >> "$HOME/.codex/skills/delegate/SKILL.md"
    ! env -u CODEX_HOME "$ROOT/install.sh" --codex >/dev/null 2>&1 || fail "overwrote modified skill" || return 1
    env -u CODEX_HOME "$ROOT/install.sh" --force --codex >/dev/null || return 1
    env -u CODEX_HOME "$ROOT/install.sh" --codex --force >/dev/null || return 1
    cmp -s "$ROOT/delegate/SKILL.md" "$HOME/.codex/skills/delegate/SKILL.md" || fail "force did not replace skill"
}

test_codex_check_does_not_install() {
    install_home
    local rc
    env -u CODEX_HOME "$ROOT/install.sh" --codex --check >/dev/null; rc=$?
    assert_eq "$rc" 1 || return 1
    [ ! -e "$HOME/.codex" ] || fail "check wrote Codex files"
}

test_codex_custom_home_and_quoted_hook_work_without_session_environment() {
    install_home
    unset DELEGATE_STATE_DIR
    local codex_home="$TMP/custom codex" script hook out
    env CODEX_HOME="$codex_home" "$ROOT/install.sh" --codex >/dev/null || return 1
    script="$codex_home/skills/delegate/bin/delegate"
    env CODEX_HOME="$codex_home" CODEX_SESSION_ID=sess-codex CLAUDE_CODE_SESSION_ID= "$script" on >/dev/null || return 1
    [ -f "$codex_home/state/delegate/sess-codex" ] || fail "custom state missing" || return 1
    hook="$(jq -r '.hooks.UserPromptSubmit[0].hooks[0].command' "$codex_home/hooks.json")"
    out="$(printf '{"session_id":"sess-codex","cwd":"%s"}' "$PWD" | env CODEX_HOME="$codex_home" CODEX_SESSION_ID= CLAUDE_CODE_SESSION_ID= bash -c "$hook")"
    assert_contains "$out" 'delegate mode is ON (session)' || return 1
    [ ! -e "$HOME/.codex" ] || fail "ignored custom Codex home"
}

test_codex_sessions_projects_and_off_are_isolated_from_claude() {
    install_home
    unset DELEGATE_STATE_DIR
    local codex_home="$TMP/codex-home"
    DELEGATE_HOST=claude "$DELEGATE" on >/dev/null || return 1
    DELEGATE_HOST=claude "$DELEGATE" on --project >/dev/null || return 1
    assert_eq "$(env CODEX_HOME="$codex_home" CODEX_SESSION_ID=sess-1 "$DELEGATE" status)" off || return 1
    env CODEX_HOME="$codex_home" CODEX_SESSION_ID=sess-1 "$DELEGATE" on >/dev/null || return 1
    assert_eq "$(env CODEX_HOME="$codex_home" CODEX_SESSION_ID=sess-2 "$DELEGATE" status)" off || return 1
    mkdir sub && touch sub/keep && git add sub/keep && cd sub
    env CODEX_HOME="$codex_home" CODEX_SESSION_ID=sess-1 "$DELEGATE" on --project >/dev/null || return 1
    [ -f ../.codex/delegate.on ] || fail "Codex project flag not at root" || return 1
    assert_eq "$(env CODEX_HOME="$codex_home" CODEX_SESSION_ID=sess-1 "$DELEGATE" status)" 'on (session, project)' || return 1
    assert_eq "$(env CODEX_HOME="$codex_home" CODEX_SESSION_ID=sess-2 "$DELEGATE" status)" 'on (project)' || return 1
    env CODEX_HOME="$codex_home" CODEX_SESSION_ID=sess-1 "$DELEGATE" off >/dev/null || return 1
    assert_eq "$(env CODEX_HOME="$codex_home" CODEX_SESSION_ID=sess-1 "$DELEGATE" status)" off || return 1
    assert_eq "$(DELEGATE_HOST=claude "$DELEGATE" status)" 'on (session, project)'
}

test_codex_hook_uses_stdin_session_and_project_state() {
    DELEGATE_HOST=codex CODEX_SESSION_ID=c1 "$DELEGATE" on >/dev/null || return 1
    local out
    out="$(printf '{"session_id":"c2","cwd":"%s"}' "$PWD" | DELEGATE_HOST=codex CODEX_SESSION_ID=c1 "$DELEGATE" hook)"
    assert_eq "$out" '' || return 1
    DELEGATE_HOST=codex "$DELEGATE" on --project >/dev/null || return 1
    out="$(printf '{"session_id":"c2","cwd":"%s"}' "$PWD" | DELEGATE_HOST=codex "$DELEGATE" hook)"
    assert_contains "$out" 'delegate mode is ON (project)' || return 1
    out="$(printf 'not json' | DELEGATE_HOST=codex "$DELEGATE" hook)" || fail "invalid input blocked the hook" || return 1
    assert_eq "$out" ''
}

test_codex_without_session_id_requires_project_mode() {
    local out rc
    out="$(DELEGATE_HOST=codex CODEX_SESSION_ID= "$DELEGATE" on 2>&1)"; rc=$?
    assert_eq "$rc" 1 || return 1
    assert_contains "$out" --project
}

test_codex_accepts_thread_id_when_session_id_is_absent() {
    CODEX_THREAD_ID=codex-thread "$DELEGATE" on >/dev/null || return 1
    [ -f "$DELEGATE_STATE_DIR/codex-thread" ] || fail "thread flag missing" || return 1
    assert_eq "$(CODEX_THREAD_ID=codex-thread "$DELEGATE" status)" 'on (session)' || return 1
    assert_eq "$(CODEX_THREAD_ID=another-thread "$DELEGATE" status)" off
}

test_invalid_hook_configuration_leaves_installation_untouched() {
    install_home
    mkdir -p "$HOME/.codex"
    local invalid
    for invalid in 'not json' '' '[]' '{"hooks":[]}' '{"hooks":{"UserPromptSubmit":{}}}' '{} {}'; do
        printf '%s' "$invalid" > "$HOME/.codex/hooks.json"
        cp "$HOME/.codex/hooks.json" "$TMP/invalid-before.json"
        ! env -u CODEX_HOME "$ROOT/install.sh" --codex --force >/dev/null 2>&1 || fail "invalid hooks accepted" || return 1
        cmp -s "$TMP/invalid-before.json" "$HOME/.codex/hooks.json" || fail "invalid hooks changed" || return 1
        [ ! -e "$HOME/.codex/skills/delegate" ] || fail "skill written before validation" || return 1
        [ ! -e "$HOME/.config/opencode/agents/delegate-executor.md" ] || fail "agent written before validation" || return 1
    done
}

test_install_rejects_conflicting_modes_and_unknown_options() {
    local args rc
    for args in '--codex --force --check' '--check --codex --force' '--other'; do
        "$ROOT/install.sh" $args >/dev/null 2>&1; rc=$?
        assert_eq "$rc" 2 || return 1
    done
}
