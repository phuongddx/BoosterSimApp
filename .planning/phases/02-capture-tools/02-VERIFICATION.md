---
phase: 02-capture-tools
verified: 2026-08-30T16:50:19Z
status: passed
score: 4/4 must-haves verified
behavior_unverified: 0
overrides_applied: 0
---

# Phase 2: Capture Tools Verification Report

**Phase Goal:** Users capture App-Store-ready screenshots and recordings of the Simulator directly from the side panel
**Verified:** 2026-08-30T16:50:19Z
**Status:** passed
**Re-verification:** No — initial verification (no prior 02-VERIFICATION.md)

**Must-haves source:** ROADMAP.md Phase 2 Success Criteria (the contract), decomposed by the must_haves blocks of plans 02-01…02-04 (frontmatter verified: plans may only add detail — every roadmap SC is covered below). The 5 prohibitions across the plans are verified as negative checks.

**Method note:** All file:line evidence below was read from the live working tree at HEAD (`0a9e662`), which includes all five review-fix commits (e420435, 4f5367e, f9a8f51, cb99177, 9ba8aba — confirmed present on main). Automated evidence (83/83 unit bundle exit 0, Debug build exit 0) and the four human smoke approvals are treated as on-record per the assignment; no UAT was re-opened and no suite was re-run by the verifier.

## Goal Achievement

### Observable Truths

