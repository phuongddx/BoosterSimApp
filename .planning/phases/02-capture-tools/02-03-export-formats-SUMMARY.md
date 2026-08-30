---
phase: 02-capture-tools
plan: 03
subsystem: capture
tags: [imageio, gif, avassetreader, avassetexportsession, passthrough, combine, dispatchqueue, export]

# Dependency graph
requires:
  - phase: 02-capture-tools (plan 01)
    provides: CaptureExportFormat enum (AppSettings), destination routing machinery, CaptureThumbnailPanel, facade shape
  - phase: 02-capture-tools (plan 02)
    provides: staged .mov contract (temp folder, boostersim-capture- prefix, finish-callback finalization), CaptureSaveRouter seam, RecordingSectionView section precedent
provides:
  - CaptureExporter — GIF (AVAssetReader → ImageIO, integer-centisecond delays, LoopCount 0, one hoisted CIContext) + MP4/MOV (AVAssetExportPresetPassthrough, A2 re-encode fallback)
  - ExportState machine (idle/running/completed/failed/cancelled) + ExportError in Models/
  - Exported pure config surface — gifDelayCentiseconds, gifProperties, exportMapping, outputURL, downsampleScale, sweepStaleCaptures
  - Background-queue export with published progress + lock-guarded cancellation; partial output deleted on every exit path
  - CaptureSaveRouter.route(fileAt:) — desktop/clipboard(file URL)/custom/ask routing for movies with deterministic overwrite
  - CaptureService.exportRecording(as:) facade — staged file deleted only after the destination write; failures/cancel leave it for retry
  - ExportSectionView — format/GIF-width/fps pills, progress + Cancel, completion caption with Reveal, destination caption
  - Launch sweep: CaptureExporter.sweepStaleCaptures() removes boostersim-capture-* temp files older than 24h (T-02-04)
affects: [04-phase-gate, 03-export]

# Actuals (#2632) — pairs with the plan's estimate (32k tokens, low confidence)
actuals:
  tokens: 16900        # chars/4 over the realized diff (43ac46c~1..aa8baa1): ~67.6k chars, 741 insertions
  tasks: 2             # both auto tasks (tdd + plain)
  commits: 3           # test(RED) + feat(GREEN) + feat(Task 2); docs commit excluded

# Tech tracking
tech-stack:
  added: []            # Apple frameworks only (AVFoundation, ImageIO, CoreImage, os) — REQ-nfr-03 intact, zero SPM change
  patterns:
    - "CPU-bound export on DispatchQueue.global(qos: .userInitiated) with Combine-only state hops (SimCtlService pattern) — zero async-bridge tokens in the exporter"
    - "OSAllocatedUnfairLock<Bool> as the Sendable cross-queue cancellation flag"
    - "Deterministic export naming from the staged recording stem — same source + format → same output name → clean overwrite (idempotency truth)"
    - "A2 fallback pre-wired: passthrough MP4 failure re-encodes once via AVAssetExportPresetHighestQuality"

key-files:
  created:
    - BoosterSimApp/Services/CaptureExporter.swift
    - BoosterSimApp/Models/ExportState.swift
    - BoosterSimApp/Views/SideWindow/capture/ExportSectionView.swift
  modified:
    - BoosterSimApp/Services/CaptureService.swift
    - BoosterSimApp/Services/CaptureSaveRouter.swift
    - BoosterSimApp/Views/SideWindow/tabs/CaptureTabView.swift
    - BoosterSimApp/App/AppDelegate.swift
    - BoosterSimAppTests/CaptureExportConfigTests.swift

