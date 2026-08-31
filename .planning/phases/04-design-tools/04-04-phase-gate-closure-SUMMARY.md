---
phase: 04-design-tools
plan: 04
subsystem: ui
tags: [documentation, phase-gate, xcodebuild, sha256-pin, blocking-smoke, overlay, design-tools]

requires:
  - phase: 04-design-tools
    provides: the full as-shipped overlay toolset (04-01 grid spine, 04-02 safe-area + import, 04-03 ruler + magnifier) this gate documents and proves
  - phase: 03-app-actions
    provides: the phase-gate closure pattern (docs truth pass → full bundle + sha256 pin → blocking-human smoke; requirements stay open at halt)
provides:
  - Truthful docs — system-architecture.md § Design Tools, codebase-summary.md file map + primary-types table, code-standards.md bridge-pattern exemption (symbol-grepped against source)
  - Automated gate record — 229/229 unit bundle, Debug build, Package.resolved sha256 pin proven identical across the gate
  - The six-group blocking smoke structure with nine plan-flagged + two research-log (A2/A3) assumption dispositions — awaiting user execution
affects: [phase-5-planning (docs onboarding), 04-verify (smoke record feeds REQ close on approval)]

actuals:
  tokens: 9250   # chars/4 over the realized docs diff (161 insertions + 17 deletions, 4 files); gate runs add no diff
  tasks: 1       # Task 1 complete + committed; Task 2 automated portion green, human gate PENDING (see status)
  commits: 2     # d7ba011 (docs truth pass) + this metadata commit

tech-stack:
  added: []   # documentation + gates only — zero packages, zero source changes
  patterns:
    - "Symbol grep truth gate: every documented symbol must appear in BOTH architecture and summary docs (grep -l | wc -l == 2) — the proven 03-05 shape, third use"
    - "Dependency pin by sha256 content-stability (file untracked → git diff vacuous): 70386616a707… identical before/after the bundle run — the 02-04 standard, third use"

key-files:
  created:
    - .planning/phases/04-design-tools/04-04-phase-gate-closure-SUMMARY.md
  modified:
    - docs/system-architecture.md
    - docs/codebase-summary.md
    - docs/code-standards.md
    - .planning/codebase/CONVENTIONS.md

key-decisions:
  - "Async exemption documented as the bridge PATTERN (sync public API → single private Task bridge → TCC preflight) naming both instances — CaptureService (Phase 2) and PixelSamplerService (Phase 4) — not a single-type accident (RESEARCH Pitfall 6 instruction)"
  - "iOS runtime gap surfaced, not auto-fixed: no iOS simulator runtime is installed on this host (only watchOS 26.2; iOS 26.3/26.5 show Unavailable) — re-downloading multi-GB platform images is user-machine state; the blocking checkpoint carries the install/boot instruction instead"
  - "Status halted at the blocking-human gate: REQ-roadmap-phase4-design-tools stays open at halt and closes only on user approval (the Phase 3 gate pattern)"

patterns-established:
  - "Phase-gate closure pattern, third use: docs truth pass (symbol grep) → full unit bundle + Debug build + sha256 pin → blocking-human six-group smoke → close on approval only"

requirements-completed: []   # REQ-roadmap-phase4-design-tools intentionally OPEN at halt — closes on smoke approval (shared-ID gate #2388, Phase 3 pattern)

coverage:
  - id: D1
    description: "Docs truth pass: § Design Tools architecture section (D-04 layer table, service split, cached-capture sampling, capture-mode input, permission degradation, versioned persistence keys), file-map refresh with wc -l-verified LOC for all 22 Phase 4 files, async-exemption wording naming both bridge instances"
    requirement: REQ-roadmap-phase4-design-tools
    verification:
      - kind: other
        ref: "symbol grep loop: 11/11 symbols (DesignOverlayService/Panel/Controller, PixelSamplerService, SafeAreaCatalog, OverlayGeometry, 5 overlay views, DesignOverlayPresets) each present in BOTH docs — zero MISSING"
        status: pass
      - kind: other
        ref: "LOC audit: 24 claimed figures vs wc -l — zero mismatches; design-placeholder grep clean"
        status: pass
    human_judgment: false
  - id: D2
    description: "Automated phase gate: full BoosterSimAppTests bundle + Debug build + dependency pin"
    requirement: REQ-roadmap-phase4-design-tools
    verification:
      - kind: unit
        ref: "xcodebuild test -only-testing:BoosterSimAppTests -skip-testing:BoosterSimAppUITests -parallel-testing-enabled NO — 229 tests / 24 suites, TEST SUCCEEDED, exit 0"
        status: pass
      - kind: other
        ref: "xcodebuild Debug build — BUILD SUCCEEDED, exit 0; Package.resolved sha256 70386616a70796c3cfeea9cc621708cc294eac4c6825bfe400d52e4234cf8852 identical before/after (git diff vacuous — file untracked)"
        status: pass
    human_judgment: false
  - id: D3
    description: "Blocking human smoke over a booted Simulator: six groups (grid, safe-area, ruler, magnifier/picker, comparison import, focus+degradation) with nine plan-flagged assumption dispositions + research-log A2/A3 surfaced to the user — the phase's actual acceptance test"
    requirement: REQ-roadmap-phase4-design-tools
    verification: []
    human_judgment: true
    rationale: "NSPanel compositing over a foreign window, TCC-gated sampling, focus retention, and artboard alignment are manual-only rows in 04-VALIDATION — no automated suite can observe them. The transparency prohibition (must_haves) forbids closing on suite-green alone."

