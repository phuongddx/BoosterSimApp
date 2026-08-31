# Codebase Structure

**Analysis Date:** 2026-08-31

## Directory Layout

```text
BoosterSimApp/                      # repo root
├── BoosterSimApp.xcodeproj/        # Xcode project — 4 targets: app, unit tests, UI tests, BoosterSimConnect framework
├── BoosterSimApp/                  # main app target source
│   ├── App/                        # AppDelegate (composition root)
│   ├── Models/                     # value types, settings, wire-contract models
│   ├── Services/                   # ObservableObject services + pure helpers + process seams
│   ├── Utilities/                  # design tokens, logger, pure rendering, animation
│   ├── Windows/                    # NSPanel subclasses + AppKit controllers
│   ├── Views/                      # SwiftUI views, grouped by surface
│   │   ├── MenuBar/                # MenuBarExtra content
│   │   ├── Onboarding/             # first-launch 4-step flow
│   │   ├── Preferences/            # Settings scene tabs
│   │   ├── Shared/                 # reusable atoms (CollapsibleSection, AccentButton, StatusBadge)
│   │   ├── SideWindow/             # side panel root + tab sections
│   │   │   ├── tabs/               # one view per tab (Capture, Design, Actions, Network)
│   │   │   ├── actions/            # Actions tab sections (locale, push, privacy, defaults, …)
│   │   │   ├── capture/            # Capture tab sections (export, recording)
│   │   │   ├── network/            # Network tab: traffic list/detail, conditions, block rules
│   │   │   └── (root files)        # SideWindowView, TabBarView, Design* sections, DeepLink, Certificates, …
│   │   └── Overlay/                # design-overlay tool views (grid, ruler, magnifier, safe area, comparison)
│   ├── BoosterSimAppApp.swift      # @main entry
│   └── Assets.xcassets/            # AppIcon, AccentColor
├── BoosterSimAppTests/             # unit tests (XCTest + Swift Testing), hosted in the app
├── BoosterSimAppUITests/           # XCUITest launch/screenshot tests
├── BoosterSimConnect/              # iOS framework target, loaded into Simulator apps (DEBUG)
├── booster-sim-cli/                # standalone SwiftPM executable (boostersim CLI)
├── docs/                           # living architecture/standards docs + journals
├── plans/                          # dated implementation-plan directories (MMDD-HHMM-slug)
├── scripts/                        # helper scripts
├── .planning/                      # GSD state: ROADMAP.md, PROJECT.md, phases/, codebase/
├── BoosterHealth-Entitlements.plist# entitlements (app is non-sandboxed)
└── AGENTS.md / CLAUDE.md / README.md
```

## Directory Purposes

**`BoosterSimApp/App/`:**
- Purpose: Application composition root
- Contains: `AppDelegate.swift` — owns every service, panel, controller; lifecycle wiring; onboarding window
- Key files: `BoosterSimApp/App/AppDelegate.swift`

**`BoosterSimApp/Services/`:**
- Purpose: All domain logic and state. 36 files, roughly four families: (1) tracking core (`SimulatorWindowTracker`, `WindowEnumerator`, `WindowObserver`, `PermissionManager`), (2) feature services (one per tab capability), (3) pure helpers (`PositionCalculator`-style: `OverlayGeometry`, `SafeAreaCatalog`, `DerivedDataAppScanner`), (4) process/network seams (`SimCtlService`, `PulseServer`/`PulseClientConnection`/`PulsePacketDecoder`, `CommandServer`)
- Contains: `@MainActor final class … ObservableObject` services, static pure enums, same-type extension files
- Key files: `SimulatorWindowTracker.swift`, `SimCtlService.swift`, `CaptureService.swift`, `AppActionService.swift`, `DesignOverlayService.swift` (+`+Presets.swift`, `+Import.swift`), `PixelSamplerService.swift`, `ConnectService.swift`, `NetworkConditionService.swift`, `CommandServer.swift`

**`BoosterSimApp/Models/`:**
- Purpose: Value types, settings, enums, and wire-contract models — no AppKit windows, no business logic beyond pure predicates
- Contains: structs/enums, `AppSettings` (`@AppStorage` singleton), protocol-adjacent types (`PrivacyPermission` TCC strings, `PushPayload`, `DefaultsEntry`)
- Key files: `AppSettings.swift`, `BoosterCommand.swift`, `AppAction.swift`, `AppActionModels.swift`, `SimulatorWindow.swift`

**`BoosterSimApp/Windows/`:**
- Purpose: AppKit window surfaces and their controllers — everything that owns an `NSPanel`
- Contains: `SideWindowController` + `SideWindowPanel`, `DesignOverlayController` (+`+InputMode.swift`) + `DesignOverlayPanel`, `AXHighlightPanel`, `CaptureThumbnailPanel`, pure `PositionCalculator`
- Key files: `SideWindowController.swift`, `DesignOverlayController.swift`, `DesignOverlayPanel.swift`

