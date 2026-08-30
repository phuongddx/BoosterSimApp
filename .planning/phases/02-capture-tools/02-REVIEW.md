---
phase: 02-capture-tools
reviewed: 2026-08-30T14:42:46Z
depth: standard
files_reviewed: 24
files_reviewed_list:
  - BoosterSimApp/App/AppDelegate.swift
  - BoosterSimApp/Models/ASCFramePreset.swift
  - BoosterSimApp/Models/AppSettings.swift
  - BoosterSimApp/Models/BezelMode.swift
  - BoosterSimApp/Models/CaptureDestination.swift
  - BoosterSimApp/Models/ExportState.swift
  - BoosterSimApp/Models/RecordingState.swift
  - BoosterSimApp/Services/CaptureExporter.swift
  - BoosterSimApp/Services/CaptureSaveRouter.swift
  - BoosterSimApp/Services/CaptureService.swift
  - BoosterSimApp/Services/RecordingService.swift
  - BoosterSimApp/Services/ScreenshotService.swift
  - BoosterSimApp/Services/TouchIndicatorController.swift
  - BoosterSimApp/Utilities/AppLogger.swift
  - BoosterSimApp/Utilities/CaptureCompositor.swift
  - BoosterSimApp/Utilities/CaptureFilename.swift
  - BoosterSimApp/Views/SideWindow/capture/ExportSectionView.swift
  - BoosterSimApp/Views/SideWindow/capture/RecordingSectionView.swift
  - BoosterSimApp/Views/SideWindow/tabs/CaptureTabView.swift
  - BoosterSimApp/Windows/CaptureThumbnailPanel.swift
  - BoosterSimAppTests/CaptureExportConfigTests.swift
  - BoosterSimAppTests/CaptureFramingTests.swift
  - BoosterSimAppTests/CaptureSettingsTests.swift
  - docs/system-architecture.md
findings:
  critical: 2
  warning: 3
  info: 3
  total: 8
status: issues_found
---

# Phase 02: Code Review Report

**Reviewed:** 2026-08-30T14:42:46Z
**Depth:** standard
**Files Reviewed:** 24
**Status:** issues_found

## Summary

All 24 scoped files were read in full and traced cross-module (facade → services → router/UI), with the four phase SUMMARYs and AGENTS.md as context. The documented deviations (seven presets, CaptureFilename/ExportState splits, deprecated sync AVFoundation rationale, A2 fallback pre-wired) were verified against the code and accepted as-is; the compositor geometry engine, filename sanitizer, state machines, filename-only UI strings, and design-token usage in the new views are solid.

Two BLOCKER defects survive, both provable by inspection:

1. **MOV export deletes its own input.** `outputURL(for: .mov)` resolves to the staged source path itself, and `export()` unconditionally removes the output before reading — so `Export as MOV` destroys the only copy of the recording and then fails. The committed test asserts only `pathExtension == "mov"`, so this is invisible to the suite.
2. **A Record→Stop double-tap wedges the recorder permanently.** `start()` publishes `.recording` synchronously but the `SCStream` is only assigned after `startCapture()` returns; a `stop()` landing in that window no-ops (`stream == nil`), the stream keeps recording, and no finish callback ever arrives — the state machine cannot leave `.finishing`.

