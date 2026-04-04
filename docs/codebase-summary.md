# Codebase Summary

## Project Stats

- **Language:** Swift 6 (strict concurrency)
- **Frameworks:** AppKit, SwiftUI, Combine, CoreGraphics, ApplicationServices, ServiceManagement, QuartzCore, HealthKit
- **Files:** ~51 Swift source files (~4,400 LOC in BoosterSimApp; ~335 LOC in BoosterHealth companion; ~4,625 LOC total)
- **Targets:** BoosterSimApp (macOS), BoosterHealth (iOS companion for HealthKit), test targets
- **External dependencies:** None
- **Test targets:** BoosterSimAppTests, BoosterSimAppUITests (empty, not yet configured)

## Directory Structure

```
BoosterSimApp/
├── BoosterSimApp.xcodeproj/
├── BoosterSimApp/                        # Main target
│   ├── BoosterSimAppApp.swift            # @main entry point (23 LOC)
│   ├── App/
│   │   └── AppDelegate.swift             # NSApplicationDelegate (107 LOC)
│   ├── Models/
│   │   ├── SimulatorWindow.swift         # Window data model (25 LOC)
│   │   ├── AppSettings.swift             # @AppStorage settings (52 LOC)
│   │   ├── BuildRecord.swift             # Build history record (28 LOC)
│   │   └── AXNode.swift                  # Accessibility tree node (18 LOC)
│   ├── Services/
│   │   ├── SimulatorWindowTracker.swift  # Core detection service (199 LOC)
│   │   ├── WindowEnumerator.swift        # CGWindowList scan (65 LOC)
│   │   ├── WindowObserver.swift          # AXObserver wrapper (158 LOC)
│   │   ├── PermissionManager.swift       # Permission checks/requests (143 LOC)
│   │   ├── XcodeDetector.swift           # Xcode path detection (39 LOC)
│   │   ├── SimCtlService.swift           # xcrun simctl executor (78 LOC)
│   │   ├── StatusBarService.swift        # Status bar config (110 LOC)
│   │   ├── EnvironmentOverrideService.swift # Appearance/accessibility (279 LOC)
│   │   ├── BuildStatsService.swift       # Build history polling (97 LOC)
│   │   ├── AXInspectorService.swift      # AX tree walker (112 LOC)
│   │   ├── CameraService.swift           # Camera menu automation (93 LOC)
│   │   └── HealthDataService.swift       # HealthKit companion installer/trigger (116 LOC)
│   ├── Windows/
│   │   ├── SideWindowPanel.swift         # NSPanel subclass (37 LOC)
│   │   ├── SideWindowController.swift    # Panel lifecycle, spring tracking (224 LOC)
│   │   ├── PositionCalculator.swift      # Pure frame math, content height + centering (90 LOC)
│   │   └── AXHighlightPanel.swift        # Floating orange border overlay (68 LOC)
│   ├── Views/
│   │   ├── MenuBar/
│   │   │   └── MenuBarView.swift         # MenuBarExtra content (59 LOC)
│   │   ├── SideWindow/
│   │   │   ├── SideWindowView.swift      # Root side panel view, content height callback (128 LOC)
│   │   │   ├── SideWindowTitleBar.swift  # Collapse button + title (~35 LOC)
│   │   │   ├── DeviceHeaderView.swift    # Active device info (90 LOC)
│   │   │   ├── CollapsedStripView.swift  # 28pt collapsed state (~40 LOC)
│   │   │   ├── SideWindowFooter.swift    # Version/status footer (~30 LOC)
│   │   │   ├── FeatureSectionView.swift  # Collapsible section (90 LOC)
│   │   │   ├── FeatureRowView.swift      # Individual feature row (74 LOC)
│   │   │   ├── StatusBarSectionView.swift # Status bar preset UI (129 LOC)
│   │   │   ├── EnvironmentOverridesView.swift # Accessibility toggles (145 LOC)
│   │   │   ├── BuildStatsSectionView.swift # Build history section (92 LOC)
│   │   │   ├── BuildChartView.swift      # Canvas bar chart (42 LOC)
│   │   │   ├── AXTreeView.swift          # Accessibility tree list (141 LOC)
│   │   │   ├── CameraView.swift          # Camera toggle UI (99 LOC)
│   │   │   └── HealthDataSectionView.swift # Health data presets + manual UI (156 LOC)
│   │   ├── Preferences/
│   │   │   ├── PreferencesView.swift     # Tab container (~30 LOC)
│   │   │   ├── GeneralTab.swift          # Position + launch at login (~45 LOC)
│   │   │   └── AboutTab.swift            # App info + links (79 LOC)
│   │   ├── Onboarding/
│   │   │   ├── OnboardingContainerView.swift  # 4-step flow (114 LOC)
│   │   │   ├── OnboardingStepView.swift       # Single step layout (98 LOC)
│   │   │   └── ProgressDotsView.swift         # Step indicator dots (~25 LOC)
│   │   └── Shared/
│   │       ├── AccentButton.swift        # Amber CTA button (~25 LOC)
│   │       ├── StatusBadge.swift         # Colored dot + label (44 LOC)
│   │       └── CollapsibleSection.swift  # Reusable collapsible header (47 LOC)
│   └── Utilities/
│       ├── DesignTokens.swift            # Layout/spacing constants (51 LOC)
│       └── SpringAnimator.swift          # CADisplayLink spring physics (112 LOC)
├── BoosterHealth/                        # iOS companion app (Simulator-only)
│   ├── BoosterHealthApp.swift            # @main entry, handles URL scheme (81 LOC)
│   ├── HealthDataGenerator.swift         # HKHealthStore writes (205 LOC)
│   ├── HealthPayload.swift               # URL parser + HealthPreset enum (49 LOC)
│   ├── BoosterHealth-Info.plist          # URL scheme registration
│   └── BoosterHealth-Entitlements.plist  # HealthKit capability
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
| Panel lifecycle & spring tracking | `Windows/SideWindowController.swift` |
| Position math | `Windows/PositionCalculator.swift` |
| Spring animation physics | `Utilities/SpringAnimator.swift` |
| Design constants | `Utilities/DesignTokens.swift` |
| Settings persistence | `Models/AppSettings.swift` |

## Largest Files (by LOC)

| Rank | File | LOC | Notes |
|---|---|---|---|
| 1 | `EnvironmentOverrideService.swift` | 279 | Candidate for split |
| 2 | `HealthDataGenerator.swift` | 205 | BoosterHealth target |
| 3 | `SideWindowController.swift` | 224 | Monitor growth |
| 4 | `SimulatorWindowTracker.swift` | 199 | — |
| 5 | `HealthDataSectionView.swift` | 156 | — |
| 6 | `AXTreeView.swift` | 141 | — |
| 7 | `EnvironmentOverridesView.swift` | 145 | — |

## Feature Sections (Side Panel — Phase 6 Complete)

| Section | Features | Status |
|---|---|---|
| Status Bar | Status Presets (Screenshot Ready, Low Battery, No Signal), Custom Config | Complete |
| Environment | Dark/Light Mode, Increase Contrast, Dynamic Type, Reduce Motion, Bold Text | Complete |
| Builds | Build History (last 30), Duration Chart, Stats | Complete |
| Accessibility | AX Tree Inspector, Element Highlight, Frame Info | Complete |
| Camera | Front/Back Toggle (iOS Simulator only), Mac Camera Input | Complete |
| Health Data | 4 Presets (Active Day, Rest Day, Sick Day, 7-Day History), Manual Mode, Clear Data | Complete |
| Captures | Screenshot, Record Screen, GIF Recording, Video Export | Placeholder |
| App Actions | Reset App, Clear Keychain, Push Notification, Deep Link | Placeholder |
| Design Tools | Grid Overlay, Safe Area Overlay, Ruler, Color Picker | Placeholder |
| Network | Throttle Network, Block Requests, View Logs, Certificates | Placeholder |
