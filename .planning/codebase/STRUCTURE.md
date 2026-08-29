# Codebase Structure

**Analysis Date:** 2026-08-29

## Directory Layout

```
BoosterSimApp/                        # Xcode project root
├── BoosterSimApp/                    # Main app target source
│   ├── App/                          # App lifecycle
│   ├── Models/                       # Data types (value types)
│   ├── Services/                     # Business logic & external integrations
│   ├── Windows/                      # AppKit window management
│   ├── Views/                        # SwiftUI views
│   │   ├── SideWindow/               # Floating panel UI (4 tabs)
│   │   │   ├── tabs/                 # Tab content views
│   │   │   └── network/              # Network tab subviews + models
│   │   ├── MenuBar/                  # Menu bar dropdown content
│   │   ├── Preferences/              # Preferences window (General, About)
│   │   ├── Onboarding/               # First-launch onboarding flow
│   │   └── Shared/                   # Reusable view components
│   ├── Utilities/                    # Cross-cutting helpers
│   └── Assets.xcassets/              # Asset catalog (app icon, accent color)
├── BoosterSimConnect/                # iOS SPM framework (PulseProxy activation)
├── booster-sim-cli/                  # SPM CLI tool (ArgumentParser)
│   └── Sources/boostersim/
│       ├── boostersim.swift          # CLI entry point
│       ├── Commands/                 # Subcommand implementations
│       └── Services/
│           └── SimCtlService.swift   # CLI's own simctl wrapper
├── BoosterSimAppTests/               # Unit tests
├── BoosterSimAppUITests/             # UI tests
├── BoosterSimApp.xcodeproj/         # Xcode project
├── docs/                             # Project documentation
│   └── journals/                     # Session journals
├── plans/                            # Historical implementation plans
│   └── reports/                      # Plan execution reports
├── scripts/                          # Build/utility scripts
├── .github/workflows/                # CI (GitHub Actions)
├── .claude/                          # Claude agent config, skills, memory
├── .planning/                        # GSD planning artifacts
├── .build-benchmark/                 # Build optimization notes
└── CLAUDE.md / AGENTS.md / README.md
```

## Directory Purposes

**`BoosterSimApp/BoosterSimApp/App/`:**
- Purpose: Application lifecycle management and service wiring
- Contains: `AppDelegate.swift` (service container, tracking startup, onboarding)
- Key files: `BoosterSimApp/App/AppDelegate.swift`

**`BoosterSimApp/BoosterSimApp/Models/`:**
- Purpose: Value-type data structures shared across services and views
- Contains: `SimulatorWindow.swift`, `AXNode.swift`, `BuildRecord.swift`, `AppSettings.swift`
- Key files: `BoosterSimApp/Models/AppSettings.swift` (also contains `SideWindowPosition` enum)

**`BoosterSimApp/BoosterSimApp/Services/`:**
- Purpose: All business logic, external process orchestration, protocol handling, and permission management
- Contains: 21 Swift files covering simulator control, accessibility, screen capture, certificates, network protocol, deep links, design comparison, permissions, window enumeration, Xcode detection
- Key files: `BoosterSimApp/Services/SimCtlService.swift` (shared `xcrun simctl` executor), `BoosterSimApp/Services/ConnectService.swift` (network event aggregation), `BoosterSimApp/Services/PulseServer.swift` (TCP server)

**`BoosterSimApp/BoosterSimApp/Windows/`:**
- Purpose: AppKit window/panel management — floating panel, position calculation, spring animation, highlight overlay
- Contains: `SideWindowController.swift`, `SideWindowPanel.swift`, `AXHighlightPanel.swift`, `PositionCalculator.swift`
- Key files: `BoosterSimApp/Windows/SideWindowController.swift` (central window manager)

**`BoosterSimApp/BoosterSimApp/Views/SideWindow/`:**
- Purpose: Main floating panel UI — tab bar, device header, 4 tab content views, feature sections
- Contains: `SideWindowView.swift` (root), `TabBarView.swift`, `SideTab.swift`, `CollapsedStripView.swift`, `SideWindowFooter.swift`, `DeviceHeaderView.swift`, plus 8 feature section views
- Subdirectories: `tabs/` (4 tab views: Capture, Design, Actions, Network), `network/` (network subviews + `NetworkEventModel.swift`)
- Key files: `BoosterSimApp/Views/SideWindow/SideWindowView.swift` (root view), `BoosterSimApp/Views/SideWindow/TabBarView.swift` (tab navigation)

