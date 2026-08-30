---
phase: 02-capture-tools
plan: 01
subsystem: capture
tags: [screencapturekit, scscreenshotmanager, coregraphics, appstoreconnect, nspanel, combine, tcc]

# Dependency graph
requires:
  - phase: 01-foundation
    provides: side-panel shell, SimulatorWindowTracker (CGWindowID), PermissionManager, design tokens
provides:
  - One-shot window screenshot spine (ScreenshotService + CaptureCompositor + CaptureService facade + CaptureThumbnailPanel)
  - ASCFramePreset / BezelMode / CaptureBackground / CaptureDestination option models (raw values are persistence keys)
  - Pure-CG compositing engine with unit tests (frame/render, alpha-flattened, uniform scale)
  - Capture settings persistence (eight @AppStorage keys + custom-path StorageKey + CaptureExportFormat/CaptureDestinationKind)
  - Sanitized timestamp-unique filename builder (CaptureFilename utility)
  - Destination routing: Desktop folder / clipboard / custom (NSSavePanel begin) / ask
  - TCC permission degradation flow (preflight → setup UX → quit-and-reopen prompt)
affects: [02-recording-touch-indicators, 03-export, 04-phase-gate]

# Actuals (#2632) — pairs with the plan's estimate (55k tokens, low confidence)
actuals:
  tokens: 18457        # chars/4 over the realized diff (96b113b..HEAD), incl. scaffold deletion
  tasks: 2             # of 3 — Task 3 is the blocking-human live smoke (pending)
  commits: 4           # test(RED) ×2 + feat(GREEN) ×2

# Tech tracking
tech-stack:
  added: []            # Apple frameworks only (ScreenCaptureKit, CoreGraphics, ImageIO, AppKit) — REQ-nfr-03 intact
  patterns:
    - "Sync Combine facade over async SCK internals (DeepLinkService Task-bridge, NetworkConditionService shell)"
    - "@Published option mirrors synced to AppSettings via didSet (relaunch persistence without @AppStorage publish caveats)"
    - "Generic pillsGrid/pillsRow (RawRepresentable + RandomAccessCollection) for 260pt pill pickers"
    - "Alpha-skipped CGContext bitmap as the alpha-flattening mechanism (ASC rejects transparency)"

key-files:
  created:
    - BoosterSimApp/Models/ASCFramePreset.swift
    - BoosterSimApp/Models/BezelMode.swift
    - BoosterSimApp/Models/CaptureDestination.swift
    - BoosterSimApp/Utilities/CaptureCompositor.swift
    - BoosterSimApp/Utilities/CaptureFilename.swift
    - BoosterSimApp/Services/ScreenshotService.swift
    - BoosterSimApp/Windows/CaptureThumbnailPanel.swift
    - BoosterSimAppTests/CaptureFramingTests.swift
    - BoosterSimAppTests/CaptureSettingsTests.swift
  modified:
    - BoosterSimApp/Services/CaptureService.swift
    - BoosterSimApp/Views/SideWindow/tabs/CaptureTabView.swift
    - BoosterSimApp/Models/AppSettings.swift
    - BoosterSimApp/App/AppDelegate.swift
    - BoosterSimApp/Utilities/AppLogger.swift

key-decisions:
  - "Screenshot acquisition uses SCContentFilter(desktopIndependentWindow:) matched to the tracked CGWindowID — display filters rewritten away (privacy prohibition)"
  - "Alpha flattening via alpha-skipped output bitmap — opacity by construction, not post-processing"
  - "Filename builder extracted to Utilities/CaptureFilename.swift (Rule-3) — plan placed it in CaptureService, but the standing 200-LOC limit could not otherwise close"
  - "Preset count is SEVEN, not the plan's 'eight' — every enumeration in the plan lists exactly 7 verified ASC portrait sizes (6.9\"×3, 6.5\"×2, iPad 13\"×2); the count '8' is a plan arithmetic slip; inventing an 8th size would violate 'exact per Apple's spec'"
  - "Clipboard destination skips the floating thumbnail — nothing on disk to reveal in Finder"

patterns-established:
  - "Pill picker helpers (pillsGrid/pillsRow) over any String-raw option enum"
  - "AppSettings injected-suite init rebinding @AppStorage storage for isolated-suite tests"
  - "Borderless NSPanel copy with threeAXHighlightPanel divergences (clickable, image content, 3s timer)"

requirements-completed: []   # REQ-roadmap-phase2-capture-tools / REQ-fr-09 / REQ-nfr-03 stay open until the Task 3 live smoke is human-approved

