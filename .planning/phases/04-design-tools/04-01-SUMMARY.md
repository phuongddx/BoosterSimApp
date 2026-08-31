---
phase: 04-design-tools
plan: 01
subsystem: ui
tags: [appkit, nspanel, overlay, swiftui, combine, userdefaults, swift-testing, safe-area, geometry]

requires:
  - phase: 01-window-tracking
    provides: SimulatorWindowTracker.activeSimulator (device + frame authority), SideWindowPanel/AXHighlightPanel configs
  - phase: 02-capture-tools
    provides: ScreenshotService scale math precedent (backingScale), Swift Testing house style
provides:
  - DesignOverlayService — design overlay tool state with versioned persistence and one-shot legacy import
  - DesignOverlayPanel + OverlayLayer install contract — the single persistent click-through panel all overlay tools ride (D-04 z-order)
  - DesignOverlayController — tracker frame sync + service visibility sink + geometry push
  - OverlayGeometry — the pure coordinate mapper (content rect, scale, dual 8/4 spacings, device-point round trip, image-pixel Y-flip, distance)
  - SafeAreaCatalog — name-first/size-second inset + logical-size constants table (D-02 refined)
  - GridOverlayView — dual 8pt/4pt draw-based grid renderer
  - AppLogger.design category
  - Wave 0 suites: SafeAreaCatalogTests, GridGeometryTests, RulerMathTests, OverlayPersistenceTests (22 tests)
affects: [04-02 safe-area + comparison import, 04-03 ruler + magnifier, 04-04 phase gate]

actuals:
  tokens: 14320   # chars/4 over the realized diff (911 insertions + 173 deletions across 17 files)
  tasks: 2
  commits: 3

tech-stack:
  added: []   # Apple frameworks only — no new dependencies (threat T-04-SC accept)
  patterns:
    - "Single persistent overlay NSPanel with role-keyed subview install (install(_:at: OverlayLayer)) — z-order by subview order, never window order (D-04)"
    - "Pure mapper enum (OverlayGeometry) centralizing Y-flip/scale math; scale always a parameter, never a hardcoded backing literal"
    - "Versioned UserDefaults schema + flag-guarded one-shot tolerant legacy import (Pitfall 5 pattern)"
    - "objectWillChange → receive(on: DispatchQueue.main) → read post-mutation state (no async keyword needed)"

key-files:
  created:
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
  modified:
    - BoosterSimApp/Views/SideWindow/DesignComparisonView.swift
    - BoosterSimApp/Views/SideWindow/tabs/DesignTabView.swift
    - BoosterSimApp/App/AppDelegate.swift
    - BoosterSimApp/Windows/SideWindowController.swift
    - BoosterSimApp/Views/SideWindow/SideWindowView.swift
    - BoosterSimApp/Utilities/AppLogger.swift
  deleted:
    - BoosterSimApp/Services/DesignComparisonService.swift

key-decisions:
  - "OverlayLayer install uses addSubview(positioned:.below, relativeTo:) with a clamped layer index — AppKit has no insertSubview(_:at:); ordering stays deterministic regardless of install call order"
  - "objectWillChange sink rides receive(on: DispatchQueue.main) so visibility reads post-mutation state — keeps the controller free of async/await tokens (Combine-only criterion)"
  - "Panel visibility = (any tool on AND Simulator tracked): tracker sink carries the SideWindowController attach shape (setFrame+orderFront / orderOut), refreshVisibility centralizes the tool-on ordering decision"
  - "Task 1 service shipped the full persistence contract (write-through toggles + flag-guarded tolerant import) so the tracer's done criteria hold; Task 2's suite arrived green-on-arrival and locks the contract"

patterns-established:
  - "Overlay install contract (D-04): later plans call panel.install(view, at: .comparison/.interactive/.safeArea/.grid) — never addSubview directly"
  - "Geometry injection: controller resolves frame→contentRect + deviceName→logicalSize→scale and pushes via view.update(...) — views never query windows or catalogs themselves"
  - "Legacy tolerance decode: private ImportedEntry with all-optional fields (production never re-declares the deleted spacing field); legacy shape exists only as a test fixture"

requirements-completed:
  - REQ-roadmap-phase4-design-tools

