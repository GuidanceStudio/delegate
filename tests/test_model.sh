# `delegate model` picks an executor model and its effort, known presets first,
# otherwise from `opencode models --verbose`, and writes $DELEGATE_CONFIG.

test_model_preset_with_explicit_effort() {
    fake_models
    local out rc
    out="$("$DELEGATE" model openrouter/deepseek/deepseek-v4.1-flash low 2>"$TMP/err")"; rc=$?
    assert_eq "$rc" "0" || return 1
    assert_contains "$out" "model: openrouter/deepseek/deepseek-v4.1-flash" || return 1
    assert_contains "$out" "effort: low" || return 1
    assert_contains "$out" "levels: low medium high max" || return 1
    grep -qx "model=openrouter/deepseek/deepseek-v4.1-flash" "$DELEGATE_CONFIG" \
        || fail "model not written to config" || return 1
    grep -qx "variant=low" "$DELEGATE_CONFIG" || fail "variant not written to config"
}

test_model_glm_default_effort_is_high() {
    fake_models
    local out rc
    out="$("$DELEGATE" model openrouter/z-ai/glm-5.3-flash 2>"$TMP/err")"; rc=$?
    assert_eq "$rc" "0" || return 1
    assert_contains "$out" "effort: high" || return 1
    assert_contains "$out" "levels: low medium high max" || return 1
    grep -qx "model=openrouter/z-ai/glm-5.3-flash" "$DELEGATE_CONFIG" || return 1
    grep -qx "variant=high" "$DELEGATE_CONFIG" || fail "high not chosen by default"
}

test_model_preset_does_not_call_opencode() {
    fake_models
    local rc
    "$DELEGATE" model openrouter/qwen/qwen3.8-flash high >/dev/null 2>&1; rc=$?
    assert_eq "$rc" "0" || return 1
    [ ! -s "$TMP/models_calls" ] || fail "opencode was invoked for a preset: $(cat "$TMP/models_calls")"
}

test_model_discovered_default_is_xhigh() {
    fake_models
    local out rc
    out="$("$DELEGATE" model openrouter/x-ai/grok-4.6 2>"$TMP/err")"; rc=$?
    assert_eq "$rc" "0" || return 1
    assert_contains "$out" "model: openrouter/x-ai/grok-4.6" || return 1
    assert_contains "$out" "effort: xhigh" || return 1
    assert_contains "$out" "levels: low high xhigh" || return 1
    grep -qx "model=openrouter/x-ai/grok-4.6" "$DELEGATE_CONFIG" || return 1
    grep -qx "variant=xhigh" "$DELEGATE_CONFIG" || fail "xhigh not chosen"
}

test_model_discovered_without_variants_is_none() {
    fake_models
    local out rc
    out="$("$DELEGATE" model openrouter/acme/plain 2>"$TMP/err")"; rc=$?
    assert_eq "$rc" "0" || return 1
    assert_contains "$out" "effort: none" || return 1
    assert_contains "$out" "levels:" || return 1
    grep -qx "model=openrouter/acme/plain" "$DELEGATE_CONFIG" || return 1
    grep -qx "variant=" "$DELEGATE_CONFIG" || fail "variant should be empty"
}

test_model_unknown_model_is_refused() {
    fake_models
    local out rc
    out="$("$DELEGATE" model openrouter/nope/nope 2>&1)"; rc=$?
    assert_eq "$rc" "1" || return 1
    assert_contains "$out" "openrouter/nope/nope" || return 1
    assert_contains "$out" "opencode config" || return 1
    [ ! -e "$DELEGATE_CONFIG" ] || fail "config written for an unknown model"
}

test_model_unknown_effort_is_refused() {
    fake_models
    local out rc
    out="$("$DELEGATE" model openrouter/qwen/qwen3.8-flash low 2>&1)"; rc=$?
    assert_eq "$rc" "1" || return 1
    assert_contains "$out" "high max" || return 1
    [ ! -e "$DELEGATE_CONFIG" ] || fail "config written for an unknown effort"
}

test_model_no_args_shows_current_and_presets() {
    printf 'model=openrouter/z-ai/glm-5.3-flash\nvariant=max\n' > "$DELEGATE_CONFIG"
    local out rc
    out="$("$DELEGATE" model 2>"$TMP/err")"; rc=$?
    assert_eq "$rc" "0" || return 1
    assert_contains "$out" "model: openrouter/z-ai/glm-5.3-flash" || return 1
    assert_contains "$out" "effort: max" || return 1
    assert_contains "$out" "openrouter/deepseek/deepseek-v4.1-flash" || return 1
    assert_contains "$out" "openrouter/z-ai/glm-5.3-flash" || return 1
    assert_contains "$out" "openrouter/qwen/qwen3.8-flash"
}

test_model_no_args_without_config_shows_the_default() {
    local out
    out="$("$DELEGATE" model)"
    assert_contains "$out" "model: openrouter/deepseek/deepseek-v4.1-flash" || return 1
    assert_contains "$out" "effort: high"
}

test_model_discovery_failure_does_not_save_a_selection() {
    local out rc
    out="$(PATH="$(path_without_opencode)" "$DELEGATE" model openrouter/acme/plain 2>&1)"; rc=$?
    assert_eq "$rc" 1 || return 1
    assert_contains "$out" 'unable to read models' || return 1
    [ ! -e "$DELEGATE_CONFIG" ] || fail "selection saved after failed discovery"
}

test_model_write_failure_does_not_report_success() {
    printf 'not a directory' > "$TMP/blocked"
    local rc
    DELEGATE_CONFIG="$TMP/blocked/config" "$DELEGATE" model openrouter/z-ai/glm-5.3-flash max >/dev/null 2>&1; rc=$?
    assert_eq "$rc" 1
}

test_glm_medium_is_a_valid_effort() {
    fake_models
    local out rc
    out="$("$DELEGATE" model openrouter/z-ai/glm-5.3-flash medium 2>"$TMP/err")"; rc=$?
    assert_eq "$rc" "0" || return 1
    assert_contains "$out" "effort: medium" || return 1
    assert_contains "$out" "levels: low medium high max" || return 1
    grep -qx "model=openrouter/z-ai/glm-5.3-flash" "$DELEGATE_CONFIG" || return 1
    grep -qx "variant=medium" "$DELEGATE_CONFIG" || fail "medium not saved"
}
