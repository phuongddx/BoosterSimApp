---
phase: 04-design-tools
plan: 04
type: execute
wave: 4
depends_on: ["04-01", "04-02", "04-03"]
files_modified:
  - docs/system-architecture.md
  - docs/codebase-summary.md
  - docs/code-standards.md
autonomous: false
requirements:
  - REQ-roadmap-phase4-design-tools
user_setup:
  - service: ios-simulator
    why: "Task 2 blocking smoke needs a booted iOS Simulator with visible content of known colors (any app screen), Screen Recording permission granted to BoosterSimApp (onboarded), and an exported artboard PNG (any Figma/Sketch artboard exported as image) for the import step"
    dashboard_config:
      - task: "Boot one iOS Simulator device (prefer a 12-16 series iPhone so safe-area insets are among the verified rows)"
        location: "Xcode → Devices and Simulators, or Simulator.app"
      - task: "Export any artboard as PNG from Figma/Sketch (1x) and keep it findable"
        location: "Figma/Sketch export dialog"
estimate:
  tokens: 20000
  raw_tokens: 20000
  tasks: 2
  confidence: low

must_haves:
  truths:
    - "docs/system-architecture.md carries a Design Tools section whose symbols, data flow, permission/degradation paths, and persistence keys match the as-shipped source (grep-verified), and docs/codebase-summary.md lists the new files with real LOC"
    - "docs/code-standards.md states the async-exemption truthfully: the sanctioned bridge pattern (CaptureService AND PixelSamplerService), not a single-type accident"
    - "The full BoosterSimAppTests bundle passes (exit 0) and both dependencies remain unperturbed: zero SPM changes (git diff on Package.resolved clean + sha256 identical before/after the gate)"
    - "A blocking human smoke over a booted Simulator observes all six groups green: grid (dual 8/4 + tracking + persistence), safe-area (auto + manual + reset + landscape), ruler (device-point readout + Esc + Simulator focus kept), magnifier/picker (correct hex + commit + copy), comparison import (open/drag/paste + opacity + guides-above-image per D-04), and focus persistence + degraded states"
    - "Every flagged assumption carried by plans 01-03 (idempotency, concurrency, A4 bezel/title-bar, A5 freshness, A6 import interpretation, A1 legacy rows, capture-mode focus) PLUS the two research-log assumptions no plan carries as a flag (A2: D-02's '96pt family' wording has no real iPhone referent — the real shipped top set is {20, 44, 47, 48, 50, 54, 59, 62}; A3: 17-series/Air rows default to the 59-family) is answered pass/known-gap/surfaced-to-user in the smoke record before REQ-roadmap-phase4-design-tools closes"
  artifacts:
    - docs/system-architecture.md
    - docs/codebase-summary.md
    - docs/code-standards.md
  key_links:
    - "As-shipped source symbols → docs sections (grep -l in BOTH docs per the proven 03-05 truth-gate shape) — the doc-truth link the next phase's onboarding reads"
    - "04-01/02/03 flagged_assumptions → Task 2 smoke step outcomes → SUMMARY record → requirement close (requirements stay open at halt, close on approval — Phase 3 gate pattern)"
  prohibitions:
    - requirement_id: REQ-roadmap-phase4-design-tools
      category: transparency
      status: unverified
      flagged: true
      verification: judgment
      statement: "MUST NOT close REQ-roadmap-phase4-design-tools on suite-green alone — the phase's acceptance is visual (overlays over a foreign window, TCC-gated sampling); the blocking smoke observing all six groups is the close condition, and any known gap must be recorded honestly in the SUMMARY rather than smoothed over"
  flagged_assumptions: []
---

<objective>
Close Phase 4 the way Phases 2/3 closed: make the documentation tell the as-shipped truth, prove the dependency pin, then gate the phase behind a blocking human smoke that observes every roadmap criterion live.

