---
phase: 02-capture-tools
plan: 02
type: execute
wave: 2
depends_on: ["02-01-screenshot-tracer"]
files_modified:
  - BoosterSimApp/Services/RecordingService.swift
  - BoosterSimApp/Services/TouchIndicatorController.swift
  - BoosterSimApp/Services/CaptureService.swift
  - BoosterSimApp/Views/SideWindow/tabs/CaptureTabView.swift
  - BoosterSimAppTests/CaptureExportConfigTests.swift
  - BoosterSimAppTests/CaptureSettingsTests.swift
autonomous: false
requirements:
  - REQ-roadmap-phase2-capture-tools
user_setup:
  - service: ios-simulator
    why: "Task 3 live smoke needs a booted iOS Simulator for a real recording and the touch-indicator relaunch cycle"
    dashboard_config:
      - task: "Boot one iOS Simulator device and keep its window open; be ready to relaunch it once after enabling touch indicators"
        location: "Xcode → Open Developer Tool → Simulator"
estimate:
  tokens: 42000
  raw_tokens: 42000
  tasks: 3
  confidence: low

must_haves:
  truths:
    - "Clicking Record starts a ScreenCaptureKit stream of the tracked Simulator window that writes frames to disk via SCRecordingOutput as they arrive — no frame buffers accumulate in app memory; Stop finalizes a playable .mov in the system temp folder whose duration matches the recorded interval and whose dimensions match the window at 2x"
    - "The stream is configured with minimumFrameInterval CMTime(value: 1, timescale: 120) and queueDepth 5 with audio capture off; the recording UI presents the rate as up to 120 fps because delivered frames are bounded by the host display refresh"
    - "With Show touch indicators enabled, starting a recording sets Simulator's ShowSingleTouches preference via in-process CFPreferences (never a subprocess), surfaces a Simulator-relaunch hint, and after the recording restores the exact prior value — or clears the key when it was previously unset; a finished session never leaves Simulator preferences modified"
    - "Single active capture at a time: starting a recording while one is active is refused by the state machine; stop on an idle service is a no-op; stop-then-export never deadlocks the UI"
    - "Recording state follows idle → recording → finishing → exported(URL) with illegal transitions trapped in Debug builds; stopCapture returning does NOT mark the file ready — only the SCRecordingOutput finish callback does, after the asset's duration is verified positive"
    - "Elapsed time and output size update live in the Capture tab during recording without blocking the main thread"
  artifacts:
    - BoosterSimApp/Services/RecordingService.swift
    - BoosterSimApp/Services/TouchIndicatorController.swift
    - BoosterSimAppTests/CaptureExportConfigTests.swift
  key_links:
    - "CaptureTabView Record button → CaptureService.startRecording() → TouchIndicatorController.enable() (when toggled) → RecordingService.start(windowID:frame:) → SCStream + SCRecordingOutput(delegate) on a dedicated serial queue → finish callback → RecordingState.exported(URL) → CaptureService.stagedRecordingURL → export UI (plan 03)"
    - "RecordingService.stop() → await stream stopCapture → state .finishing → SCRecordingOutputDelegate finish → AVAsset duration check → .exported(URL) → TouchIndicatorController.restore() (also on the error path)"
    - "RecordingService delegate wrappers (SCStreamDelegate, SCRecordingOutputDelegate) → Task { @MainActor [weak self] } hop → @Published state — callbacks never touch main-actor state directly"
  prohibitions:
    - requirement_id: REQ-roadmap-phase2-capture-tools
      category: safety
      status: unverified
      flagged: true
      statement: "MUST NOT mutate any Simulator preference other than ShowSingleTouches, and must always restore the snapshotted prior value (including the was-unset case) after the recording — cross-app preference writes are scoped to that single key with snapshot+restore semantics"
    - requirement_id: REQ-roadmap-phase2-capture-tools
      category: transparency
      status: unverified
      flagged: true
      statement: "MUST NOT advertise a fixed 120 fps — the UI presents the rate as up to 120 fps and documents that delivered frames depend on the host display (a 60 Hz panel delivers ~60)"
  flagged_assumptions:
    - requirement_id: REQ-roadmap-phase2-capture-tools
      probe: research-A3
      status: unresolved
      statement: "The M3 Pro MacBook Pro internal display supports ProMotion; true 120 fps delivery is measured (frame count / duration) during the Task 3 smoke and recorded in the summary — configured rate 120 is the criterion, delivered rate is display-bounded"
    - requirement_id: REQ-roadmap-phase2-capture-tools
      probe: research-A6
      status: unresolved
      statement: "Simulator must relaunch for ShowSingleTouches to take effect; the relaunch hint is shown when indicators are enabled — if stale-cfprefsd pickup turns out to work live, the hint is merely conservative (no functional harm)"
    - requirement_id: REQ-roadmap-phase2-capture-tools
      probe: research-A2
      status: resolved-by-design
      statement: "SCRecordingOutput writes .mov (community/Apple-sample default); MP4 is produced by plan 03's AVAssetExportSession transcode regardless of container-inference behavior"