coverage:
  - id: D1
    description: "Pure geometry/data engines: SafeAreaCatalog (name-first/size-second/manualDefaults incl. 375x812 disambiguation) and OverlayGeometry (content rect, scale, dual 8/4 spacings, device-point round trip, image-pixel Y-flip, distance)"
    requirement: REQ-roadmap-phase4-design-tools
    verification:
      - kind: unit
        ref: "BoosterSimAppTests/SafeAreaCatalogTests.swift (6 tests)"
        status: pass
      - kind: unit
        ref: "BoosterSimAppTests/GridGeometryTests.swift (4 tests)"
        status: pass
      - kind: unit
        ref: "BoosterSimAppTests/RulerMathTests.swift (5 tests)"
        status: pass
    human_judgment: false
  - id: D2
    description: "DesignOverlayService cut-over: versioned preset schema (DesignOverlayPresets), per-tool toggle persistence (DesignOverlayShowGrid/ShowRuler), flag-guarded one-shot tolerant legacy import (idempotent, corruption-safe); fake pickColor and single-spacing model deleted"
    requirement: REQ-roadmap-phase4-design-tools
    verification:
      - kind: unit
        ref: "BoosterSimAppTests/OverlayPersistenceTests.swift (7 tests)"
        status: pass
    human_judgment: false
  - id: D3
    description: "Overlay rendering layer: persistent click-through DesignOverlayPanel (8 config properties, D-04 install contract, setCaptureMode seam), tracker-synced DesignOverlayController, dual-grid GridOverlayView, AppDelegate/SideWindowController wiring — grid draws over the live Simulator window, follows move/resize, survives focus loss"
    requirement: REQ-roadmap-phase4-design-tools
    verification:
      - kind: other
        ref: "xcodebuild Debug build exit 0 (BUILD SUCCEEDED) + source assertions (8 panel props, no key-window call, Combine-only controller)"
        status: pass
    human_judgment: true
    rationale: "NSPanel compositing over a foreign app's window, focus-loss persistence, and move/resize tracking are not meaningfully unit-testable — deliberately deferred to the 04-04 phase-gate blocking smoke per the plan's verification section and 04-RESEARCH Validation Architecture."

duration: 13min
completed: 2026-08-31
status: complete
---

# Phase 4 Plan 01: Overlay Grid Tracer Summary

**Dual 8pt/4pt grid over the live Simulator window via one persistent click-through NSPanel — cut-over service, D-04 layered install contract, tracker-synced controller, and 22 Wave-0 unit tests green**

## Performance

- **Duration:** 13 min (started 2026-08-31T13:16:22Z, completed 2026-08-31T13:30:06Z)
- **Tasks:** 2
- **Files modified:** 16 (10 created, 6 modified, 1 deleted — 17 entries in the diff)

## Accomplishments

- One green vertical path: Design tab Grid toggle → DesignOverlayService (showGrid persisted under DesignOverlayShowGrid) → DesignOverlayController service sink → panel orderFront/orderOut + GridOverlayView hidden/visible → dual 8pt/4pt grid drawn in device points over the Simulator content rect
- Scaffold cut-over complete: DesignComparisonService.swift deleted (fake 1×1-bitmap pickColor core and single-spacing grid model gone), zero orphan tokens repo-wide; persistence shape, color helpers, and preset CRUD carried into the versioned schema
- D-04 z-order pinned from day one: `install(_:at: OverlayLayer)` maps layer roles (comparison < interactive < safeArea < grid) to deterministic subview order via `addSubview(positioned:.below, relativeTo:)` — later plans cannot violate z-order by toggle or orderFront sequence
- Persistence hardened and unit-locked: toggles round-trip, presets version cleanly, the legacy DesignComparisonPresets payload imports once (flag-guarded, tolerant per-field, idempotent), corrupted data degrades to empty without trapping

## Task Commits

1. **Task 1 (tracer, TDD): Wave 0 suites** — `cc45170` (test — RED: build failed on missing SafeAreaCatalog/OverlayGeometry types, verified before commit)
2. **Task 1 (tracer, TDD): end-to-end slice** — `bd34298` (feat — 15 tests green, Debug build green)
3. **Task 2 (TDD): persistence contract suite** — `c60003b` (test — 7 tests green)

**Tracer feedback gate:** re-ran the tracer `<verify>` end-to-end after commit bd34298 — 15/15 tests, ** TEST SUCCEEDED **, BUILD SUCCEEDED. Mode: interactive + end-of-phase + `<automated>`-only → auto-continued to expansion (no checkpoint), per checkpoints.md row 3.

## Files Created/Modified

- `BoosterSimApp/Services/SafeAreaCatalog.swift` — name-keyed/logical-size-fallback inset + logical-size table (verified 13/15/16 rows; ASSUMED legacy/iPad rows flagged in header)
- `BoosterSimApp/Services/OverlayGeometry.swift` — the pure coordinate mapper (7 functions; scale always a parameter)
- `BoosterSimApp/Services/DesignOverlayService.swift` — @MainActor tool state, versioned keys, one-shot tolerant legacy import
- `BoosterSimApp/Windows/DesignOverlayPanel.swift` — persistent transparent click-through NSPanel + OverlayLayer contract + setCaptureMode seam
- `BoosterSimApp/Windows/DesignOverlayController.swift` — tracker frame sink + service visibility sink, geometry push (Combine only)
- `BoosterSimApp/Views/Overlay/GridOverlayView.swift` — draw(_:)-based dual grid (minors half-alpha hairline, majors full alpha, widths ÷ backingScaleFactor)
- `BoosterSimApp/Views/SideWindow/DesignComparisonView.swift` — rewired to DesignOverlayService; spacing slider + dead Pick Color button deleted; grid color/opacity controls (D-03) added
- `BoosterSimApp/Views/SideWindow/tabs/DesignTabView.swift` — environmentObject rename
- `BoosterSimApp/App/AppDelegate.swift` — designOverlayService/Panel/Controller lazy wiring + attach in applicationDidFinishLaunching
- `BoosterSimApp/Windows/SideWindowController.swift` — init param + environmentObject chain renamed (one-line swap, no behavior change)
- `BoosterSimApp/Views/SideWindow/SideWindowView.swift` — #Preview wiring renamed (unlisted d=1 caller found in blast-radius analysis)
- `BoosterSimApp/Utilities/AppLogger.swift` — `design` category added
- `BoosterSimAppTests/{SafeAreaCatalog,GridGeometry,RulerMath,OverlayPersistence}Tests.swift` — 22 Swift Testing tests, zero XCTest imports

