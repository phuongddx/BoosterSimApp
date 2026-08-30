---
phase: 02-capture-tools
fixed_at: 2026-08-31T00:05:00+07:00
review_path: .planning/phases/02-capture-tools/02-REVIEW.md
iteration: 1
findings_in_scope: 5
fixed: 5
skipped: 0
status: all_fixed
---

# Phase 02: Code Review Fix Report

**Fixed at:** 2026-08-31T00:05:00+07:00
**Source review:** .planning/phases/02-capture-tools/02-REVIEW.md
**Iteration:** 1

**Summary:**
- Findings in scope: 5 (CR-01, CR-02, WR-01, WR-02, WR-03)
- Fixed: 5
- Skipped: 0
- Info findings (IN-01..IN-03): left OPEN with rationale notes in 02-REVIEW.md, per assignment scope

## Fixed Issues

### CR-01: MOV export deletes its own input

**Files modified:** `BoosterSimApp/Services/CaptureExporter.swift`, `BoosterSimAppTests/CaptureExportConfigTests.swift`
**Commit:** e420435
**Applied fix:** `outputURL(for:format:)` now detects same-extension exports (staged .mov → MOV) and resolves a distinct sibling `boostersim-export-<stamp>.mov` instead of returning the source URL; extension-changing formats keep the original replacement semantics. Belt-and-braces `output != source` guards wrap both output pre-delete sites (`export()` and `runVideoExport`). The staged input is never deleted by the export; deletion remains the router's post-persist retention step. Tests: `movOutputIsADistinctSiblingNeverTheStagedSource` (pure mapping) and `movExportProducesADistinctFileAndLeavesTheStagedSourceIntact` (real two-frame H.264 fixture exported through passthrough — asserts exported file exists AND staged source survives), replacing the old extension-only assertion.

### CR-02: Record→Stop race wedges the recorder in `.finishing` forever

**Files modified:** `BoosterSimApp/Services/RecordingService.swift`, `BoosterSimAppTests/CaptureExportConfigTests.swift`
**Commit:** 4f5367e
**Applied fix:** After `startCapture()` returns and assigns `self.stream`/`self.recordingOutput`, the machine state is re-checked: if stop() raced the spin-up (state already `.finishing`), the fresh stream is stopped immediately (`stopStream()`), which drives the SCRecordingOutput finish callback and the `.finishing → .exported/.error` transition. Every path from `.recording` now reaches the finish callback or a terminal state; no unbounded recording; the touch-pref override is still released by `CaptureService.stopRecording()` on the raced path. The decision is exposed as the pure `RecordingService.stopRacedStartup(_:)` (only `.finishing` owes the late stop) with regression test `stopRacedStartupIsOwedOnlyWhileFinishing`.

### WR-01: Touch-indicator preference leaks on quit

**Files modified:** `BoosterSimApp/App/AppDelegate.swift`
**Commit:** f9a8f51
**Applied fix:** `applicationWillTerminate` calls `captureService.touchIndicatorController.restore()`. `restore()` is guarded by the controller's own state machine — a no-op when no session is open (idle refuses `.restoring`), so quit-without-recording is unaffected; quit mid-session restores the snapshotted `ShowSingleTouches` value (kCFNull when previously unset).

### WR-02: Export-routing copy failure destroys the exported file

**Files modified:** `BoosterSimApp/Services/CaptureSaveRouter.swift`
**Commit:** cb99177
**Applied fix:** `persistFile`'s catch no longer executes `removeItem(at: sourceURL)`. A transient destination failure (volume full/unmounted, permissions) now leaves the completed export in temp for retry — for GIF, avoiding a full re-encode. The 24h stale-temp sweep (`CaptureExporter.sweepStaleCaptures`) bounds temp lifetime; the success path still deletes the source and fires `onPersisted`, preserving the staged-recording retention rule.

### WR-03: Pixel dimensions hardcode a 2× Retina scale

**Files modified:** `BoosterSimApp/Services/ScreenshotService.swift`, `BoosterSimApp/Services/RecordingService.swift`, `BoosterSimAppTests/CaptureExportConfigTests.swift`
**Commit:** 9ba8aba
**Applied fix:** Both capture paths resolve the display scale via `ScreenshotService.backingScale(for:screens:)` — the backing scale of the screen containing the tracked window frame, falling back to the main screen, then 2× — and size output through `pixelSize(for:scale:)` (fractional scales round to whole pixels). On a 1× display the output now matches the window's backing store instead of upscaling. Mapping regression-tested at 1×/2×/3× plus 1.5× rounding.

## Skipped Issues

None — all five in-scope findings were fixed.

## Info Findings (out of scope, left OPEN with rationale in 02-REVIEW.md)

- **IN-01** (gradient color token): deferred — one consumer; token extraction waits for a second.
- **IN-02** (raw localizedDescription at UI): deferred — user-visible copy change belongs with the phase's copy decisions.
- **IN-03** (eager Desktop folder creation): deferred — harmless side effect; lazy suggestedURL rides the next routing change.

## Verification

All gates ran in the **main checkout** (workflow.use_worktrees=false; no worktree was created).

- `xcodebuild -project BoosterSimApp.xcodeproj -scheme BoosterSimApp -destination platform=macOS test -only-testing:BoosterSimAppTests -skip-testing:BoosterSimAppUITests` → exit 0, `** TEST SUCCEEDED **`, **83/83 test cases passed** (baseline 79 + 4 new regression tests; per-suite counts match on-disk `@Test` counts exactly). UI tests skipped per assignment; the pre-existing full-suite exit-65 (UITests) was not chased.
- `xcodebuild -project BoosterSimApp.xcodeproj -scheme BoosterSimApp -configuration Debug build` → exit 0, `** BUILD SUCCEEDED **`.
- Each finding was additionally verified with a targeted `-only-testing:BoosterSimAppTests/CaptureExportConfigTests` run at commit time (exit 0, 18/18).

### Environment note (test-infra, not product)

Two intermittent xcodebuild hazards were diagnosed and worked around during verification; neither is caused by the fixes:
1. **Parallel runner multiplication**: with the scheme's default parallel execution, `test` sometimes spawned two app-runner instances; one exits before connecting ("Early unexpected exit … exited with code 0 before establishing connection") or wedges the session. Pass `-parallel-testing-enabled NO` (as every intermediate bounded run did) if this resurfaces.
2. **Wedged `xcodebuild -runFirstLaunch` helpers**: stray helpers block runs between destination selection and "Testing started"; `pkill -f "xcodebuild -runFirstLaunch"` clears them.
3. The CR-01 round-trip test deliberately does NOT await `CaptureExporter.export`'s completion: that completion rides a `DispatchQueue.main.async` hop the Swift Testing app-host starves mid-suite (verified via unified log: AVFoundation completes the export, the continuation leaks). The test owns the passthrough session and polls `session.status` under a 60s hard bound, so it drives the same real export contract but cannot wedge the suite.

---

_Fixed: 2026-08-31T00:05:00+07:00_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_
