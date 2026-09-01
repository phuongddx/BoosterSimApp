---
phase: 07-polish-distribution
plan: "05"
subsystem: ui
tags: [swiftui, actions-tab, appactioncatalog, phase6-wiring, sidepanel, simulator]

# Dependency graph
requires:
  - phase: 06-platform-system (pre-.planning)
    provides: StatusBarSectionView, BuildStatsSectionView, AXTreeView, CameraView + their services (already constructed/injected end-to-end)
  - phase: 03-app-actions
    provides: AppActionSection/AppActionCatalog searchable-section pattern (Convention A) and AppActionCatalogTests contract suite
provides:
  - All four Phase 6 views reachable from the running app's side panel (Actions tab catalog mount) — ROADMAP C5 / Phase 7 criterion 5
  - 13-section Actions catalog (enum + entries + mount table in lockstep), fully searchable
  - CameraView support probing (onAppear + onChange of pid) — the "Requires Xcode 14+" stale-state trap closed
  - pid threading SideWindowView → ActionsTabView for AXTreeView/CameraView
affects: [07-06-phase-gate-closure, verify-work, docs/system-architecture.md tab map]

# Actuals (#2632) — pairs with the plan's estimate (20000 tokens) to calibrate future estimates.
# Same estimateTokens scale (chars/4 over the realized diff), never a harness token count.
actuals:
  tokens: 2110    # 8443 diff chars / 4 over the 5 files actually changed (plan estimated 20000 — mechanical wiring was cheaper than the estimate's confidence:low assumed)
  tasks: 2
  commits: 2

# Tech tracking
tech-stack:
  added: []     # none — wiring only, per plan
  patterns:
    - "Phase 6 flat-section views mount bare into ActionsTabView.sectionView (EnvironmentOverridesView precedent) — enum case, catalog entry, mount case in lockstep"
    - "View-owned lifecycle probing: CameraView owns probeSupport via onAppear + onChange(of: pid) with a one-owner NOTE (EnvironmentOverridesView's loadCurrentState convention)"

key-files:
  created: []   # no new files — wiring + test-contract updates only, per plan
  modified:
    - BoosterSimApp/Models/AppAction.swift
    - BoosterSimApp/Views/SideWindow/tabs/ActionsTabView.swift
    - BoosterSimApp/Views/SideWindow/SideWindowView.swift
    - BoosterSimApp/Views/SideWindow/CameraView.swift
    - BoosterSimAppTests/AppActionCatalogTests.swift

key-decisions:
  - "statusBar sits immediately after environment (visual-state overrides adjacent); camera/axTree/buildStats sit between defaults and reset (inspection/info before the destructive terminal section) — all nine existing sections keep relative order, so the stable-order tests needed only count/list updates"
  - "Signature mismatch handled at the mount: StatusBarSectionView takes udid (like every Actions section); AXTreeView/CameraView take pid via a new ActionsTabView parameter fed by SideWindowView's activeSim?.pid — no view signatures changed, udid never passed where pid is required"
  - "probeSupport has exactly one owner — CameraView itself (onAppear + onChange of pid), documented with a NOTE comment; AXTreeView keeps manual-refresh load BY DESIGN (no auto-load added), BuildStats/StatusBar need no lifecycle additions (service polling / tap-driven verbs)"
  - "Catalog ids follow the house lowercase-hyphen style: status-bar, camera-routing, ax-tree, build-stats"

patterns-established:
  - "Catalog lockstep rule: a new Actions-tab section requires three coordinated edits (AppActionSection case, AppActionCatalog.all entry with keywords + effectLatency, sectionView mount case) — the section-coverage test fails until all three land"

requirements-completed: []  # REQ-roadmap-phase7-polish-distribution stays open — phase umbrella; 07-01 notarization still human-gated, 07-02/07-06 pending (07-03 precedent)

