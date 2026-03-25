# Architecture

**Analysis Date:** 2026-03-25

## Pattern Overview

**Overall:** SwiftUI `@main` App + `@NSApplicationDelegateAdaptor` (AppKit service provider)

**Key Characteristics:**
- Service-oriented architecture: all business logic owned by AppDelegate services
- SwiftUI views as pure presentation layer, no business logic
- Reactive data flow via Combine `@Published` properties
- Dual-mode simulator detection: CGWindowList polling + real-time AXObserver callbacks
- Swift 6 strict concurrency with `@MainActor` enforcement
- Zero external dependencies (pure Apple frameworks only)

## Layers

**Presentation Layer:**
- Purpose: User-facing SwiftUI views and menu bar UI
- Location: `BoosterSimApp/Views/`
- Contains: SwiftUI views (MenuBarView, SideWindowView, PreferencesView, OnboardingView), view components (FeatureSectionView, DeviceHeaderView, etc.)
- Depends on: Models, Services (via @EnvironmentObject / @ObservedObject), DesignTokens
- Used by: NSPanel/MenuBarExtra hosts

**Window Management Layer:**
- Purpose: AppKit window lifecycle, positioning, and panel hosting
- Location: `BoosterSimApp/Windows/`
- Key components:
  - `SideWindowPanel` — NSPanel subclass with floating behavior (level .floating, hidesOnDeactivate = false)
  - `SideWindowController` — manages panel lifecycle, position sync, collapse state; embeds SwiftUI content via NSHostingController
  - `PositionCalculator` — pure static enum for frame math (right/left/bottom/dynamic positioning relative to simulator)
  - `AXHighlightPanel` — overlay panel for UI inspection highlighting
- Depends on: Models, Services, DesignTokens
- Used by: AppDelegate

**Service Layer:**
- Purpose: Business logic, system integration, state management
- Location: `BoosterSimApp/Services/`
- Services (all owned by AppDelegate):
  - **Core Detection:**
    - `SimulatorWindowTracker` — publishes @Published simulators + activeSimulator; dual-mode: CGWindowList poll (2s) + AXObserver per PID for real-time move/resize
    - `WindowEnumerator` — enumerates Simulator windows via CGWindowListCopyWindowInfo; handles Quartz→AppKit Y-flip
    - `WindowObserver` — wraps AXObserver to deliver real-time window move/resize via onFrameChanged closure
  - **Feature Services:**
    - `StatusBarService` — accesses Simulator status bar info via simctl
    - `EnvironmentOverrideService` — manages environment variable overrides
    - `BuildStatsService` — monitors and publishes build analytics (duration, frequency)
    - `AXInspectorService` — tree traversal via AXUIElement; publishes @Published highlightFrame for overlay
    - `CameraService` — detects camera availability per simulator
  - **System Integration:**
    - `PermissionManager` — Accessibility, Screen Recording, Xcode DerivedData checks/requests; polling for permission grants
    - `SimCtlService` — thin wrapper around xcrun simctl commands
    - `XcodeDetector` — locates Xcode and DerivedData path
- Depends on: Models, Utilities
- Used by: AppDelegate, Views (via @EnvironmentObject injection), SideWindowController

**Model Layer:**
- Purpose: Domain data structures and computed properties
- Location: `BoosterSimApp/Models/`
- Key models:
  - `SimulatorWindow` — detected window: id, pid, frame, deviceName, isOnScreen, isMinimized, deviceType (iOS/watchOS/tvOS/visionOS), udid
  - `SimulatorDeviceType` — enum with sfSymbol mapping
  - `AppSettings` — @AppStorage-backed user settings: position, showSideWindow, launchAtLogin, xcodePath
  - `AXNode` — parsed accessibility tree node
  - `BuildRecord` — analytics event: timestamp, duration, deviceType
- Depends on: Foundation only
- Used by: Services, Views

