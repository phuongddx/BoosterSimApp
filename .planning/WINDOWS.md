---
schema_version: 1
open_count: 1
waived_count: 0
fixed_count: 0
total_count: 1
last_updated: 2026-08-29T16:16:41.615Z
---

# Broken Windows Ledger

> Cross-phase defect register. With `workflow.windows_enforce` enabled, `/gsd-ship` blocks while `open_count > 0`.
> Waive with `gsd-tools windows waive <id> "<reason>"` (reason required).
> Mark fixed with `gsd-tools windows fixed <id>`.

| id | phase | kind | file | line | description | status | reason | recorded_at | resolved_at |
|----|-------|------|------|------|-------------|--------|--------|-------------|-------------|
| 1 | 5 | unrun-verify | .planning/phases/05-network-tools/05-01-command-channel-tracer-PLAN.md |  | 05-01 Task 3: live-Simulator airplane smoke (7 steps) pending human verification | open |  | 2026-08-29T16:16:41.615Z |  |

````json
[
  {
    "id": 1,
    "kind": "unrun-verify",
    "phase": "5",
    "file": ".planning/phases/05-network-tools/05-01-command-channel-tracer-PLAN.md",
    "line": null,
    "description": "05-01 Task 3: live-Simulator airplane smoke (7 steps) pending human verification",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-08-29T16:16:41.615Z",
    "resolved_at": null
  }
]
````
