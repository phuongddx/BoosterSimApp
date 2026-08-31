---
phase: 04-design-tools
plan: 03
subsystem: ui
tags: [appkit, nspanel, overlay, combine, screencapturekit, pixel-sampling, ruler, magnifier, color-picker, swift-testing, design-tokens]

requires:
  - phase: 04-design-tools
    provides: DesignOverlayPanel install contract + setCaptureMode seam, DesignOverlayController tracker/service sinks, OverlayGeometry frozen mapper (imagePixel/devicePoint/distance), DesignOverlayService state + color helpers, RulerMathTests mapper lock
  - phase: 02-capture-tools
    provides: ScreenshotService.capture(windowID:windowFrame:) + backingScale/pixelSize (reused, never re-derived), CaptureService Task-bridge/TCC-preflight shape (the sanctioned async exemption)
provides:
  - PixelSamplerService — the second sanctioned async site: one cached capture per arming, generation-guarded late-result discard, OverlayGeometry-only pixel mapping, honest permission/tracker degradation, resize-only re-capture (A5)
  - RulerOverlayView — capture-mode drag-measure with live device-point readout (OverlayGeometry.devicePoint + distance), endpoint markers, Esc cancel
  - MagnifierView — hover-follow loupe (OverlayMetrics tokens), magnified cached-image crop via the sampleRegion seam, crosshair, live hex pill, click-to-commit pick
  - DesignOverlayController+InputMode — OverlayInputMode machine (clickThrough/ruler/magnifier) with Esc + global/local mouse-moved monitor lifecycle balanced on every disarm path and deinit (T-04-08)
  - Sampler injection seam — AppDelegate lazy pixelSamplerService → attach(to:service:pixelSampler:) (W2 resolved: controller stores, never constructs)
  - OverlayMetrics design tokens (markerRadius/readoutInset/loupeDiameter/magnification default+range)
  - pickedColor producer shipped — the 04-01 broken-window stub is closed (WINDOWS.md #4 fixed)
affects: [04-04 phase gate (visual smoke of ruler/loupe/focus/Esc, D-04 five-layer ordering), docs CONVENTIONS exemption wording (capture-path pattern now names CaptureService + PixelSamplerService)]

actuals:
  tokens: 14059   # chars/4 over the realized diff (995 insertions + 61 deletions across 13 files; 56,236 diff chars)
  tasks: 3
  commits: 4

tech-stack:
  added: []   # Apple frameworks only — no new dependencies
  patterns:
    - "Cached-capture sampling: one Task-bridge capture per arming, every cursor read hits the memory-only CGImage locally (µs reads, never a TCC-gated per-move capture)"
    - "Arming-generation token: disarm bumps the generation so late capture results discard by construction (unit-locked via handleCaptureResult seam)"
    - "Capture-mode event routing at the panel container: hitTest consults the interactive band only — render layers stay visually above (D-04) without swallowing input"
    - "Monitor lifetime == armed lifetime: Esc local keyDown + global/local mouse-moved installed on arm, removed in one exit funnel + deinit"
    - "Controller-pushed loupe state (direct view update, no per-move @Published churn → no per-move redraw of render tools)"

key-files:
  created:
    - BoosterSimApp/Services/PixelSamplerService.swift
    - BoosterSimApp/Views/Overlay/RulerOverlayView.swift
    - BoosterSimApp/Views/Overlay/MagnifierView.swift
    - BoosterSimApp/Windows/DesignOverlayController+InputMode.swift
    - BoosterSimApp/Views/SideWindow/DesignToolsSection.swift
    - BoosterSimAppTests/PixelSamplerTests.swift
  modified:
    - BoosterSimApp/Windows/DesignOverlayController.swift
    - BoosterSimApp/Windows/DesignOverlayPanel.swift
    - BoosterSimApp/Services/DesignOverlayService.swift
    - BoosterSimApp/Views/SideWindow/DesignComparisonView.swift
    - BoosterSimApp/App/AppDelegate.swift
    - BoosterSimApp/Utilities/DesignTokens.swift
    - BoosterSimAppTests/OverlayPersistenceTests.swift

key-decisions:
  - "Capture-mode hit-test routing lives in the panel's container view (OverlayContainerView): render-only layers above the interactive slot would otherwise swallow every ruler/picker mouse event while the grid is visible — D-04 z-order untouched"
  - "refreshIfFrameChanged semantics: a resize/orientation change re-captures; pure window translation does not (content pixels are translation-invariant) — honors A5 freshness without per-move captures during Simulator drags"
  - "Loupe state is pushed directly to MagnifierView per move; service.liveHex publishes only at pick — a per-move @Published would fire objectWillChange → refreshVisibility → redraw of every render tool on every cursor step"
  - "Arm/disarm pair rendered as one state-flipping AccentButton (Measure/Stop, Pick/Stop): the pair exists across the two states; amber stays in the panel, overlay chrome uses system blue (D-03)"
  - "Sampler arm refusal auto-reverts: preflight/tracker guard failures mirror the caption into the service and return the panel to click-through without installing monitors"
  - "This host rasterizes CG fills into Display P3 — PixelSamplerTests read expected colors back from an identically-built rep instead of hardcoding sRGB primaries (proves WHICH pixel is selected, not colorimetry); sampleColor returns display-space components, matching Digital Color Meter"

patterns-established:
  - "Interactive overlay tools: arm via service helper → armed-flag sink → capture mode + monitors; disarm funnels through one exitToClickThrough — future tools copy the funnel, not their own teardown"
  - "Test seams over mocks: injectCache/handleCaptureResult/preflightPermission keep the sampler suite SCK-free and headless while testing the real mapping/generation logic"

requirements-completed:
  - REQ-roadmap-phase4-design-tools

coverage:
  - id: D1
    description: "PixelSamplerService engine: cached-capture sampling with Y-flip/scale mapping (frameHeight 200/scale 2 and 1x), out-of-bounds nil, late-result discard after disarm, denied-permission caption with no capture issued"
    requirement: REQ-roadmap-phase4-design-tools
    verification:
      - kind: unit
        ref: "BoosterSimAppTests/PixelSamplerTests.swift (6 tests)"
        status: pass
    human_judgment: false
  - id: D2
    description: "Ruler end-to-end: capture-mode panel input, drag-measure with live device-point readout via OverlayGeometry.devicePoint + distance, endpoint markers, Esc cancel, click-through restored on commit/cancel, single-tool arming"
    requirement: REQ-roadmap-phase4-design-tools
    verification:
      - kind: unit
        ref: "BoosterSimAppTests/RulerMathTests.swift (5 tests, mapper lock) + OverlayPersistenceTests single-tool test"
        status: pass
      - kind: other
        ref: "xcodebuild Debug build exit 0 + source assertions (device-point conversion only, zero coroutine keywords in controller/views, Esc monitor removed in deinit, .interactive install)"
        status: pass
    human_judgment: true
    rationale: "Drag interaction over a live Simulator window, focus retention, and Esc-while-Simulator-focused are not unit-testable — deferred to the 04-04 phase-gate blocking smoke per the plan's verification section."
  - id: D3
    description: "Magnifier + Color Picker: hover-follow loupe (OverlayMetrics tokens, cached-image crop via sampleRegion, edge-flipping offset, live hex pill), click-to-commit pickedColor + auto-disarm, side-panel arm/disarm + magnification stepper + honest degradation captions"
    requirement: REQ-roadmap-phase4-design-tools
    verification:
      - kind: unit
        ref: "BoosterSimAppTests/OverlayPersistenceTests.swift magnificationPersistsAndSingleToolArmingHolds"
        status: pass
      - kind: other
        ref: "xcodebuild Debug build exit 0 + source assertions (zero raw loupe literals, monitor add/remove balanced incl. deinit, zero CGEvent symbols, single pick path)"
        status: pass
    human_judgment: true
    rationale: "Loupe accuracy against known colors and hover-follow feel over the live Simulator are manual-only rows in 04-VALIDATION — close at the 04-04 phase-gate smoke."

duration: 30min
completed: 2026-08-31
status: complete
---

# Phase 4 Plan 03: Ruler + Magnifier Summary

**Interactive pixel inspection over the live Simulator: drag-measure ruler with device-point readout and a hover-follow magnifier loupe with click-to-commit color picking — both riding one cached ScreenCaptureKit capture per arming through the second sanctioned Task bridge, 229/229 unit tests green**

## Performance

- **Duration:** 30 min (started 2026-08-31T14:02:06Z, completed 2026-08-31T14:32:20Z)
- **Tasks:** 3
- **Files modified:** 13 (6 created, 7 modified)

## Accomplishments

- Success criterion 2's engine and surfaces shipped: `PixelSamplerService` (one cached capture per arming, generation-guarded late-result discard, OverlayGeometry-only mapping, honest permission/tracker degradation) + `RulerOverlayView` + `MagnifierView` + the panel's Color Picker section — the 04-01 `pickedColor` stub now has its real producer (WINDOWS.md #4 closed)
- The W2 injection seam landed as planned: AppDelegate owns `lazy var pixelSamplerService` (stateless ScreenshotService + tracker, the captureService precedent); `attach(to:service:pixelSampler:)` delivers it to the controller, which stores it and never constructs one
- Monitor discipline holds everywhere: Esc (keyCode 53) + observe-only global `mouseMoved` + panel-local `mouseMoved` are installed only while a tool is armed, funnel through one `exitToClickThrough`, and are removed on every disarm path and in deinit — zero CGEvent taps, memory-only cache, zero file-write symbols (T-04-06/07/08)
- The concurrency convention survived its second exception: the only `Task`/`await`/`async` occurrences in the phase live inside PixelSamplerService's single private bridge (CaptureService shape); controller and views are Combine + AppKit events only (source-grepped)

## Task Commits

1. **Task 1 (TDD RED): failing PixelSamplerTests** — `2ebfbb0` (test — RED verified: "cannot find type 'PixelSamplerService' in scope", TEST FAILED)
2. **Task 1 (TDD GREEN): PixelSamplerService** — `d233016` (feat — 11/11 PixelSampler+RulerMath green)
3. **Task 2: ruler + input-mode machine + injection seam** — `f0e7000` (feat — BUILD SUCCEEDED + 11/11 targeted)
4. **Task 3: magnifier loupe + color pick + panel sections** — `c30819d` (feat — BUILD SUCCEEDED + 24/24 targeted + 229/229 full bundle)

**Plan metadata:** `{final docs hash}` (docs: complete plan)

## Files Created/Modified

- `BoosterSimApp/Services/PixelSamplerService.swift` — cached-capture sampler: arm/disarm lifecycle, generation guard, sampleColor/sampleRegion/imagePixel (all via OverlayGeometry), backingScale from ScreenshotService, AppLogger verbs-only
- `BoosterSimApp/Views/Overlay/RulerOverlayView.swift` — acceptsFirstMouse + mouseDown/dragged/up; line, markers, live readout pill in device points; readout flips side inside panel bounds
- `BoosterSimApp/Views/Overlay/MagnifierView.swift` — circular loupe, crosshair, hex pill, above-leading/below-trailing edge flip; state controller-pushed, pick click forwarded
- `BoosterSimApp/Windows/DesignOverlayController.swift` — sampler storage + armed-flag sinks + error mirror + interactive installs + armed flags in anyToolOn + magnifier resize re-capture
- `BoosterSimApp/Windows/DesignOverlayController+InputMode.swift` — OverlayInputMode machine, ruler/magnifier mode reactions, commit/pick paths, monitor lifecycle
- `BoosterSimApp/Windows/DesignOverlayPanel.swift` — OverlayContainerView hit-test routing to the interactive band (capture-mode input)
- `BoosterSimApp/Services/DesignOverlayService.swift` — isRulerArmed/isMagnifierArmed, rulerDistance, samplerError, liveHex, magnification (persisted), arm/disarm helpers with the single-tool rule
- `BoosterSimApp/Views/SideWindow/DesignToolsSection.swift` — Ruler + Color Picker sections (arm/disarm CTAs, distance row, stepper, error caption, swatch + hex/RGB + copy)
- `BoosterSimApp/Views/SideWindow/DesignComparisonView.swift` — old ruler toggle + picker block replaced by DesignToolsSection
- `BoosterSimApp/App/AppDelegate.swift` — lazy pixelSamplerService + extended attach call
- `BoosterSimApp/Utilities/DesignTokens.swift` — OverlayMetrics enum
- `BoosterSimAppTests/PixelSamplerTests.swift` — 6 Swift Testing tests (synthetic CGImage fixtures, rep-derived expectations)
- `BoosterSimAppTests/OverlayPersistenceTests.swift` — +1 magnification-persistence/single-tool test (13 total)

## Decisions Made

- Capture-mode input routing sits in the panel container's `hitTest` (interactive band only): the visible grid/safe-area views are ABOVE the interactive slot per D-04 and would otherwise swallow every ruler/picker mouse event — one seam, z-order untouched
- A5 freshness reads "frame change" as resize/orientation only: translation leaves window-relative content pixels identical, so `refreshIfFrameChanged` re-captures on resize but never during Simulator drags (no per-move captures)
- Per-move loupe updates push straight to the view; `service.liveHex` publishes only at pick — avoids objectWillChange → refreshVisibility → per-move redraw of every render tool
- Sampler arm refusal (preflight/tracker guard) auto-reverts to click-through with the caption mirrored into the Design tab — degradation is visible and harmless
- OverlayMetrics tokens landed in Task 2 (ruler chrome needs them too); Task 3's loupe constants joined the same enum — no raw loupe literals anywhere in MagnifierView

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Panel capture-mode hit-test routing**
- **Found during:** Task 2
- **Issue:** The plan's mouse-driven RulerOverlayView never receives events when any render tool above the .interactive slot is visible — AppKit hit-testing picks the topmost subview (grid/safe-area/comparison), which sits above the ruler by D-04 design
- **Fix:** `OverlayContainerView.hitTest` (inside DesignOverlayPanel.swift) routes events to the first visible interactive-band view; render layers keep their z-order and stay non-interactive by construction
- **Files modified:** BoosterSimApp/Windows/DesignOverlayPanel.swift
- **Verification:** BUILD SUCCEEDED; D-04 install order unchanged (install calls grep-verified)
- **Committed in:** f0e7000

**2. [Rule 2 - Code standards] Controller + view section splits (<200 LOC)**
- **Found during:** Task 2/3
- **Issue:** The input-mode machine pushes DesignOverlayController past 200 LOC; the ruler/picker sections push DesignComparisonView past it — docs/code-standards mandate <200 (04-02 precedent: CLAUDE.md precedence over plan file lists)
- **Fix:** `DesignOverlayController+InputMode.swift` (same type, shared internal state — the service-extension pattern) and `DesignToolsSection.swift` (extracted sections, plan-named symbols unchanged)
- **Files modified:** the two new files + the two originals
- **Verification:** `wc -l` all touched files < 200; full bundle green
- **Committed in:** f0e7000, c30819d

**3. [Rule 1 - Test correctness] P3-rasterization-proof fixture expectations**
- **Found during:** Task 1 GREEN
- **Issue:** This host's CGContext rasterizes fills into Display P3 even when tagged sRGB (probe: pure green fill reads back (0,249,0)); hardcoded sRGB primaries made the exact-color assertions fail on green channels while the mapping itself was correct
- **Fix:** Tests read expected components from an identically-built NSBitmapImageRep at the known pixel — the suite proves which pixel a window point selects (the actual contract), on any host display profile
- **Files modified:** BoosterSimAppTests/PixelSamplerTests.swift
- **Verification:** PixelSamplerTests 6/6 green
- **Committed in:** d233016

**4. [Plan-structure] OverlayMetrics tokens added in Task 2 instead of Task 3**
- **Found during:** Task 2
- **Issue:** Task 2's ruler chrome (marker radius, readout inset) needs design tokens; the code-standards "never hardcode layout values" rule applies to Task 2's drawing code, but the plan schedules the enum for Task 3
- **Fix:** OverlayMetrics created in Task 2 with the ruler constants; Task 3's loupe constants (loupeDiameter/magnification default/range, exactly the plan's values) joined it
- **Files modified:** BoosterSimApp/Utilities/DesignTokens.swift
- **Verification:** Task 3 acceptance criterion "OverlayMetrics exists with loupe constants" holds
- **Committed in:** f0e7000, c30819d

---

**Total deviations:** 4 auto-fixed (1 blocking, 1 code-standards, 1 test-correctness, 1 plan-structure)
**Impact on plan:** No scope change — every plan-named symbol, seam, and acceptance criterion landed as specified; the fixes make the plan's own interaction model actually receive events and keep the code standards intact.

## Issues Encountered

- Swift 6 init ordering: `magnification` (didSet, no inline default) must be assigned before `importLegacyPresets()` runs ("self used before all stored properties initialized") — assignment moved above the init's method calls
- Several edit-tool anchor slips (renumbering drift on multi-hunk patches) mangled regions of DesignOverlayService and the controller extension mid-task; every one was caught by the syntax probe or the immediate re-read and repaired before any build/commit — no commit contains a broken tree
- Task 2's first build failed on extension-visibility (`currentContentRect`/`currentScale` private) — flipped to internal with the same comment convention DesignOverlayService uses for its +Presets/+Import split

## Known Stubs

None — no new stubs, placeholders, or unwired controls. (The pre-existing 04-01 `pickedColor` producer gap is now closed by this plan: WINDOWS.md entry #4 marked fixed.)

## Flagged Edges Still Open (close at 04-04 phase-gate smoke)

- Focus retention while a tool is armed (Simulator title bar must not grey — Pitfall 4 warning sign), Esc fired while the SIMULATOR holds focus (local monitor sees own-app events only; plan-sanctioned local-monitor choice), loupe accuracy against known colors, and D-04 five-layer ordering with ruler/magnifier readouts live
- Cached-capture freshness (A5): Simulator content changing mid-hover shows stale pixels until resize/re-arm — smoke's loupe step confirms acceptability
- CGImage partial-edge crops: `cropping(to:)` clamps at image bounds, so the loupe may show a non-square aspect at the window's extreme edges — visual check at smoke

## User Setup Required

None — no external service configuration required. (Screen Recording permission is already part of onboarding; denied permission degrades with an honest caption.)

## Next Phase Readiness

- 04-04 (phase-gate closure) has everything the smoke needs: arm/measure/Esc, arm/pick/copy, degradation captions, and the five-layer D-04 stack (comparison < ruler/magnifier < safeArea < grid) installed and ordered
- Docs truth pass (04-04) should name the async-exemption pattern with both sites (CaptureService + PixelSamplerService) per the plan's success criteria
- 229/229 unit tests green; zero new dependencies; monitors balanced; no ambient tracking paths

---
*Phase: 04-design-tools*
*Completed: 2026-08-31*

## Self-Check: PASSED

All 6 created files exist on disk; commits 2ebfbb0 / d233016 / f0e7000 / c30819d present in git log; Task 1 (11/11 tests), Task 2 (BUILD SUCCEEDED + 11/11), Task 3 (BUILD SUCCEEDED + 24/24 + 229/229 full bundle) all exit 0; acceptance-criteria greps pass for all three tasks (async-keyword confinement, mapper exclusivity, monitor balance, token usage, layer install, single-tool rule).
