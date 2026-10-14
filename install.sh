#!/usr/bin/env bash
# Installs the delegate skill, its opencode agent, and its UserPromptSubmit hook.
#   ./install.sh [--codex|--target claude|codex|all] [--force|--check]
# Default: install for every assistant home that exists (~/.claude and/or
# ${CODEX_HOME:-~/.codex}), and fail if neither exists. --codex: Codex only.
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENT_DEST="$HOME/.config/opencode/agents/delegate-executor.md"

MODE=install
TARGET=""
choose_target() {
    if [ -n "$TARGET" ] && [ "$TARGET" != "$1" ]; then
        echo "delegate: conflicting install targets" >&2; exit 2
    fi
    TARGET="$1"
}
usage() { echo "usage: ./install.sh [--codex|--target claude|codex|all] [--force|--check]" >&2; exit 2; }
while [ $# -gt 0 ]; do
    case "$1" in
        --codex) choose_target codex; shift ;;
        --target) [ $# -ge 2 ] || usage; choose_target "$2"; shift 2 ;;
        --force) [ "$MODE" != check ] || { echo "--force and --check cannot be combined" >&2; exit 2; }; MODE=force; shift ;;
        --check) [ "$MODE" != force ] || { echo "--force and --check cannot be combined" >&2; exit 2; }; MODE=check; shift ;;
        *) usage ;;
    esac
done
if [ -n "$TARGET" ]; then
    case "$TARGET" in
        claude|codex) targets=("$TARGET") ;;
        all) targets=(claude codex) ;;
        *) usage ;;
    esac
else
    targets=()
    if [ -d "$HOME/.claude" ]; then targets+=(claude); fi
    if [ -d "${CODEX_HOME:-$HOME/.codex}" ]; then targets+=(codex); fi
    if [ "${#targets[@]}" -eq 0 ]; then
        echo "install: no ~/.claude or ~/.codex found; re-run with --target claude|codex|all" >&2
        exit 2
    fi
fi

select_target() {
    HOST="$1"
    if [ "$HOST" = codex ]; then
        HOST_ROOT="${CODEX_HOME:-$HOME/.codex}"
        SETTINGS="$HOST_ROOT/hooks.json"
    else
        HOST_ROOT="$HOME/.claude"
        SETTINGS="$HOST_ROOT/settings.json"
    fi
    SKILL_DEST="$HOST_ROOT/skills/delegate"
    printf -v HOOK_CMD '%q hook' "$SKILL_DEST/bin/delegate"
}

# Prints missing, installed or differs.
state() { [ -e "$2" ] || { echo missing; return; }; diff -rq "$1" "$2" >/dev/null && echo installed || echo differs; }

hook_state() {
    [ -f "$SETTINGS" ] && jq -e --arg c "$HOOK_CMD" \
        '[.hooks.UserPromptSubmit[]?.hooks[]?.command] | index($c)' "$SETTINGS" >/dev/null 2>&1 \
        && echo installed || echo missing
}

agent_state="$(state "$SRC/delegate/opencode/delegate-executor.md" "$AGENT_DEST")"
# Validate every selected target before writing any installation files.
rc=0
for t in "${targets[@]}"; do
    select_target "$t"
    if [ -e "$SETTINGS" ] && ! jq -se '
        length == 1 and (.[0] | type == "object"
        and (.hooks == null or (.hooks | type == "object"))
        and (.hooks.UserPromptSubmit == null or (.hooks.UserPromptSubmit | type == "array")))
    ' "$SETTINGS" >/dev/null 2>&1; then
        echo "delegate: invalid hook configuration: $SETTINGS" >&2; exit 1
    fi
    skill_state="$(state "$SRC/delegate" "$SKILL_DEST")"
    if [ "$MODE" = check ]; then
        echo "$t skill: $skill_state"; echo "$t hook: $(hook_state)"
        [ "$skill_state $(hook_state)" = "installed installed" ] || rc=1
    elif [ "$MODE" = install ] && { [ "$skill_state" = differs ] || [ "$agent_state" = differs ]; }; then
        echo "$t skill: $skill_state, agent: $agent_state. An installed copy differs from this one; re-run with --force to overwrite it." >&2
        exit 1
    fi
    if [ "$MODE" != check ] && [ -d "$SKILL_DEST" ] && [ "$(cd "$SKILL_DEST" && pwd -P)" = "$(cd "$SRC/delegate" && pwd -P)" ]; then
        echo "delegate: cannot install over the source directory" >&2; exit 1
    fi
done
if [ "$MODE" = check ]; then
    echo "agent: $agent_state"
    [ "$agent_state" = installed ] || rc=1
    exit "$rc"
fi

mkdir -p "$(dirname "$AGENT_DEST")" && cp "$SRC/delegate/opencode/delegate-executor.md" "$AGENT_DEST"
for t in "${targets[@]}"; do
    select_target "$t"
    rm -rf "$SKILL_DEST" && mkdir -p "$(dirname "$SKILL_DEST")" && cp -R "$SRC/delegate" "$SKILL_DEST"
    if [ "$(hook_state)" = missing ]; then
        [ -f "$SETTINGS" ] || echo '{}' > "$SETTINGS"
        tmp="$(mktemp "$SETTINGS.XXXXXX")"
        jq --arg c "$HOOK_CMD" \
            '.hooks.UserPromptSubmit = ((.hooks.UserPromptSubmit // []) + [{hooks: [{type: "command", command: $c}]}])' \
            "$SETTINGS" > "$tmp" && mv "$tmp" "$SETTINGS"
    fi
done
echo "delegate installed: agent in $AGENT_DEST, skill and hook for ${targets[*]}"
if [[ " ${targets[*]} " == *" codex "* ]]; then
    echo "Codex: open /hooks to review and trust the delegate hook. Reload skills or start a new session if needed."
fi
if ! command -v opencode >/dev/null 2>&1; then
    echo "warning: opencode is not on PATH; delegate mode cannot be switched on until it is installed (https://opencode.ai)" >&2
fi
