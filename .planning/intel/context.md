# Ingested Context (from DOC-classified docs)

Running notes keyed by topic. All entries carry source attribution for provenance.

## topic: architecture
- source: docs/system-architecture.md
- SwiftUI App + AppKit hybrid: `@main` SwiftUI entry (MenuBarExtra `.menu` style + Settings
  scene) with `@NSApplicationDelegateAdaptor`; `AppDelegate` (@MainActor, ObservableObject)
  owns and wires all core/feature services; onboarding NSWindow on first launch.
- Core services: SimulatorWindowTracker (dual-mode detection: WindowEnumerator 0.5s polling
  fallback + WindowObserver AXObserver per-PID real-time events; NSWorkspace notifications),
  PermissionManager (Accessibility, Screen Recording, DerivedData via security-scoped
  bookmarks), WindowEnumerator (CGWindowListCopyWindowInfo, Quartz→AppKit Y flip),
  WindowObserver (AXObserver C-callback bridging, refcon retain/release), XcodeDetector
  (pure filesystem path checks, no process execution).
- Feature services: EnvironmentOverrideService (instant a11y toggles via `xcrun simctl spawn`),
  StatusBarService (4 presets + custom via `xcrun simctl ui`), BuildStatsService (DerivedData
  log polling every 5s, last 30 records), AXInspectorService (lazy AX tree walk + highlight),
  CameraService (AX menu automation: I/O → Camera → FaceTime HD), CertificateService /
  CertificateStore / CertificateModels (local CA via /usr/bin/openssl, keychain install,
  rotate/reset, state persistence, 0o600 permissions under Application Support), SimCtlService
  (centralized xcrun simctl executor).
- Connect pipeline: ConnectService (@MainActor, wraps PulseServer, converts PulseDecodedEvent →
  NetworkEvent, maps taskCompleted / skips taskCreated, 500-event cap, connection state machine
  disconnected → searching → connected) → PulseServer (NWListener TCP, Bonjour `_pulse._tcp.`,
  OS-assigned port) → PulseClientConnection (per-client receive loop, state machine connecting →
  waitingHello → active → disconnected, 10 MB buffer cap, handshake/ping-pong) →
  PulsePacketDecoder (pure static: 5-byte header [code: UInt8][contentSize: UInt32 BE], zlib
  payloads, Codable structs).
- Window management: SideWindowPanel (NSPanel, .floating, hidesOnDeactivate=false,
  canJoinAllSpaces + fullScreenAuxiliary, isReleasedWhenClosed=false, hides when Simulator
  loses focus); SideWindowController (Combine sink on tracker.$activeSimulator, certificate
  trust reconciliation on Simulator change, SpringAnimator tracking, side-switch snap, reduced
  motion → rigid 1:1, content-driven sizing with 400pt floor, Cmd+W interception);
  PositionCalculator (pure enum, left/right/bottom/dynamic frames, dynamic prefers right,
  NSScreen best-containment); AXHighlightPanel (orange border overlay, auto-hide 2.5s).
- Views: MenuBarView (Cmd+B toggle, simulator list, settings, quit); SideWindowView (4 tabs:
  Capture / Design / Actions / Network via SideTab + TabBarView); Network tab receives
  ConnectService (@ObservedObject) with ConnectStatusBanner, ConnectSetupView (3-step setup +
  copy-to-clipboard), TrafficFilterBar, TrafficList (auto-scroll, empty state), TrafficRowView,
  TrafficDetailView (Summary/Headers/Body/Metrics sheet + Copy as cURL), CurlExporter (redacts
  sensitive headers); DeviceHeaderView, CollapsedStripView (28pt + 2pt amber stripe),
  StatusBarSectionView, EnvironmentOverridesView, CertificateSectionView,
  BuildStatsSectionView/BuildChartView, AXTreeView, CameraView; shared atoms: FeatureSectionView,
  FeatureRowView, AccentButton, StatusBadge, CollapsibleSection; PreferencesView
  (General/About); OnboardingContainerView (4 steps).
