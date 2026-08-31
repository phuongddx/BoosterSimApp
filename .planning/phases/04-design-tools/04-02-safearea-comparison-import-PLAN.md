---
phase: 04-design-tools
plan: 02
type: execute
wave: 2
depends_on: ["04-01"]
files_modified:
  - BoosterSimApp/Services/SafeAreaCatalog.swift
  - BoosterSimApp/Services/OverlayGeometry.swift
  - BoosterSimApp/Services/DesignOverlayService.swift
  - BoosterSimApp/Views/Overlay/SafeAreaOverlayView.swift
  - BoosterSimApp/Views/Overlay/ComparisonImageView.swift
  - BoosterSimApp/Views/SideWindow/DesignComparisonView.swift
  - BoosterSimApp/Views/SideWindow/tabs/DesignTabView.swift
  - BoosterSimApp/Windows/DesignOverlayController.swift
  - BoosterSimAppTests/SafeAreaCatalogTests.swift
  - BoosterSimAppTests/OverlayPersistenceTests.swift
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
    - "With a booted Simulator, toggling Safe Area draws Xcode-guide-style translucent bands (fill 0.15 + stroke 0.6 adaptive blue, D-03) at device-correct insets auto-selected from the tracked Simulator's device name via SafeAreaCatalog — D-02's mechanism: constants table first, manual override as the escape hatch"
    - "The safe-area overlay resolves orientation from the tracked content rect (portrait vs landscape aspect) and applies the verified landscape shape (top 0, bottom 21, sides = portrait top) — rotating the Simulator window re-resolves the bands"
    - "Manual per-side inset fields override the auto-selected values; Reset to Device Values restores the catalog resolution in one click (D-02)"
    - "The user can import an artboard image via file open, drag-and-drop onto the Design tab, or clipboard paste; it renders aspect-fit over the Simulator content at the comparison layer (BOTTOM of the D-04 stack — grid and safe-area stay above it regardless of toggle order)"
    - "Comparison opacity (and the kept overlay/split modes) control how much of the Simulator shows through the artboard; the artboard never covers the guide layers (D-04)"
    - "Re-importing an image replaces the previous one (no accumulation); an oversized image is rejected with a status caption before decode-caching, never a crash or OOM"
    - "The safe-area toggle persists across relaunch like every per-tool toggle (criterion 4)"
  artifacts:
    - BoosterSimApp/Views/Overlay/SafeAreaOverlayView.swift
    - BoosterSimApp/Views/Overlay/ComparisonImageView.swift
  key_links:
    - "DesignOverlayController tracker sink → SafeAreaCatalog.insets(for:logicalSize:) auto-resolution (on device/frame change) → DesignOverlayService.resolvedInsets @Published → SafeAreaOverlayView band rects via OverlayGeometry scale"
    - "DesignComparisonView manual fields / reset action → DesignOverlayService override model → controller re-push (override wins until reset)"
    - "DesignComparisonView import row + DesignTabView drop target + paste action → DesignOverlayService image accept (dimension-capped) → ComparisonImageView installed at OverlayLayer.comparison"
  prohibitions:
    - requirement_id: REQ-roadmap-phase4-design-tools
      category: privacy
      status: unverified
      flagged: true
      verification: test
      statement: "MUST NOT transmit imported artboards or any design content off the machine — the import paths are file open / drag / paste only, with no network client (no Figma API fetch, no telemetry): zero network-transfer symbols in the design-overlay sources (RESEARCH rejected the Figma API against the Apple-only ethos; RocketSim ships file-based overlays too)"
  flagged_assumptions:
    - requirement_id: REQ-roadmap-phase4-design-tools
      probe: research-A6
      status: unresolved
      statement: "File/drag/paste import of a user-exported image satisfies the roadmap's 'import a Figma/Sketch artboard' — neither .fig nor .sketch is a publicly documented format, so v1 imports exported PNG/PDF/JPEG. If the user expected native format parsing, scope changes materially; closes at the 04-04 phase-gate smoke via the import step."
    - requirement_id: REQ-roadmap-phase4-design-tools
      probe: research-A1
      status: unresolved
      statement: "Legacy device inset rows (44/48/20 families, iPad 20/20) are ASSUMED per 04-RESEARCH (verified rows cover 12-16 series); wrong legacy rows misplace guides but the D-02 manual override hides the error. Closes opportunistically at the 04-04 smoke if a legacy device is available."
    - requirement_id: REQ-roadmap-phase4-design-tools
      probe: idempotency
      status: unresolved
      statement: "UNRESOLVED EDGE (probe: 'What happens if this runs twice on the same input?') — re-importing the same image replaces the previous overlay image (single overlayImage slot, no accumulation) and re-dropping mid-drag is a no-op; unit-locked via OverlayPersistenceTests import-replace case in this plan, stays flagged until the 04-04 smoke."