key-decisions:
  - "Export names derive from the staged recording stem (boostersim-capture-<stamp>.gif/.mp4/.mov) — no fresh timestamp, so re-running an export deterministically replaces its prior output file"
  - "Clipboard destination for videos writes the file URL via NSPasteboard.writeObjects and keeps the temp payload as the paste object — a URL with no file is useless; the 24h launch sweep reclaims it if never pasted"
  - "ExportState/ExportError live in Models/ExportState.swift (RecordingState precedent, 200-LOC house limit) — the plan's artifact list placed them in CaptureExporter.swift"
  - "macOS-15-deprecated sync AVFoundation metadata (tracks(withMediaType:), nominalFrameRate, timeRange, exportAsynchronously/status/error) used deliberately — every modern replacement is async-only and the plan bans the async bridge in this unit"
  - "A2 fallback wired now (passthrough MP4 → HighestQuality re-encode, once) so the plan-04 phase gate expects zero further code changes"

patterns-established:
  - "Section views own their private pill/caption helpers (third occurrence: CaptureTabView, RecordingSectionView, ExportSectionView) — per-section helpers are the tab convention"
  - "Terminal results funnel through one finish() exit path that deletes partial output before handing control to the caller"

requirements-completed: []   # REQ-roadmap-phase2-capture-tools closes at the phase gate (plan 04), consistent with plans 01-02

coverage:
  - id: D1
    description: "Exporter config surface — centisecond quantization (10→10, 5→20, 15→7), loop-forever properties, format→preset/file-type/extension mappings, deterministic output naming, downsample scale bounds"
    requirement: REQ-roadmap-phase2-capture-tools
    verification:
      - kind: unit
        ref: "BoosterSimAppTests/CaptureExportConfigTests.swift (6 new @Test funcs; suite 14/14, all passing)"
        status: pass
    human_judgment: false
  - id: D2
    description: "Live GIF/MP4/MOV export from a staged recording — loops/timing, passthrough transcode plays, thumbnail reveal, destination routing, temp lifecycle close"
    requirement: REQ-roadmap-phase2-capture-tools
    verification:
      - kind: manual_procedural
        ref: "Plan 04 phase-gate smoke steps 3–4 (GIF export → loops, timing correct; MP4/MOV + each destination once)"
        status: unknown
    human_judgment: true
    rationale: "Needs a real staged recording, TCC grant, and WindowServer — research validation architecture marks live export manual-only; plan 02-03's proof is config-level by design"

# Metrics
duration: 10min
completed: 2026-08-30
status: complete
---

# Phase 02 Plan 03: Export Formats Summary

**GIF export via AVAssetReader → ImageIO (integer-centisecond delays, loop-forever, one hoisted CIContext per export) and MP4/MOV via AVAssetExportSession passthrough with the A2 re-encode fallback, routed through the shared destination machinery with staged-file lifecycle closed**

## Performance

- **Duration:** 10 min (started 2026-08-30T14:01:15Z, completed 2026-08-30T14:11:38Z)
- **Tasks:** 2 of 2 complete
- **Files modified:** 8 (3 created, 5 modified)
- **Commits:** 3 (test ×1 RED, feat ×2 GREEN)

## Accomplishments

- CaptureExporter: GIF path decodes the staged .mov with AVAssetReader (32BGRA), decimates samples by `nominalFrameRate / fps`, scales frames to the selected width via one CIContext hoisted before the loop, and encodes through `CGImageDestinationCreateWithURL(…, "com.compuserve.gif", …)` with quantized delays and `kCGImagePropertyGIFLoopCount: 0`
- Video path: `AVAssetExportSession` passthrough to `.mp4` / `.quickTimeMovie`; on passthrough failure for MP4 it re-encodes once with `AVAssetExportPresetHighestQuality` (research A2, wired so the phase gate needs no code changes)
- DispatchQueue + Combine only — zero `await`/`Task {` tokens in the exporter; progress published from main, cancellation via `OSAllocatedUnfairLock`, partial output deleted on failure AND cancel
- Export routing through CaptureSaveRouter: Desktop copy with deterministic overwrite, clipboard writes the file URL, custom/ask non-modal save panel with the format-correct extension; staged recording deleted only after the destination write succeeds
- Export section UI: GIF/MP4/MOV pills bound to the AppSettings keys through facade mirrors, GIF-only 480/640 + 5/10 fps pills, Export disabled without a staged recording, progress + Cancel while running, completion caption with Reveal
- Launch sweep wired in `applicationDidFinishLaunching` (T-02-04); Wave-0 suites green: CaptureExportConfigTests 14/14, full unit bundle **79/79 exit 0** (73 baseline + 6 new — no regression); Debug build clean

