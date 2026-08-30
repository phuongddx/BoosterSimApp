---
phase: 02-capture-tools
plan: 04
type: execute
wave: 4
depends_on: ["02-01-screenshot-tracer", "02-02-recording-pipeline", "02-03-export-formats"]
files_modified:
  - docs/system-architecture.md
autonomous: false
requirements:
  - REQ-roadmap-phase2-capture-tools
  - REQ-nfr-03
user_setup:
  - service: ios-simulator
    why: "Task 2 phase-gate smoke exercises every Phase 2 criterion live: framed screenshot, 30s recording, delivered-fps measurement, GIF/MP4/MOV export, all three destinations, thumbnail"
    dashboard_config:
      - task: "Boot one iOS Simulator device (6.9-inch class) with its window open; BoosterSimApp running with Screen Recording granted; a ProMotion-capable display in use if available"
        location: "Xcode → Open Developer Tool → Simulator"
estimate:
  tokens: 18000
  raw_tokens: 18000
  tasks: 2
  confidence: low

must_haves:
  truths:
    - "All four Phase 2 success criteria are observed TRUE in one live phase-gate smoke session: a screenshot at exact ASC preset dimensions with no alpha and window-scoped content; a 30-second recording that plays with a measured delivered-fps line; a GIF export that loops with correct timing and an MP4/MOV export that plays; each save destination (Desktop/clipboard/custom) exercised once; the floating thumbnail appears and auto-hides"
    - "The full unit bundle — the pre-existing suites plus CaptureFramingTests, CaptureExportConfigTests, CaptureSettingsTests — exits 0 via the phase-gate standard command (unit bundle only, UI tests skipped per the documented pre-existing env failure), and the app scheme Debug build is clean"
    - "No dependency changed: the swiftpm workspace share shows an empty git diff at close (REQ-nfr-03 — Apple frameworks only, zero installs this phase)"
    - "docs/system-architecture.md documents the capture subsystem: the service split and data flow, the ShowSingleTouches cross-app preference scope + restore semantics, the Screen Recording permission requirement, and the degraded behavior when it is denied"
  artifacts:
    - docs/system-architecture.md
  key_links:
    - "docs/system-architecture.md capture section ↔ shipped code (ScreenshotService, RecordingService, CaptureCompositor, CaptureExporter, TouchIndicatorController, CaptureThumbnailPanel) — doc claims must name the real symbols"
  prohibitions:
    - requirement_id: REQ-roadmap-phase2-capture-tools
      category: privacy
      status: unverified
      flagged: true
      statement: "MUST NOT capture or record any screen content beyond the tracked Simulator window — re-verified during this gate's smoke (window-scoped output only, no desktop/panel pixels in screenshots or recordings)"
    - requirement_id: REQ-roadmap-phase2-capture-tools
      category: privacy
      status: unverified
      flagged: true
      statement: "MUST NOT retain captured content beyond the user-requested output — re-verified during this gate's smoke: no boostersim-capture-* temp files remain after the session (deterministic cleanup + launch sweep)"
  flagged_assumptions:
    - requirement_id: REQ-roadmap-phase2-capture-tools
      probe: research-A2
      status: unresolved
      statement: "MP4 via AVAssetExportSession passthrough from the HEVC .mov — the gate's step 3 resolves it live; if passthrough fails, apply the documented AVAssetExportPresetHighestQuality fallback inside plan 03's exporter before closing the phase and record the decision"
---

<objective>
Phase-gate closure: prove all four Phase 2 success criteria true and close the phase honestly.

Update docs/system-architecture.md with the capture subsystem (house docs rule — Phase 5 pattern), run the phase-gate automated standard (full unit bundle + Debug build + no-SPM-change diff), then run the single-Session manual smoke from 02-VALIDATION.md covering every criterion, the manual-only verification rows, and the two flagged retention/window-scoping prohibitions.

Purpose: the live behaviors (SCK capture, playable recordings, delivered fps, GIF timing, clipboard/desktop/custom saves, TCC degradation) are manual-only per the validation strategy; this plan is where they are observed and recorded.
Output: docs updated, automated gate green, per-step smoke record in the summary.
</objective>

<execution_context>
@~/.claude/gsd-core/workflows/execute-plan.md
@~/.claude/gsd-core/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/ROADMAP.md
@.planning/STATE.md
@.planning/phases/02-capture-tools/02-VALIDATION.md
@.planning/phases/02-capture-tools/02-01-SUMMARY.md
@.planning/phases/02-capture-tools/02-02-SUMMARY.md
@.planning/phases/02-capture-tools/02-03-SUMMARY.md

@docs/system-architecture.md
</context>

<tasks>

