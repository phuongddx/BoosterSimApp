# Phase 7: Polish & Distribution - Pattern Map

**Mapped:** 2026-09-01
**Files analyzed:** 11 (4 existing views to mount, 3 candidate host tabs, 1 root view, pbxproj + Package.resolved, updater wiring + tests)
**Analogs found:** 11 / 11 (8 exact, 3 role-match — see No Analog notes for Sparkle's UI surface)

**Research-status flag:** `07-RESEARCH.md` was not yet on disk at mapping time (phase dir held only `07-CONTEXT.md`); the file list is derived from `07-CONTEXT.md` decisions 1 and 3 + ROADMAP Phase 7 criterion 5 + `docs/codebase-summary.md:274-278` ("Standalone views (exist but not wired into tabs yet)"). When RESEARCH.md lands, the planner should reconcile — but every pattern below is read from the live tree at HEAD and is stable regardless.

**Carried convention flag (from 04-PATTERNS.md, still true):** repo tests are **Swift Testing** (`import Testing`, `@Test`, `#expect` — AppActionCatalogTests.swift:1-7), NOT XCTest. Phase 7's unit suites must follow that convention.

## The Headline Finding — Injection Is Already Complete

The four Phase 6 services are **already constructed, injected, and live end-to-end**. The orphan gap is *purely* that `SideWindowView.tabContent` (4-case switch) never instantiates the views. No AppDelegate or controller changes are required for the wiring:

| Chain link | Evidence | Status |
|---|---|---|
| Construction (lazy vars) | `AppDelegate.swift:17-21` — `statusBarService`, `envOverrideService`, `buildStatsService`, `axInspectorService`, `cameraService` | ✓ already there |
| Controller injection | `AppDelegate.swift:43-59` — `SideWindowController(settings:tracker:statusBarService:envOverrideService:buildStatsService:axInspectorService:cameraService:…)` (args at :46-50) | ✓ already there |
| EnvironmentObject mounting | `SideWindowController.swift:200-205` (embedSwiftUIContent params) → `:227-231` `.environmentObject(statusBarService/envOverride/buildStats/axInspector/camera)` chained on SideWindowView → `:240-242` NSHostingView | ✓ already there |
| View-side declarations | `SideWindowView.swift:11-17` — `@EnvironmentObject` for all seven services incl. the four orphans' | ✓ already there, **unused** |
| Service lifecycles already running | `AppDelegate.swift:88` `buildStatsService.startMonitoring()`; `:89` `connectService.startServer()`; `:97-104` `axInspectorService.$highlightFrame` → `axHighlightPanel.show/hide()` sink | ✓ already running |

**Consequence for the planner:** the wiring task is "add view instantiations inside an existing tab," not "thread services." Any plan that touches AppDelegate/SideWindowController for this is re-doing finished work. The 04-VERIFICATION.md "Key Link Verification" table documented this same already-complete pattern for Design-tab services; Phase 6 services are identical in shape.

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `Views/SideWindow/StatusBarSectionView.swift` (mount existing) | component (flat section) | request-response (simctl via service) | `EnvironmentOverridesView` mount in `ActionsTabView.swift:75-76` | exact |
| `Views/SideWindow/BuildStatsSectionView.swift` (mount existing) | component (flat section) | streaming (5s polling) | same | exact |
| `Views/SideWindow/AXTreeView.swift` (mount existing) | component (flat section) | request-response (lazy AX walk) | same + pid plumbing via `SimulatorWindow.pid` | exact w/ delta |
| `Views/SideWindow/CameraView.swift` (mount existing) | component (flat section) | event-driven (AX menu press) | same + **probeSupport gap** (below) | role-match w/ delta |
| Host tab view (modify — planner's pick per CONTEXT decision 3) | component (tab mount) | binding | 3 mapped conventions below | exact (all 3) |
| `Views/SideWindow/SideWindowView.swift` (modify only if mounting at root) | component (root switch) | binding | itself (`tabContent`, :62-77) | exact |
| `BoosterSimApp.xcodeproj/project.pbxproj` (modify — Sparkle) | config | — | Pulse addition (Phase 5), pbxproj:80-87, :312-314, :416-436, :199-202 | exact w/ single-target delta |
| `Package.resolved` (start tracking) | config | — | pin-hash gate pattern (Phases 2-4 closures) | exact |
| Updater wiring (new — SPUStandardUpdaterController or thin wrapper) | service/controller | event-driven | AppDelegate lazy-var service block (:17-39) + `Views/Preferences/AboutTab.swift` surface | role-match (no auto-update analog exists) |
| Unit tests: PositionCalculator/WindowEnumerator/AppSettings (new) | test | — | `AppActionCatalogTests` Swift Testing convention | exact convention |
| Onboarding UI tests (extend `BoosterSimAppUITests/`) | test | — | 3 existing files in the target | role-match |

## Pattern Assignments

### `Views/SideWindow/StatusBarSectionView.swift` (mount — flat section)

**Analog:** `EnvironmentOverridesView`'s bare mount in `ActionsTabView.swift:75-76` (`case .environment: EnvironmentOverridesView(udid: udid)`) — the established precedent for mounting a Phase 6 flat-section view without a CollapsibleSection wrapper.

**Shape** (StatusBarSectionView.swift:5-13): `@EnvironmentObject var service: StatusBarService` + `let udid: String?` + local `@State showCustom/customConfig`. Takes **udid**, not pid.

**Body — honest disabled-state branch** (:15-23):
```swift
var body: some View {
    VStack(spacing: 0) {
        sectionHeader
        if isDisabled {
            noSimulatorRow
        } else {
            presetButtons
            if showCustom { customControls }
        }
    }
}
```
No `onAppear` load needed — StatusBarService verbs (`applyPreset`/`clearOverrides`/`applyCustom`, :49, :62, :104) are tap-driven.

**Flat-section header convention — copy verbatim for any new section header** (:29-40; identical in all four orphan views and BuildStats):
```swift
private var sectionHeader: some View {
    HStack(spacing: Spacing.xs) {
        Image(systemName: "clock").imageScale(.small).foregroundStyle(.secondary)
        Text("Status Bar").font(.subheadline).fontWeight(.medium).foregroundStyle(.secondary)
        Spacer()
        // optional trailing accessory (ProgressView / count caption / refresh button)
    }
    .padding(.horizontal, Spacing.md)
    .frame(height: SideWindowMetrics.compactRowHeight)
}
```

**Custom expander pattern** (:81-104): `@State showCustom` toggle reveals `VStack(spacing: Spacing.sm)` of `Text("…").font(.caption).foregroundStyle(.secondary)` + `TextField`/`Slider` rows, inline `service.lastError` error caption (`.caption2 .red`), and a `.borderedProminent` Apply button `.disabled(isDisabled)`. This is the in-repo pattern for "presets + custom" pairs.

---

### `Views/SideWindow/BuildStatsSectionView.swift` (mount — zero-param)

**Analog:** same bare-mount precedent. **Easiest mount of the four** — no init params at all; the service is already polling (AppDelegate.swift:88).

**Shape** (BuildStatsSectionView.swift:5-7): `@EnvironmentObject var service: BuildStatsService` only.

**Body** (:20-32): `sectionHeader` → empty check → `chartRow` + `buildList`. The header shows the trailing accessory variant (:44-47): `Text("\(count) builds · avg \(avgFormatted)").font(.caption2).foregroundStyle(.tertiary)`.

**Rows** (:60-80): status icon (`.green`/`.red` success tint), `.body` label, trailing two-line caption stack (`.caption` + `.caption2`), `.padding(.horizontal, Spacing.md)` + `.frame(height: SideWindowMetrics.rowHeight)`. Empty state (:82-86): `Text("No builds found in DerivedData").font(.caption).foregroundStyle(.secondary)` at rowHeight.

**Companion:** `BuildChartView` (Canvas bars) is referenced from :56 and needs no separate mounting.

---

### `Views/SideWindow/AXTreeView.swift` (mount — takes pid, not udid)

**Shape** (AXTreeView.swift:5-8): `@EnvironmentObject var service: AXInspectorService` + `let pid: pid_t?`.

**Body** (:9-20): four-state branch — `pid == nil → noSimulatorRow`, `service.isLoading → loadingRow`, `service.rootNodes.isEmpty → emptyRow`, else `nodeList`.

**pid source — the plumbing delta:** `SimulatorWindow.pid: pid_t` (SimulatorWindow.swift:24, from `kCGWindowOwnerPID`). `SideWindowView` already exposes the tracker via `@ObservedObject` (:7) and the helper `private var activeSim: SimulatorWindow?` (:24), so the argument is `activeSim?.pid` (non-optional `pid_t` on the model → optional at the call site, exactly matching the parameter type). Do **not** pass udid — AXUIElementCreateApplication needs the process id (AXInspectorService.swift:40).

**Load behavior — mount as-is, flag any change:** the only `loadRoot(for:)` call site is the header's inline refresh button (AXTreeView.swift:33-35, button at :22-43). There is **no onAppear auto-load**; the tree loads on user tap by design. If the planner wants auto-load-on-appear, that is a behavior change to the Phase 6 view, not a copy of an existing pattern — decide explicitly.

---

### `Views/SideWindow/CameraView.swift` (mount — pid + a real gap to close)

**Shape** (CameraView.swift:5-8): `@EnvironmentObject var service: CameraService` + `let pid: pid_t?` (same pid plumbing as AXTreeView).

**Body** (:9-16): `if !service.isSupported → unsupportedRow` else `cameraRows` (Front/Back toggle rows, :18-40; row helper :64-81 with trailing `Text(isEnabled ? "Mac Camera" : "Simulated").font(.caption2)` state pill).

**TRAP — `probeSupport` has zero call sites.** `CameraService.probeSupport(pid:)` (CameraService.swift:49) is defined but never called anywhere in the repo (grep: definition only). `isSupported` starts `false` (:38), so a naively mounted CameraView renders `"Requires Xcode 14+"` forever. **The mount must add the probe**, following the house convention for view-owned state loading — `EnvironmentOverridesView.swift:65-70`:
```swift
.onAppear {
    if let udid { service.loadCurrentState(udid: udid) }
}
.onChange(of: udid) { _, newUdid in
    if let newUdid { service.loadCurrentState(udid: newUdid) }
}
```
…whose AppDelegate counterpart documents the discipline (AppDelegate.swift:94-95: "NOTE: envOverrideService.loadCurrentState is called from EnvironmentOverridesView (onAppear + onChange) — no need to duplicate here"). So: `probeSupport(activeSim?.pid)` in `onAppear`/`onChange(of: activeSim?.pid)` at the mount site (or in CameraView itself — one owner, noted like the AppDelegate comment).

---

### Host tab — the three existing mount conventions (planner picks per CONTEXT decision 3)

**Hard constraint first (REQ-fr-13, locked + verified):** exactly four tabs. `SideTab` enum has 4 cases with icon+label (SideTab.swift:4-24) and `TabBarView` renders `ForEach(SideTab.allCases, id: \.self)` (TabBarView.swift:13) — adding a 5th case auto-renders a 5th tab button and regresses a shipped requirement. **No 5th tab; 07-CONTEXT decision 3 already rules it out.**

**Convention A — ActionsTabView: catalog-driven section table** (the 03-04 pattern, 14 actions / 9 sections). If sections land here, they MUST join the catalog — the tab's search contract covers every section, and unsearchable sections would silently break `AppActionCatalog.filter`'s "nothing lost to the wiring" guarantee (ActionsTabView.swift:39-42) plus `AppActionCatalogTests` contracts:
- Section order is the enum (AppAction.swift:25-35 — `AppActionSection: String, CaseIterable, Identifiable, Sendable`, fixed mount order);
- Entries in `AppActionCatalog.all` (:53-107) with `keywords` + `effectLatency`;
- Rendering via `visibleSections` (:40-42: `isFiltering ? matchedSections : AppActionSection.allCases`) → `ForEach(visibleSections) { sectionView($0) }` (:58-60) → the single `sectionView(_:)` switch (:73-81+);
- Two mount styles inside the switch: **bare** (`case .environment: EnvironmentOverridesView(udid: udid)`, :75-76) and **CollapsibleSection-wrapped** (`case .deepLinks: CollapsibleSection(title:icon:isExpanded:) { … }`, :77-80).

**Convention B — NetworkTabView: flat always-visible stack** (NetworkTabView.swift:29-56). Not a ScrollView — `VStack(spacing: 0)` stacking `ConnectStatusBanner` → viewer-or-setup → `Divider()` → `NetworkConditionsSectionView()` → `BlockRulesView()` → `CertificateSectionView(...)`. Sections are always mounted; closures (`udidProvider`) carry per-row context. This is the precedent if Status Bar/Build Stats/Camera should be permanently visible rather than disclosure-gated.

**Convention C — CaptureTabView: ScrollView of CollapsibleSection rows + bare sections** (CaptureTabView.swift:20-40). `ScrollView { VStack(spacing: Spacing.xxs) { CollapsibleSection(title: "Screenshot", icon: "camera", isExpanded: $isScreenshotExpanded) {…}; RecordingSectionView(…); ExportSectionView(…); destinationSection } }` — default-expanded first section (`= true`), bare flat sections after. DesignTabView (:16-20) is the single-CollapsibleSection degenerate case. **CollapsibleSection atom** (Shared/CollapsibleSection.swift:4-47) is the shared wrapper: `title`/`icon`/`isExpanded` Binding/`@ViewBuilder content`; chevron rotates 90° (:33-38); Reduce Motion collapses to `0.1s` linear (:13-15); per docs/design-guidelines.md it is already the atom of record (`EnvironmentOverridesView`, `BuildStatsSectionView` consumers listed there — note: in the current tree those two actually render their own flat `sectionHeader`s; the design-guidelines consumer list is aspirational on that detail, the *atom API* is what to copy).

**Root-level note:** `SideWindowView.tabContent` (SideWindowView.swift:62-77) passes `activeUDID` (:26-29, `sim.udid ?? "booted"`) and `activeSim?.displayName` into tab views; sections mounted directly in a tab get their arguments the same way.

---

### `project.pbxproj` — Sparkle via the Pulse template (Phase 5)

Four coordinated edits, mirroring Pulse exactly (BoosterSimApp.xcodeproj/project.pbxproj):

| Edit | Pulse evidence | Sparkle delta |
|---|---|---|
| 1. Package reference block | `:80-87` — `XCRemoteSwiftPackageReference "Pulse"` with `repositoryURL` + `requirement { kind = upToNextMajorVersion; minimumVersion = 5.1.0; }` | New block: `https://github.com/sparkle-project/Sparkle.git`, fresh 24-hex object id |
| 2. Project-level list | `:312-314` — `packageReferences = ( 07896468… /* XCRemoteSwiftPackageReference "Pulse" */, );` | Append the new reference id |
| 3. Product dependency entry | `:416-436` — `XCSwiftPackageProductDependency` section; note Pulse has **distinct per-target entries** (`Pulse` :417-421 vs `Pulse (BoosterSimConnect)` :427-431) both pointing at the same package | One entry, product `Sparkle` |
| 4. Target attach | `:199-202` — `packageProductDependencies` on the **BoosterSimApp native target** (and separately `:271-274` on BoosterSimConnect for Pulse) | Attach to the **app target only**. BoosterSimConnect is an iphonesimulator framework — linking a macOS Sparkle there is wrong by platform, unlike Pulse which is deliberately dual-target |

**Package.resolved:** exists at `BoosterSimApp.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved` (format v3: `originHash` + pins; currently the single Pulse 5.2.2 pin) and is **untracked in git** (`git ls-files --error-unmatch` fails) — the known infra gap recorded in 07-CONTEXT (`code_context`). Adding Sparkle changes this file, so the Sparkle commit is the forcing function to `git add` it in the same change. Gate precedent: Phases 2-4 closures asserted "zero SPM changes — sha256 identical" against this file; Phase 7 flips that to asserting the **new** post-Sparkle pin hash once, after the addition.

**Policy wording (CONTEXT decision 1):** Sparkle is a second **named** exception to the Apple-frameworks-only policy — the plan must amend the exception wording where it lives (PROJECT.md Constraints "exception: Pulse/PulseProxy…", REQUIREMENTS.md REQ-nfr-03) rather than silently expanding it.

---

### Updater wiring (new — role-match only)

No auto-update code exists anywhere in the repo. Closest construction patterns:

- **Service ownership:** the AppDelegate lazy-var block (AppDelegate.swift:17-39) is the house shape — construct once, inject where needed. Sparkle's `SPUStandardUpdaterController` is an AppKit controller; it can be constructed in AppDelegate or owned by the Preferences window, but **not** as a SwiftUI `@StateObject` in a tab (code-standards: services lift state; `@MainActor final class` preferred).
- **UI surface:** "Check for Updates" belongs in Preferences — `Views/Preferences/PreferencesView.swift` (General | About tabs, `AboutTab.swift` is the natural host) per docs/design-guidelines.md Preferences section. `Views/Shared/AccentButton.swift` is the CTA atom if a custom button is wanted over the standard Sparkle one.
- **Concurrency fit:** Sparkle is Objective-C + delegate callbacks on the main thread — compatible with the no-async/await, @MainActor, Combine-only standard (docs/code-standards.md Concurrency). Nothing in Sparkle requires the sanctioned Task-bridge.
- **No analog (goes to RESEARCH, not patterns):** `SUFeedURL`/`SUPublicEDKey` Info.plist keys, EdDSA keypair generation, appcast XML hosting (CONTEXT `specifics` suggests GitHub Releases as the default), and the non-sandbox signing notes (`ENABLE_APP_SANDBOX = NO` is compatible with notarization — Developer ID + hardened runtime + staple).

## Shared Patterns

### Flat-section header (all four orphans + EnvironmentOverridesView)
**Source:** StatusBarSectionView.swift:29-40 (identical shape in BuildStatsSectionView.swift:36-52, AXTreeView.swift:22-43, CameraView.swift:23-36)
**Apply to:** every section mounted into a tab, so siblings read identically: `HStack(spacing: Spacing.xs)` + SF Symbol `.imageScale(.small)` `.secondary` + title `.subheadline`/`.medium`/`.secondary` + trailing accessory + `.padding(.horizontal, Spacing.md)` + `.frame(height: SideWindowMetrics.compactRowHeight)`.

### Honest state rows (never a blank/optimistic section)
**Source:** AXTreeView.swift:77-89 (loading/empty), :91-95 (noSimulator); CameraView.swift:83-90 (unsupported); BuildStatsSectionView.swift:82-86 (empty)
**Apply to:** all four mounts as-is — they already degrade honestly; the mount site only supplies the nil-able argument that drives them.

### View-owned service state loading (onAppear + onChange)
**Source:** EnvironmentOverridesView.swift:65-70 + the documenting NOTE at AppDelegate.swift:94-95
**Apply to:** CameraView's missing `probeSupport` call (required — see TRAP above); NOT needed for StatusBar (tap-driven) or BuildStats (already polling) or AXTree (manual refresh by design).

### Design tokens everywhere
**Source:** every excerpt above; tokens in `Utilities/DesignTokens.swift` (docs/code-standards.md Design Tokens section)
**Apply to:** any new wrapper code — `Spacing.*` for gaps, `SideWindowMetrics.compactRowHeight/rowHeight/expandedWidth` for sizing; `CornerRadius.*` for anything rounded. 260pt expanded width is fixed; all four views' `#Preview`s already frame to `SideWindowMetrics.expandedWidth`.

### REQ-fr-13 enforcement point
**Source:** SideTab.swift:4-8 (4 cases) + TabBarView.swift:13 (`ForEach(SideTab.allCases)`)
**Apply to:** any integration proposal — if it adds a `SideTab` case, it violates a verified requirement. Sections go *inside* a tab.

### Test conventions
**Source:** AppActionCatalogTests.swift:1-7 — `import Testing`, `struct …Tests`, `@Test func`, `#expect`; pure-logic focus (catalog/filter, argv builders). Unit suites for PositionCalculator/WindowEnumerator/AppSettings follow the same shape (`@testable import BoosterSimApp`). UI tests extend the existing `BoosterSimAppUITests/` target (3 files: `BoosterSimAppUITests.swift`, `ScreenshotTests.swift`, `BoosterSimAppUITestsLaunchTests.swift` — target confirmed in pbxproj:246-252) — no new target.

## No Analog Found

| Concern | Role | Reason | Guidance |
|---------|------|--------|----------|
| Sparkle updater configuration (Info.plist keys, EdDSA keys, appcast) | config | No auto-update code exists in the repo | Use RESEARCH.md / Sparkle standard defaults; CONTEXT `specifics` seeds GitHub Releases hosting |
| Archive → notarytool → stapler → DMG flow | build/distribution | No scripts/ or CI pipeline analog exists | Greenfield; document the non-sandbox rationale (REQUIREMENTS.md Out of Scope: sandbox incompatible with AX/CGWindowList/simctl) |
| App icon art | asset | `Assets.xcassets/AppIcon.appiconset/` holds only `Contents.json` (CONTEXT decision 2 records the generation-tool failure) | Planner options (a)/(b)/(c) per 07-CONTEXT decision 2; placeholder path must follow design-guidelines (amber accent + SF Symbol, no hardcoded hex) |
| PrivacyInfo.xcprivacy | config | No privacy manifest exists (07-CONTEXT `code_context`) | Enumerate required-reason APIs against the real codebase (AX, ScreenCaptureKit, UserDefaults) in RESEARCH, not here |

## Metadata

**Analog search scope:** `BoosterSimApp/Views/SideWindow/**`, `BoosterSimApp/Views/Shared/`, `BoosterSimApp/Views/Preferences/`, `BoosterSimApp/App/`, `BoosterSimApp/Windows/`, `BoosterSimApp/Models/`, `BoosterSimApp/Services/` (CameraService, AXInspectorService), `BoosterSimApp.xcodeproj/project.pbxproj`, `BoosterSimAppTests/`, `BoosterSimAppUITests/`
**Files read:** 25+ (all four orphan views in full, all four tab views, SideWindowView, SideWindowController, AppDelegate, SideTab, TabBarView, CollapsibleSection, SimulatorWindow, CameraService, AppAction, tests, pbxproj sections, Package.resolved, docs)
**Pattern extraction date:** 2026-09-01
**Source tree state:** HEAD at mapping time; all file:line references read live (not from docs).