---

<objective>
Expand the proven overlay slice with the two render-only tools: the D-02 safe-area guide and the criterion-3 artboard comparison overlay.

Task 1 extends the pure-data tier (orientation-aware catalog rows + landscape geometry) and the service state (auto-resolved insets, manual override model, persisted toggle). Task 2 renders SafeAreaOverlayView at the .safeArea layer (above the comparison image, below the grid — D-04) and adds the side-panel controls: toggle, per-side manual fields, reset-to-device action, resolved-values caption, and content-rect calibration fields (the bezel escape hatch from RESEARCH Pattern 5 / Open Question 5). Task 3 delivers the import story end-to-end: ComparisonImageView at the BOTTOM .comparison layer with opacity + kept overlay/split modes (RESEARCH Open Question 1: keep split — state already exists), fed by file open (existing seed), drag-and-drop, and paste — with the decompression-bomb dimension cap.

Purpose: criteria 1 (safe-area half) and 3 (comparison import) close here; D-02's constants-table mechanism and D-04's install order are exercised by a second and third consumer, proving the tracer contracts generalize.
Output: 2 new overlay views, 8 modified files, extended Wave 0 suites (landscape rows, import validation).
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

Source analogs (PATTERNS.md carries excerpts; the 04-01 SUMMARY records as-built deltas):
@BoosterSimApp/Services/SafeAreaCatalog.swift
@BoosterSimApp/Services/OverlayGeometry.swift
@BoosterSimApp/Services/DesignOverlayService.swift
@BoosterSimApp/Windows/DesignOverlayPanel.swift
@BoosterSimApp/Windows/DesignOverlayController.swift
@BoosterSimApp/Views/Overlay/GridOverlayView.swift
@BoosterSimApp/Views/SideWindow/DesignComparisonView.swift
@BoosterSimApp/Views/SideWindow/tabs/DesignTabView.swift
@BoosterSimAppTests/SafeAreaCatalogTests.swift
@BoosterSimAppTests/OverlayPersistenceTests.swift
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: Orientation-aware safe-area resolution — landscape rows + geometry, service state (auto/manual/reset), persisted toggle</name>
  <files>
    BoosterSimApp/Services/SafeAreaCatalog.swift,
    BoosterSimApp/Services/OverlayGeometry.swift,
    BoosterSimApp/Services/DesignOverlayService.swift,
    BoosterSimAppTests/SafeAreaCatalogTests.swift,
    BoosterSimAppTests/OverlayPersistenceTests.swift
  </files>
  <read_first>
    - .planning/phases/04-design-tools/04-CONTEXT.md — D-02 verbatim (constants table keyed per device + orientation, editable manual fields, reset-to-device action; constants not queryable live)
    - .planning/phases/04-design-tools/04-RESEARCH.md — SafeAreaCatalog verified-constants section (landscape verified shape: top 0, bottom 21, sides = portrait top, 16-series CITED; legacy rows ASSUMED), Code Examples safe-area guide draw skeleton, Pattern 5 (device-space alignment + manual calibration escape hatch), Open Question 5
    - .planning/phases/04-design-tools/04-PATTERNS.md — SafeAreaCatalog assignment (enum table style, lookup inputs from SimulatorWindow), shared persistence pattern
    - The 04-01 as-built versions of SafeAreaCatalog.swift, OverlayGeometry.swift, DesignOverlayService.swift (whole files — the exact signatures the tracer shipped; extend, do not reshape)
    - BoosterSimAppTests/SafeAreaCatalogTests.swift + BoosterSimAppTests/OverlayPersistenceTests.swift (extend the existing suites in place)
  </read_first>
  <behavior>
    - SafeAreaCatalogTests (extended): landscape resolution — insets(for:logicalSize:orientation: .landscape) for a 16-series device returns top 0, bottom 21, left/right = portrait top (59 for the 393x852 family); SE-class (20/0 portrait) landscape stays 0-inset sides
    - SafeAreaCatalogTests (extended): orientation is derived — OverlayGeometry.orientation(contentRect:) returns .portrait for a tall rect, .landscape for a wide rect, and the catalog lookup consumes it (round-trip via the service-facing entry point)
    - SafeAreaCatalogTests (extended): iPad fallback row resolves (768x1024-class size → 20/20 portrait, 20-sides landscape per the ASSUMED row) and unknown iPad name falls back by size
    - OverlayPersistenceTests (extended): showSafeArea toggle round-trips on an isolated suite like showGrid does; manual override values round-trip; reset clears the override flag so auto-resolution wins again
    - OverlayPersistenceTests (extended): image import accept/reject — a synthetic NSImage under the dimension cap is accepted; a synthetic over-cap payload is rejected with a nil result + caption string, no trap
  </behavior>
  <action>
    Extend SafeAreaCatalog (no reshape of the 04-01 API): add the orientation parameter to the lookup entry point with a .portrait default (source-compatible), and a `static func landscape(from portrait: Insets) -> Insets` transform encoding the verified shape (top 0, bottom 21, sides = portrait top) — legacy 20/0 rows landscape to all-zero sides per the ASSUMED rows, expressed as one data table, not special cases. Extend OverlayGeometry with `orientation(contentRect:) -> Orientation` (aspect comparison, enum declared alongside) and keep every existing signature untouched. DesignOverlayService gains the safe-area state per D-02: showSafeArea: Bool (persisted under "DesignOverlayShowSafeArea" in the versioned-key convention), resolvedInsets: SafeAreaCatalog.Insets (set by the controller from the tracker device — the service stays tracker-free per the Architectural Responsibility Map), useManualInsets: Bool + manualTop/Bottom/Leading/Trailing CGFloat fields (persisted), resetInsetsToDevice() clearing the manual flag, and the effectiveInsets computed switch (manual wins while flagged). Also add the import-accept validation RESEARCH V5 mandates: `static func validateImported(_ image: NSImage) -> Bool` style dimension-cap check (reject either edge over 16384 px — the decompression-bomb guard) plus an importError caption published on rejection; drag/paste acceptance lands in Task 3 on this seam. Re-import replaces the single overlayImage slot (never appends). Keep the file under 200 LOC — move nothing out, add tightly.
  </action>
  <verify>
    <automated>xcodebuild -project BoosterSimApp.xcodeproj -scheme BoosterSimApp -destination 'platform=macOS' test -only-testing:BoosterSimAppTests/SafeAreaCatalogTests -only-testing:BoosterSimAppTests/OverlayPersistenceTests -parallel-testing-enabled NO</automated>
    <fails_when>non-zero exit, a "failed" marker in the Swift Testing run summary, or "Executed 0 tests" (an -only-testing filter matched no suite)</fails_when>
  </verify>
  <acceptance_criteria>
    - SafeAreaCatalogTests covers the landscape transform (16-series: 0/21/sides=portrait-top), orientation derivation, and the iPad fallback; SafeAreaCatalog's 04-01 portrait rows are unchanged (existing tests still pass unmodified)
    - OverlayGeometry gains orientation(contentRect:) without any signature change to the six 04-01 functions
    - DesignOverlayService persists showSafeArea + manual inset fields, exposes resetInsetsToDevice() and an effectiveInsets computation where the manual flag wins until reset; the dimension-cap validation rejects over-16384px edges with a caption and accepts normal images
    - All extended tests green on the command above
  </acceptance_criteria>
  <done>D-02's full mechanism is data-complete and unit-locked: auto-resolution by name/size/orientation, manual override, reset, persisted toggle, and the import dimension cap.</done>
