#!/usr/bin/env bash
# Installs the delegate skill, its opencode agent, and its UserPromptSubmit hook.
#   ./install.sh [--target claude|codex|all] [--force] [--check]
#   --target claude   install into ~/.claude (skill and hooks in settings.json)
#   --target codex    install into ~/.codex (skill and hooks in hooks.json)
#   --target all      both targets
#   --force           install, overwriting a copy that differs
#   --check           report what is installed; exit 1 if anything is missing or differs
# Without --target, each of claude/codex whose home directory already exists is
# installed; if neither exists, --target is required.
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENT_SRC="$SRC/delegate/opencode/delegate-executor.md"
AGENT_DEST="$HOME/.config/opencode/agents/delegate-executor.md"

usage() {
    echo "usage: ./install.sh [--target claude|codex|all] [--force|--check]" >&2
    exit 2
}

MODE=install
TARGET=""
while [ $# -gt 0 ]; do
    case "$1" in
        --force) MODE=force; shift ;;
        --check) MODE=check; shift ;;
        --target) [ $# -ge 2 ] || usage; TARGET="$2"; shift 2 ;;
        *) usage ;;
    esac
done

case "$TARGET" in
    "" | claude | codex | all) ;;
    *) usage ;;
esac

if [ "$TARGET" = all ]; then
    targets=(claude codex)
elif [ -n "$TARGET" ]; then
    targets=("$TARGET")
else
    targets=()
    [ -d "$HOME/.claude" ] && targets+=(claude)
    [ -d "$HOME/.codex" ] && targets+=(codex)
    if [ ${#targets[@]} -eq 0 ]; then
        echo "install: no ~/.claude or ~/.codex found; re-run with --target claude|codex|all" >&2
        exit 2
    fi
fi

skill_dir() { echo "$HOME/.$1/skills/delegate"; }
hooks_file() { case "$1" in claude) echo "$HOME/.claude/settings.json" ;; codex) echo "$HOME/.codex/hooks.json" ;; esac; }
hook_cmd() { echo "$(skill_dir "$1")/bin/delegate hook"; }

# Prints missing, installed or differs.
state() { [ -e "$2" ] || { echo missing; return; }; diff -rq "$1" "$2" >/dev/null && echo installed || echo differs; }

# Both hooks files share one schema: a UserPromptSubmit array of {hooks: [...]}.
hook_state() {
    [ -f "$1" ] && jq -e --arg c "$2" \
        '[.hooks.UserPromptSubmit[]?.hooks[]?.command] | index($c)' "$1" >/dev/null 2>&1 \
        && echo installed || echo missing
}

# Appends the hook only when absent, so a second run leaves the file byte-identical.
install_hook() {
    [ "$(hook_state "$1" "$2")" = missing ] || return 0
    [ -f "$1" ] || echo '{}' > "$1"
    local tmp; tmp="$(mktemp "$1.XXXXXX")"
    jq --arg c "$2" \
        '.hooks.UserPromptSubmit = ((.hooks.UserPromptSubmit // []) + [{hooks: [{type: "command", command: $c}]}])' \
        "$1" > "$tmp" && mv "$tmp" "$1"
}

agent_state="$(state "$AGENT_SRC" "$AGENT_DEST")"

if [ "$MODE" = check ]; then
    rc=0
    for t in "${targets[@]}"; do
        s="$(state "$SRC/delegate" "$(skill_dir "$t")")"
        h="$(hook_state "$(hooks_file "$t")" "$(hook_cmd "$t")")"
        echo "$t skill: $s"; echo "$t hook: $h"
        [ "$s" = installed ] && [ "$h" = installed ] || rc=1
    done
    echo "agent: $agent_state"
    [ "$agent_state" = installed ] || rc=1
    exit "$rc"
fi

if [ "$MODE" = install ]; then
    for t in "${targets[@]}"; do
        if [ "$agent_state" = differs ] || [ "$(state "$SRC/delegate" "$(skill_dir "$t")")" = differs ]; then
            echo "$t: an installed copy differs from this one; re-run with --force to overwrite it." >&2
            exit 1
        fi
    done
fi

# The opencode agent is shared by every target, so it is installed once.
mkdir -p "$(dirname "$AGENT_DEST")" && cp "$AGENT_SRC" "$AGENT_DEST"

for t in "${targets[@]}"; do
    rm -rf "$(skill_dir "$t")" && mkdir -p "$(dirname "$(skill_dir "$t")")" && cp -R "$SRC/delegate" "$(skill_dir "$t")"
    install_hook "$(hooks_file "$t")" "$(hook_cmd "$t")"
done

echo "delegate installed: agent in $AGENT_DEST, skill and hook for ${targets[*]}"
[[ " ${targets[*]} " == *" codex "* ]] && \
    echo 'codex: approve the delegate hook once in Codex (it is marked "review required" until you do)'
command -v opencode >/dev/null 2>&1 || \
    echo "warning: opencode is not on PATH; delegate mode cannot be switched on until it is installed (https://opencode.ai)" >&2