## Decisions Made

- AppKit-idiomatic ordered install: `insertSubview(_:at:)` is UIKit-only; install() uses `addSubview(_:positioned:.below, relativeTo:)` with a clamped index so install call order never matters
- `objectWillChange` deferral via `receive(on: DispatchQueue.main)` instead of DispatchQueue.async — satisfies the Combine-only/no-coroutine-keyword acceptance criterion while still reading post-mutation state
- Panel ordering centralized in `refreshVisibility` (any tool on ∧ Simulator tracked → orderFront, else orderOut) so sink 1 keeps the mandated SideWindowController attach shape without fighting sink 2
- Task 1 shipped write-through toggles (didSet) + the full import contract because the tracer's own done criteria ("persists across app relaunch") demand them; Task 2's suite is therefore green-on-arrival — it locks the contract rather than driving it

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Migrated the unlisted SideWindowView #Preview caller**
- **Found during:** Task 1 (blast-radius analysis before the cut-over)
- **Issue:** AGENTS.md-mandated impact analysis (GitNexus MCP unavailable in this harness — jarvis unindexed; grep fallback used) surfaced a d=1 caller the plan's file list omits: `SideWindowView.swift` #Preview constructs `DesignComparisonService()` and passes it through `SideWindowController` init + `.environmentObject`
- **Fix:** Renamed preview wiring to `designOverlayService` (3 lines) — required for the "zero DesignComparisonService tokens" acceptance criterion and to compile
- **Files modified:** BoosterSimApp/Views/SideWindow/SideWindowView.swift
- **Verification:** Debug build exit 0; token grep = 0 occurrences
- **Committed in:** bd34298

---

**Total deviations:** 1 auto-fixed (1 blocking)
**Impact on plan:** None — clean-cutover requirement ("migrate every caller") applied to a caller the file list missed. No scope creep.

## Issues Encountered

- Task 2's suite passed on first run (no RED phase observed). Investigated per TDD discipline: expected by plan structure — Task 1's action spec explicitly carries the versioned keys, write-through toggles, and the flag-guarded tolerant import ("Task 2 unit-locks this import"). The suite locks the contract (7 tests) and required no hardening changes.
- Two mid-implementation compile errors fixed before any commit (extension init visibility → mapping moved into a private method; `NSColor(SwiftUI.Color)` → `import SwiftUI` in the controller). Both resolved within the task; no extra commits needed.

## Known Stubs

- `pickedColor` (DesignOverlayService.swift:26) has no producer until plan 04-03 ships PixelSamplerService — the plan deleted the fake `pickColor(at:)` core and its placeholder button by design ("its real arm/disarm UI arrives in 04-03"). The Color Picker section renders its readout only; intentional, plan-scheduled.

## Flagged Edges Still Open (close at 04-04 phase-gate smoke)

- Idempotency edge is unit-locked but the double-run guard stays flagged until the 04-04 smoke confirms on a real upgraded defaults store
- Concurrency guarantees are @MainActor-serialized by construction; mid-render/mid-import interruption stays flagged until the 04-04 smoke exercises move/resize/relaunch during active overlays
- Content-rect = frame − 28pt title bar assumes bezels OFF (A4); bezel-on alignment waits for 04-02's manual calibration fields

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- Plans 02 (safe-area + comparison import) and 03 (ruler + magnifier) ride the proven slice: `panel.install(view, at:)` for z-order, `DesignOverlayService` for state, `OverlayGeometry` for all coordinate math, `DesignOverlayController` for tracker/service plumbing
- No blockers. Visual end-to-end proof (grid over live Simulator, focus persistence, tracking) is deliberately deferred to the 04-04 phase-gate blocking smoke.

---
*Phase: 04-design-tools*
*Completed: 2026-08-31*

## Self-Check: PASSED

All 10 created files exist on disk; commits cc45170 / bd34298 / c60003b present in git log; DesignComparisonService.swift deletion confirmed; both task verify commands exit 0 (15 tests in 3 suites + 7 tests in 1 suite, BUILD SUCCEEDED).
