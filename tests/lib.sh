# Shared helpers: each test runs in a fresh temp dir with its own state dir.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DELEGATE="$ROOT/delegate/bin/delegate"

setup() {
    TMP="$(mktemp -d)"
    export DELEGATE_STATE_DIR="$TMP/state"
    export CLAUDE_CODE_SESSION_ID="sess-1"
    mkdir -p "$TMP/repo" && git -C "$TMP/repo" init -q
    cd "$TMP/repo"
}

teardown() { cd /; rm -rf "$TMP"; }

fail() { echo "  FAIL: $*"; return 1; }

assert_eq() { [ "$1" = "$2" ] || fail "expected [$2], got [$1]"; }
assert_contains() { case "$1" in *"$2"*) ;; *) fail "[$1] does not contain [$2]";; esac; }