coverage:
  - id: D1
    description: "ASC framing engine — exact preset table, centered uniform-scale framing, opaque output, drawn-bezel cutout geometry"
    requirement: REQ-roadmap-phase2-capture-tools
    verification:
      - kind: unit
        ref: "BoosterSimAppTests/CaptureFramingTests.swift (8 @Test funcs, all passing)"
        status: pass
    human_judgment: false
  - id: D2
    description: "Capture settings persistence (eight keys + custom path) and sanitized timestamp-unique filenames"
    requirement: REQ-roadmap-phase2-capture-tools
    verification:
      - kind: unit
        ref: "BoosterSimAppTests/CaptureSettingsTests.swift (5 @Test funcs, all passing)"
        status: pass
    human_judgment: false
  - id: D3
    description: "Live end-to-end screenshot on a booted Simulator — preset-exact dimensions, no alpha, window-only content, thumbnail, permission cycle, all four destinations"
    requirement: REQ-roadmap-phase2-capture-tools
    verification: []
    human_judgment: true
    rationale: "Needs TCC Screen Recording grant state cycling, WindowServer access, and a real booted Simulator window — research marks live SCScreenshotManager manual-only; not reproducible in unit tests"

# Metrics
duration: 28min
completed: 2026-08-30
status: halted           # Tasks 1–2 complete and green; halted at the designed Task 3 blocking-human checkpoint
---

# Phase 02 Plan 01: Screenshot Tracer Summary

**One-shot window screenshot spine: SCScreenshotManager + desktop-independent filter → pure-CG ASC compositor (alpha-free) → Desktop/clipboard/custom/ask routing → 3s floating thumbnail, with TCC degradation flow and full settings persistence**

## Performance

- **Duration:** 28 min (started 2026-08-30T11:47:13Z, stopped 2026-08-30T12:15:22Z)
- **Tasks:** 2 of 3 complete (Task 3 = blocking-human live smoke, pending)
- **Files modified:** 14 (9 created, 5 modified)
- **Commits:** 4 (test ×2 RED, feat ×2 GREEN)

## Accomplishments

- Tracer slice end-to-end: Capture button → CaptureService sync facade (TCC preflight, degraded UX, quit-and-reopen prompt) → ScreenshotService (SCScreenshotManager, desktopIndependentWindow filter matched to tracked CGWindowID, Simulator-bundle DEBUG guard) → CaptureCompositor (preset canvas, uniform scale, bezel/background, alpha-skipped output) → sanitized timestamped write + CaptureThumbnailPanel (3s auto-hide, click-to-reveal)
- The defective 312-LOC scaffold is fully cut over: display filter, unbounded frame array, 15 fps cap, hand-rolled AVAssetWriter loop, per-frame CIContext GIF, and runModal save all deleted
- Wave 0 tests green: CaptureFramingTests 8/8, CaptureSettingsTests 5/5; full unit bundle 59/59 exit 0; Debug build clean
- Eight capture keys persist across relaunch via AppSettings (injected-suite rebindable); custom folder as plain string path (REQ-nfr-04)

## Task Commits

1. **Task 1 (tracer):** `efade03` test — failing CaptureFramingTests (RED); `4012692` feat — models, compositor, ScreenshotService, facade, thumbnail panel, tab, wiring (GREEN)
2. **Task 2 (auto):** `c056992` test — failing CaptureSettingsTests (RED); `1e52ec2` feat — persistence, filename builder, clipboard/custom/ask routing, destination section (GREEN)
3. **Task 3 (checkpoint:human-verify, gate blocking-human):** pending human smoke — not committed, nothing to commit

## Verification

- Task 1 `<automated>`: `-only-testing:BoosterSimAppTests/CaptureFramingTests` — 8/8 passed; Debug build — **BUILD SUCCEEDED**
- Task 2 `<automated>`: `-only-testing CaptureSettingsTests -only-testing CaptureFramingTests` — 13/13 passed
- Full house-standard unit suite `-only-testing:BoosterSimAppTests -skip-testing:BoosterSimAppUITests` — **TEST SUCCEEDED, exit 0, 59 cases, 0 failures**
- Pre-existing flake note (STATE.md line 87, pristine-HEAD-verified): the plan's exact verify invocations intermittently exit 65 *after all test cases pass* via the post-test runner "Early unexpected exit" bootstrap — the documented flag combination above exits 0. Two occurrences this run, both with every case green.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Extracted filename builder to Utilities/CaptureFilename.swift**
- **Found during:** Task 2
- **Issue:** Plan placed `captureFilename(device:preset:date:)` in CaptureService.swift, but Task 2's routing + persistence additions push that file past the standing 200-LOC house limit (248 LOC with everything in place). Task 2's acceptance pins NSPasteboard/NSSavePanel/route in CaptureService, so routing could not move instead.
- **Fix:** Pure filename construction (sanitizer + stamp formatter) moved to a caseless-enum utility in `Utilities/` (PositionCalculator precedent); CaptureService and tests call `CaptureFilename.captureFilename(...)`. CaptureService lands at exactly 200 LOC.
- **Files modified:** BoosterSimApp/Utilities/CaptureFilename.swift (new), BoosterSimApp/Services/CaptureService.swift, BoosterSimAppTests/CaptureSettingsTests.swift
- **Verification:** CaptureSettingsTests filename behaviors green; unit suite exit 0
- **Committed in:** 1e52ec2