**Utility Layer:**
- Purpose: Constants and pure algorithms
- Location: `BoosterSimApp/Utilities/`
- Key utilities:
  - `DesignTokens` — static enums: Spacing (4pt grid), CornerRadius, SideWindowMetrics, OnboardingMetrics, PreferencesMetrics
  - `SpringAnimator` — spring physics engine for smooth panel position transitions; onFrameUpdate closure driven by Timer
- Depends on: Foundation only
- Used by: Views, SideWindowController, PositionCalculator

**App Entry Point:**
- Purpose: SwiftUI @main entry, menu bar scene, preferences scene, service initialization
- Location: `BoosterSimApp/BoosterSimAppApp.swift`
- Triggers: macOS app launch
- Responsibilities: Creates MenuBarExtra, Settings scene; injects AppDelegate via @NSApplicationDelegateAdaptor

## Data Flow

**Simulator Detection → Window Display:**

1. **On app launch (applicationDidFinishLaunching):**
   - AppDelegate starts SimulatorWindowTracker: `tracker.startTracking()`
   - Tracker refreshes device type cache (simctl list devices --json on background queue)
   - Tracker calls `WindowEnumerator.enumerateSimulatorWindows()` (CGWindowListCopyWindowInfo scan)
   - Tracker publishes `@Published simulators: [SimulatorWindow]` and `@Published activeSimulator: SimulatorWindow?`

2. **Real-time tracking (dual mode):**
   - **CGWindowList polling:** Timer fires every 2s, triggers `WindowEnumerator` scan, publishes full state
   - **AXObserver fast path:** For each simulator PID, `WindowObserver` registers on window elements for kAXWindowMoved/Resized notifications
   - Move/resize events trigger `onFrameChanged` closure → direct frame update without CGWindowList scan (low-latency during drag)

3. **Window attachment (SideWindowController):**
   - AppDelegate calls `sideWindowController.attach(to: tracker)`
   - SideWindowController subscribes to `tracker.$activeSimulator` via Combine sink
   - When simulator changes → `attachToSimulator(sim)` called
   - SpringAnimator animates panel frame from current position to new target (calculated by PositionCalculator)
   - Periodically (every 0.1s during animation) updates panel position via `panel.setFrame(frame, display: true)`

4. **SwiftUI view updates:**
   - SideWindowView observes `@ObservedObject var tracker: SimulatorWindowTracker`
   - When tracker.$activeSimulator changes → view redraws with new device info
   - Services injected as @EnvironmentObject → child views access state reactively

**Active Simulator Changes:**

1. User switches between multiple open simulators (or launches new one)
2. WindowEnumerator scan detects change → tracker publishes new activeSimulator
3. AppDelegate Combine sink reacts → reloads feature services:
   - `envOverrideService.loadCurrentState(udid:)`
   - `cameraService.probeSupport(pid:)`
   - `axInspectorService.loadRoot(for:)`
4. SideWindowController repositions panel
5. SideWindowView updates header + all feature sections

**AX Highlight (Inspection):**

1. AXInspectorService publishes `@Published highlightFrame: CGRect?`
2. AppDelegate subscribes: `axInspectorService.$highlightFrame.sink { frame in ... }`
3. When highlightFrame changes → `axHighlightPanel.show(at: frame)` or `.hide()`
4. Panel stays above simulator window, follows inspection target

## Key Abstractions

**SimulatorWindowTracker:**
- Purpose: Abstracts simulator detection (both CGWindowList polling + AXObserver)
- Examples: `BoosterSimApp/Services/SimulatorWindowTracker.swift`
- Pattern: Service class with @Published properties; delegates to WindowEnumerator (scan) + WindowObserver (real-time)

**PositionCalculator:**
- Purpose: Pure frame math, zero side effects
- Examples: `BoosterSimApp/Windows/PositionCalculator.swift`
- Pattern: Static enum with pure functions (rightFrame, leftFrame, bottomFrame, dynamicFrame)

**SideWindowController:**
- Purpose: AppKit window lifecycle + SwiftUI content embedding
- Examples: `BoosterSimApp/Windows/SideWindowController.swift`
- Pattern: Managed lifecycle, owns SideWindowPanel and SpringAnimator, hosts SwiftUI view via NSHostingController

