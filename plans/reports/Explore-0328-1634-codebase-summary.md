# BoosterSimApp Codebase Exploration Report

**Date:** March 28, 2026
**Project:** BoosterSimApp (macOS menu bar companion for iOS Simulator)
**Total LOC:** ~3,924 Swift | ~46 files
**Architecture:** SwiftUI + AppKit services + NSPanel floating window

---

## 1. Directory Structure & File Organization

```
BoosterSimApp/
├── App/                       (105 LOC)
│   └── AppDelegate.swift      — Main @NSApplicationDelegate, service initialization
├── Models/                    (131 LOC)
│   ├── SimulatorWindow.swift  — Device window model + SimulatorDeviceType enum
│   ├── AppSettings.swift      — @AppStorage user preferences (position, launch-at-login)
│   ├── AXNode.swift           — Accessibility tree node (immutable value type)
│   └── BuildRecord.swift      — Xcode build record from LogStoreManifest.plist
├── Services/                  (1,373 LOC)
│   ├── SimulatorWindowTracker.swift     — Core window detection + device classification
│   ├── AXInspectorService.swift         — Accessibility tree walker
│   ├── BuildStatsService.swift          — Polls Xcode DerivedData for build history
│   ├── CameraService.swift              — AX menu automation for camera routing
│   ├── EnvironmentOverrideService.swift — Simulator appearance/a11y overrides
│   ├── StatusBarService.swift           — Status bar config via simctl
│   ├── SimCtlService.swift              — Shared xcrun simctl executor
│   ├── WindowObserver.swift             — AXObserver for real-time window events
│   ├── WindowEnumerator.swift           — CGWindowList polling
│   ├── PermissionManager.swift          — Accessibility permission checks
│   └── XcodeDetector.swift              — Xcode.app discovery (unused in current build)
├── Views/                     (1,701 LOC)
│   ├── MenuBar/
│   │   └── MenuBarView.swift  — Floating menu with quick settings
│   ├── SideWindow/            — Primary floating panel UI
│   │   ├── SideWindowView.swift           — Root SwiftUI view
│   │   ├── SideWindowTitleBar.swift       — Collapse/menu buttons
│   │   ├── SideWindowFooter.swift         — Bottom status/info
│   │   ├── CollapsedStripView.swift       — Minimized state (vertical strip)
│   │   ├── DeviceHeaderView.swift         — Device name + multi-sim picker
│   │   ├── EnvironmentOverridesView.swift — Appearance/a11y toggles
│   │   ├── StatusBarSectionView.swift     — Status bar presets + custom
│   │   ├── CameraView.swift               — Front/back camera toggles
│   │   ├── AXTreeView.swift               — Accessibility inspector tree
│   │   ├── BuildStatsSectionView.swift    — Recent builds chart
│   │   ├── BuildChartView.swift           — Build timeline visualization
│   │   ├── FeatureSectionView.swift       — Coming soon feature groups
│   │   └── FeatureRowView.swift           — Single feature row
│   ├── Onboarding/
│   │   ├── OnboardingContainerView.swift  — 4-step welcome flow
│   │   ├── OnboardingStepView.swift       — Individual onboarding step
│   │   └── ProgressDotsView.swift         — Step indicator dots
│   ├── Preferences/
│   │   ├── PreferencesView.swift          — Preferences window (Cmd+,)
│   │   ├── GeneralTab.swift               — Position, launch-at-login, show toggle
│   │   └── AboutTab.swift                 — App version, credits
│   └── Shared/
│       ├── AccentButton.swift             — Styled accent action button
│       └── StatusBadge.swift              — Connected/disconnected indicator
├── Windows/                   (415 LOC)
│   ├── SideWindowController.swift  — Lifecycle, positioning, collapse/expand logic
│   ├── SideWindowPanel.swift       — NSPanel subclass (floating, non-activating)
│   ├── AXHighlightPanel.swift      — Overlay for AX node highlighting
│   └── PositionCalculator.swift    — Dynamic positioning math (left/right/bottom/dynamic)
├── Utilities/                 (176 LOC)
│   ├── AppLogger.swift        — Centralized os.Logger instances (Console.app filtering)
│   ├── DesignTokens.swift     — Design system constants (spacing, dimensions, radii)
│   └── SpringAnimator.swift   — Spring physics for smooth panel position tracking
├── BoosterSimAppApp.swift     — @main SwiftUI App entry point
└── Assets.xcassets/           — App icons, accent colors
```