- Utilities: DesignTokens (Spacing, CornerRadius, SideWindowMetrics, OnboardingMetrics,
  PreferencesMetrics — single source of truth); SpringAnimator (CADisplayLink spring physics,
  stiffness=280, damping=22, rest threshold 0.5pt, snapTo() for side-switches); AppLogger
  (static os.Logger per concern, subsystem com.nextlabs.BoosterSimApp).
- Concurrency model: everything on @MainActor / main queue / CFRunLoopGetMain; Swift 6 strict
  concurrency at compile time; no async/await — Combine @Published + Timer only.

## topic: architecture-key-design-decisions
- source: docs/system-architecture.md
- Recorded decisions (none ADR-formalized, none locked): SwiftUI @main +
  @NSApplicationDelegateAdaptor; MenuBarExtra .menu style; Settings scene (Cmd+); NSPanel over
  NSWindow; dual-mode tracking (poll + AXObserver); `xcrun simctl spawn` for env overrides;
  NWListener + Bonjour for Connect (macOS hosts TCP server, Simulator apps connect —
  zero-config); BoosterSimConnect as loadable framework (Bundle.load, DEBUG builds only);
  zero external dependencies (⚠ conflicts with repo state — see INGEST-CONFLICTS.md);
  non-sandboxed (required for Accessibility API, CGWindowList, simctl control).

## topic: code-standards
- source: docs/code-standards.md
- Language/runtime: Swift 6 strict concurrency (no @unchecked Sendable shortcuts), macOS 15
  Sequoia minimum, Xcode 16.3+, no async/await (Combine @Published + Timer).
- Files: PascalCase matching primary type; keep under 200 LOC, split by concern; MARK order
  (Properties, Lifecycle, Public Methods, Private Methods, Extensions).
- Concurrency: @MainActor on UI/AppKit-owning classes; Combine sinks and Timers on .main;
  AXObserver callbacks on CFRunLoopGetMain; final class preferred.
- State: services publish via @Published; @AppStorage for user settings (no raw UserDefaults
  in views); @ObservedObject/@EnvironmentObject, no @StateObject in non-owning views; no
  @State for shared state.
- Design tokens mandatory — never hardcode layout values (Spacing, CornerRadius,
  SideWindowMetrics, OnboardingMetrics from DesignTokens.swift); amber accent
  #E8720C/#F59E0B via asset catalog; semantic colors; SF Pro + SF Symbols exclusively.
- View composition: small focused views; split when body exceeds ~40 lines; shared atoms in
  Views/Shared/.
- Errors/logging: try/catch everywhere, never try!; permission failures non-fatal (log +
  degraded state); AppLogger with service-name prefixes and levels debug/info/warning/error;
  never log sensitive data (UDIDs, paths, tokens).
- Memory: [weak self] in sinks/Timers; AXObserver refcon passRetain balanced with release();
  NSPanel isReleasedWhenClosed=false.
- Accessibility: accessibilityLabel on icon-only buttons; Reduce Motion → 0.1s animations;
  prefer semantic Label.
- Shell: all xcrun simctl through SimCtlService.spawn() with UDID; check UDID availability
  (may be nil without Screen Recording); parse String/JSON; handle non-zero exits.
- Tab navigation: SideTab enum (capture, design, actions, network) + TabBarView; tab switch
  spring 0.25/0.8 (linear 0.1s Reduce Motion); content views tab-agnostic, own their state.
- Prohibited: sandboxing bypass hacks; DispatchQueue.global() for UI work; @unchecked Sendable
  without justification; hardcoded localized strings; try!/as! on user data; direct subprocess
  spawning.

## topic: codebase-inventory
- source: docs/codebase-summary.md
- Stats: Swift 6 strict concurrency; frameworks AppKit/SwiftUI/Combine/CoreGraphics/
  ApplicationServices/ServiceManagement/QuartzCore/Network; 73 Swift files (~6,556 LOC);
  targets BoosterSimApp (macOS), BoosterSimConnect (iOS framework), test targets.
  External dependencies per this doc: Pulse/PulseProxy SPM (BoosterSimConnect framework only —
  understates actual linkage, see INGEST-CONFLICTS.md). Tests: BoosterSimAppTests
  (scaffold + CertificateServiceTests), BoosterSimAppUITests (scaffolds).