Task 1 is the docs truth pass: a Design Tools section in docs/system-architecture.md (architecture: single persistent overlay panel + layered install contract, service split, cached-capture sampling, capture-mode input, permission degradation, versioned persistence incl. the legacy import), the codebase-summary file map refresh, and the code-standards async-exemption wording naming the bridge pattern (RESEARCH Pitfall 6 instruction). Task 2 is the phase gate: full unit bundle + Debug build + Package.resolved pin (git diff + sha256 content-stability per the 02-04 standard, since the file is still untracked), then the six-group blocking smoke that also disposes the flagged assumptions from plans 01-03 and surfaces research-log assumptions A2/A3 to the user at the gate.

Purpose: the phase's core acceptance is visual and permission-gated — no automated suite can see a grid over a foreign window or a correct sampled hex; the human gate IS the acceptance test (04-VALIDATION Manual-Only rows).
Output: truthful docs, green full bundle, proven pin, one approved smoke record; REQ-roadmap-phase4-design-tools closes on approval.
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
@.planning/phases/04-design-tools/04-03-ruler-magnifier-SUMMARY.md
@docs/system-architecture.md
@docs/codebase-summary.md
@docs/code-standards.md
</context>

<tasks>

<task type="auto">
  <name>Task 1: Docs truth pass — Design Tools architecture section, file-map refresh, async-exemption wording</name>
  <files>
    docs/system-architecture.md,
    docs/codebase-summary.md,
    docs/code-standards.md
  </files>
  <read_first>
    - .planning/phases/04-design-tools/04-03-ruler-magnifier-SUMMARY.md and the 01/02 SUMMARYs — as-built deltas (what actually shipped vs plan: naming, keys, constants) are the truth source
    - docs/system-architecture.md — existing Capture Tools section (the § structure this pass extends) and any Design placeholder lines to correct
    - docs/codebase-summary.md — current file map + LOC table format
    - docs/code-standards.md — the concurrency exemption list (currently "CaptureService alone" per STATE.md Phase 3 note) and prohibited-patterns section
    - .planning/phases/04-design-tools/04-RESEARCH.md — Pitfall 6 (update the exemption wording to name the pattern, not one type), Pattern 1-6 (the architecture the section documents)
  </read_first>
  <action>
    docs/system-architecture.md: add a "Design Tools" section alongside Capture Tools documenting the AS-SHIPPED architecture: one persistent transparent click-through NSPanel (DesignOverlayPanel) tracking the Simulator frame via the tracker sink with a locked subview-order install contract (D-04 layers: comparison < interactive < safeArea < grid); the service split (DesignOverlayService state + SafeAreaCatalog pure constants + OverlayGeometry pure mapping + PixelSamplerService cached-capture sampling); capture-mode input (ignoresMouseEvents flip + local Esc monitor + global mouseMoved while armed); permission degradation (Screen Recording preflight → honest caption); persistence (versioned DesignOverlay* keys, one-shot legacy import from the scaffold key); the bezels-off content-rect assumption with the calibration escape hatch. Correct any stale placeholder/key lines the pass finds (02-04 truth-pass precedent: fix stale lines in the same pass).

    docs/codebase-summary.md: add the new files (Windows/DesignOverlayPanel.swift, Windows/DesignOverlayController.swift, Services/{DesignOverlayService,PixelSamplerService,SafeAreaCatalog,OverlayGeometry}.swift, Views/Overlay/{Grid,SafeArea,Ruler,Magnifier,ComparisonImage}Overlay/View.swift, the four+one test suites) with real wc -l LOC, and mark the deleted scaffold service as removed.

    docs/code-standards.md: update the async-exemption wording to name the sanctioned bridge PATTERN — sync public API → single private Task bridge → TCC preflight — instantiated by CaptureService (Phase 2) and PixelSamplerService (Phase 4); views/controllers stay synchronous. Update the persistence-key convention note with the versioned-key + one-shot-import pattern if the doc enumerates keys.

    Truth-gate the pass with the proven grep loop (see verify). No aspirational statements: every documented symbol, key, and constant must exist in source at commit time.
  </action>
  <verify>
    <automated>for f in DesignOverlayService DesignOverlayPanel DesignOverlayController PixelSamplerService SafeAreaCatalog OverlayGeometry GridOverlayView SafeAreaOverlayView RulerOverlayView MagnifierView ComparisonImageView DesignOverlayPresets; do grep -l "$f" docs/system-architecture.md docs/codebase-summary.md | wc -l | grep -q '^2$' || echo "MISSING: $f"; done</automated>
    <fails_when>any "MISSING: <symbol>" line in the output (a symbol absent from either doc)</fails_when>
  </verify>
  <acceptance_criteria>
    - The grep loop prints zero MISSING lines for all eleven symbols
    - docs/system-architecture.md documents the panel config flags (hidesOnDeactivate false / nonactivating / click-through), the D-04 layer order, the cached-capture sampling model, the permission-degradation path, and the versioned persistence keys — each statement traceable to shipped source
    - docs/code-standards.md names both bridge instances in the exemption wording (no stale single-type claim)
    - docs/codebase-summary.md LOC figures match wc -l at commit time
    - No stale Design placeholder or deleted-service reference remains in any of the three docs
  </acceptance_criteria>
  <done>Docs tell the as-shipped truth, proven by the symbol grep across both architecture and summary docs.</done>
