# DEVPLAN — delegate

## Plan

### Objective

On the user's request, switch the coding assistant into a mode where it keeps
planning, reviewing, verifying and committing, and hands every step that writes
code or tests to opencode running a cheap model (default
`openrouter/deepseek/deepseek-v4.1-flash-1017`). The saving comes from the assistant
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
README.md
```

### Out of scope

- Running more than one executor at a time.
- Any executor other than opencode.
- Editing the user's other skills.

Closed milestones: `DEVPLAN-COMPLETED.md`.

---

## M14: Default to DeepSeek V4.1 Flash 1017 ✅

**Why:** DeepSeek released the 2026-10-17 snapshot of V4.1 Flash
(`deepseek/deepseek-v4.1-flash-1017` on OpenRouter, $0.15/M input and $0.60/M
output on the DeepSeek endpoint). OpenRouter already serves requests for
`deepseek/deepseek-v4.1-flash` pinned to DeepSeek with the 1017 snapshot, so
the default should name the model that actually runs.

**Approach:** the new id replaces `openrouter/deepseek/deepseek-v4.1-flash` as the
default model and as a preset (low, medium, high, max, as opencode reports it).
The opencode config already defines the model; its top-level `model` moves to it.

**Tasks:**
- [x] T1 — tests: every id in `tests/` moves to the new one
- [x] T2 — `delegate/bin/delegate`: `DEFAULT_MODEL`, `PRESET_IDS`, `preset_levels`
- [x] T3 — `delegate/SKILL.md`, `README.md`
- [x] T4 — `~/.config/opencode/opencode.json`: `model` → `openrouter/deepseek/deepseek-v4.1-flash-1017`
- [x] Commit & push; `./install.sh --force`

**Done when:** `tests/run.sh` is green, the installed `delegate model` reports
`openrouter/deepseek/deepseek-v4.1-flash-1017` at `high`, and `opencode.json` names it as `model`.

---

## M15: Run the opencode request check inside a git repository ✅

**Why:** since M12, `delegate run` refuses a folder outside git, and
`tests/check_opencode_request.mjs` runs it in a scratch `repo` folder that is
not a repository, so the check stops before opencode sends a request.

**Approach:** the check runs `git init` in its scratch `repo` folder before the
first `delegate run`.

**Tasks:**
- [x] T1 — `tests/check_opencode_request.mjs`: `git init` the scratch repository
- [x] Commit & push

**Done when:** `node tests/check_opencode_request.mjs` exits 0 and `tests/run.sh` is green.

---

## M16: Each executor run gets its own temporary directory, removed after it ✅

**Why:** opencode extracts a native library of 5.4 MB into the temporary
directory at every `opencode run` and never removes it. On a machine whose
`/tmp` is a 7.5 GB tmpfs with a user quota, 893 copies (about 5 GB) built up
in three days from executor runs and other opencode callers, and the quota ran
out: test suites and the assistant's own output capture failed with "Disk
quota exceeded".

**Approach:** `delegate run` creates a directory with `mktemp -d`, runs
opencode with `TMPDIR` pointing at it, and removes it when opencode exits.
Measured: with `TMPDIR` set, opencode writes the library there and nothing
into `/tmp`.

**Tasks:**
- [x] T1 — test: the executor sees a `TMPDIR` of its own, and what it writes there is gone after the run; red first
- [x] T2 — `delegate/bin/delegate`: the run's own `TMPDIR`, removed after opencode exits
- [x] Commit & push; `./install.sh --force`

**Done when:** `tests/run.sh` is green and a real `delegate run` leaves no new
`-00000000.so` in `/tmp`.

---

## M17: `delegate setup` replaces the installer ✅

**Why:** `install.sh` copied the skill folder, which the rest of the skill
ecosystem now leaves to the user (a `cp -r` from the README), and it forced a
choice between `--force` and a refusal when the copy had drifted. What it did
beyond the copy is real configuration that must stay: the opencode agent file
and the `UserPromptSubmit` hook entry in the host's settings.

**Approach:** the payload configures itself. `delegate setup [--target
claude|codex|all] [--check]` registers the agent and the hook for the installed
copy it runs from, with the same guarantees as the installer: hook JSON
validated before any write (every selected host first), idempotent, an old
hook without its status message upgraded in place, a warning when opencode is
missing, the Codex trust message. It refuses to run from a source checkout
(the hook points at the script's own path), unless `DELEGATE_HOST` is set.
`install.sh`, its skill copy, `--force` and differs logic are removed.

**Tasks:**
- [x] T1 — `delegate/bin/delegate`: `setup` subcommand and usage line
- [x] T2 — tests: `place_skill` and `run_setup` helpers; every installer test ported; new tests for the refusal from an uninstalled source, the default target, a changed agent reported as differs, and `--target all` validating both hook files first
- [x] T3 — remove `install.sh`; `delegate/SKILL.md` and `README.md` describe copy, `setup`, update
- [x] Commit & push

**Done when:** `tests/run.sh` is green and, under a scratch home, copying the
folder, `setup`, `setup --check` and a second `setup` leave the settings file
byte-identical.