---

## 2. Key Services & Responsibilities

### Core Services (SimulatorWindowTracker Leadership)

**SimulatorWindowTracker** (270 LOC) — **Orchestrator**
- Real-time iOS/watchOS/tvOS/visionOS simulator window detection
- Device type classification via `simctl list devices --json` (iPhone/Watch/TV/Vision)
- Published state: `@Published simulators: [SimulatorWindow]`, `activeSimulator`, `isSimulatorFocused`
- Hybrid detection: CGWindowList polling + AXObserver notifications
- Device info cache: device name → (type, UDID) mapping
- Workspace notifications: tracks Simulator.app focus state

**WindowObserver** (110 LOC) — **Real-Time Position Tracking**
- Per-PID AXObserver listening for `kAXWindowMoved/Resized` notifications
- Two-tier notification model:
  - Tier 1: Lifecycle notifications (created, minimized, destroyed) on app element
  - Tier 2: Positional notifications on window elements (fast path during drag)
- Callback pattern: `onFrameChanged` fast path for panel position sync
- Properly balanced retain/release via `Unmanaged.passRetained()`

**WindowEnumerator** (100 LOC) — **CGWindowList Polling**
- Enumerates visible/minimized windows via Quartz APIs
- Filters by process ID and Simulator.app bundle identifier
- Handles screen recording permission (returns `displayName` fallback when UDID unavailable)

### Feature Services (Pure Business Logic)

**AXInspectorService** (180 LOC) — **Accessibility Tree Walker**
- Lazy loads AXUIElement hierarchy up to depth 5
- Raw CFString AX attributes (macOS 26 SDK compatibility)
- Reads role, title, description, value, frame from elements
- Background queue execution for AX calls
- Auto-highlight with 2.5s timeout via `$highlightFrame` published property
- Integrated into AXHighlightPanel for visual feedback

**BuildStatsService** (140 LOC) — **Xcode Build Monitoring**
- Polls `~/Library/Developer/Xcode/DerivedData/*/Logs/Build/LogStoreManifest.plist`
- Parses build records: scheme, duration, status, error/warning counts
- Mtime-based caching to minimize re-parsing
- 5s poll interval; limits to 20 projects + 30 recent builds
- Publishes `@Published recentBuilds: [BuildRecord]`

**EnvironmentOverrideService** (220 LOC) — **Simulator Customization**
- **Tier 1 (official):** Dark mode, increase contrast, dynamic type via `simctl ui` commands
- **Tier 2 (accessibility domain):** Reduce motion, bold text, grayscale, smart invert, etc. via `simctl spawn` + defaults read/write
- Instant toggle implementation (no app relaunch required)
- State syncing: loads current state from simulator on attach
- Smart invert requires reading multiple plist keys for correct detection

**StatusBarService** (120 LOC) — **Status Bar Configuration**
- Presets: Screenshot Ready (9:41, 100% battery), Low Battery, No Signal
- Custom config support (time, battery level/state, WiFi bars/mode, cellular, operator)
- Executes via `simctl status_bar <udid> override` with argument builder
- Publishes `isApplying`, `lastError` for UI feedback

**CameraService** (95 LOC) — **AX Menu Automation**
- Clicks Simulator.app menu: Features → Camera → Front/Back Camera → Mac Built-In Camera
- Path-based AX menu navigation with checkmark detection
- 150ms delay post-click for state synchronization
- Probes camera support upfront; publishes `isFrontEnabled`, `isBackEnabled`

**SimCtlService** (80 LOC) — **xcrun Executor**
- Centralized `xcrun simctl <args>` process runner
- Background queue execution; main thread result delivery
- Error handling: `SimCtlError` enum (commandFailed, xcrunNotFound, timeout)
- Convenience: `run()` returns `AnyPublisher<String>`, `runVoid()` for fire-and-forget

