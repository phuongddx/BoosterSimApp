---
phase: 03-app-actions
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - BoosterSimApp/Services/SimCtlService.swift
  - BoosterSimApp/Services/DerivedDataAppScanner.swift
  - BoosterSimApp/Services/AppActionService.swift
  - BoosterSimApp/Views/SideWindow/actions/AppPickerBar.swift
  - BoosterSimApp/Views/SideWindow/actions/AppResetSectionView.swift
  - BoosterSimApp/Views/SideWindow/tabs/ActionsTabView.swift
  - BoosterSimApp/App/AppDelegate.swift
  - BoosterSimApp/Views/SideWindow/SideWindowView.swift
  - BoosterSimApp/Utilities/AppLogger.swift
  - BoosterSimAppTests/DerivedDataAppScannerTests.swift
  - BoosterSimAppTests/AppActionServiceTests.swift
autonomous: false
requirements:
  - REQ-roadmap-phase3-app-actions
  - REQ-fr-13
user_setup:
  - service: ios-simulator
    why: "Task 3 blocking smoke needs a booted iOS Simulator with (a) one non-Apple app built from Xcode into DerivedData and installed, carrying visible persisted state, and (b) the BoosterSimApp local CA generated+installed (Network tab Certificates) to prove the D-02 keychain-wipe reconcile"
    dashboard_config:
      - task: "Boot one iOS Simulator device and run any iOS app from Xcode onto it once (so it exists in DerivedData, is installed, and has written some UserDefaults state)"
        location: "Xcode → pick an iOS scheme → run on the booted Simulator"
      - task: "In BoosterSimApp Network tab: generate + install the local CA before the smoke"
        location: "BoosterSimApp side panel → Network → Certificates"
estimate:
  tokens: 55000
  raw_tokens: 55000
  tasks: 3
  confidence: low

must_haves:
  truths:
    - "With a booted Simulator and at least one app built into DerivedData and installed on the device, the Actions tab shows an app picker bar whose candidates are DerivedData iOS apps that are ALSO installed (currently-running apps badged), defaulting to the most recently built; picking an app and clicking Reset App Data terminates it if running, uninstalls it (data container removed), reinstalls it from its DerivedData build product when one exists, and leaves the app in a confirmed fresh state — previously written UserDefaults are gone on next launch"
    - "Re-invoking reset with identical inputs is safe: repeated reset terminates-if-running then uninstalls-if-installed without erroring — the listapps presence pre-check decides the reported outcome because uninstall exits 0 even for a missing app (exit codes never detect absence)"
    - "The device-wide keychain clear runs only after a typed destructive confirmation that names the full blast radius — every app's keychains on this Simulator plus the BoosterSimApp local CA — and afterward the CA is automatically re-reconciled through the existing CertificateService path so certificate trust works again with no manual steps (D-02)"
    - "SimCtlService survives large outputs: listapps (~33 KB today, unbounded upward) returns instead of hanging because both pipes are read concurrently with process exit; invocations are serialized (queued, never interleaved); an interrupted action leaves the service in recoverable idle state; and every existing caller keeps compiling unchanged (source-compatible signature, stdin parameter optional with nil default)"
    - "When several DerivedData trees contain the same bundle ID, the scanner resolves exactly one candidate — the most recent by build mtime — with the alternatives visible in the picker; symlinked/alias DerivedData paths resolve to the same tree rather than duplicating candidates"
    - "With no booted Simulator the new Actions tab sections render a disabled/degraded state and nothing crashes; destructive controls are disabled"
  artifacts:
    - BoosterSimApp/Services/SimCtlService.swift
    - BoosterSimApp/Services/DerivedDataAppScanner.swift
    - BoosterSimApp/Services/AppActionService.swift
    - BoosterSimApp/Views/SideWindow/actions/AppPickerBar.swift
    - BoosterSimApp/Views/SideWindow/actions/AppResetSectionView.swift
    - BoosterSimAppTests/DerivedDataAppScannerTests.swift
    - BoosterSimAppTests/AppActionServiceTests.swift
  key_links:
    - "AppPickerBar candidate tap → AppActionService.activeBundleID (@Published) → AppResetSectionView Reset button → AppActionService.resetApp(udid:bundle:) → simCtl.run(terminate) → listapps presence parse → uninstall → install(productPath) → operation/status @Published → section status caption"
    - "DerivedDataAppScanner.scan(root:) → [DiscoveredApp] → AppActionService.refreshApps(udid:) intersect listapps-parsed installed set, badge launchctl-parsed running set → @Published candidates → AppPickerBar"
    - "AppDelegate lazy var appActionService = AppActionService(simCtl:certificateService:) → SideWindowController → SideWindowView .environmentObject(appActionService) → ActionsTabView @EnvironmentObject"
    - "AppResetSectionView destructive confirm → AppActionService.clearKeychain(udid:) → CertificateService.resetKeychain(udid:) + reconcileStatus(udid:) (the same entry point SideWindowController already drives on simulator change)"
  prohibitions:
    - requirement_id: REQ-roadmap-phase3-app-actions
      category: safety
      status: unverified
      flagged: true
      statement: "MUST NOT run the device-wide keychain wipe without an explicit typed confirmation naming the blast radius (ALL Simulator keychains + the Phase 5 local CA) — the wipe is never a single unconfirmed click, never the default action, and never invoked with the ambiguous 'booted' UDID token (D-02)"
    - requirement_id: REQ-roadmap-phase3-app-actions
      category: values
      status: unverified
      flagged: true
      statement: "MUST NOT spawn xcrun/simctl subprocesses outside SimCtlService — no direct subprocess construction or detached-task spawns in any new Phase 3 code; every verb goes through the seam, UDID-scoped from the tracker's active simulator"
    - requirement_id: REQ-roadmap-phase3-app-actions
      category: privacy
      status: unverified
      flagged: true
      statement: "MUST NOT log bundle IDs, UDIDs, or DerivedData paths beyond redacted summaries — scanner and reset logging carries verbs, counts, and outcomes only (extends the house never-log-sensitive-data rule to Phase 3 surfaces)"
  flagged_assumptions:
    - requirement_id: REQ-roadmap-phase3-app-actions
      probe: research-A6
      status: unresolved
      statement: "CLOSES AT TASK 3 SMOKE IF PASS: `simctl install <udid> <path>` (reinstall step of Reset App Data) is documented-but-not-live-verified in 03-RESEARCH.md — on failure the reset must degrade to the uninstalled state with an honest caption, never report success; if the smoke shows install failing, keep the degrade path and note it in the summary"
    - requirement_id: REQ-roadmap-phase3-app-actions
      probe: concurrency
      status: unresolved
      statement: "Serializing the seam turns EnvironmentOverrideService's ~11-parallel defaults-read burst into a sequential run (~11 x <1s) — acceptable by design; if the Task 3 smoke shows loadCurrentState latency > 2s, keep serialization but raise the seam's QoS and note it"
