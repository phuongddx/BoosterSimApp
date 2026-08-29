# Codebase Structure

**Analysis Date:** 2026-08-29

## Directory Layout

```
BoosterSimApp/
├── BoosterSimApp/              # Main macOS app target source
│   ├── App/                    # App entry and lifecycle
│   ├── Models/                 # Value types and persisted settings
│   ├── Services/               # Business logic and system integration
│   ├── Views/                  # SwiftUI view hierarchy
│   │   ├── MenuBar/            # Menu bar dropdown content
│   │   ├── SideWindow/         # Side panel UI
│   │   │   ├── tabs/           # Tab content views
│   │   │   └── network/        # Network inspection sub-views
│   │   ├── Onboarding/         # First-launch onboarding flow
│   │   ├── Preferences/        # Settings window tabs
│   │   └── Shared/             # Reusable small components
│   ├── Windows/                # NSPanel management and positioning
│   ├── Utilities/              # Cross-cutting helpers
│   └── Assets.xcassets/        # App icon and accent color
├── BoosterSimConnect/          # iOS framework target (network capture injection)
├── booster-sim-cli/            # Standalone SPM CLI package
│   ├── Package.swift
│   └── Sources/boostersim/
│       ├── boostersim.swift    # @main ParsableCommand entry
│       ├── Commands/           # One file per subcommand
│       └── Services/           # CLI-only simctl wrapper
├── BoosterSimAppTests/         # Xcode unit test target
├── BoosterSimAppUITests/       # Xcode UI test target
├── BoosterSimApp.xcodeproj/    # Xcode project
├── .github/workflows/          # CI/CD
├── docs/                       # Project documentation
├── plans/                      # Historical implementation plans
├── scripts/                    # (empty)
└── .claude/                    # Claude Code config and skills
```

## Directory Purposes

**BoosterSimApp/App/:**
- Purpose: Application lifecycle management
- Contains: `AppDelegate.swift` — the central service orchestrator
- Key files: `BoosterSimApp/App/AppDelegate.swift`

**BoosterSimApp/Models/:**
- Purpose: Data types used across the app
- Contains: Plain value types (`struct`, `enum`), persisted settings
- Key files: `AppSettings.swift` (user preferences), `SimulatorWindow.swift` (detected window model), `AXNode.swift` (accessibility tree node), `BuildRecord.swift` (Xcode build entry)

**BoosterSimApp/Services/:**
- Purpose: All business logic, system integrations, and external process management
- Contains: 21 Swift files, each a single `final class: ObservableObject` service (except `CertificateModels.swift` which is pure types)
- Key files: `SimulatorWindowTracker.swift` (window detection), `SimCtlService.swift` (simctl executor), `ConnectService.swift` (network capture), `CaptureService.swift` (screen recording), `CertificateService.swift` (CA trust management)

**BoosterSimApp/Views/:**
- Purpose: All SwiftUI view declarations
- Contains: Organized by feature area (SideWindow, MenuBar, Preferences, Onboarding, Shared)
- Key files: `SideWindow/SideWindowView.swift` (root panel view), `SideWindow/TabBarView.swift` (tab selector), `SideWindow/tabs/CaptureTabView.swift` (screen recording UI)

**BoosterSimApp/Views/SideWindow/tabs/:**
- Purpose: Individual tab content for the side window
- Contains: `CaptureTabView.swift`, `DesignTabView.swift`, `ActionsTabView.swift`, `NetworkTabView.swift`

**BoosterSimApp/Views/SideWindow/network/:**
- Purpose: Network traffic inspection sub-views for the Network tab
- Contains: `TrafficList.swift`, `TrafficRowView.swift`, `TrafficFilterBar.swift`, `TrafficDetailView.swift`, `ConnectStatusBanner.swift`, `ConnectSetupView.swift`, `CurlExporter.swift`, `NetworkEventModel.swift`

**BoosterSimApp/Windows/:**
- Purpose: NSPanel subclass, positioning math, animation
- Contains: `SideWindowController.swift` (panel lifecycle + SwiftUI hosting), `SideWindowPanel.swift` (NSPanel config), `PositionCalculator.swift` (pure frame math), `AXHighlightPanel.swift` (accessibility highlight overlay)

**BoosterSimApp/Utilities/:**
- Purpose: Shared helpers used across layers
- Contains: `AppLogger.swift` (os.Logger instances), `DesignTokens.swift` (spacing/radii/metrics constants), `SpringAnimator.swift` (CADisplayLink spring physics)

**BoosterSimConnect/:**
- Purpose: iOS framework injected into Simulator apps for network capture
- Contains: Single file `BoosterSimConnect.swift` — conditional compilation (`#if DEBUG && targetEnvironment(simulator)`)
- Key files: `BoosterSimConnect/BoosterSimConnect.swift`

**booster-sim-cli/:**
- Purpose: Standalone Swift Package Manager CLI tool for AI-agent Simulator control
- Contains: ArgumentParser-based commands, independent `SimCtlService` (synchronous)
- Key files: `Sources/boostersim/boostersim.swift` (entry), `Sources/boostersim/Commands/` (8 subcommands)

**BoosterSimAppTests/:**
- Purpose: Xcode unit test target
- Contains: `CertificateServiceTests.swift`, `BoosterSimAppTests.swift`

**BoosterSimAppUITests/:**
- Purpose: Xcode UI test target
- Contains: `ScreenshotTests.swift`, `BoosterSimAppUITestsLaunchTests.swift`, `BoosterSimAppUITests.swift`

