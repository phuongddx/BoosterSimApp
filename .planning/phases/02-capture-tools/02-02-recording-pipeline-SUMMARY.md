---
phase: 02-capture-tools
plan: 02
subsystem: capture
tags: [screencapturekit, screcordingoutput, scstream, cfpreferences, showsingletouches, combine, mov, hevc]

# Dependency graph
requires:
  - phase: 02-capture-tools (plan 01)
    provides: CaptureService facade shape, AppSettings capture keys (incl. captureShowTouchIndicators), design tokens, TCC degradation flow
provides:
  - RecordingService — SCStream + SCRecordingOutput direct-to-disk recording of the tracked Simulator window (CMTime(1,120) ceiling, queueDepth 5, audio off, finish-callback finalization with AVAsset duration gate)
  - RecordingState machine (idle/recording/finishing/exported/error) with refused double-start and never-entering stop-on-idle
  - TouchIndicatorController — in-process CFPreferences snapshot/set/restore of Simulator's ShowSingleTouches (single scoped key, kCFNull clear for the was-unset case, injectable TouchPreferencesStore)
  - Capture tab Recording section — Record/Stop toggle, honest "Up to 120 fps" caption, touch-indicator toggle + relaunch hint, live elapsed/size captions, staged-recording reveal row
  - stagedRecordingURL published on the facade — the .mov contract plan 03's export consumes (temp folder, boostersim-capture- prefix)
  - CaptureSaveRouter — destination routing + save panel extracted from the facade (plan 03's export reuses it)
affects: [03-export, 04-phase-gate]

# Actuals (#2632) — pairs with the plan's estimate (42k tokens, low confidence)
actuals:
  tokens: 13008        # chars/4 over the realized diff (ce73312..af73adb): 52,033 chars, 998 insertions / 98 deletions
  tasks: 3             # Tasks 1-2 green; Task 3 blocking-human smoke APPROVED 2026-08-30 (see Checkpoint Resolution)
  commits: 4           # test(RED) x2 + feat(GREEN) x2 (docs commits excluded)

# Tech tracking
tech-stack:
  added: []            # Apple frameworks only (ScreenCaptureKit SCRecordingOutput, CoreFoundation CFPreferences, AVFoundation) — REQ-nfr-03 intact, zero SPM change
  patterns:
    - "SCRecordingOutput attached via addRecordingOutput(_:) — the macOS 15 API has no external sample-handler queue; the output owns its writer queue"
    - "Finalization gated on the recording-output finish callback + AVAsset duration>0 — stopCapture() returning is never 'file ready' (Pitfall 9)"
    - "Foreign-preference writes via injectable TouchPreferencesStore: snapshot-before-write, restore-on-every-exit-path including kCFNull for was-unset (T-02-02)"
    - "Section views observing nested services via @ObservedObject (RecordingSectionView) while control flow goes through the facade"

key-files:
  created:
    - BoosterSimApp/Models/RecordingState.swift
    - BoosterSimApp/Services/RecordingService.swift
    - BoosterSimApp/Services/TouchIndicatorController.swift
    - BoosterSimApp/Services/CaptureSaveRouter.swift
    - BoosterSimApp/Views/SideWindow/capture/RecordingSectionView.swift
    - BoosterSimAppTests/CaptureExportConfigTests.swift
  modified:
    - BoosterSimApp/Services/CaptureService.swift
    - BoosterSimApp/Services/ScreenshotService.swift
    - BoosterSimApp/Utilities/CaptureFilename.swift
    - BoosterSimApp/Views/SideWindow/tabs/CaptureTabView.swift
    - BoosterSimAppTests/CaptureSettingsTests.swift

key-decisions:
  - "Recording output attaches via stream.addRecordingOutput(_:) — verified against Apple docs + compiler; the plan's addStreamOutput(sampleHandlerQueue:) shape does not exist for SCRecordingOutput on the real macOS 15 API"
  - "RecordingState lives in Models/RecordingState.swift (state-machine enums are the Models family per CONVENTIONS) — the service file could not otherwise approach the 200-LOC target"
  - "Destination routing extracted to CaptureSaveRouter — CaptureService was at exactly 200 LOC after plan 01; the router is the seam plan 03's export writes through"
  - "isWorking for TouchIndicatorState includes .active (a session holding a pref override counts as work); double-enable is refused via canTransition, not a boolean flag"
  - "Staged .mov is HEVC in .mov (research A2) — MP4 arrives via plan 03's AVAssetExportSession transcode regardless of container inference"

patterns-established:
  - "In-memory TouchPreferencesStore double with single-shot synchronize failure injection for restore-semantics tests"
  - "Never use `is CFNull` in Swift — it compiles to always-true for CF types; use identity comparison against kCFNull"

requirements-completed: []   # REQ-roadmap-phase2-capture-tools closes at the phase gate (plan 04); smoke approved 2026-08-30

coverage:
  - id: D1
    description: "Recording configuration + state machine — CMTime(1,120) mapping, queueDepth 5 in 3...8, HEVC/.mov/boostersim-capture- output contract, all legal/illegal transitions incl. refused double-start and never-entering stop-on-idle"
    requirement: REQ-roadmap-phase2-capture-tools
    verification:
      - kind: unit
        ref: "BoosterSimAppTests/CaptureExportConfigTests.swift (8 @Test funcs, all passing)"
        status: pass
    human_judgment: false
  - id: D2
    description: "Touch-indicator snapshot/restore machine — triad semantics (true/false/unset-clears via kCFNull), errored-session restore, state machine, production domain/key constants"
    requirement: REQ-roadmap-phase2-capture-tools
    verification:
      - kind: unit
        ref: "BoosterSimAppTests/CaptureSettingsTests.swift (6 new touch-machine @Test funcs, all passing; 13 total in suite)"
        status: pass
    human_judgment: false
  - id: D3
    description: "Live recording on a booted Simulator — playable window-scoped .mov with touch dots, delivered-fps measurement (A3), refusal/no-op semantics in the real UI, ShowSingleTouches restored after the session"
    requirement: REQ-roadmap-phase2-capture-tools
    verification:
      - kind: manual_procedural
        ref: "Task 3 six-step smoke (plan 02-02 how-to-verify) — user-approved 2026-08-30: all 6 steps passed; delivered fps user-verified, exact figure not reported"
        status: pass
    rationale: "Needs TCC Screen Recording grant, WindowServer, real display timing and a booted Simulator — research marks live SCK recording manual-only; not reproducible in unit tests"

# Metrics
duration: 20min
completed: 2026-08-30
status: complete         # Tasks 1-2 green; Task 3 blocking-human smoke approved by user 2026-08-30
---

# Phase 02 Plan 02: Recording Pipeline Summary

**SCRecordingOutput direct-to-disk recording of the Simulator window (CMTime(1,120)/queueDepth 5, finish-callback finalization with duration gate) plus ShowSingleTouches snapshot/set/restore via in-process CFPreferences and the Capture-tab Recording section — Task 3 live smoke approved by the user 2026-08-30**

## Performance

- **Duration:** 20 min (started 2026-08-30T13:01:07Z, stopped 2026-08-30T13:21:29Z)
- **Tasks:** 3 of 3 complete (Task 3 = blocking-human live smoke, APPROVED 2026-08-30)
- **Files modified:** 11 (6 created, 5 modified)
- **Commits:** 4 (test ×2 RED, feat ×2 GREEN)

## Accomplishments

- RecordingService: SCStream with desktopIndependentWindow filter at the tracked CGWindowID, `minimumFrameInterval = CMTime(1,120)`, `queueDepth = 5`, `capturesAudio = false`, output written straight to disk by SCRecordingOutput (HEVC in .mov) — zero frame buffers in app memory (`CMSampleBuffer` appears nowhere in the file)
- RecordingState machine: idle→recording→finishing→exported(URL)/error(String) with illegal transitions trapped in Debug; double start refused, stop-on-idle a no-op, and export reachable ONLY from the recording-output finish callback after an `AVAsset.load(.duration) > 0` gate (Pitfall 9)
- TouchIndicatorController: single scoped key (`ShowSingleTouches` on `com.apple.iphonesimulator`), snapshot-before-write, restore on every exit path including the was-unset `kCFNull` clear; no subprocess anywhere; restore wired in CaptureService on finish, stream error, AND stop (T-02-02)
- Capture tab Recording section: Record/Stop toggle driving the facade, honest "Up to 120 fps" caption (display-bounded delivery, prohibition honored), touch-indicator toggle persisted via AppSettings + relaunch hint (A6), live elapsed/output-size captions from published state, staged-recording row with Reveal in Finder
- Wave 0 tests green: CaptureExportConfigTests 8/8 (new file), CaptureSettingsTests 13/13 (6 new); full unit bundle **73/73, exit 0** (Wave-1 baseline 59 — no regression); Debug build clean

## Checkpoint Resolution

**Task 3 — `checkpoint:human-verify` (gate: blocking-human): APPROVED — user replied "approved" on 2026-08-30 after running all six steps live** (BoosterSimApp running, one booted Simulator):

1. **PASS** — Touch-indicator toggle on; Simulator relaunched when the hint appeared (A6)
2. **PASS** — Record started; ~15 s of taps/drags on the Simulator screen; elapsed/size captions updated live
3. **PASS** — Stop produced a playable staged .mov: duration ≈ 15 s, dimensions = window at 2x, touch dots visible, no panel/desktop content
4. **PASS** — Delivered fps measured acceptable by the user; exact figure not reported ("configured 120, user-verified, exact fps figure not reported") (A3)
5. **PASS** — Double-Record while recording refused (state unchanged); post-Stop Stop a no-op, no error state
6. **PASS** — ShowSingleTouches restored: touch dots gone after relaunching Simulator

**Result:** the SCRecordingOutput direct-to-disk approach is validated end-to-end; the research D2 fallback (AVAssetWriter replan) is not needed. Plan 03 (export) is unblocked.

## Task Commits

1. **Task 1 (auto, tdd):** `b1ef0e3` test — failing CaptureExportConfigTests (RED); `22ca770` feat — RecordingService + RecordingState + CaptureSaveRouter extraction + facade recording API (GREEN)
2. **Task 2 (auto, tdd):** `f16f2b7` test — failing touch-indicator suite in CaptureSettingsTests (RED); `af73adb` feat — TouchIndicatorController + facade wiring + RecordingSectionView (GREEN)
3. **Task 3 (checkpoint:human-verify, gate blocking-human):** APPROVED 2026-08-30 — six-step live smoke, all passed (see Checkpoint Resolution); no code change, docs close-out only

## Verification

- Task 1 `<automated>`: CaptureExportConfigTests — 8/8 passed; Debug build — **BUILD SUCCEEDED**, exit 0
- Task 2 `<automated>`: CaptureSettingsTests + CaptureExportConfigTests — 38 case executions passed, 0 failed; Debug build — **BUILD SUCCEEDED**, exit 0
- House-standard full unit suite (`-only-testing:BoosterSimAppTests -skip-testing:BoosterSimAppUITests`) — **TEST SUCCEEDED, exit 0, 73 cases, 0 failures** (Wave-1 baseline 59 + 8 + 6 new)
- The plan's narrow `-only-testing:<suite>` invocations intermittently exit 65 *after all cases pass* via the documented post-test runner bootstrap flake (STATE.md, pristine-HEAD-proven) — three occurrences this run, every case green; the house-standard invocation above exits 0

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] SCRecordingOutput attaches via `addRecordingOutput(_:)`, not `addStreamOutput(_:type:sampleHandlerQueue:)`**
- **Found during:** Task 1 (first compile)
- **Issue:** The plan (and RESEARCH Pattern 3) assumed the sample's `addStreamOutput` attachment shape with a `sampleHandlerQueue` argument; the compiler rejects SCRecordingOutput there (`does not conform to SCStreamOutput`), and Apple's SCStream page lists a dedicated `addRecordingOutput(_:)` (macOS 15.0+) with no queue parameter.
- **Fix:** `try stream.addRecordingOutput(output)`; the dedicated serial queue property was deleted (it would be dead code). The criterion's intent still holds: `DispatchQueue.main` appears in RecordingService.swift zero times — the output writes to disk on SCK's own queue and delegate callbacks hop to the main actor via the NSObject wrapper + `Task { @MainActor }` pattern (Pitfall 8).
- **Files modified:** BoosterSimApp/Services/RecordingService.swift
- **Verification:** Apple docs fetch (SCStream/addRecordingOutput) + compiler + build green
- **Committed in:** 22ca770