**Service Pattern:**
- Purpose: Decoupled business logic, Combine-driven state updates
- Examples: StatusBarService, EnvironmentOverrideService, BuildStatsService, AXInspectorService, CameraService
- Pattern: ObservableObject with @Published properties; methods mutate state and trigger sink callbacks

## Entry Points

**App Entry Point:**
- Location: `BoosterSimApp/BoosterSimAppApp.swift`
- Triggers: macOS app launch (LSUIElement = true, no dock icon)
- Responsibilities:
  1. Define MenuBarExtra with MenuBarView
  2. Define Settings scene with PreferencesView
  3. Inject AppDelegate via @NSApplicationDelegateAdaptor

**AppDelegate Lifecycle:**
- Location: `BoosterSimApp/App/AppDelegate.swift`
- Triggers: NSApplication lifecycle callbacks
- Responsibilities:
  1. `applicationDidFinishLaunching` — start tracker, build services, attach side window, setup Combine sinks, show onboarding if needed
  2. `applicationWillTerminate` — stop tracker, cleanup services
  3. `applicationShouldTerminateAfterLastWindowClosed` — return false (menu bar app stays open)

**Side Window Content:**
- Location: `BoosterSimApp/Views/SideWindow/SideWindowView.swift`
- Triggers: SideWindowController embeds via NSHostingController
- Responsibilities: Root SwiftUI view; renders device header, feature sections, environment overrides, build stats, AX tree, camera info

**Menu Bar:**
- Location: `BoosterSimApp/Views/MenuBar/MenuBarView.swift`
- Triggers: MenuBarExtra in BoosterSimAppApp
- Responsibilities: Quick status, toggle side window visibility

## Error Handling

**Strategy:** Try-catch with print() fallback; no error propagation to UI (fail-silent or show "N/A")

**Patterns:**

1. **Permission checks (blocking issues):**
   - PermissionManager publishes @Published flags (accessibilityGranted, screenRecordingGranted, etc.)
   - Views observe → show permission request UI (onboarding, preferences)
   - User grants in System Settings, PermissionManager polling detects → views update

2. **Service failures (non-blocking):**
   - SimCtlService methods catch Process errors → return empty data / nil
   - WindowObserver errors (AXObserver create failure) → print and continue
   - BuildStatsService failures → show "—" in UI

3. **Window safety:**
   - SideWindowPanel lifecycle (show/hide) checks if simulator exists before ordering panel
   - PositionCalculator uses screen intersection logic — never crashes on edge cases

4. **Data model safety:**
   - SimulatorWindow.displayName fallback when deviceName is nil (Screen Recording not granted)
   - AXInspectorService safe traversal with guard-let, nil-safe @Published properties

## Cross-Cutting Concerns

**Logging:**
- Print statements to console (no structured logging)
- Prefix patterns: "[ClassName]" or "[Feature] message"
- Examples: "[WindowObserver] Failed to create AXObserver", "[AppSettings] Launch at login error"

**Validation:**
- PermissionManager validates system permissions (AXIsProcessTrusted, CGPreflightScreenCaptureAccess)
- WindowEnumerator filters windows by size (> 50pt width/height), layer (== 0), and ownership (Simulator app)
- SimulatorWindowTracker device type classification via device identifier string matching

**Authentication:**
- N/A (local app, no user accounts)

**Concurrency:**
- All UI work on @MainActor (AppDelegate, SideWindowController, views)
- Background work on DispatchQueue.global(qos: .background) for simctl queries (refreshDeviceTypeCache)
- Combine sinks receive on DispatchQueue.main → always post back to main thread
- No async/await used; pure Combine + Timer-based polling

**State Management:**
- AppDelegate owns all service instances (lazy var pattern for features)
- @Published properties in services drive SwiftUI view updates
- @AppStorage for persistence (AppSettings)
- @State in views for transient UI state (selected simulator index, etc.)

---

*Architecture analysis: 2026-03-25*
