---
name: delegate
description: >-
  Delegate mode: you keep planning, reviewing, verifying and committing, and every step that
  writes code or tests is executed by opencode on a configurable model (default DeepSeek V4.1
  Flash 1017 at high effort, through OpenRouter). Works with Claude Code and local Codex.
  Switches on for a session or project, off, reports state, and selects the executor model and
  effort and per-model OpenRouter endpoint. Use when the user asks to delegate execution to
  opencode, save tokens that way, switch delegate mode, change its model or endpoint,
  or when a hook line says delegate mode is ON.
---

# Delegate mode

The script is `bin/delegate` in this skill's directory. Below it is written `delegate`.
Use the actual script path when running commands; it need not be on `PATH`.

In Claude Code, invoke `/delegate on`. In Codex, invoke `$delegate on` (and similarly
for `off`, `status`, or `on --project`). `./install.sh` installs for the assistants present (`--codex` for Codex only);
in Codex the `UserPromptSubmit` hook must be trusted through `/hooks` before it runs.
This integration requires local Codex execution with command hooks enabled.

## Switching

| Request | Command |
|---|---|
| on for this session | `delegate on` |
| on for every session on this repo | `delegate on --project` |
| off (both levels) | `delegate off` |
| current state | `delegate status` |

While the mode is on, a hook adds one line to every prompt, so the mode survives context
compaction. Report the state to the user in one line after switching.
Codex uses `CODEX_SESSION_ID` (or `CODEX_THREAD_ID` when absent), `.codex/delegate.on`, and
`${CODEX_HOME:-$HOME/.codex}/state/delegate`; Claude uses `CLAUDE_CODE_SESSION_ID`,
`.claude/delegate.on`, and `~/.claude/state/delegate`. Installed copies identify their
host; `DELEGATE_HOST=codex` or `claude` selects it explicitly when running the source script.
Activation requires OpenCode on `PATH`; otherwise report the missing prerequisite.

## Choosing the executor model

| Request | Command |
|---|---|
| current model, effort and presets | `delegate model` |
| choose a model with its default effort | `delegate model <provider/model>` |
| choose a model and effort | `delegate model <provider/model> <effort>` |

The choice is stored in `${DELEGATE_CONFIG:-$HOME/.config/delegate/config}` and applies to
later runs. The default is `openrouter/deepseek/deepseek-v4.1-flash-1017` at `high`.
Endpoint routing follows the user's OpenCode/OpenRouter configuration unless explicitly selected.
Without an explicit effort, every model gets `xhigh` when it offers it, else `high`, else none.

Presets, with their levels: `openrouter/deepseek/deepseek-v4.1-flash-1017` and
`openrouter/z-ai/glm-5.3-flash` (low, medium, high, max), `openrouter/qwen/qwen3.8-flash`
(high, max). For other models, available efforts are read from `opencode models --verbose`.
When the user names a new model, run `delegate model <id>` without an effort and tell them the
levels it reports and the one it chose.
Unknown models or unsupported explicit efforts are refused before saving the choice.
`DELEGATE_MODEL` and `DELEGATE_VARIANT` override the saved settings for one run.

## Choosing the OpenRouter endpoint

The prefix in `provider/model` chooses the provider OpenCode calls. For models through
OpenRouter, a separate endpoint preference chooses who serves the model inside OpenRouter.

| Request | Command |
|---|---|
| current model and endpoint preference | `delegate provider` |
| choose an endpoint for the current model | `delegate provider <endpoint>` |
| inherit the user's OpenCode/OpenRouter routing | `delegate provider auto` |

For example, `delegate provider coreweave/nvfp4` selects that endpoint exclusively, with
fallback disabled and parameter support required. Use `/delegate provider` in Claude Code
or `$delegate provider` in Codex, with the same arguments.

Preferences are stored in the same config file under `provider.<provider/model>` keys.
Each complete model identifier keeps its own preference across model changes. No preference
means `auto`. `auto` removes only the skill's
preference; it preserves personal OpenCode routing. Explicit endpoints are only supported
for OpenRouter models. Slug format is validated on save; endpoint availability is checked
by the provider at execution time. `DELEGATE_MODEL` selects which model's preference is
shown, saved or applied without changing the saved model.

## What changes while it is on

Delegate mode changes who writes the code. It does not change what the workflow requires: if the
plan or method you are following asks for tests first, a verification, a plan update or a commit
message format, all of that still applies and stays with you.

| Executed by opencode | Kept by you |
|---|---|
| writing or changing code | planning and deciding the next step |
| writing or changing tests | the brief |
| fixing what a red check reports | reviewing the diff |
| | running the verification the workflow requires |
| | editing plans, devplans, changelogs, trackers |
| | commits and pushes |

**Keep a change local** when you already know the exact edit and it is a few lines in a file
already in your context: writing a brief for it costs more than making it. Delegate when the step
needs reading code you have not read, or more than one round of edit and test.

**Never delegate** anything outside the repository, anything touching secrets or credentials,
and git operations other than reading.

## Running a step

1. Write the brief to a file in your scratch directory:

   ```markdown
   ## Goal
   One or two sentences: what must be true when this is done.

   ## Context
   Files to read first, with paths. Conventions that apply (test framework, style, naming).

   ## Change
   Files to modify or create. What changes in each.

   ## Constraints
   What must not change. Files not to touch.

   ## Check
   The command that proves the step, e.g. `pytest tests/test_parser.py -q`.
   ```

   The executor has not seen the conversation. Everything it needs is in the brief or in a file
   the brief names.

2. Run it from the repository:

   ```bash
   delegate run --check "<command>" <brief-file>
   ```

   The executor needs network access and writes state outside the repository. When the
   assistant's sandbox blocks either, request permission to run this command outside it.
   Switching session mode or saving a model or endpoint also needs access to the host's state/config files.

   `run` and `on --project` work only inside a git repository: at its root, or in a
   subdirectory that holds at least one tracked file. Elsewhere (no repository, or a folder
   the enclosing repository leaves untracked or ignored) they refuse and name the directory
   and the enclosing root; tell the user to `git init` the project or run from a directory
   the repository tracks. Do not work around it by running from the enclosing root.

   The check should be the narrowest command that proves the step. When the workflow wants a test
   seen failing first, delegate the test as its own step with `--check "! <test command>"`, then
   the implementation as a second step with the plain test command.

3. Read the output. It holds the executor's report, `git status`, the check's exit code and the
   last lines of its output, the session id, the cost, and the path of the full log. The exit
   code of `delegate run` is the check's when it fails. With a passing check, an executor
   process failure or JSON error still returns nonzero. Success requires both to succeed.

4. Review `git diff` of the files listed. Read the diff, not the whole files.

## When the check is red or the diff is wrong

Resume the same executor session with a short brief that holds only the failure and what to fix:

```bash
delegate run --check "<command>" --resume <session-id> <fix-brief-file>
```

After two resumes on the same step, take the step back and do it yourself, and tell the user that
the step was taken back and why. Do the same when the executor changed files the brief did not
allow: undo the executor's edits to those files by hand, keeping any uncommitted work of the
user's that was there before the run, then continue.

If `delegate run` reports a non-zero executor exit and no changes, opencode itself is not working
(not installed, no provider key, model unavailable). Tell the user and ask whether to switch the
mode off.

If the selected endpoint is unavailable, report the error; do not silently switch
provider. JSON errors matter even if OpenCode itself reports exit code zero.

## Telling the user

In each progress update, say which steps went to the executor and their cost from the output.