## Key File Locations

**Entry Points:**
- `BoosterSimApp/BoosterSimAppApp.swift`: SwiftUI `@main` — declares menu bar and settings scenes
- `booster-sim-cli/Sources/boostersim/boostersim.swift`: CLI `@main` — ArgumentParser root command
- `BoosterSimConnect/BoosterSimConnect.swift`: iOS framework entry — `@objc public final class BoosterSimConnect`

**Configuration:**
- `BoosterSimApp/BoosterSimApp/Models/AppSettings.swift`: User preferences (`@AppStorage`)
- `BoosterHealth-Entitlements.plist`: HealthKit entitlement (for Simulator health data features)
- `.github/workflows/ci.yml`: GitHub Actions CI pipeline

**Core Logic:**
- `BoosterSimApp/BoosterSimApp/Services/`: All service implementations
- `BoosterSimApp/BoosterSimApp/Windows/SideWindowController.swift`: Panel management orchestrator
- `BoosterSimApp/BoosterSimApp/Services/SimulatorWindowTracker.swift`: Simulator window detection
- `BoosterSimApp/BoosterSimApp/Services/SimCtlService.swift`: xcrun simctl execution

**Testing:**
- `BoosterSimAppTests/CertificateServiceTests.swift`: Certificate service unit tests
- `BoosterSimAppUITests/ScreenshotTests.swift`: Visual regression tests

## Naming Conventions

**Files:**
- PascalCase: `SimulatorWindowTracker.swift`, `SideWindowController.swift`, `PositionCalculator.swift`
- One type per file (with minor exceptions: `CertificateModels.swift` contains multiple model types)
- Test files: `<Name>Tests.swift` or `<Name>UITests.swift`

**Directories:**
- PascalCase for feature directories: `Views/`, `Services/`, `Models/`, `Windows/`, `Utilities/`
- PascalCase for sub-directories: `SideWindow/`, `MenuBar/`, `Onboarding/`, `Preferences/`, `Shared/`, `network/`, `tabs/`, `Commands/`
- kebab-case for the CLI package directory: `booster-sim-cli/`

**Types:**
- `final class` for all services and controllers: `final class SimulatorWindowTracker: ObservableObject`
- `struct` for models and views: `struct SimulatorWindow: Identifiable`, `struct SideWindowView: View`
- `enum` for tabs, settings, and constants: `enum SideTab: String, CaseIterable`, `enum Spacing`, `enum SideWindowMetrics`

**Methods:**
- camelCase: `startTracking()`, `attach(to:)`, `updatePosition(animated:)`
- `MARK` comments for sections: `// MARK: - Public API`, `// MARK: - Private Helpers`

## Where to Add New Code

**New Feature (with service + UI):**
- Service implementation: `BoosterSimApp/Services/<FeatureName>Service.swift`
- View: `BoosterSimApp/Views/SideWindow/tabs/<FeatureName>TabView.swift`
- Tab enum entry: Add case to `SideTab` in `BoosterSimApp/Views/SideWindow/SideTab.swift`
- Wire in `AppDelegate`: Add `lazy var` in `BoosterSimApp/App/AppDelegate.swift`, pass to `SideWindowController.init(...)` and `embedSwiftUIContent(...)`
- Add `@EnvironmentObject` in `SideWindowView` (`BoosterSimApp/Views/SideWindow/SideWindowView.swift`)

**New Side Window Sub-view (within existing tab):**
- Implementation: `BoosterSimApp/Views/SideWindow/<FeatureName>SectionView.swift` or under a sub-directory like `network/`

**New CLI Subcommand:**
- Command: `booster-sim-cli/Sources/boostersim/Commands/<Name>Command.swift`
- Register: Add to `subcommands` array in `booster-sim-cli/Sources/boostersim/boostersim.swift`

**New Model/Value Type:**
- App models: `BoosterSimApp/Models/<Name>.swift`
- Service-scoped types: Co-locate in the service file or create `<Feature>Models.swift` in `Services/`

**New Utility:**
- Shared helpers: `BoosterSimApp/Utilities/<Name>.swift`
- Design constants: Add to existing enums in `BoosterSimApp/Utilities/DesignTokens.swift`

**New Logger Category:**
- Add `static let` to `AppLogger` enum in `BoosterSimApp/Utilities/AppLogger.swift`

## Special Directories

**.planning/:**
- Purpose: GSD planning artifacts and codebase analysis documents
- Generated: Yes (by GSD tooling)
- Committed: Yes

**plans/:**
- Purpose: Historical implementation plan directories (one per feature)
- Generated: Yes (by GSD tooling)
- Committed: Yes

**docs/:**
- Purpose: Project documentation (architecture, roadmap, design guidelines, code standards, deployment guide)
- Generated: No
- Committed: Yes

**.build-benchmark/:**
- Purpose: Build optimization benchmark data and plan
- Generated: Yes
- Committed: Yes

**.claude/:**
- Purpose: Claude Code configuration, skills, and session state
- Generated: Partially (skills, session-state)
- Committed: Partially (`settings.local.json`, `skills/`)

**BoosterSimApp/Assets.xcassets/:**
- Purpose: App icon and accent color assets
- Generated: No
- Committed: Yes

**scripts/:**
- Purpose: Build/development scripts
- Generated: No
- Committed: Yes (currently empty)

---

*Structure analysis: 2026-08-29*
