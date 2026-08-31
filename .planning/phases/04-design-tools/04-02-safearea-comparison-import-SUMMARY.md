---
phase: 04-design-tools
plan: 02
subsystem: ui
tags: [appkit, nspanel, overlay, swiftui, combine, userdefaults, swift-testing, safe-area, orientation, image-import, pasteboard, drag-drop]

requires:
  - phase: 04-design-tools
    provides: DesignOverlayService/Panel/Controller + OverlayGeometry (frozen signatures) + SafeAreaCatalog portrait rows + GridOverlayView anatomy + OverlayLayer install contract (D-04)
provides:
  - SafeAreaCatalog.insets(for:logicalSize:orientation:) with .portrait default + landscape(from:) verified-shape transform (source-compatible; 04-01 rows untouched)
  - OverlayGeometry.Orientation + orientation(contentRect:) aspect derivation
  - DesignOverlayService safe-area state — showSafeArea (persisted), resolvedInsets/resolvedDeviceName (controller-pushed), useManualInsets + manual inset fields + calibration offsets (persisted), resetInsetsToDevice(), effectiveInsets (manual wins until reset)
  - accept(image:) single import gate — 16384-px dimension cap (T-04-03), importError caption, single-slot replace
  - SafeAreaOverlayView — Xcode-guide translucent bands (fill 0.15 / stroke 0.6 systemBlue) at the .safeArea layer
  - ComparisonImageView — aspect-fit artboard, opacity/split, at the BOTTOM .comparison layer
  - Three import entry points funneling through accept — NSOpenPanel open, typed pasteboard paste, UTType.image drag-and-drop on the Design tab
affects: [04-03 ruler + magnifier, 04-04 phase gate (visual smoke of bands + import + D-04 ordering)]

actuals:
  tokens: 13504   # chars/4 over the realized diff (796 insertions + 174 deletions across 14 files; 54,016 diff chars)
  tasks: 3
  commits: 4

tech-stack:
  added: []   # Apple frameworks only — no new dependencies
  patterns:
    - "Orientation-aware catalog lookup: one data table + a single landscape transform; the portrait row itself (bottom == 0 → no home indicator) drives the classic-device all-zero case — no per-device branches"
    - "Single accept(image:) validation gate every import path funnels through (open/paste/drop); rejection is a caption, never a crash (T-04-03/T-04-04)"
    - "Task { @MainActor in } hop for NSItemProvider callbacks (CommandServer/RecordingService precedent) — views stay coroutine-free at the call site"

key-files:
  created:
    - BoosterSimApp/Views/Overlay/SafeAreaOverlayView.swift
    - BoosterSimApp/Views/Overlay/ComparisonImageView.swift
    - BoosterSimApp/Services/DesignOverlayService+Presets.swift
    - BoosterSimApp/Services/DesignOverlayService+Import.swift
    - BoosterSimApp/Views/SideWindow/DesignSafeAreaSection.swift
    - BoosterSimApp/Views/SideWindow/DesignPresetsSection.swift
  modified:
    - BoosterSimApp/Services/SafeAreaCatalog.swift
    - BoosterSimApp/Services/OverlayGeometry.swift
    - BoosterSimApp/Services/DesignOverlayService.swift
    - BoosterSimApp/Windows/DesignOverlayController.swift
    - BoosterSimApp/Views/SideWindow/DesignComparisonView.swift
    - BoosterSimApp/Views/SideWindow/tabs/DesignTabView.swift
    - BoosterSimAppTests/SafeAreaCatalogTests.swift
    - BoosterSimAppTests/OverlayPersistenceTests.swift

key-decisions:
  - "landscape(from:) encodes the verified shape as pure data derivation: bottom > 0 (home-indicator generations) → (0, 21, sides = portrait top); classic 20/0 rows → all-zero — the portrait row is the signal, honoring 'one data table, not special cases'"
  - "Landscape scale swaps the catalog's portrait logical size (w,h)→(h,w) in the controller before OverlayGeometry.scale — the 04-01 mapper signature stays untouched"
  - "Safe-area bands render fixed systemBlue (Xcode-guide look, D-03); grid keeps the tunable gridColor — the plan's 'systemBlue or gridColor-family tint' option resolved to the literal Xcode style"
  - "resolvedDeviceName added to the service (controller-pushed): the resolved-values caption needs the device name and the service is tracker-free by design"
  - "Zero-width/zero-height bands are skipped in draw(_:) — a 0-inset side must not stroke a phantom hairline at the content edge"

