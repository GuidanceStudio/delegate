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

## M6: Refuse to switch on without opencode ✅

**Why:** Without opencode the mode fails only at the first `delegate run`, after
work has started.

**Approach:** `delegate on` (both levels) exits 1 with an install hint when
`opencode` is not on PATH. `install.sh` warns when opencode is missing but
installs anyway.

**Tasks:**
- [x] `on` checks `command -v opencode`
- [x] `install.sh` warning
- [x] Test: unit — `on` and `on --project` refused with PATH lacking opencode, no flag written; install warns and succeeds
- [x] Commit & push

**Done when:** the M6 tests are green.

## M7: Configure model and effort ✅

**Why:** The executor model should be the user's choice (DeepSeek V4.1 Flash,
GLM 5.3 Flash, Qwen 3.8 Flash or any model opencode reaches), and the effort
must not depend on whatever `opencode.json` says on a given machine.

**Approach:** Efforts differ per model, so the three suggested models ship with
their levels built in (DeepSeek V4.1 Flash and GLM 5.3 Flash: low, medium,
high, max; Qwen 3.8 Flash: high, max), and any other model's levels are read
from `opencode models --verbose` before it is saved; a model opencode does not
list is refused with a hint to add it to the opencode config.
`delegate model <provider/model> [effort]` validates and writes
`~/.config/delegate/config` (`DELEGATE_CONFIG` overrides the path); without an
effort it picks xhigh when the model has it, else high, else none, and says
which. Bare `delegate model` prints the current choice and the three presets
with their levels. Resolution in `run`: `DELEGATE_MODEL`/`DELEGATE_VARIANT`,
then the config, then the default DeepSeek V4.1 Flash at high. `run` always
passes `--model`, and `--variant` when there is one; the agent file drops its
`model:` line. SKILL.md gains a short section on choosing the model.

**Tasks:**
- [x] `model` subcommand, presets and config file
- [x] `run` resolves and passes model and variant
- [x] Remove `model:` from the agent file; SKILL.md section
- [x] Test: unit with a fake `opencode models --verbose` — presets, discovered levels, unknown model and unknown effort refused, xhigh-else-high default, precedence env > config > default
- [x] Test: live — a real run with GLM 5.3 Flash completes
- [x] Commit & push

**Done when:** the M7 tests are green and the live run passes.

**Deviations:** Bare `delegate model` printed an empty model when no config existed; it now prints the resolved default (test added).

## M8: Codex as orchestrator ✅

**Why:** The user plans with Codex as well as Claude Code, and wants the same
mode there.

**Approach:** First verify on a real Codex session how a `UserPromptSubmit`
hook's stdout reaches the model and whether `CODEX_THREAD_ID` is visible to
shell commands. Session id resolves from `CLAUDE_CODE_SESSION_ID`, then
`CODEX_THREAD_ID`. State moves to `${XDG_STATE_HOME:-~/.local/state}/delegate`.
`install.sh --target claude|codex|all` installs skill and hook into `~/.claude`
and/or `~/.codex` (`skills/delegate`, `hooks.json`); without `--target` it
installs for the assistants present. SKILL.md is rewritten assistant-neutral.

**Tasks:**
- [x] Verify hook output and session id on real Codex
- [x] Session id from either assistant; neutral state dir
- [x] `install.sh --target`, Codex skill and hooks.json
- [x] SKILL.md assistant-neutral
- [x] Test: unit — install per target into a temp HOME, idempotent, `--check` per target
- [x] Test: live — in a Codex session, `delegate on` makes the hook line appear next turn and a `delegate run` completes
- [x] Commit & push

**Done when:** unit tests green and the live Codex check passes.

**Deviations:** Codex runs a new hook only after the user approves it once ("review required"); install says so. The project flag moved to `.delegate.on`. In Codex's default sandbox `delegate run` fails (no network, no writes outside the workspace), so SKILL.md tells the assistant to request escalation. With one assistant launched inside the other, the session id resolves to Claude's; `--project` covers that case.

## M9: Document and publish ✅

**Why:** Models, effort and Codex support need to be in the README for anyone
installing from `main`.

**Approach:** README sections for model and effort, and for Codex. Reinstall
for both assistants, push `main`.

**Tasks:**
- [x] README
- [x] Reinstall for Claude and Codex, `--check` green for both
- [x] Commit & push

**Done when:** `install.sh --check` is green for both and `main` is pushed.
