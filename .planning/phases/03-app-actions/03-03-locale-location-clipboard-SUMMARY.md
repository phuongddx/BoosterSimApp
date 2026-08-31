---
phase: 03-app-actions
plan: 03
subsystem: app-actions
tags: [simctl, locale, timezone, location, clipboard, pbsync, combine, swiftui]

# Dependency graph
requires:
  - phase: 03-app-actions (plan 02)
    provides: hardened SimCtlService seam (stdin, serial queue), AppActionService facade + runVerb helper + extend-the-seam recipe, AppPickerBar, ActionsTabView shell, AppLogger.actions
provides:
  - Locale/timezone verbs on the facade — applyLocale (languages -array + locale -string + optional tz write → single relaunch hop), setTimezone, readLocaleState (three typed global-domain reads with pure parsers)
  - Pure locale builders — languageArgs/localeArgs/timezoneArgs/deleteKeyArgs/readKeyArgs/relaunchArgs (--terminate-running-process)/fallbackRelaunchArgs (two-step)/localePresetChain, all against the single `.GlobalPreferences` constant
  - LocalePreset model — en-US/en-GB/vi-VN/ja-JP (languages, locale, optional timezone) triples
  - Location simulation — pure coordinate gate (typed CoordinateError, no argv on invalid), setLocation/clearLocation/applyLocationPreset (location set + Task-1 tz write + relaunch), hasSimulatedLocation state-driven Stop flag, CityPreset six-city triples
  - Clipboard sync — ClipboardDirection + pbsyncCommand exact two argv forms, syncClipboard with direction-status captions (manual only, content never logged)
  - LocaleSectionView, LocationSectionView, ClipboardSectionView mounted below the untouched EnvironmentOverridesView
  - Wave 0 suite: LocaleCommandTests (21 tests — locale/timezone/relaunch + location/clipboard builders)
affects: [03-04 defaults editor + action search, 03-05 docs + phase gate]

actuals:
  tokens: 16518   # chars/4 over the realized diff (66,074 chars) — vs. 38,000 estimate (confidence was low)
  tasks: 2        # of 3 — Task 3 is the blocking-human smoke, halted pending user verification
  commits: 4      # TDD pairs, excluding the docs commit

tech-stack:
  added: []       # Apple frameworks only (REQ-nfr-03)
  patterns:
    - "Result-typed argv gate for free-text inputs: validation builds NO args, typed error cases surface inline before any subprocess (T-03-13 shape)"
    - "One-relaunch multi-write chain: every relaunch-domain key rides a single launch --terminate-running-process hop at chain end"
    - "State-driven Stop flag (hasSimulatedLocation) published by set/preset and cleared by clear — Stop visibility is never guesswork (Pitfall 10)"

key-files:
  created:
    - BoosterSimApp/Views/SideWindow/actions/LocaleSectionView.swift
    - BoosterSimApp/Views/SideWindow/actions/LocationSectionView.swift
    - BoosterSimApp/Views/SideWindow/actions/ClipboardSectionView.swift
    - BoosterSimAppTests/LocaleCommandTests.swift
  modified:
    - BoosterSimApp/Services/AppActionService.swift
    - BoosterSimApp/Views/SideWindow/tabs/ActionsTabView.swift

key-decisions:
  - "Global-domain token pinned as `.GlobalPreferences` (single named constant) — live read-verified on the booted iPhone 17/iOS 26.3 this session; the EnvironmentOverrideService precedent spelling. Not forked; if the smoke misbehaves the documented equivalent spelling is the fallback swap in ONE constant"
  - "applyLocale carries an optional trailing `timezone` parameter so a locale preset applies languages + locale + timezone with ONE relaunch hop (truth 1's 'one chain'); the plan's literal applyLocale(languages:locale:udid:bundle:) signature survives via the default argument, and setTimezone stays the standalone path"
  - "Location/clipboard/locale verbs publish dedicated captions (localeCaption/locationCaption/clipboardCaption) + hasSimulatedLocation instead of riding the 03-01-pinned AppActionOperation machine — the 03-02 single-hop precedent; the machine and its transition tests are untouched"
  - "Preset models + builders co-locate in AppActionService.swift because AppActionModels.swift is outside this plan's files list (commit-only-named-files rule); file at 906 LOC, flagged for the plan-05 review gate"
  - "City preset chain reuses Task-1's timezoneArgs verbatim (grep-able acceptance criterion) and the relaunch hop rides only when a bundle is active — the relaunch is 'optional-but-captioned' per the plan"