patterns-established:
  - "Import funnel: every artboard path (open/paste/drop) calls accept(image:) — future API clients slot beside it without touching the cap"
  - "Typed pasteboard reads: UTType(type).conforms(to: .image) gate before NSImage(pasteboard:) — spoofed payloads touch no state (T-04-04)"
  - "Controller-only calibration: offsets are service-persisted, controller-applied to contentRect before all geometry math (bezel escape hatch)"

requirements-completed:
  - REQ-roadmap-phase4-design-tools

coverage:
  - id: D1
    description: "Orientation-aware safe-area data tier: landscape transform (16-series 0/21/sides=portrait-top; SE-class all-zero), OverlayGeometry.orientation(contentRect:) aspect derivation with catalog round-trip, iPad fallback rows"
    requirement: REQ-roadmap-phase4-design-tools
    verification:
      - kind: unit
        ref: "BoosterSimAppTests/SafeAreaCatalogTests.swift (12 tests; 6 new landscape/orientation/iPad)"
        status: pass
    human_judgment: false
  - id: D2
    description: "Safe-area service state + import cap: showSafeArea toggle persistence, manual inset/calibration round-trips, reset restores auto-resolution, effectiveInsets manual-wins, accept/validateImported 16384-px cap with caption and single-slot replace"
    requirement: REQ-roadmap-phase4-design-tools
    verification:
      - kind: unit
        ref: "BoosterSimAppTests/OverlayPersistenceTests.swift (12 tests; 5 new safe-area/import)"
        status: pass
    human_judgment: false
  - id: D3
    description: "SafeAreaOverlayView four translucent bands at the .safeArea layer (grid above, image below per D-04) + side-panel Safe Area section (toggle, resolved caption, four manual fields, manual-enable toggle, Reset AccentButton, x/y calibration)"
    requirement: REQ-roadmap-phase4-design-tools
    verification:
      - kind: other
        ref: "xcodebuild Debug build exit 0 + source assertions (install(at: .safeArea) present, alphas 0.15/0.6, hairline ÷ backingScaleFactor, no accent-color reference, orientation resolution on every tracker emission)"
        status: pass
    human_judgment: true
    rationale: "Band placement over the live Simulator window, orientation switch on window rotation, and manual-override response are visual behaviors — deliberately deferred to the 04-04 phase-gate blocking smoke per the plan's verification section."
  - id: D4
    description: "Comparison import end-to-end: ComparisonImageView aspect-fit at the BOTTOM .comparison layer with opacity/split; Open…/Paste/Clear row with error caption and drop hint; Design tab drag-and-drop with highlight; zero network-transfer symbols"
    requirement: REQ-roadmap-phase4-design-tools
    verification:
      - kind: unit
        ref: "BoosterSimAppTests/OverlayPersistenceTests.swift accept/reject seam (non-regression, 12/12 green)"
        status: pass
      - kind: other
        ref: "xcodebuild Debug build exit 0 + locality grep (0 URLSession/NWConnection/CFNetwork/URLRequest symbols in design-overlay sources) + funnel assertion (open/paste/drop → accept(image:))"
        status: pass
    human_judgment: true
    rationale: "Drag-into-tab, pasteboard interaction, image rendering fidelity, and guides-over-image ordering under a visible artboard are manual-only rows in 04-VALIDATION — closed at the 04-04 phase-gate smoke."

duration: 19min
completed: 2026-08-31
status: complete
---

# Phase 4 Plan 02: Safe-Area Guide + Comparison Import Summary

**Orientation-aware safe-area bands (landscape transform + manual override + calibration) and the bottom-layer artboard comparison overlay with file/paste/drag import behind a 16384-px bomb-guard — 24 targeted tests + full 222-test bundle green**

## Performance

- **Duration:** 19 min (started 2026-08-31T13:34:56Z, completed 2026-08-31T13:54:06Z)
- **Tasks:** 3
- **Files modified:** 14 (6 created, 8 modified)

## Accomplishments

