---
phase: "4"
slug: "design-tools"
# status lifecycle: draft (seeded by plan-phase) → validated (set by validate-phase §6)
# audit-milestone §5.5 distinguishes NOT-VALIDATED (draft) from PARTIAL (validated + nyquist_compliant: false) (#2117)
status: draft
nyquist_compliant: false
wave_0_complete: false
created: "2026-08-31"
---

# Phase 4 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Swift Testing (`import Testing`, `@Test`, `#expect`) unit bundle BoosterSimAppTests |
| **Config file** | none — existing Xcode project target |
| **Quick run command** | `xcodebuild -project BoosterSimApp.xcodeproj -scheme BoosterSimApp -destination 'platform=macOS' test -only-testing:BoosterSimAppTests -parallel-testing-enabled NO` |
| **Full suite command** | `xcodebuild -project BoosterSimApp.xcodeproj -scheme BoosterSimApp -destination 'platform=macOS' test -only-testing:BoosterSimAppTests -skip-testing:BoosterSimAppUITests -parallel-testing-enabled NO` |
| **Estimated runtime** | ~120 seconds |

---

## Sampling Rate

- **After every task commit:** Run quick run command scoped to the task's `-only-testing:` suites
- **After every plan wave:** Run full suite command
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 180 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| TBD at plan time | — | — | REQ-roadmap-phase4-design-tools | — | N/A | unit | `MISSING — Wave 0 installs task rows from finalized plans` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] Task rows of this map filled from finalized `04-*-PLAN.md` files (plan-phase planner output)
- [ ] Overlay geometry math unit suites (grid layout, safe-area inset resolution, ruler distance) stubbed per Wave 0

*Existing infrastructure (xcodebuild + Swift Testing bundle) covers the framework; no new framework install needed.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Overlay windows visually track the Simulator window (move/resize/minimize) | REQ-roadmap-phase4-design-tools | Requires live Simulator window + screen observation | Move/resize/minimize the Simulator with grid overlay on; overlay stays aligned, persists on focus loss |
| Magnifier loupe + color sampling against live Simulator pixels | REQ-roadmap-phase4-design-tools | Requires Screen Recording permission + live device content | Arm magnifier over known-color content; sampled hex matches the known value within rounding |
| Design comparison overlay visual alignment | REQ-roadmap-phase4-design-tools | Subjective visual fidelity | Import artboard PNG at correct scale, overlay on the app screen, verify alignment handles/opacity control |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 180s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