## Task Commits

1. **Task 1 (auto, tdd):** `43ac46c` test — failing GIF/export mapping suites (RED); `21b656d` feat — CaptureExporter + Models/ExportState + launch sweep (GREEN)
2. **Task 2 (auto):** `aa8baa1` feat — export facade routing + ExportSectionView + CaptureTabView mount

**Plan metadata:** (docs close-out commit follows)

## Verification

- Task 1 `<automated>`: CaptureExportConfigTests — all 14 cases passed (6 new green); Debug build — **BUILD SUCCEEDED**, exit 0
- Task 2 `<automated>`: three capture suites (ExportConfig + Settings + Framing) — all cases passed, 0 failures; Debug build — **BUILD SUCCEEDED**, exit 0
- House-standard full unit bundle (`-only-testing:BoosterSimAppTests -skip-testing:BoosterSimAppUITests`) — **TEST SUCCEEDED, exit 0, 79 cases, 0 failures**
- The plan's narrow `-only-testing` invocations intermittently exit 65 *after all cases pass* via the documented post-test runner bootstrap flake (STATE.md, pristine-HEAD-proven) — reproduced twice this run with every case green; house-standard invocation exits 0
- Acceptance criteria verified mechanically: required symbols present; `CIContext()` constructed exactly once outside the frame loop; `await`/`Task {` tokens occur zero times; AppDelegate calls `sweepStaleCaptures`

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Export section lives in its own file, not inline in CaptureTabView**
- **Found during:** Task 2
- **Issue:** CaptureTabView sits at exactly 200 LOC after plan 02; the export section (~90 LOC) cannot fit. Plan's file list named only CaptureService + CaptureTabView.
- **Fix:** `Views/SideWindow/capture/ExportSectionView.swift` (RecordingSectionView precedent); mounted by CaptureTabView, observing `captureService.exporter` via @ObservedObject. The three export AppSettings keys bind through facade mirrors (exportFormat/gifSize/gifFPS) synced to `captureExportFormat`/`captureGIFSize`/`captureGIFFps` — so the Task-2 acceptance bindings resolve in the section file CaptureTabView mounts, the same documented pattern plan 02-02 used. CaptureTabView lands 201 LOC (one mount line).
- **Files modified:** ExportSectionView.swift (new), CaptureTabView.swift, CaptureService.swift
- **Verification:** Debug build green; GIF-only pickers conditional on format; Export disabled without staged recording (grep-verified)
- **Committed in:** aa8baa1

**2. [Rule 3 - Blocking] ExportState + ExportError extracted to Models/ExportState.swift**
- **Found during:** Task 1 (GREEN)
- **Issue:** Plan's artifact list places them in CaptureExporter.swift, but with them in-file the service cannot approach the 200-LOC target.
- **Fix:** RecordingState precedent — state-machine enums are the Models family. CaptureExporter.swift lands 294 LOC (residual, RecordingService-238 class); CaptureService 237 after the facade.
- **Verification:** Full bundle green
- **Committed in:** 21b656d

**3. [Rule 1 - Bug] Real-API corrections inside the exporter**
- **Found during:** Task 1 (first compiles)
- **Issue:** (a) `AVAssetReader.add(_:)` is `throws` in this SDK, not Bool-returning; (b) `nominalFrameRate` is `Float` (Double math needed explicit conversion); (c) `AVAssetExportSession(asset:presetName:)` is failable; (d) `tracks(withMediaType:)`, `nominalFrameRate`, `timeRange`, `exportAsynchronously(completionHandler:)`, `status`, `error` are all deprecated in favor of **async-only** replacements — which the plan prohibits in this unit.
- **Fix:** try/add + explicit Double conversions + failable guards; the deprecated sync APIs are used deliberately (warnings only, Swift 5 mode) because the modern replacements would violate the no-async-bridge prohibition. Documented in key-decisions.
- **Verification:** Build green, warnings only
- **Committed in:** 21b656d

