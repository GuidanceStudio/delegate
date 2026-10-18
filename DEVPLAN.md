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
install.sh
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
