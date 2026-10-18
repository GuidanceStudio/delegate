# delegate

A skill for Claude Code and local Codex that switches on a mode in which the assistant keeps
planning, reviewing, verifying
and committing, and hands every step that writes code or tests to [opencode](https://opencode.ai)
running a configurable model. The default is DeepSeek V4.1 Flash 1017 through OpenRouter, with
effort `high`. Endpoint routing follows your OpenCode/OpenRouter settings unless you choose an endpoint
for that model with `delegate provider`.

The assistant writes a brief, the executor reads the code and edits it, and the assistant gets
back a summary of
about 20 lines: the executor's report, the changed files, and the result of a check command the
script runs itself. The assistant never reads the executor's iterations, which is where most of the
tokens in an implementation step go.

It works with any planning method or none: it decides who executes a step, not which steps there
are.

## Requirements

- Claude Code or local Codex with command hooks enabled
- opencode, with a provider configured for the model you use (OpenRouter by default)
- `git`, `jq`, `bash`

## Install

```bash
git clone https://github.com/GuidanceStudio/delegate.git
cd delegate
./install.sh                  # every assistant found: ~/.claude and/or ~/.codex
./install.sh --codex          # Codex only
./install.sh --target claude  # Claude Code only
```

This installs three things:

| What | Claude Code | Codex |
|---|---|---|
| the skill | `~/.claude/skills/delegate/` | `~/.codex/skills/delegate/` |
| the opencode agent `delegate-executor` | `~/.config/opencode/agents/` | `~/.config/opencode/agents/` |
| a `UserPromptSubmit` hook | `~/.claude/settings.json` | `~/.codex/hooks.json` |

`./install.sh --check` reports what is installed and what is out of date; `./install.sh --force`
overwrites an installed copy. Both options combine with `--codex` or `--target` in either order.
`--codex` is an alias for `--target codex`; `--target claude` and `--target all` select Claude
or both assistants. With no target option, it installs for each assistant whose home directory
exists, and stops with a hint when there is none.
Running it twice leaves the host's hook configuration unchanged. Existing hooks and
unrelated settings are preserved. Invalid hook JSON is rejected before installation.
With `--target all`, both hook files are validated before either installation is changed.
If OpenCode is missing, installation completes with a warning and activation refuses to proceed.

For Codex, `CODEX_HOME`, when set, replaces `~/.codex`. After installation, open `/hooks`
in Codex to review and trust the delegate hook; Codex does not run a new hook until you do,
because it runs a command on your machine at every prompt. Reload skills or start a new
session if the skill is not yet listed. This supports local execution; local command hooks
do not run with cloud orchestration.

The hook runs `delegate hook` before each prompt. While the mode is on, it adds one line to
the assistant's context saying so; while it is off, it prints nothing. Without the hook,
`$delegate on` still works, but in a long session Codex may lose track of the mode once its
context is compacted and go back to writing code itself.

## Usage

In Claude Code:

```
/delegate on              this session only
/delegate on --project    every session on this repository (writes .claude/delegate.on)
/delegate status
/delegate off             both levels
/delegate model           show the current model, effort and presets
/delegate model openrouter/z-ai/glm-5.3-flash max
/delegate provider        show the current model's endpoint preference
/delegate provider coreweave/nvfp4
/delegate provider auto   use your OpenCode/OpenRouter routing
```

In Codex:

```
$delegate on              this session only
$delegate on --project    every Codex session on this repository (writes .codex/delegate.on)
$delegate status
$delegate off             both levels
$delegate model           show the current model, effort and presets
$delegate model openrouter/z-ai/glm-5.3-flash max
$delegate provider        show the current model's endpoint preference
$delegate provider coreweave/nvfp4
$delegate provider auto   use your OpenCode/OpenRouter routing
```

Session state and project flags are separate for Claude and Codex. Session mode uses
`CLAUDE_CODE_SESSION_ID` or `CODEX_SESSION_ID` (falling back to `CODEX_THREAD_ID`), respectively.
The installed location identifies the assistant even when both environments are present.
Outside an assistant session,
use `on --project` instead.

`run` and `on --project` work only inside a git repository, at its root or in a
subdirectory holding at least one tracked file. From a folder outside any repository, or one
that an enclosing repository leaves untracked or ignored, they refuse and name the enclosing
root: the executor would otherwise work on the whole enclosing repository, and its edits to
untracked files would not show in `git diff`. Run `git init` in the project, or run from a
directory the repository tracks.

While the mode is on, the hook adds one line to each prompt saying so, which keeps the mode active
after context compaction.

The script can also be run by hand:

```bash
~/.claude/skills/delegate/bin/delegate run --check "pytest -q tests/test_x.py" brief.md
~/.claude/skills/delegate/bin/delegate run --check "pytest -q tests/test_x.py" --resume <session-id> fix.md
# Codex installation:
~/.codex/skills/delegate/bin/delegate run --check "pytest -q tests/test_x.py" brief.md
```

The exit code of `run` is the check's when the check fails. If it passes but the executor fails,
the executor's nonzero code is returned; an OpenCode JSON error with process exit zero returns
`1`. Both the executor and the check must succeed for the run to return zero.

### Sandboxed assistants

Codex's default sandbox (`workspace-write`, no network) blocks writes outside the
repository and network access, so Codex asks for approval to run these commands outside it:

| Command | Why |
|---|---|
| `delegate run` | the executor calls the model over the network and writes run logs to `~/.codex/state/delegate` |
| `$delegate on` (session) | writes the session flag to `~/.codex/state/delegate` |
| `$delegate model`, `$delegate provider` with arguments | write `~/.config/delegate/config` |

Approve them. If `delegate run` is denied, the step fails and Codex has to do it itself.

## Model, effort and endpoint

Use the installed script or ask the assistant via `/delegate model` in Claude or `$delegate model`
in Codex:

```bash
delegate model
delegate model <provider/model> [effort]
delegate model openrouter/z-ai/glm-5.3-flash max
delegate model openrouter/deepseek/deepseek-v4.1-flash-1017 high
delegate model openrouter/qwen/qwen3.8-flash max
```

The selection is saved in `~/.config/delegate/config`. Without an explicit effort every model
gets `xhigh` when available, otherwise `high`, or no variant if neither exists.
Known presets are DeepSeek V4.1 Flash 1017 and GLM 5.3 Flash (low, medium, high, max) and Qwen 3.8
Flash (high, max), through OpenRouter. For other
models, available efforts are read from OpenCode before saving; unknown models and unsupported
explicit efforts are refused.

The `provider/model` identifier chooses the provider OpenCode calls, such as OpenRouter
or a configured direct provider. It does not choose which endpoint serves the model inside
OpenRouter. Use `delegate provider` for that second choice:

```bash
delegate provider                    # show the current model and its endpoint preference
delegate provider coreweave/nvfp4    # save an explicit endpoint for the current model
delegate provider auto               # remove that preference and inherit OpenCode routing
```

Endpoint preferences are saved separately for each complete model identifier. Changing models
keeps their preferences; returning to a model restores its choice. A model with no preference
uses `auto`.
`auto` preserves your personal OpenCode/OpenRouter routing; it does not clear global settings.

An explicit endpoint sets OpenRouter's `order` and `only` to the chosen slug, disables fallback,
and requires parameter support. It overrides conflicting routing for that run and preserves
unrelated options. Explicit endpoints are supported only for OpenRouter models. The command
validates the slug's format without making an API request; an unavailable or incompatible
endpoint produces an execution error, without silently choosing another provider.

Inside Claude Code use `/delegate provider <endpoint>`; inside Codex use
`$delegate provider <endpoint>`. Replace `<endpoint>` with a slug or `auto`, or omit it to
inspect the current preference. The commands above abbreviate the installed script path;
installation does not add `delegate` to `PATH`. To run them directly:

```bash
~/.claude/skills/delegate/bin/delegate model openrouter/z-ai/glm-5.3-flash max
~/.claude/skills/delegate/bin/delegate provider coreweave/nvfp4
~/.claude/skills/delegate/bin/delegate provider
~/.claude/skills/delegate/bin/delegate provider auto
# Codex installation (use $CODEX_HOME/skills/delegate/bin/delegate if CODEX_HOME is set):
~/.codex/skills/delegate/bin/delegate model openrouter/z-ai/glm-5.3-flash max
~/.codex/skills/delegate/bin/delegate provider coreweave/nvfp4
~/.codex/skills/delegate/bin/delegate provider
~/.codex/skills/delegate/bin/delegate provider auto
```

## What the executor may do

The `delegate-executor` agent has the built-in file and shell tools only, so no MCP tool
definitions are sent with its requests. It cannot run `git commit`, `push`, `reset`, `checkout`,
`restore`, `stash`, `clean` or `rebase`, and its instructions keep it to the files the brief names.

## Configuration

| Variable | Default | Effect |
|---|---|---|
| `DELEGATE_MODEL` | saved selection, otherwise DeepSeek V4.1 Flash 1017 | model for one run, as `provider/model` |
| `DELEGATE_VARIANT` | saved selection, otherwise `high` | effort for one run |
| `DELEGATE_CONFIG` | `~/.config/delegate/config` | file where `delegate model` and `delegate provider` save selections |
| `DELEGATE_MAX_CHARS` | `2000` | longest executor report returned before truncation |
| `DELEGATE_STATE_DIR` | `<host home>/state/delegate` | session flags and full run logs; host home is `~/.claude` or `${CODEX_HOME:-$HOME/.codex}` |
| `DELEGATE_HOST` | installed location, then session environment | explicitly selects `codex` or `claude`, useful for running the source script |

The executor agent contains execution rules and permissions. The script selects the model and
effort and applies explicit endpoint routing per run, preserving unrelated
`OPENCODE_CONFIG_CONTENT` options. Preferences use `provider.<provider/model>=<endpoint>`
keys in the same config file; an absent key means `auto`. The file is read as data, never sourced.
Overriding only the model selects that model's default effort rather than borrowing the saved
effort from a different model. The endpoint preference follows the effective model, including
`DELEGATE_MODEL` overrides, without changing the saved model. Run summaries show the preference
as the selected slug or `auto`; `auto` is not the name of the endpoint OpenRouter ultimately uses.
A provider rejection is reported and returns nonzero.

## Tests

```bash
tests/run.sh
```

The tests use a fake `opencode` on `PATH` and make no network calls.
An additional integration check uses the real OpenCode CLI against a local simulated
OpenRouter endpoint to inspect the outgoing request:

```bash
node tests/check_opencode_request.mjs
```

That check verifies inherited routing, explicit per-model endpoints despite conflicting global
options, switching models, resetting to `auto`, and nonzero exit on API errors. It makes no
paid model requests.

## License

MIT
