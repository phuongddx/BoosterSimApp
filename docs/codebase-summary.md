# Codebase Summary

## Project Stats

- **Language:** Swift 6 (strict concurrency)
- **Frameworks:** AppKit, SwiftUI, Combine, CoreGraphics, ApplicationServices, ServiceManagement
- **Files:** 29 Swift source files (~1,700 LOC total)
- **External dependencies:** None
- **Test targets:** BoosterSimAppTests, BoosterSimAppUITests (empty, not yet configured)

## Directory Structure

```
BoosterSimApp/
├── BoosterSimApp.xcodeproj/
├── BoosterSimApp/                        # Main target
│   ├── BoosterSimAppApp.swift            # @main entry point (23 LOC)
│   ├── App/
│   │   └── AppDelegate.swift             # NSApplicationDelegate (62 LOC)
│   ├── Models/
│   │   ├── SimulatorWindow.swift         # Window data model (17 LOC)
│   │   └── AppSettings.swift            # @AppStorage settings (52 LOC)
│   ├── Services/
│   │   ├── SimulatorWindowTracker.swift  # Core detection service (109 LOC)
│   │   ├── WindowEnumerator.swift        # CGWindowList scan (65 LOC)
│   │   ├── WindowObserver.swift          # AXObserver wrapper (99 LOC)
│   │   ├── PermissionManager.swift       # Permission checks/requests (143 LOC)
│   │   └── XcodeDetector.swift          # Xcode path detection (39 LOC)
│   ├── Windows/
│   │   ├── SideWindowPanel.swift         # NSPanel subclass (37 LOC)
│   │   ├── SideWindowController.swift    # Panel lifecycle/position (131 LOC)
│   │   └── PositionCalculator.swift      # Pure frame math (82 LOC)
│   ├── Views/
│   │   ├── MenuBar/
│   │   │   └── MenuBarView.swift         # MenuBarExtra content (54 LOC)
│   │   ├── SideWindow/
│   │   │   ├── SideWindowView.swift      # Root side panel view (64 LOC)
│   │   │   ├── SideWindowTitleBar.swift  # Collapse button + title (35 LOC)
│   │   │   ├── DeviceHeaderView.swift    # Active device info (41 LOC)
│   │   │   ├── CollapsedStripView.swift  # 28pt collapsed state (30 LOC)
│   │   │   ├── SideWindowFooter.swift    # Version/status footer (31 LOC)
│   │   │   ├── FeatureSectionView.swift  # Collapsible section (70 LOC)
│   │   │   └── FeatureRowView.swift      # Individual feature row (65 LOC)
│   │   ├── Preferences/
│   │   │   ├── PreferencesView.swift     # Tab container (22 LOC)
│   │   │   ├── GeneralTab.swift          # Position + launch at login (31 LOC)
│   │   │   └── AboutTab.swift            # App info + links (75 LOC)
│   │   ├── Onboarding/
│   │   │   ├── OnboardingContainerView.swift  # 4-step flow (110 LOC)
│   │   │   ├── OnboardingStepView.swift       # Single step layout (72 LOC)
│   │   │   └── ProgressDotsView.swift         # Step indicator dots (19 LOC)
│   │   └── Shared/
│   │       ├── AccentButton.swift        # Amber CTA button (21 LOC)
│   │       └── StatusBadge.swift         # Colored dot + label (35 LOC)
│   └── Utilities/
│       └── DesignTokens.swift            # Layout/spacing constants (51 LOC)
├── BoosterSimAppTests/                   # Unit test target (empty)
├── BoosterSimAppUITests/                 # UI test target (empty)
└── plans/                               # Implementation plans
    └── reports/
```

## Key Files by Role

| Role | File |
|---|---|
| App entry | `BoosterSimAppApp.swift` |
| Service orchestration | `App/AppDelegate.swift` |
| Simulator detection | `Services/SimulatorWindowTracker.swift` |
| Low-level window scan | `Services/WindowEnumerator.swift` |
| Real-time AX events | `Services/WindowObserver.swift` |
| Panel lifecycle | `Windows/SideWindowController.swift` |
| Position math | `Windows/PositionCalculator.swift` |
| Design constants | `Utilities/DesignTokens.swift` |
| Settings persistence | `Models/AppSettings.swift` |

## Largest Files (by LOC)

1. `PermissionManager.swift` — 143 LOC
2. `SideWindowController.swift` — 131 LOC
3. `SimulatorWindowTracker.swift` — 109 LOC
4. `OnboardingContainerView.swift` — 110 LOC
5. `WindowObserver.swift` — 99 LOC

All files are under the 200 LOC limit — no modularization needed at this stage.

## Feature Sections (Side Panel — MVP Placeholders)

All feature rows display a "Coming soon" badge in the current MVP build:

| Section | Features |
|---|---|
| Captures | Screenshot, Record Screen, GIF Recording, Video Export |
| App Actions | Reset App, Clear Keychain, Push Notification, Deep Link |
| Design Tools | Grid Overlay, Safe Area Overlay, Ruler, Color Picker |
| Network | Throttle Network, Block Requests, View Logs, Certificates |
