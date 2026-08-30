---
gsd_state_version: 1.0
current_phase: 2
current_phase_name: Capture Tools
status: ready-for-verification
stopped_at: 02-04 phase-gate closure COMPLETE — Task 2 blocking-human six-step smoke user-approved 2026-08-30 (all steps pass; A2 resolved via MP4 passthrough, wired fallback not needed; no boostersim-capture-* residue; docs § Capture Tools matches); plan 4 of 4 done — Phase 2 awaits orchestrator phase tail
last_updated: "2026-08-30T14:28:16.000Z"
last_activity: 2026-08-30
last_activity_desc: 02-04 complete — phase-gate smoke approved; Phase 2 capture tools delivered
state_head: e49ccfb61dd8af34eb5a0a734f46ca0e2d90a3dc
progress:
  total_phases: 7
  completed_phases: 1
  total_plans: 8
  completed_plans: 8
  percent: 14
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-08-30)

**Core value:** Common simulator tasks (env toggles, cert trust, traffic inspection) complete in ≤2 clicks from the side panel.
**Current focus:** Phase 2 — Capture Tools

Phase: 2 (Capture Tools) — READY FOR VERIFICATION
Plan: 4 of 4 complete (02-04 phase-gate closure — human smoke approved 2026-08-30; e49ccfb + dec9aab + closure commit)
Status: ready-for-verification — six-step phase-gate smoke approved by the user (2026-08-30); all four ROADMAP success criteria observed live; orchestrator runs phase tail
Last activity: 2026-08-30 — 02-04 complete (phase-gate smoke approved; docs truth e49ccfb)

Progress: [█░░░░░░░░░] 14%

## Performance Metrics

**Velocity:**

- Total plans completed: 4 (GSD-tracked; Phases 1/6 and the Phase 5 core predate .planning)
- Average duration: 18min
- Total execution time: 72min

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 5 | 4 | - | - |
**Per-Plan Metrics:**

| Plan | Duration | Tasks | Files |
|------|----------|-------|-------|
| Phase 05 P01 | 37min | 3 tasks | 17 files |
| Phase 05 P02 | 15min | 3 tasks | 11 files |
| Phase 05 P03 | 11min | 2 tasks | 5 files |
| Phase 05 P04 | 9min | 3 tasks | 2 files |
| Phase 02-03 P03 | 10min | 2 tasks | 8 files |

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table. Recent decisions affecting current work:

- [ingest]: Pulse/PulseProxy exception to the Apple-only dependency policy (user-resolved 2026-08-29)
- [ingest]: Health Data Generator superseded — removed from repo, no roadmap scope; knowledge in intel/context.md only
- [Phase 5]: Command channel bound to loopback 127.0.0.1 with Bonjour ("_booster-cmd._tcp.") — T-05-01 mitigation; fallback to default interface documented if smoke fails discovery
- [Phase 5]: Framework sources behind #if DEBUG && targetEnvironment(simulator) (macOS app target compiles the same folder — prevents duplicate schema symbols); pbxproj uses synchronized groups so new files need no project edits
- [Phase 5]: Framing decode must copy Data to re-based [UInt8] before offset math (Data-slice startIndex trap, SIGTRAP) — fixed in CommandFrame + framework mirror
- [Phase 5]: Throttle pacing contract = chunkInterval chunkBytes*8/kbps s, completion latencyMs + totalBytes*8/kbps (plan truths #1–2; the Task-1 bullet's "1.6s" tail was an internal arithmetic slip) — rescale note for plan-04 smoke in 05-02 SUMMARY
- [Phase 5]: Pacing constructor rejects invalid specs by returning nil (never traps on wire data); framework degrades to unpaced delivery; enforcement chunkBytes = 1500
- [Phase 5]: 05-01's ea7b024 accidentally deleted BoosterCommandClient's private frame constants — framework target had not compiled since; restored in 3a1bb34 (always build the BoosterSimConnect scheme, the macOS app compiles that folder empty)
- [Phase 5]: BlockRule.matches owns the isEnabled check + field trimming (safe for UI and decode paths); every semantic change mirrors identically into NetworkConditionController's framework copy (schema-sync pair, cross-referenced)
- [Phase 5]: 05-04: docs state the AS-SHIPPED pacing contract truthfully (chunkInterval = chunkBytes*8/kbps s, no ÷1000 kilo factor — 3G paces 16 s per 1500 B chunk, 15 KB ≈ 160 s); documented as a known fidelity gap, smoke judges visibility not physical 3G timing
- [Phase 5]: 05-04 phase-gate automated standard: unit bundle via -only-testing:BoosterSimAppTests -skip-testing:BoosterSimAppUITests (exit 0, 44/44) + both scheme builds + Package.resolved sha256 70386616a707… clean across phase (REQ-nfr-03 closed); unfiltered test exits 65 on pristine HEAD (pre-existing UI-test env issue, documented)
- [Phase 2]: 02-01: Screenshot tracer spine — desktopIndependentWindow filter + SCScreenshotManager, alpha-skipped CG output; CaptureService rewritten as 200-LOC facade; defective scaffold cut over
- [Phase 2]: 02-01: ASC preset enum ships SEVEN cases (plan said 8 — arithmetic slip; all enumerations list 7 verified sizes); raw values are final persistence keys
- [Phase 2]: 02-02: SCRecordingOutput attaches via stream.addRecordingOutput(_:) — no external sample-handler queue on the real macOS 15 API (plan's addStreamOutput shape does not exist for recording outputs); output writes on SCK's own queue, callbacks hop to main via NSObject wrappers
- [Phase 2]: 02-02: export gating = finish callback + AVAsset duration>0 (stopCapture returning is never "file ready"); staged .mov is HEVC in temp with boostersim-capture- prefix — the contract plan 03 consumes
- [Phase 2]: 02-02: TouchIndicatorController = single scoped key ShowSingleTouches with snapshot/restore on every exit path (kCFNull clears the was-unset case); injectable TouchPreferencesStore; never a defaults subprocess
- [Phase 2]: 02-02: LOC splits — CaptureSaveRouter (routing seam plan 03 reuses), RecordingState in Models/, RecordingSectionView as its own file; Swift `is CFNull` compiles always-true — use identity comparison
- [Phase 02-03]: 02-03: Export output names derive from the staged recording stem (no fresh timestamp) — re-running an export deterministically overwrites its prior file; clipboard destination keeps the temp payload as the paste object (24h launch sweep reclaims it)
- [Phase 02-03]: 02-03: Exporter is DispatchQueue+Combine only (zero await/Task tokens) — macOS-15-deprecated sync AVFoundation metadata APIs used deliberately (async-only replacements banned here); A2 fallback (passthrough MP4 → HighestQuality re-encode) pre-wired for the phase gate
- [Phase 02-04]: 02-04: architecture docs carry § Capture Tools (service split + data flow + permissions/degradation + ShowSingleTouches scope/restore + temp lifecycle + honest Up-to-120-fps); stale placeholder/key-list/concurrency lines corrected in the same truth pass
- [Phase 02-04]: 02-04 phase-gate automated standard green — unit bundle 79/79 exit 0, Debug build clean, swiftpm git diff empty; Package.resolved pin proven by sha256 content stability (70386616a707…, identical to Phase 5) since the file remains untracked — track-the-file recommendation stays open
- [Phase 02-04]: 02-04 phase-gate smoke user-approved 2026-08-30 — all six steps pass; A2 resolved via MP4 passthrough (HighestQuality fallback wired but not exercised); delivered-fps figure not separately reported (user-verified acceptable); REQ-roadmap-phase2-capture-tools + REQ-nfr-03 closed on this plan

### Pending Todos

None yet.

### Blockers/Concerns

- [Phase 6]: StatusBarSectionView, BuildStatsSectionView/BuildChartView, AXTreeView, CameraView are complete but not wired into the side panel tabs (per codebase-summary) — Phase 5 closed without wiring; pick the wiring point during Phase 3 planning.
- [Phase 5]: TrafficDetailView shows placeholder timing metrics (real PulseMetrics is a v2 candidate, NET-02).
- [Phase 5][follow-up]: throttle pacing formula omits ÷1000 kilo factor (as-shipped: 3G paces 16 s per 1500 B chunk) — rescale candidate, documented in docs/system-architecture.md.
- [infra]: Package.resolved is untracked in git, so the REQ-nfr-03 pin assertion was vacuous at the git level — track the file so future pin checks are real (verifier note, 05-VERIFICATION.md).
- [Phase 5][pre-existing]: xcodebuild test exits 65 via post-test app relaunch "Early unexpected exit" flake — reproduced on pristine HEAD (also by orchestrator for ScreenshotTests 4/4); unit suites green. See deferred-items.md.

## Deferred Items

| Category | Item | Status | Deferred At | Milestone |
|----------|------|--------|-------------|-----------|
| Feature | Health Data Generator (BoosterHealth) | Superseded — removed (3b1015f) | 2026-08-29 | v1 (ingest) |
| Enhancement | Pulse Code 8, real PulseMetrics, includePeerToPeer, e2e Connect test | v2 candidates (NET-01…04) | 2026-08-29 | v1 (ingest) |
| Enhancement | Throttle pacing ÷1000 kilo-factor rescale (physical-network fidelity) | Candidate | 2026-08-30 | v2 |
Last session: 2026-08-30T14:28:16.000Z
Stopped at: 02-04 complete — phase-gate smoke approved 2026-08-30; ROADMAP 02-04 checked (4/4 plans); awaiting orchestrator phase tail
Resume file: None (plan closed; Phase 2 ready for verification)