patterns-established:
  - "Validated-input section anatomy: TextField row + computed pure-validator Result + inline typed error + disabled action — rejection before any verb, reused verbatim between view and service gate"

requirements-completed: []   # REQ-roadmap-phase3-app-actions / REQ-fr-14 close only after the Task-3 blocking smoke passes (halted now); REQ-fr-13 already Complete in REQUIREMENTS.md from Phase 1

coverage:
  - id: D1
    description: "Locale/timezone contracts — global-domain argv forms (-array/-string/delete/read), one-call relaunch + two-step fallback, preset triples, parser round-trips, read argv"
    requirement: REQ-roadmap-phase3-app-actions
    verification:
      - kind: unit
        ref: BoosterSimAppTests/LocaleCommandTests (11 tests, locale groups)
        status: pass
    human_judgment: false
  - id: D2
    description: "Location + clipboard contracts — coordinate gate (valid/empty/non-numeric/out-of-range/boundary), clear argv, six city triples composing location+timezone+relaunch, both pbsync directions, service fail-fast without simulating"
    requirement: REQ-roadmap-phase3-app-actions
    verification:
      - kind: unit
        ref: BoosterSimAppTests/LocaleCommandTests (10 tests, location/clipboard groups)
        status: pass
    human_judgment: false
  - id: D3
    description: "Live criterion-3 proof + plan-02 re-verification — guided grant (D-01), push banner tap-through, payload gate live, privacy + deep link, locale relaunch + localization (A1), Maps movement (A2), clipboard round-trip, dark/Dynamic Type reuse regression, idempotency + degraded states"
    requirement: REQ-roadmap-phase3-app-actions
    verification: []
    human_judgment: true
    rationale: "Device-state behaviors (banner delivery, TCC, CoreLocation consumers, pasteboards, relaunch localization) are impossible to exercise headless; Task 3 is the plan's blocking-human smoke"

# Metrics
duration: 38min
completed: 2026-08-31
status: halted
---

# Phase 3 Plan 03: Locale / Location / Clipboard Summary

**Criterion 3's action surface shipped and unit-pinned — locale/timezone writes on the single `.GlobalPreferences` domain with one relaunch hop, validated location simulation with tz-syncing city presets and a state-driven Stop, and manual bidirectional pbsync — halted at the Task-3 blocking-human smoke (9 steps) pending user verification.**

## Performance

- **Duration:** 38 min (04:28–05:06 UTC, automation portion)
- **Started:** 2026-08-31T04:28:06Z
- **Completed:** automation complete 2026-08-31T05:06Z; **Task 3 smoke PENDING**
- **Tasks:** 2 of 3 complete (Task 3 = `checkpoint:human-verify gate="blocking-human"`)
- **Files modified:** 6 (4 created, 2 modified)

## Accomplishments
- Locale switching with honest semantics: AppleLanguages `-array` + AppleLocale `-string` (+ optional AppleTimeZone) written to the device's global defaults domain, then ONE `launch --terminate-running-process` relaunch hop — the write chain never presents as instant (Pitfall 6 caption adjacent to every apply control), and the two-step terminate-then-launch fallback is unit-tested for A1
- Location simulation with the full safety contract: free-text coordinates pass a pure typed gate (numeric + |lat|≤90/|lon|≤180 — NO argv on invalid input), six city presets set coordinates AND write the matching timezone in one action, and `hasSimulatedLocation` drives an always-visible, prominence-when-active Clear (Pitfall 10)
- Clipboard sync is exactly two manual buttons (`pbsync host <udid>` / `pbsync <udid> host` — both research-verified round-trip), direction-status captions only, zero timers/polling, and clipboard content never read, stored, or logged (T-03-08)
- EnvironmentOverridesView reused untouched at the top of the tab (reuse contract); the three new sections mount below privacy; full unit bundle green with zero regressions (158 case-lines passed / 0 failed; baseline 138 after 03-02 + 21 new LocaleCommandTests)

## Task Commits

Each task was committed atomically (TDD pairs; RED commits fail compilation against the not-yet-existing builders by design — the 03-01/03-02 house pattern):

