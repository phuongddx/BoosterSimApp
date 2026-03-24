# Codebase Summary

## Project Stats

- **Language:** Swift 6 (strict concurrency)
- **Frameworks:** AppKit, SwiftUI, Combine, CoreGraphics, ApplicationServices, ServiceManagement
- **Files:** 44 Swift source files (~2,900 LOC total)
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
│   │   ├── SimulatorWindow.swift         # Window data model (25 LOC)
│   │   ├── AppSettings.swift             # @AppStorage settings (52 LOC)
│   │   ├── BuildRecord.swift             # Build history record (28 LOC)
│   │   └── AXNode.swift                  # Accessibility tree node (18 LOC)
│   ├── Services/
│   │   ├── SimulatorWindowTracker.swift  # Core detection service (179 LOC)
│   │   ├── WindowEnumerator.swift        # CGWindowList scan (65 LOC)
│   │   ├── WindowObserver.swift          # AXObserver wrapper (154 LOC)
│   │   ├── PermissionManager.swift       # Permission checks/requests (143 LOC)
│   │   ├── XcodeDetector.swift           # Xcode path detection (39 LOC)
│   │   ├── SimCtlService.swift           # xcrun simctl executor (85 LOC)
│   │   ├── StatusBarService.swift        # Status bar config (92 LOC)
│   │   ├── EnvironmentOverrideService.swift # Appearance/accessibility (105 LOC)
│   │   ├── BuildStatsService.swift       # Build history polling (128 LOC)
│   │   ├── AXInspectorService.swift      # AX tree walker (135 LOC)
│   │   └── CameraService.swift           # Camera menu automation (118 LOC)
│   ├── Windows/
│   │   ├── SideWindowPanel.swift         # NSPanel subclass (37 LOC)
│   │   ├── SideWindowController.swift    # Panel lifecycle/position (147 LOC)
│   │   ├── PositionCalculator.swift      # Pure frame math (82 LOC)
│   │   └── AXHighlightPanel.swift        # AX overlay panel (62 LOC)
│   ├── Views/
│   │   ├── MenuBar/
│   │   │   └── MenuBarView.swift         # MenuBarExtra content (54 LOC)
│   │   ├── SideWindow/
│   │   │   ├── SideWindowView.swift      # Root side panel view (182 LOC)
│   │   │   ├── SideWindowTitleBar.swift  # Collapse button + title (35 LOC)
│   │   │   ├── DeviceHeaderView.swift    # Active device info (84 LOC)
│   │   │   ├── CollapsedStripView.swift  # 28pt collapsed state (30 LOC)
│   │   │   ├── SideWindowFooter.swift    # Version/status footer (31 LOC)
│   │   │   ├── FeatureSectionView.swift  # Collapsible section (76 LOC)
│   │   │   ├── FeatureRowView.swift      # Individual feature row (66 LOC)
│   │   │   ├── StatusBarSectionView.swift # Status bar preset UI (117 LOC)
│   │   │   ├── EnvironmentOverridesView.swift # Accessibility toggles (161 LOC)
│   │   │   ├── BuildStatsSectionView.swift # Build history section (86 LOC)
│   │   │   ├── BuildChartView.swift      # Canvas bar chart (29 LOC)
│   │   │   ├── AXTreeView.swift          # Accessibility tree list (135 LOC)
│   │   │   └── CameraView.swift          # Camera toggle UI (93 LOC)
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

1. `SideWindowView.swift` — 182 LOC
2. `SimulatorWindowTracker.swift` — 179 LOC
3. `WindowObserver.swift` — 154 LOC
4. `EnvironmentOverridesView.swift` — 161 LOC
5. `AXTreeView.swift` — 135 LOC

All files are under the 200 LOC limit — no modularization needed at this stage.

## Feature Sections (Side Panel — Phase 6 Complete)

| Section | Features | Status |
|---|---|---|
| Status Bar | Status Presets (Screenshot Ready, Low Battery, No Signal), Custom Config | Complete |
| Environment | Dark/Light Mode, Increase Contrast, Dynamic Type, Reduce Motion, Bold Text | Complete |
| Builds | Build History (last 30), Duration Chart, Stats | Complete |
| Accessibility | AX Tree Inspector, Element Highlight, Frame Info | Complete |
| Camera | Front/Back Toggle (iOS Simulator only), Mac Camera Input | Complete |
| Captures | Screenshot, Record Screen, GIF Recording, Video Export | Placeholder |
| App Actions | Reset App, Clear Keychain, Push Notification, Deep Link | Placeholder |
| Design Tools | Grid Overlay, Safe Area Overlay, Ruler, Color Picker | Placeholder |
| Network | Throttle Network, Block Requests, View Logs, Certificates | Placeholder |