**`BoosterSimApp/BoosterSimApp/Views/MenuBar/`:**
- Purpose: Menu bar dropdown content
- Contains: `MenuBarView.swift`

**`BoosterSimApp/BoosterSimApp/Views/Preferences/`:**
- Purpose: Preferences window with General and About tabs
- Contains: `PreferencesView.swift`, `GeneralTab.swift`, `AboutTab.swift`

**`BoosterSimApp/BoosterSimApp/Views/Onboarding/`:**
- Purpose: First-launch onboarding wizard
- Contains: `OnboardingContainerView.swift`, `OnboardingStepView.swift`, `ProgressDotsView.swift`

**`BoosterSimApp/BoosterSimApp/Views/Shared/`:**
- Purpose: Reusable SwiftUI components
- Contains: `CollapsibleSection.swift`, `StatusBadge.swift`, `AccentButton.swift`

**`BoosterSimApp/BoosterSimApp/Utilities/`:**
- Purpose: Cross-cutting helpers not tied to any service
- Contains: `AppLogger.swift`, `SpringAnimator.swift`, `DesignTokens.swift`

**`BoosterSimConnect/`:**
- Purpose: iOS SPM framework loaded into Simulator apps via `Bundle.load()` to activate PulseProxy network capture
- Contains: `BoosterSimConnect.swift` (single file, conditional `#if canImport(PulseProxy)`)

**`booster-sim-cli/`:**
- Purpose: Standalone SPM CLI tool for AI-agent-driven Simulator control
- Contains: `Package.swift`, `Sources/boostersim/boostersim.swift` (ArgumentParser entry), `Commands/` (8 subcommands), `Services/SimCtlService.swift` (CLI's own simctl wrapper, independent from the app target's)

**`BoosterSimAppTests/`:**
- Purpose: Unit tests for the main app target
- Contains: `CertificateServiceTests.swift`, `BoosterSimAppTests.swift`

**`BoosterSimAppUITests/`:**
- Purpose: UI tests
- Contains: `BoosterSimAppUITests.swift`, `BoosterSimAppUITestsLaunchTests.swift`, `ScreenshotTests.swift`

## Key File Locations

**Entry Points:**
- `BoosterSimApp/BoosterSimAppApp.swift`: SwiftUI `@main` entry — defines menu bar and settings scenes
- `BoosterSimApp/App/AppDelegate.swift`: AppKit delegate — service container, startup orchestration
- `BoosterSimConnect/BoosterSimConnect.swift`: iOS framework activation entry
- `booster-sim-cli/Sources/boostersim/boostersim.swift`: CLI entry with ArgumentParser

**Configuration:**
- `BoosterHealth-Entitlements.plist`: HealthKit entitlements (seems vestigial — app is macOS-only)
- `BoosterSimApp/BoosterSimAppApp.swift`: `LSUIElement = true` is in `Info.plist` (not visible in source, set in Xcode target)
- `BoosterSimApp/Models/AppSettings.swift`: `@AppStorage` keys define persisted settings

**Core Logic:**
- `BoosterSimApp/Services/SimCtlService.swift`: Shared `xcrun simctl` process executor
- `BoosterSimApp/Services/SimulatorWindowTracker.swift`: Simulator window detection hub
- `BoosterSimApp/Services/ConnectService.swift`: Network event aggregation from Pulse protocol
- `BoosterSimApp/Services/PulsePacketDecoder.swift`: Binary protocol codec
- `BoosterSimApp/Services/CertificateService.swift`: Certificate generation/installation orchestration
- `BoosterSimApp/Services/EnvironmentOverrideService.swift`: Appearance and accessibility override management
- `BoosterSimApp/Services/CaptureService.swift`: Screen recording via ScreenCaptureKit

**Testing:**
- `BoosterSimAppTests/CertificateServiceTests.swift`: Certificate service unit tests
- `BoosterSimAppUITests/ScreenshotTests.swift`: Screenshot-based UI tests

## Naming Conventions