1. **Task 1 RED:** `5f68362` — test(03-03): locale/timezone command-builder tests
2. **Task 1 GREEN:** `884b832` — feat(03-03): locale/timezone switching with explicit relaunch
3. **Task 2 RED:** `f2a5904` — test(03-03): location + clipboard builder tests
4. **Task 2 GREEN:** `0559fef` — feat(03-03): location simulation with paired stop + bidirectional clipboard sync

**Task 3:** `checkpoint:human-verify gate="blocking-human"` — HALTED (never auto-approved; AUTO_MODE=false). See Checkpoint below.

**Plan metadata:** see docs commit below.

## Files Created/Modified
- `BoosterSimApp/Services/AppActionService.swift` — locale/timezone/location/clipboard verbs + published state + preset models + pure builders (906 LOC total; co-location forced by the plan's file list — flagged for plan-05 review)
- `BoosterSimApp/Views/SideWindow/actions/LocaleSectionView.swift` — preset pills + manual rows, current-state reload on appear/udid-change, relaunch caption adjacent to every apply control, device-wide scope caption
- `BoosterSimApp/Views/SideWindow/actions/LocationSectionView.swift` — validated lat/lon rows with inline typed errors before any verb, prominent Clear while active, city pills, relaunch + scope captions
- `BoosterSimApp/Views/SideWindow/actions/ClipboardSectionView.swift` — exactly two manual sync buttons, direction-status + text-clipboard + no-auto-sync captions
- `BoosterSimApp/Views/SideWindow/tabs/ActionsTabView.swift` — three sections mounted after privacy, below the untouched EnvironmentOverridesView
- `BoosterSimAppTests/LocaleCommandTests.swift` — 21 Wave 0 tests

## Decisions Made
- See key-decisions in frontmatter. The load-bearing ones: the `.GlobalPreferences` single-constant pin (live-verified), the optional-timezone parameter giving presets one relaunch hop, and dedicated captions instead of touching the 03-01-pinned operation machine.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] GitNexus MCP unavailable — impact analysis substituted**
- **Found during:** Task 1 read_first
- **Issue:** The plan/AGENTS.md `gitnexus_impact` pre-edit obligation could not run (no GitNexus MCP in this runtime)
- **Fix:** grep blast radius over the touched symbols: every AppActionService change is an additive extension member or new method (no existing symbol modified — d=1 callers unaffected); ActionsTabView change is three additive body lines; new views reference only new + existing public types. The AppActionOperation machine and its 03-01 transition tests are untouched by design
- **Files modified:** none (analysis only)
- **Verification:** full unit bundle + Debug build
- **Committed in:** n/a

**2. [Rule 1 - Bug] Test-file insert landed mid-function during Task 2 RED**
- **Found during:** Task 2 test authoring (edit-tool anchor off-by-one)
- **Issue:** The location/clipboard MARK groups were inserted inside `parsersRoundTripFixtureDefaultsReadOutput`; a later repair also ate the `latitudeEmpty` enum case
- **Fix:** re-read + two surgical edits restored the parser function tail and the case; structure verified via MARK/@Test listing before running RED
- **Files modified:** BoosterSimAppTests/LocaleCommandTests.swift, BoosterSimApp/Services/AppActionService.swift
- **Verification:** 21/21 LocaleCommandTests green
- **Committed in:** f2a5904 / 0559fef

**3. [Process] Verify-command flag substitution (orchestrator-proven hazard)**
- **Found during:** Task 1 verification
- **Issue:** The plan's literal `-parallel-testing-enabled NO` on plain `test` silently runs 0 tests on this Xcode (03-02 deviation 5)
- **Fix:** all gates ran with `-maximum-parallel-testing-workers 1`; Swift-Testing logs carry no XCTest `Executed N tests` line on this toolchain, so pass/fail case lines + `TEST SUCCEEDED` are the evidence (targeted 21/21 twice; full bundle 158 passed / 0 failed case-lines)
- **Files modified:** none
- **Verification:** /tmp/03-03-task1-green2.log, /tmp/03-03-task2-green3.log, /tmp/03-03-task2-build.log, /tmp/03-03-full.log
- **Committed in:** n/a

**4. [Design] AppActionService.swift at 906 LOC (house target <200)**
- The plan's files list pins every builder/model/verb to this one file (AppActionModels.swift is outside it). Cross-file splits would need either de-privatizing facade state or a second commit-rule exception. Precedent: CaptureService 312; 03-01 flagged 252. Flagged for the plan-05 phase-gate review.

