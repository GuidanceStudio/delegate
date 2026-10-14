# Endpoint preferences belong to a complete OpenRouter model id.

test_provider_default_is_auto_without_writing_or_discovering_models() {
    fake_models
    local out
    out="$("$DELEGATE" provider)" || return 1
    assert_contains "$out" 'model: openrouter/deepseek/deepseek-v4.1-flash' || return 1
    assert_contains "$out" 'provider: auto' || return 1
    [ ! -e "$DELEGATE_CONFIG" ] || fail 'read command wrote config' || return 1
    [ ! -e "$FAKE_MODELS_CALLS" ] || fail 'provider command called opencode'
}

test_provider_preserves_model_effort_and_unknown_keys() {
    printf 'model=openrouter/z-ai/glm-5.3-flash\nvariant=low\ncustom=keep' > "$DELEGATE_CONFIG"
    local out
    out="$("$DELEGATE" provider coreweave/nvfp4)" || return 1
    assert_contains "$out" 'provider: coreweave/nvfp4' || return 1
    out="$("$DELEGATE" model)" || return 1
    assert_contains "$out" 'effort: low' || return 1
    grep -qx 'custom=keep' "$DELEGATE_CONFIG" || return 1
    grep -qx 'provider.openrouter/z-ai/glm-5.3-flash=coreweave/nvfp4' "$DELEGATE_CONFIG" || return 1
    out="$("$DELEGATE" provider)" || return 1
    assert_contains "$out" 'provider: coreweave/nvfp4'
}

test_provider_choices_survive_model_switches_and_reset_independently() {
    "$DELEGATE" model openrouter/z-ai/glm-5.3-flash max >/dev/null || return 1
    "$DELEGATE" provider coreweave/nvfp4 >/dev/null || return 1
    "$DELEGATE" model openrouter/deepseek/deepseek-v4.1-flash high >/dev/null || return 1
    local out
    out="$("$DELEGATE" provider)" || return 1
    assert_contains "$out" 'provider: auto' || return 1
    "$DELEGATE" provider deepinfra/turbo >/dev/null || return 1
    "$DELEGATE" model openrouter/z-ai/glm-5.3-flash low >/dev/null || return 1
    out="$("$DELEGATE" provider)" || return 1
    assert_contains "$out" 'provider: coreweave/nvfp4' || return 1
    "$DELEGATE" provider auto >/dev/null || return 1
    out="$("$DELEGATE" model)" || return 1
    assert_contains "$out" 'effort: low' || return 1
    if grep -q '^provider.openrouter/z-ai/glm-5.3-flash=' "$DELEGATE_CONFIG"; then
        fail 'auto did not remove preference'; return 1
    fi
    "$DELEGATE" model openrouter/deepseek/deepseek-v4.1-flash >/dev/null || return 1
    out="$("$DELEGATE" provider)" || return 1
    assert_contains "$out" 'provider: deepinfra/turbo'
}

test_provider_model_override_does_not_change_saved_model() {
    "$DELEGATE" model openrouter/z-ai/glm-5.3-flash max >/dev/null || return 1
    DELEGATE_MODEL=openrouter/deepseek/deepseek-v4.1-flash "$DELEGATE" provider deepinfra >/dev/null || return 1
    local out
    out="$(DELEGATE_MODEL=openrouter/deepseek/deepseek-v4.1-flash "$DELEGATE" provider)" || return 1
    assert_contains "$out" 'provider: deepinfra' || return 1
    out="$("$DELEGATE" provider)" || return 1
    assert_contains "$out" 'model: openrouter/z-ai/glm-5.3-flash' || return 1
    assert_contains "$out" 'provider: auto' || return 1
    out="$("$DELEGATE" model)" || return 1
    assert_contains "$out" 'effort: max'
}

test_provider_invalid_arguments_leave_saved_choice_unchanged() {
    "$DELEGATE" provider coreweave/nvfp4 >/dev/null || return 1
    cp "$DELEGATE_CONFIG" "$TMP/before"
    local endpoint out rc
    for endpoint in '' 'two words' $'bad\nvariant=low' $'bad\rslug' $'bad\tslug' 'UPPERCASE' '/leading' 'trailing/' 'double//slash' 'bad=value'; do
        out="$("$DELEGATE" provider "$endpoint" 2>&1)"; rc=$?
        assert_eq "$rc" 1 || return 1
        assert_contains "$out" 'invalid endpoint' || return 1
        cmp -s "$DELEGATE_CONFIG" "$TMP/before" || fail 'invalid endpoint changed config' || return 1
    done
    "$DELEGATE" provider coreweave extra >/dev/null 2>&1; rc=$?
    assert_eq "$rc" 2 || return 1
    cmp -s "$DELEGATE_CONFIG" "$TMP/before" || fail 'extra arguments changed config'
}

test_provider_non_openrouter_model_rejects_endpoint_but_allows_auto() {
    printf 'model=anthropic/example\nvariant=high\ncustom=keep\n' > "$DELEGATE_CONFIG"
    cp "$DELEGATE_CONFIG" "$TMP/before"
    local out rc
    out="$("$DELEGATE" provider coreweave 2>&1)"; rc=$?
    assert_eq "$rc" 1 || return 1
    assert_contains "$out" 'only available for OpenRouter models' || return 1
    cmp -s "$DELEGATE_CONFIG" "$TMP/before" || return 1
    out="$("$DELEGATE" provider auto)" || return 1
    assert_contains "$out" 'provider: auto' || return 1
    cmp -s "$DELEGATE_CONFIG" "$TMP/before" || return 1
    out="$("$DELEGATE" model)" || return 1
    assert_contains "$out" 'model: anthropic/example'
}

test_provider_atomic_rename_failure_preserves_config_and_cleans_temp() {
    "$DELEGATE" provider coreweave >/dev/null || return 1
    cp "$DELEGATE_CONFIG" "$TMP/before"
    printf '#!/usr/bin/env bash\nexit 1\n' > "$TMP/bin/mv"
    chmod +x "$TMP/bin/mv"
    local out rc
    out="$("$DELEGATE" provider deepinfra 2>&1)"; rc=$?
    assert_eq "$rc" 1 || return 1
    assert_eq "$out" '' || return 1
    cmp -s "$DELEGATE_CONFIG" "$TMP/before" || fail 'rename failure changed config' || return 1
    local temps=("$DELEGATE_CONFIG".tmp.*)
    [ ! -e "${temps[0]}" ] || fail 'temporary config left behind'
}

test_provider_directory_config_is_refused() {
    mkdir "$TMP/directory-config"
    local out rc
    out="$(DELEGATE_CONFIG="$TMP/directory-config" "$DELEGATE" provider coreweave 2>&1)"; rc=$?
    assert_eq "$rc" 1 || return 1
    assert_contains "$out" 'config path is a directory' || return 1
    [ -z "$(ls -A "$TMP/directory-config")" ] || fail 'wrote inside config directory'
}