<task type="auto">
  <name>Task 1: Architecture docs update + phase-gate automated standard</name>
  <files>
    docs/system-architecture.md
  </files>
  <read_first>
    - docs/system-architecture.md (existing structure and section style — extend, do not restructure)
    - .planning/phases/02-capture-tools/02-RESEARCH.md (Recommended Approach diagram + Security Domain)
    - .planning/phases/02-capture-tools/02-VALIDATION.md (Phase-Gate Manual Smoke + full-suite command)
    - The shipped capture sources (ScreenshotService, RecordingService, CaptureCompositor, CaptureExporter, TouchIndicatorController, CaptureThumbnailPanel, CaptureService) — doc must name real symbols and match behavior
    - AGENTS.md security section (permission documentation rule: required permissions + degraded behavior)
  </read_first>
  <action>
    docs/system-architecture.md (modify): add the Capture Tools subsystem section following the existing document's style: the service split (CaptureService facade; ScreenshotService SCScreenshotManager one-shot; RecordingService SCStream + SCRecordingOutput at CMTime(1,120)/queueDepth 5; CaptureCompositor pure ASC-preset/bezel/background geometry; CaptureExporter AVAssetReader→ImageIO GIF + AVAssetExportSession MP4/MOV; TouchIndicatorController; CaptureThumbnailPanel), the data flow from Capture tab to destination routing, the permissions block (Screen Recording TCC required; grant-requires-restart cycle; degraded setup UX when denied — AGENTS.md rule), and the cross-app preference note (single key ShowSingleTouches on com.apple.iphonesimulator, snapshot+restore including the was-unset case, Simulator relaunch for effect). Keep every claim grounded in shipped symbols — no aspirational text.

    Then run the phase-gate automated standard and record results in the summary: (1) full unit bundle via xcodebuild test with -only-testing:BoosterSimAppTests (the unfiltered run exits 65 on pristine HEAD from the pre-existing UI-test env failure — documented, do not chase); (2) Debug build of the app scheme; (3) git diff --exit-code on BoosterSimApp.xcodeproj/project.xcworkspace/xcshareddata/swiftpm proving zero dependency change.
  </action>
  <verify>
    <automated>xcodebuild -project BoosterSimApp.xcodeproj -scheme BoosterSimApp -destination 'platform=macOS' test -only-testing:BoosterSimAppTests && xcodebuild -project BoosterSimApp.xcodeproj -scheme BoosterSimApp -configuration Debug build && git diff --exit-code BoosterSimApp.xcodeproj/project.xcworkspace/xcshareddata/swiftpm</automated>
  </verify>
  <acceptance_criteria>
    - docs/system-architecture.md contains a capture section naming ScreenshotService, RecordingService, CaptureCompositor, CaptureExporter, TouchIndicatorController, and CaptureThumbnailPanel, plus permission and degraded-behavior text for Screen Recording and the ShowSingleTouches scope+restore note
    - The full unit bundle command exits 0 (pre-existing suites plus the three capture test files)
    - The Debug build exits 0 and the swiftpm git diff is empty
  </acceptance_criteria>
  <reversibility rating="reversible">Documentation only; the automated gate is read-only verification.</reversibility>
  <done>Docs describe the shipped capture subsystem truthfully; the phase-gate automated standard is green with zero dependency changes.</done>
</task>