**5. [Process] WINDOWS ledger not appended**
- `.planning/WINDOWS.md` is user-dirty and the orchestrator instructed it untouched. The pending smoke is tracked here (status: halted) + a STATE.md blocker + ROADMAP 03-03 left unchecked — the 03-01 halt-time precedent.

---

**Total deviations:** 5 (1 blocking-process substitution, 1 edit-boundary bug, 1 process substitution, 1 design note, 1 process note)
**Impact on plan:** All within the planned architecture; no scope creep. Deviations 2-3 guarded the plan's own verification honesty.

## Issues Encountered
- Two compile iterations in GREEN runs (missing `nonisolated` on extension statics inheriting @MainActor isolation; `CoordinateError` missing `Error` conformance for `Result`) — both caught by the failing test run and fixed immediately; no behavioral residue
- LSP standalone-parse diagnostics on the new view files were noise (types resolve inside the project); xcodebuild is ground truth

## User Setup Required

**Task 3 smoke prerequisites (from the plan's user_setup):**
1. One booted iOS Simulator with an app that (a) can receive push notifications with permission granted (e.g. the Xcode-built app after a manual Settings grant, or Apple Calendar if notification permission was ever granted), (b) localizes visibly when the language changes, and (c) reads location (Apple Maps works)
2. BoosterSimApp running with the side panel on the Actions tab against that Simulator

## Checkpoint (Task 3 — blocking-human smoke, PENDING)

**Type:** human-verify · **Gate:** blocking-human · **Status:** awaiting user verification

Nine steps to observe and record pass/fail (per-step record lands in this summary on resume):

1. **D-01 GUIDED GRANT** — Push section with permission DENIED: the control shows the honest cannot-set caption; click Open Settings → device Settings opens; navigate Notifications → \<app\> → Allow
2. Send Test Push (alert template) — the banner arrives and taps through to the app
3. Paste a >4096-byte payload — rejected inline with the size error, no send; a template payload sends again fine
4. PRIVACY + DEEP LINK — grant then revoke a service (e.g. photos) for the active app; terminate-warning caption visible; a preset deep link still opens in the Simulator
5. LOCALE — apply the Japanese preset on a localizable app → the app relaunches (A1) and localizes; apply the Tokyo city preset → timezone changes with it; restore the original locale preset afterward
6. LOCATION — set Tokyo coordinates manually → Maps/Weather reflect them (A2); Clear restores; the Clear control is visible the whole time a simulation is active
7. CLIPBOARD — copy text on the Mac → Mac → Simulator → paste into a device text field shows it; copy different text on the device → Simulator → Mac → paste on the Mac shows it
8. REUSE REGRESSION — toggle Dark Mode and change Dynamic Type in the existing Environment section — both apply instantly, no relaunch
9. IDEMPOTENCY + EMPTY INPUTS — re-apply the same locale preset (stable, no error); clear the lat/lon fields and click Set (typed inline error, nothing sent); with the Simulator shut down, all sections show degraded/disabled states, no crash

**Resume signal:** reply "approved" to unblock Wave 4 (plan 04), or describe the failing step. A failed relaunch requires switching to the unit-tested two-step fallback inside this plan; a fake-looking permission toggle or a missing Stop is a prohibition violation and blocks approval.

## Next Phase Readiness
- Plans 04-05 ride the seam additively; the defaults editor reuses the Task-1 spawn-defaults builders and the readKeyArgs/parser pattern
- **Blocker:** Task 3 blocking-human smoke pending (9 steps above) — Wave 4 dispatch waits on its approval per the phase's wave gate
- Flagged assumptions A1 (one-call relaunch) and A2 (Maps movement) close at smoke steps 5-6

## Self-Check: PASSED
- All 4 created files exist on disk; both modified files changed as listed (git show --stat per commit)
- Commits 5f68362, 884b832, f2a5904, 0559fef present on main; no deletions in any
- Targeted LocaleCommandTests 21/21 (twice); full unit bundle 158 passed / 0 failed case-lines, TEST SUCCEEDED, exit 0; Debug build exit 0; every Task 1/2 acceptance criterion grep-verified (relaunch-last chain, verb+outcome logging, caption adjacency, tokens-only, state-driven Stop, preset→timezoneArgs reference, two-button/zero-timer clipboard, env section first and untouched)

---
*Phase: 03-app-actions — Plan: 03 (locale / location / clipboard)*
*Status: halted — Task 3 blocking-human smoke pending*
