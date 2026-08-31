---
phase: 04-design-tools
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - BoosterSimApp/Services/SafeAreaCatalog.swift
  - BoosterSimApp/Services/OverlayGeometry.swift
  - BoosterSimApp/Services/DesignOverlayService.swift
  - BoosterSimApp/Windows/DesignOverlayPanel.swift
  - BoosterSimApp/Windows/DesignOverlayController.swift
  - BoosterSimApp/Views/Overlay/GridOverlayView.swift
  - BoosterSimApp/Views/SideWindow/DesignComparisonView.swift
  - BoosterSimApp/Views/SideWindow/tabs/DesignTabView.swift
  - BoosterSimApp/App/AppDelegate.swift
  - BoosterSimApp/Windows/SideWindowController.swift
  - BoosterSimApp/Utilities/AppLogger.swift
  - BoosterSimAppTests/SafeAreaCatalogTests.swift
  - BoosterSimAppTests/GridGeometryTests.swift
  - BoosterSimAppTests/RulerMathTests.swift
  - BoosterSimAppTests/OverlayPersistenceTests.swift
autonomous: true
requirements:
  - REQ-roadmap-phase4-design-tools
estimate:
  tokens: 55000
  raw_tokens: 55000
  tasks: 2
  confidence: low

must_haves:
  truths:
    - "With a booted Simulator, toggling Grid in the Design tab draws a dual grid over the live Simulator window — emphasized 8pt major lines with subdued 4pt minor subdivisions (D-01), aligned to real device points via the tracked window's content rect and the device's logical size, in adaptive system blue with user-adjustable color and opacity (D-03)"
    - "The overlay panel exactly covers the Simulator window frame (tracker.$activeSimulator sink → setFrame/orderFront, orderOut when no Simulator) and follows move/resize in real time; the panel never becomes key and never takes focus from the Simulator"
    - "Overlays stay visible when BoosterSimApp loses focus (hidesOnDeactivate = false, .floating level, canJoinAllSpaces) — success criterion 4's persistence half"
    - "The Grid toggle (and every later per-tool toggle) persists across app relaunch via versioned UserDefaults keys — success criterion 4's per-tool half"
    - "Saved presets from the legacy scaffold decode into the new versioned schema via a flag-guarded one-shot import; a user upgrading never silently loses presets"
    - "The scaffold's fake core is gone: the 1x1-bitmap color sampler and the single-spacing grid model are deleted, while loadImage/clearOverlay/colorToHex/colorToRGB/preset save-load-delete are carried into the new service (Phase 2 cut-over precedent)"
    - "Grid/safe-area guide layers are architecturally above any future image layer from day one: the panel's install API maps layer roles to subview order (D-04), so later plans cannot violate the z-order by toggling sequence"
  artifacts:
    - BoosterSimApp/Services/SafeAreaCatalog.swift
    - BoosterSimApp/Services/OverlayGeometry.swift
    - BoosterSimApp/Services/DesignOverlayService.swift
    - BoosterSimApp/Windows/DesignOverlayPanel.swift
    - BoosterSimApp/Windows/DesignOverlayController.swift
    - BoosterSimApp/Views/Overlay/GridOverlayView.swift
    - BoosterSimAppTests/SafeAreaCatalogTests.swift
    - BoosterSimAppTests/GridGeometryTests.swift
    - BoosterSimAppTests/RulerMathTests.swift
    - BoosterSimAppTests/OverlayPersistenceTests.swift
  key_links:
    - "DesignComparisonView grid toggle → DesignOverlayService.showGrid (@Published, UserDefaults-persisted) → DesignOverlayController service sink → gridOverlayView.isHidden + panel orderFront/orderOut → GridOverlayView.draw via OverlayGeometry geometry"
    - "SimulatorWindowTracker.$activeSimulator → DesignOverlayController.attach(to:) → panel.setFrame(sim.frame) + SafeAreaCatalog device resolution (deviceName → logicalSize → grid scale) — the same sink shape SideWindowController.swift:90-98 proves"
    - "AppDelegate lazy var designOverlayService + designOverlayController → applicationDidFinishLaunching attach(to: tracker) → SideWindowController embedSwiftUIContent .environmentObject(designOverlayService) → DesignTabView/DesignComparisonView"
    - "Legacy UserDefaults key DesignComparisonPresets → one-shot tolerant import (flag DesignOverlayLegacyImported) → new key DesignOverlayPresets"
  prohibitions:
    - requirement_id: REQ-roadmap-phase4-design-tools
      category: values
      status: unverified
      flagged: true
      verification: test
      statement: "MUST NOT render overlay guide content in the amber accent color — amber is reserved for active side-panel controls per design-guidelines (D-03); grid and safe-area guides render in adaptive system blue (or the user's chosen color), never accent-tinted"
    - requirement_id: REQ-roadmap-phase4-design-tools
      category: transparency
      status: unverified
      flagged: true
      verification: test
      statement: "MUST NOT silently discard user-saved presets on the schema upgrade — legacy DesignComparisonPresets data imports once into the versioned DesignOverlayPresets key (carrying mode/opacity/showGrid/showRuler; the dropped field is the deleted single-spacing value), never vanishes without trace (RESEARCH Pitfall 5)"
  flagged_assumptions:
    - requirement_id: REQ-roadmap-phase4-design-tools
      probe: idempotency
      status: unresolved
      statement: "UNRESOLVED EDGE (probe: 'What happens if this runs twice on the same input?') — the one-shot legacy import must be idempotent: the DesignOverlayLegacyImported flag guard means a second init/relaunch imports nothing and duplicates no presets, and re-importing an identical presets payload replaces rather than appends. The double-run guard is unit-tested in OverlayPersistenceTests but the edge stays flagged until the 04-04 phase-gate smoke confirms on a real upgraded defaults store."
    - requirement_id: REQ-roadmap-phase4-design-tools
      probe: concurrency
      status: unresolved
      statement: "UNRESOLVED EDGE (probe: 'If interrupted or run in parallel, what is guaranteed?') — all overlay state mutation is @MainActor-serialized (services and controller are @MainActor; the capture Task bridge of plan 04-03 lands back on the main actor), and tracker frame updates mid-overlay only re-apply geometry. No guarantee is yet verified for interruption mid-render or mid-import; stays flagged until the 04-04 smoke exercises move/resize/relaunch during active overlays."
    - requirement_id: REQ-roadmap-phase4-design-tools
      probe: research-A4
      status: unresolved
      statement: "Simulator window content rect = frame minus ~28pt title bar, assuming device bezels OFF (the common default) — OverlayGeometry.contentRect uses SideWindowMetrics.titleBarHeight; bezel-on windows will misalign the grid until plan 04-02's manual calibration fields land (the D-02 escape hatch). Closes at the 04-04 smoke."
