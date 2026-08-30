---
phase: 02-capture-tools
plan: 03
type: execute
wave: 3
depends_on: ["02-02-recording-pipeline"]
files_modified:
  - BoosterSimApp/Services/CaptureExporter.swift
  - BoosterSimApp/Services/CaptureService.swift
  - BoosterSimApp/Views/SideWindow/tabs/CaptureTabView.swift
  - BoosterSimApp/App/AppDelegate.swift
  - BoosterSimAppTests/CaptureExportConfigTests.swift
autonomous: true
requirements:
  - REQ-roadmap-phase2-capture-tools
estimate:
  tokens: 32000
  raw_tokens: 32000
  tasks: 2
  confidence: low

must_haves:
  truths:
    - "A staged recording exports as an animated GIF that loops forever (loop count 0) with integer-centisecond frame delays at the chosen width (480/640) and fps (5/10), or transcodes to MP4/MOV via AVAssetExportSession, and the result is routed to the selected destination (Desktop/clipboard/custom/ask) with the floating-thumbnail reveal"
    - "GIF frame delays quantize exactly — 10 fps produces a 10-centisecond delay per frame and 5 fps produces 20 — never alternating values that make the GIF choppy"
    - "Export runs on a background queue with published progress and a cancel control; the main thread stays responsive throughout; the exporter uses DispatchQueue + Combine only (the async-bridge exception covers the capture services, not the exporter)"
    - "Re-running an export on the same source deterministically replaces its prior output file (same name, overwrite), and temp intermediates plus the staged recording are deleted after the destination write — nothing accumulates on disk across repeated exports"
    - "Clipboard destination for videos writes the file URL (paste reveals the movie in Finder), matching the screenshot clipboard behavior of paste-into-target"
  artifacts:
    - BoosterSimApp/Services/CaptureExporter.swift
  key_links:
    - "CaptureTabView Export button → CaptureService.exportRecording(as:) → CaptureExporter.export(source:format:gifWidth:gifFPS:completion:) on DispatchQueue.global(qos: .userInitiated) → AVAssetReader + ImageIO GIF destination OR AVAssetExportSession passthrough → destination routing (shared with screenshots) → CaptureThumbnailPanel.show(url:) → staged temp deleted"
    - "AppDelegate.applicationDidFinishLaunching → CaptureExporter.sweepStaleCaptures() removes leftover boostersim-capture-* temp files at launch"
  prohibitions:
    - requirement_id: REQ-roadmap-phase2-capture-tools
      category: privacy
      status: unverified
      flagged: true
      statement: "MUST NOT retain captured content beyond the user-requested output — export deletes temp intermediates and the staged recording after the destination write, an app-launch sweep removes stale temp captures, and no disk cache or upload of captures exists"
  flagged_assumptions:
    - requirement_id: REQ-roadmap-phase2-capture-tools
      probe: research-A2
      status: unresolved
      statement: "MP4 is produced by AVAssetExportSession passthrough transcode from the recorded .mov — verified live at the plan 04 phase-gate smoke (step 3 extends to MP4); if passthrough rejects the HEVC-in-MP4 combination, fall back to AVAssetExportPresetHighestQuality re-encode and record the decision in the summary"
---

<objective>
Export pipeline: deliver ROADMAP criterion 4 — export a recording as GIF or video (MP4/MOV).

Build CaptureExporter: the GIF path decodes the staged .mov with AVAssetReader, downsamples to the selected width/fps, and encodes through ImageIO's GIF destination with quantized integer-centisecond delays and loop count 0 (single shared CIContext per export — never per frame); the video path transcodes MOV→MP4 or re-containers MOV via AVAssetExportSession passthrough. The exporter runs CPU-bound work on a background queue with Combine progress — deliberately outside the capture-services async exception. Exported files route through the plan-01 destination machinery (Desktop/clipboard/custom/ask) with the thumbnail reveal, and the temp lifecycle closes: staged recording and intermediates deleted after the destination write, plus an app-launch sweep for stragglers.

Purpose: RESEARCH E1 makes the recorded file the single source of truth for exports (no live-frame coupling); centisecond quantization (Pitfall 6) and per-export context hoisting are the two scaffold defects this design removes by construction.
Output: 1 new service, export section in the Capture tab, extended CaptureExportConfigTests, launch-sweep wiring.
</objective>

