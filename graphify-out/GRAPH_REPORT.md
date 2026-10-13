# Graph Report - delegate  (2026-10-13)

## Corpus Check
- 19 files · ~10,953 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 182 nodes · 212 edges · 19 communities (10 shown, 9 thin omitted)
- Extraction: 100% EXTRACTED · 0% INFERRED · 0% AMBIGUOUS
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `8fedaf50`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- [[_COMMUNITY_test_run.sh|test_run.sh]]
- [[_COMMUNITY_delegate|delegate]]
- [[_COMMUNITY_test_codex.sh|test_codex.sh]]
- [[_COMMUNITY_test_model.sh|test_model.sh]]
- [[_COMMUNITY_delegate|delegate]]
- [[_COMMUNITY_test_install.sh|test_install.sh]]
- [[_COMMUNITY_lib.sh|lib.sh]]
- [[_COMMUNITY_test_provider.sh|test_provider.sh]]
- [[_COMMUNITY_test_toggle.sh|test_toggle.sh]]
- [[_COMMUNITY_Delegate mode|Delegate mode]]
- [[_COMMUNITY_Plan|Plan]]
- [[_COMMUNITY_test_hook.sh|test_hook.sh]]
- [[_COMMUNITY_install.sh|install.sh]]
- [[_COMMUNITY_check_opencode_request.mjs|check_opencode_request.mjs]]
- [[_COMMUNITY_test_prereq.sh|test_prereq.sh]]
- [[_COMMUNITY_test_hygiene.sh|test_hygiene.sh]]
- [[_COMMUNITY_DEVPLAN-COMPLETED|DEVPLAN-COMPLETED.md]]
- [[_COMMUNITY_run.sh|run.sh]]

## God Nodes (most connected - your core abstractions)
1. `fake_opencode()` - 22 edges
2. `delegate` - 9 edges
3. `Delegate mode` - 8 edges
4. `Plan` - 6 edges
5. `install.sh script` - 4 edges
6. `fail()` - 3 edges
7. `codex_install_home()` - 3 edges
8. `choose_target()` - 2 edges
9. `usage()` - 2 edges
10. `select_target()` - 2 edges

## Surprising Connections (you probably didn't know these)
- None detected - all connections are within the same source files.

## Import Cycles
- None detected.

## Communities (19 total, 9 thin omitted)

### Community 0 - "test_run.sh"
Cohesion: 0.15
Nodes (23): fake_opencode(), test_run.sh script, test_auto_routing_preserves_personal_settings_even_for_glm(), test_brief_reaches_the_executor_with_its_agent(), test_check_failure_keeps_its_code_even_when_executor_also_fails(), test_cost_is_rounded(), test_executor_does_not_wait_on_an_open_stdin(), test_executor_failure_is_reported_and_check_still_runs() (+15 more)

### Community 1 - "delegate"
Cohesion: 0.17
Nodes (13): delegate script, cmd_hook(), cmd_model(), cmd_off(), cmd_on(), cmd_provider(), cmd_run(), cmd_status() (+5 more)

### Community 2 - "test_codex.sh"
Cohesion: 0.16
Nodes (4): codex_install_home(), test_codex.sh script, test_codex_install_is_idempotent_and_options_work_in_either_order(), test_codex_installs_skill_agent_and_hook_without_changing_claude()

### Community 4 - "delegate"
Cohesion: 0.18
Nodes (10): Configuration, delegate, Install, License, Model, effort and endpoint, Requirements, Sandboxed assistants, Tests (+2 more)

### Community 6 - "lib.sh"
Cohesion: 0.24
Nodes (4): assert_contains(), assert_eq(), fail(), lib.sh script

### Community 9 - "Delegate mode"
Cohesion: 0.22
Nodes (8): Choosing the executor model, Choosing the OpenRouter endpoint, Delegate mode, Running a step, Switching, Telling the user, What changes while it is on, When the check is red or the diff is wrong

### Community 10 - "Plan"
Cohesion: 0.25
Nodes (7): Approach, DEVPLAN — delegate, Endpoint selection milestones, Layout, Objective, Out of scope, Plan

### Community 12 - "install.sh"
Cohesion: 0.43
Nodes (4): choose_target(), select_target(), install.sh script, usage()

### Community 13 - "check_opencode_request.mjs"
Cohesion: 0.40
Nodes (5): executorRequest(), requests, root, run(), server

## Knowledge Gaps
- **35 isolated node(s):** `root`, `requests`, `server`, `lib.sh script`, `run.sh script` (+30 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **9 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **What connects `root`, `requests`, `server` to the rest of the system?**
  _35 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `test_model.sh` be split into smaller, more focused modules?**
  _Cohesion score 0.14285714285714285 - nodes in this community are weakly interconnected._