**2. [Rule 1 - Bug] ASC preset count is seven, not eight**
- **Found during:** Task 1 (test authoring)
- **Issue:** Plan says "eight cases"/"eight pixel sizes" but every concrete enumeration (behavior bullets, acceptance criteria, research ASC table) lists exactly seven verified portrait sizes: 1320×2868, 1290×2796, 1260×2736 (6.9″), 1284×2778, 1242×2688 (6.5″), 2064×2752, 2048×2732 (iPad 13″).
- **Fix:** Shipped the seven enumerated cases; inventing an eighth would violate "exact per Apple's spec".
- **Files modified:** BoosterSimApp/Models/ASCFramePreset.swift, BoosterSimAppTests/CaptureFramingTests.swift
- **Verification:** presetPixelSizesMatchAppleSpecExactly + deviceFamily tests green
- **Committed in:** efade03 / 4012692

**3. [Rule 3 - Blocking] SwiftLint-conformant preset case identifiers**
- **Found during:** Task 1
- **Issue:** Underscored case names (`iphone69_1320x2868`) trip swiftlint `identifier_name`; raw values must stay stable as persistence keys.
- **Fix:** Identifiers renamed to camelCase (`iphone69x1320`) with implicit String raw values (nothing shipped — these are the final names); switch bodies and tests updated.
- **Committed in:** 4012692

**4. [Rule 3 - Blocking] GitNexus impact analysis substituted**
- **Found during:** Task 1 read_first
- **Issue:** AGENTS.md mandates `gitnexus_impact` before editing symbols, but GitNexus MCP tools are unavailable in this runtime (orchestrator note).
- **Fix:** Grep/reference-based blast-radius map instead: `CaptureService()` constructed at AppDelegate.swift:27 and SideWindowView.swift:97 (#Preview); property bindings only in CaptureTabView.swift; SideWindowController is pass-through. All d=1 sites migrated (no-arg convenience init keeps the #Preview source-compatible; AppDelegate passes dependencies explicitly).
- **Verification:** Debug build green proves all call sites compile
- **Committed in:** 4012692

**5. [Execution-order note] Tracer gate folded into Task 3**
- The generic tracer feedback gate would stop after Task 1 in interactive runs; this plan's own structure designates Task 3's blocking-human smoke (steps 1–6 verify the tracer slice; Task 1 reversibility: "flagged only, no checkpoint") as the single gate, and the orchestrator's dispatch contract instructs sequential execution through Task 3. Task 2's automated verify re-ran the tracer's tests green before this checkpoint.

---

**Total deviations:** 4 auto-fixed (2 blocking, 1 bug, 1 tooling substitution) + 1 execution-order note
**Impact on plan:** No scope creep. The CaptureFilename split and seven-preset correction are structural corrections the plans 02/03 build on; all threats mitigated as planned.

## Issues Encountered

- Intermittent pre-existing runner flake (documented above, STATE.md) — two exit-65s with all test cases green; documented house-standard invocation exits 0. Not chased per assignment instructions.
- `newValue` is not in scope inside `didSet` on `@Published`-wrapped properties — mirrors reference the property name explicitly.

## User Setup Required

Task 3 smoke prerequisites (from plan `user_setup`):
- Boot one iOS Simulator device (6.9-inch class, e.g. iPhone 16 Pro Max) and keep its window open
- Screen Recording permission for BoosterSimApp: deny once for the degraded-UX step, then grant for capture steps (System Settings → Privacy & Security → Screen & System Audio Recording)

## Next Phase Readiness / Awaiting

- **Task 3 blocking-human smoke is the only open item** — 8 steps in the checkpoint return message; ROADMAP 02-01 intentionally left unchecked until approved
- Flagged assumption A4 (title-bar chrome in desktop-independent captures) is verified at smoke step 5; if chrome appears, the CaptureCompositor crop fallback must land inside this plan before approval
- Plans 02 (recording) and 03 (export) build on this spine additively; no architectural change expected

## Self-Check: PASSED

- All 10 key files exist on disk (FOUND ×10)
- Commits efade03, 4012692, c056992, 1e52ec2 present on main
- Task acceptance criteria mechanically verified (greps + LOC counts + both xcodebuild commands green)

---
*Phase: 02-capture-tools — Plan 01 (halted at designed blocking-human checkpoint)*
*Completed (tasks 1–2): 2026-08-30*