<execution_context>
@~/.claude/gsd-core/workflows/execute-plan.md
@~/.claude/gsd-core/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/ROADMAP.md
@.planning/STATE.md
@.planning/phases/02-capture-tools/02-RESEARCH.md
@.planning/phases/02-capture-tools/02-PATTERNS.md
@.planning/phases/02-capture-tools/02-01-SUMMARY.md
@.planning/phases/02-capture-tools/02-02-SUMMARY.md

Source-of-truth analogs (read before writing each file — PATTERNS.md carries near-verbatim excerpts):
@BoosterSimApp/Services/CaptureService.swift
@BoosterSimApp/Services/SimCtlService.swift
@BoosterSimAppTests/NetworkConditionServiceTests.swift
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: CaptureExporter — ImageIO GIF with centisecond quantization + AVAssetExportSession MP4/MOV</name>
  <files>
    BoosterSimApp/Services/CaptureExporter.swift,
    BoosterSimApp/App/AppDelegate.swift,
    BoosterSimAppTests/CaptureExportConfigTests.swift
  </files>
  <read_first>
    - .planning/phases/02-capture-tools/02-RESEARCH.md (Approach E1; Pattern 3 output config; Pitfall 6 centisecond churn; Don't Hand-Roll GIF/transcode rows; Runtime State Inventory temp-file row)
    - .planning/phases/02-capture-tools/02-PATTERNS.md (CaptureExporter assignment — GIF encode block to carry over with defects marked, SimCtlService background-queue pattern, no-async rule for this unit)
    - BoosterSimApp/Services/SimCtlService.swift line 37 (DispatchQueue.global(qos: .userInitiated) + Future pattern)
    - BoosterSimApp/App/AppDelegate.swift (applicationDidFinishLaunching — sweep hook site)
    - The plan-02 versions of CaptureService.swift (stagedRecordingURL) and CaptureExportConfigTests.swift (extend the same file)
  </read_first>
  <behavior>
    - CaptureExportConfigTests: gifDelayCentiseconds(fps:) — 10 maps to 10, 5 maps to 20, 15 maps to 7 (nearest whole); results are integers and deterministic for identical input
    - CaptureExportConfigTests: GIF frame properties carry kCGImagePropertyGIFDelayTime computed from the quantized centiseconds and destination properties carry kCGImagePropertyGIFLoopCount 0 (loop forever)
    - CaptureExportConfigTests: format mapping — GIF resolves to the ImageIO path with a gif extension; MP4 resolves to AVAssetExportPresetPassthrough with the mp4 file type; MOV resolves to passthrough with the mov file type; the destination filename extension matches the format
    - CaptureExportConfigTests: downsampleScale(sourceWidth:targetWidth:) — 1920→480 yields 0.25, scales never exceed 1, aspect is preserved (target height derives from the same scale)
  </behavior>
  <action>
    Extend CaptureExportConfigTests.swift first (red) with the four GIF/export mapping suites. Then:

    BoosterSimApp/Services/CaptureExporter.swift (new, under 200 LOC): @MainActor final class CaptureExporter: ObservableObject. Published private(set) exportState — idle, running(progress: Double), completed(URL), failed(String), cancelled. Pure static mappings as the tested surface: gifDelayCentiseconds(fps:) -> Int, gifProperties(fps:) building the per-frame and destination property dictionaries, exportMapping(for: CaptureExportFormat) resolving preset/file-type/extension, downsampleScale(sourceWidth:targetWidth:) -> CGFloat. Public func export(source: URL, format: CaptureExportFormat, gifWidth: Int, gifFPS: Int, completionHandler routing via Combine/@Published) — all heavy work dispatched to DispatchQueue.global(qos: .userInitiated) (SimCtlService pattern); this unit uses DispatchQueue + Combine exclusively — the async-bridge exception is scoped to the capture services and does NOT cover the exporter (PATTERNS drift guard). GIF path: AVAssetReader over the staged .mov with an AVAssetReaderTrackOutput (32BGRA), stepping samples at the selected fps relative to the track's nominal frame rate, scaling each frame CGImage down to gifWidth (one shared CIContext created per export call and hoisted outside the frame loop — the per-frame context churn is the scaffold defect being removed), appending to CGImageDestinationCreateWithURL(url, com.compuserve.gif, count, nil) with the quantized delay properties and loop count 0. Video path: AVAssetExportSession(asset:withPreset: AVAssetExportPresetPassthrough) writing to the destination extension and file type, driven through its completion handler. Deterministic replacement (idempotency truth): before writing, remove any existing file at the destination path so a re-run of the same export overwrites cleanly. Cancellation: a published cancel flag checked between frames/readings; cancelled exports delete their partial output. Cleanup: on every exit path delete decode intermediates; static func sweepStaleCaptures() removing boostersim-capture-* files older than 24 hours from FileManager.temporaryDirectory (threat T-02-04). CaptureExportFormat is consumed from plan 01 — declared inline in AppSettings.swift beside SideWindowPosition with String raw values persisted via the captureExportFormat key; this plan must not redeclare or move it (exportMapping(for:) simply switches over the plan-01 gif/mp4/mov cases). Logging via AppLogger.capture with redaction — never output paths.

    BoosterSimApp/App/AppDelegate.swift (modify): call CaptureExporter.sweepStaleCaptures() in applicationDidFinishLaunching (one line beside existing startup work).
  </action>
  <verify>
    <automated>xcodebuild -project BoosterSimApp.xcodeproj -scheme BoosterSimApp -destination 'platform=macOS' test -only-testing:BoosterSimAppTests/CaptureExportConfigTests && xcodebuild -project BoosterSimApp.xcodeproj -scheme BoosterSimApp -configuration Debug build</automated>
  </verify>
  <acceptance_criteria>
    - CaptureExportConfigTests asserts gifDelayCentiseconds 10→10, 5→20, 15→7 (integer, deterministic), loop count 0, and the three format mappings with matching extensions
    - CaptureExporter.swift references AVAssetReader, CGImageDestinationCreateWithURL, com.compuserve.gif, kCGImagePropertyGIFLoopCount, and AVAssetExportSession
    - CaptureExporter.swift creates its CIContext exactly once per export call (hoisted before the frame loop — the constructor call appears once, outside any per-frame scope)
    - The token await followed by anything and the token Task followed by an opening brace occur in CaptureExporter.swift zero times (DispatchQueue + Combine only)
    - AppDelegate.swift applicationDidFinishLaunching calls sweepStaleCaptures
    - Both xcodebuild commands exit 0
  </acceptance_criteria>
  <reversibility rating="reversible">New service; output files overwrite deterministically and temp lifecycle is self-cleaning; no persisted contract beyond the format enum raw values (chosen once here).</reversibility>
  <done>GIF export quantizes to whole centiseconds with loop-forever and selectable width/fps; MP4/MOV transcode via passthrough; progress + cancel published from a background queue; stale temp sweep wired at launch; CaptureExportConfigTests green.</done>
</task>

<task type="auto">
  <name>Task 2: Export section UI + destination routing + staged-file lifecycle</name>
  <files>
    BoosterSimApp/Services/CaptureService.swift,
    BoosterSimApp/Views/SideWindow/tabs/CaptureTabView.swift
  </files>
  <read_first>
    - .planning/phases/02-capture-tools/02-PATTERNS.md (CaptureTabView section composition + pill pickers; AppSettings binding)
    - .planning/phases/02-capture-tools/02-RESEARCH.md section F (outputs + clipboard semantics for videos)
    - The Task 1 versions of CaptureExporter.swift and the plan-01 destination routing in CaptureService.swift
    - BoosterSimApp/Models/AppSettings.swift (captureExportFormat / captureGIFSize / captureGIFFps keys from plan 01)
  </read_first>
  <action>
    BoosterSimApp/Services/CaptureService.swift (modify): public sync exportRecording(as:) facade — guards on stagedRecordingURL being set (disabled state otherwise), invokes CaptureExporter with the persisted GIF size/fps settings, and routes the completed file through the shared destination routing: Desktop writes into the capture folder, clipboard writes the file URL via NSPasteboard (paste reveals the movie in Finder), custom/ask go through the non-modal save panel with the format-correct extension pre-populated. After the destination write succeeds, delete the staged temp recording (lifecycle closes; retention rule) and show the thumbnail reveal. Route exporter failures/cancellations into published state without touching the staged file (a failed export leaves the source intact for retry).

    BoosterSimApp/Views/SideWindow/tabs/CaptureTabView.swift (modify): Export section — format pill picker (GIF/MP4/MOV) bound to AppSettings, GIF width (480/640) and fps (5/10) pickers shown only for GIF, Export button enabled exactly when a recording is staged, progress bar + Cancel button while running, completion caption with the reveal action, and a caption documenting the destination in use. Design tokens only; Reduce Motion respected.
  </action>
  <verify>
    <automated>xcodebuild -project BoosterSimApp.xcodeproj -scheme BoosterSimApp -destination 'platform=macOS' test -only-testing:BoosterSimAppTests/CaptureExportConfigTests -only-testing:BoosterSimAppTests/CaptureSettingsTests -only-testing:BoosterSimAppTests/CaptureFramingTests && xcodebuild -project BoosterSimApp.xcodeproj -scheme BoosterSimApp -configuration Debug build</automated>
  </verify>
  <acceptance_criteria>
    - CaptureService.swift exposes exportRecording(as:) that routes through the same destination path as screenshots and deletes the staged file only after a successful destination write
    - CaptureTabView.swift binds the three export AppSettings keys, disables Export with no staged recording, and shows GIF-only width/fps pickers conditionally on the selected format
    - The full capture test bundle (all three files) and the Debug build exit 0
    - Live GIF/MP4/MOV behavior is verified at the plan 04 phase-gate smoke (this plan's proof is config-level by design — live export needs a real recording, marked manual-only in validation)
  </acceptance_criteria>
  <reversibility rating="reversible">UI composition + facade routing over the Task 1 exporter; no new contracts.</reversibility>
  <done>Criterion 4 is wired end-to-end: staged recording → chosen format → routed destination → thumbnail reveal → temp lifecycle closed; all capture suites green; ready for the phase gate.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| Staged temp .mov → exporter → user-chosen destination | Screen content moves from the temp folder into user-controlled space; overwrite semantics apply |
| Recorded file bytes → GIF/MP4 decode pipelines | AVFoundation/ImageIO parse media produced by SCRecordingOutput (trusted local source, but parser-hardened system frameworks only) |

## STRIDE Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation Plan |
|-----------|----------|-----------|----------|-------------|-----------------|
| T-02-04 | Information Disclosure | Temp files with screen content left behind | high | mitigate | Deterministic delete of intermediates on every exporter exit path (including cancel); staged recording deleted after successful destination write; CaptureExporter.sweepStaleCaptures() at app launch removes stale boostersim-capture-* files older than 24h |
| T-02-07 | Tampering | Export overwrite semantics at destination | medium | mitigate | Exports overwrite only their own deterministic output name (idempotency truth); user-facing destinations go through the plan-01 save-panel/folder machinery — no arbitrary path writes |
| T-02-03 | Information Disclosure | Clipboard exfiltration (video files) | medium | mitigate | Clipboard receives a file URL only when the user explicitly selects the clipboard destination; UI copy documents it |
| T-02-SC | Tampering | Package installs | high | mitigate | Zero installs — Apple frameworks only (ImageIO is the only GIF encoder allowed; ffmpeg-class tools are forbidden by REQ-nfr-03); no SPM change |
</threat_model>

<verification>
- Task 1/2 automated: CaptureExportConfigTests (quantization, loop, mappings, scale) + CaptureSettingsTests + CaptureFramingTests green; Debug build clean.
- Live export behavior (GIF loops/timing, MP4 plays, MOV re-container) is manual-only per validation — covered by the plan 04 phase-gate smoke steps 3–4.
- Flagged assumption A2 (passthrough MP4 from HEVC .mov) is resolved at the plan 04 smoke; fallback preset documented.
</verification>

<success_criteria>
- The 5 must_haves truths hold at config level and the export path is fully wired to destinations + thumbnail + temp lifecycle.
- All three Wave 0 test files green; exporter contains no async-bridge constructs; per-export context hoisting and centisecond quantization are enforced by tests.
- Phase gate (plan 04) can exercise GIF/MP4/MOV live with zero further code changes expected.
</success_criteria>

## Artifacts this phase produces

Created by THIS plan (new symbols):
- CaptureExporter, ExportState (idle/running/completed/failed/cancelled), gifDelayCentiseconds(fps:), gifProperties(fps:), exportMapping(for:), downsampleScale(sourceWidth:targetWidth:), sweepStaleCaptures() — BoosterSimApp/Services/CaptureExporter.swift

Consumed from plan 01 (not created here): CaptureExportFormat (gif/mp4/mov) — declared inline in BoosterSimApp/Models/AppSettings.swift beside SideWindowPosition, persisted via the captureExportFormat key.

Modified: CaptureService (exportRecording(as:) facade, staged-file deletion after destination write, video clipboard semantics), CaptureTabView (export section: format/width/fps pickers, progress + cancel), AppDelegate (launch sweep call), CaptureExportConfigTests (GIF timing + mapping suites).

Later plans add: docs + full-suite gate + phase-gate smoke (04).

<output>
Create `.planning/phases/02-capture-tools/02-03-SUMMARY.md` when done
</output>