- Safe-area resolution is data-complete and unit-locked: `SafeAreaCatalog.insets(for:logicalSize:orientation:)` (source-compatible `.portrait` default), `landscape(from:)` encoding the verified shape, `OverlayGeometry.orientation(contentRect:)` — 04-01 portrait rows untouched and still green unmodified
- D-02's full mechanism shipped: auto-resolution from the tracked device name/size/orientation on every tracker emission, persisted manual per-side override, one-click Reset to Device Values, persisted bezel-calibration offsets the controller folds into the content rect
- Criterion 3 closed: an artboard imported by open/paste/drop renders aspect-fit at the BOTTOM .comparison layer; opacity is the see-through mechanism, split clips the trailing portion — guides can never render beneath it (D-04 install order: comparison < safeArea < grid)
- Threat mitigations landed as built: T-04-03 dimension cap rejects over-16384px edges with an honest caption before caching (unit-locked accept/reject + replace), T-04-04 typed pasteboard reads ignore non-image payloads, T-04-05 zero network-transfer symbols in every design-overlay source

## Task Commits

1. **Task 1 (TDD RED): failing tests** — `5ea675e` (test — build fails on missing landscape/orientation/service APIs, verified before commit)
2. **Task 1 (TDD GREEN): catalog + geometry + service state** — `1c0d77b` (feat — 24/24 green)
3. **Task 2: SafeAreaOverlayView + panel controls** — `98e7ea7` (feat — BUILD SUCCEEDED + 16 targeted tests)
4. **Task 3: comparison import end-to-end** — `f5af4cd` (feat — BUILD SUCCEEDED + 24 targeted tests + locality/coverage source checks)

## Files Created/Modified

- `BoosterSimApp/Services/SafeAreaCatalog.swift` — orientation parameter + `landscape(from:)` transform + private `portraitInsets` split (single lookup implementation)
- `BoosterSimApp/Services/OverlayGeometry.swift` — `Orientation` enum + `orientation(contentRect:)`; all six 04-01 signatures untouched
- `BoosterSimApp/Services/DesignOverlayService.swift` — safe-area published state, `effectiveInsets`, `resetInsetsToDevice()`, versioned keys, CGFloat defaults reads; presets/import moved to extensions
- `BoosterSimApp/Services/DesignOverlayService+Presets.swift` — preset CRUD + persistence + one-shot legacy import (moved verbatim)
- `BoosterSimApp/Services/DesignOverlayService+Import.swift` — open/paste entry points, single `accept(image:)` gate, `validateImported` 16384-px cap, `maxImportedEdge`
- `BoosterSimApp/Views/Overlay/SafeAreaOverlayView.swift` — four band rects, systemBlue 0.15 fill / 0.6 stroke, hairline ÷ backingScaleFactor, zero-size bands skipped
- `BoosterSimApp/Views/Overlay/ComparisonImageView.swift` — aspect-fit draw, overlay alpha / split clip, geometry injected
- `BoosterSimApp/Windows/DesignOverlayController.swift` — installs comparison (first/bottom) → safeArea → grid; orientation-aware inset resolution into `resolvedInsets`/`resolvedDeviceName`; calibration offset application; visibility refresh covers all three views
- `BoosterSimApp/Views/SideWindow/DesignComparisonView.swift` — Import row (Open…/Paste/Clear + error caption + drop hint), Safe Area CollapsibleSection (`rectangle.dashed`)
- `BoosterSimApp/Views/SideWindow/DesignSafeAreaSection.swift` — toggle, resolved caption, four manual fields, Use Manual Insets, Reset AccentButton, x/y calibration (NumberFormatter-filtered fields)
- `BoosterSimApp/Views/SideWindow/DesignPresetsSection.swift` — presets section extracted verbatim
- `BoosterSimApp/Views/SideWindow/tabs/DesignTabView.swift` — `.onDrop(of: [UTType.image])` with typed guard, `Task { @MainActor in }` hop, accent drop highlight via tokens
- `BoosterSimAppTests/SafeAreaCatalogTests.swift` — +6 landscape/orientation/iPad tests (12 total)
- `BoosterSimAppTests/OverlayPersistenceTests.swift` — +5 safe-area state / import accept-reject tests (12 total)

## Decisions Made