duration: 12min   # to halt; smoke + close-out continue after user response
completed: 2026-08-31
status: halted    # designed stop at the blocking-human gate — flips to complete on smoke approval
---

# Phase 4 Plan 04: Phase Gate Closure Summary

**Docs made to tell the as-shipped Design Tools truth (symbol-grepped, LOC-audited), automated gate fully green — 229/229 unit bundle, Debug build, Package.resolved sha256 pin proven — and the plan halted exactly where designed: the blocking-human six-group smoke over a booted Simulator**

**STATUS: AWAITING USER SMOKE — see "Blocking Smoke Record (PENDING)" below. REQ-roadmap-phase4-design-tools stays open until approval.**

## Performance

- **Duration:** 12 min to halt (started 2026-08-31T14:49:56Z; halted 2026-08-31T15:02:00Z approx)
- **Tasks:** 1 of 2 complete (Task 2's automated portion green; human gate pending)
- **Files modified:** 4 (three docs + CONVENTIONS.md) + this SUMMARY

## Accomplishments

- Task 1 docs truth pass landed (`d7ba011`): system-architecture.md gained the full **§ Design Tools** section — D-04 layer table (comparison < interactive < safeArea < grid), service split (DesignOverlayService + extensions, SafeAreaCatalog, OverlayGeometry, PixelSamplerService), cached-capture sampling, capture-mode input (setCaptureMode, hitTest routing, Esc + hover monitor lifecycle), permission degradation, and the versioned `DesignOverlay*` persistence keys incl. the one-shot legacy import — plus the layer-diagram block, Windows/Views entries, and DesignTabView placeholder line corrected
- codebase-summary.md refreshed: all 22 Phase 4 files with wc -l LOC (audited — zero mismatches), the deleted DesignComparisonService scaffold recorded, Design tab status "Placeholder" → "Complete (Phase 4)", and a primary-types table + 40-test suite map
- code-standards.md async exemption now names the sanctioned **bridge pattern with both instances** (CaptureService + PixelSamplerService); versioned-key + one-shot-import persistence convention added
- Task 2 automated gate green: **229/229 tests in 24 suites (TEST SUCCEEDED)**, **Debug build (BUILD SUCCEEDED)**, and the dependency pin proven by content stability — sha256 `70386616a707…` identical before/after (identical to the Phase 5 and Phase 2 pins; git diff vacuous because the file is untracked)

## Automated Gate Record (Task 2, automated portion)

| Gate | Result | Evidence |
|---|---|---|
| Full unit bundle | ✅ PASS | `xcodebuild … test -only-testing:BoosterSimAppTests -skip-testing:BoosterSimAppUITests -parallel-testing-enabled NO` → "Test run with **229 tests in 24 suites passed**", `** TEST SUCCEEDED **`, exit 0 |
| Debug build | ✅ PASS | `xcodebuild … -configuration Debug build` → `** BUILD SUCCEEDED **`, exit 0 |
| SPM pin (git) | ✅ clean | `git diff --exit-code` on Package.resolved — no output (file untracked; the diff is vacuous by design) |
| SPM pin (content) | ✅ IDENTICAL | sha256 before = `70386616a70796c3cfeea9cc621708cc294eac4c6825bfe400d52e4234cf8852`, sha256 after = same — zero external packages added this phase; no drift to investigate |

## Blocking Smoke Record (PENDING — the checkpoint)

Returned to the orchestrator as `checkpoint:human-verify gate="blocking-human"`. Outcome table to be filled by the continuation agent from the user's reply; each row records pass / known-gap-with-escape-hatch / fail.

| Group | Roadmap criterion | Smoke observation (user) | Result |
|---|---|---|---|
| 1. Grid | dual 8/4 grid + tracking + persistence (crit 1) | 8pt emphasized over 4pt minors, device-aligned; follows move+resize; toggle survives relaunch; preset list stable across two relaunches | PENDING |
| 2. Safe area | bands + manual override + reset + landscape (crit 1) | bands at real insets; manual fields move; Reset restores; landscape re-resolves (sides inset, top clear) | PENDING |
| 3. Ruler | device-point readout + Esc + focus (crit 2) | drag across top inset ≈ device top inset; Esc cancels; Simulator title bar NOT grey while armed | PENDING |
| 4. Magnifier/picker | loupe + hex + commit + copy (crit 2) | known color → expected hex within rounding; click commits; Copy pastes the string; stepper changes zoom | PENDING |
| 5. Comparison import | open/drag/paste + opacity + guides above (crit 3, D-04) | imports via Open AND drag; opacity reveals; grid+safe-area+image on → guides ABOVE image; oversized image → rejection caption | PENDING |
| 6. Focus + degrade | focus persistence + per-tool toggles (crit 4) | overlays survive BoosterSimApp focus loss; Simulator shutdown hides overlays, no crash; re-boot restores | PENDING |

### Flagged-assumption dispositions (PENDING — nine plan flags + A2/A3)

| # | Assumption (source plan) | Disposition at gate |
|---|---|---|
| 1 | Legacy-import idempotency on a real upgraded defaults store (04-01) | PENDING — relaunch-twice probe in group 1 |
| 2 | Mid-render/mid-import concurrency: move/resize/relaunch during active overlays (04-01) | PENDING — exercised across groups 1, 2, 6 |
| 3 | A4 bezel/title-bar: content rect assumes bezels OFF; calibration is the bezel-on escape hatch (04-01) | PENDING — group 2 calibration fields |
| 4 | A1 legacy inset rows (44/48/20 families, iPad 20/20) and their landscape shapes (04-02) | PENDING — group 2 if such a device is booted; manual override covers |
| 5 | A6 file/drag/paste = "import a Figma/Sketch artboard" reading (04-02) | PENDING — group 5 confirms the reading; user accepts or names an expected native-format flow |
| 6 | Import idempotency live (re-import replaces, never duplicates) (04-02) | PENDING — group 5 drag-replaces step |
| 7 | A5 cached-capture freshness: stale pixels until resize/re-arm (04-03) | PENDING — group 4 loupe step |
| 8 | Arm/disarm concurrency: single-tool rule holds live (04-03) | PENDING — groups 3/4 arm-switch |
| 9 | Capture-mode focus: Simulator keeps focus; Esc while SIMULATOR focused (local-monitor choice) (04-03) | PENDING — group 3 |
| A2 | RESEARCH-log: D-02's "96pt family" wording has NO real iPhone referent — real shipped tops are {20, 44, 47, 48, 50, 54, 59, 62}; manual override is the escape hatch | SURFACED — user accepts the real row set or names the intended device (e.g. a windowed iPad) for a fix-up row |
| A3 | RESEARCH-log: 17-series/Air rows ride the 59-family default until verified | SURFACED — opportunistic check if such a device is booted; otherwise manual-override-covered, stated as such |

### Environment note (blocks the smoke until resolved)

**No iOS simulator runtime is installed on this host.** `xcrun simctl list runtimes` shows only watchOS 26.2; the iOS 26.3/26.5 runtimes appear as *Unavailable* (device data exists, runtime binaries gone — iOS 26.3 worked during the Phase 3 smoke on 2026-08-31, so this is a recent change, possibly a deliberate disk-space cleanup). Fix (user's call — it is a multi-GB download): Xcode → Settings → Platforms → install an iOS runtime, or `xcodebuild -downloadPlatform iOS`, then boot a 12–16-series iPhone. BoosterSimApp (fresh Debug build) is already running and will auto-attach when a Simulator window appears. An exported artboard PNG (Figma/Sketch, 1x) is also needed for group 5.

## Task Commits

1. **Task 1: docs truth pass** — `d7ba011` (docs — symbol grep 11/11, LOC audit zero mismatches)
2. **Task 2 automated portion** — no source changes; gate outputs recorded above and in this SUMMARY (this metadata commit)
3. **Task 2 human gate** — PENDING user smoke

**Plan metadata:** this commit (docs: phase-gate closure at halt).

## Files Created/Modified

- `docs/system-architecture.md` — § Design Tools section, layer-diagram Design Overlay block, Windows entries (DesignOverlayPanel/Controller), design side-panel components, DesignTabView placeholder line fixed, concurrency exception names both bridge sites, two Key Design Decisions rows
- `docs/codebase-summary.md` — header stats (173 files / ~21,005 LOC), 22 Phase 4 files with wc -l LOC, deleted scaffold recorded, Design tab Complete (Phase 4), primary-types table, 40-test suite map
- `docs/code-standards.md` — async exemption = bridge pattern (CaptureService + PixelSamplerService); versioned-key one-shot-import persistence convention
- `.planning/codebase/CONVENTIONS.md` — stale "CaptureService alone" exception line names the pattern (deviation 1)

## Decisions Made

- Async exemption documented as the **pattern**, not a type list — Pitfall 6's instruction; both instantiation sites named in all three places (code-standards, CONVENTIONS, system-architecture)
- No iOS runtime auto-download: multi-GB platform installs are user-machine state (the previous runtime's removal may be deliberate); surfaced in the checkpoint instead — golden-rule automation stops at changing what the user may have intentionally changed
- Requirements stay open at halt; REQUIREMENTS.md untouched; ROADMAP progress row updated mechanically (4/4 plans executed, phase status still In Progress — closure is orchestrator's, on approval)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Truth] Stale CONVENTIONS.md exemption line**
- **Found during:** Task 1
- **Issue:** The plan's read_first locates the "CaptureService alone" async-exemption claim in docs/code-standards.md, but the stale single-type claim actually lives in `.planning/codebase/CONVENTIONS.md:8` (code-standards.md carried no exception wording at all — it had to be added)
- **Fix:** Updated both: added the bridge-pattern wording to docs/code-standards.md (per acceptance criteria) and corrected the one stale line in CONVENTIONS.md to name the pattern with both instances
- **Files modified:** docs/code-standards.md, .planning/codebase/CONVENTIONS.md
- **Verification:** grep — no "CaptureService alone"-style single-type claim remains in either file
- **Committed in:** d7ba011

**2. [Rule 1 - Truth] Stale CaptureTabView LOC + tree damage repaired mid-edit**
- **Found during:** Task 1
- **Issue:** codebase-summary.md's tree carried CaptureTabView at 23 LOC (actual 201 — pre-existing staleness from before the Phase 2 split); two edit-anchor slips (duplicate DesignTabView line, mangled Utilities block) briefly damaged the tree
- **Fix:** LOC corrected to 201; duplicates/damage repaired before commit (verified by re-read)
- **Files modified:** docs/codebase-summary.md
- **Verification:** final LOC audit zero mismatches; tree structure re-read clean
- **Committed in:** d7ba011

---

**Total deviations:** 2 auto-fixed (2 truth fixes)
**Impact on plan:** None — both extend the truth pass's own goal (docs matching reality); no scope creep.

## Issues Encountered

- **iOS simulator runtime absent** (see Environment note) — blocks the human smoke until the user installs one; automated gates unaffected. Not auto-fixed deliberately (multi-GB download, possibly-intentional removal).
- Task 1's `<verify>` grep initially flagged `DesignOverlayPresets` missing from codebase-summary.md — fixed by naming the key explicitly in the primary-types table; re-run: 11/11 present in both docs.

## Known Stubs

None — no stubs introduced. (04-01's `pickedColor` producer gap was closed by 04-03; no placeholders remain in the Design path.)

## User Setup Required

Before the smoke (carried in the checkpoint): (1) an iOS simulator runtime installed + one 12–16-series iPhone booted with visible app content of known colors; (2) any Figma/Sketch artboard exported as PNG (1x) findable. Screen Recording permission is already onboarded. BoosterSimApp (fresh Debug build) is running.

## Next Phase Readiness

- On "approved": continuation agent records the six-group outcomes + 11 dispositions in this SUMMARY (flips `status: halted` → `complete`), REQ-roadmap-phase4-design-tools closes, STATE/ROADMAP phase close-out runs (Phase 3 gate pattern)
- On a named failing group: fix lands inside Phase 4 before closure (a false success caption, a silently-dropped preset, or a D-04 ordering violation requires in-phase fix per the resume-signal)
- Docs are ready for Phase 7 planning onboarding: § Design Tools is the canonical map of the overlay layer

---
*Phase: 04-design-tools*
*Halted at blocking-human smoke gate: 2026-08-31*

## Self-Check: PASSED

Commit d7ba011 present in git log; all four modified docs exist on disk; symbol grep 11/11 in both docs; LOC audit zero mismatches; 229/229 bundle + BUILD SUCCEEDED + sha256 pair identical (outputs above). Smoke groups + dispositions recorded PENDING; REQUIREMENTS.md untouched.
