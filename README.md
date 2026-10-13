# delegate

A Claude Code skill that switches on a mode in which Claude keeps planning, reviewing, verifying
and committing, and hands every step that writes code or tests to [opencode](https://opencode.ai)
running a cheaper model. The default is DeepSeek V4.1 Flash through OpenRouter.

Claude writes a brief, the executor reads the code and edits it, and Claude gets back a summary of
about 20 lines: the executor's report, the changed files, and the result of a check command the
script runs itself. Claude never reads the executor's iterations, which is where most of the
tokens in an implementation step go.

It works with any planning method or none: it decides who executes a step, not which steps there
are.

## Requirements

- Claude Code
- opencode, with a provider configured for the model you use (OpenRouter by default)
- `git`, `jq`, `bash`

## Install

```bash
git clone https://github.com/GuidanceStudio/delegate.git
cd delegate
./install.sh
```

This installs three things:

| What | Where |
|---|---|
| the skill | `~/.claude/skills/delegate/` |
| the opencode agent `delegate-executor` | `~/.config/opencode/agents/` |
| a `UserPromptSubmit` hook | `~/.claude/settings.json` |

`./install.sh --check` reports what is installed and what is out of date; `./install.sh --force`
overwrites an installed copy. Running it twice leaves `settings.json` unchanged.

## Usage

In Claude Code:

```
/delegate on              this session only
/delegate on --project    every session on this repository (writes .claude/delegate.on)
/delegate status
/delegate off             both levels
```

While the mode is on, the hook adds one line to each prompt saying so, which keeps the mode active
after context compaction.

The script can also be run by hand:

```bash
~/.claude/skills/delegate/bin/delegate run --check "pytest -q tests/test_x.py" brief.md
~/.claude/skills/delegate/bin/delegate run --check "pytest -q tests/test_x.py" --resume <session-id> fix.md
```

The exit code of `run` is the check's.

## What the executor may do

The `delegate-executor` agent has the built-in file and shell tools only, so no MCP tool
definitions are sent with its requests. It cannot run `git commit`, `push`, `reset`, `checkout`,
`restore`, `stash`, `clean` or `rebase`, and its instructions keep it to the files the brief names.

## Configuration

| Variable | Default | Effect |
|---|---|---|
| `DELEGATE_MODEL` | the agent's `model:` | model for the executor, as `provider/model` |
| `DELEGATE_MAX_CHARS` | `2000` | longest executor report returned before truncation |
| `DELEGATE_STATE_DIR` | `~/.claude/state/delegate` | session flags and full run logs |

To change the default model permanently, edit `model:` in
`~/.config/opencode/agents/delegate-executor.md`.

## Tests

```bash
tests/run.sh
```

The tests use a fake `opencode` on `PATH` and make no network calls.

## License

MIT
