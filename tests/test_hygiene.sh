# The repo is public and installed on other machines: no path from the
# author's machine may ship. Extra patterns (client or project names) are
# read from DELEGATE_HYGIENE_PATTERNS, a file kept outside the repo.
test_no_machine_paths_or_private_names() {
    local files hits
    files="$(git -C "$ROOT" ls-files --cached --others --exclude-standard | grep -v '^tests/test_hygiene.sh$')"
    hits="$(cd "$ROOT" && grep -nE '/home/[a-z]|/Users/[A-Za-z]|~/Documents' $files)"
    if [ -n "${DELEGATE_HYGIENE_PATTERNS:-}" ] && [ -f "$DELEGATE_HYGIENE_PATTERNS" ]; then
        hits="$hits$(cd "$ROOT" && grep -niEf "$DELEGATE_HYGIENE_PATTERNS" $files)"
    fi
    assert_eq "$hits" ""
}

test_hook_names_the_installed_script() {
    "$DELEGATE" on >/dev/null
    local out
    out="$(printf '{"session_id":"sess-1","cwd":"%s"}' "$PWD" | "$DELEGATE" hook)"
    assert_contains "$out" "\`$DELEGATE run"
}

test_skill_file_has_frontmatter() {
    head -1 "$ROOT/delegate/SKILL.md" | grep -qx -- "---" || fail "no frontmatter" || return 1
    grep -qx "name: delegate" "$ROOT/delegate/SKILL.md" || fail "name is not delegate"
}