---

<objective>
Tracer slice: prove the Phase 3 App Actions architecture end-to-end with ONE story — reset the active app.

Wire a single vertical path through every layer this phase touches: ActionsTabView mount → AppPickerBar (DerivedData scan ∩ listapps installed ∩ launchctl running badge, explicit selection) → AppActionService (state-machine facade, CertificateService pattern) → SimCtlService (extended seam: concurrent pipe reads fixing the >64 KB deadlock, stdin support, serialized invocations) → terminate → listapps presence check → uninstall → reinstall → status caption. Task 2 then completes success criterion 1 with the D-02 destructive keychain clear delegating to the existing CertificateService reset + reconcile.

This tracer ships the shared engine, not just one action: the seam every later verb (push, privacy, locale, location, clipboard, defaults) rides on, the scanner + active-app selection model all sections consume, the AppLogger.actions category, and the full AppDelegate/SideWindowView wiring. Plans 02 (push/deep links/privacy), 03 (locale/location/clipboard), and 04 (defaults editor/search) expand on this proven slice without architectural change.

Purpose: 03-RESEARCH.md verifies the reset mechanism live (terminate/uninstall idempotency, listapps 33 KB output, keychain device-wide-only gap behind D-02) and pins the SimCtlService pipe deadlock (Pitfall 2) as the load-bearing fix every large-output verb depends on. The scanner must be generic across ALL DerivedData trees because this repo's own DerivedData contains no iOS .app (live-verified).
Output: 3 new source files + 2 new views, 5 modified files, 2 Wave 0 Swift Testing files, one green live-reset smoke on a booted Simulator.
</objective>

<execution_context>
@~/.claude/gsd-core/workflows/execute-plan.md
@~/.claude/gsd-core/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/ROADMAP.md
@.planning/STATE.md
@.planning/phases/03-app-actions/03-CONTEXT.md
@.planning/phases/03-app-actions/03-RESEARCH.md
@.planning/phases/03-app-actions/03-PATTERNS.md
@.planning/phases/03-app-actions/03-VALIDATION.md

Source-of-truth analogs (read before writing each file — PATTERNS.md carries near-verbatim excerpts):
@BoosterSimApp/Services/SimCtlService.swift
@BoosterSimApp/Services/CertificateService.swift
@BoosterSimApp/Services/EnvironmentOverrideService.swift
@BoosterSimApp/Services/XcodeDetector.swift
@BoosterSimApp/Views/SideWindow/tabs/ActionsTabView.swift
@BoosterSimApp/Views/SideWindow/tabs/CaptureTabView.swift
@BoosterSimApp/Views/SideWindow/CertificateSectionView.swift
@BoosterSimApp/Views/SideWindow/network/TrafficFilterBar.swift
@BoosterSimApp/App/AppDelegate.swift
@BoosterSimApp/Views/SideWindow/SideWindowView.swift
@BoosterSimApp/Utilities/AppLogger.swift
@BoosterSimAppTests/NetworkConditionServiceTests.swift
@BoosterSimAppTests/ConditionVerdictTests.swift
</context>