**4. [Rule 3 - Blocking] GitNexus impact analysis substituted**
- **Found during:** Task 1 read_first
- **Issue:** AGENTS.md mandates gitnexus_impact before editing symbols; the MCP tools are unavailable in this runtime (orchestrator note).
- **Fix:** Reference-based blast radius: CaptureService init unchanged (AppDelegate + #Preview untouched — d=0 for signatures); CaptureTabView gained one mount line (no signature changes); CaptureSaveRouter gained an additive method (route(pngData:) untouched); AppSettings consumed, not modified. Build + full bundle prove call-site compatibility.
- **Committed in:** 21b656d, aa8baa1

**5. [Rule 2 - Missing Critical] A2 fallback wired ahead of the phase gate**
- **Found during:** Task 1
- **Issue:** The flagged assumption leaves the HEVC-in-MP4 passthrough fallback as a smoke-day decision; leaving it unwired would contradict "phase gate can exercise GIF/MP4/MOV live with zero further code changes expected".
- **Fix:** `finishVideoExport` retries once with `AVAssetExportPresetHighestQuality` when passthrough fails for MP4 (no retry loop — the fallback preset is not passthrough).
- **Verification:** Build green; logic exercised only at the plan-04 smoke by design
- **Committed in:** 21b656d

---

**Total deviations:** 5 auto-fixed (1 bug + 3 blocking + 1 missing-critical pre-wire)
**Impact on plan:** No scope creep — every fix is either the house LOC rule enforced, a real-SDK correction, or the plan's own A2 contingency wired so the phase gate stays code-change-free. All threat mitigations in place (T-02-04 deterministic deletes + 24h sweep; T-02-07 own-name overwrite only; T-02-03 clipboard on explicit selection with UI copy; T-02-SC zero installs).

## Issues Encountered

- Pre-existing narrow-invocation exit-65 flake (STATE.md, pristine-HEAD-proven): "Early unexpected exit … runner exited with code 0 before establishing connection" AFTER all cases pass — twice this run, zero failed cases; house-standard full-bundle invocation exits 0. Not chased per assignment.
- One executor mis-edit briefly corrupted the PLAN file's `<files>` section; reverted immediately via single-file checkout (byte-identical to HEAD, verified by clean git status before any commit landed). Zero residual effect.
- Deprecation warnings in CaptureExporter.swift for sync AVFoundation metadata APIs (see Deviation 3d) — accepted deliberately.

## User Setup Required

None — no external services. (Live export verification at the plan-04 smoke needs the same prerequisites as plan 02: granted Screen Recording permission + one booted Simulator.)

## Next Phase Readiness

- ROADMAP criterion 4 wired end-to-end at config level: staged recording → chosen format → routed destination → thumbnail reveal → temp lifecycle closed
- All three Wave-0 test files green; unit bundle 79/79 exit 0; Debug build clean; exporter contains no async-bridge constructs
- Plan 04 (phase gate) can exercise GIF/MP4/MOV live with zero further code changes expected; A2 resolves there (fallback already wired)
- Deferred to plan 04 by design: live GIF loop/timing check, MP4 playback, each destination once, docs update

## Self-Check: PASSED

- All 8 key files exist on disk (FOUND ×8)
- Commits 43ac46c, 21b656d, aa8baa1 present on main
- Task acceptance criteria mechanically verified (greps, token counts, LOC, xcodebuild green)

---
*Phase: 02-capture-tools — Plan 03 (complete)*
*Completed: 2026-08-30*