- Structure: BoosterSimApp target (App/, Models/ — SimulatorWindow, AppSettings, BuildRecord,
  AXNode; Services/ — 17 services incl. full Connect pipeline and certificate stack;
  Windows/ — SideWindowPanel, SideWindowController, PositionCalculator, AXHighlightPanel;
  Views/ — MenuBar, SideWindow (+ tabs/, network/), Preferences, Onboarding, Shared;
  Utilities/ — AppLogger, DesignTokens, SpringAnimator); BoosterSimConnect/BoosterSimConnect.swift
  (PulseProxy activation + RemoteLogger, 65 LOC); plans/reports.
- Largest files: TrafficDetailView 295 (split candidate), EnvironmentOverrideService 279
  (split candidate), SideWindowController 234 (monitor growth), NetworkEventModel 208,
  SimulatorWindowTracker 199, CertificateService 195, PulseClientConnection 183,
  CertificateSectionView 177, PulsePacketDecoder 174.
- Feature status matrix: Capture tab and Design tab = placeholders; Actions/Environment =
  complete (11 toggles); Actions/Quick Actions = placeholder; Network Connect, Traffic Viewer,
  Certificates = complete; Network/Throttle + Block = placeholder. Standalone complete views
  not yet wired into tabs: StatusBarSectionView, BuildStatsSectionView/BuildChartView,
  AXTreeView, CameraView.
- Note: this inventory predates the BoosterHealth removal (see INGEST-CONFLICTS.md) and does
  not reflect that the working tree contains no health feature files.

## topic: deployment
- source: docs/deployment-guide.md
- Dev build: macOS 15 Sequoia+, Xcode 16.3+, iOS Simulator installed. Build via
  `xcodebuild -project BoosterSimApp.xcodeproj -scheme BoosterSimApp -configuration Debug build`
  or open in Xcode (Cmd+R).
- First run: menu-bar bolt icon → onboarding window → grant Accessibility → grant Screen
  Recording → open Simulator (panel attaches). Without Accessibility: 0.5s polling fallback
  (functional, less responsive). Without Screen Recording: device names render as
  "Simulator (ID: XXXX)". DerivedData optional via Preferences → General.
- Distribution (future, Phase 7): code signing via team ID; archive + exportArchive +
  notarytool submit --wait + stapler staple; DMG via hdiutil (UDZO, volname "BoosterSim");
  App Store would require entitlements review (sandbox incompatible with current API usage —
  AXIsProcessTrusted, CGWindowListCopyWindowInfo, AXObserverCreate, xcrun simctl spawn).
- Sandbox: non-sandboxed (ENABLE_APP_SANDBOX = NO) by requirement.
- Version scheme: MAJOR.MINOR.PATCH semver — major = breaking architecture change, minor =
  feature phase complete, patch = bug fix. Current: 0.1.0 (MVP).

## topic: health-data-generator-discovery
- source: docs/journals/2026-03-28-health-data-generator-discovery.md
- Root constraint: `xcrun simctl` provides zero HealthKit commands (verified on Xcode 16);
  HealthKit data can only be written by an iOS app running in the Simulator via HKHealthStore.
- Chosen solution: minimal iOS companion app BoosterHealth bundled in
  BoosterSimApp.app/Contents/Resources/, installed via `simctl install`, triggered via URL
  scheme `boosterhealth://generate?preset=active_day&date=...`; writes 9 data types (steps,
  heart rate, HRV, resting HR, blood oxygen, active energy, distance, sleep, workouts).
- Rejected alternatives: XCTHealthKit (needs Xcode test runner, too heavy), HealthKitUtility
  package (external dependency risk).
- Plan: plans/0328-1642-health-data-generator/plan.md — 5 phases, 12h (target setup 1h, iOS
  companion 4h, macOS HealthDataService 2h, UI 3h, integration 2h).