### Utility Services

**PermissionManager** — Accessibility permission checks
**XcodeDetector** — Xcode.app path discovery (placeholder for future integration)

---

## 3. View Hierarchy & UI Architecture

### Entry Point
- **BoosterSimAppApp.swift** — `@main` SwiftUI App with:
  - MenuBarExtra("BoosterSim", systemImage: "bolt.fill")
  - Settings scene for Cmd+, preferences
  - Services injected via `@NSApplicationDelegateAdaptor(AppDelegate.self)`

### Windows Layer

**SideWindowPanel** (NSPanel)
- Floating, non-activating, stays visible across spaces
- Full-size content view, transparent titlebar
- Managed by SideWindowController lifecycle

**SideWindowController** (250 LOC)
- Attaches/detaches from SimulatorWindowTracker
- Shows/hides panel based on simulator focus + settings
- Collapse/expand animation with spring physics
- Dynamic positioning: left/right/bottom relative to simulator frame
- Keyboard shortcut: Cmd+Shift+S to toggle
- Respects accessibility reduced motion

**AXHighlightPanel** (NSPanel overlay)
- Shows yellow/red highlight at AX node frame
- Driven by AXInspectorService.$highlightFrame

### Primary Views

**SideWindowView** (150 LOC) — Root SwiftUI view
- Conditional rendering: expanded vs. collapsed state
- Hosts all feature sections: environment overrides, status bar, camera, build stats, AX tree
- Multi-simulator picker when >1 device running
- Environment objects: services injected for SwiftUI bindings

**SideWindowTitleBar** — Collapse button + menu
**SideWindowFooter** — About/links

**CollapsedStripView** — Minimized vertical strip with expand button

### Feature Sections

**DeviceHeaderView** (80 LOC)
- Shows device icon, name, connection status (green/red indicator)
- Multi-simulator picker: buttons for each running simulator
- Device type icons: iphone, applewatch, tv, visionpro

**EnvironmentOverridesView** (180 LOC)
- Accessibility group: contrast, transparency, bold text, reduce motion, grayscale, smart invert, etc.
- Appearance group: dark mode toggle
- Dynamic Type group: content size slider
- Bindings to EnvironmentOverrideService with closures for setter dispatch

**StatusBarSectionView** (100 LOC)
- Preset buttons: Screenshot Ready, Low Battery, No Signal
- Clear/Custom toggle for advanced config
- Disabled when no simulator detected

**CameraView** (80 LOC)
- Front/Back camera toggles
- Only shows when camera menu is available in Simulator

**BuildStatsSectionView** + **BuildChartView** (150 LOC total)
- Lists recent 5-10 builds with duration, success/failure, error/warning counts
- Timeline visualization (bar chart of build durations)

**AXTreeView** (120 LOC)
- Expandable tree of AX elements
- Row per element: role, label, value, frame
- Highlight/unhighlight on interaction

### Onboarding

**OnboardingContainerView** (100 LOC)
- 4-step welcome flow (slides)
- Shown on first launch via `@AppStorage("completedOnboarding")`
- Steps: intro, features, setup, done

**ProgressDotsView** — Dot indicator

### Preferences

**PreferencesView** (80 LOC)
- Native Cmd+, window
- Tabs: General, About

**GeneralTab** (35 LOC)
- Side window position picker (left, right, bottom, dynamic)
- Show toggle
- Launch at login (synced with SMAppService)

**AboutTab** — Version, credits, links

---

## 4. Models & Data Structures

**SimulatorWindow** (36 LOC)
```swift
struct SimulatorWindow: Identifiable, Equatable {
    let id: CGWindowID
    let pid: pid_t
    var deviceName: String?          // nil without Screen Recording perm
    var frame: CGRect                // AppKit screen coords
    var isOnScreen: Bool
    var isMinimized: Bool
    var deviceType: SimulatorDeviceType = .iOS
    var udid: String?
    var displayName: String { ... }  // fallback when UDID unavailable
}
```