**Files:**
- Services: PascalCase + `Service` suffix — e.g., `StatusBarService.swift`, `AXInspectorService.swift`
- Models: PascalCase noun — e.g., `SimulatorWindow.swift`, `BuildRecord.swift`, `AppSettings.swift`
- Views: PascalCase + `View` suffix — e.g., `SideWindowView.swift`, `MenuBarView.swift`, `CollapsibleSection.swift`
- Windows: PascalCase + `Panel`/`Controller` suffix — e.g., `SideWindowPanel.swift`, `SideWindowController.swift`, `AXHighlightPanel.swift`
- Utilities: PascalCase descriptive — e.g., `AppLogger.swift`, `SpringAnimator.swift`, `DesignTokens.swift`
- Protocol/network types: PascalCase — e.g., `PulseServer.swift`, `PulsePacketDecoder.swift`, `PulseClientConnection.swift`
- CLI commands: PascalCase + `Command` suffix — e.g., `TapCommand.swift`, `ScreenshotCommand.swift`

**Directories:**
- Feature directories: PascalCase — `Services/`, `Windows/`, `Views/`, `Models/`, `Utilities/`
- View subdirectories: PascalCase — `SideWindow/`, `MenuBar/`, `Preferences/`, `Onboarding/`, `Shared/`
- Nested view organization: lowercase for sub-concerns — `tabs/`, `network/`
- SPM packages: kebab-case — `booster-sim-cli/`

**Types:**
- Service classes: `final class: ObservableObject` with `@MainActor`
- Model structs: `struct: Identifiable, Sendable, Equatable` (value types)
- Enums: PascalCase cases — `SideTab.capture`, `SimulatorDeviceType.iOS`, `PulsePacketCode.clientHello`
- Error enums: `enum FooError: LocalizedError` — e.g., `SimCtlError`, `CertificateError`
- Published properties: `@Published private(set) var` for read-only external state

## Where to Add New Code

**New Feature (with UI):**
- Primary code: `BoosterSimApp/Services/<Feature>Service.swift`
- View: `BoosterSimApp/Views/SideWindow/<Feature>SectionView.swift`
- If it needs a full tab: `BoosterSimApp/Views/SideWindow/tabs/<Feature>TabView.swift` and add case to `SideTab` in `BoosterSimApp/Views/SideWindow/SideTab.swift`
- Wire in `AppDelegate.swift` (lazy var + pass to `SideWindowController` init + `.environmentObject()` in `embedSwiftUIContent`)

**New Service (no UI):**
- Implementation: `BoosterSimApp/Services/<Name>Service.swift`
- If it uses `simctl`: inject `SimCtlService` in init, call `simCtl.run(args)`
- Wire in `AppDelegate.swift` as lazy var

**New Model:**
- Value types: `BoosterSimApp/Models/<Name>.swift`
- Service-specific types: can live in the service file or `BoosterSimApp/Models/<Name>Models.swift`

**New Window/Panel:**
- Implementation: `BoosterSimApp/Windows/<Name>Panel.swift` or `<Name>Controller.swift`
- Follow `SideWindowPanel` pattern: `NSPanel` subclass with floating level

**New View Component:**
- Reusable: `BoosterSimApp/Views/Shared/<Name>.swift`
- Tab-specific: `BoosterSimApp/Views/SideWindow/<Name>View.swift`

**Utilities:**
- Shared helpers: `BoosterSimApp/Utilities/<Name>.swift`
- Design constants: add to existing `BoosterSimApp/Utilities/DesignTokens.swift`

**New CLI Subcommand:**
- Implementation: `booster-sim-cli/Sources/boostersim/Commands/<Name>Command.swift`
- Register in `boostersim.swift` `subcommands` array

## Special Directories

**`BoosterSimApp/Assets.xcassets/`:**
- Purpose: Asset catalog for app icon and accent color
- Generated: No
- Committed: Yes

**`BoosterSimApp.xcodeproj/`:**
- Purpose: Xcode project configuration
- Generated: Partially (pbxproj, xcuserdata are machine-managed)
- Committed: Yes

**`booster-sim-cli/`:**
- Purpose: Standalone SPM CLI package (independent build from main app)
- Generated: No
- Committed: Yes

**`BoosterSimConnect/`:**
- Purpose: iOS SPM framework (consumed by iOS apps, not by the macOS app itself)
- Generated: No
- Committed: Yes

**`.build-benchmark/`:**
- Purpose: Build optimization analysis notes
- Generated: No
- Committed: Yes

**`plans/`:**
- Purpose: Historical implementation plans and execution reports (GSD workflow artifacts)
- Generated: No
- Committed: Yes

---

*Structure analysis: 2026-08-29*
