# delegate

A skill for Claude Code and Codex that switches on a mode in which the assistant keeps planning,
reviewing, verifying and committing, and hands every step that writes code or tests to
[opencode](https://opencode.ai) running a cheaper model. The default is DeepSeek V4.1 Flash through
OpenRouter, at high effort.

The assistant writes a brief, the executor reads the code and edits it, and the assistant gets back
a summary of about 20 lines: the executor's report, the changed files, and the result of a check
command the script runs itself. The assistant never reads the executor's iterations, which is where
most of the tokens in an implementation step go.

It works with any planning method or none: it decides who executes a step, not which steps there
are.

## Requirements

- Claude Code or Codex
- opencode, with a provider configured for the model you use (OpenRouter by default)
- `git`, `jq`, `bash`

## Install

```bash
git clone https://github.com/GuidanceStudio/delegate.git
cd delegate
./install.sh
```

Without options it installs for each assistant found on the machine (`~/.claude`, `~/.codex`).
`--target claude`, `--target codex` or `--target all` chooses explicitly.

| What | Claude Code | Codex |
|---|---|---|
| skill | `~/.claude/skills/delegate/` | `~/.codex/skills/delegate/` |
| `UserPromptSubmit` hook | `~/.claude/settings.json` | `~/.codex/hooks.json` |
| opencode agent `delegate-executor` | `~/.config/opencode/agents/` | same |

Codex runs a new hook only after you approve it: open Codex once after installing and approve the
delegate hook, which is listed as "review required" until then.

`./install.sh --check` reports what is installed and what is out of date; `--force` overwrites an
installed copy. Running it twice leaves the settings files unchanged. If opencode is not on `PATH`
the install completes with a warning, and the mode refuses to switch on until it is installed.

## Usage

Ask the assistant to switch delegate mode on. In Claude Code the skill is also `/delegate`, in
Codex `$delegate`.

```
delegate on              this session only
delegate on --project    every session on this repository (writes .delegate.on at the root)
delegate status
delegate off             both levels
```

While the mode is on, the hook adds one line to each prompt saying so, which keeps the mode active
after context compaction.

The session is identified by `CLAUDE_CODE_SESSION_ID` or `CODEX_THREAD_ID`. When one assistant is
started from inside the other, both are set and the Claude Code one is used; use `--project` in
that case.

The script can also be run by hand, from the repository:

```bash
~/.claude/skills/delegate/bin/delegate run --check "pytest -q tests/test_x.py" brief.md
~/.claude/skills/delegate/bin/delegate run --check "pytest -q tests/test_x.py" --resume <session-id> fix.md
```

The exit code of `run` is the check's.

### Sandboxed assistants

The executor calls the model over the network and writes its own state outside the repository. In
Codex's default sandbox both are blocked, so `delegate run` has to be approved to run outside it.
The skill tells the assistant to request that permission.

## Model and effort

```
delegate model                                       current choice and presets
delegate model openrouter/z-ai/glm-5.3-flash         choose a model, effort picked automatically
delegate model openrouter/qwen/qwen3.8-flash max     choose a model and an effort
```

The choice is saved in `~/.config/delegate/config` and applies to every later run. Without an
explicit effort the script picks xhigh when the model offers it, otherwise high.

| Preset | Effort levels |
|---|---|
| `openrouter/deepseek/deepseek-v4.1-flash` (default, high) | low, medium, high, max |
| `openrouter/z-ai/glm-5.3-flash` | low, medium, high, max |
| `openrouter/qwen/qwen3.8-flash` | high, max |

Any other model works if opencode lists it (`opencode models`): its effort levels are read from
opencode before it is saved, and a model opencode does not list is refused until it is added to the
opencode config.

## What the executor may do

The `delegate-executor` agent has the built-in file and shell tools only, so no MCP tool
definitions are sent with its requests. It cannot run `git commit`, `push`, `reset`, `checkout`,
`restore`, `stash`, `clean` or `rebase`, and its instructions keep it to the files the brief names.

## Configuration

| Variable | Default | Effect |
|---|---|---|
| `DELEGATE_MODEL` | from `delegate model` | model for one run, as `provider/model` |
| `DELEGATE_VARIANT` | from `delegate model` | effort for one run |
| `DELEGATE_CONFIG` | `~/.config/delegate/config` | where `delegate model` saves the choice |
| `DELEGATE_MAX_CHARS` | `2000` | longest executor report returned before truncation |
| `DELEGATE_STATE_DIR` | `${XDG_STATE_HOME:-~/.local/state}/delegate` | session flags and full run logs |

## Tests

```bash
tests/run.sh
```

The tests use a fake `opencode` on `PATH` and make no network calls.

## License

MIT
