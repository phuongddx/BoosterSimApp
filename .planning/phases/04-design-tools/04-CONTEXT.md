# Phase 4: Design Tools - Context

**Gathered:** 2026-08-31
**Status:** Ready for planning

<domain>
## Phase Boundary

Pixel-inspection and comparison overlays rendered **on top of the Simulator window**: dual 8pt/4pt grid + safe-area inset overlays, ruler with distance measurement, magnifier with color picker, Figma/Sketch artboard import as a design comparison overlay, and per-tool toggles whose overlays persist when the app loses focus (REQ-roadmap-phase4-design-tools).

This phase delivers the missing overlay rendering layer (transparent windows tracking the Simulator frame) and completes/replaces the existing Design-tab scaffold. It does not add new tool categories beyond the four roadmap criteria.

</domain>

<decisions>
## Implementation Decisions

### Grid & Safe-Area (user-locked 2026-08-31)
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

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Design system & code standards
- `docs/design-guidelines.md` — the 12-constraint design SPEC (utility-first native macOS feel; amber accent for primary CTA/active indicators only; semantic system colors; SF Pro/SF Symbols; 4pt spacing grid; SideWindowMetrics)
- `.planning/intel/constraints.md` — full design-system + platform constraints digest from the docs ingest
- `docs/code-standards.md` — file <200 LOC, MARK order, SimCtlService-only subprocess rule, AppLogger, no try!/as! on user data
- `BoosterSimApp/Utilities/DesignTokens.swift` — Spacing/CornerRadius/SideWindowMetrics constants (mandatory; never hardcode layout values)

### Requirements & phase scope
- `.planning/REQUIREMENTS.md` — REQ-roadmap-phase4-design-tools (pending) + traceability
- `.planning/ROADMAP.md` § Phase 4 — goal, criteria 1–4, depends on Phase 1

### Existing code to study before designing
- `BoosterSimApp/Services/DesignComparisonService.swift` — the scaffold being completed/replaced (state model, presets persistence key `DesignComparisonPresets`)
- `BoosterSimApp/Views/SideWindow/DesignComparisonView.swift` + `BoosterSimApp/Views/SideWindow/tabs/DesignTabView.swift` — current Design tab UI
- `BoosterSimApp/Windows/AXHighlightPanel.swift` — transparent borderless NSPanel precedent over the Simulator (floating level, ignoresMouseEvents, canJoinAllSpaces, fullScreenAuxiliary)
- `BoosterSimApp/Windows/SideWindowController.swift` — how windows track the Simulator frame from `SimulatorWindowTracker` publisher
- `BoosterSimApp/Services/SimulatorWindowTracker.swift` — `activeSimulator` (device + frame) source for overlay positioning and D-02 device auto-selection

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `AXHighlightPanel`: working transparent-overlay-over-Simulator pattern (borderless `NSPanel`, `.floating`, clear background) — but auto-dismissing and mouse-ignoring; needs a persistent, frame-tracking sibling
- `SimulatorWindowTracker` publishes `activeSimulator` with device type + frame — drives both overlay tracking and D-02 inset auto-selection
- `DesignComparisonService`/`DesignComparisonView`: persistence (presets via UserDefaults `DesignComparisonPresets`), image loading via `NSOpenPanel`, hex/rgb color formatting helpers worth keeping
- Phase 2 `SCScreenshotManager` (ScreenCaptureKit one-shot window capture): sanctioned async exception + real screen sampling path for the magnifier/color picker; Screen Recording permission already in onboarding
- `DesignTokens.swift`, `CollapsibleSection`, `AccentButton`, `StatusBadge` for panel UI

### Established Patterns
- Service-container: `@MainActor final class: ObservableObject` services, `@Published` state, wired in `AppDelegate`, injected via `.environmentObject()`
- Windows layer (`BoosterSimApp/Windows/`): `*Panel`/`*Controller` naming, `isReleasedWhenClosed = false`, controller owns lifecycle
- No async/await except the ScreenCaptureKit exception (CaptureService precedent)
- Presets persisted as `Codable` arrays in UserDefaults (`DesignPreset`)

### Integration Points
- `DesignTabView` (`Views/SideWindow/tabs/`) is the mount point; `SideTab.design` case already exists in the tab bar
- New overlay windows belong in `BoosterSimApp/Windows/` following the `AXHighlightPanel`/`SideWindowController` patterns; frame sync should subscribe to the same tracker publisher the side panel uses

</code_context>

<specifics>
## Specific Ideas

- Dual grid reads "like Figma/Sketch major-minor grids" (user, 2026-08-31) — emphasized 8pt lines over 4pt minor lines
- Safe-area margins styled "like Xcode's guides" — translucent fill + stroke, adaptive blue for grid lines

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 4-Design Tools*
*Context gathered: 2026-08-31*