**`BoosterSimApp/Views/`:**
- Purpose: All SwiftUI. Grouped by surface; the side panel is further grouped by tab then section
- Contains: `SideWindow/SideWindowView.swift` (root, environment-object consumer), `SideWindow/tabs/` (4 tab roots), `SideWindow/actions|capture|network/` (section views), design sections at `SideWindow/` root (`DesignComparisonView`, `DesignToolsSection`, `DesignSafeAreaSection`, `DesignPresetsSection`), `Overlay/` tool views, `MenuBar/`, `Onboarding/`, `Preferences/`, `Shared/` atoms
- Key files: `SideWindow/SideWindowView.swift`, `SideWindow/tabs/{CaptureTabView,DesignTabView,ActionsTabView,NetworkTabView}.swift`, `Overlay/MagnifierView.swift`, `Overlay/RulerOverlayView.swift`

**`BoosterSimApp/Utilities/`:**
- Purpose: Cross-cutting, dependency-light helpers
- Contains: `DesignTokens.swift` (layout constants), `AppLogger.swift` (os.Logger namespace), `SpringAnimator.swift` (display-link spring), `CaptureCompositor.swift` (pure CG rendering), `CaptureFilename.swift`
- Key files: `DesignTokens.swift`, `AppLogger.swift`

**`BoosterSimConnect/`:**
- Purpose: iOS framework (its own Xcode target) loaded into Simulator apps via `Bundle.load()` in DEBUG builds; captures URLSession traffic (Pulse/PulseProxy) and enforces pushed network conditions
- Contains: `BoosterSimConnect.swift` (entry/activation), `BoosterNetworkProtocol.swift`, `BoosterCommandClient.swift`, `CommandFrameAssembler.swift`, `NetworkConditionController.swift` (mirror of `Models/BoosterCommand.swift`), `ThrottlePacing.swift`
- Key files: `BoosterSimConnect/BoosterSimConnect.swift`, `BoosterSimConnect/NetworkConditionController.swift`

**`BoosterSimAppTests/`:**
- Purpose: Unit tests (XCTest + Swift Testing) with headless seams (`ScriptedSimCtl.swift`, cache injection)
- Key files: `AppActionServiceTests.swift`, `OverlayPersistenceTests.swift`, `PixelSamplerTests.swift`, `SafeAreaCatalogTests.swift`, `RulerMathTests.swift`, `GridGeometryTests.swift`, `PushPayloadTests.swift`, `UserDefaultsEditorServiceTests.swift`, `ScriptedSimCtl.swift`

**`BoosterSimAppUITests/`:**
- Purpose: XCUITest launch/screenshot smoke tests
- Key files: `ScreenshotTests.swift`, `BoosterSimAppUITestsLaunchTests.swift`

**`docs/`:**
- Purpose: Hand-maintained architecture and standards documentation (kept current with code), plus journals
- Key files: `system-architecture.md`, `code-standards.md`, `codebase-summary.md`, `project-roadmap.md`

**`plans/`:**
- Purpose: Per-task implementation plans, named `MMDD-HHMM-slug/` (e.g. `plans/0411-2219-booster-sim-connect-activation/`)
- Generated: No (human/agent authored); Committed: Yes

**`.planning/`:**
- Purpose: GSD workflow state — `ROADMAP.md`, `PROJECT.md`, `REQUIREMENTS.md`, `STATE.md`, `phases/` (RESEARCH/PLAN/VALIDATION per phase), `codebase/` (these documents)
- Generated: Workflow-managed; Committed: Yes

## Key File Locations

**Entry Points:**
- `BoosterSimApp/BoosterSimAppApp.swift`: `@main` SwiftUI App — `MenuBarExtra` + `Settings` scenes, delegate adaptor
- `BoosterSimApp/App/AppDelegate.swift`: all construction/wiring; read this first to find who owns what

**Configuration:**
- `BoosterSimApp.xcodeproj/project.pbxproj`: targets, build settings (`MACOSX_DEPLOYMENT_TARGET = 26.2`, `SWIFT_VERSION = 5.0`, `INFOPLIST_KEY_LSUIElement = YES`)
- `BoosterHealth-Entitlements.plist`: entitlements (non-sandboxed app)
- `BoosterSimApp/Utilities/DesignTokens.swift`: all layout constants
- `booster-sim-cli/Package.swift`: standalone CLI SwiftPM manifest

**Core Logic:**
- Tracking: `BoosterSimApp/Services/SimulatorWindowTracker.swift` (+ `WindowObserver.swift`, `WindowEnumerator.swift`)
- Actions domain: `BoosterSimApp/Services/AppActionService.swift` — public verbs in the class, argv in `nonisolated static` builder extensions at the bottom of the file
- Overlay math: `BoosterSimApp/Services/OverlayGeometry.swift`, `SafeAreaCatalog.swift`; input machine `BoosterSimApp/Windows/DesignOverlayController+InputMode.swift`
- Wire contract: `BoosterSimApp/Models/BoosterCommand.swift` ↔ `BoosterSimConnect/NetworkConditionController.swift` (kept semantically identical)

**Testing:**
- Unit: `BoosterSimAppTests/*Tests.swift` (file-per-type mirror; pure-logic tests for builders, geometry, persistence, payloads)
- UI: `BoosterSimAppUITests/`

## Naming Conventions