---

<objective>
**Scope note — accepted risk (plan-checker W1, revision 1):** files_modified lists 15 entries and Task 1 spans 14 files, past the scope_sanity soft threshold. Accepted as-is rather than re-sliced: the phase budget instrument passes (over_budget=false, 0.55 ratio), every one of the 14 files carries its own near-verbatim directive paragraph in the Task 1 action (PATTERNS.md excerpts), and repo precedent exists (05-01 shipped 17 files in one plan). The alternative — lifting SafeAreaCatalog + OverlayGeometry + their suites into a leading geometry-kernel plan (~5 files, tracer at ~10) — was rejected because it would put a horizontal math-foundation plan ahead of this phase's tracer, violating tracer-first decomposition and adding a wave to the critical path, all to clear an advisory-only warning. In-task mitigation: the action's strict sub-ordering (Wave 0 suites red → pure-math kernel green → panel/controller/UI wiring) keeps each build step small and individually verifiable.
Tracer slice: prove the Phase 4 overlay architecture end-to-end with ONE story — a dual 8pt/4pt grid drawn over the live Simulator window.

Wire a single vertical path through every layer this phase touches: DesignComparisonView grid toggle → DesignOverlayService (cut-over of the scaffold service: real state, versioned persistence, fake core deleted) → DesignOverlayController (tracker frame sink, service sink) → DesignOverlayPanel (ONE persistent transparent click-through NSPanel over the Simulator frame, D-04 subview-order install API) → GridOverlayView (AppKit draw(_:), dual major-minor lines in device points via SafeAreaCatalog + OverlayGeometry). Task 2 hardens the persistence half of success criterion 4: per-tool toggle round-trips and the versioned preset schema with one-shot legacy import.

This tracer ships the shared engine every later tool rides on: the panel + layered install contract (D-04), the controller input-mode seam (capture-mode flip lands pre-wired for 04-03), the device→geometry resolution chain, and the Wave 0 pure-math test suites (SafeAreaCatalog, GridGeometry, RulerMath, OverlayPersistence). Plans 02 (safe-area + comparison import), 03 (ruler + magnifier), and 04 (phase gate) expand on this proven slice without architectural change.

Purpose: 04-RESEARCH.md verifies every pattern in-repo (AXHighlightPanel config, SideWindowController tracker sink, CaptureService Task-bridge, ScreenshotService scale math) and pins the load-bearing risks this plan neutralizes on day one — z-order by subview order not window order (Pitfall 1), Y-flip/scale mismatches centralized in one tested mapper (Pitfall 2), and legacy presets silently vanishing (Pitfall 5).
Output: 6 new source files + 1 deleted scaffold service, 5 modified files, 4 Wave 0 Swift Testing suites, one green grid-over-Simulator path (visual proof at the 04-04 phase-gate smoke).
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

