#!/usr/bin/env bash
# Installs the delegate skill, its opencode agent, and its UserPromptSubmit hook.
#   ./install.sh           install; refuses to overwrite a copy that differs
#   ./install.sh --force   install, overwriting a copy that differs
#   ./install.sh --check   report what is installed; exit 1 if anything is missing or differs
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DEST="$HOME/.claude/skills/delegate"
AGENT_DEST="$HOME/.config/opencode/agents/delegate-executor.md"
SETTINGS="$HOME/.claude/settings.json"
HOOK_CMD="$SKILL_DEST/bin/delegate hook"

MODE=install
case "${1:-}" in
    "") ;;
    --force) MODE=force ;;
    --check) MODE=check ;;
    *) echo "usage: ./install.sh [--force|--check]" >&2; exit 2 ;;
esac

# Prints missing, installed or differs.
state() { [ -e "$2" ] || { echo missing; return; }; diff -rq "$1" "$2" >/dev/null && echo installed || echo differs; }

hook_state() {
    [ -f "$SETTINGS" ] && jq -e --arg c "$HOOK_CMD" \
        '[.hooks.UserPromptSubmit[]?.hooks[]?.command] | index($c)' "$SETTINGS" >/dev/null 2>&1 \
        && echo installed || echo missing
}

skill_state="$(state "$SRC/delegate" "$SKILL_DEST")"
agent_state="$(state "$SRC/delegate/opencode/delegate-executor.md" "$AGENT_DEST")"

if [ "$MODE" = check ]; then
    echo "skill: $skill_state"; echo "agent: $agent_state"; echo "hook: $(hook_state)"
    [ "$skill_state $agent_state $(hook_state)" = "installed installed installed" ]
    exit
fi

if [ "$MODE" = install ] && { [ "$skill_state" = differs ] || [ "$agent_state" = differs ]; }; then
    echo "skill: $skill_state, agent: $agent_state. An installed copy differs from this one;" \
         "re-run with --force to overwrite it." >&2
    exit 1
fi

rm -rf "$SKILL_DEST" && mkdir -p "$(dirname "$SKILL_DEST")" && cp -R "$SRC/delegate" "$SKILL_DEST"
mkdir -p "$(dirname "$AGENT_DEST")" && cp "$SRC/delegate/opencode/delegate-executor.md" "$AGENT_DEST"

# settings.json is rewritten only when the hook is absent, so a second run leaves it byte-identical.
if [ "$(hook_state)" = missing ]; then
    [ -f "$SETTINGS" ] || echo '{}' > "$SETTINGS"
    tmp="$(mktemp "$SETTINGS.XXXXXX")"
    jq --arg c "$HOOK_CMD" \
        '.hooks.UserPromptSubmit = ((.hooks.UserPromptSubmit // []) + [{hooks: [{type: "command", command: $c}]}])' \
        "$SETTINGS" > "$tmp" && mv "$tmp" "$SETTINGS"
fi

echo "delegate installed: skill in $SKILL_DEST, agent in $AGENT_DEST, hook in $SETTINGS"