# Coverage metadata (#1602)
coverage:
  - id: D1
    description: "Status Bar Override reachable + searchable from the Actions tab (enum case, catalog entry, bare udid mount)"
    requirement: REQ-roadmap-phase7-polish-distribution
    verification:
      - kind: unit
        ref: "BoosterSimAppTests/AppActionCatalogTests.swift#catalogCoversEveryTabSection (statusBar in pinned list)"
        status: pass
      - kind: unit
        ref: "BoosterSimAppTests/AppActionCatalogTests.swift#statusBarKeywordHitsTheNewSection (battery query)"
        status: pass
      - kind: other
        ref: "grep: 'case statusBar' AppAction.swift + 'StatusBarSectionView(udid: udid)' ActionsTabView.swift"
        status: pass
    human_judgment: false
  - id: D2
    description: "BuildStatsSectionView, AXTreeView, CameraView mounted in the Actions catalog with pid threaded from SideWindowView (13 sections, all searchable; SideTab still exactly 4 cases)"
    requirement: REQ-roadmap-phase7-polish-distribution
    verification:
      - kind: unit
        ref: "BoosterSimAppTests/AppActionCatalogTests.swift#catalogCoversEveryTabSection (13-section pinned list) + cameraKeywordHitsTheCameraSection"
        status: pass
      - kind: other
        ref: "grep: BuildStatsSectionView()/AXTreeView(pid: pid)/CameraView(pid: pid) in ActionsTabView + 'pid: activeSim?.pid' in SideWindowView + 'grep -c 'case [a-z]' SideTab.swift == 4'"
        status: pass
    human_judgment: false
  - id: D3
    description: "CameraView probes support on appear and on pid change (house onAppear/onChange convention, one-owner NOTE) — stale 'Requires Xcode 14+' trap closed"
    requirement: REQ-roadmap-phase7-polish-distribution
    verification:
      - kind: other
        ref: "grep: probeSupport(pid: at CameraView.swift onAppear + onChange(of: pid) — matches EnvironmentOverridesView.swift:65-70 convention"
        status: pass
    human_judgment: false
  - id: D4
    description: "The four Phase 6 sections render and behave correctly in the running app against a live Simulator (visual reachability of ROADMAP C5)"
    requirement: REQ-roadmap-phase7-polish-distribution
    verification: []
    human_judgment: true
    rationale: "Wiring/mount/search are grep- and unit-proven (D1–D3), but 'user can reach and use' the sections against a booted Simulator is a visual/live-behavior claim — deferred to the 07-06 phase-gate smoke per the plan's no-human-gate-for-mechanical-wiring stance."

# Metrics
duration: 8min
completed: 2026-09-01
status: complete
---

# Phase 7 Plan 05: Phase 6 View Wiring Summary

**All four orphaned Phase 6 views (StatusBar, BuildStats, AXTree, Camera) mounted end-to-end into the Actions tab's 13-section searchable catalog — pid threaded from the tracked Simulator window, CameraView's probeSupport gap closed, SideTab untouched at 4 cases**

## Performance

- **Duration:** 8 min
- **Started:** 2026-09-01T04:53:50Z
- **Completed:** 2026-09-01T05:01:30Z
- **Tasks:** 2/2
- **Files modified:** 5

## Accomplishments
- StatusBarSectionView reachable from the Actions tab (tracer slice): `AppActionSection.statusBar` + "Status Bar Override" catalog entry + bare `StatusBarSectionView(udid: udid)` mount — exactly the EnvironmentOverridesView precedent
- BuildStatsSectionView, AXTreeView, CameraView mounted the same way with three new enum cases and catalog entries between `defaults` and `reset`; the catalog is now 18 actions / 13 sections, all searchable
- pid threading: `ActionsTabView` gained `let pid: pid_t?`, fed by `SideWindowView`'s `activeSim?.pid` (SimulatorWindow.pid from kCGWindowOwnerPID) — udid remains the argument for every existing section
- CameraView now probes support on onAppear + onChange of pid (the only `probeSupport` call site in the repo, with a one-owner NOTE) — without it the section rendered "Requires Xcode 14+" forever
- Test contract updated to the 13-section reality + two keyword filter tests (battery → statusBar, camera → camera); full unit bundle 266/266 green

## Task Commits

Each task was committed atomically:

1. **Task 1: Tracer — StatusBarSectionView mounted end-to-end** - `4990984` (feat)
2. **Task 2: Mount BuildStats + AXTree + Camera — pid threading + probeSupport** - `74149dd` (feat)

**Plan metadata:** (see final docs commit below)

