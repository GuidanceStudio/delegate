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

## M10: Integrate the merged-specs branch ✅

**Why:** A collaborator's branch adds host detection from the install path,
`run` failing on executor errors even when the check passes, per-model
OpenRouter endpoint selection (`delegate provider`) and an integration test
against a simulated endpoint. It cannot be merged as is: one commit rebuilt on
the pre-M6 base, plus generated `graphify-out/` files carrying a machine path.

**Approach:** Branch from `main`, take the branch's files except
`graphify-out/` and its devplan files, ignore `graphify-out/`. Then apply the
user's choices: default DeepSeek V4.1 Flash at high with the single
xhigh-else-high rule (no special case for any model); `medium` back in the
DeepSeek and GLM presets; `install.sh` without options installs for the
assistants present, keeping `--target` and `--codex`. Restore the guard that the
agent file pins no model and the SKILL.md instruction to report a new model's
levels. Commit with the collaborator as co-author, merge to `main`.

**Tasks:**
- [x] Import the branch's files without `graphify-out/`; add `.gitignore`
- [x] Apply the three choices (default, presets, install default)
- [x] Restore the agent-file guard and the levels instruction
- [x] Test: full suite green including hygiene, and the `.mjs` integration check passes
- [x] Test: live — a delegated run on the default model, and `delegate provider` set then reset to `auto`
- [x] Reinstall for Claude and Codex, commit, merge to `main`, push

**Done when:** the suite and the integration check are green and `main` holds the integration, pushed.

**Deviations:** The branch had dropped `medium` from the GLM preset; a live GLM run at medium through an explicit `z-ai` endpoint succeeded, so it stays. The integration check assumed the old default and was updated to it.