**SimulatorDeviceType** — Enum with SF symbol mapping (iOS, watchOS, tvOS, visionOS)

**AppSettings** (55 LOC)
```swift
@AppStorage properties:
- position: SideWindowPosition (left|right|bottom|dynamic)
- showSideWindow: Bool
- launchAtLogin: Bool
- xcodePath: String
```
Custom setter: `setLaunchAtLogin()` syncs with SMAppService

**AXNode** (13 LOC) — Immutable tree node
```swift
struct AXNode: Identifiable, Sendable {
    let id: UUID, role, label, value: String
    let frame: CGRect
    let hasChildren: Bool
    var children: [AXNode]? = nil  // lazy loading
}
```

**BuildRecord** (30 LOC) — Xcode build data
```swift
struct BuildRecord: Identifiable, Sendable {
    let id, schemeName: String
    let startDate: Date
    let duration: TimeInterval
    let succeeded: Bool
    let errorCount, warningCount: Int
    var formattedDuration: String { ... }
    var formattedDate: String { ... }
}
```

**StatusBarConfig** (51 LOC) — Codable config
```swift
struct StatusBarConfig: Codable, Equatable {
    var time: String = "9:41"
    var batteryLevel: Int = 100
    var batteryState: String = "charged"  // charging|charged|discharging
    var wifiBars: Int = 3
    var wifiMode: String = "active"
    var cellularBars: Int = 4
    var cellularMode: String = "active"
    var dataNetwork: String = "wifi"  // wifi|5g|lte|4g|3g|hide
    var operatorName: String = ""
}
```

**AppearanceStyle** — Enum (light, dark, unknown)

**SideWindowPosition** — Enum with labels + icons (left, right, bottom, dynamic)

---

## 5. App Entry Point & Lifecycle

**BoosterSimAppApp.swift** (23 LOC)
- MenuBarExtra renders MenuBarView
- Settings scene for Cmd+, preferences
- Services isolated in AppDelegate

**AppDelegate** (105 LOC)
```swift
@MainActor NSApplicationDelegate {
    // Core
    let tracker = SimulatorWindowTracker()
    let settings = AppSettings()
    let simCtlService = SimCtlService()
    
    // Features (lazy-initialized)
    lazy var statusBarService = StatusBarService(simCtl: simCtlService)
    lazy var envOverrideService = EnvironmentOverrideService(simCtl: simCtlService)
    lazy var buildStatsService = BuildStatsService()
    lazy var axInspectorService = AXInspectorService()
    lazy var cameraService = CameraService()
    lazy var axHighlightPanel = AXHighlightPanel()
    
    // Windows
    lazy var sideWindowController = SideWindowController(...)
    
    // Lifecycle hooks
    func applicationDidFinishLaunching(...) {
        // 1. Prevent duplicate instances
        // 2. Wire side window to tracker
        // 3. Start simulator detection + build monitoring
        // 4. Drive AXHighlightPanel from service
        // 5. Show onboarding on first launch
    }
    
    func applicationWillTerminate(...) {
        tracker.stopTracking()
        buildStatsService.stopMonitoring()
    }
}
```

### Initialization Chain
1. BoosterSimAppApp creates AppDelegate
2. AppDelegate initializes core services on first access
3. applicationDidFinishLaunching:
   - Attaches SideWindowController to tracker
   - Starts window tracking + build monitoring
   - Subscribes AXHighlightPanel to inspector
   - Shows onboarding if needed
4. Simulator detection → tracker publishes activeSimulator
5. SideWindowController shows/hides panel on focus changes

---

## 6. Windows & NSPanel Management

**SideWindowPanel** (37 LOC)
- NSPanel subclass
- Config: floating level, fullScreenAuxiliary, nonactivatingPanel
- Transparent titlebar, hidden title
- Not movable by window background (fixed position)
- Key window capable, non-main window
- Released when closed = false (manual lifecycle)