</task>

<task type="auto">
  <name>Task 2: SafeAreaOverlayView at the .safeArea layer + side-panel controls (toggle, manual fields, reset, calibration)</name>
  <files>
    BoosterSimApp/Views/Overlay/SafeAreaOverlayView.swift,
    BoosterSimApp/Windows/DesignOverlayController.swift,
    BoosterSimApp/Views/SideWindow/DesignComparisonView.swift
  </files>
  <read_first>
    - .planning/phases/04-design-tools/04-CONTEXT.md — D-03 (Xcode-guide styling: translucent fill + stroke, adaptive blue, amber never on overlay content), D-02 manual-override escape hatch wording
    - .planning/phases/04-design-tools/04-RESEARCH.md — Code Examples safe-area guide draw skeleton (systemBlue fill 0.15 / stroke 0.6, hairline via backingScaleFactor), Pattern 5 + Pitfall 3 (bezel drift → manual calibration fields), Pitfall 7 (1px hairlines via backingScaleFactor)
    - The 04-01 as-built GridOverlayView.swift (the view anatomy to mirror: geometry injection, draw guard, hairline discipline) and DesignOverlayController.swift (install + visibility + geometry push)
    - BoosterSimApp/Views/SideWindow/DesignComparisonView.swift (04-01 as-built — section conventions to extend)
    - BoosterSimApp/Utilities/DesignTokens.swift (Spacing tokens + SideWindowMetrics; no raw literals)
  </read_first>
  <action>
    BoosterSimApp/Views/Overlay/SafeAreaOverlayView.swift (new): `final class SafeAreaOverlayView: NSView` in the GridOverlayView anatomy — geometry + effectiveInsets injected by the controller, draw(_:) guards on both. Render four inset bands (top/bottom/leading/trailing) as NSBezierPath rects sized inset x scale within the content rect: fill systemBlue (or service gridColor-family adaptive tint) withAlphaComponent 0.15, stroke withAlphaComponent 0.6, lineWidth 1.0 / window.backingScaleFactor (the RESEARCH draw skeleton verbatim; D-03 — never the accent amber). Update on service objectWillChange via the controller's existing refresh path.

    BoosterSimApp/Windows/DesignOverlayController.swift (modify): install SafeAreaOverlayView via panel.install(view, at: .safeArea) — between the grid (above) and the comparison image (below) per D-04; extend the tracker sink to resolve SafeAreaCatalog.insets(for: sim.deviceName, logicalSize:, orientation: OverlayGeometry.orientation(contentRect:)) on every device/frame change and push into service.resolvedInsets (the service stays tracker-free); extend the service-sink visibility refresh to safeAreaOverlayView.isHidden = !service.showSafeArea.

    BoosterSimApp/Views/SideWindow/DesignComparisonView.swift (modify): new "Safe Area" CollapsibleSection with the pre-assigned SF Symbol `rectangle.dashed`: showSafeArea Toggle; a resolved-values caption row (device name + effective insets, monospacedDigit); four manual fields (top/bottom/leading/trailing, TextField value: with .keyboardType(.decimalPad)-equivalent macOS filtering) + a "Use Manual Insets" toggle binding useManualInsets; a "Reset to Device Values" AccentButton (this is an active control — amber allowed HERE, not in the overlay) calling resetInsetsToDevice(); a calibration sub-row with two small offset fields (x/y, persisted via the service) that the controller adds to contentRect before geometry computation — the bezel escape hatch (Pitfall 3 / Open Question 5). Design tokens only; existing section conventions untouched.
  </action>
  <verify>
    <automated>xcodebuild -project BoosterSimApp.xcodeproj -scheme BoosterSimApp -configuration Debug build && xcodebuild -project BoosterSimApp.xcodeproj -scheme BoosterSimApp -destination 'platform=macOS' test -only-testing:BoosterSimAppTests/SafeAreaCatalogTests -only-testing:BoosterSimAppTests/GridGeometryTests -parallel-testing-enabled NO</automated>
    <fails_when>non-zero exit on either command, "BUILD FAILED", a "failed" marker in the test summary, or "Executed 0 tests"</fails_when>
  </verify>
  <acceptance_criteria>
    - SafeAreaOverlayView.swift draws four band rects with the fill/stroke alphas 0.15/0.6 and hairline width divided by window.backingScaleFactor; it references no accent-color asset
    - DesignOverlayController installs the view at the .safeArea layer (install(_:at:) call present) and resolves insets on every activeSimulator emission feeding service.resolvedInsets
    - DesignComparisonView contains the Safe Area section with toggle, four manual fields, manual-enable toggle, reset button, resolved caption, and calibration offset fields — all bound to DesignOverlayService
    - The catalog resolution path runs through name-first/size-second with the orientation transform (no second lookup implementation)
    - Build + targeted suites green
  </acceptance_criteria>
  <done>Success criterion 1 complete: both halves of the criterion render — the dual grid (04-01) and the orientation-aware, manually-overridable safe-area bands — with grid above safe-area above any image per D-04.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 3: Comparison import end-to-end — ComparisonImageView at the bottom layer, file/drag/paste, opacity + split, bomb-guard</name>
  <files>
    BoosterSimApp/Views/Overlay/ComparisonImageView.swift,
    BoosterSimApp/Services/DesignOverlayService.swift,
    BoosterSimApp/Views/SideWindow/DesignComparisonView.swift,
    BoosterSimApp/Views/SideWindow/tabs/DesignTabView.swift,
    BoosterSimApp/Windows/DesignOverlayController.swift
  </files>
  <read_first>
    - .planning/phases/04-design-tools/04-CONTEXT.md — D-04 (comparison image BELOW ruler/magnifier readouts and below all guides; its opacity control is the see-through mechanism), import-path discretion (Figma API rejected: network + token surface against Apple-only ethos)
    - .planning/phases/04-design-tools/04-RESEARCH.md — Alternatives Considered (file/drag/paste vs Figma REST), Security Domain V5 row + threat patterns (decompression bomb; pasteboard type spoofing → typed pasteboard reads), Open Questions 1 (keep split) and 5, Don't Hand-Roll (UTType.image via NSOpenPanel.allowedContentTypes — scaffold already does)
    - .planning/phases/04-design-tools/04-PATTERNS.md — DesignComparisonService cut-over assignment (loadImage keep-verbatim excerpt), DesignTabView assignment
    - The Task 1 version of DesignOverlayService.swift (validation seam + importError caption already present)
    - BoosterSimApp/Services/DesignComparisonService.swift git history or the PATTERNS excerpt lines 56-63 (the loadImage seed this task re-exposes) — the seed now lives in DesignOverlayService
    - The 04-01 as-built DesignOverlayController.swift + DesignOverlayPanel.swift (install API + layer enum)
  </read_first>
  <behavior>
    - OverlayPersistenceTests (final extension of this plan): the accept-validation seam — a valid-dimension synthetic image passes, an over-cap synthetic image is rejected with importError set (already unit-locked in Task 1; this task must not regress it)
    - No new unit surface otherwise — view rendering and paste/drag are manual-only (04-VALIDATION Manual-Only rows); the task verify is build + existing suites
  </behavior>
  <action>
    BoosterSimApp/Views/Overlay/ComparisonImageView.swift (new): `final class ComparisonImageView: NSView` in the GridOverlayView anatomy — image + opacity + comparisonMode + splitPosition + geometry injected by the controller. draw(_:): guard image + geometry; aspect-fit the NSImage into the content rect (image.size in points, centered); in .overlay mode draw full-rect with alpha = overlayOpacity (the D-04 see-through mechanism); in .split mode clip to the trailing portion of the content rect at splitPosition x bounds.width (scaffold semantics kept — RESEARCH Open Question 1: keep split, state already exists). Never draw above guides — installed at OverlayLayer.comparison, the BOTTOM slot.

    DesignOverlayService (modify): expose three import entry points funneling into ONE accept path that runs the Task 1 dimension cap: loadImage() (the kept NSOpenPanel seed, allowedContentTypes [.image]) now routes through accept; `func importImage(from pasteboard: NSPasteboard)` reading typed image payloads only (NSImage(pasteboard:) guarded to image types — ignore non-image payloads per the threat register); a shared `func accept(image: NSImage)` that validates, replaces overlayImage (single slot — re-import replaces), clears/sets importError, and logs count + outcome only. Add onDragDropped convenience not needed — the view layer hands NSImage over.

    DesignComparisonView (modify): the comparison section gains an "Import" row: Open… button (loadImage), Paste button (importImage(from: NSPasteboard.general)), Clear button (clearOverlay), an importError caption row, and a drop hint caption. Keep the mode picker + opacity slider + split slider bound as shipped.

    DesignTabView (modify): make the tab scroll view an image drop target — .onDrop(of: [UTType.image], isTargeted:) handing the NSItemProvider-loaded NSImage to the service accept path; visual drop highlight via the existing token system; failed/non-image drops return false and set no state.

    DesignOverlayController (modify): install ComparisonImageView via panel.install(view, at: .comparison) FIRST in install order (bottom); extend the visibility refresh (image present → visible) and push image/opacity/mode/split changes on service updates.
  </action>
  <verify>
    <automated>xcodebuild -project BoosterSimApp.xcodeproj -scheme BoosterSimApp -configuration Debug build && xcodebuild -project BoosterSimApp.xcodeproj -scheme BoosterSimApp -destination 'platform=macOS' test -only-testing:BoosterSimAppTests/OverlayPersistenceTests -only-testing:BoosterSimAppTests/SafeAreaCatalogTests -parallel-testing-enabled NO</automated>
    <fails_when>non-zero exit on either command, "BUILD FAILED", a "failed" marker in the test summary, or "Executed 0 tests"</fails_when>
  </verify>
  <acceptance_criteria>
    - ComparisonImageView.swift aspect-fits within the content rect, applies alpha from overlayOpacity in overlay mode, and clips at splitPosition in split mode; it is installed via install(_:at: .comparison) so no later-added guide can render beneath it
    - All three import entry points (open, paste, drop) funnel through the single accept(image:) path that runs the dimension cap, sets importError on rejection, and replaces (never accumulates) the image slot
    - The pasteboard path reads typed image payloads only — non-image payloads leave state untouched
    - Zero network-transfer symbols (URLSession, NWConnection, CFNetwork, URLRequest) across DesignOverlayService.swift, ComparisonImageView.swift, SafeAreaOverlayView.swift, and DesignOverlayController.swift — the locality prohibition's source check
    - Build + targeted suites green
  </acceptance_criteria>
  <reversibility rating="reversible">Import-path choice (file/drag/paste, no Figma API) is additive local behavior; a future API client would slot beside accept(image:) without reshaping the layer contract.</reversibility>
  <done>Success criterion 3 complete: an artboard imported by any of the three paths renders under the guides with working opacity/split controls; oversized or non-image payloads degrade with captions, never crashes.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| User-chosen image files / pasteboard / drag payloads → app memory | Untrusted decoded image data crosses into the app (decompression bombs, type spoofing) |
