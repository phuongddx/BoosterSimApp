---
phase: 07-polish-distribution
plan: 05
type: execute
wave: 1
depends_on: []
files_modified:
  - BoosterSimApp/Models/AppAction.swift
  - BoosterSimApp/Views/SideWindow/tabs/ActionsTabView.swift
  - BoosterSimApp/Views/SideWindow/SideWindowView.swift
  - BoosterSimApp/Views/SideWindow/CameraView.swift
  - BoosterSimAppTests/AppActionCatalogTests.swift
autonomous: true
requirements:
  - REQ-roadmap-phase7-polish-distribution
estimate:
  tokens: 20000
  raw_tokens: 20000
  tasks: 2
  confidence: low

must_haves:
  truths:
    - "ROADMAP C5: all four Phase 6 views are reachable from the running app's side panel — StatusBarSectionView, BuildStatsSectionView, AXTreeView, and CameraView are instantiated in the Actions tab's catalog mount table (the host chosen per 07-CONTEXT decision 3's planner-research mandate, D-3: the searchable Actions catalog is the tab built to absorb capability sections, with EnvironmentOverridesView as the exact Phase 6 precedent) — zero call sites outside #Preview remains only for nothing"
    - "REQ-fr-13 stays intact: SideTab still has EXACTLY four cases (capture/design/actions/network) — no 5th tab, verified by grep at the gate; the four views join the Actions tab's AppActionSection catalog so the tab's search contract keeps covering every section (nothing mounted outside the catalog)"
    - "The CameraService.probeSupport(pid:) gap is closed: CameraView (or its mount) probes support on onAppear + onChange of pid per the EnvironmentOverridesView.swift:65-70 house convention — without it the section renders 'Requires Xcode 14+' forever; AXTreeView keeps its manual-refresh load design (no auto-load added — Phase 6 behavior preserved)"
    - "The pid/udid signature mismatch is handled at the mount: StatusBarSectionView takes udid (activeUDID, like every Actions-tab section); AXTreeView and CameraView take pid (a new ActionsTabView parameter fed by SideWindowView's activeSim?.pid — SimulatorWindow.swift:24) — no view signatures change"
    - "AppActionCatalogTests' section-coverage contract is updated to the 13-section reality (the pinned expectedSections list at :69-90) and stays green — the catalog remains the single owner of section order and search visibility"
  artifacts:
    - (no new files — wiring + test-contract updates only)
  key_links:
    - "AppActionSection enum (4 new cases) → AppActionCatalog.all (4 new searchable entries with keywords + effectLatency) → ActionsTabView.sectionView mount table → the four views' @EnvironmentObject services (already injected end-to-end by SideWindowController:227-231 — injection is NOT this plan's work, per 07-PATTERNS' headline finding)"
    - "SideWindowView.tabContent (.actions case) → ActionsTabView(udid:deviceName:pid:) → activeSim?.pid → AXTreeView(pid:) / CameraView(pid:) — the plumbing delta the pattern map flagged"
  prohibitions:
    - requirement_id: REQ-roadmap-phase7-polish-distribution
      category: regression
      status: unverified
      flagged: true
      verification: automated
      statement: "MUST NOT add a SideTab case (REQ-fr-13 is locked at exactly 4 tabs), MUST NOT mount anything into the Actions tab outside the AppActionCatalog (unsearchable sections break the tab's nothing-lost-to-the-wiring guarantee), and MUST NOT pass udid where pid is required or vice versa (AXTreeView/CameraView take pid_t from the Simulator window; StatusBarSectionView takes the udid string)"
  flagged_assumptions:
    - "Appending statusBar after environment and camera/axTree/buildStats between defaults and reset keeps a sensible mount order while leaving all nine existing sections' relative order untouched — the catalog's stable-order tests stay valid with only count/list updates"
    - "BuildStatsSectionView()'s 5s polling service is already running (AppDelegate:88) — mounting the view adds no lifecycle work"