Both contradict phase-gate evidence at face value: the 02-04 smoke recorded "MOV plays once" (plausibly the staged file, not an export — the export path cannot succeed) and "no temp residue" (CR-01's destructive delete would itself produce that result). Recommend re-verifying MOV export live after the fix.

## Critical Issues

### CR-01: MOV export deletes its own input — staged recording destroyed, export guaranteed to fail
**Resolution:** FIXED (e420435) — `outputURL` now gives same-extension exports a distinct `boostersim-export-*` sibling (capture prefix swapped to export prefix) and both output delete sites guard `output != source`, so the staged .mov can never be its own export target. Regression coverage: the pure mapping test plus a real staged-fixture MOV passthrough round-trip asserting the exported file exists and the staged source survives.

**File:** `BoosterSimApp/Services/CaptureExporter.swift:66-69, 85` (also `:191`)
**Issue:** `outputURL(for:format:)` is `source.deletingPathExtension().appendingPathExtension(mapping.pathExtension)`. The staged recording is already `.mov`, so for `format: .mov` the output URL **equals the source URL**. `export()` then executes `try? FileManager.default.removeItem(at: output)` *before* any export work, destroying the staged recording — the only copy of the user's video. `runVideoExport` proceeds against a nonexistent file: `AVAssetExportSession` fails (or `finish` cleans up), the user gets an export error, and `stagedRecordingURL`/the staged-reveal row keep pointing at a dead path. GIF and MP4 are unaffected (extension changes). This is data loss plus a broken feature, and it also explains a false "no boostersim-capture-* residue" observation in the phase-gate smoke. `CaptureExportConfigTests.outputFilenameExtensionMatchesTheFormat` (`CaptureExportConfigTests.swift:146-152`) asserts only the extension and structurally cannot catch the collision.
**Fix:**
```swift
// In export(): never delete when the mapping would target the source itself,
// and give MOV a distinct deterministic output stem.
nonisolated static func outputURL(for source: URL, format: CaptureExportFormat) -> URL {
    let ext = exportMapping(for: format).pathExtension
    guard ext == source.pathExtension else {
        return source.deletingPathExtension().appendingPathExtension(ext)
    }
    // Same container: the staged file already IS the target format.
    return source.deletingLastPathComponent()
        .appendingPathComponent("boostersim-export-" + source.deletingPathExtension().lastPathComponent + "." + ext)
}
// Belt-and-braces at the delete sites:
if output != source { try? FileManager.default.removeItem(at: output) }
```
Simplest alternative with identical semantics: treat `.mov` as a passthrough copy in `CaptureService.exportRecording` (route the staged file directly — it already matches the target container/codec). Add a regression test: `#expect(CaptureExporter.outputURL(for: testURL, format: .mov) != testURL)`.

### CR-02: Record→Stop race wedges the recorder in `.finishing` forever — live stream never stopped, unbounded disk growth
**Resolution:** FIXED (4f5367e) — once `startCapture()` assigns the stream, a machine already in `.finishing` (stop() raced the spin-up) stops the fresh stream immediately via `stopStream()`, so the finish callback fires and every `.recording` path reaches `.exported`/`.error`. The decision is exposed as pure `RecordingService.stopRacedStartup(_:)` with a state-machine regression test.

**File:** `BoosterSimApp/Services/RecordingService.swift:60-67, 73-78, 113-114, 122-128`
**Issue:** `start()` transitions to `.recording` **synchronously**, but the `SCStream` is assigned to `self.stream` only after `try await stream.startCapture()` returns — and `startStream` first awaits `SCShareableContent.excludingDesktopWindows(...)`, a genuinely slow async hop (tens–hundreds of ms). A `stop()` landing in that window passes the state-machine guard (`.recording → .finishing` is legal), runs `stopStream()` while `self.stream` is still `nil`, so `try await stream?.stopCapture()` is a silent no-op. The in-flight `startStream` then finishes and starts a live recording that nothing will ever stop: the recording-output finish callback never fires, `RecordingState` forbids `.finishing → .recording` and `.finishing → .finishing` (so Record and Stop are both dead — the button is disabled at "Finishing…"), `isWorking` stays true so the stats timer ticks forever while `recordedFileSize` grows without bound. The app is wedged until relaunch, and the held touch-indicator override (`TouchIndicatorState.active`) also never restores (the sink restores only on `.exported`/`.error`). UI-reachable with a fast double-click because the Stop button enables the instant `.recording` publishes.
**Fix:**
```swift
// In startStream, after the stream is finally live:
try await stream.startCapture()
self.stream = stream
self.recordingOutput = output
if state == .finishing {                 // stop() raced the spin-up
    Task { [weak self] in await self?.stopStream() }
}
```
Optionally also expose a `streamActive` published flag and keep Stop disabled until it is true, so the UI never offers a stop that cannot yet act.

## Warnings

### WR-01: Touch-indicator preference leaks permanently when the app quits mid-session
**Resolution:** FIXED (f9a8f51) — `applicationWillTerminate` now calls `captureService.touchIndicatorController.restore()`; restore is a state-machine no-op while no session is open, so quit-without-recording is unaffected.

**File:** `BoosterSimApp/App/AppDelegate.swift:105-108` (with `BoosterSimApp/Services/TouchIndicatorController.swift:96-116`)
**Issue:** `ShowSingleTouches` restore is wired on finish/stream-error/stop, but `applicationWillTerminate` never restores. Quitting BoosterSimApp (Cmd+Q) while a recording is active — or during the CR-02 wedge — leaves `ShowSingleTouches = true` in Simulator's domain indefinitely. The snapshot mechanism cannot self-heal: the next `enable()` snapshots the *polluted* `true` and faithfully restores `true` forever after. This contradicts the docs' "restore on every recording exit path" claim (`docs/system-architecture.md:481`).
**Fix:** Call `captureService.touchIndicatorController.restore()` in `applicationWillTerminate` (guard on an open session — `restore()` is already a no-op when idle), or observe `NSApplication.willTerminateNotification` inside the controller. The hard-crash path remains inherently uncoverable — document it in the cross-app note.

### WR-02: Export-routing copy failure destroys the exported file, violating the retry contract
**Resolution:** FIXED (cb99177) — `persistFile`'s catch no longer removes `sourceURL`; the completed export survives routing/copy failures for retry and the 24h stale-temp sweep bounds its lifetime. The staged recording is still deleted only after `onPersisted` fires.

**File:** `BoosterSimApp/Services/CaptureSaveRouter.swift:147-149`
**Issue:** `persistFile`'s catch path executes `try? FileManager.default.removeItem(at: sourceURL)` when the destination write fails. A transient failure (destination volume full/unmounted, permissions) therefore throws away the completed export — for GIF, an expensive re-encode — even though the staged source survives and the temp sweep would reclaim the export in 24h anyway. `CaptureService.exportRecording`'s contract says routing failures leave artifacts "for retry"; the staged file survives, but the routing step itself should not destroy data it failed to move.
**Fix:** In the catch, keep `sourceURL` (log via `onError` only); delete it solely on the success path (`:142`). The 24h sweep bounds temp lifetime regardless.

### WR-03: Pixel dimensions hardcode a 2× Retina scale instead of the display's scale factor
**Resolution:** FIXED (9ba8aba) — both capture paths size output via `ScreenshotService.backingScale(for:screens:)` (containing screen → main screen → 2× fallback) and `pixelSize(for:scale:)` instead of a hardcoded 2×; the scale-to-pixels mapping is regression-tested at 1×/2×/3× and fractional scales.

**File:** `BoosterSimApp/Services/ScreenshotService.swift:53-54`; `BoosterSimApp/Services/RecordingService.swift:99-100`
**Issue:** Both capture paths set output dimensions as `Int(frame.width) * 2` / `Int(frame.height) * 2`, assuming every display is 2×. On a 1× (non-Retina) display — e.g. a 1080p external monitor — the requested output is double the window's backing store: screenshots/recordings are upscaled (soft/blurry), and recordings waste bitrate on invented pixels. The ASC compositor masks this for screenshots (it rescales onto the preset canvas), but recording resolution is exactly what the user receives.
**Fix:** Resolve the scale from the tracked window's screen: `let scale = Int(window.screen?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2)` and multiply by that, or omit width/height entirely so SCK uses the filter's native size.

## Info

### IN-01: Amber gradient literals duplicate the asset-catalog accent with no shared token
**Resolution:** OPEN — advisory, deferred: a single hardcoded gradient with no observed drift; extracting a color token is worth doing only when a second color consumer appears (avoid a one-use token).

**File:** `BoosterSimApp/Models/BezelMode.swift:39-49`
**Issue:** `CaptureBackground.fillColors` hardcodes CGColor amber values with a comment that they "mirror" the asset accent (`#F59E0B`). `DesignTokens.swift` defines spacing/radii/metrics but no color tokens, so there is nothing to reference — if the accent ever changes, the compositor background silently drifts.
**Fix:** Add a color token (or a `Gradient.amber` constant) to `DesignTokens.swift` and derive `fillColors` from it, keeping the CG-only renderer constraint.

### IN-02: Raw `localizedDescription` reaches the UI contrary to the code's own redaction comment
**Resolution:** OPEN — advisory, deferred: mapping raw descriptions to stable user text changes user-visible failure copy, which should ride the phase's copy decisions (and IN-02's three call sites together), not a review fix.

