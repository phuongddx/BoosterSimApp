---
phase: 04-design-tools
plan: 03
type: execute
wave: 3
depends_on: ["04-02"]
files_modified:
  - BoosterSimApp/Services/PixelSamplerService.swift
  - BoosterSimApp/Services/DesignOverlayService.swift
  - BoosterSimApp/Views/Overlay/RulerOverlayView.swift
  - BoosterSimApp/Views/Overlay/MagnifierView.swift
  - BoosterSimApp/Views/SideWindow/DesignComparisonView.swift
  - BoosterSimApp/Windows/DesignOverlayController.swift
  - BoosterSimApp/App/AppDelegate.swift
  - BoosterSimApp/Utilities/DesignTokens.swift
  - BoosterSimAppTests/PixelSamplerTests.swift
autonomous: true
requirements:
  - REQ-roadmap-phase4-design-tools
estimate:
  tokens: 40000
  raw_tokens: 40000
  tasks: 3
  confidence: low

must_haves:
  truths:
    - "With a booted Simulator, arming the ruler from the Design tab flips the overlay into capture mode (click-through off), click-drag draws a measurement line with endpoint markers and a live distance readout in DEVICE points via OverlayGeometry, and commit or Esc returns the overlay to click-through without the Simulator ever losing key focus"
    - "Arming the magnifier shows a hover-follow loupe zooming the Simulator content around the cursor from a single cached ScreenCaptureKit capture (one capture per arming — no per-move captures), with a color swatch + live hex readout; clicking commits the picked color into the Design tab's picker section (hex/RGB strings + copy)"
    - "Sampled colors are the correct pixel: window-point → CGImage-pixel mapping flips Y against the frame height and multiplies by the display backing scale (correct on 1x external displays, not just Retina)"
    - "When Screen Recording permission is denied or no Simulator is tracked, arming any sampling tool degrades with an honest caption and issues no capture"
    - "The loupe reads memory-only cached pixels; nothing sampled, cropped, or cached is written to disk or logged, and both global event monitors are removed on disarm and on controller deinit"
    - "Ruler/magnifier readouts render at the .interactive layer — above the comparison image, below grid/safe-area guides (D-04)"
  artifacts:
    - BoosterSimApp/Services/PixelSamplerService.swift
    - BoosterSimApp/Views/Overlay/RulerOverlayView.swift
    - BoosterSimApp/Views/Overlay/MagnifierView.swift
    - BoosterSimAppTests/PixelSamplerTests.swift
  key_links:
    - "AppDelegate lazy var pixelSamplerService = PixelSamplerService(screenshotService: ScreenshotService(), tracker: tracker) (stateless ScreenshotService constructed inline, the captureService precedent at AppDelegate.swift:29-34) → applicationDidFinishLaunching call designOverlayController.attach(to:service:pixelSampler:) → controller stored property — the sampler's construction/injection seam (Task 2): the controller receives the sampler together with its tracker/screenshot dependencies at attach, never constructs one itself"
    - "DesignComparisonView arm buttons → DesignOverlayService isRulerArmed/isMagnifierArmed @Published → DesignOverlayController input-mode reaction → panel.setCaptureMode(true) + PixelSamplerService.arm() → ScreenshotService.capture(windowID:frame:) (the sanctioned async bridge, CaptureService shape) → cached CGImage"
    - "Global NSEvent.addGlobalMonitorForEvents(.mouseMoved) (armed only) + panel-local mouse events → controller → window-point → OverlayGeometry.imagePixel → PixelSamplerService.sampleColor(at:) → MagnifierView loupe / pickedColor commit"
    - "PixelSamplerService.sampleColor(at:) + OverlayGeometry.imagePixel — the single tested mapper; no other code path converts window points to capture pixels (Pitfall 2)"
  prohibitions:
    - requirement_id: REQ-roadmap-phase4-design-tools
      category: privacy
      status: unverified
      flagged: true
      verification: test
      statement: "MUST NOT persist or leak captured Simulator content — the cached CGImage stays memory-only for the lifetime of an arming (cleared on disarm), is never written to disk, never included in AppLogger output (verbs + outcomes only), and the global mouse-monitor is removed on every disarm path and in deinit (no ambient cursor tracking after the tool closes)"
  flagged_assumptions:
    - requirement_id: REQ-roadmap-phase4-design-tools
      probe: research-A5
      status: unresolved
      statement: "Cached-capture freshness is acceptable for the loupe: one capture per arming, re-captured on re-arm and on tracked-frame change; Simulator content changing mid-hover shows stale pixels until the next re-arm. Closes at the 04-04 smoke (the loupe step)."
    - requirement_id: REQ-roadmap-phase4-design-tools
      probe: concurrency
      status: unresolved
      statement: "UNRESOLVED EDGE (probe: 'If interrupted or run in parallel, what is guaranteed?') — arm/disarm/state are @MainActor-serialized with the capture Task bridge hopping back to the main actor; disarming while a capture is in flight must discard the late result (guarded by an arming-generation token or equivalent), and frame updates during capture mode only re-apply geometry. Unit-lock the late-result discard in PixelSamplerTests where synthesizable; the rest closes at the 04-04 smoke."
    - requirement_id: REQ-roadmap-phase4-design-tools
      probe: research-pitfall-4
      status: unresolved
      statement: "Capture-mode key/focus handling: .nonactivatingPanel + becomesKeyOnlyIfNeeded + local keyDown monitor for Esc (keyCode 53) keeps the Simulator focused; verified visually at the 04-04 smoke (warning sign per RESEARCH: Simulator title bar greying when arming a tool)."