---

<objective>
Recording pipeline: deliver ROADMAP criterion 3 — ScreenCaptureKit recording of the Simulator window including 120 FPS configuration and touch indicators visible in recordings.

Build RecordingService (SCStream + SCRecordingOutput direct-to-disk at minimumFrameInterval CMTime(1,120), queueDepth 5 — zero frame accumulation, replacing the scaffold's in-memory array approach) and TouchIndicatorController (in-process CFPreferences snapshot/set/restore of Simulator's ShowSingleTouches — Simulator itself renders the dots inside its window, so captured frames contain them for free). Integrate both into the plan-01 facade: start refused while active, stop a no-op while idle, stop-then-finalize gated on the recording-output finish callback (never on stopCapture returning).

Purpose: RESEARCH marks SCRecordingOutput (macOS 15+) as having zero in-repo usage and the stop-race (Pitfall 9) as the classic failure — this plan proves the riskiest new API surface with unit tests for every pure mapping plus a live smoke BEFORE plan 03 builds export on the recorded file.
Output: 2 new services, 1 Wave 0 test file (CaptureExportConfigTests), recording + touch-indicator sections in the Capture tab, one green live-recording smoke.
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

Source-of-truth analogs (read before writing each file — PATTERNS.md carries near-verbatim excerpts):
@BoosterSimApp/Services/CaptureService.swift
@BoosterSimApp/Services/ScreenshotService.swift
@BoosterSimApp/Services/NetworkConditionService.swift
@BoosterSimAppTests/NetworkConditionServiceTests.swift
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: RecordingService — SCRecordingOutput direct-to-disk stream with finish-callback finalization</name>
  <files>
    BoosterSimApp/Services/RecordingService.swift,
    BoosterSimApp/Services/CaptureService.swift,
    BoosterSimAppTests/CaptureExportConfigTests.swift
  </files>
  <read_first>
    - .planning/phases/02-capture-tools/02-RESEARCH.md (Pattern 3 recording shape; Pitfalls 3, 5, 8, 9; State of the Art SCRecordingOutput row)
    - .planning/phases/02-capture-tools/02-PATTERNS.md (RecordingService + CaptureExportConfigTests assignments with drift guards)
    - BoosterSimApp/Services/CaptureService.swift scaffold lines 82–116 (stream lifecycle being replaced) and 291–312 (non-isolated NSObject delegate wrappers with the Task { @MainActor [weak self] } hop — keep this shape)
    - BoosterSimApp/Services/ScreenshotService.swift (plan-01 window matching + config conventions to mirror)
    - BoosterSimApp/Services/NetworkConditionService.swift lines 8–49 + 140–170 (state enum with canTransition/isWorking + begin/finish/transition quartet)
    - BoosterSimAppTests/NetworkConditionServiceTests.swift lines 14–24 (transition-assertion test style)
    - The plan-01 CaptureService facade and CaptureTabView
  </read_first>
  <behavior>
    - CaptureExportConfigTests: frame-interval mapping — configuredFrameInterval(for: 120) equals CMTime(value: 1, timescale: 120); the queueDepth constant equals 5 and lies within 3...8
    - CaptureExportConfigTests: recording output config mapping — codec choice resolves to the expected SCRecordingOutputConfiguration video codec cases and the output URL extension is mov with a boostersim-capture- timestamp prefix
    - CaptureExportConfigTests: RecordingState transitions — idle→recording legal; recording→recording illegal (double start refused); recording→finishing legal; finishing→exported(url) legal; finishing→error(String) legal; error→idle legal; idle→finishing illegal (stop on idle never enters the machine); isWorking true only for recording and finishing
  </behavior>
  <action>
    Write CaptureExportConfigTests.swift first (Swift Testing, red) — pure config/state mappings only, no stream session. Then:

    BoosterSimApp/Services/RecordingService.swift (new, under 200 LOC): @MainActor final class RecordingService: ObservableObject. enum RecordingState: Equatable in the NetworkConditionState shape — cases idle, recording, finishing, exported(URL), error(String) — with canTransition(to:) and isWorking, plus the begin/finish/transition quartet calling assertionFailure on illegal transitions. @Published private(set) state, elapsed: TimeInterval, outputBytes: Int64. Public sync API start(windowID:frame:) / stop() bridging through Task { await ... } internally (RecordingService is a capture service — inside the CONVENTIONS exception; nothing outside the capture services adopts the async bridge). Configuration as pure, testable statics: configuredFrameInterval(for fps: Int) -> CMTime, queueDepth = 5, recordingConfiguration(outputURL:) mapping codec .hevc. Stream setup mirroring ScreenshotService: SCShareableContent window match on the tracked CGWindowID, SCContentFilter(desktopIndependentWindow:), SCStreamConfiguration with width/height = Int(windowFrame dimensions) * 2, showsCursor = false, capturesAudio = false, minimumFrameInterval from the mapping, queueDepth 5. Output: SCRecordingOutputConfiguration with outputURL in FileManager.temporaryDirectory named boostersim-capture- + timestamp + .mov; SCRecordingOutput(configuration:delegate:) attached via addStreamOutput(_:type:sampleHandlerQueue:) on a dedicated serial DispatchQueue (a labeled queue — never the main queue, Pitfall 8). Stop path per Pitfall 9: stop() transitions to finishing, awaits stream stopCapture, and stays finishing until the recording-output delegate's finish callback fires; the callback handler then loads AVAsset(url:) and requires duration > 0 and isPlayable before transitioning to exported(URL) — a zero-length or unplayable file goes to error(String). File bottom: private final class wrappers per protocol (SCStreamDelegate for didStopWithError, SCRecordingOutputDelegate for finish/failure) holding weak var owner and hopping with Task { @MainActor [weak self] } — published state is never touched from the callback thread. Live UI numbers: Combine Timer on main publishing elapsed; outputBytes read from the output's recordedFileSize. Logging via AppLogger.capture with redaction.

    BoosterSimApp/Services/CaptureService.swift (modify): own a RecordingService; startRecording() guards on the combined state — a start while recording/finishing is refused (early return, published state unchanged — probe truth), stopRecording() is a no-op when idle; when RecordingState reaches exported(URL), publish stagedRecordingURL (drives the export UI in plan 03 and a reveal row now). Route stream errors into lastError without crashing.
  </action>
  <verify>
    <automated>xcodebuild -project BoosterSimApp.xcodeproj -scheme BoosterSimApp -destination 'platform=macOS' test -only-testing:BoosterSimAppTests/CaptureExportConfigTests && xcodebuild -project BoosterSimApp.xcodeproj -scheme BoosterSimApp -configuration Debug build</automated>
  </verify>
  <acceptance_criteria>
    - CaptureExportConfigTests.swift exists, imports Testing, asserts CMTime(value: 1, timescale: 120) for the 120 mapping, bounds queueDepth within 3...8, and covers every legal/illegal RecordingState transition including the refused double-start and the never-entering stop-on-idle
    - RecordingService.swift references SCRecordingOutput, SCRecordingOutputConfiguration, minimumFrameInterval, and queueDepth, and the sampleHandlerQueue argument is a labeled serial DispatchQueue — DispatchQueue.main occurs in it zero times
    - RecordingService.swift declares the five-case RecordingState with canTransition and isWorking, and the CMSampleBuffer token occurs in it zero times (no frame accumulation)
    - The finalization path contains an AVAsset duration-is-positive check reached only from the recording-output finish callback — stopCapture alone never produces exported
    - Both xcodebuild commands exit 0
  </acceptance_criteria>
  <reversibility rating="reversible">New service, no persisted contract; the temp .mov lifecycle is fully owned in-process and cleaned by plan 03's sweep.</reversibility>
  <done>Recording writes directly to disk with zero accumulation at the configured 120 fps ceiling; the state machine refuses double starts and no-op stops; finalization is gated on the finish callback with a duration check; CaptureExportConfigTests green.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: TouchIndicatorController — ShowSingleTouches snapshot/set/restore + recording UI section</name>
  <files>
    BoosterSimApp/Services/TouchIndicatorController.swift,
    BoosterSimApp/Services/CaptureService.swift,
    BoosterSimApp/Views/SideWindow/tabs/CaptureTabView.swift,
    BoosterSimAppTests/CaptureSettingsTests.swift
  </files>
  <read_first>
    - .planning/phases/02-capture-tools/02-RESEARCH.md (Pattern 6 CFPreferences mechanism verbatim; Runtime State Inventory Simulator-pref row; Pitfall on overlay-drawn indicators)
    - .planning/phases/02-capture-tools/02-PATTERNS.md (TouchIndicatorController assignment — state-machine shell from NetworkConditionService, mechanism has NO in-repo analog, use Pattern 6 verbatim; drift guard: never shell out to defaults, never lose the was-unset restore case)
    - BoosterSimApp/Services/NetworkConditionService.swift (state machine quartet + published shell)
    - The Task 1 versions of RecordingService.swift and CaptureService.swift
    - BoosterSimAppTests/CaptureSettingsTests.swift (extend the existing suite — same file, isolated-suite helpers already present)
  </read_first>
  <behavior>
    - CaptureSettingsTests: TouchIndicatorState machine — idle→applying→active→restoring→idle legal path; applying→error(String) legal; double-enable while active refused; isWorking semantics per case
    - CaptureSettingsTests: restore semantics through an injected in-memory preference store — previously-true restores true, previously-false restores false, previously-unset clears the key (the sentinel null); the production domain/key strings are asserted as constants (com.apple.iphonesimulator / ShowSingleTouches) without touching real preferences
    - CaptureSettingsTests: after restore, the store's value equals the snapshot exactly — a cancelled or errored session still restores (restore runs on every exit path)
  </behavior>
  <action>
    Extend CaptureSettingsTests.swift first (red) with the touch-machine suite. Then:

    BoosterSimApp/Services/TouchIndicatorController.swift (new, under 200 LOC): @MainActor final class TouchIndicatorController: ObservableObject. enum TouchIndicatorState: Equatable — idle, applying, active, restoring, error(String) — with canTransition/isWorking and the transition quartet. Define protocol TouchPreferencesStore with copyValue(forKey:domain:), setValue(_:forKey:domain:), synchronize(domain:) and a production conformer implementing them with CFPreferencesCopyAppValue, CFPreferencesSetAppValue, CFPreferencesAppSynchronize on domain com.apple.iphonesimulator, key ShowSingleTouches (RESEARCH Pattern 6 verbatim — the only key this controller ever references; enable() snapshots the prior value, writes true as CFNumber, synchronizes; restore() writes the snapshot back or clears via kCFNull when the snapshot was unset). Published: state and needsSimulatorRelaunch (research A6 — the pref takes effect after Simulator relapses; hint shown when indicators are enabled). Tests inject an in-memory store; the real domain is never touched by tests. The controller stays entirely in-process — the house rule routes command execution through SimCtlService, and this mechanism deliberately uses the preference API instead of any command spawn.

    BoosterSimApp/Services/CaptureService.swift (modify): when the captureShowTouchIndicators setting is on, startRecording() runs touchIndicatorController.enable() BEFORE the stream starts, and restore() runs on every exit path — after the finish callback, on stream error, and on stop — so Simulator preferences are never left modified (threat T-02-02). Order: enable failure degrades to recording-without-indicators plus a published hint (never blocks the recording).

    BoosterSimApp/Views/SideWindow/tabs/CaptureTabView.swift (modify): Recording section — Record/Stop toggle button (video / stop SF Symbols) driving the facade, a caption reading Up to 120 fps (prohibition on overclaiming), the Show touch indicators toggle bound to AppSettings, the relaunch hint row when indicators turn on, live elapsed + output-size captions, and a staged-recording row (filename + reveal in Finder) appearing when stagedRecordingURL is set. Reduce Motion 0.1s linear; all layout via design tokens.
  </action>
  <verify>
    <automated>xcodebuild -project BoosterSimApp.xcodeproj -scheme BoosterSimApp -destination 'platform=macOS' test -only-testing:BoosterSimAppTests/CaptureSettingsTests -only-testing:BoosterSimAppTests/CaptureExportConfigTests && xcodebuild -project BoosterSimApp.xcodeproj -scheme BoosterSimApp -configuration Debug build</automated>
  </verify>
  <acceptance_criteria>
    - TouchIndicatorController.swift references CFPreferencesCopyAppValue, CFPreferencesSetAppValue, CFPreferencesAppSynchronize, and kCFNull, declares the TouchPreferencesStore protocol, and the ShowSingleTouches string is the only preference key constant in the file
    - The tokens NSTask and Process( occur in TouchIndicatorController.swift zero times
    - CaptureService.swift calls the indicator controller's enable before stream start and restore on every exit path (finish, stream error, stop)
    - CaptureSettingsTests covers the triad restore semantics (true/false/unset) via the injected store and the state-machine transitions
    - CaptureTabView.swift contains the fps caption wording "Up to 120 fps" and a touch-indicator toggle bound to the AppSettings key
    - Both xcodebuild commands exit 0
  </acceptance_criteria>
  <reversibility rating="costly">Writes a third-party app's preference domain — one-way only if restore were skipped; the snapshot/restore machine plus the every-exit-path wiring is the mandated mitigation (threat T-02-02), and the Task 3 smoke re-verifies restore on a real Simulator.</reversibility>
  <done>Touch indicators flip Simulator's own rendering via the single scoped preference with guaranteed restore on every path; the recording UI shows honest fps wording, live stats, and the staged recording; all capture test suites green.</done>
</task>

<task type="checkpoint:human-verify" gate="blocking-human">
  <name>Task 3: Smoke recording on a live Simulator — playable .mov, delivered fps, touch dots, pref restore</name>
  <files>none</files>
  <read_first>
    - .planning/phases/02-capture-tools/02-VALIDATION.md (Manual-Only rows: playable .mov, touch dots visible, delivered-fps measurement)
    - .planning/phases/02-capture-tools/02-RESEARCH.md Pitfall 5 (fps vs display refresh), Pitfall 9 (stop race), assumption A3/A6
  </read_first>
  <action>
    Blocking human checkpoint — recording needs TCC + real display timing + WindowServer (manual-only per validation). Prerequisites (user_setup): BoosterSimApp running, one booted Simulator, touch indicators toggled on (relaunch Simulator when hinted — A6). Execute the six steps; the executor computes delivered fps by counting frames via AVAssetReader over the staged file divided by duration (a short swift CLI snippet is fine — Apple frameworks only) and records configured 120 vs delivered N with the display name in the summary. Step 5 verifies the refusal/no-op semantics of probe truth 2 against the real UI. Step 6 verifies the preference restore: dots gone after restore + next Simulator relaunch.
  </action>
  <verify>
    <human-check>All six smoke steps recorded pass/fail in the summary; specifically the staged .mov plays with correct duration and dimensions, contains touch dots and no BoosterSimApp panel or desktop pixels, and Simulator's preference is restored afterwards.</human-check>
  </verify>
  <acceptance_criteria>
    - Summary records per-step pass/fail plus the measured delivered-fps line (configured 120, delivered N, display name)
    - The .mov is playable, duration ≈ the recorded interval, dimensions = window at 2x, content window-scoped with visible touch dots
    - Start-while-recording refused and stop-while-idle a no-op in the live UI (state machine proven against real interaction)
    - ShowSingleTouches restored after the session (dots disappear after restore + relaunch); a relaunch hint appeared when indicators were enabled
  </acceptance_criteria>
  <what-built>The Phase 2 recording pipeline: Capture tab Record button → CaptureService (indicator enable on the start path) → RecordingService SCStream + SCRecordingOutput at CMTime(1,120)/queueDepth 5 on a dedicated serial queue → finish-callback finalization with duration check → staged .mov published for plan 03 export. TouchIndicatorController snapshots/sets/restores Simulator's ShowSingleTouches via in-process CFPreferences. CaptureExportConfigTests + CaptureSettingsTests + CaptureFramingTests green; app builds.</what-built>
  <how-to-verify>
    With BoosterSimApp running and one booted Simulator:
    1. Toggle Show touch indicators on in the Capture tab; relaunch Simulator when the hint appears (A6)
    2. Click Record; tap and drag on the Simulator screen for ~15 s; watch elapsed/size captions update live
    3. Click Stop; after the finishing state clears, open the staged .mov — it plays, duration ≈ 15 s, dimensions = window at 2x, frames contain touch dots and no panel/desktop content
    4. Measure delivered fps (frame count via AVAssetReader ÷ duration); record "configured 120, delivered N on <display>"
    5. While recording, click Record again — refused (state unchanged); after stopping, click Stop again — no-op, no error state
    6. After the session, Simulator's touch dots are gone (preference restored; relaunch Simulator once to confirm)
  </how-to-verify>
  <resume-signal>Reply "approved" to unblock plan 03 (export), or describe the failing step — a zero-byte or unplayable .mov invalidates the SCRecordingOutput approach (research D2 fallback: AVAssetWriter) and halts for replan.</resume-signal>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| Simulator window content → BoosterSimApp recording stream | Screen pixels cross from WindowServer under TCC Screen Recording; output lands in the system temp folder |
| BoosterSimApp → com.apple.iphonesimulator preferences | Cross-app CFPreferences write, scoped to one key with snapshot+restore |
| SCK callback queues → @MainActor service state | Non-isolated delegate callbacks hop to main via Task { @MainActor } |

## STRIDE Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation Plan |
|-----------|----------|-----------|----------|-------------|-----------------|
| T-02-02 | Tampering | Cross-app preference write (com.apple.iphonesimulator) | medium | mitigate | Single key ShowSingleTouches only; snapshot-before-write and restore-after including the was-unset case; in-process CFPreferences (no command spawn); restore wired on every exit path; documented in code and system-architecture.md (plan 04) |
| T-02-01 | Information Disclosure | Recorded screen content | high | mitigate | Window-scoped desktopIndependentWindow filter (never display-wide); TCC preflight unchanged from plan 01; staged file lives only in the system temp folder and is deleted after export (plan 03) or sweep; AppLogger.capture redaction |
| T-02-04 | Information Disclosure | Staged .mov left in temp | high | mitigate | Staged recordings are boostersim-capture- prefixed in temporaryDirectory; plan 03 deletes them after destination write and adds the app-launch sweep; summary of Task 3 confirms no stray files |
| T-02-06 | DoS | Sample-handler queue starving main thread | medium | mitigate | Dedicated serial DispatchQueue for stream output (never the main queue); Swift 6 isolation via the NSObject wrapper + main-actor hop pattern; live captions update through published state on main only |
| T-02-SC | Tampering | Package installs | high | mitigate | Zero installs — Apple frameworks only; no SPM change (empty git diff on the swiftpm share at the plan 04 gate) |
</threat_model>

<verification>
- Task 1/2 automated: CaptureExportConfigTests (new Wave 0 file) + CaptureSettingsTests (extended) + CaptureFramingTests green via the plan's xcodebuild commands; Debug build clean.
- Task 3: blocking human smoke — playable .mov, delivered-fps measurement (A3), touch dots visible, refusal/no-op semantics, preference restore (A6).
- Idempotency/concurrency probe truths are covered by unit tests (state machine) and step 5 of the smoke.
</verification>

<success_criteria>
- The 6 must_haves truths hold; the live smoke proves a playable, window-scoped, touch-dotted recording with honest fps reporting and restored Simulator preferences.
- All three capture test files green; app builds; no frame accumulation anywhere in the recording path.
- The staged .mov contract (temp folder, boostersim-capture- prefix, finish-callback finalization) is stable for plan 03's export to consume.
</success_criteria>

## Artifacts this phase produces

Created by THIS plan (new symbols):
- RecordingService, RecordingState (idle/recording/finishing/exported/error), configuredFrameInterval(for:), recordingConfiguration(outputURL:), private SCStreamDelegate + SCRecordingOutputDelegate wrapper classes — BoosterSimApp/Services/RecordingService.swift
- TouchIndicatorController, TouchIndicatorState, TouchPreferencesStore (protocol + CFPreferences conformer) — BoosterSimApp/Services/TouchIndicatorController.swift
- Tests: CaptureExportConfigTests (new Wave 0 file); CaptureSettingsTests extended with the touch-machine suite

Modified: CaptureService (startRecording/stopRecording guards, stagedRecordingURL, indicator wiring on every exit path), CaptureTabView (recording section: record/stop, fps caption, indicator toggle + relaunch hint, live stats, staged row).

Later plans add: CaptureExporter + GIF/MP4/MOV formats + temp sweep (03), docs + phase gate (04).

<output>
Create `.planning/phases/02-capture-tools/02-02-SUMMARY.md` when done
</output>