- Landscape transform is pure data derivation: `bottom > 0` (home-indicator generations) → `(0, 21, sides = portrait top)`; classic 20/0 rows → all-zero — the portrait row itself is the signal, so the "one data table, not special cases" constraint holds
- Controller swaps the catalog's portrait logical size for landscape scale computation instead of adding a second scale function — 04-01 mapper signatures stay frozen
- Safe-area bands render fixed `systemBlue` (the literal Xcode-guide look); grid keeps the tunable `gridColor` — the plan offered either ("systemBlue or gridColor-family adaptive tint")
- `resolvedDeviceName` rides the service (controller-pushed, service stays tracker-free) because the resolved-values caption needs the device name
- `TextField(value:formatter:)` with a shared `NumberFormatter` for the numeric fields — guaranteed CGFloat binding (no reliance on `format: .number` CGFloat overload availability)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 — Code-standards precedence] Split DesignOverlayService and DesignComparisonView to hold the <200 LOC standard**
- **Found during:** Task 1 (service) and Task 2 (view)
- **Issue:** Plan additions push DesignOverlayService to ~260 LOC and DesignComparisonView (already 229 from 04-01) past 290 — `docs/code-standards.md` / AGENTS.md mandate files < 200 LOC; CLAUDE.md precedence over plan file lists
- **Fix:** Presets machinery moved verbatim to `DesignOverlayService+Presets.swift`, import paths to `DesignOverlayService+Import.swift` (same type, same symbols); the presets UI extracted to `DesignPresetsSection.swift` and safe-area controls live in `DesignSafeAreaSection.swift` (final: service 140, view 186 LOC)
- **Files modified:** the four new files above + the two originals
- **Verification:** `wc -l` all files < 200; full 222-test bundle green
- **Committed in:** 1c0d77b, 98e7ea7

**2. [Plan-structure] Task 3's tdd flag degenerated to a single feat commit**
- **Found during:** Task 3
- **Issue:** Task 3 is `tdd="true"` but its `<behavior>` explicitly mandates "No new unit surface otherwise — view rendering and paste/drag are manual-only (04-VALIDATION Manual-Only rows)" — there is no new failing test to write
- **Fix:** Ran the Task-1-locked accept/reject suite before and after implementation (green both sides) as the regression net; shipped one `feat` commit per the plan's own behavior spec
- **Files modified:** none beyond plan scope
- **Verification:** OverlayPersistenceTests 12/12 pre- and post-change
- **Committed in:** f5af4cd

---

**Total deviations:** 2 auto-fixed (1 code-standards split, 1 TDD-shape adaptation)
**Impact on plan:** No scope change — the splits keep every plan-named symbol on `DesignOverlayService` and every behavior identical; Task 3 follows the plan's own no-new-tests mandate.

## Issues Encountered

- RED phase surfaced a self-inflicted test bug (the first edit dropped the existing `makeSize` builder from SafeAreaCatalogTests) — caught by the RED compile run, fixed before the RED commit; the committed RED failure lists exactly the missing production APIs (`landscape`, `orientation`, `extra argument 'orientation'`)
- Task 1 GREEN needed one compile fix: `= .manualDefaults` implicit-member lookup against `SafeAreaCatalog.Insets` → qualified `SafeAreaCatalog.manualDefaults`
- Edit-tool anchor slips (duplicated brace/header fragments) were all caught by the syntax probe or immediate re-read and repaired before any build/commit — no commit contains a broken tree

## Known Stubs

None — no new stubs, placeholders, or unwired controls in this plan. (The pre-existing `pickedColor` producer gap remains 04-01's documented, plan-scheduled stub until 04-03's PixelSamplerService.)

## Flagged Edges Still Open (close at 04-04 phase-gate smoke)

- Legacy inset rows (44/48/20 families, iPad 20/20) and their landscape shapes stay [ASSUMED] — manual override hides placement errors (plan flagged_assumptions A1)
- File/drag/paste of exported PNG/PDF/JPEG as the reading of "import a Figma/Sketch artboard" (A6) — closes via the 04-04 import step
- Re-import replace and mid-drag no-op are unit-locked; the live double-run check rides the 04-04 smoke (idempotency probe)
- Visual proof of band placement, orientation switch on window rotation, import rendering, and D-04 ordering under a visible artboard — all plan-designed deferrals to the 04-04 blocking smoke

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- 04-03 (ruler + magnifier) rides the proven install contract: `panel.install(view, at: .interactive)` slots between the comparison image and the safe-area bands; setCaptureMode seam already inert-waiting; controller/geometry/service patterns unchanged
- Wave 2 leaves 222/222 unit tests green, zero network symbols, zero new dependencies
- No blockers.

---
*Phase: 04-design-tools*
*Completed: 2026-08-31*

## Self-Check: PASSED

All 6 created files exist on disk; commits 5ea675e / 1c0d77b / 98e7ea7 / f5af4cd present in git log; all touched files < 200 LOC; Task 1 (24 tests), Task 2 (build + 16 tests), Task 3 (build + 24 tests + locality/coverage greps), and the full 222-test unit bundle all exit 0.
