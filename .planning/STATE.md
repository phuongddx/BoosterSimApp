---
gsd_state_version: 1.0
current_phase: 4
current_phase_name: Design Tools
status: executing
stopped_at: Phase 4 context gathered
last_updated: "2026-08-31T11:46:56.400Z"
last_activity: 2026-08-31
last_activity_desc: Phase 3 complete, transitioned to Phase 4
state_head: d176ba9f059380003288108c1ac37931df7ce1de
progress:
  total_phases: 7
  completed_phases: 3
  total_plans: 17
  completed_plans: 13
  percent: 43
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-08-31)

**Core value:** Common simulator tasks (env toggles, cert trust, traffic inspection) complete in ≤2 clicks from the side panel.
**Current focus:** Phase 4 — Design Tools (Phases 2 Capture, 3 App Actions, 5 Network complete + verified)

## Current Position

Phase: 4 (Design Tools) — READY TO EXECUTE
Plan: Not started
Status: Ready to execute
Last activity: 2026-08-31 — Phase 3 complete, transitioned to Phase 4

Progress: [██████████░░░░░░░░░░] 5 of 7 phases complete (1, 2, 3, 5, 6) — next: Phase 4 Design Tools

## Performance Metrics

**Velocity:**

- Total plans completed: 13 (GSD-tracked; Phases 1/6 and the Phase 5 core predate .planning)
- Average duration: 18min
- Total execution time: 72min

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 5 | 4 | - | - |
| 2 | 4 | - | - |
| 3 | 5 | - | - |
**Per-Plan Metrics:**

| Plan | Duration | Tasks | Files |
|------|----------|-------|-------|
| Phase 05 P01 | 37min | 3 tasks | 17 files |
| Phase 05 P02 | 15min | 3 tasks | 11 files |
| Phase 05 P03 | 11min | 2 tasks | 5 files |
| Phase 05 P04 | 9min | 3 tasks | 2 files |
| Phase 02-03 P03 | 10min | 2 tasks | 8 files |
| Phase 03 P01 | 15min | 3 tasks | 13 files |
| Phase 3 P02 | 33min | 2 tasks | 13 files |
| Phase 03 P03 | 38min | 2 tasks | 6 files |
| Phase 03 P04 | 22min | 2 tasks | 11 files |

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
- [Phase 3]: [Phase 3][03-01] clearKeychain composes resetKeychain → reconcileStatus → install — reconcileStatus alone is status-only and would never restore CA trust; pure delegation, no verb duplication
- [Phase 3]: [Phase 3][03-01] SimCtlService seam hardened in place: concurrent pipe drains (>64KB deadlock fix), optional stdin, machine-wide serial queue — publisher signature unchanged, zero call-site edits
- [Phase 3]: [Phase 3][03-01] Scanner fixtures synthesized in temp dirs (nested .app dirs break test-bundle codesign); AppKeychainResetting protocol seam pins the D-02 delegate order on a scripted double
- [Phase 3]: [Phase 3][03-02] D-01 shipped as guided manual grant: honest caption + com.apple.Preferences launch verb + inline steps + Send-as-test-push probe — no control anywhere claims to toggle notification authorization (PrivacyPermissionTests locks notifications out of the enum)
- [Phase 3]: [Phase 3][03-02] DeepLinkService rides the seam: init(simCtl:defaults:) with injectable UserDefaults (default .standard) + internal addToHistory make the isolated-suite persistence contract testable; parse/history behavior byte-for-byte identical, failure captions now carry simctl stderr per plan
- [Phase 3]: [Phase 3][03-02] Push gate before any subprocess: PushPayload.parse (typed empty/invalidJSON/notObject/missingAPS/invalidShape) + validate (4096-byte cap on JSONEncoder output); sendPush logs verb+byte-size+outcome only; explicit bundle arg beats the embedded Simulator Target Bundle key
- [Phase 3]: [Phase 3][03-02] Single-hop verbs (privacy/settings/push) publish dedicated privacyCaption/pushResult instead of riding the 03-01-pinned AppActionOperation machine; shared runVerb helper (30s timeout) — CONVENTIONS async-exemption list shrinks to CaptureService alone
- [Phase 3]: [Phase 3][03-03] Global-domain token pinned as .GlobalPreferences (single named constant) — live read-verified on the booted iOS 26.3 device; applyLocale's optional trailing timezone gives presets ONE relaunch hop; location/clipboard/locale verbs publish dedicated captions + hasSimulatedLocation instead of riding the 03-01-pinned operation machine
- [Phase 3]: [Phase 3][03-04] Defaults editor reads the on-disk plist FILE via get_app_container's data container (export verb silently unsupported in simulator — grep-checked absent) and writes validated spawn-defaults argv; json capsules write as -data <hex> (live-verified vs `defaults help write` + host scratch-domain round-trip) and are read-only in the UI — binary plists corrupt under text editing
- [Phase 3]: [Phase 3][03-04] AppActionCatalog (14 actions / 9 sections, fixed mount order incl. the reused environment + deep-link sections) owns BOTH tab section order and search visibility — empty query renders AppActionSection.allCases through the same section table, so the search wiring cannot drop a section; view carries zero query contains-chains
- [Phase 03]: [Phase 3][03-05] Phase-gate closure pattern (2nd use): docs truth pass (symbols grep-verified vs source) → full-bundle + sha256 pin (git diff vacuous, file untracked) + prohibition greps → blocking-human six-group smoke; requirements stay open at halt, close on approval

