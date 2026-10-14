# DEVPLAN — delegate

## Plan

### Objective

On the user's request, switch the coding assistant into a mode where it keeps
planning, reviewing, verifying and committing, and hands every step that writes
code or tests to opencode running a cheap model (default
`openrouter/deepseek/deepseek-v4.1-flash`). The saving comes from the assistant
never reading the files the executor reads, nor its iterations: it writes a
brief, receives a bounded summary plus a check it did not have to trust, and
reviews the diff.

### Approach

One shell entry point, `delegate`, with subcommands `on`, `off`, `status`,
`run` and `hook`. A `UserPromptSubmit` hook re-injects one line per turn while
the mode is on, so it survives context compaction. An opencode agent,
`delegate-executor`, carries the executor's rules and denies commit and push.
The skill text says who executes a step, never which steps a workflow has, so
it works under any planning method or none.

### Layout

```
delegate/            skill payload (installed as-is)
  SKILL.md
  bin/delegate
  opencode/delegate-executor.md
tests/               plain-bash tests, run with tests/run.sh
install.sh
README.md
```

### Out of scope

- Running more than one executor at a time.
- Any executor other than opencode.
- Editing the user's other skills.

Closed milestones: `DEVPLAN-COMPLETED.md`.

---

## M11: Explain the Codex hook and sandbox prompts in the README ✅

**Why:** The README tells Codex users to trust the hook in `/hooks` but not what
the hook does, what happens without trusting it, or which commands ask to leave
the sandbox.

**Tasks:**
- [x] README: what the hook does, the effect of not trusting it, and which commands need sandbox approval in Codex

**Done when:** the README covers the three points and `tests/run.sh` is green.

---

## M12: Refuse to run where the executor's changes cannot be reviewed ✅

**Why:** `project_root` takes the nearest enclosing git repository even when the
current directory is not part of it. From a project folder that a larger
repository leaves untracked, `delegate run` hands opencode the whole enclosing
repository as its working directory, runs the check there, and prints a
`git status` of everything in it; the executor's edits to untracked files never
appear in `git diff`, so the review has nothing to read. `delegate on --project`
from the same folder writes the flag at the enclosing root and switches the mode
on for every project under it. Outside any repository, `run` sends the executor
to the current directory and the `git status` it prints fails.

**Measured:** 14 Oct 2026 — from a folder left untracked by the repository that
holds it, `project_root` resolves to that repository's root. The executor's agent
allows every bash command, so its working directory exposes whatever that root
holds, git-ignored secrets included.

**Approach:** one guard, called by `run` and `on --project` before opencode is
called or a flag is written. It refuses when the current directory is in no git
repository, or when it is below the root and no file under it is tracked
(untracked or ignored). The message names the directory and the enclosing root,
and says what to do: `git init` the project, or run from a directory the
repository tracks. A fresh repository with nothing tracked yet is accepted at its
own root. `on` (session), `off`, `status` and the hook are unchanged.

**Tasks:**
- [x] T1 — tests: `run` and `on --project` refuse outside a repository and in an untracked or an ignored subdirectory, without calling opencode or writing a flag; a fresh repository is accepted at its root; the two existing subdirectory tests track a file in `sub`
- [x] T2 — the guard in `bin/delegate`
- [x] T3 — SKILL.md and README: where `run` and `on --project` work, and what to do when refused
- [x] Commit & push; `./install.sh --force`

**Done when:** `tests/run.sh` is green, and from a folder left untracked by an
enclosing repository the installed `delegate run` and `delegate on --project`
refuse and name that repository's root.

---

## M13: Give the hook a name ✅

**Why:** Codex lists a hook by its `statusMessage` and shows "Unnamed hook" when it
has none, which is what users see when asked to trust the delegate hook.

**Approach:** `install.sh` writes `"statusMessage": "delegate: mode reminder"` on the
delegate hook in both hosts. An existing installation whose delegate hook has no
`statusMessage` gets it on the next install, without a duplicate entry; a second
install leaves the file byte-identical.

**Tasks:**
- [x] T1 — tests: a fresh install names the hook; an existing unnamed delegate hook gets the name without duplication; other hooks are untouched; a second install changes nothing; `--check` reports an unnamed hook as differing
- [x] T2 — `install.sh`
- [x] Commit & push; `./install.sh --force`

**Done when:** `tests/run.sh` is green and `~/.codex/hooks.json` and `~/.claude/settings.json` carry the name.