<tasks>

<task type="tracer" tdd="true">
  <name>Task 1: Reset-app end-to-end — seam hardening, DerivedData scanner, AppActionService, app picker, reset section, wiring</name>
  <files>
    BoosterSimApp/Services/SimCtlService.swift,
    BoosterSimApp/Services/DerivedDataAppScanner.swift,
    BoosterSimApp/Services/AppActionService.swift,
    BoosterSimApp/Views/SideWindow/actions/AppPickerBar.swift,
    BoosterSimApp/Views/SideWindow/actions/AppResetSectionView.swift,
    BoosterSimApp/Views/SideWindow/tabs/ActionsTabView.swift,
    BoosterSimApp/App/AppDelegate.swift,
    BoosterSimApp/Views/SideWindow/SideWindowView.swift,
    BoosterSimApp/Utilities/AppLogger.swift,
    BoosterSimAppTests/DerivedDataAppScannerTests.swift,
    BoosterSimAppTests/AppActionServiceTests.swift
  </files>
  <read_first>
    - .planning/phases/03-app-actions/03-RESEARCH.md — Verified simctl Surface rows (terminate, uninstall idempotent-exit-0, get_app_container, listapps 33 KB, spawn launchctl UIKitApplication rows); Problem Domain §1 (reset approaches) and §5 (active-app detection); Pitfalls 2 (pipe deadlock), 3 (uninstall exit 0), 11 (no frontmost verb); Assumptions Log A1-adjacent install caveat
    - .planning/phases/03-app-actions/03-PATTERNS.md — assignments for every file above (analog excerpts + drift guards), Shared Patterns (seam discipline, @MainActor+@Published, weak-self flatMap chains, CollapsibleSection, destructive confirm, test house style), No Analog Found (scanner plist/mtime, picker reconcile)
    - BoosterSimApp/Services/SimCtlService.swift (whole file, 78 lines — the seam being extended: pipes created at lines 47-48, wait-then-read order at lines 53-61)
    - BoosterSimApp/Services/CertificateService.swift lines 14-37 (init-injected deps + published state), 91-101 (resetKeychain + the udid != "booted" refusal), 148-176 (begin/finish/fail/transition quartet + runSimCtl 30s timeout)
    - BoosterSimApp/Services/EnvironmentOverrideService.swift lines 269-278 (write → flatMap → sink chain style, .store(in: &cancellables))
    - BoosterSimApp/Services/XcodeDetector.swift (whole file — caseless-enum pure FS scanner style)
    - BoosterSimApp/Views/SideWindow/tabs/ActionsTabView.swift (whole file, 23 lines — the mount point; EnvironmentOverridesView + deep-link section stay untouched at top)
    - BoosterSimApp/Views/SideWindow/tabs/CaptureTabView.swift lines 10-40 (multi-section VStack(spacing: Spacing.xxs) shell + per-section is…Expanded @State)
    - BoosterSimApp/Views/SideWindow/CertificateSectionView.swift lines 4-37 (udidProvider/deviceNameProvider + confirmationDialog(role: .destructive) wiring)
    - BoosterSimApp/Views/SideWindow/network/TrafficFilterBar.swift lines 4-62 (horizontal pill row + compactRowHeight — AppPickerBar layout analog)
    - BoosterSimApp/App/AppDelegate.swift lines 17-25 (lazy var service block) and 38-49 (sideWindowController construction/pass-down)
    - BoosterSimApp/Views/SideWindow/SideWindowView.swift lines 111-120 (.environmentObject injection chain)
    - BoosterSimApp/Utilities/AppLogger.swift lines 5-15 (static category registry)
    - BoosterSimAppTests/NetworkConditionServiceTests.swift lines 8-45 (makeDefaults isolated suite + transition-test shapes) and BoosterSimAppTests/ConditionVerdictTests.swift (pure input→output style)
    - .planning/codebase/CONVENTIONS.md — Shell Commands section (seam rules) and testing guidance
    - AGENTS.md GitNexus section — run gitnexus_impact upstream on SimCtlService BEFORE editing (callers: EnvironmentOverrideService, CertificateService, StatusBarService, NetworkConditionService, DeepLinkService) and report blast radius in the summary
  </read_first>
  <behavior>
    - DerivedDataAppScannerTests: fixture DerivedData tree (committed into the test bundle, injected root) — scanner returns bundleID + name for every fixture .app under */Build/Products/*-iphonesimulator/, returns NOTHING for macOS/universal product dirs, and orders results by build mtime descending
    - DerivedDataAppScannerTests: two fixture trees containing the SAME bundle ID resolve to exactly one candidate — the most recent mtime — and the older one stays visible in the alternatives list; a symlinked fixture path resolves to the same tree (no duplicate candidates)
    - DerivedDataAppScannerTests: missing/corrupt fixture Info.plist entries are skipped without throwing; an empty root returns []
    - AppActionServiceTests: reset command builders — terminate, listapps presence check, uninstall, install(productPath) arg arrays are exactly the simctl argv forms from 03-RESEARCH.md Verified Surface
    - AppActionServiceTests: listapps XML-plist fixture parses to the installed bundle-ID set; launchctl output fixture parses to the running set via the UIKitApplication prefix; the candidate reconcile (scan ∩ installed, running badged) is a pure function over injected inputs
    - AppActionServiceTests: AppActionOperation transitions — idle→working→idle legal, reentrant working→working rejected, error(String)→idle recoverable (isWorking false after every terminal path)
  </behavior>
  <action>
    NOTE: tracer by design — one story only (detect active app → reset); push/privacy/locale/location/clipboard/defaults arrive in plans 02-04 riding this seam. Every new file under the 200-LOC house target; new files join the BoosterSimApp target automatically via pbxproj synchronized groups (STATE.md Phase 5 decision) — no project edits; the Debug build in verify proves membership. Write both Wave 0 test files FIRST (Swift Testing, red), then implement green. Log through a new AppLogger.actions category only.

    BoosterSimAppTests/DerivedDataAppScannerTests.swift (new): Swift Testing struct with a fixture DerivedData tree committed as test-bundle resources (at minimum: two app bundles with distinct bundle IDs under -iphonesimulator products, one duplicate bundle ID in an older tree, one macOS product dir that must be ignored, one symlinked path alias). Scanner must take an injectable root — never hardcode the real home-DerivedData. Cover the behavior bullets with pure #expect assertions.

    BoosterSimAppTests/AppActionServiceTests.swift (new): house style from NetworkConditionServiceTests — pure command-builder and parse-contract tests plus operation-transition tests. Parsing helpers must be internal static/pure functions taking String/Data so tests run headless with fixture strings (a small listapps XML plist + a launchctl excerpt as inline fixtures); no live device in unit tests.

    BoosterSimApp/Services/SimCtlService.swift (modify — run gitnexus_impact first and record it): three changes, signature-compatible for every existing caller. (1) DEADLOCK FIX: read stdout and stderr CONCURRENTLY with process exit — attach readabilityHandler (or drain both pipes before waiting) and only resolve the Future after exit status AND both EOFs; the current wait-then-read order hangs above the 64 KB pipe buffer (RESEARCH Pitfall 2 — listapps is already 33 KB). (2) STDIN: add an optional stdin: Data? = nil parameter; when present, write it to a standardInput pipe and close it after writing (serves `push <udid> -` in plan 02; nil default keeps all current call sites source-compatible). (3) SERIALIZATION: run invocations through a private serial queue so subprocesses queue instead of interleaving (probe truth: one action pipeline at a time); preserve main-thread delivery of the publisher and the existing print-log line (redact nothing new — args are already the log surface; do not add payload/UDID logging beyond what exists). Keep the AnyPublisher<String, SimCtlError> contract untouched.

    BoosterSimApp/Services/DerivedDataAppScanner.swift (new): caseless `enum DerivedDataAppScanner` (XcodeDetector style) with `struct DiscoveredApp: Equatable, Identifiable` (bundleID, name, productPath, lastBuiltAt) declared alongside. static func scan(root: URL) -> [DiscoveredApp]: glob root/*/Build/Products/*-iphonesimulator/*.app via FileManager, resolve symlinks (resolvingSymlinksInPath) BEFORE dedupe, read each .app/Info.plist via NSDictionary(contentsOf:) for CFBundleIdentifier/CFBundleName (skip entries missing either), take mtime from attributesOfItem, dedupe equal bundle IDs keeping the most recent mtime (alternatives retained in a parallel output or as a non-selected flag — the picker must be able to show them), sort newest-first. Also a static var defaultRoot: URL (home DerivedData) used only by the service layer, so tests always inject a fixture root. Pure FS work, no ObservableObject, no simctl.

    BoosterSimApp/Services/AppActionService.swift (new): @MainActor final class AppActionService: ObservableObject in the CertificateService shell shape — init(simCtl: SimCtlService, certificateService: CertificateService); @Published private(set) var operation: AppActionOperation = .idle, status/result captions, candidates: [DiscoveredApp], runningBundleIDs: Set<String>, installedBundleIDs: Set<String>, activeBundleID: String?. Declare AppActionOperation (idle/working per-verb/error(String), isWorking, canTransition) in the CertificateModels associated-value style (same file or Models — keep file under target). Implement the begin/finish/fail/transition quartet verbatim in shape. Internal static pure helpers, unit-tested: command builders for terminate/listapps/uninstall/install; parseInstalledApps(fromListAppsXML:) -> Set<String> via PropertyListSerialization; parseRunningApps(fromLaunchctlOutput:) -> Set<String> matching the UIKitApplication: prefix. refreshApps(udid:) chains simCtl.run(["listapps", udid]) and simCtl.run(["spawn", udid, "launchctl", "list"]) into those parsers, intersects with DerivedDataAppScanner.scan(root: .defaultRoot), publishes candidates (installed-only; badge = running), defaults activeBundleID to the newest candidate. resetApp(udid:bundle:) = terminate (ignore not-running failure) → listapps presence parse → uninstall → if a DiscoveredApp productPath exists, install attempt with degrade caption on failure (flagged assumption A6 — never claim success when the reinstall step failed) → finish with an honest status caption. Refuse udid.isEmpty || udid == "booted" for every destructive verb (CertificateService.swift:92 discipline). All chains are [weak self] + flatMap + .store(in: &cancellables) with the 30s timeout helper — Combine-only chains, zero coroutine keywords anywhere, and no direct subprocess construction outside the seam.

    BoosterSimApp/Views/SideWindow/actions/AppPickerBar.swift (new): one-row horizontal ScrollView of candidate pills (TrafficFilterBar anatomy, SideWindowMetrics.compactRowHeight, optionPill styling from CaptureTabView) — app name, running badge (SF Symbol dot/green), selected state bound to appActionService.activeBundleID; explicit tap-to-select ONLY (RESEARCH Pitfall 11 — no frontmost guessing); overflow scrolls horizontally; empty state caption "No installed apps found in DerivedData — build and run an app from Xcode first". Design tokens only; a11y labels per row.

    BoosterSimApp/Views/SideWindow/actions/AppResetSectionView.swift (new): CollapsibleSection(title: "App Reset", icon: "arrow.uturn.backward", …) in the CertificateSectionView declaration shape (udidProvider, @EnvironmentObject appActionService, @State confirms). Two actions behind .confirmationDialog: "Reset App Data" (terminate + uninstall + reinstall attempt — confirm message names the app and that its container data is erased) and "Uninstall" (confirm names app removal). Status caption rows driven by operation/status; disabled state when no active app or no booted device (udidProvider nil). Keychain clear UI lands in Task 2 in this same file. No raw layout literals — Spacing/CornerRadius tokens.

    BoosterSimApp/Views/SideWindow/tabs/ActionsTabView.swift (modify): keep EnvironmentOverridesView + the deep-link CollapsibleSection untouched at top; wrap body sections in the CaptureTabView VStack(spacing: Spacing.xxs) shell and append AppPickerBar (pinned near top of the scroll) + AppResetSectionView below the existing sections with per-section is…Expanded @State. Add @EnvironmentObject var appActionService.

    BoosterSimApp/App/AppDelegate.swift (modify): add `lazy var appActionService = AppActionService(simCtl: simCtlService, certificateService: certificateService)` in the lazy block style and pass it into sideWindowController alongside the existing services.

    BoosterSimApp/Views/SideWindow/SideWindowView.swift (modify): extend the .environmentObject chain with appActionService (missing injection = crash on first render of @EnvironmentObject).

    BoosterSimApp/Utilities/AppLogger.swift (modify): add one registry line — static let actions = Logger(subsystem: subsystem, category: "Actions") — matching neighbor formatting.
  </action>
  <verify>
    <automated>xcodebuild -project BoosterSimApp.xcodeproj -scheme BoosterSimApp -destination 'platform=macOS' test -only-testing:BoosterSimAppTests/DerivedDataAppScannerTests -only-testing:BoosterSimAppTests/AppActionServiceTests -parallel-testing-enabled NO && xcodebuild -project BoosterSimApp.xcodeproj -scheme BoosterSimApp -configuration Debug build</automated>
  </verify>
  <acceptance_criteria>
    - Both Wave 0 test files exist, import Testing, use @Test funcs with #expect, and cover every behavior bullet above (fixture-tree scan/filter/dedupe/symlink; arg-array builders; listapps + launchctl parse contracts; operation transitions incl. reentrancy rejection)
    - DerivedDataAppScanner.swift declares a caseless enum with an injectable scan(root:) parameter — the token NSHomeDirectory appears in it at most once (defaultRoot accessor), never inside scan logic; it contains no ObservableObject conformance
    - SimCtlService.swift reads both pipes concurrently with exit (readabilityHandler or read-before-wait — the wait-then-read sequence no longer exists), declares an optional stdin Data parameter with nil default, and routes invocations through a serial queue; its public publisher signature is unchanged
    - The process-launch constructor call occurs zero times across DerivedDataAppScanner.swift, AppActionService.swift, AppPickerBar.swift, and AppResetSectionView.swift combined — every verb goes through the injected seam
    - AppActionService.swift is at or under 200 lines, declares @MainActor final class AppActionService: ObservableObject with init-injected deps, and contains zero coroutine keyword occurrences (Combine chains only)
    - AppResetSectionView.swift wires both destructive buttons inside confirmationDialog with role: .destructive; udid == "booted" or empty is refused before any destructive verb (unit-tested refusal)
    - AppLogger.swift contains static let actions with category "Actions"
    - Both xcodebuild commands exit 0
  </acceptance_criteria>
  <reversibility rating="costly">SimCtlService is the shared seam with five live consumer services — the signature stays source-compatible (verified by the full build), but the serialization behavior and pipe-drain order change every consumer's runtime path; the AppActionService facade + scanner contracts are what plans 02-04 build on.</reversibility>
  <done>One green vertical path: the Actions tab lists real DerivedData-derived installed apps, selecting one and resetting terminates → uninstalls → reinstalls it with an honest status caption; both Wave 0 suites green; app builds; the seam survives a 33 KB listapps output without hanging.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: D-02 destructive keychain clear — red-typed blast-radius confirm, CertificateService delegate, automatic CA reconcile</name>
  <files>
    BoosterSimApp/Services/AppActionService.swift,
    BoosterSimApp/Views/SideWindow/actions/AppResetSectionView.swift,
    BoosterSimAppTests/AppActionServiceTests.swift
  </files>
  <read_first>
    - .planning/phases/03-app-actions/03-CONTEXT.md — D-02 [keychain-clear] verbatim (locked: device-wide-only reality, red-typed confirmation naming blast radius, automatic CA re-reconcile via existing CertificateService)
    - .planning/phases/03-app-actions/03-RESEARCH.md — Verified Surface keychain row (only add-root-cert/add-cert/reset exist; reset is device-wide; items survive uninstall), Pitfall 4, Action Latency table keychain row, Security Domain destructive-ops row
    - BoosterSimApp/Services/CertificateService.swift lines 91-101 (resetKeychain — already runs the device verb, clears the persisted-install record, lands the state machine) and lines 123-144 (reconcileStatus — the re-reconcile entry point)
    - BoosterSimApp/Windows/../Views/SideWindow/SideWindowController.swift lines 78-80 (the existing reconcile-on-simulator-change wiring this task reuses)
    - BoosterSimApp/Views/SideWindow/CertificateSectionView.swift lines 34-37 (confirmationDialog + role: .destructive calling the service)
    - The Task 1 versions of AppActionService.swift and AppResetSectionView.swift
  </read_first>
  <behavior>
    - AppActionServiceTests: clearKeychain operation transitions — idle→resetting→idle legal; reentrant resetting rejected while working; error path lands error(String) then recovers to idle
    - AppActionServiceTests: clearKeychain refuses empty and the ambiguous default UDID token exactly like resetApp does (typed error, no verb issued)
    - AppActionServiceTests: the reconcile call sequence is asserted on a scripted double — reset verb completion is followed by exactly one reconcileStatus trigger (delegate order pinned)
  </behavior>
  <action>

    AppActionService.clearKeychain(udid:): DELEGATE, do not re-implement — call certificateService.resetKeychain(udid:) (it already runs the device-wide verb, clears the persisted-install record, and lands its own state machine correctly) and on completion trigger certificateService.reconcileStatus(udid:) so the local CA is regenerated/reinstalled automatically (D-02's reconcile promise). Guard the same UDID refusals as every destructive verb. Surface progress through AppActionService.operation so the section can show a working state while the certificate service runs; log verb + outcome only (no UDID-bearing detail) through AppLogger.actions.

    AppResetSectionView: add the "Clear Keychain (All Apps)" action — role: .destructive red-typed button inside a .confirmationDialog whose title and message NAME THE BLAST RADIUS per D-02: erases EVERY app's keychain on this Simulator (not just the selected app) AND removes the BoosterSimApp local CA, which is re-generated and re-installed automatically afterward. The wipe call site exists ONLY inside that confirmation closure — no other call path, no default/button-less trigger, disabled when no booted device. After completion the status caption reports the reconcile outcome honestly (e.g. CA re-installed / reconcile failed with the certificate status).
  </action>
  <verify>
    <automated>xcodebuild -project BoosterSimApp.xcodeproj -scheme BoosterSimApp -destination 'platform=macOS' test -only-testing:BoosterSimAppTests/AppActionServiceTests -parallel-testing-enabled NO</automated>
  </verify>
  <acceptance_criteria>
    - AppActionServiceTests covers the three new behavior bullets and is green
    - AppResetSectionView.swift contains exactly one keychain-wipe call site and it sits inside the destructive confirmation closure; the dialog message string mentions both every-app blast scope and the local CA consequence
    - AppActionService.swift contains no second device-keychain verb implementation — the call delegates to CertificateService.resetKeychain (grep: the reset implementation is not duplicated)
    - The test command exits 0
  </acceptance_criteria>
  <reversibility rating="costly">Device-wide keychain wipe is one-way in effect (every app's credentials + the Phase 5 CA) — the human gate IS the red-typed typed confirmation inside this task plus the Task 3 blocking smoke, per the planning context; rated costly (not one-way) so no separate pre-task decision checkpoint is inserted.</reversibility>
  <done>Success criterion 1 complete: reset-app works end-to-end (Task 1) and the D-02 keychain clear runs only behind a blast-radius-naming typed confirmation with automatic CA re-reconcile; unit tests green.</done>
</task>

<task type="checkpoint:human-verify" gate="blocking-human">
  <name>Task 3: Smoke the tracer on a live Simulator — app detection, reset, reinstall degrade, keychain wipe + CA reconcile</name>
  <files>none</files>
  <read_first>
    - .planning/phases/03-app-actions/03-VALIDATION.md — Manual-Only Verifications rows: "Reset app clears state", "Keychain wipe + CA reconcile", and the Per-Task Verification Map rows for reset sequence + scanner
    - .planning/phases/03-app-actions/03-RESEARCH.md — Pitfalls 3 (uninstall exit 0), 4 (keychain kills CA), 11 (no frontmost verb); Assumptions Log A6-adjacent install caveat (degrade path)
  </read_first>
  <action>
    Blocking human checkpoint — the tracer's end-to-end proof needs a booted Simulator, a real DerivedData-built app, and the live device keychain. Prerequisites (user_setup): BoosterSimApp running; one booted Simulator with a non-Apple app built+installed from Xcode carrying visible persisted state; the local CA generated + installed. Execute the seven steps in how-to-verify, recording per-step pass/fail. Step 4 is the flagged-assumption A6 check (reinstall): if the reinstall leg fails, the DOWNGRADE must still be honest (app left uninstalled + caption) — do not approve a false success caption. Step 6 is the D-02 proof: the dialog must name the full blast radius before the wipe, and the CA must reconcile without manual steps.
  </action>
  <verify>
    <human-check>All seven smoke steps observed and recorded pass/fail in the summary; specifically: picker lists only installed DerivedData apps with a running badge on the running one; reset produces a fresh app; the keychain dialog names every-app blast scope + CA consequence and cert trust works again afterward with zero manual steps.</human-check>
  </verify>
  <acceptance_criteria>
    - Summary contains a per-step pass/fail record for all 7 smoke steps
    - Picker candidates = DerivedData ∩ installed, running app badged, selection is explicit (step 1)
    - Reset App Data yields a fresh launch with prior state gone; plain Uninstall removes the app; repeated reset errors nothing (steps 2-4)
    - Keychain dialog names the blast radius; wipe → CA re-reconciles automatically (steps 5-6)
    - No-Simulator degraded state renders disabled controls with no crash (step 7)
  </acceptance_criteria>
  <what-built>The Phase 3 app-actions spine wired end-to-end: SimCtlService seam (concurrent pipe reads, stdin, serialized invocations) → DerivedDataAppScanner (fixture-tested FS scan + plist parse + mtime dedupe) → AppActionService (state-machine facade: refreshApps reconcile, resetApp with reinstall-degrade, clearKeychain delegating to CertificateService + reconcile) → AppPickerBar + AppResetSectionView mounted in ActionsTabView, wired through AppDelegate/SideWindowView, logging via AppLogger.actions. DerivedDataAppScannerTests + AppActionServiceTests green; app builds; success criterion 1 delivered.</what-built>
  <how-to-verify>
    With BoosterSimApp running and the booted Simulator prepared per user_setup:
    1. Open the Actions tab — the picker bar lists the Xcode-built app (name + bundle), with a running badge while it runs; system apps and uninstalled DerivedData leftovers do NOT appear; selection changes on tap
    2. In the app, create visible persisted state (log in / set a preference), then click Reset App Data → confirm → the app terminates, reinstalls from DerivedData; relaunch it — the state is gone (fresh)
    3. Click Uninstall → confirm → the app disappears from the device; the picker drops or badges it accordingly
    4. Click Reset App Data again on the now-uninstalled app — no error, honest caption (idempotent path); if the reinstall leg fails, the caption must say so plainly (A6 degrade — file a note, do not approve a false success)
    5. Network tab → Certificates: confirm the CA is installed. Then Actions → App Reset → Clear Keychain — the RED confirmation names every app's keychains + the local CA; confirm the wipe
    6. Immediately check the Certificates section — the CA re-reconciles automatically (regenerated/reinstalled; trust state restored) with no manual action; re-run a trusted-request flow if convenient
    7. Shut down the Simulator — Actions sections show the disabled/degraded state, no crash; re-boot restores function
  </how-to-verify>
  <resume-signal>Reply "approved" to unblock wave 2 (plan 02 push/deep links/privacy), or describe the failing step — a false success caption on the reinstall degrade or a missing blast-radius name in the keychain dialog requires a fix inside this plan before expansion proceeds.</resume-signal>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| BoosterSimApp → Simulator device state | simctl verbs mutate device state (terminate/uninstall/install/keychain) — UDID scoping is the gate |
| User filesystem (DerivedData) → scanner | Read-only enumeration of all the user's DerivedData trees crosses into broad local data access |
| simctl subprocess stdout/stderr → app | Unbounded-size output crosses the pipe boundary into the app's memory/threads |

## STRIDE Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation Plan |
|-----------|----------|-----------|----------|-------------|-----------------|
| T-03-01 | Tampering/Elevation | Destructive verbs on wrong/ambiguous device (uninstall, keychain reset) | high | mitigate | UDID always from the tracker's active simulator; refuse empty and the ambiguous default UDID token on every destructive verb (CertificateService discipline, unit-tested); confirm dialogs name device + app + blast radius |
| T-03-02 | Denial of Service | SimCtlService pipe deadlock on >64 KB outputs (listapps today) | high | mitigate | Concurrent pipe drains with exit (readabilityHandler) — the wait-then-read order is deleted; verified by structure + the 33 KB listapps call in refreshApps during the Task 3 smoke |
| T-03-03 | Information Disclosure | DerivedData enumeration exposes the user's full app-build inventory | medium | mitigate | Scan is local + read-only; AppLogger.actions logs counts/verbs only — no bundle IDs, paths, or UDIDs; no persistence of scan results beyond session state; nothing leaves the process |
| T-03-04 | Tampering | Device-wide keychain wipe destroying all apps' credentials + Phase 5 CA (D-02) | high | mitigate | Red-typed typed confirmation naming the full blast radius; single call site inside the confirm closure; automatic CertificateService reconcile afterward; blocking smoke step 6 proves the gate |
| T-03-SC | Tampering | Package installs | high | mitigate | Zero package installs this phase — Apple frameworks only (REQ-nfr-03); no SPM change; asserted at the phase gate (plan 05) |
</threat_model>

<verification>
- Task 1/2 automated: DerivedDataAppScannerTests + AppActionServiceTests green via the plan's xcodebuild commands; full Debug build proves target membership (synchronized groups) and source-compatible seam change.
- Task 3: blocking human smoke on a live Simulator (7 steps) — the only honest end-to-end check of criterion 1, the reinstall-degrade honesty (A6), and the D-02 gate + reconcile.
- No SPM/pbxproj package changes this plan.
</verification>

<success_criteria>
- The 6 must_haves truths hold; specifically the live reset proof (fresh state, idempotent repeat, reinstall-or-honest-degrade) and the D-02 keychain gate (blast-radius confirm + automatic CA reconcile) are observed on a live Simulator.
- Both Wave 0 test files green; app builds; the seam keeps all five existing consumer services compiling and survives large outputs.
- Architecture proven well enough that plans 02 (push/deep links/privacy), 03 (locale/location/clipboard), and 04 (defaults editor/search) are additive, not architectural.
</success_criteria>

## Artifacts this phase produces

Created by THIS plan (new symbols):
- DerivedDataAppScanner (+ DiscoveredApp) — BoosterSimApp/Services/DerivedDataAppScanner.swift
- AppActionService (+ AppActionOperation state machine, pure command builders, listapps/launchctl parsers) — BoosterSimApp/Services/AppActionService.swift
- AppPickerBar, AppResetSectionView — BoosterSimApp/Views/SideWindow/actions/
- AppLogger.actions category — BoosterSimApp/Utilities/AppLogger.swift
- Tests: DerivedDataAppScannerTests (fixture DerivedData tree), AppActionServiceTests

Modified: SimCtlService (concurrent pipe reads + stdin + serialized invocations — the seam every Phase 3 verb rides), ActionsTabView (multi-section shell + picker + reset section), AppDelegate (appActionService construction/pass-down), SideWindowView (.environmentObject injection).

Later plans add: PushPayload + PrivacyPermission + push/privacy verbs + DeepLinkService seam migration (02), locale/location/clipboard verbs + section views (03), AppAction catalog + ActionSearchBar + DefaultsEntry + UserDefaultsEditorService + editor view (04), docs + phase gate (05).

<output>
Create `.planning/phases/03-app-actions/03-01-SUMMARY.md` when done
</output>
