---
phase: 02-capture-tools
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - BoosterSimApp/Models/ASCFramePreset.swift
  - BoosterSimApp/Models/BezelMode.swift
  - BoosterSimApp/Models/CaptureDestination.swift
  - BoosterSimApp/Utilities/CaptureCompositor.swift
  - BoosterSimApp/Services/ScreenshotService.swift
  - BoosterSimApp/Services/CaptureService.swift
  - BoosterSimApp/Windows/CaptureThumbnailPanel.swift
  - BoosterSimApp/Views/SideWindow/tabs/CaptureTabView.swift
  - BoosterSimApp/App/AppDelegate.swift
  - BoosterSimApp/Utilities/AppLogger.swift
  - BoosterSimAppTests/CaptureFramingTests.swift
autonomous: false
requirements:
  - REQ-roadmap-phase2-capture-tools
  - REQ-fr-09
  - REQ-nfr-03
user_setup:
  - service: ios-simulator
    why: "Task 3 live smoke needs a booted iOS Simulator window tracked by the panel, plus the macOS Screen Recording TCC grant (deny-state also exercised for the degraded UX)"
    dashboard_config:
      - task: "Boot one iOS Simulator device (6.9-inch class, e.g. iPhone 16 Pro Max) and keep its window open"
        location: "Xcode → Open Developer Tool → Simulator"
      - task: "Screen Recording permission for BoosterSimApp: deny once for the degraded-UX step, then grant for capture steps"
        location: "macOS System Settings → Privacy & Security → Screen & System Audio Recording"
estimate:
  tokens: 55000
  raw_tokens: 55000
  tasks: 3
  confidence: low

must_haves:
  truths:
    - "With a tracked Simulator window and Screen Recording granted, clicking Capture in the Capture tab produces a PNG at ~/Desktop/BoosterSim Captures/ whose pixel dimensions exactly equal the selected App Store Connect preset (e.g. 1320x2868) and which contains ONLY the Simulator window's content composited onto an opaque background — the Mac desktop, other app windows, and BoosterSimApp's own panel never appear, and the saved file carries no alpha channel"
    - "Bezel mode (none / simulatorNative / drawn) and background (solid color / gradient) selections change the composited output; the drawn bezel renders a rounded-rect device silhouette around the content at uniform scale — content is never stretched (aspect preserved within 1%)"
    - "After every successful capture a floating thumbnail appears near the Simulator window, auto-hides after ~3 seconds, and clicking it reveals the saved file in Finder"
    - "Screenshots save to Desktop, the clipboard (pasteable into Preview as PNG), or a custom path chosen through a non-modal save panel; the chosen destination, preset, bezel mode, and background persist across app relaunch"
    - "With Screen Recording denied, capture controls show a permission-setup state and nothing crashes; after the user grants permission and quits + reopens the app (Apple's restart requirement), capture works with no further steps"
    - "Repeated captures are independent: a second screenshot with identical inputs produces a NEW file (timestamped filename), never corrupts/appends to prior output; re-running an export on the same source deterministically replaces its prior output file"
  artifacts:
    - BoosterSimApp/Models/ASCFramePreset.swift
    - BoosterSimApp/Models/BezelMode.swift
    - BoosterSimApp/Models/CaptureDestination.swift
    - BoosterSimApp/Utilities/CaptureCompositor.swift
    - BoosterSimApp/Services/ScreenshotService.swift
    - BoosterSimApp/Services/CaptureService.swift
    - BoosterSimApp/Windows/CaptureThumbnailPanel.swift
    - BoosterSimAppTests/CaptureFramingTests.swift
  key_links:
    - "CaptureTabView capture button → CaptureService.takeScreenshot() (sync facade, Task { await } bridge, DeepLinkService pattern) → ScreenshotService.capture(windowID:frame:) → SCScreenshotManager.captureImage(contentFilter:configuration:) with SCContentFilter(desktopIndependentWindow:) matched to the tracked CGWindowID → CaptureCompositor.render(...) → destination write + CaptureThumbnailPanel.show(url:)"
    - "AppDelegate lazy var captureService/captureThumbnailPanel → SideWindowController (existing captureService injection, unchanged signature) → .environmentObject(captureService) → CaptureTabView"
    - "PermissionManager CGPreflightScreenCaptureAccess() poll → CaptureService.permissionGranted (@Published) → CaptureTabView degraded setup UI + quit-and-reopen prompt after grant"
  prohibitions:
    - requirement_id: REQ-roadmap-phase2-capture-tools
      category: privacy
      status: unverified
      flagged: true
      statement: "MUST NOT capture or record any screen content beyond the tracked Simulator window — display-wide content filters, full-desktop capture, or output containing the user's desktop, other windows, or BoosterSimApp's own floating panel are forbidden (the scaffold's display-filter defect is being rewritten away)"
    - requirement_id: REQ-roadmap-phase2-capture-tools
      category: privacy
      status: unverified
      flagged: true
      statement: "MUST NOT retain captured content beyond the user-requested output — temp intermediates are deleted after every save, no disk cache or cloud upload of captures exists, and the clipboard receives captures only when the user explicitly selects that destination"
    - requirement_id: REQ-roadmap-phase2-capture-tools
      category: values
      status: unverified
      flagged: true
      statement: "MUST NOT bundle third-party device-frame artwork without a verified license — v1 ships Simulator-native and CoreGraphics-drawn bezel modes only (research A1 keeps photoreal assets deferred)"
  flagged_assumptions:
    - requirement_id: REQ-roadmap-phase2-capture-tools
      probe: research-A4
      status: unresolved
      statement: "Desktop-independent window capture includes titlebar pixels; SCStreamFrameInfo.contentRect + scaleFactor handling strips them cleanly — verified visually at the Task 3 checkpoint; if chrome remains, add the crop fallback inside CaptureCompositor before Task 3 passes"