## Files Created/Modified
- `BoosterSimApp/Models/AppAction.swift` — AppActionSection grows statusBar + camera/axTree/buildStats (9 → 13 cases); four new catalog entries in matching section positions
- `BoosterSimApp/Views/SideWindow/tabs/ActionsTabView.swift` — `pid: pid_t?` parameter; four bare mounts in the sectionView table (statusBar/camera/axTree/buildStats)
- `BoosterSimApp/Views/SideWindow/SideWindowView.swift` — .actions case passes `pid: activeSim?.pid` into ActionsTabView
- `BoosterSimApp/Views/SideWindow/CameraView.swift` — body gains onAppear/onChange probeSupport with one-owner NOTE (only edit to a Phase 6 view)
- `BoosterSimAppTests/AppActionCatalogTests.swift` — expectedSections pinned to 13; statusBar + camera keyword tests

## Decisions Made
- Mount order: statusBar after environment; camera/axTree/buildStats between defaults and reset — keeps every pre-existing section's relative order intact (stable-order tests untouched beyond the list itself)
- Tracer gate resolved per `human_verify_mode: end-of-phase` + automated-only verify: verify re-run end-to-end after the tracer commit (TEST SUCCEEDED) before expansion — no human stop, matching the plan's `autonomous: true`
- REQ-fr-13 guarded by running the plan's `grep -c 'case [a-z]' SideTab.swift == 4` gate in BOTH task verifies — SideTab was never opened

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Plan verify greps are BSD-grep-shaped; this harness ships pi-uu-grep**
- **Found during:** Task 1 verify
- **Issue:** `/usr/bin/grep` here is `pi-uu-grep 0.2.0` (Rust regex). The plan's literal patterns containing `(`/`)` and `?` (e.g. `StatusBarSectionView(udid: udid)`, `pid: activeSim?.pid`) are regex metacharacters under that engine — parens become groups, `?` a quantifier — so the greps fail (or would error on the unbalanced `probeSupport(pid:`) even though the target strings exist
- **Fix:** Ran those patterns with `grep -F` (fixed-string) — byte-identical literal-substring semantics to BSD `grep -q`. Patterns without metacharacters (`case statusBar` etc.) ran verbatim. No source changes
- **Files modified:** none (verification-tooling adaptation only)
- **Verification:** both task verifies + the end-state orphan grep all pass; TEST SUCCEEDED both times
- **Committed in:** n/a

**2. [Documentation note] Plan's read_first names "ActionsTabView.swift #Preview" as a second construction site — no #Preview exists**
- **Found during:** Task 2 read_first
- **Issue:** ActionsTabView.swift has no `#Preview` block (repo-grepped: the only construction site of `ActionsTabView(` anywhere is SideWindowView.swift:70)
- **Fix:** The one real construction site gained `pid:` — the plan's intent ("every construction site updated") is fully satisfied; nothing else to update
- **Files modified:** none beyond the planned SideWindowView edit
- **Verification:** grep `ActionsTabView\(` → single hit, updated
- **Committed in:** `74149dd`

---

**Total deviations:** 2 (1 Rule-3 tooling adaptation, 1 plan-vs-tree documentation note — zero code-scope deviations)
**Impact on plan:** None on delivered behavior — both are verification/context corrections; the code changes match the plan exactly.

## Issues Encountered
- One edit-anchoring slip during Task 1 (a catalog insert briefly landed inside the preceding entry's continuation lines due to post-edit renumbering) — caught immediately by the edit response, repaired before any build/commit; the committed tree is correct (Task 1 verify + tests green)

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- ROADMAP C5 / Phase 7 criterion 5 is code-true: all four Phase 6 sections reachable from the Actions tab, searchable, REQ-fr-13 unregressed (4 tabs), camera support detection live
- Remaining Phase 7: 07-01 notarization human gate, 07-02 Sparkle (Wave 2), 07-06 phase-gate closure — 07-06's smoke should exercise the four new sections on a live Simulator (D4 above)
- Zero orphaned Phase 6 views remain: each of the four has exactly one real call site (ActionsTabView mount table) beyond its own #Preview

## Self-Check: PASSED

All 5 modified files + SUMMARY exist on disk; both task commits (4990984, 74149dd) found in git log; orphan-check grep confirms one real call site per Phase 6 view beyond #Preview; SideTab 4-case gate green in both task verifies; unit bundle 266/266.

---
*Phase: 07-polish-distribution*
*Completed: 2026-09-01*
