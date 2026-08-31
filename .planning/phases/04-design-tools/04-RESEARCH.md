# Phase 4: Design Tools - Research

**Researched:** 2026-08-31
**Domain:** macOS AppKit transparent-overlay windows + ScreenCaptureKit pixel sampling + SwiftUI control panel (Swift 6 strict concurrency, Apple frameworks only)
**Confidence:** HIGH (architecture and in-repo integration), MEDIUM (external device constants)

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01: Dual 8pt+4pt grid.** 8pt minor lines with emphasized 4pt subdivisions rendered together (Figma/Sketch major-minor grid style), matching the criterion's "8pt/4pt grid" wording literally. This **replaces** the scaffold's single `gridSpacing` value (`DesignComparisonService.gridSpacing`, default 20) — the single-spacing model is not kept alongside. — **Reversibility:** reversible — grid composition is local to the overlay renderer + service state.
- **D-02: Safe-area insets = per-device constants table + manual override.** Built-in inset values keyed by device logical size (44/59/96pt families + orientation), auto-selected from the detected Simulator device (`SimulatorWindowTracker.activeSimulator` provides the device), with editable manual fields and a reset-to-device-values action. Manual override is the escape hatch for custom devices and zoomed displays; constants are not queryable live. — **Reversibility:** reversible — additive model on top of auto-selection.
- **D-03: Visual defaults + adjustable.** Ship strong adaptive defaults (system-adaptive blue grid lines; safe-area margins styled like Xcode's guides with translucent fill + stroke) AND keep the scaffold's existing color/opacity controls so the user can tune against any app palette. Extends existing service state (`gridColor`, `gridOpacity`) rather than deleting it. Amber accent stays reserved for active controls per design-guidelines — overlay content is not accent-tinted. — **Reversibility:** reversible.
- **D-04: Z-order — guides on top.** When grid/safe-area and a comparison image are both visible: grid/safe-area above ruler/magnifier readouts above the imported design image above Simulator content. The comparison image's opacity control remains the way to see through the artboard; guides are never hidden by the image. — **Reversibility:** costly — z-order decisions embedded in the overlay window/compositing architecture are cheaper to pin now than to reshuffle after renderers exist; rationale: multiple overlay surfaces and their paint order derive from this.

### Claude's Discretion
- **Scaffold disposition:** `DesignComparisonService` + `DesignComparisonView` carry a fake core (`pickColor(at:)` samples only our own window content per its own comment; grid/ruler toggles publish state that no overlay window consumes). Follow the Phase 2 precedent (02-01): research decides cut-over vs in-place hardening; do not preserve the stubs.
- **Overlay window architecture** (one shared overlay panel vs per-tool panels, click-through vs interactive capture modes, tracking via `SimulatorWindowTracker` frame updates): research + planning own this. Undiscussed by user choice.
- **Ruler/magnifier input model** (panel-driven vs on-Simulator interactive capture mode): undiscussed by user choice — research should present trade-offs in RESEARCH.md and planning picks one.
- **Design import path** (file open/drag, clipboard paste, Figma API fetch-by-URL): undiscussed by user choice. Note: Figma API integration adds network + token management surface — weigh against Apple-frameworks-only ethos before committing.
- **Magnifier behavior** (hover-follow loupe vs click-to-sample, magnification factor): undiscussed by user choice. Real screen sampling should ride the Phase 2 `SCScreenshotManager`/ScreenCaptureKit precedent (the sanctioned async exception); Screen Recording permission is already part of onboarding.
- **Safe-area table values** (exact per-family constants): research compiles them; D-02 locks only the mechanism.

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| REQ-roadmap-phase4-design-tools | Visual overlays — 8pt/4pt grid, safe-area insets, ruler with distance measurement, magnifier with color picker, Figma/Sketch design comparison, focus-persistent overlays, per-tool toggle persistence | Single persistent overlay NSPanel architecture (§Architecture Patterns), dual-grid + SafeAreaCatalog rendering (D-01/D-02), capture-mode ruler/magnifier over cached ScreenCaptureKit frame (§Pixel Sampling), file/drag/paste artboard import (§Import Path), panel config for focus persistence (§Pattern 2), @AppStorage/UserDefaults toggle persistence (§Pattern 6) |
</phase_requirements>

## Project Constraints (from CLAUDE.md)

- **Apple frameworks only** (AppKit, SwiftUI, Combine, CoreGraphics, ApplicationServices, ServiceManagement). Pulse/PulseProxy SPM exception exists (Phase 5) but nothing here needs it.
- **Swift 6 strict concurrency** — `@MainActor` on UI-touching classes; **no async/await at the architecture level** — Combine `@Published` + Timer; the single sanctioned async site is the ScreenCaptureKit capture path (CaptureService precedent: sync public API → `Task {}` bridge → async internals).
- **`SimCtlService`-only subprocess rule** — never spawn `xcrun simctl` directly.
- **Files < 200 LOC**, MARK order: Properties → Lifecycle → Public Methods → Private Methods → Extensions. `final class` preferred.
- **AppLogger** for all service logging (category enum in `Utilities/AppLogger.swift`); never log sensitive data.
- **DesignTokens.swift mandatory** — never hardcode layout values. Amber accent `#E8720C`/`#F59E0B` via `AccentColor` asset; **Phase 4 SF Symbols are pre-assigned in design-guidelines.md**: grid overlay `grid`, safe area `rectangle.dashed`, ruler `ruler`, color picker `eyedropper`.
- **Non-sandboxed** app; permissions at runtime (Screen Recording already in onboarding).
- **Reference implementation:** `../RocketSimApp/dev-docs/` is read-only reference for how features are designed/named/structured.
- **GitNexus directives** (from CLAUDE.md): run `gitnexus_impact` before editing symbols, `gitnexus_detect_changes()` before committing; never rename via find-and-replace. The executor should honor these during implementation.
- **`isReleasedWhenClosed = false`** and **`hidesOnDeactivate = false`** on all app-owned panels.

## Summary

Phase 4 turns the dead Design-tab scaffold into real overlay tooling. The scaffold's core is fake — `pickColor(at:)` builds an empty 1×1 bitmap and samples it (`// This only captures our own window content`, DesignComparisonService.swift:82-83), and its grid/ruler toggles publish state no window consumes. Following the Phase 2 precedent (02-01 "defective scaffold cut over"), the recommendation is a **cut-over**: keep the service's persistence shape and color-format helpers as seeds, replace the fake core, and add the missing overlay window layer.

The architecture centers on **one transparent, click-through `NSPanel`** (`DesignOverlayPanel`) that exactly covers the tracked Simulator window frame, hosting all four tools as ordered subviews. This makes D-04's locked z-order trivially enforceable (subview order, not window-server ordering — cross-level window stacking is absolute and same-level ordering depends on `orderFront` call order [VERIFIED: developer.apple.com/documentation/appkit/nswindow/level-swift.struct via Context7]). A controller subscribes `tracker.$activeSimulator` exactly as `SideWindowController.attach(to:)` does (verified pattern, SideWindowController.swift:90-98). Focus persistence (criterion 4) falls out of the panel config: `.floating` level + `.canJoinAllSpaces, .fullScreenAuxiliary` + `hidesOnDeactivate = false` + `.nonactivatingPanel` — all verified in the repo's own `SideWindowPanel.swift:28-30` and `AXHighlightPanel.swift:29-41`.

Pixel sampling (magnifier/color picker) rides the shipped Phase 2 path: `SCContentFilter(desktopIndependentWindow:)` + `SCScreenshotManager.captureImage` wrapped in `ScreenshotService` (ScreenshotService.swift:53-68), bridged to sync callers via `Task {}` (CaptureService.swift:127-135). The key performance insight: **capture once per arming, then sample locally from the cached CGImage** as the cursor moves — no per-move ScreenCaptureKit calls. Ruler/magnifier interactivity is a temporary "capture mode" where the panel flips `ignoresMouseEvents = false`; hover-follow uses `NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved)` (mouse events need no extra permission; the app already holds Accessibility for key events) [VERIFIED: developer.apple.com/documentation/appkit/nsevent/addglobalmonitorforevents].

The safe-area constants table (D-02) keys on **device name first, logical size as fallback** — verified per-generation values from Use Your Loaf (13/15/16 series) plus the Apple HIG dimensions list. One finding the planner must surface: **the D-02 "44/59/96pt families" shorthand contains no real 96pt iPhone safe-area family** (real tops: 20, 44–50, 47–62) and `375×812` is size-ambiguous (iPhone X = 44pt vs 13 mini = 50pt), which is why name-keying is the correct refinement of the locked mechanism.

**Primary recommendation:** Cut over the scaffold into `DesignOverlayService` (state) + `DesignOverlayPanel`/`DesignOverlayController` (one persistent click-through panel) + `PixelSamplerService` (cached-capture sampling) + `SafeAreaCatalog` (name-keyed constants) + five small overlay NSViews, with file/drag/paste artboard import and no Figma API.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Overlay rendering (grid, safe-area, ruler, magnifier, image) | Overlay window tier (`Windows/` NSPanel + NSViews) | — | Must composite above the Simulator's own window; AppKit owns window-server layering |
| Tool state, toggles, presets | Service tier (`Services/` ObservableObject) | Side panel UI | Service-container pattern (established); views only bind |
| Simulator frame tracking | Service tier (`SimulatorWindowTracker`) | Overlay controller sink | Tracker is the single frame authority (Phase 1); controller only reacts |
| Pixel sampling | Service tier (`PixelSamplerService` → `ScreenshotService`) | Magnifier view | ScreenCaptureKit + TCC preflight live in services (sanctioned async site) |
| Device → insets/size mapping | Service tier (`SafeAreaCatalog`, pure data) | Unit tests | Pure lookup — unit-testable without windows |
| Import UX (open/drag/paste) | Side panel UI tier (`DesignComparisonView`) | Service (image store) | Panel is the interaction surface; NSOpenPanel from view action, image lands in service |
| Measurement math (distance, point↔pixel mapping) | Service/utility tier | Overlay views | Pure functions; Y-flip and scale math must be unit-tested |

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| AppKit NSPanel/NSView | macOS 15+ SDK (Xcode 26.3 installed) | Transparent overlay window + `draw(_:)`-based tool renderers | Only way to composite over another app's window; repo precedent (AXHighlightPanel, SideWindowPanel) |
| ScreenCaptureKit (`SCScreenshotManager`) | macOS 15+ | One-shot Simulator-window capture for sampling | Shipped in Phase 2 (`ScreenshotService`); Screen Recording permission already onboarded |
| Combine | System | Tracker frame sync, tool-state propagation | Project-wide pattern; no async/await allowed |
| SwiftUI | macOS 15+ | Side-panel control UI only (not overlay rendering) | All 4 tabs already SwiftUI; overlay views stay AppKit for exact drawing control |
| UserNotifications-free, no new frameworks | — | — | Nothing in this phase needs a new framework |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `NSEvent.addGlobalMonitorForEvents` | macOS 10.6+ | Hover-follow magnifier cursor tracking over other apps | Only while magnifier armed |
| `NSPasteboard` / SwiftUI drag-drop | System | Artboard paste + drag import | Import path |
| `NSBitmapImageRep(cgImage:)` or CGImage data-provider read | System | Local pixel sampling from cached capture | Magnifier/color picker reads |
| `UniformTypeIdentifiers` | System | Constrain imported image types | Already imported by scaffold |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Single overlay panel, ordered subviews | Per-tool NSPanels | Per-tool panels make D-04 z-order depend on `orderFront` call order at same `.floating` level — fragile. Single panel pins order in one place. Rejected: multi-panel. |
| Cached-capture sampling | Per-mouse-move ScreenCaptureKit capture | Per-move captures are ~10-30ms async each and hammer TCC-gated APIs; one capture per arming + local `CGImage` reads are ~µs. Rejected: per-move. |
| AppKit `draw(_:)` overlay views | SwiftUI `NSHostingView` overlay | SwiftUI layer adds hosting overhead and fights exact line placement at device scale; AXHighlightView precedent is plain AppKit. Rejected for overlays (SwiftUI stays for the side panel). |
| File/drag/paste import | Figma REST API fetch-by-URL | API adds OAuth token management + network stack against Apple-only ethos (REQ-nfr-03 heritage); even RocketSim (commercial reference) ships file-based overlays and lists Figma/Sketch integration as *Planned* [CITED: RocketSimApp/dev-docs/project-roadmap.md:22-27, 92-99]. Rejected for v1. |
| `hidesOnDeactivate = false` persistent panel | Re-showing on focus events | Focus-event re-show flickers and fights the tracker's own focus sink; the repo already proves the persistent config (criterion 4). Rejected: focus-event approach. |

**Installation:**
```bash
# No packages to install — Apple frameworks only (project constraint).
```

**Version verification:** N/A — no external dependencies. Xcode 26.3 / Swift 6.2.4 / macOS 26.6.2 host probed this session (see Environment Availability).

## Package Legitimacy Audit

**Not applicable — this phase installs zero external packages.** All work uses AppKit, SwiftUI, Combine, CoreGraphics, ScreenCaptureKit, UniformTypeIdentifiers (system frameworks). No registry lookups, no postinstall surface. (REQ-nfr-03 heritage: Apple-only with the single Phase 5 Pulse exception, which this phase does not touch.)

## Architecture Patterns

### System Architecture Diagram

```
                    Simulator.app window (foreign app)
        ┌──────────────────────────────────────────────┐
        │  [Z4] Simulator content (device screen)      │
        │  ┌────────────────────────────────────────┐  │
        │  │ [Z3] ComparisonImageView (artboard,    │  │
        │  │      opacity/split)                    │  │
        │  │  ┌──────────────────────────────────┐  │  │
        │  │  │ [Z2] RulerOverlayView line +     │  │  │
        │  │  │      MagnifierView loupe         │  │  │
        │  │  │  ┌────────────────────────────┐  │  │  │
        │  │  │  │ [Z1] GridOverlayView (8/4) │  │  │  │
        │  │  │  │      SafeAreaOverlayView   │  │  │  │
        │  │  │  └────────────────────────────┘  │  │  │   D-04: subview order
        │  │  └──────────────────────────────────┘  │  │   inside ONE panel =
        │  └────────────────────────────────────────┘  │   locked paint order
        └──────────────────────────────────────────────┘
              ▲ setFrame(simulator frame)   ▲ click-through ⇄ capture mode
              │                             │ (ignoresMouseEvents flip)
┌─────────────────────────────┬───────────────────────────────────┐
│ DesignOverlayController     │ Side panel (SwiftUI, 260pt)       │
│ (Windows/, @MainActor)      │ DesignComparisonView → controls   │
│  sink tracker.$active-      │  DesignOverlayService             │
│  Simulator → panel frame    │  (Services/, @Published toggles,  │
│  sink service → tool views  │  @AppStorage persistence)         │
└────────────┬────────────────┴─────────────┬─────────────────────┘
             │ arm sampler                  │ import (open/drag/paste)
             ▼                              ▼
┌─────────────────────────────┐   ┌──────────────────────────────┐
│ PixelSamplerService         │   │ SafeAreaCatalog (pure data)  │
│  Task{} → ScreenshotService │   │  deviceName → insets +       │
│  → cached CGImage (memory)  │   │  logical size; size fallback │
│  sample(point) → NSColor    │   │  + manual override fields    │
└─────────────────────────────┘   └──────────────────────────────┘
```

Primary use case trace: user toggles Grid in the side panel → `DesignOverlayService.showGrid` publishes → controller unhides `[Z1]` subview → grid renders at device-point spacing over Simulator content. Sampling: user arms picker → controller flips panel to capture mode + `PixelSamplerService` captures once → cursor moves fire global mouseMoved → loupe reads cached pixels → click commits `pickedColor` → panel returns to click-through.

### Recommended Project Structure
```
BoosterSimApp/
├── Windows/
│   ├── DesignOverlayPanel.swift        # ONE borderless NSPanel; subview z-order; capture-mode toggle
│   └── DesignOverlayController.swift   # lifecycle, tracker sink (frame sync), service sink, input mode
├── Services/
│   ├── DesignOverlayService.swift      # replaces DesignComparisonService; toggles, image, picked color,
│   │                                   #   ruler state, presets; @AppStorage/UserDefaults persistence
│   ├── PixelSamplerService.swift       # Task{} bridge → ScreenshotService; cached CGImage; sample(point:)
│   └── SafeAreaCatalog.swift           # name-keyed inset constants + logical-size fallback + scale math input
├── Views/
│   ├── Overlay/                        # new folder; plain AppKit NSViews, draw(_:) based, each < 200 LOC
│   │   ├── GridOverlayView.swift       # D-01 dual 8pt/4pt major-minor grid
│   │   ├── SafeAreaOverlayView.swift   # Xcode-guide-style translucent fill + stroke (D-03)
│   │   ├── RulerOverlayView.swift      # measurement line, tick marks, distance readout
│   │   ├── MagnifierView.swift         # loupe image + color swatch + hex readout
│   │   └── ComparisonImageView.swift   # artboard NSImage, opacity, D-04 z3 position, optional split
│   └── SideWindow/
│       └── DesignComparisonView.swift  # existing control panel, rewired to DesignOverlayService
└── BoosterSimAppTests/
    ├── SafeAreaCatalogTests.swift      # Wave 0
    ├── GridGeometryTests.swift         # Wave 0
    ├── OverlayPersistenceTests.swift   # Wave 0
    └── RulerMathTests.swift            # Wave 0
```

### Pattern 1: Persistent Transparent Overlay Panel (D-04 carrier)
**What:** One borderless, non-activating, click-through NSPanel pinned to the Simulator frame.
**When to use:** All four tools; the panel exists whenever any tool is on.
**Example (config assembled from the repo's two verified panels):**
```swift
// Source: BoosterSimApp/Windows/SideWindowPanel.swift:28-30 + AXHighlightPanel.swift:29-41 (both verified in-repo)
super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
           backing: .buffered, defer: false)
isOpaque            = false
backgroundColor     = .clear
level               = .floating
ignoresMouseEvents  = true                      // click-through by default; false only in capture mode
collectionBehavior  = [.canJoinAllSpaces, .fullScreenAuxiliary]
isReleasedWhenClosed = false                    // controller owns lifecycle
hidesOnDeactivate   = false                     // criterion 4: survives app focus loss
contentView         = overlayContainerView      // subview order = D-04 paint order
```

### Pattern 2: Tracker Frame Sync (existing precedent, reuse verbatim)
**What:** Subscribe `$activeSimulator` and `setFrame` the panel to the Simulator window frame.
**When to use:** Overlay controller `attach(to:)` — same shape as SideWindowController.
**Example:**
```swift
// Source: BoosterSimApp/Windows/SideWindowController.swift:90-98 (verified in-repo)
func attach(to tracker: SimulatorWindowTracker) {
    trackerCancellable = tracker.$activeSimulator.sink { [weak self] simulator in
        guard let self else { return }
        if let sim = simulator {
            self.overlayPanel.setFrame(sim.frame, display: true)  // overlay covers the whole window
            self.overlayPanel.orderFront(nil)
        } else {
            self.overlayPanel.orderOut(nil)                       // no Simulator → no overlay
        }
    }
}
```
Note: unlike the side panel (which parks beside the Simulator), the overlay **is** the Simulator frame — `sim.frame` used directly, no PositionCalculator.

### Pattern 3: Cached-Capture Pixel Sampling (magnifier + color picker)
**What:** One ScreenCaptureKit capture per arming; all cursor-position reads hit the cached CGImage locally.
**When to use:** Magnifier hover, click-to-sample, and re-capture only on Simulator frame change or re-arm.
**Example:**
```swift
// Async internals ride the sanctioned exception (CaptureService.swift:127-135 pattern, verified in-repo):
func arm() {
    guard let sim = tracker.activeSimulator, CGPreflightScreenCaptureAccess() else { return }  // :203
    Task { [weak self] in
        let image = try? await self?.screenshotService.capture(windowID: sim.id, windowFrame: sim.frame)
        self?.cachedCapture = image   // pixels = sim.frame × backingScale (ScreenshotService.pixelSize)
    }
}
/// Sync, main-thread: window point → pixel row/col (CGImage is TOP-origin; AppKit is BOTTOM-origin)
func sampleColor(at windowPoint: CGPoint) -> NSColor? { /* flip Y against frame.height, × scale */ }
```

### Pattern 4: Capture-Mode Input (interactive tools over a click-through panel)
**What:** When ruler/magnifier arms, flip `ignoresMouseEvents = false` (+ `acceptsMouseMovedEvents = true`); on commit/cancel/Esc, flip back. Esc while the panel can't become key arrives via a local event monitor (`addLocalMonitorForEvents`) removed on disarm.
**When to use:** Ruler click-drag, picker click-to-commit; global `mouseMoved` monitor feeds the hover loupe (works over the Simulator because global monitors see other apps' events; own-app events don't fire it — irrelevant here since the overlay itself is transparent to the cursor except in capture mode).

### Pattern 5: Device-Space Grid Alignment (D-01)
**What:** Grid spacing in window points = device logical points × `scale`, where `scale = deviceScreenAreaWidth / deviceLogicalWidth`. `deviceLogicalWidth` comes from `SafeAreaCatalog` (auto-selected via `activeSimulator.deviceName`); `deviceScreenArea` = window content rect (window frame minus title bar; manual calibration fields as the D-02 escape hatch for bezel-on windows).
**Why:** 8pt/4pt lines must land on real device points or the overlay lies. Drawing uses `NSBezierPath` with crisp 1px lines at `window.backingScaleFactor`.

### Pattern 6: Persistence (toggles + presets)
**What:** Per-tool toggles via `@AppStorage`-backed `AppSettings` (code-standards: "no raw UserDefaults in views"); presets as `Codable` arrays in UserDefaults (established `DesignPreset` pattern) under a **new schema** — see Runtime State Inventory for the legacy-key decision.

### Anti-Patterns to Avoid
- **Multiple same-level overlay windows for z-order:** window-server stacking within one level follows `orderFront` call order — an invisible, order-dependent contract. Use subview order in one panel (D-04).
- **Per-mouse-move ScreenCaptureKit captures:** async latency (~10–30ms) makes the loupe laggy and hammers a TCC-gated API. Cache one frame.
- **Sampling CGImage rows in AppKit Y orientation:** CGImage pixel (0,0) is top-left; AppKit points are bottom-origin. The scaffold's `pickColor(at:)` already demonstrates this confusion (it flips against *screen* height for a *window*-local sample). Centralize the flip in one tested function.
- **Hardcoding 2× pixel scale:** capture pixels = frame × display `backingScale` (1× external monitors exist) — `ScreenshotService.backingScale`/`pixelSize` already handle this (02 review WR-03); reuse, don't re-derive.
- **Hiding the grid behind the comparison image:** never let the image view cover guide layers regardless of toggle order (D-04 — guides are never hidden by the image).
- **Amber-tinting overlay content:** amber is reserved for active controls in the side panel; overlay guides use adaptive blue/system colors (D-03).

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Window capture for sampling | CGDisplayStream/CGWindowListCreateImage pipelines | `ScreenshotService.capture` (ScreenCaptureKit, shipped) | CGWindowListCreateImage is deprecated on macOS 15; SCK path is TCC-preflighted and scale-correct in-repo |
| Backing-scale math | Manual 2× assumptions | `ScreenshotService.backingScale(for:screens:)` / `pixelSize(for:scale:)` | 1× external displays; 02-review WR-03 already fixed this |
| Color formatting | New hex/rgba string code | Scaffold's `colorToHex`/`colorToRGB` (keep in cut-over) | Verified working (DesignComparisonService.swift:95-107) |
| Window enumeration/tracking | New polling/AX plumbing | `SimulatorWindowTracker.activeSimulator` | Single frame authority since Phase 1; REQ-nfr-06 degradation built in |
| Image type filtering | Manual extension checks | `UTType.image` via `NSOpenPanel.allowedContentTypes` | Scaffold already does this (line 56) |
| Device inset/size data | Live query of the simulator app | `SafeAreaCatalog` constants + manual override | D-02 locks constants-as-data ("constants are not queryable live"); manual override is the escape hatch |
| Global cursor position | CGEvent taps (interception) | `NSEvent.addGlobalMonitorForEvents` (observe-only) | Taps require permissions and can modify events — overkill and riskier for a loupe |

**Key insight:** Every hard part of this phase (overlay compositing, TCC-gated capture, frame tracking, scale math) already exists in the repo from Phases 1–2. Phase 4 is composition + drawing, not infrastructure.

## Runtime State Inventory

> Included because this phase replaces/refactors the existing Design scaffold (Phase 2 precedent 02-01 cut-over).

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | UserDefaults key `"DesignComparisonPresets"` (`private let presetsKey = "DesignComparisonPresets"` — DesignComparisonService.swift:44) holding legacy `DesignPreset {id, name, mode, opacity, gridSpacing, showGrid, showRuler}` (lines 32-40, verbatim). D-01 removes `gridSpacing`; new schema won't decode cleanly — current `loadPresets()` uses `try?` so legacy data **silently vanishes** (lines 138-142). | Code edit: version the key (e.g. `DesignOverlayPresets`) or wrap a tolerant legacy→new mapping; decide in planning. Not a data migration — no server, local defaults only. |
| Live service config | None — no external service holds design-tool state. Verified: the phase touches only local windows/defaults. | None |
| OS-registered state | None — no Task Scheduler/launchd/pm2 items; app registrations (login item) are unrelated to this scaffold. | None |
| Secrets/env vars | None — no secrets in scaffold (grep of DesignComparisonService shows only the presets key). | None |
| Build artifacts | None — synchronized groups (no pbxproj edits needed for new files, per Phase 5 STATE.md decision); no external builds. | None |

## Common Pitfalls

### Pitfall 1: Z-order by window level instead of subview order
**What goes wrong:** Guides and image in separate panels at `.floating` — ordering follows `orderFront` call order; a later image `orderFront` puts the image above the grid, violating D-04.
**Why it happens:** Window-server stacking *within* a level is call-order; *across* levels it's absolute ("the bottom window in a higher level will obscure the top window of the level below it" [VERIFIED: developer.apple.com via Context7]).
**How to avoid:** One panel; D-04 order = `addSubview` order (grid/safe-area last = topmost).
**Warning signs:** Toggling tools in different sequences changes layering.

### Pitfall 2: Y-axis and scale mismatches when sampling
**What goes wrong:** Picked color is wrong-pixel or nil near edges; loupe shows mirrored content.
**Why it happens:** Three coordinate spaces in play: AppKit window points (bottom-origin), CGImage pixels (top-origin), and device logical points (grid space) — plus `backingScale` multiplication. The scaffold's fake already flipped against the wrong reference (screen height for a window-local sample).
**How to avoid:** One pure, unit-tested mapper: `windowPoint → imagePixel(point, frame.height, scale)`; one pure `windowPoint → devicePoint(contentRect, logicalSize)`.
**Warning signs:** Off-by-`titleBarHeight` errors; colors correct at top-left, wrong at bottom.

### Pitfall 3: Simulator device bezels shift the device screen area
**What goes wrong:** Grid aligns perfectly with bezels off, drifts when Simulator's View → Show Device Bezels is enabled (window gains bezel padding around the screen).
**Why it happens:** `sim.frame` is the whole window, not the device screen rect; bezel padding is unknown from CGWindow data.
**How to avoid:** v1 assumes bezels off (default for modern iPhone simulators [ASSUMED]) with content rect = frame minus title bar; ship manual calibration fields (D-02 escape hatch covers this too). Optional robust path: detect the screen rect from the cached capture (uniform bezel margins).
**Warning signs:** Smoke test with bezels on shows horizontal offset growing symmetrically.

### Pitfall 4: Capture-mode focus and key handling
**What goes wrong:** Esc doesn't cancel the ruler; clicking the overlay steals key focus from the Simulator; hover events don't arrive.
**Why it happens:** `.nonactivatingPanel` doesn't make the panel key; `acceptsMouseMovedEvents` defaults false; global monitors don't fire for own-app events (so local monitoring is needed for in-panel movement) [VERIFIED: developer.apple.com addGlobalMonitorForEvents docs].
**How to avoid:** `becomesKeyOnlyIfNeeded`; explicit `acceptsMouseMovedEvents = true` + `NSTrackingArea` in capture mode; cancel-Esc via a temporary `addLocalMonitorForEvents`; never `makeKeyAndOrderFront` — always `orderFront`.
**Warning signs:** Simulator title bar greys (focus stolen) when arming a tool.

### Pitfall 5: Legacy presets silently dropped
**What goes wrong:** Users lose saved presets without explanation after update.
**Why it happens:** `try? JSONDecoder().decode` returns nil on schema mismatch → empty list (scaffold lines 138-142).
**How to avoid:** Version the persistence key; optionally map legacy fields (mode/opacity/showGrid/showRuler carry over; `gridSpacing` maps to "4pt on" state).
**Warning signs:** Empty preset list after first launch of the new build.

### Pitfall 6: A second async site violating the concurrency convention
**What goes wrong:** New service sprinkles `async`/`Task` outside the sanctioned capture path; CONVENTIONS drift (STATE.md: the exemption list is deliberately tiny — "CaptureService alone" per Phase 3 note).
**Why it happens:** PixelSamplerService needs `await screenshotService.capture(...)`.
**How to avoid:** Copy the CaptureService shape exactly: `@MainActor final class`, sync public API, single private `Task {}` bridge; update `docs/code-standards.md` exemption wording in the phase's docs truth pass if the list is meant to name the pattern rather than one type.
**Warning signs:** Code review finds `await` in views or controllers.

### Pitfall 7: 1× display breaks pixel math
**What goes wrong:** Captures and grid hairlines are 2×-scaled on Retina-only assumptions — wrong size on 1× external monitors.
**Why it happens:** Hardcoded scale factors.
**How to avoid:** Always through `ScreenshotService.backingScale` (capture) and `window.backingScaleFactor` (drawing).
**Warning signs:** Overlay lines 2px on external monitor; sampled pixel offset ×2.

## Code Examples

### Dual 8pt/4pt grid draw (D-01)
```swift
// Pattern (AXHighlightView draw precedent — AXHighlightPanel.swift:8-16, in-repo):
override func draw(_ dirtyRect: NSRect) {
    guard let geom = geometry else { return }            // contentRect + scale + logicalSize
    let minor = geom.pointSize * 4                        // 4 device-pt → window-pt via scale
    let major = geom.pointSize * 8
    drawLines(spacing: minor, width: 1.0 / window.backingScaleFactor,
              color: gridColor.withAlphaComponent(gridOpacity * 0.5))   // 4pt subdued
    drawLines(spacing: major, width: 1.5 / window.backingScaleFactor,
              color: gridColor.withAlphaComponent(gridOpacity))         // 8pt emphasized
}
```
(Exact emphasis weights are D-03 "strong adaptive defaults" — tune at implementation against Figma's major-minor look.)

### Safe-area guide draw (D-02/D-03, Xcode-guide style)
```swift
// Translucent fill + stroke over the inset bands; insets from SafeAreaCatalog in DEVICE points,
// converted to window points through the same geometry mapper as the grid.
let band = NSBezierPath(rect: topBandRect)             // e.g. height = inset.top * scale
NSColor.systemBlue.withAlphaComponent(0.15).setFill()  // adaptive, not accent amber (D-03)
band.fill()
NSColor.systemBlue.withAlphaComponent(0.6).setStroke()
band.lineWidth = 1.0 / window.backingScaleFactor
band.stroke()
```

### Safe-area catalog lookup (D-02 mechanism, name-keyed)
```swift
// Values below verified for the cited generations; full table in SafeAreaCatalog section.
enum SafeAreaCatalog {
    static func insets(for deviceName: String?, logicalSize: CGSize?) -> Insets {
        if let name = deviceName, let exact = byName[name] { return exact }   // 1st: device name
        if let size = logicalSize, let bySize = byLogicalSize[size] { return bySize } // 2nd: size
        return .manualDefaults                                                  // 3rd: manual override
    }
}
```

### State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `CGWindowListCreateImage` for window pixels | ScreenCaptureKit `SCScreenshotManager.captureImage` | macOS 14+; CGWindowListCreateImage deprecated | Phase 2 already on SCK — reuse; never add the deprecated API |
| Manual device-size tables from marketing names | Keyed constants + simctl-classified device name (`SimulatorWindowTracker.refreshDeviceTypeCache`) | In-repo, Phase 1 | Catalog keys on the tracker's `deviceName`, not new simctl calls |
| Pre-notched uniform 20pt status bar | Per-generation insets (44/47/48/50/54/59/62) | iOS X→16 era | Table is per-logical-size/name; "44/59/96" shorthand in D-02 is not the real value set — see Assumptions |

**Deprecated/outdated:**
- `CGWindowListCreateImage`: deprecated for cross-window capture on macOS 15 — do not use.
- Single `gridSpacing` scaffold model (default 20): superseded by D-01 dual grid — delete, don't parameterize.

## SafeAreaCatalog — Verified Constants Table (D-02 values)

**Key order (refines D-02's "keyed by device logical size"):** device **name** first (from `SimulatorWindowTracker.activeSimulator.deviceName`), logical size second, manual override third. Name-keying is required because sizes collide: `375×812` is both iPhone X/XS/11 Pro (top 44 [ASSUMED]) and iPhone 12/13 mini (top 50 [CITED]) — a size-only key picks the wrong insets for one of them.

**Verified rows** (portrait top/bottom; landscape top 0, sides = portrait top, bottom 21):

| Logical size (pt) | Devices | Top | Bottom | Provenance |
|---|---|---|---|---|
| 393×852 | iPhone 15, 15 Pro, 16, 14 Pro | 59 | 34 | "Safe Area Insets (portrait): top: 59, bottom: 34, left: 0, right: 0" [CITED: useyourloaf.com/blog/iphone-16-screen-sizes/] (14 Pro: 54 [ASSUMED — predates the 15's "59"] ) |
| 430×932 | iPhone 15 Plus, 15 Pro Max, 16 Plus, 14 Pro Max | 59 | 34 | Same row quoted as iPhone 16 Plus: "top: 59, bottom: 34" [CITED: same] |
| 402×874 | iPhone 16 Pro | 62 | 34 | "The status bar is 54 points high with a top safe area inset of 62 points" [CITED: same] |
| 440×956 | iPhone 16 Pro Max | 62 | 34 | "top safe area inset of 62 points" [CITED: same] |
| 390×844 | iPhone 12, 12 Pro, 13, 13 Pro, 14 | 47 | 34 | "Safe Area Insets (portrait): top: 47, bottom: 34, left: 0, right: 0" [CITED: useyourloaf.com/blog/iphone-13-screen-sizes/] |
| 428×926 | iPhone 12 Pro Max, 13 Pro Max, 14 Plus | 47 | 34 | Same post: "(same as the iPhone 13)" [CITED: same] |
| 375×812 | iPhone 12 mini, 13 mini | 50 | 34 | "Safe Area Insets (portrait): top: 50, left: 0, bottom: 34, right: 0" [CITED: same] |
| 420×912 | iPhone Air | ? | ? | Dimensions listed [CITED: developer.apple.com/design/human-interface-guidelines/layout — search snippet]; insets not yet documented this session → default to 59-family + manual override |
| 402×874† | iPhone 17 | ? | ? | HIG lists 402×874 for iPhone 17 [CITED: same] — collides with 16 Pro; name key resolves |

**Unverified legacy rows** (all [ASSUMED] — classic pre-13 values, stable for years but not source-verified this session):
| 375×812 | iPhone X, XS, 11 Pro | 44 | 34 | [ASSUMED] |
| 414×896 | iPhone XR, 11 (@2x); XS Max, 11 Pro Max (@3x) | 48 | 34 | [ASSUMED] |
| 375×667 | iPhone SE 2/3, 8, 7, 6s | 20 | 0 | [ASSUMED] |
| 414×736 | iPhone 8/7/6s Plus | 20 | 0 | [ASSUMED] |
| 320×568 | iPhone SE 1st, iPod touch 7 | 20 | 0 | [ASSUMED] |
| iPad sizes (744–1366pt) | iPad family | 20–24 | 20 | [ASSUMED] |

**Notes:**
- Status-bar height ≠ safe-area top on Dynamic Island devices: status bar 54pt, inset 59pt (16-series) — the overlay should draw the **safe-area inset**, matching Xcode's guides [CITED: useyourloaf 16-series post].
- Landscape verified shape: "Safe Area Insets (landscape): top: 0, bottom: 21, left: 59, right: 59" [CITED: useyourloaf 16-series post].
- **"96pt family" from D-02:** no iPhone safe-area top equals 96 in any source consulted this session. The real set is {20, 44, 47, 48, 50, 54, 59, 62}. Flagged in Assumptions Log — the locked *mechanism* (constants table + manual override) is unaffected; planner should surface the shorthand discrepancy at next user contact, not block on it.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Legacy iPhone insets (44/48/20 rows) and iPad rows (20–24) | SafeAreaCatalog table | Wrong guide position on old devices; manual override hides it; low severity |
| A2 | D-02's "96pt family" is discuss-phase shorthand — no such iPhone inset exists | SafeAreaCatalog notes | User intended something specific by "96" (possibly iPad windowed mode); if so, one table row + override covers it |
| A3 | iPhone 17/Air insets default to 59-family | SafeAreaCatalog + Open Questions | Guides off by a few pt on newest devices until confirmed; manual override covers |
| A4 | Simulator window content rect = frame minus ~28pt title bar when bezels off; bezels-off is the common default | Pattern 5, Pitfall 3 | Grid misalignment for bezel-on users; manual calibration is the escape hatch |
| A5 | Cached-capture sampling is acceptable freshness for the magnifier (re-capture on frame change/arming) | Pattern 3 | Stale loupe content if Simulator content changes mid-hover — mitigated by re-capture triggers |
| A6 | File/drag/paste import satisfies "import a Figma/Sketch artboard" (users export PNG themselves) | Import Path | If the user expected native .fig/.sketch file parsing, scope changes materially — neither format is publicly documented; flag at planning |
| A7 | 14 Pro top inset = 54 | SafeAreaCatalog | Minor; same-size 15-series row (59) dominates in practice |

## Open Questions

1. **Split comparison mode: keep or cut?**
   - What we know: scaffold has `ComparisonMode.overlay`/`.split` + `splitPosition`; D-04 defines z-order only for overlay mode.
   - What's unclear: whether split view (left half design, right half Simulator) is in scope for "design comparison overlay".
   - Recommendation: keep as a cheap mode of `ComparisonImageView` (clip rect), since state already exists; cut only if planning wants tighter scope.
2. **Legacy preset disposition** — versioned new key vs tolerant legacy mapping (Pitfall 5). Recommendation: new key `DesignOverlayPresets` + one-shot best-effort legacy import; presets are low-value data.
3. **17-series rows** — confirm iPhone 17/Air insets at smoke time against a live simulator (readout from any running app's safe-area) or leave manual. Recommendation: verify opportunistically during phase-gate smoke; don't block.
4. **Magnifier default factor** — 4× vs 8× loupe. Recommendation: 8× default, adjustable stepper; not load-bearing.
5. **Bezel-on alignment** — manual calibration fields (recommended v1) vs capture-based screen-rect detection (deferred enhancement). Recommendation: manual fields now; detection is a v2 candidate.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Xcode + xcodebuild | Build/test gate | ✓ | Xcode 26.3 | — |
| Swift 6 strict concurrency | All code | ✓ | 6.2.4 | — |
| macOS host ≥ 15 | Runtime target | ✓ | 26.6.2 | — |
| `xcrun simctl` | Tracker device cache (existing) | ✓ | Xcode 26.3 toolchain | — |
| Booted iOS Simulator | Smoke test only | ✗ at research time | — | Boot any device before smoke (`simctl boot` / Simulator.app) |
| Screen Recording permission | PixelSamplerService | ✓ by design | — | Granted in onboarding (Phase 1, REQ-fr-09); preflight via `CGPreflightScreenCaptureAccess()` (CaptureService.swift:203) |

**Missing dependencies with no fallback:** none.
**Missing dependencies with fallback:** booted Simulator needed only at verification time.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | XCTest (existing `BoosterSimAppTests` target; 20 unit files incl. `ScriptedSimCtl` fixture) |
| Config file | none — scheme-based (`BoosterSimApp.xcodeproj`, scheme `BoosterSimApp`) |
| Quick run command | `xcodebuild -project BoosterSimApp.xcodeproj -scheme BoosterSimApp -destination 'platform=macOS' test -only-testing:BoosterSimAppTests -skip-testing:BoosterSimAppUITests -parallel-testing-enabled NO` |
| Full suite command | `xcodebuild -project BoosterSimApp.xcodeproj -scheme BoosterSimApp -destination platform=macOS test` (config.json `test_command`; gate timeout 1500s) |

(`-parallel-testing-enabled NO` per STATE.md pre-existing issue: parallel xcodebuild runs hang intermittently. Note also the pre-existing unfiltered-suite exit-65 UI-test flake — unit-bundle-only is the established phase-gate standard.)

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| REQ-roadmap-phase4-design-tools | Catalog lookup: name hit, size fallback, unknown → manual defaults | unit | quick cmd + `-only-testing:BoosterSimAppTests/SafeAreaCatalogTests` | ❌ Wave 0 |
| REQ-roadmap-phase4-design-tools | Dual-grid geometry: 8/4 spacing in device points → window points under scale; no drift across frame sizes | unit | quick cmd + `-only-testing:BoosterSimAppTests/GridGeometryTests` | ❌ Wave 0 |
| REQ-roadmap-phase4-design-tools | Point mapping: window point → CGImage pixel (Y-flip + backingScale) round-trips; window point → device point | unit | quick cmd + `-only-testing:BoosterSimAppTests/RulerMathTests` | ❌ Wave 0 |
| REQ-roadmap-phase4-design-tools | Persistence: toggles round-trip; legacy `DesignComparisonPresets` payload doesn't crash new decode | unit | quick cmd + `-only-testing:BoosterSimAppTests/OverlayPersistenceTests` | ❌ Wave 0 |
| REQ-roadmap-phase4-design-tools | Color formatting: hex/RGB strings (scaffold helpers kept) | unit | piggyback OverlayPersistenceTests or ColorFormatTests | ❌ Wave 0 |
| REQ-roadmap-phase4-design-tools | Overlay visible over Simulator, survives focus loss, toggles per tool; ruler distance readout; loupe sampling correct pixel; import via open/drag/paste | smoke (manual, blocking-human six-group per Phase 3 gate pattern) | phase-gate smoke script | manual-only — NSPanel compositing over a foreign window and TCC-gated capture are not meaningfully unit-testable |

### Sampling Rate
- **Per task commit:** quick unit command (unit bundle only, exit 0 standard per Phase 5 gate).
- **Per wave merge:** unit bundle + Debug build (`xcodebuild -project BoosterSimApp.xcodeproj -scheme BoosterSimApp -configuration Debug build`).
- **Phase gate:** full unit bundle green + blocking-human smoke (booted Simulator; covers criteria 1–4 visually).

### Wave 0 Gaps
- [ ] `BoosterSimAppTests/SafeAreaCatalogTests.swift` — catalog rows incl. 375×812 name-disambiguation
- [ ] `BoosterSimAppTests/GridGeometryTests.swift` — spacing/scale math
- [ ] `BoosterSimAppTests/RulerMathTests.swift` — Y-flip/scale mapping + distance
- [ ] `BoosterSimAppTests/OverlayPersistenceTests.swift` — toggle + preset round-trip, legacy-key tolerance
- [ ] Framework install: none needed (XCTest in place)

## Security Domain

> security_enforcement absent from config → included.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | N/A — local dev tool, no accounts |
| V3 Session Management | no | N/A |
| V4 Access Control | no | N/A — single-user desktop app |
| V5 Input Validation | **yes** | Imported images are untrusted input: constrain via `UTType.image` (scaffold already does) + **cap decoded pixel dimensions** before retaining (decompression-bomb guard: a 50k×50k PNG can OOM the app) |
| V6 Cryptography | no | No crypto in scope; never hand-roll any |
| V14 Config | minor | No secrets; defaults only via UserDefaults |

### Known Threat Patterns for this Stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Decompression bomb via imported artboard | DoS | Check `NSImage.size`/CGImage dims against a max (e.g. 16384px edge) before caching; reject with a status caption, not a crash |
| Captured-screen data leakage | Information Disclosure | Cached CGImage stays memory-only; never written to disk or logged; AppLogger calls must never include pixel data or full captured frames |
| Screen Recording permission over-reach | Elevation/Privacy | Sample only the tracked Simulator window via `desktopIndependentWindow` filter (Phase 2 design — prevents capturing BoosterSimApp/other apps); preflight `CGPreflightScreenCaptureAccess()` and degrade with a caption when denied |
| Pasteboard type spoofing | Tampering | Read images via typed pasteboard APIs (`NSImage.self` / UTType-constrained); ignore non-image payloads |

## Sources

### Primary (HIGH confidence — in-repo, read this session)
- `BoosterSimApp/Services/DesignComparisonService.swift` — scaffold state, fake `pickColor` (68-86), presets key (44), color helpers (95-107)
- `BoosterSimApp/Windows/AXHighlightPanel.swift` + `SideWindowPanel.swift` — verified overlay-panel configs (incl. `hidesOnDeactivate = false` SideWindowPanel.swift:29)
- `BoosterSimApp/Windows/SideWindowController.swift:90-110` — tracker attach/focus-sink pattern
- `BoosterSimApp/Services/SimulatorWindowTracker.swift` + `Models/SimulatorWindow.swift:22-36` — `activeSimulator` fields (deviceName, frame, udid)
- `BoosterSimApp/Services/ScreenshotService.swift:53-100` + `CaptureService.swift:127-135, 202-219` — SCK capture, Task-bridge, TCC preflight, scale math
- `BoosterSimApp/Utilities/DesignTokens.swift:7-35` — Spacing/CornerRadius/SideWindowMetrics
- `docs/design-guidelines.md` + `docs/code-standards.md` + `.planning/intel/constraints.md` — Phase 4 SF Symbols, accent rules, file/MARK/concurrency rules
- `.planning/phases/04-design-tools/04-CONTEXT.md`, `.planning/REQUIREMENTS.md`, `.planning/ROADMAP.md:116-129`, `.planning/STATE.md`
- `RocketSimApp/dev-docs/project-roadmap.md:22-27, 92-99` — reference app: file-based overlays shipped; Figma/Sketch API integration still "Planned" there

### Secondary (MEDIUM confidence)
- Context7 `/websites/developer_apple_appkit` → developer.apple.com: `ignoresMouseEvents`, `nonactivatingPanel`, `canJoinAllSpaces`, window-level stacking semantics
- developer.apple.com/documentation/appkit/nsevent/addglobalmonitorforevents(matching:handler:) (via sosumi) — global monitor semantics, AX requirement for key events only
- useyourloaf.com/blog/iphone-16-screen-sizes/, /iphone-15-screen-sizes/, /iphone-13-screen-sizes/ — verified safe-area insets + logical sizes (quotes in SafeAreaCatalog section)
- developer.apple.com/design/human-interface-guidelines/layout (search snippet) — iPhone Air/17 logical dimensions

### Tertiary (LOW confidence)
- Figma/Sketch artboard export workflow (designers export PNG @1x/2x/3x) — common practice, no single authoritative doc; assumptions A6

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — Apple frameworks, zero new dependencies, all precedents in-repo
- Architecture: HIGH — every pattern verified against shipped repo code; single-panel D-04 mechanism grounded in official window-level docs
- Safe-area constants: MEDIUM — 13/15/16-series verified via Use Your Loaf; legacy rows and 17-series flagged [ASSUMED]
- Pitfalls: HIGH — coordinate/scale/z-order pitfalls traceable to real scaffold bugs or official docs

**Research date:** 2026-08-31
**Valid until:** 2026-09-30 (stable Apple APIs; 17-series constants may firm up sooner)