**SideWindowController** (280 LOC)
- Owns panel; embeds NSHostingView<SideWindowView>
- State: `isVisible`, `isCollapsed`
- Services: tracker, statusBar, envOverride, buildStats, axInspector, camera
- Attach/detach flow:
  - `attach(to:)` subscribes to tracker.activeSimulator & isSimulatorFocused
  - Shows panel when simulator detected + focused
  - Hides when simulator lost or focus lost
- Collapse animation: spring physics (0.3s response, 0.8 damping) or 0.1s linear (reduce motion)
- Position updates: left/right/bottom via PositionCalculator
- Keyboard shortcut: Cmd+Shift+S toggle

**PositionCalculator** (120 LOC)
- Dynamic positioning: left/right/bottom based on simulator frame
- Considers screen bounds, panel size, simulator position
- Offset algorithms to keep panel visible + near simulator

**AXHighlightPanel** (90 LOC)
- NSPanel overlay for AX tree highlighting
- Yellow/red background, opaque
- Shown/hidden by AXInspectorService.$highlightFrame subscriber

---

## 7. Recent Commits & Features Added

### Latest Activity (Top 10 commits)

1. **93430a2** — "feat(env-overrides): fix smart invert detection and move state sync to view"
   - Smart invert fix (requires reading multiple plist keys)
   - State sync moved from AppDelegate to EnvironmentOverridesView.onAppear
   - Files: AppDelegate, EnvironmentOverrideService, Views

2. **488956f** — "feat(side-window): hide panel when simulator loses focus"
   - Panel now hides when Simulator.app not frontmost
   - Re-shows on focus regain
   - Respects `showSideWindow` user setting
   - Files: SideWindowController, SimulatorWindowTracker

3. **498b0dc** — "fix(env-overrides): show controls when sim detected but UDID unavailable"
   - Controls active even without Screen Recording permission
   - Falls back to "booted" pseudo-UDID

4. **c31beca** — "fix(side-window): remove placeholder sections, add env overrides preview"
   - Removed unused placeholder sections
   - Added EnvironmentOverridesView to preview

5. **8916b3f** — "feat(previews): add #Preview macros to all SwiftUI views"
   - All 22 SwiftUI views now have #Preview blocks
   - Enables canvas editing in Xcode

6. **72c18b8** — "feat(env-overrides): instant accessibility toggles without app relaunch"
   - Toggles apply immediately via simctl spawn + defaults write
   - No app relaunch required

7. **2e2020d** — "feat(animation): add spring physics for panel position tracking"
   - SpringAnimator utility for smooth position animations
   - 0.3s spring response with 0.8 damping

8. **8b49849** — "Reapply: feat(animation): fix AX tracking, fast position path, spring transitions"

9. **50fe8e1** — "docs: map existing codebase"
   - Architecture documentation added

10. **f9ae583** — "feat: initial commit — BoosterSimApp MVP"
    - Window detection, basic panel, placeholder features

---

## 8. Design System & Utilities

**DesignTokens.swift** (52 LOC)
```swift
Spacing:   xxs(2), xs(4), sm(8), md(12), lg(16), xl(20), xxl(24)  // 4pt grid
Radii:     small(4), medium(6), large(8), panel(10), onboarding(12)
SideWindowMetrics:
  - expandedWidth: 260pt
  - collapsedWidth: 28pt
  - minHeight: 400pt
  - rowHeight: 32pt
OnboardingMetrics: 480×520
PreferencesMetrics: 500×380
```

**AppLogger.swift** (13 LOC)
```swift
enum AppLogger {
    static let windowTracking = Logger(subsystem: "com.nextlabs.BoosterSimApp", category: "WindowTracking")
    static let permissions = Logger(...)
    static let settings = Logger(...)
}
// Filter in Console.app by subsystem: com.nextlabs.BoosterSimApp
```

**SpringAnimator.swift** (100 LOC)
- CABasicAnimation with spring timing
- `onFrameUpdate` callback for smooth position tracking
- `animateTo(frame:duration:)` method
- Respects reduce motion setting

---

## 9. Key Architecture Decisions