**2. [Rule 3 - Blocking] LOC-forced splits around the 200-line house target**
- **Found during:** Tasks 1-2 (CaptureService and CaptureTabView both sat at exactly 200 LOC after plan 01)
- **Issue:** The plan's additions (recording facade + indicator wiring + recording UI section) cannot fit without splits; the plan's file list named only 6 files.
- **Fix:** (a) destination routing extracted to `Services/CaptureSaveRouter.swift` (the seam plan 03's export reuses); (b) `pngData(from:)` and `CaptureError.userMessage` moved to ScreenshotService; (c) RecordingState split to `Models/RecordingState.swift`; (d) the recording UI section lives in `Views/SideWindow/capture/RecordingSectionView.swift` (network/NetworkConditionsSectionView precedent) — so the Task-2 acceptance greps for "Up to 120 fps" and the toggle bind resolve in that file, not CaptureTabView.swift; (e) shared `captureTarget()` preflight helper deduplicates screenshot/recording entry. Landing sizes: CaptureService 196, CaptureTabView 200, TouchIndicatorController 164, router 87, section 127.
- **Residual:** RecordingService.swift is 238 LOC vs the plan's "under 200" — the state enum already moved out; the remainder (config statics pinned by the committed RED test, stream lifecycle, live-stats timer, two delegate wrappers) does not compress further without fragmenting single-concern code.
- **Files modified:** see key-files
- **Verification:** all behavior preserved — full unit bundle 73/73 incl. every plan-01 suite; build green
- **Committed in:** 22ca770, af73adb

**3. [Rule 1 - Bug] Swift `is CFNull` compiles to always-true**
- **Found during:** Task 2 GREEN (restore-semantics tests failing: store always emptied)
- **Issue:** The in-memory test store's `value is CFNull` sentinel check is compiled as always-true for CF types (compiler warning says as much), so every write took the clear-key path.
- **Fix:** identity comparison `(value as AnyObject) !== (kCFNull as AnyObject)`; production casts (`as? CFPropertyList`) verified at runtime for both NSNumber and kCFNull.
- **Files modified:** BoosterSimAppTests/CaptureSettingsTests.swift
- **Verification:** restore triad + errored-session tests green
- **Committed in:** af73adb

**4. [Rule 3 - Blocking] GitNexus impact analysis substituted**
- **Found during:** Task 1 read_first
- **Issue:** AGENTS.md mandates gitnexus_impact before editing symbols; the MCP tools are unavailable in this runtime (orchestrator note).
- **Fix:** Grep-based blast radius: CaptureService init signatures unchanged (AppDelegate.swift:27 + SideWindowView #Preview untouched, d=1 sites compile — build green); takeScreenshot/route callers only in CaptureTabView/the facade itself; AppSettings untouched this plan.
- **Committed in:** 22ca770

---

**Total deviations:** 4 auto-fixed (2 bugs, 2 blocking/tooling)
**Impact on plan:** No scope creep — every split is either the plan's own 200-LOC rule enforced or a real-API correction the smoke will exercise. All threat-model mitigations wired as planned (T-02-02 single-key snapshot/restore on every exit path; T-02-01 window-scoped filter; T-02-06 no main-queue output handling; T-02-SC zero installs).

## Issues Encountered

- Pre-existing runner flake (STATE.md, pristine-HEAD-proven): narrow `-only-testing` invocations exit 65 *after all cases pass* ("test runner exited with code 0 before establishing connection") — three occurrences this run, zero failed cases; house-standard full-bundle invocation exits 0. Not chased per assignment.
- RecordingService.swift lands 238 LOC (see Deviation 2 residual).

## User Setup Required

Task 3 smoke prerequisites (from plan `user_setup`):
- BoosterSimApp running with Screen Recording granted (System Settings → Privacy & Security → Screen & System Audio Recording)
- One booted iOS Simulator device with its window open; be ready to relaunch it once after enabling touch indicators

## Next Phase Readiness

- Tasks 1-2 green and committed; the staged-.mov contract (temp folder, boostersim-capture- prefix, HEVC/.mov, finish-callback finalization) is stable for plan 03
- Task 3 smoke APPROVED 2026-08-30 — plan 03 (export) is unblocked; the D2 fallback (AVAssetWriter replan) is moot
- Delivered-fps measurement (A3) recorded as user-verified (exact figure not reported); relaunch-hint check (A6) passed

## Self-Check: PASSED

- All 11 key files exist on disk (FOUND ×11)
- Commits b1ef0e3, 22ca770, f16f2b7, af73adb present on main
- Task acceptance criteria mechanically verified (greps + LOC counts + xcodebuild green); Task 3 criteria verified by the user's approved smoke 2026-08-30 (fps user-verified, figure not reported)

---
*Phase: 02-capture-tools — Plan 02 (complete — Task 3 smoke approved 2026-08-30)*
*Completed: 2026-08-30 (Tasks 1-3)*
