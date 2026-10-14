# Shared helpers: each test runs in a fresh temp dir with its own state dir.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DELEGATE="$ROOT/delegate/bin/delegate"

setup() {
    TMP="$(mktemp -d)"
    unset CODEX_SESSION_ID CODEX_THREAD_ID CODEX_HOME DELEGATE_HOST
    unset DELEGATE_MODEL DELEGATE_VARIANT OPENCODE_CONFIG_CONTENT
    export DELEGATE_STATE_DIR="$TMP/state"
    export DELEGATE_CONFIG="$TMP/config"
    export CLAUDE_CODE_SESSION_ID="sess-1"
    mkdir -p "$TMP/repo" "$TMP/bin" && git -C "$TMP/repo" init -q
    printf '#!/usr/bin/env bash\nexit 0\n' > "$TMP/bin/opencode"
    chmod +x "$TMP/bin/opencode"
    export PATH="$TMP/bin:$PATH"
    cd "$TMP/repo"
}

# Replaces the stub opencode with one that answers `models --verbose` with two
# blocks — one with variants (grok), one without (plain) — and appends one line
# to $TMP/models_calls per invocation, so a test can prove it was not called.
fake_models() {
    mkdir -p "$TMP/bin"
    cat > "$TMP/bin/opencode" <<'FAKE'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$FAKE_MODELS_CALLS"
if [ "${1:-}" = "models" ] && [ "${2:-}" = "--verbose" ]; then
    cat <<'OUT'
openrouter/x-ai/grok-4.6
{
  "id": "x-ai/grok-4.6",
  "providerID": "openrouter",
  "variants": {
    "low": { "reasoningEffort": "low" },
    "high": { "reasoningEffort": "high" },
    "xhigh": { "reasoningEffort": "xhigh" }
  }
}
openrouter/acme/plain
{
  "id": "acme/plain",
  "providerID": "openrouter"
}
OUT
fi
exit 0
FAKE
    chmod +x "$TMP/bin/opencode"
    export PATH="$TMP/bin:$PATH" FAKE_MODELS_CALLS="$TMP/models_calls"
}

# Prints PATH with every directory that holds an executable `opencode` removed.
path_without_opencode() {
    local dirs dir out=""
    IFS=':' read -r -a dirs <<< "$PATH"
    for dir in "${dirs[@]}"; do
        [ -x "$dir/opencode" ] && continue
        out="${out:+$out:}$dir"
    done
    printf '%s' "$out"
}

teardown() { cd /; rm -rf "$TMP"; }

fail() { echo "  FAIL: $*"; return 1; }

assert_eq() { [ "$1" = "$2" ] || fail "expected [$2], got [$1]"; }
assert_contains() { case "$1" in *"$2"*) ;; *) fail "[$1] does not contain [$2]";; esac; }

install_home() {
    export HOME="$TMP/home"
    mkdir -p "$HOME/.claude"
    printf '%s\n' '{"model":"x","hooks":{"UserPromptSubmit":[{"hooks":[{"type":"command","command":"/opt/other-hook.sh"}]}]}}' > "$HOME/.claude/settings.json"
}