</task>

<task type="checkpoint:human-verify" gate="blocking-human">
  <name>Task 2: Phase gate — full unit bundle + dependency pin, then six-group blocking smoke over a booted Simulator</name>
  <files>none</files>
  <read_first>
    - .planning/phases/04-design-tools/04-VALIDATION.md — Manual-Only Verifications rows (tracking, loupe sampling vs known color, artboard alignment) and the Per-Task Verification Map
    - .planning/phases/04-design-tools/04-01..03-PLAN.md flagged_assumptions blocks — the nine flagged items this smoke disposes (04-01: idempotency, concurrency, A4; 04-02: A6, A1, import-idempotency; 04-03: A5, arm/disarm concurrency, capture-mode focus)
    - .planning/phases/04-design-tools/04-RESEARCH.md — Open Question 3 (verify 17-series/Air insets opportunistically if such a device is booted; do not block otherwise), the Assumptions Log rows A2 (D-02's "96pt family" shorthand has no real iPhone referent — real top set {20, 44, 47, 48, 50, 54, 59, 62}) and A3 (17-series/Air default to the 59-family), and Environment Availability (booted Simulator required at verification time only)
  </read_first>
  <action>
    Run the automated gate FIRST and record outputs: the full unit bundle (proven 03-05 command), the Debug build, and the dependency pin — capture sha256 of BoosterSimApp.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved BEFORE and AFTER the bundle run and require identical hashes (the file is untracked, so the git diff alone is vacuous — the 02-04 content-stability standard). Zero external packages were added this phase; any hash drift is a red flag to investigate, not to commit.

    Then the blocking human smoke over the prepared Simulator (user_setup). Execute the six groups in how-to-verify, recording per-step pass/fail AND an explicit disposition for each flagged assumption. Known-gap honesty rule: a step that reveals a limitation (e.g. bezel-on misalignment, stale loupe content) records the gap and its escape hatch — it does not fail the phase if the roadmap criterion itself is met and the gap is documented in the SUMMARY. A FALSE success caption or a silently-dropped preset DOES fail the gate (the transparency prohibition). If a 17-series or iPhone Air device is available, opportunistically compare its safe-area bands against a running app's real insets; otherwise leave the row manual-override-covered and say so.
    Disposition completeness (resolves plan-checker W5): the flagged_assumptions blocks of plans 01-03 do not carry research-log assumptions A2 and A3 — dispose both HERE so the locked-wording-vs-shipped-table discrepancy reaches the user at the gate rather than dying in the research file. A2: state plainly that the D-02 discuss-phase "96pt family" wording has no real iPhone safe-area referent (no device has a 96pt top inset; the shipped SafeAreaCatalog rows cover the real tops {20, 44, 47, 48, 50, 54, 59, 62}) with the manual override as the escape hatch for anything the table misses — ask the user to accept the real row set or name the device they meant by "96" (e.g. a windowed iPad) so a row can be added in a fix-up. A3: record that 17-series/Air rows ship on the 59-family default until the opportunistic live check runs, manual override covering any gap. Both get their own lines in the SUMMARY dispositions.
  </action>
  <verify>
    <automated>xcodebuild -project BoosterSimApp.xcodeproj -scheme BoosterSimApp -destination 'platform=macOS' test -only-testing:BoosterSimAppTests -skip-testing:BoosterSimAppUITests -parallel-testing-enabled NO && git diff --exit-code BoosterSimApp.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved</automated>
    <fails_when>non-zero exit, any failed test in the BoosterSimAppTests summary, or non-empty git diff output on Package.resolved</fails_when>
    <human-check>All six smoke groups observed and recorded pass/fail with per-flagged-assumption dispositions; specifically: dual 8/4 grid visible and device-aligned; safe-area bands match the device's real insets with working manual override + reset; ruler readout matches a known distance; magnifier hex matches a known color within rounding; imported artboard renders with guides ABOVE it while all three tool toggles are on; overlays survive BoosterSimApp focus loss and hide cleanly when the Simulator shuts down.</human-check>
  </verify>
  <acceptance_criteria>
    - Full unit bundle exits 0; Debug build exits 0; Package.resolved sha256 identical before/after (recorded in the SUMMARY)
    - Summary contains a per-step pass/fail record for all six groups plus a disposition line for each of the nine plan-flagged assumptions AND the two research-log assumptions A2/A3 (pass / known-gap-with-escape-hatch / follow-up / surfaced-to-user) — the A2 line records the user's answer on the 96pt-family shorthand
    - Grid group: 8pt lines visibly emphasized over 4pt minors; grid stays aligned through a Simulator move + resize; toggle state survives app relaunch (idempotency edge re-checked: relaunching twice imports no duplicate presets — visible preset list stable)
    - Safe-area group: bands sit at the booted device's real insets (compare against Xcode's guides or a running app's layout), manual fields move them, Reset restores, window rotation re-resolves (landscape shape: sides inset, top clear)
    - Ruler group: drag between two known points reports the expected device-point distance (e.g. across the top inset band); Esc cancels cleanly; the Simulator title bar does NOT grey while the tool is armed (focus retained)
    - Magnifier group: loupe over a known solid color shows the expected hex within rounding; click commits; Copy pastes the hex string; magnification stepper changes zoom
    - Comparison group: the artboard imports via Open AND via drag (paste optional), opacity slider reveals the Simulator through it, and with grid + safe-area + image all enabled the guides render ABOVE the image (D-04 proof); an oversized image attempt shows the rejection caption
    - Degradation group: focusing another Mac app leaves overlays visible; shutting down the Simulator hides the overlays without a crash; re-booting restores them
  </acceptance_criteria>
  <what-built>The complete Phase 4 overlay toolset on the 04-01 tracer spine: DesignOverlayPanel (persistent click-through panel, D-04 layered install) + DesignOverlayController (tracker sync, input modes) + DesignOverlayService (cut-over state, versioned persistence, one-shot legacy import) + SafeAreaCatalog/OverlayGeometry (tested pure data/math) + five overlay views (Grid dual 8/4, SafeArea bands, Ruler with device-point readout, Magnifier loupe + picker, Comparison image) + PixelSamplerService (cached-capture sampling, the second sanctioned async site) — documented truthfully, full bundle green, pin proven.</what-built>
  <how-to-verify>
    With BoosterSimApp running, the Simulator booted per user_setup, Screen Recording granted, and an exported artboard PNG at hand:
    1. GRID: Design tab → toggle Grid on → confirm emphasized 8pt lines over subdued 4pt minors aligned to app layout; move and resize the Simulator window (overlay follows); toggle off/on; quit and relaunch BoosterSimApp (toggle persisted; preset list unchanged — no duplicates)
    2. SAFE AREA: toggle Safe Area → bands match the device's real insets; type manual values (bands move); click Reset to Device Values (bands restore); rotate the Simulator window/scene to landscape (bands re-resolve: side insets, clear top)
    3. RULER: arm the ruler → the Simulator keeps focus (title bar not grey) → drag across the top inset band → readout approximately equals the device's top inset in points → press Esc (line clears, overlay click-through again)
    4. MAGNIFIER: arm the magnifier → hover a known solid color → loupe shows it zoomed with the expected hex caption → click (color commits to the picker section) → Copy and paste the hex somewhere (string matches) → step magnification up/down
    5. COMPARISON: import the artboard via Open… → it renders over the app screen; drag the same file onto the Design tab (replaces, no duplicate); lower opacity to see the app through it; enable Grid + Safe Area simultaneously → guides render ABOVE the artboard (D-04); try an oversized image if available → rejection caption, no crash
    6. FOCUS + DEGRADE: click another Mac app (overlays stay visible); arm a tool and let the Mac screen lock/unlock if convenient; shut down the Simulator (overlays hide, no crash); boot again (overlays return); optionally re-verify safe-area on a 17-series/Air device if present; close by surfacing A2/A3 to the user — A2: the shipped inset table's real tops {20…62} replace the discuss-phase "96pt family" wording (accept, or name the intended device); A3: 17-series/Air rows ride the 59-family default until verified
  </how-to-verify>
  <resume-signal>Reply "approved" to close Phase 4 (REQ-roadmap-phase4-design-tools closes on approval; requirements stayed open at halt per the Phase 3 gate pattern), or name the failing group/step — a false success caption, a silently-dropped preset, or a D-04 ordering violation requires a fix inside this phase before closure.</resume-signal>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| Docs ↔ source | Documentation claims cross into onboarding truth; no new runtime boundary this plan |
| Smoke environment ↔ app | The blocking smoke exercises TCC-gated capture and overlay compositing live — verifying plans 01-03 mitigations, adding none |

## STRIDE Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation Plan |
|-----------|----------|-----------|----------|-------------|-----------------|
| T-04-09 | Repudiation | Phase closed on suite-green without visual proof | high | mitigate | Blocking-human gate is the close condition (the transparency prohibition); SUMMARY must carry per-group pass/fail + per-assumption dispositions; requirements stay open at halt and close only on approval |
| T-04-10 | Tampering | Dependency drift during the phase | low | mitigate | Pin gate: git diff --exit-code on Package.resolved + sha256 content-stability before/after the bundle run (the 02-04 standard; file untracked so the hash is the real proof) — zero packages were added this phase, drift is investigate-not-commit |

Carried mitigations verified by the smoke (no new code): T-04-06/07/08 (memory-only cache, window-scoped capture, monitor balance) are exercised live in groups 4 and 6.

</threat_model>

<verification>
- Task 1 symbol grep zero MISSING across both docs
- Task 2 automated gate: full unit bundle exit 0 + Debug build + pin proven (sha256 pair recorded)
- Task 2 human gate: six groups observed, nine flagged assumptions + research-log A2/A3 dispositioned (A2/A3 surfaced to the user, answer recorded)
- Phase close: on approval only (STATE/REQUIREMENTS updates by the orchestrator per the Phase 3 gate pattern)
</verification>

<success_criteria>
- All four roadmap criteria observed live: 8/4 grid + safe-area (1), ruler + magnifier/picker (2), artboard import (3), focus persistence + per-tool toggles (4)
- Docs truthful (grep-proven), pin proven, bundle green, assumptions dispositioned
- REQ-roadmap-phase4-design-tools ready to close
</success_criteria>

## Artifacts this phase produces

**Plan 04-04 symbols:** none (documentation + gates only). Docs sections updated: system-architecture.md "Design Tools" section, codebase-summary.md file map (11 new files + 1 deletion recorded), code-standards.md async-exemption wording (names CaptureService + PixelSamplerService as the bridge-pattern instances). Gate records: full-bundle output, Package.resolved sha256 pair, six-group smoke record with nine plan-flag + A2/A3 assumption dispositions in the SUMMARY.

<output>
Create `.planning/phases/04-design-tools/04-04-phase-gate-closure-SUMMARY.md` when done
</output>