<task type="checkpoint:human-verify" gate="blocking-human">
  <name>Task 2: Phase-gate manual smoke — all four criteria on one booted Simulator</name>
  <files>none</files>
  <read_first>
    - .planning/phases/02-capture-tools/02-VALIDATION.md (Phase-Gate Manual Smoke checklist — this task executes it verbatim)
    - .planning/phases/02-capture-tools/02-RESEARCH.md (Pitfall 5 delivered-fps measurement; assumption A2 MP4 passthrough)
  </read_first>
  <action>
    Blocking human checkpoint — the phase gate. Prerequisites (user_setup): BoosterSimApp running, Screen Recording granted, one booted 6.9-inch-class Simulator. Execute the six smoke steps from 02-VALIDATION.md and record per-step pass/fail in the summary. Step 2 measures delivered fps over a 30-second recording (frame count via AVAssetReader ÷ duration; record configured 120 vs delivered N and the display). Step 3 exports the SAME recording as GIF and as MP4 (and MOV once) — resolving flagged assumption A2 live; a passthrough failure triggers the documented re-encode fallback inside the plan 03 exporter before the phase closes. Step 5 doubles as the retention-prohibition re-check: after the session, confirm no boostersim-capture-* files remain in the system temp folder (launch sweep + deterministic cleanup). Window scoping is re-verified in every captured artifact (no desktop or panel pixels).
  </action>
  <verify>
    <human-check>All six smoke steps observed and recorded pass/fail in the summary; all four ROADMAP success criteria confirmed true on the live Simulator, including the delivered-fps line and the empty temp folder.</human-check>
  </verify>
  <acceptance_criteria>
    - Summary contains a per-step pass/fail record for the 6-step gate (screenshot dimensions/alpha, recording playable + delivered fps, GIF/MP4/MOV exports, three destinations, thumbnail, docs updated)
    - Screenshot is preset-exact with no alpha and window-scoped content; recording plays with touch dots when enabled; GIF loops with even timing; MP4 plays (A2 resolved or fallback applied); each destination produces/reveals its artifact once
    - No boostersim-capture-* temp files remain after the session (retention prohibition re-verified)
    - docs/system-architecture.md updated (Task 1) — gate step 6 confirms
  </acceptance_criteria>
  <what-built>Phase 2 complete: framed ASC-preset screenshots (SCScreenshotManager + pure compositor), Desktop/clipboard/custom saves with floating thumbnail, SCRecordingOutput recordings at the 120 fps configured ceiling with Simulator-native touch indicators, and GIF/MP4/MOV export — all surfaced in the Capture tab of the side panel. Full unit bundle green, Debug build clean, zero dependency changes, architecture documented.</what-built>
  <how-to-verify>
    With BoosterSimApp running, Screen Recording granted, and one booted Simulator:
    1. Capture a screenshot with a 6.9-inch preset — verify dimensions match the preset exactly, no alpha channel, only Simulator content on the chosen background
    2. Record ~30 s (touch indicators on) — verify the .mov plays, duration/dimensions are right, dots are visible, and record delivered fps (frame count ÷ duration) vs configured 120
    3. Export the recording as GIF (loops forever, even timing), as MP4 (plays — resolves A2), and as MOV once
    4. Exercise each destination once: Desktop (file in ~/Desktop/BoosterSim Captures/), clipboard (paste works), custom path (save panel)
    5. Confirm the thumbnail appears and auto-hides after each capture/export; afterwards confirm no boostersim-capture-* files remain in the temp folder
    6. Confirm docs/system-architecture.md capture section reflects what was exercised
  </how-to-verify>
  <resume-signal>Reply "approved" to close Phase 2 (all criteria true), or describe the failing step — failures route to gap-closure planning, not silent closure.</resume-signal>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| Whole phase re-verified | This gate re-exercises every trust boundary from plans 01–03 (TCC-gated capture, cross-app preference, temp lifecycle, clipboard) against the final assembled system |

## STRIDE Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation Plan |
|-----------|----------|-----------|----------|-------------|-----------------|
| T-02-01 | Information Disclosure | Captured content beyond the Simulator window | high | mitigate | Gate step 1–2 re-verify window-scoped output in every artifact type (screenshot, recording, exported GIF/video) |
| T-02-04 | Information Disclosure | Screen-content temp files retained | high | mitigate | Gate step 5 re-verifies the empty temp folder after a full capture+export session (deterministic cleanup + launch sweep from plan 03) |
| T-02-SC | Tampering | Package installs / dependency drift | high | mitigate | git diff --exit-code on the swiftpm workspace share in Task 1 — zero dependency change required to close (REQ-nfr-03) |
</threat_model>

<verification>
- Task 1: automated phase-gate standard (full unit bundle, Debug build, empty swiftpm diff) — all exit 0.
- Task 2: the 6-step manual smoke covering all four success criteria, the manual-only validation rows, and both re-verified prohibitions.
- Flagged assumption A2 resolved at step 3 (passthrough MP4) or the documented fallback applied.
</verification>

<success_criteria>
- The 4 must_haves truths hold — equivalently, all four ROADMAP Phase 2 success criteria are observed true in the gate session.
- Automated gate green; docs truthful; zero dependency changes; summary carries the per-step record and the delivered-fps line.
- Phase 2 closes with no silent gaps: any failing step routes to gap closure.
</success_criteria>

## Artifacts this phase produces

Created by THIS plan: none (closure plan — docs + verification only).

Modified: docs/system-architecture.md (capture subsystem section: service split, data flow, permissions + degraded behavior, ShowSingleTouches scope/restore note).

Phase 2 totals across plans 01–04: ASCFramePreset, BezelMode, CaptureBackground, CaptureDestination, CaptureCompositor + FramingResult, ScreenshotService + CaptureError, CaptureService (rewritten facade), RecordingService + RecordingState, TouchIndicatorController + TouchIndicatorState + TouchPreferencesStore, CaptureExporter + ExportState + CaptureExportFormat, CaptureThumbnailPanel, AppLogger.capture, 8 AppSettings capture keys, three Swift Testing suites (CaptureFramingTests, CaptureExportConfigTests, CaptureSettingsTests).

<output>
Create `.planning/phases/02-capture-tools/02-04-SUMMARY.md` when done
</output>