Source-of-truth analogs (read before writing each file — PATTERNS.md carries near-verbatim excerpts):
@BoosterSimApp/Services/DesignComparisonService.swift
@BoosterSimApp/Views/SideWindow/DesignComparisonView.swift
@BoosterSimApp/Views/SideWindow/tabs/DesignTabView.swift
@BoosterSimApp/Windows/AXHighlightPanel.swift
@BoosterSimApp/Windows/SideWindowPanel.swift
@BoosterSimApp/Windows/SideWindowController.swift
@BoosterSimApp/Services/SimulatorWindowTracker.swift
@BoosterSimApp/Models/SimulatorWindow.swift
@BoosterSimApp/Models/ASCFramePreset.swift
@BoosterSimApp/Utilities/DesignTokens.swift
@BoosterSimApp/Utilities/AppLogger.swift
@BoosterSimApp/App/AppDelegate.swift
@BoosterSimAppTests/CaptureFramingTests.swift
@BoosterSimAppTests/NetworkConditionServiceTests.swift
</context>

<tasks>

<task type="tracer" tdd="true">
  <name>Task 1: Grid-over-Simulator end-to-end — cut-over service, persistent overlay panel, tracker-synced controller, dual-grid view, Wave 0 math suites</name>
  <files>
    BoosterSimApp/Services/SafeAreaCatalog.swift,
    BoosterSimApp/Services/OverlayGeometry.swift,
    BoosterSimApp/Services/DesignOverlayService.swift,
    BoosterSimApp/Windows/DesignOverlayPanel.swift,
    BoosterSimApp/Windows/DesignOverlayController.swift,
    BoosterSimApp/Views/Overlay/GridOverlayView.swift,
    BoosterSimApp/Views/SideWindow/DesignComparisonView.swift,
    BoosterSimApp/Views/SideWindow/tabs/DesignTabView.swift,
    BoosterSimApp/App/AppDelegate.swift,
    BoosterSimApp/Windows/SideWindowController.swift,
    BoosterSimApp/Utilities/AppLogger.swift,
    BoosterSimAppTests/SafeAreaCatalogTests.swift,
    BoosterSimAppTests/GridGeometryTests.swift,
    BoosterSimAppTests/RulerMathTests.swift
  </files>
  <!-- planner-discipline-allow: DesignComparisonService -->
  <!-- planner-discipline-allow: gridSpacing -->
  <read_first>
    - .planning/phases/04-design-tools/04-CONTEXT.md — D-01 (dual 8/4 grid replaces the single-spacing model), D-03 (adaptive defaults + keep color/opacity controls, amber never on overlay content), D-04 (guides-on-top z-order), scaffold-disposition discretion (Phase 2 cut-over precedent, stubs not preserved)
    - .planning/phases/04-design-tools/04-RESEARCH.md — Architecture Patterns (system diagram, Pattern 1 panel config, Pattern 2 tracker sync, Pattern 5 device-space grid alignment), Anti-Patterns to Avoid (z-order by window level, Y-flip, hardcoded 2x scale, amber-tinting), Don't Hand-Roll table, Recommended Project Structure, Assumptions A2/A4
    - .planning/phases/04-design-tools/04-PATTERNS.md — Pattern Assignments for every file above (near-verbatim analog excerpts: AXHighlightPanel config block, SideWindowController attach sink, scaffold state/persistence/helpers/loadImage, DesignTabView mount, AppDelegate lazy block, SideWindowController environmentObject chain, CaptureFramingTests house style), No Analog Found rows (interactive views, global monitor, z-ordered container), framework discrepancy flag (Swift Testing, NOT XCTest)
    - BoosterSimApp/Services/DesignComparisonService.swift (whole file, 148 lines — the file being replaced: state 10-23, preset struct 32-40, presetsKey 44, loadImage 56-63, fake pickColor 68-86, color helpers 95-107, persistence 138-150)
    - BoosterSimApp/Views/SideWindow/DesignComparisonView.swift (whole file, 224 lines — binding conventions to keep, spacing-slider block ~65-77 and dead Pick Color button to delete)
    - BoosterSimApp/Views/SideWindow/tabs/DesignTabView.swift (whole file, 16 lines — mount point)
    - BoosterSimApp/Windows/AXHighlightPanel.swift (whole file — borderless panel config 28-42, draw-based view 7-17; the auto-dismiss Timer 44-58 is the part NOT to copy)
    - BoosterSimApp/Windows/SideWindowPanel.swift lines 22-35 (hidesOnDeactivate/isReleasedWhenClosed persistence flags)
    - BoosterSimApp/Windows/SideWindowController.swift lines 7-30 (class shape), 90-110 (attach sink + focus handling), 213-227 (embedSwiftUIContent environmentObject chain), end of file (keyMonitor add/remove-in-deinit discipline)
    - BoosterSimApp/Services/SimulatorWindowTracker.swift lines 20-23 (published sources) and BoosterSimApp/Models/SimulatorWindow.swift lines 22-36 (id/deviceName/frame/deviceType/udid fields)
    - BoosterSimApp/Models/ASCFramePreset.swift lines 21-54 (enum constants-table shape SafeAreaCatalog copies)
    - BoosterSimApp/Utilities/DesignTokens.swift lines 7-35 (Spacing/CornerRadius/SideWindowMetrics.titleBarHeight = 28)
    - BoosterSimApp/Utilities/AppLogger.swift lines 5-15 (category registry)
    - BoosterSimApp/App/AppDelegate.swift lines 17-49 (lazy service block + controller construction + attach site)
    - BoosterSimAppTests/CaptureFramingTests.swift (whole file — Swift Testing house style: import Testing, @Test, #expect, synthetic builders) and BoosterSimAppTests/NetworkConditionServiceTests.swift lines 8-45 (makeDefaults isolated-suite pattern for injectable UserDefaults)
    - .planning/codebase/CONVENTIONS.md — concurrency exemption list and testing guidance
    - AGENTS.md GitNexus section — run gitnexus_impact upstream on the scaffold service BEFORE deleting it and on SideWindowController BEFORE editing; report blast radius in the summary
  </read_first>
  <behavior>
    - SafeAreaCatalogTests: name-keyed lookup returns the verified rows — "iPhone 16 Pro" → top 62/bottom 34, "iPhone 15" → 59/34, "iPhone 13 mini" → 50/34; logical-size fallback returns 390x844 → 47/34 when the name is unknown
    - SafeAreaCatalogTests: 375x812 name disambiguation — "iPhone X" → top 44, "iPhone 13 mini" → top 50, size-only fallback for 375x812 → 50 (mini family wins the size key; name key resolves the collision)
    - SafeAreaCatalogTests: unknown name + unknown size → manualDefaults; iPad-size fallback row; logicalSize(for:) returns the size for a known name ("iPhone 16 Pro" → 402x874) and nil for unknown
    - GridGeometryTests: gridSpacings(scale:) returns (8x, 4x) exactly for scale 1.0/2.0/3.0; contentRect(windowFrame:) subtracts exactly SideWindowMetrics.titleBarHeight from the top and leaves origin.x/width untouched; scale(contentRect:deviceLogicalSize:) = contentRect.width / logicalWidth
    - GridGeometryTests: devicePoint round-trip — windowPointToDevicePoint then back through the inverse lands on the original point (within CGFloat epsilon) across three synthetic frame/size pairs
    - RulerMathTests: imagePixel(forWindowPoint:frameHeight:scale:) — top-left window point maps to pixel (0,0), bottom-left maps to (0, frameHeight x scale), i.e. the Y axis is flipped against frame height then multiplied by scale; works for scale 1.0 (1x external display) and 2.0
    - RulerMathTests: distance(a,b) is hypot and is 0 for equal points
  </behavior>
  <action>
    NOTE: tracer by design — one story only (grid toggle → overlay panel → drawn grid); safe-area view, comparison image, ruler, magnifier arrive in plans 02-03 riding this panel/controller/service. Every new file under the 200-LOC house target; new files join the BoosterSimApp target automatically via pbxproj synchronized groups (STATE.md Phase 5 decision) — the Debug build in verify proves membership. Write the three pure-math Wave 0 suites FIRST (Swift Testing house style per CaptureFramingTests — Testing import, @Test funcs, #expect, zero XCTest imports), watch them fail to build (types missing = red), then implement green. Log through a new AppLogger.design category only.

    BoosterSimApp/Services/SafeAreaCatalog.swift (new): caseless `enum SafeAreaCatalog` in the ASCFramePreset constants-table style — pure data, no ObservableObject, no AppKit imports (Foundation + CoreGraphics only). Declare `struct Insets: Equatable { let top, bottom, left, right: CGFloat }` alongside. Lookup order REFINES D-02 per RESEARCH: (1) device-name key from SimulatorWindow.deviceName via a byName dictionary, (2) logical-size key (width x height as the dictionary key type), (3) manualDefaults fallback. Ship the verified portrait rows: 393x852 → (59,34), 430x932 → (59,34), 402x874 → (62,34), 440x956 → (62,34), 390x844 → (47,34), 428x926 → (47,34), 375x812 → (50,34) size key; name-keyed exceptions: iPhone X/XS/11 Pro → (44,34), 12/13 mini → (50,34); legacy ASSUMED rows from the RESEARCH table (414x896 → 48/34, 375x667 and 414x736 and 320x568 → 20/0, iPad sizes → 20/20). Also `static func logicalSize(forDeviceName:) -> CGSize?` (the Pattern 5 scale input) covering the same name keys. Header comment: raw-value provenance (useyourloaf verified vs ASSUMED rows) and that constants are not queryable live per D-02.

    BoosterSimApp/Services/OverlayGeometry.swift (new): caseless `enum OverlayGeometry` — the ONE pure mapper all views/services share (RESEARCH Pitfall 2: centralize the flip, never re-derive per call site). Functions with exact signatures: `contentRect(windowFrame:) -> CGRect` (frame minus SideWindowMetrics.titleBarHeight from the top — bezels-off assumption A4), `scale(contentRect:deviceLogicalSize:) -> CGFloat`, `gridSpacings(scale:) -> (major: CGFloat, minor: CGFloat)` (8x scale / 4x scale — D-01), `devicePoint(forWindowPoint:contentRect:scale:) -> CGPoint` plus its inverse `windowPoint(fromDevicePoint:contentRect:scale:) -> CGPoint`, `imagePixel(forWindowPoint:frameHeight:scale:) -> CGPoint` (Y flipped against frame height, then x scale — CGImage top-origin vs AppKit bottom-origin), `distance(_:_:) -> CGFloat` (hypot). Pure functions only; no stored state; CoreGraphics/Foundation imports only.

    BoosterSimApp/Services/DesignOverlayService.swift (new — the cut-over; delete BoosterSimApp/Services/DesignComparisonService.swift in the same commit): `@MainActor final class DesignOverlayService: ObservableObject` (repo convention — the old service was NOT MainActor; sibling services are). KEEP the scaffold seeds verbatim in shape: overlayImage/overlayOpacity/comparisonMode/splitPosition/showGrid/gridColor/showRuler/rulerStart/rulerEnd/pickedColor/presets published state, ComparisonMode enum, loadImage()/clearOverlay(), colorToHex/colorToRGB/copyColorToClipboard, savePreset/loadPreset/deletePreset, DesignPreset Codable struct. CHANGE per D-01: no single-spacing property anywhere — the grid model is the dual 8/4 pair computed by OverlayGeometry.gridSpacings; the legacy preset field is dropped from the new schema. ADD per D-03: gridOpacity: Double (default 1.0) if not already present. Persistence: init(defaults: UserDefaults = .standard) injectable (03-02 DeepLinkService pattern); per-tool toggles persisted under versioned keys ("DesignOverlayShowGrid", "DesignOverlayShowRuler") restored at init; presets under the NEW key "DesignOverlayPresets" — the legacy "DesignComparisonPresets" key is read exactly once behind a "DesignOverlayLegacyImported" flag using a tolerant decode (decode-if-present per field: mode/opacity/showGrid/showRuler carried, spacing ignored); Task 2 unit-locks this import. DELETE the fake pickColor(at:) entirely — real sampling arrives in plan 04-03 via PixelSamplerService. Log through AppLogger.design (verb + outcome only).

    BoosterSimApp/Windows/DesignOverlayPanel.swift (new): `final class DesignOverlayPanel: NSPanel` — config merged verbatim from the two verified panels per PATTERNS: super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false); isOpaque = false; backgroundColor = .clear; level = .floating; ignoresMouseEvents = true; collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]; isReleasedWhenClosed = false; hidesOnDeactivate = false (criterion 4). contentView is a plain container NSView. D-04 CONTRACT: `enum OverlayLayer { case comparison, interactive, safeArea, grid }` (bottom → top) and `func install(_ view: NSView, at layer: OverlayLayer)` inserting at a deterministic index derived from the layer order — later plans call install(), so z-order can never depend on toggle or orderFront sequence (Pitfall 1). `func setCaptureMode(_ active: Bool)` flips ignoresMouseEvents and acceptsMouseMovedEvents (seam for 04-03; inert until then). NEVER makeKey — orderFront only (Pitfall 4).

    BoosterSimApp/Windows/DesignOverlayController.swift (new): `@MainActor final class DesignOverlayController: ObservableObject` in the SideWindowController shape. Owns the panel. `func attach(to tracker: SimulatorWindowTracker, service: DesignOverlayService)` — two sinks both storing into cancellables: (1) tracker.$activeSimulator → sim present ? panel.setFrame(sim.frame, display: true) + panel.orderFront(nil) : panel.orderOut(nil); on sim change also recompute the geometry bundle (contentRect + SafeAreaCatalog.logicalSize(forDeviceName: sim.deviceName) → scale) and push to views; (2) service.objectWillChange → refresh tool visibility (gridOverlayView.isHidden = !service.showGrid) and keep panel ordered front while ANY tool is on, orderOut when none are. Installs GridOverlayView at .grid. Files stay under 200 LOC by keeping this controller to orchestration only (drawing lives in views, math in OverlayGeometry, state in the service).

    BoosterSimApp/Views/Overlay/GridOverlayView.swift (new): `final class GridOverlayView: NSView`, draw(_:)-based (AXHighlightView precedent; SwiftUI stays in the side panel). Geometry bundle (contentRect + scale) injected via an update method; draw guards on geometry. Dual grid per D-01/D-03: minor lines at gridSpacings.minor with color alpha multiplied by 0.5 and hairline width 1.0 / window.backingScaleFactor; major lines at gridSpacings.major with full configured alpha and width 1.5 / backingScaleFactor (crisp 1px-quantized hairlines, Pitfall 7); color from service gridColor (default adaptive system blue — NEVER the accent amber, D-03). Lines drawn across the content rect in window points; NSBezierPath strokes.

    BoosterSimApp/Views/SideWindow/DesignComparisonView.swift (modify): rename the observed object to DesignOverlayService. DELETE the single-spacing slider block (~lines 65-77) and its state binding entirely (D-01) and delete the dead Pick Color placeholder button (its real arm/disarm UI arrives in 04-03 with PixelSamplerService). KEEP the comparison mode picker, opacity slider, image import row, and preset save/load/delete rows bound to the new service. Grid section: Toggle bound to showGrid (persisted), ColorPicker bound to gridColor, opacity slider bound to gridOpacity (D-03 tunability). Section headers stay `Label(..., systemImage:)` with the pre-assigned SF Symbol `grid`; existing Divider/CollapsibleSection conventions untouched. Design tokens only — no raw layout literals.

    BoosterSimApp/Views/SideWindow/tabs/DesignTabView.swift (modify): mechanical — @EnvironmentObject type renamed to DesignOverlayService; DesignComparisonView(service:) call updated. No new sections yet (safe-area section lands in 04-02).

    BoosterSimApp/App/AppDelegate.swift (modify): lazy block — replace the design service lazy var with `lazy var designOverlayService = DesignOverlayService()`; add `lazy var designOverlayController = DesignOverlayController(panel: designOverlayPanel)` and `lazy var designOverlayPanel = DesignOverlayPanel()` in the axHighlightPanel precedent style; in applicationDidFinishLaunching where sideWindowController attaches, call designOverlayController.attach(to: tracker, service: designOverlayService); pass designOverlayService into sideWindowController's init alongside existing services.

    BoosterSimApp/Windows/SideWindowController.swift (modify): init parameter + embedSwiftUIContent environmentObject chain line renamed to designOverlayService (one-line swap per PATTERNS; the chain sits ~lines 213-227). No behavior change to panel positioning.

    BoosterSimApp/Utilities/AppLogger.swift (modify): one registry line — static let design = Logger(subsystem: subsystem, category: "Design") — matching neighbor formatting.
  </action>
  <verify>
    <automated>xcodebuild -project BoosterSimApp.xcodeproj -scheme BoosterSimApp -destination 'platform=macOS' test -only-testing:BoosterSimAppTests/SafeAreaCatalogTests -only-testing:BoosterSimAppTests/GridGeometryTests -only-testing:BoosterSimAppTests/RulerMathTests -parallel-testing-enabled NO && xcodebuild -project BoosterSimApp.xcodeproj -scheme BoosterSimApp -configuration Debug build</automated>
    <fails_when>non-zero exit on either command, "BUILD FAILED" in the build output, a "failed" marker in the Swift Testing run summary, or "Executed 0 tests" (an -only-testing filter matched no suite)</fails_when>
  </verify>
  <acceptance_criteria>
    - All three Wave 0 suites exist, import Testing, declare @Test funcs using #expect, contain zero XCTest imports, and every behavior bullet above is covered
    - SafeAreaCatalog.swift declares a caseless enum with the name-first/size-second/manualDefaults lookup, contains no ObservableObject conformance and no AppKit import; the verified rows (393x852→59/34, 402x874→62/34, 390x844→47/34, 375x812 name-disambiguated 44 vs 50) are asserted in SafeAreaCatalogTests
    - OverlayGeometry.swift contains the six pure functions with the exact signatures in the action; no function re-derives backing scale from a hardcoded literal (scale is always a parameter)
    - The path BoosterSimApp/Services/DesignComparisonService.swift no longer exists, the token DesignComparisonService occurs zero times across BoosterSimApp/ sources, and the deleted single-spacing property name occurs zero times across BoosterSimApp/ sources (cut-over complete, no orphan references)
    - DesignOverlayService.swift is @MainActor final class ... ObservableObject with init(defaults: UserDefaults = .standard), persists showGrid under the key DesignOverlayShowGrid, stores presets under DesignOverlayPresets, and reads the legacy DesignComparisonPresets key only behind the DesignOverlayLegacyImported flag
    - DesignOverlayPanel.swift sets all eight config properties from the action list verbatim (borderless + nonactivatingPanel styleMask, clear background, floating level, ignoresMouseEvents true, canJoinAllSpaces + fullScreenAuxiliary, isReleasedWhenClosed false, hidesOnDeactivate false) and exposes install(_:at:) with the OverlayLayer enum plus setCaptureMode(_:); the panel source contains no key-window ordering call
    - DesignOverlayController.swift sinks tracker.$activeSimulator calling setFrame(sim.frame, display: true) + orderFront on presence and orderOut on nil (the SideWindowController attach shape), and no coroutine keyword appears in it (Combine only)
    - GridOverlayView.swift draw(_:) strokes two spacings — one at gridSpacings.minor with halved alpha and one at gridSpacings.major with full alpha, both widths divided by window.backingScaleFactor
    - AppDelegate constructs designOverlayController and attaches it in applicationDidFinishLaunching; SideWindowController injects designOverlayService into the environmentObject chain
    - AppLogger.swift contains static let design with category "Design"
    - Every new source file is at or under 200 lines
    - Both xcodebuild commands exit 0
  </acceptance_criteria>
  <reversibility rating="costly">D-04 z-order is embedded here: the OverlayLayer install contract and the single-panel architecture are what plans 02-03 build every renderer on — reshuffling them after three renderers exist is a coordinated change across all overlay views (CONTEXT.md rates D-04 costly, not one-way; no decision checkpoint required, the human locked the order in discuss).</reversibility>
  <done>One green vertical path: with a Simulator running, the Design tab's Grid toggle draws the dual 8pt/4pt grid over the Simulator window, tracks move/resize, survives app focus loss, and persists its toggle across relaunch; the scaffold's fake core is deleted; three pure-math suites + full app build green.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: Persistence hardening — toggle round-trips, versioned preset schema, one-shot legacy import, OverlayPersistenceTests</name>
  <files>
    BoosterSimApp/Services/DesignOverlayService.swift,
    BoosterSimAppTests/OverlayPersistenceTests.swift
  </files>
  <read_first>
    - .planning/phases/04-design-tools/04-RESEARCH.md — Pitfall 5 (legacy presets silently dropped: the try? decode returning nil means silent loss), Runtime State Inventory row for the stored presets key, Open Question 2 (recommendation: new key + one-shot best-effort legacy import — presets are low-value data)
    - .planning/phases/04-design-tools/04-PATTERNS.md — DesignComparisonService cut-over assignment (persistence shape keep + tolerance), Shared Patterns → Persistence
    - The Task 1 version of BoosterSimApp/Services/DesignOverlayService.swift (whole file — the persistence code this task locks under test)
    - BoosterSimAppTests/NetworkConditionServiceTests.swift lines 8-45 (makeDefaults isolated-suite + round-trip test shapes)
    - BoosterSimAppTests/CaptureSettingsTests.swift (Codable round-trip house style)
  </read_first>
  <behavior>
    - OverlayPersistenceTests: showGrid/showRuler toggle round-trip — set true on a service built on an isolated UserDefaults suite, re-init a second service on the same suite, toggles read back true; default suite untouched
    - OverlayPersistenceTests: new-schema preset round-trip — save a preset carrying mode/opacity/showGrid/showRuler, re-init, the preset decodes with identical fields
    - OverlayPersistenceTests: legacy tolerance — a hand-encoded legacy payload (the old Codable shape that includes the deleted spacing field) planted under the legacy key imports once into the new key with mode/opacity/showGrid/showRuler carried and no decode crash
    - OverlayPersistenceTests: idempotent import — running init twice against the same suite (flag already set) imports nothing: preset count unchanged, no duplicates (this is the idempotency edge guard)
    - OverlayPersistenceTests: corrupted payload — garbage Data under either key leaves presets empty and init completes without trapping
  </behavior>
  <action>
    Write BoosterSimAppTests/OverlayPersistenceTests.swift first (Swift Testing, isolated UserDefaults suite via UserDefaults(suiteName:) + removePersistentDomain cleanup per the NetworkConditionServiceTests pattern; construct legacy payloads with a local legacy-shaped Codable struct inside the test file so the production schema never re-declares the deleted field). Then harden DesignOverlayService to green: the one-shot import reads the legacy key only when the DesignOverlayLegacyImported flag is absent, decodes tolerantly (per-field decode-if-present so a missing or extra field never fails the whole array), maps every decodable entry into the new schema, writes the new key, sets the flag, and logs one summary line (imported count only — never payload contents). Deleting presets persists immediately (savePresets on mutation, the scaffold's existing shape). No other behavior changes from Task 1.
  </action>
  <verify>
    <automated>xcodebuild -project BoosterSimApp.xcodeproj -scheme BoosterSimApp -destination 'platform=macOS' test -only-testing:BoosterSimAppTests/OverlayPersistenceTests -parallel-testing-enabled NO</automated>
    <fails_when>non-zero exit, a "failed" marker in the Swift Testing run summary, or "Executed 0 tests" (the -only-testing filter matched no suite)</fails_when>
  </verify>
  <acceptance_criteria>
    - OverlayPersistenceTests.swift exists, imports Testing, and all five behavior bullets are covered including the double-init idempotency case and the corrupted-payload case
    - DesignOverlayService.swift reads the legacy key only inside the flag-guarded one-shot import (single read site), sets DesignOverlayLegacyImported after importing, and the import tolerates both a missing field and an extra field in the legacy payload
    - No production file re-declares the deleted legacy spacing field — the legacy shape exists only inside the test file as a fixture
    - The test command exits 0 with all OverlayPersistenceTests passing
  </acceptance_criteria>
  <done>Success criterion 4's persistence half is unit-locked: toggles round-trip, presets version cleanly, the legacy import is one-shot and idempotent, and corrupted data degrades to empty instead of trapping.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| User defaults store → service decode | Persisted preset/toggle payloads cross from disk into the app; legacy payloads have a different schema |
| Overlay window ↔ window server | The app renders above ALL other apps' windows (.floating, all spaces) — content discipline is the gate |
| Tracker device metadata → catalog | kCGWindowName-derived device names drive inset/scale resolution |

## STRIDE Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation Plan |
|-----------|----------|-----------|----------|-------------|-----------------|
| T-04-01 | Spoofing/Tampering | DesignOverlayPanel rendering above every app's windows | medium | mitigate | Overlay content restricted to guide rendering (line art from GridOverlayView); panel is non-activating, never key, and click-through (ignoresMouseEvents true) outside capture mode — it cannot host interactive chrome that mimics Simulator UI; no text input or button-like rendering in overlay layers |
| T-04-02 | Denial of Service | Legacy/corrupted defaults payloads crashing init decode | low | mitigate | Tolerant per-field decode behind try?; corrupted data degrades to empty presets (unit-tested in OverlayPersistenceTests); no force-try on user data (code-standards) |
| T-04-SC | Tampering | Package installs | n/a | accept | Zero external packages this phase (Apple frameworks only, RESEARCH Package Legitimacy Audit: not applicable) — no package-legitimacy gate surface exists |

</threat_model>

<verification>
- Task 1 + Task 2 automated gates green (targeted suites + Debug build)
- Cut-over complete: old service file deleted, zero references repo-wide, no deleted-property references
- Panel config source assertions hold (eight config properties + no key-window ordering call)
- Visual end-to-end proof (grid over live Simulator, focus persistence, tracking) is deliberately deferred to the 04-04 phase-gate blocking smoke — NSPanel compositing over a foreign window is manual-only per 04-RESEARCH Validation Architecture
</verification>

<success_criteria>
- Criterion 1 (grid half): dual 8pt/4pt grid renders over the Simulator window, device-point aligned
- Criterion 4: overlays persist through focus loss; per-tool toggle persists across relaunch
- Architecture proven: one panel, layered install contract, tracker sync, pure tested geometry — plans 02-03 only add views + state
- Presets survive the schema upgrade (one-shot idempotent import, unit-locked)
</success_criteria>

## Artifacts this phase produces

**Plan 04-01 symbols (new):**
- `enum SafeAreaCatalog` + `struct SafeAreaCatalog.Insets` + `static func insets(...)` / `logicalSize(forDeviceName:)` — Services/SafeAreaCatalog.swift
- `enum OverlayGeometry` + `contentRect(windowFrame:)`, `scale(contentRect:deviceLogicalSize:)`, `gridSpacings(scale:)`, `devicePoint(forWindowPoint:contentRect:scale:)`, `windowPoint(fromDevicePoint:contentRect:scale:)`, `imagePixel(forWindowPoint:frameHeight:scale:)`, `distance(_:_:)` — Services/OverlayGeometry.swift
- `@MainActor final class DesignOverlayService: ObservableObject` (replaces the deleted `DesignComparisonService`) — Services/DesignOverlayService.swift
- `final class DesignOverlayPanel: NSPanel` + `enum OverlayLayer` + `install(_:at:)` + `setCaptureMode(_:)` — Windows/DesignOverlayPanel.swift
- `@MainActor final class DesignOverlayController: ObservableObject` + `attach(to:service:)` — Windows/DesignOverlayController.swift
- `final class GridOverlayView: NSView` — Views/Overlay/GridOverlayView.swift
- `AppLogger.design` category — Utilities/AppLogger.swift
- Swift Testing suites: `SafeAreaCatalogTests`, `GridGeometryTests`, `RulerMathTests`, `OverlayPersistenceTests` — BoosterSimAppTests/

**Deleted:** `BoosterSimApp/Services/DesignComparisonService.swift` (fake core cut over; seeds carried into DesignOverlayService)

**Modified consumers:** DesignComparisonView, DesignTabView, AppDelegate (service + controller wiring), SideWindowController (environmentObject rename)

<output>
Create `.planning/phases/04-design-tools/04-01-overlay-grid-tracer-SUMMARY.md` when done
</output>