---

<objective>
Close the confirmed Phase 6 reachability gap (ROADMAP C5): wire the four built-but-orphaned views into the Actions tab, entirely as mechanical mount work — construction, injection, and service lifecycles are already complete end-to-end (07-PATTERNS' headline finding: the gap is view instantiation only).

Task 1 is the tracer: StatusBarSectionView — the easiest mount (udid-native, exactly like the EnvironmentOverridesView precedent) — goes end-to-end from catalog enum case through searchable entry, mount-table case, and the updated test contract. Task 2 mounts the remaining three, threading pid into ActionsTabView and closing the probeSupport gap in CameraView.

Purpose: criteria 1/2/4/5 of Phase 6 become reachable from the running app; ROADMAP C5 is the phase's only UI-wiring work.
Output: no new files — an extended catalog/mount table, one new view parameter, one probe addition, updated test pins.
</objective>

<execution_context>
@~/.claude/gsd-core/workflows/execute-plan.md
@~/.claude/gsd-core/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/ROADMAP.md
@.planning/STATE.md
@.planning/phases/07-polish-distribution/07-CONTEXT.md
@.planning/phases/07-polish-distribution/07-RESEARCH.md
@.planning/phases/07-polish-distribution/07-PATTERNS.md
@BoosterSimApp/Models/AppAction.swift
@BoosterSimApp/Views/SideWindow/tabs/ActionsTabView.swift
@BoosterSimApp/Views/SideWindow/SideWindowView.swift
@BoosterSimApp/Views/SideWindow/CameraView.swift
@BoosterSimAppTests/AppActionCatalogTests.swift
</context>

<tasks>

<task type="tracer">
  <name>Task 1: Tracer — StatusBarSectionView mounted end-to-end into the Actions catalog</name>
  <files>
    BoosterSimApp/Models/AppAction.swift,
    BoosterSimApp/Views/SideWindow/tabs/ActionsTabView.swift,
    BoosterSimAppTests/AppActionCatalogTests.swift
  </files>
  <read_first>
    - BoosterSimApp/Models/AppAction.swift — AppActionSection enum (:25-37), AppAction struct, AppActionCatalog.all entry style (:53-107: id/title/keywords/section/effectLatency shapes)
    - BoosterSimApp/Views/SideWindow/tabs/ActionsTabView.swift — the sectionView mount table (:72-96; the bare-mount precedent `case .environment: EnvironmentOverridesView(udid: udid)` at :75-76)
    - BoosterSimAppTests/AppActionCatalogTests.swift:69-90 — the section-coverage test with its pinned expectedSections list (the assertion this task updates)
    - .planning/phases/07-polish-distribution/07-PATTERNS.md — Convention A (catalog-driven section table) and why mounting outside the catalog is prohibited
  </read_first>
  <action>
    AppAction.swift: add `case statusBar` to AppActionSection immediately after `environment` (visual-state overrides adjacent; all existing sections keep their relative order). Add one AppAction to AppActionCatalog.all in matching section position: Status Bar Override — id following the existing lowercase-dot id style, keywords covering statusbar/status bar/time/battery/signal/preset/custom, effectLatency .instant (simctl spawn, instant effect).
    ActionsTabView.swift: add `case .statusBar: StatusBarSectionView(udid: udid)` to sectionView — bare mount, exactly the environment precedent. No wrapper, no CollapsibleSection, no onAppear (StatusBarService verbs are tap-driven per 07-PATTERNS).
    AppActionCatalogTests.swift: update the expectedSections list in the section-coverage test to include statusBar at its position; add one filter test (e.g. query "status bar" or "battery" matches the new entry's section) following the existing keyword-hit test shape (:15-17).
  </action>
  <verify>
    <automated>grep -q 'case statusBar' BoosterSimApp/Models/AppAction.swift && grep -q 'StatusBarSectionView(udid: udid)' BoosterSimApp/Views/SideWindow/tabs/ActionsTabView.swift && grep -c 'case ' BoosterSimApp/Views/SideWindow/SideTab.swift | grep -qx 4 && xcodebuild -project BoosterSimApp.xcodeproj -scheme BoosterSimApp -destination 'platform=macOS' test -only-testing:BoosterSimAppTests/AppActionCatalogTests -parallel-testing-enabled NO 2>&1 | tail -5</automated>
    <fails_when>the enum/mount greps fail, SideTab grew a case, or the catalog suite reports any failure</fails_when>
  </verify>
  <done>Status Bar overrides are reachable from the Actions tab, searchable through the catalog, with the section-coverage contract updated and green — the proven mount pattern Tasks 2 repeats three times.</done>
</task>

<task type="auto">
  <name>Task 2: Mount BuildStats + AXTree + Camera — pid threading and the probeSupport gap</name>
  <files>
    BoosterSimApp/Models/AppAction.swift,
    BoosterSimApp/Views/SideWindow/tabs/ActionsTabView.swift,
    BoosterSimApp/Views/SideWindow/SideWindowView.swift,
    BoosterSimApp/Views/SideWindow/CameraView.swift,
    BoosterSimAppTests/AppActionCatalogTests.swift
  </files>
  <read_first>
    - BoosterSimApp/Views/SideWindow/SideWindowView.swift — tabContent's .actions case (:70) passes activeUDID + displayName today; activeSim (:24) already exists and carries pid
    - BoosterSimApp/Views/SideWindow/CameraView.swift — takes `let pid: pid_t?` (:7); renders unsupportedRow while service.isSupported stays false
    - BoosterSimApp/Services/CameraService.swift — probeSupport(pid:) (zero call sites anywhere — the trap), isSupported starts false
    - BoosterSimApp/Views/SideWindow/EnvironmentOverridesView.swift:65-70 — the onAppear + onChange probe convention to copy; and AppDelegate.swift:94-95's NOTE documenting the one-owner discipline
    - BoosterSimApp/Views/SideWindow/AXTreeView.swift — takes `let pid: pid_t?`; loadRoot(for:) fires ONLY from the header's refresh button (manual load BY DESIGN — preserve)
    - BoosterSimApp/Views/SideWindow/BuildStatsSectionView.swift — zero init params; service already polling (AppDelegate:88)
    - BoosterSimApp/Views/SideWindow/tabs/ActionsTabView.swift #Preview — the other construction site that must gain the pid argument
  </read_first>
  <action>
    AppAction.swift: add `case camera`, `case axTree`, `case buildStats` to AppActionSection between `defaults` and `reset` (inspection/info sections before the destructive terminal section; existing relative order untouched). Add three catalog entries in matching positions: Camera Routing (keywords camera/mac camera/front/back/video input; .instant), AX Tree Inspector (keywords accessibility/ax/tree/inspector/elements/highlight; .instant), Build Statistics (keywords build/stats/xcode/deriveddata/chart/times; .instant) — ids in the house style.
    SideWindowView.swift: pass `pid: activeSim?.pid` into ActionsTabView at the .actions case.
    ActionsTabView.swift: add `let pid: pid_t?` beside udid/deviceName; update the #Preview construction; add three bare mounts to sectionView — `BuildStatsSectionView()` (zero params), `AXTreeView(pid: pid)`, `CameraView(pid: pid)`. udid stays the argument for every existing section; pid is used ONLY by AXTreeView/CameraView (the signature mismatch handled at the mount — never pass one for the other).
    CameraView.swift: close the probeSupport gap with the house convention on the body's VStack — `.onAppear { if let pid { service.probeSupport(pid: pid) } }` and `.onChange(of: pid) { _, newPID in if let newPID { service.probeSupport(pid: newPID) } }` — one owner (the view), with a NOTE comment in the EnvironmentOverridesView style. This is the only edit to a Phase 6 view; AXTreeView gets NO auto-load (manual refresh by design) and BuildStatsSectionView/StatusBarSectionView need no lifecycle additions.
    AppActionCatalogTests.swift: extend expectedSections to the 13-section list in final order; optionally one keyword test (e.g. "camera" matches the camera section) mirroring Task 1's addition.
  </action>
  <verify>
    <automated>grep -q 'case camera' BoosterSimApp/Models/AppAction.swift && grep -q 'case axTree' BoosterSimApp/Models/AppAction.swift && grep -q 'case buildStats' BoosterSimApp/Models/AppAction.swift && grep -q 'AXTreeView(pid: pid)' BoosterSimApp/Views/SideWindow/tabs/ActionsTabView.swift && grep -q 'CameraView(pid: pid)' BoosterSimApp/Views/SideWindow/tabs/ActionsTabView.swift && grep -q 'BuildStatsSectionView()' BoosterSimApp/Views/SideWindow/tabs/ActionsTabView.swift && grep -q 'pid: activeSim?.pid' BoosterSimApp/Views/SideWindow/SideWindowView.swift && grep -q 'probeSupport(pid:' BoosterSimApp/Views/SideWindow/CameraView.swift && grep -c 'case ' BoosterSimApp/Views/SideWindow/SideTab.swift | grep -qx 4 && xcodebuild -project BoosterSimApp.xcodeproj -scheme BoosterSimApp -destination 'platform=macOS' test -only-testing:BoosterSimAppTests -skip-testing:BoosterSimAppUITests -parallel-testing-enabled NO 2>&1 | tail -5</automated>
    <fails_when>any mount/plumbing/probe grep fails, SideTab grew a case, or the full unit bundle reports any failure</fails_when>
  </verify>
  <done>All four Phase 6 views are instantiated in the Actions tab's catalog (13 sections, all searchable), pid is threaded from the tracked Simulator window, CameraView probes support on appear/change, and the full unit bundle is green with the updated section contract.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| Catalog contract ↔ rendered sections | The Actions tab's search guarantees coverage of every mounted section; mounting outside the catalog silently breaks that guarantee |
| Locked requirement ↔ tab structure | REQ-fr-13 (exactly 4 tabs) is a verified shipped contract — the wiring must not regress it |

## STRIDE Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation Plan |
|-----------|----------|-----------|----------|-------------|-----------------|
| T-07-14 | Tampering (requirement regression) | SideTab enum | high | mitigate | Prohibition + gate grep: SideTab stays exactly 4 cases; sections go INSIDE a tab |
| T-07-15 | Repudiation (search contract) | ActionsTabView mounts | medium | mitigate | All four mounts go through AppActionSection + AppActionCatalog; the section-coverage test pins enum == catalog == expected list, updated to 13 sections |
| T-07-16 | Tampering (stale state illusion) | CameraView support probe | medium | mitigate | probeSupport wired via the established onAppear/onChange convention; without it the view lies ("Requires Xcode 14+") — the trap the pattern map flagged |
</threat_model>

<verification>
- Task 1: statusBar enum + bare mount greps, SideTab 4-case gate, AppActionCatalogTests green
- Task 2: all three mounts + pid threading + probe greps, SideTab gate again, FULL unit bundle green
- End state: zero orphaned Phase 6 views (grep StatusBarSectionView/BuildStatsSectionView/AXTreeView/CameraView call sites — one real call site each beyond #Preview)
</verification>

<success_criteria>
- ROADMAP C5 TRUE: Status Bar overrides, Build Stats, AX Tree Inspector, and Camera routing are all reachable from the side panel
- REQ-fr-13 unregressed (4 tabs), search contract intact (13 catalog sections), camera support detection live
- Mechanical wiring only — no service/construction work redone, no human gate needed
</success_criteria>

<output>
Create `.planning/phases/07-polish-distribution/07-05-phase6-view-wiring-SUMMARY.md` when done
</output>