- Key risk: HealthKit auth dialog on first companion launch; needs UX guidance in side panel
  pre-launch.
- ⚠ Implementation was later REMOVED from the repo — see INGEST-CONFLICTS.md.

## topic: health-data-generator-implementation
- source: docs/journals/2026-03-28-health-data-generator.md
- Reported 5-phase completion (status "Resolved", 2026-03-28): 7 files — BoosterHealth app
  (BoosterHealthApp, HealthPayload URL-scheme parser, HealthDataGenerator via HKHealthStore
  incl. HKWorkoutBuilder continuations), HealthDataService (simctl orchestration, 4 presets,
  idle → generating → success/error state machine, 3s auto-reset), HealthDataSectionView
  (2×2 grid, manual controls, clear button), CollapsibleSection extraction, Shell Script
  build phase copying BoosterHealth.app into Resources.
- Build lessons: Xcode rejected Copy Files phase ("Multiple commands produce Info.plist" —
  PBXFileSystemSynchronizedRootGroup auto-picking root Info.plists); pivot to explicit
  mkdir -p / cp -r shell script; ENABLE_USER_SCRIPT_SANDBOXING=NO required for cross-target
  access (accepted for internal tooling).
- Lessons: iOS companion apps in macOS need explicit orchestration (simctl install + URL
  scheme), not .app-resource embedding; shell script build phases as Xcode pressure-relief
  valve; HKWorkoutBuilder with continuations over deprecated init; state machine prevents
  races on rapid preset clicks.
- ⚠ SUPERSEDED BY REPO STATE: git history shows the feature added (9bf180c) then removed
  (3b1015f "refactor: remove BoosterHealth companion app and health data service"); no
  BoosterHealth/ or Health*.swift files exist in the working tree. See INGEST-CONFLICTS.md.

## topic: connect-transport-rewrite
- source: docs/journals/2026-04-12-booster-sim-connect-activation.md
- Context: original NWBrowser client-mode discovery (commit b144e1e) was architecturally
  backwards — Simulator apps are Pulse clients, not servers. Full rewrite to NWListener
  server-mode: BoosterSimApp hosts TCP server advertising `_pulse._tcp.` via Bonjour;
  Simulator apps running BoosterSimConnect connect to it. 35 files changed, 4,139 lines
  inserted (journal states "zero external dependencies added" for that changeset).
- Reverse-engineered Pulse wire protocol: 5-byte header [code: UInt8][contentSize: UInt32 BE];
  zlib-compressed body; code 10 (networkTaskCompleted) body = [3× UInt32 BE manifest]
  [JSON event][request body][response body]; code 0 clientHello = JSON device+app info;
  code 6 ping/pong keepalive. Code 8 (taskCreated) deliberately skipped for MVP (no
  response/error/timing data).
- Critical crash fix: `withUnsafeBytes { $0.load(as: UInt32.self) }` crashes on misaligned
  Data slices — replaced with copyBytes pattern (memcpy, alignment-free).
- Cross-platform embedding: iOS Simulator framework cannot live in Contents/Frameworks/
  (macOS bundle validation is platform-strict) — Run Script copies pre-built framework to
  Contents/Resources/ with graceful fallback when missing; Xcode refuses nested xcodebuild
  for the same project (two-step pre-build workflow).
- UI layer: 7 view files (TrafficList, TrafficRowView, TrafficDetailView 4-tab sheet,
  TrafficFilterBar, ConnectSetupView, ConnectStatusBanner, CurlExporter with sensitive-header
  redaction); ConnectService wraps PulseServer, 500-event ring buffer.
- Root causes: transport contract not verified before building pipeline; Apple bundle
  validation undocumented platform strictness; Swift Data-slice alignment trap.
- Open items from journal: end-to-end test with real iOS app embedding BoosterSimConnect;
  verify Bonjour discoverability from Simulator; 10 MB buffer behavior under load; Code 8
  (taskCreated) support; replace placeholder timing data in TrafficDetailView metrics with
  real PulseMetrics; evaluate NWParameters.includePeerToPeer.