| Defaults store → service decode | Persisted manual insets + toggle payloads cross from disk |
| Overlay window ↔ window server | Guide rendering above all apps (same discipline as 04-01: line-art/band rendering only) |

## STRIDE Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation Plan |
|-----------|----------|-----------|----------|-------------|-----------------|
| T-04-03 | Denial of Service | Decompression bomb via imported artboard (50k x 50k PNG OOMs the app) | medium | mitigate | Single accept(image:) path rejects either pixel edge over 16384 px BEFORE caching, sets an honest importError caption (never a crash); unit-locked accept/reject in OverlayPersistenceTests |
| T-04-04 | Tampering | Pasteboard type spoofing (non-image payload claiming image type) | low | mitigate | Typed reads only (NSImage(pasteboard:) / UTType.image-constrained open panel and drop types); non-image payloads return false and touch no state |
| T-04-05 | Information Disclosure | Imported designs exfiltrated over the network | high | mitigate | No network client exists in the import path (source-grepped absence: URLSession/NWConnection/CFNetwork/URLRequest); RESEARCH rejected the Figma REST API for exactly this surface; ASVS L1 + block_on=high satisfied by construction and by the acceptance-criteria source check |

</threat_model>

<verification>
- Task 1 targeted suites green (extended SafeAreaCatalogTests + OverlayPersistenceTests)
- Task 2/3 build + suites green; install-layer assertions hold (safeArea above comparison, grid above safeArea)
- Locality source check (zero network-transfer symbols) green
- Visual proof (band placement, orientation switch, import rendering, D-04 ordering under a visible image) rides the 04-04 phase-gate blocking smoke
</verification>

