# DEVPLAN — delegate

## Plan

### Objective

On the user's request, switch the coding assistant into a mode where it keeps
planning, reviewing, verifying and committing, and hands every step that writes
code or tests to opencode running a cheap model (default
`openrouter/z-ai/glm-5.3-flash`, effort `max`, endpoint routing inherited from OpenCode/OpenRouter).
The user can save an explicit OpenRouter endpoint for each model. The saving comes from the assistant
never reading the files the executor reads, nor its iterations: it writes a
brief, receives a bounded summary plus a check it did not have to trust, and
reviews the diff.

### Approach

One shell entry point, `delegate`, with subcommands `on`, `off`, `status`,
`model`, `provider`, `run` and `hook`. A `UserPromptSubmit` hook re-injects one line per turn while
the mode is on, so it survives context compaction. An opencode agent,
`delegate-executor`, carries the executor's rules and denies commit and push.
The skill text says who executes a step, never which steps a workflow has, so
it works under any planning method or none.

`./install.sh --codex` installs the skill and prompt hook for local Codex;
`--target all` installs both hosts and the default remains Claude Code.
Each host keeps its own session state and project flag; both Codex session/thread IDs work.
`delegate model` saves model and effort selection. `delegate provider` saves an OpenRouter
endpoint for the effective model; `auto` removes that preference and preserves personal
OpenCode routing. Explicit endpoints apply per run, without changing global OpenCode defaults.
Activation requires OpenCode;
executor process failures and JSON errors cannot result in a successful run.

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

### Endpoint selection milestones

- [x] M10 — Add `delegate provider [<endpoint>|auto]`. Show the effective model and preference;
  save preferences as `provider.<complete-model-id>=<endpoint>` in the existing config.
  Preserve model, effort, other preferences and unknown keys through atomic writes. Reject
  invalid arguments and explicit endpoints for non-OpenRouter models without changing config.
- [x] M11 — Remove automatic CoreWeave routing. Apply only the effective model's explicit
  endpoint with `order`, `only`, disabled fallback and required parameter support. With `auto`,
  preserve OpenCode options. Show the preference in run summaries; preserve error reporting.
  Existing configs require no migration and inherit routing. Model overrides use their own preference.
- [x] M12 — Document model/effort and all endpoint commands in README, skill instructions and
  CLI help, including Claude/Codex invocation, installed paths and the two provider levels.
  Verify save/show/reset, per-model retention, overrides, invalid input, atomic failure,
  inherited routing, explicit routing and errors with the Bash suite and real OpenCode
  against a local simulated OpenRouter endpoint; make no paid model requests.

Validation: 80 Bash tests passed, plus the real OpenCode/local endpoint integration check.

Closed milestones: `DEVPLAN-COMPLETED.md`.
