# Codebase Summary

## Project Stats

- **Language:** Swift 6 (strict concurrency)
- **Frameworks:** AppKit, SwiftUI, Combine, CoreGraphics, ApplicationServices, ServiceManagement, QuartzCore, Network
- **Files:** 73 Swift source files (~6,556 LOC total across app, iOS framework source, and tests)
- **Targets:** BoosterSimApp (macOS), BoosterSimConnect (iOS framework), test targets
- **External dependencies:** Pulse/PulseProxy SPM (BoosterSimConnect framework only)
- **Test targets:** BoosterSimAppTests (unit tests), BoosterSimAppUITests (UI test scaffolds)

## Directory Structure

```
BoosterSimApp/
├── BoosterSimApp.xcodeproj/
├── BoosterSimApp/                        # Main target
│   ├── BoosterSimAppApp.swift            # @main entry point (23 LOC)
│   ├── App/
│   │   └── AppDelegate.swift             # NSApplicationDelegate (109 LOC)
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
│   │   ├── CertificateModels.swift       # CA status / operation / error types (96 LOC)
│   │   ├── CertificateStore.swift        # OpenSSL CA generation + persistence (172 LOC)
│   │   ├── CertificateService.swift      # CA trust management flow (195 LOC)
│   │   ├── ConnectService.swift          # Pulse server host + event pipeline (118 LOC)
│   │   ├── PulseServer.swift             # NWListener TCP server + Bonjour (104 LOC)
│   │   ├── PulseClientConnection.swift   # Per-client protocol handler (183 LOC)
│   │   └── PulsePacketDecoder.swift      # Binary protocol parser (174 LOC)
│   ├── Windows/
│   │   ├── SideWindowPanel.swift         # NSPanel subclass (37 LOC)
│   │   ├── SideWindowController.swift    # Panel lifecycle, spring tracking (234 LOC)
│   │   ├── PositionCalculator.swift      # Pure frame math, content height + centering (90 LOC)
│   │   └── AXHighlightPanel.swift        # Floating orange border overlay (68 LOC)
│   ├── Views/
│   │   ├── MenuBar/
│   │   │   └── MenuBarView.swift         # MenuBarExtra content (59 LOC)
│   │   ├── SideWindow/
│   │   │   ├── SideWindowView.swift      # Root side panel view, tab-based layout (108 LOC)
│   │   │   ├── SideTab.swift             # Tab enum for side window navigation (27 LOC)
│   │   │   ├── TabBarView.swift          # Icon tab bar with amber underline (71 LOC)
│   │   │   ├── tabs/
│   │   │   │   ├── CaptureTabView.swift  # Capture tab: screenshot, recording, GIF (23 LOC)
│   │   │   │   ├── DesignTabView.swift   # Design tab: grid, safe area, ruler, picker (23 LOC)
│   │   │   │   ├── ActionsTabView.swift  # Actions tab: env overrides + quick actions (25 LOC)
│   │   │   │   └── NetworkTabView.swift  # Network tab: live traffic + certificates (62 LOC)
│   │   │   ├── network/
│   │   │   │   ├── NetworkEventModel.swift # NetworkEvent, HTTPMethod, TrafficFilter, ConnectionState (208 LOC)
│   │   │   │   ├── TrafficRowView.swift    # Single request row in traffic list (98 LOC)
│   │   │   │   ├── TrafficList.swift       # Scrollable traffic list + empty state (73 LOC)
│   │   │   │   ├── TrafficDetailView.swift # Sheet: Summary/Headers/Body/Metrics tabs (300 LOC)
│   │   │   │   ├── TrafficFilterBar.swift  # Method + status filter pills + search (136 LOC)
│   │   │   │   ├── ConnectStatusBanner.swift # Connection state dot + label (92 LOC)
│   │   │   │   ├── ConnectSetupView.swift  # Setup instructions + code snippet (89 LOC)
│   │   │   │   └── CurlExporter.swift      # NetworkEvent → cURL command (49 LOC)
│   │   │   ├── DeviceHeaderView.swift    # Active device info (90 LOC)
│   │   │   ├── CollapsedStripView.swift  # 28pt collapsed state (35 LOC)
│   │   │   ├── SideWindowFooter.swift    # Version/status footer (36 LOC)
│   │   │   ├── FeatureSectionView.swift  # Collapsible section (90 LOC)
│   │   │   ├── FeatureRowView.swift      # Individual feature row (74 LOC)
│   │   │   ├── StatusBarSectionView.swift # Status bar preset UI (129 LOC)
│   │   │   ├── EnvironmentOverridesView.swift # Accessibility toggles (145 LOC)
│   │   │   ├── CertificateSectionView.swift # CA trust management UI (177 LOC)
│   │   │   ├── BuildStatsSectionView.swift # Build history section (92 LOC)
│   │   │   ├── BuildChartView.swift      # Canvas bar chart (42 LOC)
│   │   │   ├── AXTreeView.swift          # Accessibility tree list (141 LOC)
│   │   │   └── CameraView.swift          # Camera toggle UI (99 LOC)
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
│       ├── AppLogger.swift               # Centralized os.Logger instances (14 LOC)
│       ├── DesignTokens.swift            # Layout/spacing constants (51 LOC)
│       └── SpringAnimator.swift          # CADisplayLink spring physics (112 LOC)
├── BoosterSimAppTests/                   # Unit test target
│   ├── BoosterSimAppTests.swift          # Basic test scaffold (17 LOC)
│   └── CertificateServiceTests.swift     # Certificate service behavior tests (26 LOC)
├── BoosterSimAppUITests/                 # UI test target
│   ├── BoosterSimAppUITests.swift        # UI test scaffold (41 LOC)
│   └── BoosterSimAppUITestsLaunchTests.swift # Launch test scaffold (33 LOC)
├── BoosterSimConnect/                    # iOS framework source (loaded into Simulator apps)
│   └── BoosterSimConnect.swift           # PulseProxy activation + RemoteLogger (65 LOC)
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
| Pulse server + traffic pipeline | `Services/ConnectService.swift` |
| TCP server (NWListener) | `Services/PulseServer.swift` |
| Per-client protocol handler | `Services/PulseClientConnection.swift` |
| Binary protocol parser | `Services/PulsePacketDecoder.swift` |
| Network event models | `Views/SideWindow/network/NetworkEventModel.swift` |
| iOS framework activation | `BoosterSimConnect/BoosterSimConnect.swift` |
| Tab-based navigation | `Views/SideWindow/SideTab.swift`, `Views/SideWindow/TabBarView.swift` |
| Panel lifecycle & spring tracking | `Windows/SideWindowController.swift` |
| Position math | `Windows/PositionCalculator.swift` |
| AX element highlight | `Windows/AXHighlightPanel.swift` |
| CA trust management | `Services/CertificateService.swift` |
| CA models & types | `Services/CertificateModels.swift` |
| CA persistence | `Services/CertificateStore.swift` |
| Spring animation physics | `Utilities/SpringAnimator.swift` |
| Centralized logging | `Utilities/AppLogger.swift` |
| Design constants | `Utilities/DesignTokens.swift` |
| Settings persistence | `Models/AppSettings.swift` |
| Build stats polling | `Services/BuildStatsService.swift` |
| AX tree inspection | `Services/AXInspectorService.swift` |
| Camera automation | `Services/CameraService.swift` |
| Environment overrides | `Services/EnvironmentOverrideService.swift` |
| Status bar config | `Services/StatusBarService.swift` |

## Largest Files (by LOC)

| Rank | File | LOC | Notes |
|---|---|---|---|
| 1 | `TrafficDetailView.swift` | 295 | Network detail sheet (4 tabs) — candidate for split |
| 2 | `EnvironmentOverrideService.swift` | 279 | Candidate for split |
| 3 | `SideWindowController.swift` | 234 | Monitor growth |
| 4 | `NetworkEventModel.swift` | 208 | Network event + filter models |
| 5 | `SimulatorWindowTracker.swift` | 199 | — |
| 6 | `CertificateService.swift` | 195 | CA trust management |
| 7 | `PulseClientConnection.swift` | 183 | Per-client protocol handler |
| 8 | `CertificateSectionView.swift` | 177 | Side panel trust UI |
| 9 | `PulsePacketDecoder.swift` | 174 | Binary protocol parser |

## Feature Sections (Side Panel — Tab-Based UI)

| Tab | Section | Features | Status |
|---|---|---|---|
| Capture | Captures | Screenshot, Record Screen, GIF Recording, Video Export | Placeholder |
| Design | Design Tools | Grid Overlay, Safe Area Overlay, Ruler, Color Picker | Placeholder |
| Actions | Environment | Dark/Light Mode, Increase Contrast, Dynamic Type, Reduce Motion, Bold Text, Smart Invert, Reduce Transparency, Grayscale, On/Off Labels, Button Shapes, Differentiate Without Color | Complete |
| Actions | Quick Actions | Reset App, Clear Keychain, Push Notification, Deep Link | Placeholder |
| Network | Connect | Pulse TCP server (NWListener + Bonjour), binary protocol decode, connection state banner, setup instructions | Complete |
| Network | Traffic Viewer | Filter by method/status, traffic list, detail sheet (headers/body/metrics), cURL export | Complete |
| Network | Certificates | CA Generation, Simulator Keychain Install, Rotate, Reset, Trust-State Messaging | Complete |
| Network | Network Tools | Throttle Network, Block Requests | Placeholder |

**Wired sections** (exist in tabs, fully functional):
- Actions tab: `EnvironmentOverridesView` (11 a11y toggles)
- Network tab: `ConnectService` + `PulseServer` + `TrafficList`/`TrafficDetailView` + `CertificateSectionView`

**Standalone views** (exist but not wired into tabs yet):
- `StatusBarSectionView` — status bar presets + custom (Complete)
- `BuildStatsSectionView` / `BuildChartView` — build history + bar chart (Complete)
- `AXTreeView` — accessibility tree inspector with lazy loading (Complete)
- `CameraView` — Mac camera input toggle (Complete)