<success_criteria>
- Criterion 1 fully closed (grid 04-01 + safe-area here, orientation-aware, manually overridable)
- Criterion 3 closed (file/drag/paste import, opacity/split, guides never hidden by the image)
- D-02's escape hatch real: manual insets + content-rect calibration fields
- No new external surface: zero network symbols, zero packages
</success_criteria>

## Artifacts this phase produces

**Plan 04-02 symbols (new):**
- `final class SafeAreaOverlayView: NSView` — Views/Overlay/SafeAreaOverlayView.swift
- `final class ComparisonImageView: NSView` — Views/Overlay/ComparisonImageView.swift
- `SafeAreaCatalog.landscape(from:)` + orientation-aware `insets(...)` parameter + iPad fallback rows — Services/SafeAreaCatalog.swift
- `OverlayGeometry.orientation(contentRect:)` + `enum OverlayGeometry.Orientation` — Services/OverlayGeometry.swift
- `DesignOverlayService`: showSafeArea, resolvedInsets, useManualInsets, manualTop/Bottom/Leading/Trailing, resetInsetsToDevice(), effectiveInsets, calibration offsets, importImage(from:), accept(image:) with the 16384-px dimension cap + importError caption

**Consumers modified:** DesignOverlayController (safe-area + comparison install, inset auto-resolution), DesignComparisonView (Safe Area section, Import row), DesignTabView (image drop target)

<output>
Create `.planning/phases/04-design-tools/04-02-safearea-comparison-import-SUMMARY.md` when done
</output>