---

<objective>
Deliver success criterion 2: interactive pixel inspection over the Simulator — the ruler with device-point distance measurement and the magnifier loupe with click-to-commit color picking.

Task 1 ships PixelSamplerService: the cached-capture sampler riding the sanctioned async exception (CaptureService's sync-facade → single Task bridge → TCC-preflight shape) over the Phase 2 ScreenshotService, with the tested point→pixel mapper and main-actor-serialized arm/disarm. Task 2 adds the ruler and the sampler injection seam (AppDelegate lazy var pixelSamplerService → controller attach): capture-mode input on the panel (the 04-01 setCaptureMode seam), drag-measure with a live device-point readout, Esc-cancel via a local event monitor, D-04 .interactive layer placement. Task 3 adds the magnifier: hover-follow loupe fed by a global mouseMoved monitor (observe-only, no event taps), 8x default adjustable zoom, click-to-commit pickedColor, and the side-panel picker section (hex/RGB via the kept scaffold helpers + clipboard copy via the kept seed).

Purpose: this is the only interactive surface of the phase and the only new async site — both ride seams the repo already proved (CaptureService/ScreenshotService; SideWindowController's key-monitor discipline). Everything the criterion needs as "real" (real screen pixels, not the deleted fake sampler) closes here.
Output: 2 new overlay views + 1 new service, 5 modified files, 1 new Swift Testing suite.
</objective>

<execution_context>
@~/.claude/gsd-core/workflows/execute-plan.md
@~/.claude/gsd-core/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/ROADMAP.md
@.planning/STATE.md
@.planning/phases/04-design-tools/04-CONTEXT.md
@.planning/phases/04-design-tools/04-RESEARCH.md
@.planning/phases/04-design-tools/04-PATTERNS.md
@.planning/phases/04-design-tools/04-VALIDATION.md
@.planning/phases/04-design-tools/04-01-overlay-grid-tracer-SUMMARY.md
@.planning/phases/04-design-tools/04-02-safearea-comparison-import-SUMMARY.md

Source analogs (PATTERNS.md carries near-verbatim excerpts; SUMMARYs record as-built deltas):
@BoosterSimApp/Services/CaptureService.swift
@BoosterSimApp/Services/ScreenshotService.swift
@BoosterSimApp/Services/DesignOverlayService.swift
@BoosterSimApp/Windows/DesignOverlayController.swift
@BoosterSimApp/Windows/DesignOverlayPanel.swift
@BoosterSimApp/Views/Overlay/GridOverlayView.swift
@BoosterSimApp/Utilities/DesignTokens.swift
@BoosterSimAppTests/CaptureFramingTests.swift
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: PixelSamplerService — cached-capture sampler, sanctioned Task bridge, tested pixel mapping, arm/disarm lifecycle</name>
  <files>
    BoosterSimApp/Services/PixelSamplerService.swift,
    BoosterSimAppTests/PixelSamplerTests.swift
  </files>
  <read_first>
    - .planning/phases/04-design-tools/04-RESEARCH.md — Pattern 3 (cached-capture sampling with the arm()/sampleColor skeleton), Pattern 4 (capture-mode input), Pitfall 2 (Y-flip/scale — one tested mapper), Pitfall 6 (second async site: copy the CaptureService shape EXACTLY, CONVENTIONS exemption list stays tiny), Pitfall 7 (1x displays), Don't Hand-Roll rows (ScreenshotService capture/pixelSize/backingScale — reuse, never re-derive; NSEvent global monitor over CGEvent taps), Security Domain (memory-only cache, window-scoped filter, TCC preflight)
    - .planning/phases/04-design-tools/04-PATTERNS.md — PixelSamplerService assignment (CaptureService.swift:127-135 sync-facade excerpt, CaptureService.swift:202-219 TCC preflight + tracked-window resolution excerpt, ScreenshotService.swift:38-68 + pixelSize/backingScale excerpts)
    - BoosterSimApp/Services/CaptureService.swift lines 120-140 (the sanctioned bridge shape), 200-220 (preflight/target resolution)
    - BoosterSimApp/Services/ScreenshotService.swift lines 38-100 (capture(windowID:windowFrame:) async internals, desktopIndependentWindow filter, pixelSize(for:scale:), backingScale(for:screens:))
    - The 04-01 as-built BoosterSimApp/Services/OverlayGeometry.swift (imagePixel signature — the mapper this service consumes, never re-implements)
    - BoosterSimAppTests/CaptureFramingTests.swift (Swift Testing + synthetic CGImage construction style for the sampling tests)
    - AGENTS.md GitNexus section — gitnexus_impact upstream on ScreenshotService BEFORE any touch (this plan should only CALL it; report if a signature change becomes tempting)
  </read_first>
  <behavior>
    - PixelSamplerTests: synthetic-image sampling — construct a small CGImage in-test (e.g. 4x4 pixels with known colors via CGContext), inject it into the sampler's cache through an internal seam, then sampleColor(at:) for window points whose mapped pixels are known: returns the exact injected color; a point mapping outside the image returns nil (no trap)
    - PixelSamplerTests: mapping correctness — for frameHeight 200 and scale 2.0, a window point at the TOP edge samples image row 0 and the BOTTOM edge samples the last row (Y-flip proof against a vertically graded synthetic image: distinct colors per row)
    - PixelSamplerTests: 1x display — scale 1.0 mapping stays correct (no doubled offsets)
    - PixelSamplerTests: late-result discard — completing an arm after disarm (simulated by invoking the internal result-handling with a stale generation token) leaves the cache empty and publishes nothing
    - PixelSamplerTests: degraded preflight — with permission preflight returning false (injectable seam or documented skip), arm() publishes the denied caption, issues no capture, and leaves state clean
  </behavior>
  <action>
    BoosterSimApp/Services/PixelSamplerService.swift (new): `@MainActor final class PixelSamplerService: ObservableObject` — init(screenshotService: ScreenshotService, tracker: SimulatorWindowTracker). Public sync API only (the CaptureService facade discipline): `func arm()` — guard CGPreflightScreenCaptureAccess() (on failure publish samplerError caption "Screen Recording permission required" and return; never prompt from here), guard tracker.activeSimulator non-nil (caption "No Simulator window is being tracked"), bump an arming generation counter, then ONE private `Task { [weak self] in ... }` bridge calling screenshotService.capture(windowID: sim.id, windowFrame: sim.frame); on completion, still-current generation + still armed → cache the CGImage (memory-only stored property), else discard. `func disarm()` — clears the cached image, increments the generation (late results discard), removes nothing itself (monitor ownership stays in the controller). `func sampleColor(at windowPoint: CGPoint) -> NSColor?` — sync, main-thread: guard cached image, map via OverlayGeometry.imagePixel(forWindowPoint: frameHeight: scale:) with the scale from ScreenshotService.backingScale, read the pixel via NSBitmapImageRep(cgImage:)/CGImage data-provider read — one code path, no per-move captures (Pitfall: per-move SCK rejected). Also `func sampleRegion(around:radius:)`-shaped internal helper returning the loupe crop (CGImage cropping via cropping(to:)) for MagnifierView. Log arm/disarm/sample outcomes via AppLogger.design — verbs and outcomes ONLY, never pixel values or image dimensions-bearing dumps. File target under 200 LOC: the mapper is OverlayGeometry's, the capture is ScreenshotService's — this service is lifecycle + cache only.

    BoosterSimAppTests/PixelSamplerTests.swift (new): Swift Testing house style; all behavior bullets via the internal seams (an `internal func handleCaptureResult(_:generation:)`-shaped seam and an injectable cache setter keep tests SCK-free and headless); synthetic CGImages built with CGContext in-file (CaptureFramingTests synthetic-builder style).
  </action>
  <verify>
    <automated>xcodebuild -project BoosterSimApp.xcodeproj -scheme BoosterSimApp -destination 'platform=macOS' test -only-testing:BoosterSimAppTests/PixelSamplerTests -only-testing:BoosterSimAppTests/RulerMathTests -parallel-testing-enabled NO</automated>
    <fails_when>non-zero exit, a "failed" marker in the Swift Testing run summary, or "Executed 0 tests" (an -only-testing filter matched no suite)</fails_when>
  </verify>
  <acceptance_criteria>
    - PixelSamplerService.swift is @MainActor final class with sync public API; the only asynchronous keyword occurrences in the file are inside the single private Task bridge (the CaptureService exemption shape); no view or controller ever touches the bridge
    - The service calls ScreenshotService.capture(windowID:windowFrame:) — no ScreenCaptureKit symbol and no deprecated CGWindowListCreateImage call appears in the file; no re-derived backing-scale constant (scale always from ScreenshotService.backingScale)
    - sampleColor maps exclusively through OverlayGeometry.imagePixel (no second Y-flip implementation anywhere in the file)
    - The cached CGImage lives in a private stored property with no file-write call and no FileManager reference in the file
    - PixelSamplerTests covers all five behavior bullets including late-result discard and denied-permission degradation; suite green on the command above
  </acceptance_criteria>
  <reversibility rating="costly">PixelSamplerService is the second sanctioned async site — CONVENTIONS names the exemption list deliberately (Phase 3 shrank it to CaptureService alone); adding this site is a documented exception future phases will copy, so the shape must be exact (STATE.md Pitfall 6).</reversibility>
  <done>Criterion 2's engine ships: real cached-capture pixel sampling with tested Y-flip/scale mapping, main-actor-serialized arm/disarm with late-result discard, and honest permission degradation — no per-move captures.</done>
</task>

<task type="auto">
  <name>Task 2: Ruler — capture-mode input on the panel, drag-measure with device-point readout, Esc cancel</name>
  <files>
    BoosterSimApp/Views/Overlay/RulerOverlayView.swift,
    BoosterSimApp/Windows/DesignOverlayController.swift,
    BoosterSimApp/Services/DesignOverlayService.swift,
    BoosterSimApp/App/AppDelegate.swift
  </files>
  <read_first>
    - .planning/phases/04-design-tools/04-RESEARCH.md — Pattern 4 (capture-mode input: ignoresMouseEvents flip + acceptsMouseMovedEvents + NSTrackingArea + local keyDown monitor for Esc; global monitors don't fire for own-app events), Pitfall 4 (focus/key handling: becomesKeyOnlyIfNeeded, never makeKey, orderFront only), D-04 layer placement
    - .planning/phases/04-design-tools/04-PATTERNS.md — RulerOverlayView assignment (no in-repo interactive analog — event-monitor add/remove discipline from SideWindowController's keyMonitor excerpt is the pattern), DesignOverlayController delta notes
    - The 04-01 as-built DesignOverlayPanel.swift (setCaptureMode seam) and DesignOverlayController.swift (install/sink shapes)
    - BoosterSimApp/Windows/SideWindowController.swift end-of-file keyMonitor (addLocalMonitorForEvents + removeMonitor in deinit — the discipline to copy)
    - The 04-01 as-built OverlayGeometry.swift (devicePoint + distance signatures)
  </read_first>
  <action>
    BoosterSimApp/Views/Overlay/RulerOverlayView.swift (new): `final class RulerOverlayView: NSView` — interactive (acceptsFirstMouse, mouseDown(canDrag:) captures the start point, mouseDragged updates the end point + live readout, mouseUp commits). Rendering in draw(_:): measurement line between start/end (converted to DEVICE points for the label via OverlayGeometry.devicePoint + OverlayGeometry.distance — the readout is device points, the criterion's "measure distances"), endpoint markers, and the readout as drawn text (NSAttributedString draw(at:) with a monospacedDigit font, background pill for legibility) offset from the line. Geometry injected as in GridOverlayView.

    BoosterSimApp/Windows/DesignOverlayController.swift (modify): add the input-mode state machine — `enum OverlayInputMode { case clickThrough, ruler, magnifier }`. React to service.isRulerArmed: arm → panel.setCaptureMode(true), mode = .ruler, install/enable ruler view at .interactive layer; disarm/commit/Esc → setCaptureMode(false), mode = .clickThrough. Esc handling: a local NSEvent.addLocalMonitorForEvents(matching: .keyDown) monitor (keyCode 53) installed on arm, removed on every disarm path AND in deinit (the SideWindowController keyMonitor discipline — no monitor leaks). Installs RulerOverlayView via panel.install(view, at: .interactive) — above .comparison, below .safeArea/.grid (D-04). Never makeKey — the panel takes mouse events in capture mode without activation (Pitfall 4); becomesKeyOnlyIfNeeded stays.
    Injection seam (resolves plan-checker W2 — who constructs the sampler, how the controller obtains it): BoosterSimApp/App/AppDelegate.swift (modify) — the lazy block gains `lazy var pixelSamplerService = PixelSamplerService(screenshotService: ScreenshotService(), tracker: tracker)` in the lazy-block style; ScreenshotService is stateless (ScreenshotService.swift:10-11 — no stored state), so inline construction matches the captureService precedent at AppDelegate.swift:29-34. The applicationDidFinishLaunching attach call shipped by 04-01 extends to `designOverlayController.attach(to: tracker, service: designOverlayService, pixelSampler: pixelSamplerService)`. In DesignOverlayController, extend the 04-01 attach signature to `attach(to:service:pixelSampler:)` and store the sampler as a property at attach time — attach runs at launch, before any tool can arm, so the Task 3 magnifier path calls this injected instance; the controller never constructs PixelSamplerService itself.

    DesignOverlayService (modify): isRulerArmed: Bool @Published + rulerDistance: String? readout (or the start/end points it already publishes: rulerStart/rulerEnd seeds from the scaffold — reuse those), armRuler()/disarmRuler() helpers keeping exactly one tool armed at a time (arming one disarms the other — the input mode is singular by construction).
  </action>
  <verify>
    <automated>xcodebuild -project BoosterSimApp.xcodeproj -scheme BoosterSimApp -configuration Debug build && xcodebuild -project BoosterSimApp.xcodeproj -scheme BoosterSimApp -destination 'platform=macOS' test -only-testing:BoosterSimAppTests/RulerMathTests -only-testing:BoosterSimAppTests/PixelSamplerTests -parallel-testing-enabled NO</automated>
    <fails_when>non-zero exit on either command, "BUILD FAILED", a "failed" marker in the test summary, or "Executed 0 tests"</fails_when>
  </verify>
  <acceptance_criteria>
    - RulerOverlayView handles mouseDown/mouseDragged/mouseUp, converts the readout through OverlayGeometry.devicePoint + OverlayGeometry.distance (device points — not window points, not pixels), and contains no second distance implementation
    - AppDelegate constructs pixelSamplerService as a lazy var (stateless ScreenshotService + tracker, the captureService precedent) and passes it at the attach call site; DesignOverlayController receives it via the extended attach(to:service:pixelSampler:) signature and stores it — no PixelSamplerService construction inside the controller
    - DesignOverlayController owns an OverlayInputMode with ruler/magnifier/clickThrough states; arming calls panel.setCaptureMode(true) and installing a local keyDown monitor for Esc (keyCode 53); EVERY disarm path and deinit removes the monitor (removeMonitor present in deinit)
    - The controller and view contain zero coroutine keywords (Combine + AppKit events only — the async bridge lives solely in PixelSamplerService)
    - RulerOverlayView is installed at the .interactive layer (install(_:at:) call) — D-04 order preserved
    - DesignOverlayService enforces single-tool arming (arming one disarms the other)
    - Build + targeted suites green
  </acceptance_criteria>
  <done>The ruler half of criterion 2 works end-to-end: arm → drag → live device-point distance → commit/Esc → click-through restored, Simulator focus never stolen (visual proof at the 04-04 smoke).</done>
</task>

<task type="auto">
  <name>Task 3: Magnifier — hover-follow loupe, click-to-commit color pick, side-panel picker section</name>
  <files>
    BoosterSimApp/Views/Overlay/MagnifierView.swift,
    BoosterSimApp/Windows/DesignOverlayController.swift,
    BoosterSimApp/Services/DesignOverlayService.swift,
    BoosterSimApp/Views/SideWindow/DesignComparisonView.swift,
    BoosterSimApp/Utilities/DesignTokens.swift
  </files>
  <read_first>
    - .planning/phases/04-design-tools/04-CONTEXT.md — magnifier discretion (hover-follow loupe vs click-to-sample; ride the Phase 2 SCSanctioned path; Screen Recording already in onboarding)
    - .planning/phases/04-design-tools/04-RESEARCH.md — Pattern 3/4 (hover via NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) — observe-only, no CGEvent taps; local monitoring needed for own-app events), Open Question 4 (8x default, adjustable), Security Domain (memory-only; AppLogger never logs pixel data)
    - .planning/phases/04-design-tools/04-PATTERNS.md — MagnifierView assignment + DesignTokens rule (new layout constants go into a new DesignTokens enum — never hardcoded)
    - The Task 1 PixelSamplerService.swift (sampleColor/sampleRegion seams) and Task 2 DesignOverlayController.swift (input-mode machine + monitor discipline)
    - BoosterSimApp/Utilities/DesignTokens.swift (whole file — where the new OverlayMetrics enum joins)
    - The 04-01 as-built DesignComparisonView.swift (where the picker section replaces the deleted dead button)
  </read_first>
  <action>
    BoosterSimApp/Utilities/DesignTokens.swift (modify): add `enum OverlayMetrics` alongside the existing enums — loupeDiameter: CGFloat = 96, loupeMagnificationDefault: Double = 8, loupeMagnificationRange: ClosedRange<Double> = 2...16, readoutInset: CGFloat (small padding token value consistent with Spacing neighbors). These are the only new literals — the views read them from here.

    BoosterSimApp/Views/Overlay/MagnifierView.swift (new): `final class MagnifierView: NSView` — draw(_:) renders the loupe: a circular clip of diameter OverlayMetrics.loupeDiameter positioned OFFSET from the current cursor point (above-leading, flipping to below-trailing near screen edges so the loupe never covers the sampled point), containing the magnified crop from PixelSamplerService's cached image around the cursor pixel (sampleRegion seam scaled by the magnification factor), a center crosshair, and a compact live hex caption (drawn text) of the color under the cursor. Updates are driven by the controller pushing the cursor point; no event handling inside the view itself.

    BoosterSimApp/Windows/DesignOverlayController.swift (modify): extend the input-mode machine for .magnifier — on arm: panel.setCaptureMode(true), PixelSamplerService.arm(), install a GLOBAL NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) handler (observe-only closure reading event.locationInWindow → convert to panel-local point → push to MagnifierView + update the live hex) PLUS the panel-local mouseMoved path (global monitors don't fire for own-app events — Pitfall 4); on click (panel mouseDown while .magnifier): sampleColor(at:) → service.pickedColor = color → auto-disarm (click-to-commit; the panel returns to click-through). Remove the global monitor on EVERY disarm path and in deinit (same discipline as the Esc monitor — no ambient cursor tracking survives the tool). Frame-change while armed → re-arm the sampler (freshness per flagged assumption A5).

    DesignOverlayService (modify): isMagnifierArmed: Bool @Published + magnification: Double (default OverlayMetrics.loupeMagnificationDefault, persisted under "DesignOverlayMagnification") + liveHex: String? (published for the loupe caption; pickedColor seed already exists); armMagnifier()/disarmMagnifier() with the single-tool rule from Task 2.

    DesignComparisonView (modify): new "Color Picker" section with the pre-assigned SF Symbol `eyedropper`: an arm/disarm AccentButton pair (active controls — amber allowed here, never in the overlay), magnification Stepper bound to magnification (OverlayMetrics range), the committed pickedColor swatch + hex/RGB rows via the kept colorToHex/colorToRGB helpers, and a Copy button calling the kept copyColorToClipboard seed. Ruler section: arm/disarm buttons + the committed distance readout row (Task 2 state surfaced).
  </action>
  <verify>
    <automated>xcodebuild -project BoosterSimApp.xcodeproj -scheme BoosterSimApp -configuration Debug build && xcodebuild -project BoosterSimApp.xcodeproj -scheme BoosterSimApp -destination 'platform=macOS' test -only-testing:BoosterSimAppTests/PixelSamplerTests -only-testing:BoosterSimAppTests/RulerMathTests -only-testing:BoosterSimAppTests/OverlayPersistenceTests -parallel-testing-enabled NO</automated>
    <fails_when>non-zero exit on either command, "BUILD FAILED", a "failed" marker in the test summary, or "Executed 0 tests"</fails_when>
  </verify>
  <acceptance_criteria>
    - OverlayMetrics exists in DesignTokens.swift with loupeDiameter/magnification default + range constants; MagnifierView.swift references no raw numeric literal for loupe size or magnification (reads OverlayMetrics)
    - The loupe crop comes from PixelSamplerService's cached image (sampleRegion seam) — the view contains no ScreenCaptureKit reference and no per-move capture call
    - The global mouseMoved monitor is installed only while .magnifier is armed and removed on every disarm path AND deinit (addGlobalMonitorForEvents + removeMonitor both present, balanced); no CGEvent tap anywhere in the phase's code
    - Click-to-commit writes service.pickedColor and auto-disarms (single code path); the Design tab picker section shows swatch + hex + RGB via the kept helpers and copies via the kept seed
    - magnification persists under the versioned key; single-tool arming still holds
    - Build + targeted suites green
  </acceptance_criteria>
  <done>Success criterion 2 complete: ruler + magnifier/color picker work over the live Simulator from one cached capture per arming, commit/cancel cleanly, degrade honestly without permission, and leak nothing (memory-only, monitors balanced).</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| Screen Recording TCC gate → app | ScreenCaptureKit capture of another app's window is privacy-gated; scope discipline is the mitigation |
| Captured pixels → app memory | Screen content crosses into the app's memory cache (log/disk exfiltration is the risk) |
| Global event stream → app (observe-only) | The mouseMoved global monitor sees cursor positions across all apps while armed |

## STRIDE Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation Plan |
|-----------|----------|-----------|----------|-------------|-----------------|
| T-04-06 | Information Disclosure | Captured Simulator frames leaking to disk/logs | high | mitigate | Cache is a private memory-only stored property, cleared on disarm; zero file-write/FileManager symbols in PixelSamplerService (source-checked); AppLogger.design logs verbs/outcomes only — never pixel values or frame data (house rule + security_asvs_level 1 + block_on=high satisfied) |
| T-04-07 | Elevation of Privilege / Privacy | Screen Recording permission over-reach (capturing beyond the Simulator) | medium | mitigate | Capture exclusively via ScreenshotService's desktopIndependentWindow filter scoped to tracker.activeSimulator's windowID (Phase 2 design, reused); CGPreflightScreenCaptureAccess preflight with honest denied caption; no self-capture possible by construction |
| T-04-08 | Spoofing of Privacy / Repudiation | Ambient cursor tracking surviving tool disarm | medium | mitigate | Global monitor lifetime == armed lifetime: removed on every disarm path and in deinit (acceptance-criteria balanced add/remove check); observe-only handler (never mutates or swallows events); no CGEvent tap (Don't Hand-Roll row) |

</threat_model>

<verification>
- Task 1 PixelSamplerTests + RulerMathTests green (mapping, late-discard, permission degradation)
- Task 2/3 build + targeted suites green; monitor add/remove balance and layer-order assertions hold
- Zero coroutine keywords outside PixelSamplerService's single bridge; zero file-write symbols in the sampler; no CGEvent tap
- Visual proof (loupe accuracy against known colors, ruler readout, Esc, focus retention) rides the 04-04 phase-gate blocking smoke per 04-VALIDATION Manual-Only rows
</verification>

<success_criteria>
- Criterion 2 closed: measure distances + sample pixel colors with the magnifier/color picker, over the live Simulator
- The phase's only async site is the sanctioned single Task bridge (CONVENTIONS exemption wording updated in 04-04's docs truth pass)
- D-04 holds with all five layers installed: grid > safe-area > ruler/magnifier readouts > comparison image > Simulator content
</success_criteria>

## Artifacts this phase produces

**Plan 04-03 symbols (new):**
- `@MainActor final class PixelSamplerService: ObservableObject` + `arm()` / `disarm()` / `sampleColor(at:)` + internal sampleRegion + arming-generation seam — Services/PixelSamplerService.swift (the second sanctioned async site, CaptureService shape)
- `final class RulerOverlayView: NSView` — Views/Overlay/RulerOverlayView.swift
- `final class MagnifierView: NSView` — Views/Overlay/MagnifierView.swift
- `enum OverlayInputMode { clickThrough, ruler, magnifier }` — Windows/DesignOverlayController.swift
- `enum OverlayMetrics` (loupeDiameter 96, magnification 8 default, 2...16 range, readoutInset) — Utilities/DesignTokens.swift
- Swift Testing suite `PixelSamplerTests` — BoosterSimAppTests/

**Service state added:** DesignOverlayService.isRulerArmed/isMagnifierArmed, ruler readout, magnification (persisted), liveHex, single-tool arm helpers

<output>
Create `.planning/phases/04-design-tools/04-03-ruler-magnifier-SUMMARY.md` when done
</output>
