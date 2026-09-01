---
schema_version: 1
open_count: 5
waived_count: 0
fixed_count: 1
total_count: 6
last_updated: 2026-09-01T04:11:36.931Z
---

# Broken Windows Ledger

> Cross-phase defect register. With `workflow.windows_enforce` enabled, `/gsd-ship` blocks while `open_count > 0`.
> Waive with `gsd-tools windows waive <id> "<reason>"` (reason required).
> Mark fixed with `gsd-tools windows fixed <id>`.

| id | phase | kind | file | line | description | status | reason | recorded_at | resolved_at |
|----|-------|------|------|------|-------------|--------|--------|-------------|-------------|
| 1 | 5 | unrun-verify | .planning/phases/05-network-tools/05-01-command-channel-tracer-PLAN.md |  | 05-01 Task 3: live-Simulator airplane smoke (7 steps) pending human verification | open |  | 2026-08-29T16:16:41.615Z |  |
| 2 | 5 | unrun-verify | .planning/phases/05-network-tools/05-04-phase-gate-closure-SUMMARY.md |  | Task-3 six-group phase-gate manual smoke pending human approval (airplane/throttle/block/reconcile/certs/clean-state) — closes phase 5 on approval | open |  | 2026-08-29T17:10:33.233Z |  |
| 3 | 2 | unrun-verify | .planning/phases/02-capture-tools/02-01-screenshot-tracer-PLAN.md |  | 02-01 Task 3 blocking-human live smoke (8 steps) pending — needs booted Simulator + TCC cycle; tracked as checkpoint, not silently skipped | open |  | 2026-08-30T12:16:19.153Z |  |
| 4 | 04 | stub | BoosterSimApp/Services/DesignOverlayService.swift | 26 | pickedColor has no producer until 04-03 PixelSamplerService (fake pickColor deleted by plan; Color Picker readout intentionally inert) | fixed |  | 2026-08-31T13:31:37.013Z | 2026-08-31T14:33:21.453Z |
| 5 | 07 | deviation | scripts/build-release.sh |  | Stage-0 pre-build + BUILD_DIR pin: nested iphonesimulator build inside archive fails (PulseObjCHelpers module redefinition, exit 65) | open |  | 2026-09-01T04:11:36.808Z |  |
| 6 | 07 | deviation | docs/deployment-guide.md |  | Dropped stale cd BoosterSimApp line (xcodeproj lives at repo root) | open |  | 2026-09-01T04:11:36.931Z |  |

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
  },
  {
    "id": 2,
    "kind": "unrun-verify",
    "phase": "5",
    "file": ".planning/phases/05-network-tools/05-04-phase-gate-closure-SUMMARY.md",
    "line": null,
    "description": "Task-3 six-group phase-gate manual smoke pending human approval (airplane/throttle/block/reconcile/certs/clean-state) — closes phase 5 on approval",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-08-29T17:10:33.233Z",
    "resolved_at": null
  },
  {
    "id": 3,
    "kind": "unrun-verify",
    "phase": "2",
    "file": ".planning/phases/02-capture-tools/02-01-screenshot-tracer-PLAN.md",
    "line": null,
    "description": "02-01 Task 3 blocking-human live smoke (8 steps) pending — needs booted Simulator + TCC cycle; tracked as checkpoint, not silently skipped",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-08-30T12:16:19.153Z",
    "resolved_at": null
  },
  {
    "id": 4,
    "kind": "stub",
    "phase": "04",
    "file": "BoosterSimApp/Services/DesignOverlayService.swift",
    "line": 26,
    "description": "pickedColor has no producer until 04-03 PixelSamplerService (fake pickColor deleted by plan; Color Picker readout intentionally inert)",
    "status": "fixed",
    "reason": "",
    "recorded_at": "2026-08-31T13:31:37.013Z",
    "resolved_at": "2026-08-31T14:33:21.453Z"
  },
  {
    "id": 5,
    "kind": "deviation",
    "phase": "07",
    "file": "scripts/build-release.sh",
    "line": null,
    "description": "Stage-0 pre-build + BUILD_DIR pin: nested iphonesimulator build inside archive fails (PulseObjCHelpers module redefinition, exit 65)",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-09-01T04:11:36.808Z",
    "resolved_at": null
  },
  {
    "id": 6,
    "kind": "deviation",
    "phase": "07",
    "file": "docs/deployment-guide.md",
    "line": null,
    "description": "Dropped stale cd BoosterSimApp line (xcodeproj lives at repo root)",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-09-01T04:11:36.931Z",
    "resolved_at": null
  }
]
````