**File:** `BoosterSimApp/Services/ScreenshotService.swift:17-22, 62`; `BoosterSimApp/Services/CaptureService.swift:234`; `BoosterSimApp/Views/SideWindow/capture/ExportSectionView.swift:105-107`
**Issue:** `CaptureError.userMessage` documents "never raw error strings at the UI" yet `.captureFailed` wraps `error.localizedDescription` verbatim; `performCapture`'s generic catch publishes `error.localizedDescription` to `lastError`; `ExportError.failed` forwards AVAssetReader/session descriptions straight into `ExportSectionView.statusCaption`. AVFoundation/URL errors frequently embed temp-file paths, which conflicts with the project's path-redaction posture (AppLogger deliberately drops the detail in `CaptureExporter.swift:270` — the UI should match).
**Fix:** Map known failures to stable user text and route the raw description to `AppLogger.capture` (private/debug level) instead of the UI.

### IN-03: Desktop folder is created as a side effect of every capture regardless of destination
**Resolution:** OPEN — advisory, deferred: the eager Desktop-folder creation is harmless (empty folder, clipboard-only users); making `suggestedURL` lazy is a small routing-signature refactor better placed with the next capture-routing change.

**File:** `BoosterSimApp/Services/CaptureService.swift:228-230`
**Issue:** `suggestedURL: CaptureDestination.defaultDesktopFolder().appendingPathComponent(filename)` is evaluated eagerly inside `performCapture`, so `~/Desktop/BoosterSim Captures/` is created on every screenshot even when the destination is clipboard/custom/ask. Harmless but surprising: clipboard-only users accumulate an empty folder.
**Fix:** Build the suggested URL inside `route(pngData:)`'s `.desktop` case (or pass a closure), so the folder materializes only when actually written.

---

_Out of scope notes (not counted): performance; the documented 200-LOC residuals (RecordingService 238, CaptureExporter 294) and deprecated sync-AVFoundation usage are accepted documented deviations; the `optionPill`/`captionRow` helper duplication across the three capture views is the documented per-section convention. GitNexus impact tools were unavailable in this runtime; the grep-based blast-radius substitution documented in all four SUMMARYs was applied for this read-only review._

_Reviewed: 2026-08-30T14:42:46Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
