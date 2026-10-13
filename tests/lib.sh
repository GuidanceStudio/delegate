# Shared helpers: each test runs in a fresh temp dir with its own state dir.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DELEGATE="$ROOT/delegate/bin/delegate"

setup() {
    TMP="$(mktemp -d)"
    export DELEGATE_STATE_DIR="$TMP/state"
    export CLAUDE_CODE_SESSION_ID="sess-1"
    mkdir -p "$TMP/repo" "$TMP/bin" && git -C "$TMP/repo" init -q
    # A trivial opencode so tests pass on machines where it is not installed;
    # test_run.sh's fake_opencode overwrites this same file.
    printf '#!/usr/bin/env bash\nexit 0\n' > "$TMP/bin/opencode"
    chmod +x "$TMP/bin/opencode"
    export PATH="$TMP/bin:$PATH"
    cd "$TMP/repo"
}

teardown() { cd /; rm -rf "$TMP"; }

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

fail() { echo "  FAIL: $*"; return 1; }

assert_eq() { [ "$1" = "$2" ] || fail "expected [$2], got [$1]"; }
assert_contains() { case "$1" in *"$2"*) ;; *) fail "[$1] does not contain [$2]";; esac; }