---

<objective>
Tracer slice: prove the Phase 2 capture architecture end-to-end with ONE story — a framed screenshot.

Wire a single vertical path through every layer this phase touches: Capture tab button (CaptureTabView) → CaptureService (rewritten as a slim sync Combine facade over async internals) → ScreenshotService (SCScreenshotManager one-shot with SCContentFilter(desktopIndependentWindow:) matched to the tracked CGWindowID) → CaptureCompositor (pure CoreGraphics ASC-preset/bezel/background compositing) → save to ~/Desktop/BoosterSim Captures/ → CaptureThumbnailPanel (borderless floating NSPanel, 3s auto-hide).

This tracer ships the shared engine, not just one shot: the three capture option models (ASCFramePreset with Apple's exact pixel table, BezelMode, CaptureDestination), the fully unit-testable compositor (Wave 0 CaptureFramingTests), the TCC permission-degradation flow (preflight → setup UX → quit-and-reopen prompt), and the AppLogger capture category. Plans 02 (recording + touch indicators) and 03 (GIF/MP4/MOV export) expand on this proven slice without architectural change.

Purpose: RESEARCH.md audits the existing 312-LOC CaptureService as a defective scaffold (whole-desktop filter, unbounded frame array, 15 fps cap, no screenshot path, no thumbnail). The rewrite splits it into small units per the 200-LOC house limit; this tracer proves the SCK acquisition + compositing + output spine before recording/export build on it.
Output: 7 new source files, 3 modified files, 1 Wave 0 Swift Testing file, one green live-screenshot smoke on a booted Simulator.
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

Source-of-truth analogs (read before writing each file — PATTERNS.md carries near-verbatim excerpts):
@BoosterSimApp/Services/CaptureService.swift
@BoosterSimApp/Services/DeepLinkService.swift
@BoosterSimApp/Services/NetworkConditionService.swift
@BoosterSimApp/Services/PermissionManager.swift
@BoosterSimApp/Windows/AXHighlightPanel.swift
@BoosterSimApp/Windows/PositionCalculator.swift
@BoosterSimApp/Views/SideWindow/network/NetworkConditionsSectionView.swift
@BoosterSimApp/Models/AppSettings.swift
@BoosterSimApp/Utilities/DesignTokens.swift
@BoosterSimApp/Utilities/AppLogger.swift
@BoosterSimAppTests/ConditionVerdictTests.swift
</context>

<tasks>

<task type="tracer" tdd="true">
  <name>Task 1: One-shot screenshot end-to-end — models, compositor, SCScreenshotManager, facade, thumbnail panel</name>
  <files>
    BoosterSimApp/Models/ASCFramePreset.swift,
    BoosterSimApp/Models/BezelMode.swift,
    BoosterSimApp/Models/CaptureDestination.swift,
    BoosterSimApp/Utilities/CaptureCompositor.swift,
    BoosterSimApp/Services/ScreenshotService.swift,
    BoosterSimApp/Services/CaptureService.swift,
    BoosterSimApp/Windows/CaptureThumbnailPanel.swift,
    BoosterSimApp/Views/SideWindow/tabs/CaptureTabView.swift,
    BoosterSimApp/App/AppDelegate.swift,
    BoosterSimApp/Utilities/AppLogger.swift,
    BoosterSimAppTests/CaptureFramingTests.swift
  </files>
  <read_first>
    - .planning/phases/02-capture-tools/02-RESEARCH.md (Patterns 2, 4, 5; Pitfalls 1, 2, 4, 7, 10; Recommended Project Structure; Security Domain)
    - .planning/phases/02-capture-tools/02-PATTERNS.md (every file above has an assigned analog with excerpts and drift guards)
    - BoosterSimApp/Services/CaptureService.swift (the 312-LOC scaffold being rewritten: SCK setup at lines 82–116, non-isolated delegate wrappers at 291–312)
    - BoosterSimApp/Services/DeepLinkService.swift lines 50–52 (sync facade over Task { await } bridge — the documented CONVENTIONS exception)
    - BoosterSimApp/Services/NetworkConditionService.swift lines 51–62 (modern @MainActor + @Published private(set) service shell)
    - BoosterSimApp/Services/PermissionManager.swift lines 51–76 (CGPreflightScreenCaptureAccess / CGRequestScreenCaptureAccess + 1s grant poll)
    - BoosterSimApp/Windows/AXHighlightPanel.swift lines 29–42 + scheduleDismiss ~55–60 (borderless panel config + timer dismiss)
    - BoosterSimApp/Windows/PositionCalculator.swift (caseless-enum pure utility style with /// doc comments)
    - BoosterSimApp/Views/SideWindow/network/NetworkConditionsSectionView.swift (CollapsibleSection composition, pill pickers, Reduce Motion 0.1s linear)
    - BoosterSimApp/Views/SideWindow/tabs/CaptureTabView.swift (mount point, existing Task-bridge button shape, flagged raw layout values at lines ~96/109/114)
    - BoosterSimApp/Models/AppSettings.swift lines 9–37 (enum raw-value presentation + @AppStorage key style)
    - BoosterSimApp/Utilities/AppLogger.swift lines 8–14 and BoosterSimApp/Utilities/DesignTokens.swift
    - BoosterSimAppTests/ConditionVerdictTests.swift (Swift Testing struct + private builders + MARK groups)
    - AGENTS.md GitNexus section — run gitnexus_impact upstream on CaptureService before the rewrite (live-wired in AppDelegate, SideWindowController, CaptureTabView, SideWindowView #Preview) and report blast radius
  </read_first>
  <behavior>
    - CaptureFramingTests: ASCFramePreset table — all eight pixel sizes exact per Apple's spec: 6.9-inch 1320x2868, 1290x2796, 1260x2736; 6.5-inch 1284x2778, 1242x2688; iPad 13-inch 2064x2752, 2048x2732 (portrait)
    - CaptureFramingTests: frame(content:preset:padding:mode:) — contentRect is centered with rounded origin, lies inside the padding-inset canvas, and scale equals min(availWidth/contentWidth, availHeight/contentHeight)
    - CaptureFramingTests: no-stretch invariant — contentRect aspect equals content aspect within 0.01 for tall, wide, and square inputs (uniform scale only)
    - CaptureFramingTests: render() output is opaque — the returned CGImage bitmap reports no alpha channel for an input with transparency (ASC rejects alpha)
    - CaptureFramingTests: drawn-bezel geometry — the bezel cutout insets the contentRect symmetrically on all sides and the content scale stays uniform
  </behavior>
  <action>
    NOTE: tracer by design — one path only (screenshot → Desktop → thumbnail); recording/export/clipboard/custom-path arrive in later plans/tasks. Every file under 200 LOC per docs/code-standards.md. Write CaptureFramingTests.swift FIRST (Swift Testing, red), then implement green. New files join the BoosterSimApp target automatically via the pbxproj's synchronized filesystem groups (STATE.md Phase 5 decision) — no project edit; the build in verify proves membership.

    BoosterSimAppTests/CaptureFramingTests.swift (new): struct CaptureFramingTests with private CGSize/CGRect builders and MARK-grouped @Test funcs covering the five behavior bullets above. Pure logic only — the compositor must be testable headless with zero mocks.

    BoosterSimApp/Models/ASCFramePreset.swift (new): enum ASCFramePreset: String, CaseIterable with one case per Apple ASC size (eight cases), computed pixelSize: CGSize carrying the exact table values, displayName: String, and a deviceFamily classification (iphone69 / iphone65 / ipad13). Raw values are persistence keys — choose stable names once (renaming strands stored selections, NetworkConditionService init-doc precedent).

    BoosterSimApp/Models/BezelMode.swift (new): enum BezelMode: String, CaseIterable with cases none, simulatorNative, drawn and computed label; plus sibling enum CaptureBackground: String, CaseIterable with cases solid, gradient, computed label and color resolution using semantic design-token colors (this file owns the compositing-option models; the renderer stays in the compositor).

    BoosterSimApp/Models/CaptureDestination.swift (new): enum CaptureDestination: Equatable in the CertificateModels associated-value style — cases desktop, clipboard, custom(URL), ask — with computed label and a static defaultDesktopFolder resolving ~/Desktop/BoosterSim Captures/ (created on demand via FileManager).

    BoosterSimApp/Utilities/CaptureCompositor.swift (new): caseless enum CaptureCompositor (PositionCalculator style: static funcs, /// doc comments with parameter lists, MARK order). Imports Foundation and CoreGraphics ONLY — keep it free of ScreenCaptureKit and AppKit dependencies so the framing tests run headless. struct FramingResult: Equatable with canvas: CGSize, contentRect: CGRect, scale: CGFloat. static func frame(content:preset:padding:mode:) -> FramingResult implementing the RESEARCH Pattern 4 math (avail = canvas minus 2x padding, scale = min of the two ratios, scaled size rounded down, centered rounded origin). static func render(content: CGImage, preset: ASCFramePreset, bezel: BezelMode, background: CaptureBackground, padding: CGFloat) -> CGImage: fill solid or vertical-gradient background, rounded-rect clip for the drawn-bezel silhouette, draw the content into contentRect with CGContext interpolation, always flatten to an opaque sRGB bitmap (drop the alpha channel — ASC rejects transparency, Pitfall 7).

    BoosterSimApp/Services/ScreenshotService.swift (new): @MainActor final class ScreenshotService with enum CaptureError: Error (windowNotFound, screenRecordingDenied, captureFailed(String)) and func capture(windowID: CGWindowID, windowFrame: CGRect) async throws -> CGImage. Implementation per RESEARCH Pattern 2: SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true), match content.windows by windowID against the tracked CGWindowID, add a DEBUG assertion that the matched SCWindow bundleIdentifier belongs to Simulator (Pitfall 1 self-capture guard), build SCContentFilter(desktopIndependentWindow:) — never the display-based filter form — then SCStreamConfiguration with width/height = Int(windowFrame dimensions) * 2 (Retina window output per Apple sample; no display-based fudge), scalesToFit = false, showsCursor = false, ignoreShadowsSingleWindow = true, captureResolution = .best, and finish with SCScreenshotManager.captureImage(contentFilter:configuration:). The async bridge lives INSIDE this capture service only (documented CONVENTIONS exception; ScreenshotService and RecordingService are capture services — no other new unit may adopt async).

    BoosterSimApp/Services/CaptureService.swift (rewrite, stays under 200 LOC): @MainActor final class CaptureService: ObservableObject — slim facade in the NetworkConditionService shell shape. @Published private(set): permissionGranted: Bool, isCapturing: Bool, lastError: String?, lastSavedURL: URL?. Injected via init: ScreenshotService, CaptureThumbnailPanel, and PermissionManager for the permission poll. Public methods synchronous, bridging through Task { await ... } (DeepLinkService pattern): takeScreenshot(), and the settings accessors the tab binds (selectedPreset, bezelMode, background, destination — persisted via AppSettings once Task 2 adds the keys; session @Published is fine for the tracer). takeScreenshot flow: preflight CGPreflightScreenCaptureAccess — when false, set a published permissionDenied state and return (never throw at the UI); when true: isCapturing → capture(windowID:frame:) using the tracked Simulator window (SimulatorWindowTracker) → CaptureCompositor.render with selected options → encode PNG → write to the Desktop destination folder using filename builder captureFilename(device:preset:date:) ("BoosterSim-" + sanitized device + "-" + preset raw + "-" + yyyyMMdd-HHmmss timestamp + ".png") → CaptureThumbnailPanel.show(url:) → clear isCapturing. Delete the scaffold's stream lifecycle, frame-accumulation array, hand-rolled writer loop, and exportAsGIF block entirely — git history preserves them; do not leave a comment mentioning the removed symbols (cutover, not deprecation). Handle the TCC restart gotcha (Pitfall 2): when permission flips granted during the poll, publish a needsRelaunch hint; on next launch re-preflight before enabling capture controls. All logging through AppLogger.capture with redaction — never the output path, UDIDs, or any screen-content description.

    BoosterSimApp/Windows/CaptureThumbnailPanel.swift (new): final class CaptureThumbnailPanel: NSPanel copying the AXHighlightPanel configuration verbatim (styleMask [.borderless, .nonactivatingPanel], isOpaque false, backgroundColor .clear, level .floating, collectionBehavior [.canJoinAllSpaces, .fullScreenAuxiliary], isReleasedWhenClosed false) with exactly three behavioral divergences per PATTERNS: ignoresMouseEvents = false (clickable), contentView = NSImageView proportionally scaled with CornerRadius.large mask + shadow, and Timer auto-hide at 3.0 seconds (scheduleDismiss pattern). Click action NSWorkspace.shared.activateFileViewerSelecting([url]). Anchor near the tracked Simulator frame's trailing edge; sizing via DesignTokens only. Reduce Motion: crossfade, no slide.

    BoosterSimApp/Views/SideWindow/tabs/CaptureTabView.swift (rewrite body): compose from CollapsibleSection(title:icon:) blocks (NetworkConditionsSectionView pattern) with private computed sub-views: a Screenshot section (ASC preset pill picker, bezel picker, background picker, Capture button with camera SF Symbol calling the facade, status caption rows driven by service state including the permission-degraded setup view with quit-and-reopen prompt). Replace the three flagged raw layout values at current lines ~96/109/114 with Spacing / CornerRadius tokens (conventions.md names this file as the deviation to fix). Keep the file under 200 LOC via private computed vars; reusable atoms go to Views/Shared/ only if genuinely shared.

    BoosterSimApp/App/AppDelegate.swift (modify): add lazy var captureThumbnailPanel = CaptureThumbnailPanel() beside axHighlightPanel, and construct captureService with its dependencies (ScreenshotService() + the panel). The existing SideWindowController → .environmentObject(captureService) wiring is unchanged — no signature change.

    BoosterSimApp/Utilities/AppLogger.swift (modify): add one line in the existing style — static let capture = Logger(subsystem: subsystem, category: "Capture") — matching the aligned-column formatting of neighbors.
  </action>
  <verify>
    <automated>xcodebuild -project BoosterSimApp.xcodeproj -scheme BoosterSimApp -destination 'platform=macOS' test -only-testing:BoosterSimAppTests/CaptureFramingTests && xcodebuild -project BoosterSimApp.xcodeproj -scheme BoosterSimApp -configuration Debug build</automated>
  </verify>
  <acceptance_criteria>
    - BoosterSimAppTests/CaptureFramingTests.swift exists, imports Testing, uses @Test funcs with #expect, and asserts the eight exact ASC pixel sizes (1260x2736, 1290x2796, 1320x2868, 1242x2688, 1284x2778, 2048x2732, 2064x2752) plus the framing, no-stretch, opaque-output, and bezel-geometry behaviors
    - CaptureCompositor.swift declares enum CaptureCompositor with static frame(...) and static render(...), and the string "import ScreenCaptureKit" occurs in it zero times
    - ScreenshotService.swift references SCScreenshotManager.captureImage and SCContentFilter(desktopIndependentWindow: and the display-filter initializer spelling occurs in it zero times
    - CaptureService.swift is at or under 200 lines, declares @MainActor final class CaptureService: ObservableObject with a synchronous takeScreenshot() that contains no direct await (bridged inside Task blocks), and the tokens CMSampleBuffer and AVAssetWriter occur in it zero times
    - CaptureThumbnailPanel.swift sets styleMask [.borderless, .nonactivatingPanel], level .floating, isReleasedWhenClosed false, ignoresMouseEvents false, and a 3.0 auto-hide timer
    - AppLogger.swift contains static let capture with category "Capture"
    - CaptureTabView.swift raw layout literals (.padding( with bare integer 8 or 12, .cornerRadius( with bare integer 6) occur zero times outside comments — Spacing/CornerRadius tokens are used
    - Both xcodebuild commands exit 0
  </acceptance_criteria>
  <reversibility rating="costly">CaptureService public API changes with d=1 callers (AppDelegate, SideWindowController, CaptureTabView, SideWindowView #Preview) and the defective scaffold is deleted — git-recoverable, but the facade shape and the persistence-bound enum raw values set the contract plans 02/03 build on; flagged only, no checkpoint.</reversibility>
  <done>One green vertical path: Capture button produces an ASC-preset-sized, alpha-free PNG of only the Simulator window on the Desktop with a 3s floating thumbnail; CaptureFramingTests green; app builds; the defective scaffold is fully cut over.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: Capture settings persistence, filename builder, clipboard + custom-path destinations</name>
  <files>
    BoosterSimApp/Models/AppSettings.swift,
    BoosterSimApp/Services/CaptureService.swift,
    BoosterSimApp/Views/SideWindow/tabs/CaptureTabView.swift,
    BoosterSimAppTests/CaptureSettingsTests.swift
  </files>
  <read_first>
    - .planning/phases/02-capture-tools/02-PATTERNS.md (AppSettings + CaptureSettingsTests assignments, StorageKey alternative)
    - BoosterSimApp/Models/AppSettings.swift (existing @AppStorage block lines 33–37 — extend, do not restructure)
    - BoosterSimApp/Services/NetworkConditionService.swift StorageKey + injected-UserDefaults pattern (lines 56–99) for the custom-path URL
    - BoosterSimAppTests/NetworkConditionServiceTests.swift lines 5–51 (makeDefaults isolated suite + defer removePersistentDomain + re-init round-trip)
    - .planning/phases/02-capture-tools/02-RESEARCH.md section F (Outputs) and threat T-02-05 (filename sanitization)
    - The Task 1 versions of CaptureService.swift and CaptureTabView.swift
  </read_first>
  <behavior>
    - CaptureSettingsTests: every capture key (destination, ASC preset, bezel mode, background, export format, GIF size, GIF fps, touch indicators) round-trips through an isolated UserDefaults suite — write on one AppSettings instance, re-init from the same suite, values re-apply
    - CaptureSettingsTests: captureFilename(device:preset:date:) sanitizes path-unsafe characters — a device string containing slash, colon, or spaces yields a filename containing none of them (hyphen-separated components only), stays deterministic for identical inputs, and differs when the date advances (timestamped uniqueness)
    - CaptureSettingsTests: the custom-path directory persists as a plain string path via the StorageKey pattern and survives re-init (non-sandboxed app, REQ-nfr-04 — no bookmark dance)
  </behavior>
  <action>
    Write CaptureSettingsTests.swift first (red) using the makeDefaults() isolated-suite helper — never UserDefaults.standard. Then:

    BoosterSimApp/Models/AppSettings.swift (modify): append the capture @AppStorage keys following the existing RawRepresentable-String enum style: captureDestination, captureASCFramePreset, captureBezelMode, captureBackground, captureExportFormat, captureGIFSize (Int, default 480), captureGIFFps (Int, default 10), captureShowTouchIndicators (Bool, default false). For the custom-path URL use the NetworkConditionService StorageKey + injected UserDefaults string-path pattern instead of forcing the type into @AppStorage. Raw values are persistence keys — final names now.

    BoosterSimApp/Services/CaptureService.swift (modify): move the tracer's session @Published options onto AppSettings-backed storage; add pure static func captureFilename(device:preset:date:) -> String with an allowlist sanitizer (alphanumeric + hyphen; every other character collapses to a single hyphen) — the mitigation for threat T-02-05. Complete destination routing func route(pngData:filename:suggestedURL:): desktop writes into the capture folder (timestamped name — a second capture never touches the first), clipboard clears and writes NSPasteboard .png data (user-selected destination only, threat T-02-03), custom path opens NSSavePanel via begin(completionHandler:) with the persisted directory and pre-populated name field — the modal runModal variant is the anti-pattern being replaced (RESEARCH Anti-Patterns), ask begins the panel each time. Delete any intermediate temp file after the destination write (retention rule).

    BoosterSimApp/Views/SideWindow/tabs/CaptureTabView.swift (modify): destination picker section — pill picker for Desktop / Clipboard / Custom / Ask, a reveal row for the chosen custom folder, and captions reflecting the active destination; bind through AppSettings.
  </action>
  <verify>
    <automated>xcodebuild -project BoosterSimApp.xcodeproj -scheme BoosterSimApp -destination 'platform=macOS' test -only-testing:BoosterSimAppTests/CaptureSettingsTests -only-testing:BoosterSimAppTests/CaptureFramingTests</automated>
  </verify>
  <acceptance_criteria>
    - CaptureSettingsTests.swift exists, imports Testing, builds its own UserDefaults suite via makeDefaults-style helper (UserDefaults.standard is referenced zero times), and covers the eight-key round-trip, filename sanitization + timestamp uniqueness, and custom-path persistence
    - AppSettings.swift declares the eight capture @AppStorage keys plus a StorageKey-based custom-path accessor
    - CaptureService.swift references NSPasteboard and NSSavePanel with begin(completionHandler:), and the runModal token occurs in it zero times
    - The test command exits 0
  </acceptance_criteria>
  <reversibility rating="costly">The @AppStorage key strings and enum raw values become user defaults keys on first release — renaming after ships strands stored selections; choose final names in this task.</reversibility>
  <done>All capture options persist across relaunch; clipboard and custom-path destinations work through the shared routing; filename builder is sanitized and timestamp-unique (idempotency truth); CaptureSettingsTests green.</done>
</task>

<task type="checkpoint:human-verify" gate="blocking-human">
  <name>Task 3: Smoke the tracer on a live Simulator — framed screenshot, thumbnail, destinations, permission cycle</name>
  <files>none</files>
  <read_first>
    - .planning/phases/02-capture-tools/02-VALIDATION.md (Manual-Only Verifications rows for live screenshot, thumbnail, clipboard/Desktop/custom save, permission-denied degradation)
    - .planning/phases/02-capture-tools/02-RESEARCH.md Pitfall 2 (TCC restart), Pitfall 4 (chrome/contentRect — flagged assumption A4), Pitfall 7 (alpha)
  </read_first>
  <action>
    Blocking human checkpoint — the tracer's end-to-end proof needs a booted Simulator, a real TCC state cycle, and WindowServer (research marks live SCScreenshotManager manual-only). Prerequisites (user_setup): BoosterSimApp running; one booted 6.9-inch-class Simulator with its window open; Screen Recording permission first DENIED, then granted. Execute the eight steps in how-to-verify, recording per-step pass/fail. Step 5 is the flagged-assumption A4 check: if Simulator title-bar chrome appears in the framed output, do NOT approve — file the CaptureCompositor crop fallback as a follow-up edit in this plan before approval. Step 2 verifies the degraded UX (setup view shown, no crash); step 3 exercises Apple's grant-requires-restart cycle through the in-app prompt.
  </action>
  <verify>
    <human-check>All eight smoke steps observed and recorded pass/fail in the summary; specifically the saved PNG is exactly the selected preset's pixel size with no alpha channel, contains only Simulator window content, and the thumbnail appears then auto-hides at ~3s.</human-check>
  </verify>
  <acceptance_criteria>
    - Summary contains a per-step pass/fail record for the 8 smoke steps
    - Denied-permission state shows setup UX with no crash; grant + quit/reopen recovers capture (steps 2–3)
    - Output PNG dimensions equal the selected ASC preset exactly, with no alpha channel and no desktop/panel/title-bar pixels (steps 4–5)
    - Thumbnail shows ~3s and reveals in Finder on click (step 6); clipboard paste and custom-path save both produce valid PNGs (step 7); two captures leave two independent files (step 8)
  </acceptance_criteria>
  <what-built>The Phase 2 screenshot spine wired end-to-end: CaptureTabView button → CaptureService sync facade (TCC preflight + degraded UX + quit-and-reopen prompt) → ScreenshotService (SCScreenshotManager, desktopIndependentWindow filter) → CaptureCompositor (ASC preset + bezel + background, alpha-flattened) → destination routing (Desktop/clipboard/custom/ask, sanitized timestamped filenames) → CaptureThumbnailPanel (3s auto-hide, click-to-reveal). CaptureFramingTests and CaptureSettingsTests green; AppSettings carries the eight capture keys; app builds.</what-built>
  <how-to-verify>
    With BoosterSimApp running and one booted Simulator (6.9-inch class):
    1. Confirm the panel tracks the Simulator window and the Capture tab shows the screenshot section
    2. With Screen Recording denied/revoked: click Capture — setup/permission view appears, no crash, no file written
    3. Grant Screen Recording in System Settings; the app prompts to quit and reopen — do so; capture controls become enabled
    4. Select preset 1320x2868 and click Capture — a PNG appears in ~/Desktop/BoosterSim Captures/ whose dimensions are exactly 1320x2868 and which has no alpha channel (Get Info / Preview export check)
    5. Inspect the image content — only the Simulator window on the chosen background; no Mac desktop, no BoosterSimApp panel, no title-bar chrome strip (chrome present = assumption A4 failed, file crop fallback)
    6. The floating thumbnail appears near the Simulator, auto-hides after ~3s, and clicking it reveals the file in Finder
    7. Switch destination to Clipboard and capture — paste into Preview works as PNG; switch to Custom path, pick a folder via the save panel — the file exists there
    8. Capture twice in a row — two distinct timestamped files, both intact
  </how-to-verify>
  <resume-signal>Reply "approved" to unblock wave 2 (plan 02 recording), or describe the failing step — chrome contamination or alpha failures require a compositor fix inside this plan before expansion proceeds.</resume-signal>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| Simulator window content → BoosterSimApp capture pipeline | Screen pixels cross from WindowServer into the app; TCC Screen Recording is the gate |
| BoosterSimApp → user filesystem / clipboard | Output files and clipboard writes land in user-controlled space |
| Untrusted strings (device names) → file paths | Filename construction from Simulator-provided device strings |

## STRIDE Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation Plan |
|-----------|----------|-----------|----------|-------------|-----------------|
| T-02-01 | Information Disclosure | Captured screen content (screenshots/recordings) | high | mitigate | TCC preflight gates every capture control; SCContentFilter(desktopIndependentWindow:) scopes capture to the tracked window only (display filter is the rewritten-away defect); auto-hiding 3s thumbnail; no disk cache beyond requested output; AppLogger.capture redacts paths/UDIDs/content |
| T-02-04 | Information Disclosure | Temp/output files with screen content left behind | high | mitigate | Desktop/custom destinations are user-chosen; any intermediate temp file is deleted inside the destination routing; compositor renders in memory; plan 03 adds the boostersim-capture-* launch sweep |
| T-02-05 | Tampering | Filename builder (device strings into paths) | medium | mitigate | Allowlist sanitizer (alphanumeric + hyphen) with unit tests; writes confined to the fixed Desktop capture folder or NSSavePanel-governed locations (ASVS V5) |
| T-02-03 | Information Disclosure | Clipboard exfiltration | medium | mitigate | Clipboard writes happen only when the user explicitly selects the clipboard destination; UI copy documents the behavior |
| T-02-SC | Tampering | Package installs | high | mitigate | Zero package installs this phase — Apple frameworks only (REQ-nfr-03); no SPM change, verified by an empty git diff on the swiftpm workspace share at the phase gate (plan 04) |
</threat_model>

<verification>
- Task 1/2 automated: CaptureFramingTests and CaptureSettingsTests green via the plan's xcodebuild commands; app scheme Debug build clean (synchronized groups prove target membership).
- Task 3: blocking human smoke on a live Simulator (8 steps) — the only honest end-to-end check of criterion 1 and the TCC degradation flow (research marks live SCK capture manual-only).
- No SPM/pbxproj package changes this plan.
</verification>

<success_criteria>
- The 6 must_haves truths hold; specifically the live-screenshot proof (preset-exact dimensions, no alpha, window-scoped content, thumbnail, permission cycle) is observed on a live Simulator.
- Both Wave 0 test files (CaptureFramingTests, CaptureSettingsTests) green; app builds; scaffold cutover complete (no frame accumulation, no writer loop, no display filter).
- Architecture proven well enough that plan 02 (recording) and plan 03 (export) are additive, not architectural.
</success_criteria>

## Artifacts this phase produces

Created by THIS plan (new symbols):
- ASCFramePreset (8 cases, pixelSize/displayName/deviceFamily) — BoosterSimApp/Models/ASCFramePreset.swift
- BezelMode, CaptureBackground — BoosterSimApp/Models/BezelMode.swift
- CaptureDestination (desktop/clipboard/custom(URL)/ask) — BoosterSimApp/Models/CaptureDestination.swift
- CaptureCompositor (frame/render), FramingResult — BoosterSimApp/Utilities/CaptureCompositor.swift
- ScreenshotService (+ CaptureError) — BoosterSimApp/Services/ScreenshotService.swift
- CaptureThumbnailPanel — BoosterSimApp/Windows/CaptureThumbnailPanel.swift
- AppLogger.capture category — BoosterSimApp/Utilities/AppLogger.swift
- Tests: CaptureFramingTests, CaptureSettingsTests

Modified: CaptureService (rewritten slim facade: takeScreenshot, permission state, destination routing, captureFilename), CaptureTabView (rewritten sections), AppSettings (8 capture keys + custom-path StorageKey), AppDelegate (thumbnail panel + service construction).

Later plans add: RecordingService + TouchIndicatorController + RecordingState (02), CaptureExporter + export formats (03), docs + phase gate (04).

<output>
Create `.planning/phases/02-capture-tools/02-01-SUMMARY.md` when done
</output>
