---
name: delegate
description: >-
  Delegate mode: you keep planning, reviewing, verifying and committing, and every step that
  writes code or tests is executed by opencode on a cheaper model (default DeepSeek V4.1 Flash
  via OpenRouter). `/delegate on` switches it on for this session, `/delegate on --project` for
  every session on the repo, `/delegate off` switches it off, `/delegate status` reports it. Use
  when the user asks to save tokens by delegating execution, to "delegate to opencode", or when a
  hook line says delegate mode is ON.
---

# Delegate mode

The script is `bin/delegate` in this skill's directory. Below it is written `delegate`.

## Switching

| Request | Command |
|---|---|
| on for this session | `delegate on` |
| on for every session on this repo | `delegate on --project` |
| off (both levels) | `delegate off` |
| current state | `delegate status` |

While the mode is on, a hook adds one line to every prompt, so the mode survives context
compaction. Report the state to the user in one line after switching.

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

   The check should be the narrowest command that proves the step. When the workflow wants a test
   seen failing first, delegate the test as its own step with `--check "! <test command>"`, then
   the implementation as a second step with the plain test command.

3. Read the output. It holds the executor's report, `git status`, the check's exit code and the
   last lines of its output, the session id, the cost, and the path of the full log. The exit
   code of `delegate run` is the check's: the executor's report alone proves nothing.

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

## Telling the user

In each progress update, say which steps went to the executor and their cost from the output.