| Aspect | Decision | Rationale |
|--------|----------|-----------|
| **Window Detection** | Hybrid CGWindowList + AXObserver | CGWindowList for discovery, AX for real-time position updates during drag |
| **Device Classification** | simctl list devices --json + cache | Single source of truth; cached to minimize process spawning |
| **Simulator State Queries** | Cached with mtime checking | Avoids re-reading unchanged files (build stats, device info) |
| **AX Calls** | Background queue execution | AX APIs can block; main thread isolation |
| **Focus Tracking** | NSWorkspace notifications | Detects when Simulator.app loses focus |
| **Panel Positioning** | Spring animation | Smooth, physics-based tracking without hardcoded curves |
| **Settings Persistence** | @AppStorage | Native macOS UserDefaults integration |
| **Status Bar Config** | Codable struct | Type-safe, JSON-serializable |
| **Service Injection** | AppDelegate @EnvironmentObject | Centralized service ownership; avoids global singletons |
| **Collapse/Expand** | NSAnimationContext | Native CoreAnimation integration |

---

## 10. File Statistics Summary

| Directory | Files | LOC | Purpose |
|-----------|-------|-----|---------|
| App | 1 | 105 | @NSApplicationDelegate, service initialization |
| Models | 4 | 131 | Data structures, enums |
| Services | 11 | 1,373 | Business logic, simulator integration, AX tree, build monitoring |
| Views | 22 | 1,701 | SwiftUI UI components (side window, onboarding, prefs, menu bar) |
| Windows | 4 | 415 | NSPanel management, positioning, controllers |
| Utilities | 3 | 176 | Design tokens, logging, spring animation |
| Entry point | 1 | 23 | @main SwiftUI App |
| **Total** | **46** | **3,924** | Fully functional macOS menu bar companion |

---

## 11. Unresolved Questions & Future Enhancements

### Completed in Latest Commits
- ✅ Smart invert detection fixed (multi-key read)
- ✅ Panel visibility synchronized to simulator focus
- ✅ Environment overrides work without Screen Recording perm (pseudo-UDID fallback)
- ✅ All SwiftUI views have #Preview macros

### Known Placeholder Features
- 🔲 Capture section (Screenshot, Record Screen, GIF, Export) — UI only
- 🔲 Actions section (Reset App, Clear Keychain, Push Notification, Deep Link) — UI only
- 🔲 Design section (Grid Overlay, Safe Area, Ruler, Color Picker) — UI only
- 🔲 Network section (Throttle, Block Requests, View Logs, Certificates) — UI only
- 🔲 XcodeDetector service — Unused

### Potential Improvements
- Auto-discover Xcode path (vs. current empty default)
- Persistent custom status bar configurations
- Build notification alerts
- Accessibility permission auto-prompt on launch
- Multi-language localization

---

## 12. Build & Project Info

**Project Structure:**
- Main target: BoosterSimApp
- Test targets: BoosterSimAppTests, BoosterSimAppUITests
- Build system: Xcode 16+
- Deployment target: macOS 13+
- Language: Swift 5.10+

**Key Frameworks:**
- AppKit (NSPanel, NSApplication, AX APIs)
- SwiftUI (UI composition)
- Combine (reactive state, publishers)
- ApplicationServices (AXUIElement, AXObserver)
- ServiceManagement (SMAppService for launch-at-login)
- OSLog (structured logging)

**Notable Absence:**
- No external dependencies (pure Apple frameworks)
- No third-party UI libraries
- No network frameworks
- No database persistence

---

## Summary

BoosterSimApp is a mature, well-architected macOS companion app for iOS Simulator development. The codebase demonstrates:

- **Clean service layer** with clear separation of concerns
- **Reactive architecture** via Combine publishers
- **Intelligent window tracking** combining CGWindowList polling with real-time AX notifications
- **Smooth animations** via spring physics
- **Feature-complete UI** with onboarding, preferences, and multi-simulator support
- **Production-ready error handling** and logging
- **Zero external dependencies** (all native Apple frameworks)

Recent commits show active development focused on accessibility features, focus-based visibility, and UI polish. The codebase is well-positioned for rapid feature addition in captured sections (screenshot, recording, network tools).

