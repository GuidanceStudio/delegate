# Guard: `delegate run` and `delegate on --project` must refuse to work where
# the executor's changes could not be reviewed. `on` (session), `off`, `status`
# and `hook` are unchanged.

# Replaces the stub opencode with one that records every invocation in
# $TMP/calls, so a test can prove it was or was not called.
recording_opencode() {
    printf '#!/usr/bin/env bash\necho "$*" >> "%s"\nexit 0\n' "$TMP/calls" > "$TMP/bin/opencode"
    chmod +x "$TMP/bin/opencode"
}

test_run_outside_any_repository_is_refused() {
    recording_opencode
    echo brief > "$TMP/brief.md"
    mkdir "$TMP/norepo" && cd "$TMP/norepo"
    export GIT_CEILING_DIRECTORIES="$TMP"
    local err rc
    err="$("$DELEGATE" run --check true "$TMP/brief.md" 2>&1 >/dev/null)"; rc=$?
    [ "$rc" -ne 0 ] || fail "run accepted outside any repository" || return 1
    [ ! -e "$TMP/calls" ] || fail "opencode was called" || return 1
    assert_contains "$err" "$TMP/norepo"
}

test_run_in_an_untracked_subdirectory_is_refused() {
    recording_opencode
    echo brief > "$TMP/brief.md"
    mkdir -p proj && cd proj
    : > untracked.txt
    local err rc
    err="$("$DELEGATE" run --check true "$TMP/brief.md" 2>&1 >/dev/null)"; rc=$?
    [ "$rc" -ne 0 ] || fail "run accepted in an untracked subdirectory" || return 1
    [ ! -e "$TMP/calls" ] || fail "opencode was called" || return 1
    assert_contains "$err" "$TMP/repo/proj" || return 1
    assert_contains "$err" "$TMP/repo"
}

test_run_in_a_git_ignored_subdirectory_is_refused() {
    recording_opencode
    echo brief > "$TMP/brief.md"
    printf 'ignored/\n' > .gitignore
    mkdir ignored && : > ignored/file.txt
    cd ignored
    local err rc
    err="$("$DELEGATE" run --check true "$TMP/brief.md" 2>&1 >/dev/null)"; rc=$?
    [ "$rc" -ne 0 ] || fail "run accepted in a git-ignored subdirectory" || return 1
    [ ! -e "$TMP/calls" ] || fail "opencode was called"
}

test_on_project_in_an_untracked_subdirectory_is_refused() {
    recording_opencode
    mkdir -p proj && cd proj
    : > untracked.txt
    local err rc
    err="$("$DELEGATE" on --project 2>&1 >/dev/null)"; rc=$?
    [ "$rc" -ne 0 ] || fail "on --project accepted in an untracked subdirectory" || return 1
    [ ! -e "$TMP/repo/.claude/delegate.on" ] || fail "project flag written at the repository root" || return 1
    [ ! -e './.claude/delegate.on' ] || fail "project flag written in the current directory" || return 1
    assert_contains "$err" "$TMP/repo/proj"
}

test_on_project_outside_any_repository_is_refused() {
    recording_opencode
    mkdir "$TMP/norepo" && cd "$TMP/norepo"
    export GIT_CEILING_DIRECTORIES="$TMP"
    local err rc
    err="$("$DELEGATE" on --project 2>&1 >/dev/null)"; rc=$?
    [ "$rc" -ne 0 ] || fail "on --project accepted outside any repository" || return 1
    [ ! -e "$TMP/norepo/.claude/delegate.on" ] || fail "project flag written in the current directory" || return 1
    assert_contains "$err" "$TMP/norepo"
}

test_run_at_the_root_of_a_fresh_repository_is_accepted() {
    recording_opencode
    echo brief > "$TMP/brief.md"
    "$DELEGATE" run --check true "$TMP/brief.md" >/dev/null || fail "run refused at the repository root" || return 1
    [ -e "$TMP/calls" ] || fail "opencode was not called"
}

test_run_in_a_subdirectory_with_a_tracked_file_is_accepted() {
    recording_opencode
    echo brief > "$TMP/brief.md"
    mkdir sub && : > sub/keep && git add sub/keep && cd sub
    "$DELEGATE" run --check true "$TMP/brief.md" >/dev/null || fail "run refused in a subdirectory with a tracked file" || return 1
    [ -e "$TMP/calls" ] || fail "opencode was not called"
}