| # | Truth (ROADMAP SC) | Status | Evidence |
|---|-------|--------|----------|
| 1 | User can capture a Simulator screenshot (ScreenCaptureKit) with device bezels, wallpaper/background padding, and App Store Connect framing optimization | ✓ VERIFIED | **Acquisition**: `SCContentFilter(desktopIndependentWindow:)` matched to tracked CGWindowID + Simulator-bundle DEBUG assert — ScreenshotService.swift:53-56; `SCScreenshotManager.captureImage` :70. **ASC framing**: 7 exact presets (1320×2868 … 2048×2732) — ASCFramePreset.swift:17-36, unit-tested `presetPixelSizesMatchAppleSpecExactly` (CaptureFramingTests.swift:36); uniform-scale/center framing, opaque alpha-skipped output — CaptureCompositor.swift:47-70, 84-131. **Bezels**: none/simulatorNative/drawn — BezelMode.swift:17-23, drawn silhouette CaptureCompositor.swift:196-203; "device bezels" judged against the recorded license-clean resolution (02-RESEARCH.md:117 — Simulator-native captures Simulator's own rendered bezel, drawn mode renders a CG silhouette; photoreal asset frames deferred for licensing). **Background padding**: solid/gradient fills + 24pt default padding — BezelMode.swift:30-52, CaptureCompositor.swift:176-194. **Behavior**: human smoke 02-01 (8/8, 2026-08-30 — dims exactly 1320×2868, no alpha, window-only content, A4 held) + 02-04 phase-gate step 1. |
| 2 | User can save captures to Desktop, clipboard, or a custom path, with a floating thumbnail preview after capture | ✓ VERIFIED | Four destinations — CaptureDestination.swift:12-38 (`~/Desktop/BoosterSim Captures/` created on demand); routing switch — CaptureSaveRouter.swift:37-60 (clipboard NSPasteboard only under the user-selected `.clipboard` case); non-modal `NSSavePanel.begin` with persisted directory — CaptureSaveRouter.swift:92-105, 121-136; persistence via 8 `@AppStorage` keys + custom-folder StorageKey — AppSettings.swift:68-76, 104-119 (round-trip unit-tested, CaptureSettingsTests.swift:17-45). Thumbnail: borderless floating NSPanel, 3s auto-hide timer, click reveals in Finder — CaptureThumbnailPanel.swift:26-56, 66-110; shown from the save path — CaptureSaveRouter.swift:112. **Behavior**: human smoke 02-01 steps 6-8 (thumbnail reveal, clipboard paste, custom save, independent timestamped files) + 02-04 steps 4-5. |
| 3 | User can record the Simulator screen (ScreenCaptureKit), including 120 FPS, with touch indicators visible during recordings | ✓ VERIFIED | `SCStream` + `SCRecordingOutput` direct-to-disk (attached via `addRecordingOutput(_:)`, macOS 15 API) — RecordingService.swift:107-113; `minimumFrameInterval = CMTime(1,120)` (config ceiling), `queueDepth = 5`, `capturesAudio = false` — RecordingService.swift:25-27, 42-45, 105-107 (unit-tested `frameIntervalFor120IsOneOver120`); zero frame accumulation (`CMSampleBuffer` absent from the service; output writes on SCK's own queue, callbacks hop via `Task { @MainActor }` wrappers — RecordingService.swift:265-296); finish-callback finalization gated on AVAsset duration > 0 — RecordingService.swift:145-160; state machine refuses double-start / no-ops stop-on-idle — RecordingState.swift:19-46 (unit-tested). Touch indicators: single scoped key `ShowSingleTouches` on `com.apple.iphonesimulator` via in-process CFPreferences, snapshot/restore incl. `kCFNull` for was-unset — TouchIndicatorController.swift:86-88, 99-131; enable-before-stream + restore on finish/error/stop — CaptureService.swift:133-151, 95-110, and quit — AppDelegate.swift:105-113 (WR-01). FPS honesty: "Up to 120 fps — delivered frames follow your display's refresh rate" — RecordingSectionView.swift:84; delivered-fps display-bounded per flagged-assumption A3 resolution, user-verified acceptable (02-02 smoke step 4). **Behavior**: human smoke 02-02 (6/6, 2026-08-30 — playable ~15s .mov with touch dots, double-Record refused, pref restored). |
| 4 | User can export a recording as GIF or video (MP4/MOV) | ✓ VERIFIED | GIF: AVAssetReader (32BGRA) → ImageIO `com.compuserve.gif` with integer-centisecond delays and `kCGImagePropertyGIFLoopCount: 0`, one hoisted CIContext — CaptureExporter.swift:60-75, 159-229 (quantization unit-tested 10→10, 5→20, 15→7). MP4/MOV: `AVAssetExportSession` passthrough with the A2 `HighestQuality` re-encode fallback — CaptureExporter.swift:77-91, 231-274. CR-01 fix verified: same-extension MOV resolves a distinct `boostersim-export-*` sibling and both delete sites guard `output != source` — CaptureExporter.swift:93-108, 205-208; regression-tested by pure mapping **and** a real passthrough round-trip asserting the staged source survives (CaptureExportConfigTests.swift:169, 241). Routing through the shared destination machinery with staged deletion only after the durable write — CaptureService.swift:159-176, CaptureSaveRouter.swift:52-77, 134-155. **Behavior**: 02-04 phase-gate step 3 (GIF loops evenly, MP4 plays via passthrough, MOV) + post-review MOV re-check 2026-08-30 (exported MOV plays with correct duration; same take still exports GIF/MP4 — CR-01 fix live-confirmed). |

**Score:** 4/4 truths verified (0 present, behavior-unverified)

Behavioral evidence basis: SC1-SC4 are behavior-dependent; each rests on (a) code presence + wiring verified by this read, (b) unit tests exercising the pure mappings/state machines (37 capture `@Test` funcs on disk; full bundle 83/83 exit 0 at HEAD, on record), and (c) recorded human smoke approvals covering the live behavior (below). Reliance check (#1955) applied per truth — no coincidental-reliance flags: every load-bearing ordering (enable-before-stream, delete-after-persist, stop-raced-startup check) is code-enforced at the cited lines.

### Prohibitions (negative checks)

| # | MUST NOT | Status | Evidence |
|---|----------|--------|----------|
| 1 | Capture/record any screen content beyond the tracked Simulator window | ✓ NOT VIOLATED | Zero `SCContentFilter(display` initializers in BoosterSimApp/ (grep, 0 hits); both acquisition paths use `desktopIndependentWindow` + Simulator-bundle DEBUG assert (ScreenshotService.swift:49-56; RecordingService.swift:91-98). Human-verified in output: 02-01 step 5 and 02-02 step 3 (no desktop/panel/title-bar pixels). |
| 2 | Retain captured content beyond the user-requested output | ✓ NOT VIOLATED | Screenshots composite in memory (no temp files); staged recording deleted only after the destination write (CaptureService.swift:166-176); partial export output deleted on failure and cancel (CaptureExporter.swift:276-290); routing failures keep files only for retry, bounded by the 24h launch sweep (CaptureSaveRouter.swift:145-155; CaptureExporter.swift `sweepStaleCaptures`, wired AppDelegate.swift:81). Human-verified: 02-04 step 6 — no `boostersim-capture-*` residue after the session. |
| 3 | Bundle third-party device-frame artwork without a verified license | ✓ NOT VIOLATED | No image/PDF/SVG assets beyond accent/icon exist in the target (find, 0 hits); shipped modes are simulatorNative (Simulator's own rendering) and drawn (CoreGraphics) — BezelMode.swift:17-23. Resolution recorded in 02-RESEARCH.md:117. |
| 4 | Mutate any Simulator preference other than ShowSingleTouches / fail to restore the snapshotted value | ✓ NOT VIOLATED | Every read/write goes through `preferenceKey`/`preferenceDomain` constants — the single key `ShowSingleTouches` on `com.apple.iphonesimulator` (TouchIndicatorController.swift:86-88, 116, 143-152); restore covers true/false/unset-incl-`kCFNull` (unit-tested triad + errored-session restore, CaptureSettingsTests.swift:138-185); wired on every exit path incl. quit (AppDelegate.swift:113). No subprocess (`NSTask`/`Process(` absent). Human-verified: 02-02 step 6 (dots gone after restore + relaunch). |
| 5 | Advertise a fixed 120 fps | ✓ NOT VIOLATED | UI caption "Up to 120 fps — delivered frames follow your display's refresh rate" (RecordingSectionView.swift:84); docs state 120 is the configured ceiling, delivery display-bounded (docs/system-architecture.md § Capture Tools). |

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `BoosterSimApp/Services/ScreenshotService.swift` | SCK one-shot window capture | ✓ VERIFIED | 100 LOC; preflight, desktop-independent filter, WR-03 backing-scale sizing, PNG encode |
| `BoosterSimApp/Services/RecordingService.swift` | SCStream + SCRecordingOutput pipeline | ✓ VERIFIED | 298 LOC (documented residual); CMTime(1,120)/queueDepth 5/audio off; finish-callback finalization; CR-02 raced-stop fix |
| `BoosterSimApp/Services/CaptureService.swift` | Sync Combine facade | ✓ VERIFIED | TCC preflight, screenshot/recording/export flows, option mirrors persisted to AppSettings |
| `BoosterSimApp/Services/CaptureExporter.swift` | GIF + MP4/MOV export | ✓ VERIFIED | 311 LOC (documented residual); quantized GIF, passthrough + fallback, sweep; CR-01 fix |
| `BoosterSimApp/Services/CaptureSaveRouter.swift` | Destination routing + save panels | ✓ VERIFIED | 158 LOC; desktop/clipboard/custom/ask for PNG data and files; WR-02 fix |
| `BoosterSimApp/Services/TouchIndicatorController.swift` | ShowSingleTouches snapshot/set/restore | ✓ VERIFIED | 166 LOC; injectable store, state machine, kCFNull restore |
| `BoosterSimApp/Utilities/CaptureCompositor.swift` | Pure CG ASC compositing | ✓ VERIFIED | No SCK/AppKit imports; frame/render, bezel/background, opaque output |
| `BoosterSimApp/Utilities/CaptureFilename.swift` | Sanitized timestamped filenames | ✓ VERIFIED | Allowlist sanitizer (T-02-05) + shared stamp |
| `BoosterSimApp/Models/ASCFramePreset.swift` | ASC pixel table | ✓ VERIFIED | 7 exact presets + deviceFamily |
| `BoosterSimApp/Models/BezelMode.swift` | Bezel + background option models | ✓ VERIFIED | none/simulatorNative/drawn; solid/gradient |
| `BoosterSimApp/Models/CaptureDestination.swift` | Destination model | ✓ VERIFIED | 4 cases + defaultDesktopFolder |
| `BoosterSimApp/Models/RecordingState.swift`, `Models/ExportState.swift` | State machines | ✓ VERIFIED | canTransition/isWorking; illegal transitions trapped |
| `BoosterSimApp/Models/AppSettings.swift` | 8 capture keys + CaptureExportFormat | ✓ VERIFIED | gif/mp4/mov inline at :40-49; keys :68-76; injected-suite rebinding |
| `BoosterSimApp/Windows/CaptureThumbnailPanel.swift` | Floating 3s thumbnail | ✓ VERIFIED | AXHighlightPanel config + 3 divergences; click-to-reveal |
| `BoosterSimApp/Views/SideWindow/tabs/CaptureTabView.swift` + `capture/RecordingSectionView.swift` + `capture/ExportSectionView.swift` | Capture tab UI | ✓ VERIFIED | Permission-degraded setup view, pickers, record/stop, export controls — design tokens only |
| `BoosterSimAppTests/CaptureFramingTests.swift` / `CaptureSettingsTests.swift` / `CaptureExportConfigTests.swift` | Wave 0 suites | ✓ VERIFIED | 8 / 11 / 18 `@Test` funcs on disk, incl. all 4 review-fix regression tests |
| `docs/system-architecture.md` § Capture Tools | Truthful subsystem docs | ✓ VERIFIED | :438-483 — all six required symbols named; permission/degradation, ShowSingleTouches scope+restore, temp lifecycle, fps honesty |

**Artifacts:** 18/18 verified (exists, substantive, wired)

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|----|--------|-------|
| CaptureTabView Capture button | ScreenshotService | `takeScreenshot()` → `Task { await performCapture }` → `capture(windowID:frame:)` | ✓ WIRED | CaptureTabView.swift:100-108 → CaptureService.swift:118-127, 196-221 |
| ScreenshotService | Compositor → destination | `CaptureCompositor.render` → `route(pngData:)` → thumbnail | ✓ WIRED | CaptureService.swift:205-219; CaptureSaveRouter.swift:37-60, 107-116 |
| Record button | SCRecordingOutput | `startRecording()` → `enable()` → `start(windowID:frame:)` → stream + output | ✓ WIRED | RecordingSectionView.swift:44-58 → CaptureService.swift:133-151 → RecordingService.swift:83-98 |
| Finish callback | Export UI | `RecordingState.exported(URL)` → `stagedRecordingURL` → ExportSectionView enabled state | ✓ WIRED | RecordingService.swift:145-160 → CaptureService.swift:95-110 → ExportSectionView.swift:60-86 |
| Export button | Destination + lifecycle | `exportRecording(as:)` → `CaptureExporter.export` → `route(fileAt:)` → `deleteStagedRecording` | ✓ WIRED | CaptureService.swift:159-176; CaptureExporter.swift:113-147; CaptureSaveRouter.swift:52-77 |
| AppDelegate | Tab views | construction → SideWindowController → `.environmentObject(captureService)` → `CaptureTabView()` | ✓ WIRED | AppDelegate.swift:27-34, 51; SideWindowView.swift:66, 97-120 |
| PermissionManager | Degraded UX | preflight/poll → `permissionGranted`/`needsRelaunch` → setup view + quit prompt | ✓ WIRED | CaptureService.swift:92, 112-127; CaptureTabView.swift:151-175 |

**Wiring:** 7/7 connections verified

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------| ------------- | ------ | ------------------ | ------ |
| CaptureTabView preset pills | `ASCFramePreset.allCases` | Exact Apple pixel table (ASCFramePreset.swift:26-36) | Yes | ✓ FLOWING |
| Status/staged/export captions | `lastSavedURL`/`lastError`/`stagedRecordingURL`/`exportState` | Live pipeline @Published state | Yes | ✓ FLOWING |
| Recording live stats | `elapsed`/`outputBytes` | 0.5s timer over `recordingOutput.recordedFileSize` (RecordingService.swift:226-244) | Yes | ✓ FLOWING |
| Thumbnail image | `NSImage(contentsOf: url)` | The actually-saved capture file (CaptureThumbnailPanel.swift:67) | Yes | ✓ FLOWING |
| Filenames | `captureFilename(device:preset:date:)` | Tracked `deviceName` + preset + timestamp, sanitized (CaptureFilename.swift:18-27) | Yes | ✓ FLOWING |

No static fallbacks, hardcoded empty data, or mock sources found on any rendered path.

### Behavioral Spot-Checks

Not re-run by the verifier (assignment: evidence on record, no UAT re-open; project-wide validation is the orchestrator's job). On-record automated evidence at HEAD post-fixes: full unit bundle `-only-testing:BoosterSimAppTests -skip-testing:BoosterSimAppUITests` → exit 0, 83/83 (02-REVIEW-FIX.md § Verification); Debug build → exit 0. Commit presence independently confirmed via `git log` (all five review-fix commits + docs commits on main). Known pre-existing, pristine-HEAD-proven: unfiltered `test` exits 65 (ScreenshotTests env + launch-metrics) — documented in STATE.md, not a phase gap.

### Probe Execution

No `scripts/*/tests/probe-*.sh` probes exist or are declared by this phase's plans — phase probes were the xcodebuild gates above (satisfied on record).

## Requirements Coverage

| Requirement | Source Plan | Status | Evidence |
|-------------|------------|--------|----------|
| **REQ-roadmap-phase2-capture-tools** — screenshot/recording from the side panel: SCK capture, device bezels, wallpaper/background padding, ASC framing, floating thumbnail, Desktop/clipboard/custom save, SCK recording, 120 FPS, touch indicators, GIF export, MP4/MOV export | 02-01…02-04 | ✓ SATISFIED | All four ROADMAP SCs verified (table above). Every clause maps to wired, live-verified behavior. |
| **REQ-nfr-03** — Apple frameworks only (Pulse/PulseProxy exception via BoosterSimConnect) | 02-04 (shared-ID gate) | ✓ SATISFIED | All capture sources import Apple frameworks only (ScreenCaptureKit, CoreGraphics, ImageIO, AVFoundation, Combine, CoreFoundation, AppKit, os); zero package installs; `Package.resolved` sha256 `70386616…4234cf8852` re-verified by this verifier — byte-identical to the Phase 5 pin. Track-the-file recommendation remains open from Phase 5 (informational). |

**Coverage:** 2/2 requirements satisfied

Orphan check: REQUIREMENTS.md maps no additional IDs to Phase 2 that no plan claimed. Plan 02-01 also listed REQ-fr-09 (Phase 1, already Complete) — covered by the destination spine, no orphan.

Note: the REQ-roadmap-phase2-capture-tools checkbox in REQUIREMENTS.md (`- [ ]`, traceability "Pending") is expected to consolidate at `phase.complete` — the orchestrator's immediate next step — and is not a phase gap.

## Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| — | — | None — debt-marker scan (TBD/FIXME/XXX/TODO/HACK/PLACEHOLDER) across all 20 phase source/test files returned zero matches; no empty returns, no console-only handlers, no hardcoded-empty props on rendered paths | ℹ️ | None |

Documented deviations accepted as-is (advisory, non-blocking): RecordingService 238→298 LOC and CaptureExporter 294→311 LOC vs the 200-LOC house target (02-REVIEW.md out-of-scope note; single-concern code); deprecated sync AVFoundation metadata APIs in CaptureExporter used deliberately because the plan bans the async bridge in that unit; review IN-01 (gradient color token), IN-02 (raw localizedDescription at UI), IN-03 (eager Desktop folder creation) left OPEN advisory with rationale.

**Anti-patterns:** 0 found (0 blockers, 0 warnings)

## Human Verification Required

**None pending.** Four human-verification records are on file as SATISFIED (assignment constraint: treated as satisfied, UAT not re-opened):

1. **02-01 screenshot smoke — APPROVED 2026-08-30 (8/8):** panel tracking; denied-permission degradation clean; grant + quit/reopen recovers; 1320×2868 PNG exact dims, no alpha; window-only content (A4 held — no chrome); thumbnail ~3s + Finder reveal; clipboard paste works; custom path + independent double-capture files.
2. **02-02 recording smoke — APPROVED 2026-08-30 (6/6):** playable ~15s .mov at window-2x dims with touch dots and no panel/desktop content; delivered fps user-verified acceptable (A3; exact figure not reported); double-Record refused / stop-on-idle no-op; ShowSingleTouches restored after session + relaunch (A6).
3. **02-04 phase-gate smoke — APPROVED 2026-08-30 (6/6):** all four SCs observed in one session — screenshot dims/alpha, 30s recording playable with dots, GIF loops evenly, MP4 plays (A2 resolved via passthrough), MOV, all three destinations, thumbnail auto-hide, no `boostersim-capture-*` temp residue, docs cross-check.
4. **Post-review MOV re-check — APPROVED 2026-08-30:** after the CR-01 fix, an exported MOV plays with correct duration AND the same recording still exports as GIF/MP4 afterward — criterion-4 evidence restored on the fixed code path.

## Gaps Summary

**No gaps found.** All four ROADMAP success criteria are verified true against the live codebase with file:line evidence, behavioral backup from 37 on-disk capture unit tests (83/83 bundle exit 0 at HEAD) and four recorded human approvals; all 5 prohibitions hold as negative checks; both requirement IDs are satisfied; artifacts exist, are substantive, are wired, and carry real data; no debt markers or blocker anti-patterns. The five review findings (CR-01/CR-02/WR-01..03) are fixed on main with regression tests; the three IN findings remain advisory by documented decision. Phase goal achieved — ready for `phase.complete`.

## Verification Metadata

**Verification approach:** Goal-backward (ROADMAP SCs → code existence/substance/wiring/data-flow → recorded behavioral evidence)
**Must-haves source:** ROADMAP.md Phase 2 Success Criteria, decomposed by PLAN must_haves (4 plans)
**Automated checks:** on record at HEAD — unit bundle 83/83 exit 0, Debug build exit 0, Package.resolved pin re-verified by verifier; commit presence verified (5/5 fix commits)
**Prohibition checks:** 5/5 verified (grep/read + recorded human evidence)
**Human checks required:** 0 pending (4 satisfied on record)

---
*Verified: 2026-08-30T16:50:19Z*
*Verifier: Claude (gsd-verifier)*