**Files:**
- PascalCase, file name matches the primary type: `SideWindowController.swift` declares `SideWindowController`
- Same-type extensions get a `+Concern` suffix: `DesignOverlayService+Presets.swift`, `DesignOverlayService+Import.swift`, `DesignOverlayController+InputMode.swift` — used to hold files under the ~200 LOC standard
- Suffixes encode role: `*Service` (state/verbs), `*Controller` (AppKit window owner), `*Panel` (NSPanel subclass), `*View`/`*Section`/`*Tab` (SwiftUI), `*Tests` (unit tests)
- Pure helpers carry no suffix: `PositionCalculator`, `OverlayGeometry`, `CaptureCompositor`, `SafeAreaCatalog`, `SpringAnimator`

**Directories:**
- Lowercase plural for layers: `Models/`, `Services/`, `Utilities/`, `Views/`, `Windows/`, `App/`
- Views subgrouped by surface in lowercase: `MenuBar/`, `Onboarding/`, `Preferences/`, `Shared/`, `SideWindow/` (with `actions/`, `capture/`, `network/`, `tabs/`), `Overlay/`

**Code:**
- Every file uses `// MARK: -` sections in the order Imports → Properties → Lifecycle → Public Methods → Private Methods → Extensions (see `docs/code-standards.md`)
- `@MainActor final class` for services/controllers; `private(set) @Published` for exposed state; `[weak self]` in all sinks
- Swift types PascalCase, members camelCase; settings keys are camelCase strings (`captureExportFormat`, `sideWindowPosition`)

## Where to Add New Code

**New feature service (a new panel capability):**
1. Create `BoosterSimApp/Services/<Name>Service.swift` — `@MainActor final class … ObservableObject`, `@Published private(set)` state, sync API
2. Construct it in `BoosterSimApp/App/AppDelegate.swift` (eager `let` or `lazy var`, following the existing grouping)
3. Pass it into `SideWindowController.init` and add it to the `.environmentObject(…)` chain in `embedSwiftUIContent` (`BoosterSimApp/Windows/SideWindowController.swift:145-181`)
4. Consume via `@EnvironmentObject` in the relevant section view; add a `#Preview` fixture following `BoosterSimApp/Views/SideWindow/SideWindowView.swift:96-127`
5. Tests in `BoosterSimAppTests/<Name>ServiceTests.swift` with injected seams (see `ScriptedSimCtl.swift`, `PixelSamplerService` injectable closures)

**New simctl-backed verb:**
- Put argv construction in a `nonisolated static func` extension of the owning service (pure, testable), run it through `SimCtlService` / `runVerb`/`runChain` — reference `BoosterSimApp/Services/AppActionService.swift:724-808`

**New Actions-tab section:**
- View: `BoosterSimApp/Views/SideWindow/actions/<Name>SectionView.swift`; register in `AppActionCatalog` (`BoosterSimApp/Models/AppAction.swift`) so search and mount order come from the catalog

**New Design-overlay tool view:**
- View: `BoosterSimApp/Views/Overlay/<Name>View.swift`; add a slot to `OverlayLayer` if it needs its own band and `install` it in `DesignOverlayController.init` (`BoosterSimApp/Windows/DesignOverlayController.swift`); state goes on `DesignOverlayService` with write-through persistence; a readout/CTA section goes under `BoosterSimApp/Views/SideWindow/` (see `DesignToolsSection.swift`)

**New tab (beyond Capture/Design/Actions/Network):**
- Add a case to `SideTab` (`BoosterSimApp/Views/SideWindow/SideTab.swift`), a root view in `BoosterSimApp/Views/SideWindow/tabs/`, and a `switch` case in `SideWindowView.tabContent`

**New model/value type:**
- `BoosterSimApp/Models/<Name>.swift`; wire-contract types that cross to the framework must be mirrored in `BoosterSimConnect/` and covered by payload tests

**New utility (pure, reusable):**
- `BoosterSimApp/Utilities/`; layout constants must extend `DesignTokens.swift`, logging concerns must extend `AppLogger.swift`

**Tests:**
- `BoosterSimAppTests/<Type>Tests.swift` mirroring the type name; keep tests headless via seams — no live Simulator, no ScreenCaptureKit, no real windows

## Special Directories

**`BoosterSimApp/Assets.xcassets/`:**
- Purpose: App icon and accent color
- Generated: No; Committed: Yes

**`plans/`:**
- Purpose: Archived per-task plan documents (RESEARCH/PLAN/reports per slug)
- Generated: By GSD workflows; Committed: Yes

**`.planning/`:**
- Purpose: GSD project state consumed by plan/execute phases
- Generated: By GSD workflows; Committed: Yes

**`.gsd/`, `.omx/`, `.build-benchmark/`, `.gitnexus/`, `.swift-module-cache/`:**
- Purpose: Tool state, agent artifacts, build benchmarks, code index, Swift module cache
- Generated: Yes; Committed: No (local tooling artifacts)

**`docs/journals/`:**
- Purpose: Dated engineering journal entries
- Generated: Manual; Committed: Yes

---

*Structure analysis: 2026-08-31*