### Pending Todos

None yet.

### Blockers/Concerns

- [Phase 6]: StatusBarSectionView, BuildStatsSectionView/BuildChartView, AXTreeView, CameraView are complete but not wired into the side panel tabs (per codebase-summary) — Phases 5 and 2 closed without wiring; pick the wiring point during Phase 3 planning.
- [Phase 5]: TrafficDetailView shows placeholder timing metrics (real PulseMetrics is a v2 candidate, NET-02).
- [Phase 5][follow-up]: throttle pacing formula omits ÷1000 kilo factor (as-shipped: 3G paces 16 s per 1500 B chunk) — rescale candidate, documented in docs/system-architecture.md.
- [infra]: Package.resolved is untracked in git, so the REQ-nfr-03 pin assertion is vacuous at the git level — content stability proven by sha256 across Phases 5+2; track the file so future pin checks are real.
- [infra][pre-existing]: parallel-testing xcodebuild runs intermittently hang (runner instance multiplication) — use -parallel-testing-enabled NO for targeted suites (02-REVIEW-FIX.md).
- [Phase 5][pre-existing]: xcodebuild test exits 65 via post-test app relaunch "Early unexpected exit" flake — reproduced on pristine HEAD (also by orchestrator for ScreenshotTests 4/4); unit suites green. See deferred-items.md.

## Deferred Items

| Category | Item | Status | Deferred At | Milestone |
|----------|------|--------|-------------|-----------|
| Feature | Health Data Generator (BoosterHealth) | Superseded — removed (3b1015f) | 2026-08-29 | v1 (ingest) |
| Enhancement | Pulse Code 8, real PulseMetrics, includePeerToPeer, e2e Connect test | v2 candidates (NET-01…04) | 2026-08-29 | v1 (ingest) |
| Enhancement | Throttle pacing ÷1000 kilo-factor rescale (physical-network fidelity) | Candidate | 2026-08-30 | v2 |
| Enhancement | Photoreal device-bezel asset frames (license decision pending) | v2 candidate (license-clean modes shipped) | 2026-08-30 | v2 |
| Enhancement | SimulatorWindowTracker list-devices spawn → SimCtlService migration | Follow-up (verifier disposition 2026-08-31, accepted pre-existing) | 2026-08-31 | v1.x |

## Session Continuity

Last session: 2026-08-31T10:07:59.333Z
Stopped at: Phase 4 context gathered
Resume file: .planning/phases/04-design-tools/04-CONTEXT.md
