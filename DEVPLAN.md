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

---

## M1: Toggle the mode per session or per project ✅

**Why:** The mode has to outlive the turn it was switched on in, and the user
chooses whether it binds one session or every session on a project.

**Approach:** `delegate on` writes `~/.claude/state/delegate/<session-id>`
(session id from `CLAUDE_CODE_SESSION_ID`); `delegate on --project` writes
`.claude/delegate.on` at the git root (cwd outside a repo). `off` removes both,
`status` prints `on (session)`, `on (project)` or `off`. `delegate hook` reads
the hook JSON on stdin (`session_id`, `cwd`) and prints the reminder line only
when either flag is set. State dir overridable with `DELEGATE_STATE_DIR` for
tests.

**Tasks:**
- [x] `bin/delegate` with `on [--project]`, `off`, `status`, `hook`
- [x] Test: unit — on/off/status at both levels, `off` clears both
- [x] Test: unit — hook prints the line only when a flag is set, silent and exit 0 otherwise, including malformed stdin
- [x] Commit & push

**Done when:** `tests/run.sh` is green on the M1 tests.

**Deviations:** No remote exists until M5, so M1–M4 commit locally and push with M5.

## M2: Run the executor and return a bounded summary ✅

**Why:** The token saving only exists if the assistant receives a summary it
can act on and a check result it does not have to take on the executor's word.

**Approach:** `delegate run --check "<cmd>" [--resume <id>] <brief-file>` runs
`opencode run --agent delegate-executor --format json --dir <git root>` with
the brief, writes the full event log to a file under the state dir, then prints:
the executor's final message (truncated to `DELEGATE_MAX_CHARS`, default 2000),
`git diff --stat`, the check's exit code and last 40 lines of output, the
opencode session id for `--resume`, and the log path. Exit code is the check's.
Model from `DELEGATE_MODEL`. The agent file denies `git commit*` and
`git push*` and tells the executor to touch only the files the brief names.

**Tasks:**
- [x] `run` subcommand in `bin/delegate`
- [x] `opencode/delegate-executor.md` agent definition
- [x] Test: unit with a fake `opencode` on PATH — output contract, `--resume` passes the session id, model override
- [x] Test: unit — failing check reports failure and non-zero exit even when the executor claims success
- [x] Commit & push

**Done when:** `tests/run.sh` is green on the M1 and M2 tests.

## M3: Write SKILL.md and README ✅

**Why:** The rules on what to delegate decide whether the mode saves tokens or
spends more of them.

**Approach:** `SKILL.md` covers: switching the mode; what is delegated (any
step that writes code or tests, under whatever workflow is running); what stays
with the assistant (planning, the brief, diff review, verification, plan
bookkeeping, commit, push); the threshold under which a change stays local
because the brief would cost more than the edit; a brief template; resume at
most twice on a red check, then take the work back. README covers install and
usage.

**Tasks:**
- [x] `delegate/SKILL.md`
- [x] `README.md`
- [x] Test: grep over the repo finds no other skill's name, no machine path, no client name
- [x] Commit & push

**Done when:** the grep check returns nothing.

**Deviations:** The hook line now carries the script's absolute path, so the reminder stays usable after compaction. Private names are not listed in the repo: the test reads them from a file named by `DELEGATE_HYGIENE_PATTERNS`, kept outside it.

## M4: Install script ✅

**Why:** Three things land in three places — skill, opencode agent, hook — and
a second run must not register the hook twice.

**Approach:** `install.sh` copies `delegate/` to `~/.claude/skills/delegate`,
the agent to `~/.config/opencode/agents/`, and adds the hook to
`~/.claude/settings.json` with `jq` only when absent. Flags `--check` (report
what is installed and stale) and `--force` (overwrite). `HOME` is honoured, so
tests install into a temp home.

**Tasks:**
- [x] `install.sh` with `--check` and `--force`
- [x] Test: unit — install into a temp `HOME`, run twice, `settings.json` byte-identical and existing hooks preserved
- [x] Commit & push

**Done when:** the idempotency test is green.

## M5: Smoke test against the real executor and publish ✅

**Why:** The fake executor proves the contract, not that the real model
follows the brief and the agent's permissions hold.

**Approach:** Install locally, run one small task in a throwaway repo with real
opencode and the default model, confirm the diff is correct, no commit was
made, and the summary is the only thing returned. Then create the public
`GuidanceStudio/delegate` repo and push `main`.

**Tasks:**
- [x] Smoke run in a throwaway repo
- [x] Create public GitHub repo, push `main`

**Done when:** the smoke run passes and `main` is on the remote.

**Deviations:** The first smoke run hung: `opencode run` reads an inherited open stdin until EOF, so `run` now redirects it from /dev/null (test added). Cost is rounded to 4 decimals. The permission block was probed directly with a no-instructions agent, since the executor refused the git commands before reaching it.
