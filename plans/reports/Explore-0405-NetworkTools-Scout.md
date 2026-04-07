# Scout Report: BoosterSimApp Architecture for Network Tools Features

**Date:** April 5, 2026  
**Focus:** Service patterns, view architecture, AppDelegate wiring, and simctl capabilities  
**Goal:** Understand how to build Network Tools (Phase 5) following established patterns

---

## 1. Service Class Patterns

### Core Pattern: @MainActor ObservableObject with Combine

**Structure:**
- `@MainActor final class` (strict concurrency)
- Conforms to `ObservableObject`
- Uses `@Published` for reactive state
- Private `Set<AnyCancellable>` for subscription management
- Services injected into `AppDelegate` and passed to views via `@EnvironmentObject`

**Examples:**

#### SimCtlService (78 LOC)
**File:** `/Services/SimCtlService.swift`
- **Responsibility:** Centralized executor for `xcrun simctl` commands
- **Pattern:** Fire-and-forget Publisher-returning methods
  ```swift
  func run(_ args: [String]) -> AnyPublisher<String, SimCtlError>
  func runVoid(_ args: [String]) -> AnyPublisher<Void, SimCtlError>
  ```
- **Background execution:** Dispatches to `.global(qos: .userInitiated)`, delivers on `.main`
- **Error handling:** `SimCtlError` enum with 3 cases (commandFailed, xcrunNotFound, timeout)
- **No polling:** Fire-and-forget design; calling code handles state lifecycle

#### StatusBarService (110 LOC)
**File:** `/Services/StatusBarService.swift`
- **State:** `@Published isApplying`, `@Published lastError`
- **Models:** `StatusBarPreset` enum + `StatusBarConfig` struct
- **Methods:**
  - `applyPreset(_ preset:, to udid:)` — uses `simCtl.runVoid()`
  - `applyCustom(_ config:, to udid:)` — constructs CLI args from struct
  - `clearOverrides(for udid:)` — fire-and-forget
- **Sink pattern:** Weak-self capture, `store(in: &cancellables)`
- **Key insight:** Service owns completion handling; views just bind to @Published state

#### EnvironmentOverrideService (279 LOC)
**File:** `/Services/EnvironmentOverrideService.swift`
- **Published state:** 10 properties (appearance, reduceMotion, boldText, etc.)
- **Two-tier command strategy:**
  - **Tier 1:** Official `simctl ui` commands (appearance, contrast, content_size)
  - **Tier 2:** Plist defaults read/write via `simctl spawn` (com.apple.Accessibility domain)
- **Notification strategy:** Use `notifyutil -p` Darwin notifications for instant apply (no relaunch)
- **Complex example - setBoldText:**
  - Chained `flatMap` across 4 commands: write 3 plist keys, post notification
  - Pattern: `flatMap { [weak self] _ -> AnyPublisher<...> in ... }`
  - Error resilience: Prints to log, doesn't crash
- **Load state pattern:**
  ```swift
  func loadCurrentState(udid: String) {
    // Read current values from simulator, populate @Published properties
    simCtl.run(["ui", udid, "appearance"])
      .sink(receiveCompletion: { _ in }, 
            receiveValue: { output in 
              self?.appearance = ...
            })
      .store(in: &cancellables)
  }
  ```

#### HealthDataService (116 LOC)
**File:** `/Services/HealthDataService.swift`
- **State machine:** `@Published var state: HealthDataState` (idle, installing, generating, done, error)
- **Trigger pattern:**
  1. Check bundled app exists
  2. Set state → installing
  3. `simctl install <udid> <app path>` (flatMap)
  4. Set state → generating
  5. `simctl openurl <udid> <scheme://params>` (flatMap)
  6. On success: state → done, then `asyncAfter(3s)` reset to idle
  7. On error: state → error(message)
- **Key insight:** Companion app inside bundle; URL scheme parsing in iOS target

### What NOT to do (from code-standards.md)

- ❌ No `DispatchQueue.global()` for UI work (use `.main`)
- ❌ No `@unchecked Sendable` shortcuts
- ❌ No direct subprocess spawning (route through SimCtlService)
- ❌ No error suppression with `try!`
- ❌ No logging of sensitive data (UDIDs, file paths)

---

## 2. Side Panel View Architecture

### Section View Pattern

**Header Structure:** All feature sections follow the same layout:
```
┌─ Section Header (28pt) ─────────────────┐
│ [Icon] Title [Spacer] [Optional Status] │
└─────────────────────────────────────────┘
┌─ Content (when expanded) ───────────────┐
│ ┌─ Row 1 ──────────────────────────────┐│
│ │ [Icon] Label [Control] [Status]      ││
│ └──────────────────────────────────────┘│
│ ┌─ Row 2 ──────────────────────────────┐│
│ │ ...                                   ││
│ └──────────────────────────────────────┘│
└─────────────────────────────────────────┘
```

**Reusable Component:** `CollapsibleSection<Content>`
**File:** `/Views/Shared/CollapsibleSection.swift` (47 LOC)

```swift
struct CollapsibleSection<Content: View>: View {
    let title: String
    let icon: String
    @Binding var isExpanded: Bool
    @ViewBuilder let content: () -> Content
    // Respects accessibilityReduceMotion for animations
}
```

**Pattern:**
- Header button toggles `@State var isExpanded`
- Chevron rotates 0° → 90° on expand
- Content fades in/out with spring animation (or linear if reduce motion)
- Dividers inside content separate logical groups

### Example Section Views

#### StatusBarSectionView (129 LOC)
**File:** `/Views/SideWindow/StatusBarSectionView.swift`
- Header shows icon, title, optional progress indicator
- 2-button row: preset buttons + Clear/Custom toggle
- Custom controls expand below (time TextField, battery Slider)
- Disabled state when `udid == nil`

**Row structure:**
```swift
private func presetButtons: some View {
  VStack(spacing: Spacing.xs) {
    HStack(spacing: Spacing.xs) {
      ForEach(StatusBarPreset.allCases) { preset in
        Button { service.applyPreset(preset, to: udid) } 
        label: { VStack(spacing: 2) { Image(...) Text(...) } }
        .buttonStyle(.bordered)
        .disabled(isDisabled)
      }
    }
    .padding(.horizontal, Spacing.md)
    // Custom controls here if showCustom
  }
}
```

#### EnvironmentOverridesView (145 LOC)
**File:** `/Views/SideWindow/EnvironmentOverridesView.swift`
- **No CollapsibleSection** — always expanded, integrated into main view
- **Subsection headers:** Gray secondary text, no disclosure
- **Toggle rows pattern:**
  ```swift
  toggleRow("Label", icon: "symbol", 
    isOn: binding(\.property, { service.setSomething($0, udid:) }))
  ```
- **KeyPath-based binding factory:**
  ```swift
  private func binding(_ keyPath: KeyPath<Service, Bool>,
                       _ setter: @escaping (Bool) -> Void) -> Binding<Bool> {
    Binding(get: { service[keyPath: keyPath] }, set: setter)
  }
  ```
- **Dynamic Type slider:** A–slider–A with current size name below

#### HealthDataSectionView (156 LOC)
**File:** `/Views/SideWindow/HealthDataSectionView.swift`
- **Uses CollapsibleSection** with preset grid + manual controls
- **Presets grid:** LazyVGrid (2 columns, flexible)
  ```swift
  LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Spacing.xs) {
    ForEach(HealthPreset.allCases, id: \.self) { preset in
      presetButton(preset)
    }
  }
  ```
- **Status row:** Shows progress or completion state with icon + text
  ```swift
  switch healthDataService.state {
  case .installing: ProgressView() + "Installing companion…"
  case .generating: ProgressView() + "Generating data…"
  case .done: Image(.checkmark) + "Done"
  case .error(let msg): Image(.exclamation) + msg
  case .idle: EmptyView()
  }
  ```
- **Auth hint row:** Dismissable yellow info box (stored in @AppStorage)

#### BuildStatsSectionView (92 LOC)
**File:** `/Views/SideWindow/BuildStatsSectionView.swift`
- Header shows icon, title, count + average duration (computed)
- Chart row: embeds BuildChartView (Canvas bar chart)
- Build list: iterates first 10 records with checkmark/X icons, durations, dates
- Empty state: caption text when no builds

### SideWindowView: Root Composition
**File:** `/Views/SideWindow/SideWindowView.swift` (128 LOC)

```swift
struct SideWindowView: View {
  @ObservedObject var tracker: SimulatorWindowTracker
  @ObservedObject var controller: SideWindowController
  
  // Services injected as @EnvironmentObject (8 total)
  @EnvironmentObject var statusBarService: StatusBarService
  @EnvironmentObject var envOverrideService: EnvironmentOverrideService
  // ... etc
  
  var body: some View {
    Group {
      if controller.isCollapsed {
        CollapsedStripView(onExpand: { controller.toggleCollapsed() })
          .transition(.opacity)
      } else {
        VStack(spacing: 0) {
          SideWindowTitleBar(onCollapse: { controller.toggleCollapsed() })
          DeviceHeaderView(tracker: tracker, selectedIndex: $selectedSimIndex)
          EnvironmentOverridesView(udid: activeUDID)
          HealthDataSectionView(udid: activeUDID ?? "booted")
          SideWindowFooter()
        }
        .transition(.opacity)
      }
    }
    .onGeometryChange(for: CGFloat.self) { proxy in
      proxy.size.height
    } action: { _ in
      onHeightChanged?()  // Notify SideWindowController of content height change
    }
  }
}
```

**Key patterns:**
- `onGeometryChange` callback for content-driven panel resizing
- Services passed as environment objects from SideWindowController
- Multi-device picker state in SideWindowView (`@State selectedSimIndex`)

---

## 3. AppDelegate Service Orchestration

**File:** `/App/AppDelegate.swift` (107 LOC)

```swift
@MainActor final class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
  // Core services
  let tracker = SimulatorWindowTracker()
  let settings = AppSettings()
  let simCtlService = SimCtlService()
  
  // Feature services (lazy init, share simCtlService)
  lazy var statusBarService = StatusBarService(simCtl: simCtlService)
  lazy var envOverrideService = EnvironmentOverrideService(simCtl: simCtlService)
  lazy var buildStatsService = BuildStatsService()
  lazy var axInspectorService = AXInspectorService()
  lazy var cameraService = CameraService()
  lazy var healthDataService = HealthDataService(simCtl: simCtlService)
  lazy var axHighlightPanel = AXHighlightPanel()
  
  // Window controller receives all services
  lazy var sideWindowController = SideWindowController(
    settings: settings,
    tracker: tracker,
    statusBarService: statusBarService,
    envOverrideService: envOverrideService,
    buildStatsService: buildStatsService,
    axInspectorService: axInspectorService,
    cameraService: cameraService,
    healthDataService: healthDataService
  )
  
  func applicationDidFinishLaunching(_ notification: Notification) {
    // 1. Wire side window to tracker
    sideWindowController.attach(to: tracker)
    
    // 2. Start tracking + monitoring
    tracker.startTracking()
    buildStatsService.startMonitoring()
    
    // 3. Drive AX highlight panel from service
    axInspectorService.$highlightFrame
      .receive(on: DispatchQueue.main)
      .sink { [weak self] frame in
        if let frame { self?.axHighlightPanel.show(at: frame) }
        else { self?.axHighlightPanel.hide() }
      }
      .store(in: &cancellables)
    
    // 4. Show onboarding on first launch
    if !completedOnboarding {
      openOnboardingWindow()
    }
  }
  
  func applicationWillTerminate(_ notification: Notification) {
    tracker.stopTracking()
    buildStatsService.stopMonitoring()
  }
}
```

**Wiring pattern:**
1. Services instantiated or lazily-initialized in AppDelegate
2. Services passed to SideWindowController (dependency injection)
3. SideWindowController passes services as `@EnvironmentObject` to SwiftUI content
4. Views access services via `@EnvironmentObject` or bindings to service `@Published` properties
5. Service lifecycle managed by AppDelegate (startTracking, stopTracking, etc.)

---

## 4. SimCtlService: Command Execution Pattern

**File:** `/Services/SimCtlService.swift` (78 LOC)

### Method Signature
```swift
func run(_ args: [String]) -> AnyPublisher<String, SimCtlError> {
  // Executes on background queue, delivers on main
  // Returns AnyPublisher for composability
}

func runVoid(_ args: [String]) -> AnyPublisher<Void, SimCtlError> {
  // Convenience for fire-and-forget commands
  run(args).map { _ in () }.eraseToAnyPublisher()
}
```

### Usage Examples

**Simple:**
```swift
simCtl.runVoid(["ui", udid, "appearance", "dark"])
  .sink(receiveCompletion: { _ in }, receiveValue: { _ in })
  .store(in: &cancellables)
```

**Chained (flatMap):**
```swift
simCtl.run(["install", udid, companionPath])
  .flatMap { _ -> AnyPublisher<String, SimCtlError> in
    return simCtl.run(["openurl", udid, urlStr])
  }
  .sink(
    receiveCompletion: { completion in
      if case .failure(let err) = completion { self?.state = .error(err.localizedDescription) }
    },
    receiveValue: { _ in self?.state = .done }
  )
  .store(in: &cancellables)
```

**Error resilience:**
```swift
simCtl.run(["spawn", udid, "defaults", "read", ...])
  .sink(
    receiveCompletion: { _ in },  // Ignore errors, continue with degraded state
    receiveValue: { output in
      self?.property = (output.trimmingCharacters(in: .whitespacesAndNewlines) == "1")
    }
  )
  .store(in: &cancellables)
```

### Command Categories (from code inspection)

| Category | Example | Files |
|---|---|---|
| **UI Controls** | `ui <udid> appearance (light\|dark)` | StatusBarSectionView, EnvironmentOverridesView |
| **Status Bar** | `status_bar <udid> override --time 9:41 ...` | StatusBarService |
| **Spawn (Plist)** | `spawn <udid> defaults read/write com.apple.Accessibility <key>` | EnvironmentOverrideService |
| **App Install** | `install <udid> <app.app path>` | HealthDataService |
| **URL Scheme** | `openurl <udid> scheme://params` | HealthDataService |
| **Device List** | `list devices --json` | SimulatorWindowTracker (device classification) |

---

## 5. Existing Network-Related Code

### Current Status: Placeholder Only

**NetworkItems placeholder** in SideWindowView.swift (lines 58–63):
```swift
private let networkItems: [FeatureItem] = [
  FeatureItem(icon: "tortoise", label: "Throttle Network"),
  FeatureItem(icon: "xmark.shield", label: "Block Requests"),
  FeatureItem(icon: "list.bullet.rectangle", label: "View Logs"),
  FeatureItem(icon: "lock.shield", label: "Certificates")
]
```

**StatusBarConfig includes dataNetwork field:**
```swift
var dataNetwork: String = "wifi"  // wifi | 5g | lte | 4g | 3g | hide
```
— Built into `status_bar` CLI args, but no UI to change it yet

**No existing network inspection, throttling, or packet capturing code.**

---

## 6. Key Infrastructure Files

### Models

#### SimulatorWindow (36 LOC)
**File:** `/Models/SimulatorWindow.swift`
```swift
struct SimulatorWindow: Identifiable, Equatable {
  let id: CGWindowID          // Quartz window ID
  let pid: pid_t              // Process ID for AX observer
  var deviceName: String?     // nil without Screen Recording
  var frame: CGRect           // AppKit screen coordinates
  var isOnScreen: Bool
  var isMinimized: Bool
  var deviceType: SimulatorDeviceType = .iOS
  var udid: String?           // simctl UDID, nil if unavailable
}
```

#### AppSettings (52 LOC)
**File:** `/Models/AppSettings.swift`
- All persistence via `@AppStorage` (no raw UserDefaults)
- Keys: sideWindowPosition, showSideWindow, launchAtLogin, xcodePath
- `setLaunchAtLogin()` syncs with SMAppService

#### BuildRecord (28 LOC)
**File:** `/Models/BuildRecord.swift`
- timestamp, duration, device name, success flag
- Decoded from Xcode IDEActivityLog JSON

#### AXNode (18 LOC)
**File:** `/Models/AXNode.swift`
- Accessibility tree node: role, description, frame
- Hashable for list rendering

### Utilities

#### DesignTokens (51 LOC)
**File:** `/Utilities/DesignTokens.swift`

Single source of truth — **NEVER hardcode values:**
```swift
enum Spacing {
  static let xxs: CGFloat = 2      // 4pt grid
  static let xs: CGFloat = 4
  static let sm: CGFloat = 8
  static let md: CGFloat = 12
  static let lg: CGFloat = 16
  static let xl: CGFloat = 20
  static let xxl: CGFloat = 24
}

enum CornerRadius {
  static let small: CGFloat = 4
  static let medium: CGFloat = 6
  static let large: CGFloat = 8
  static let panel: CGFloat = 10
}

enum SideWindowMetrics {
  static let expandedWidth: CGFloat = 260
  static let collapsedWidth: CGFloat = 28
  static let minHeight: CGFloat = 400
  static let rowHeight: CGFloat = 32
  static let compactRowHeight: CGFloat = 28
  static let titleBarHeight: CGFloat = 28
}
```

#### SpringAnimator (112 LOC)
**File:** `/Utilities/SpringAnimator.swift`
- CADisplayLink-driven damped harmonic motion
- Stiffness=280, damping=22, rest threshold=0.5pt
- Auto-stops at rest
- Used for smooth panel position tracking

---

## 7. SideWindowController: Window Management

**File:** `/Windows/SideWindowController.swift` (224 LOC)

### Lifecycle

```swift
class SideWindowController: ObservableObject {
  @Published var isVisible = false
  @Published var isCollapsed = false
  
  func attach(to tracker: SimulatorWindowTracker) {
    // Subscribe to tracker.activeSimulator + tracker.isSimulatorFocused
    // Show/hide panel accordingly
  }
  
  func toggle() { isVisible ? hide() : show() }
  
  func toggleCollapsed() {
    // Animate collapse/expand with NSAnimationContext
    // Respects accessibilityDisplayShouldReduceMotion
  }
  
  func updatePosition(animated: Bool = false) {
    // Called on simulator frame changes or content height changes
    // Uses PositionCalculator + SpringAnimator or rigid tracking
  }
}
```

### Position Update Logic

```
Simulator moves/resizes
      ↓
AXObserver callback or poll
      ↓
SimulatorWindowTracker publishes new frame
      ↓
SideWindowController sink receives new activeSimulator
      ↓
updatePosition() called
      ↓
PositionCalculator.panelFrame() → target frame
      ↓
Detect side-switch? ─ YES → springAnimator.snapTo() → spring to rest
                   └─ NO → springAnimator.setTarget() → smoothly track

Content height changes (via SideWindowView.onGeometryChange)
      ↓
DispatchQueue.main.async { updatePosition() }
      ↓
Panel resizes + repositions
```

---

## 8. Design Standards

From `/docs/code-standards.md`:

### Concurrency
- `@MainActor` on all UI/AppKit-owning classes
- AppDelegate and SideWindowController explicitly marked
- Combine sinks and Timer callbacks dispatch to `.main`
- Swift 6 strict concurrency enforced

### File Organization
- **File size:** Keep under 200 LOC
- **MARK structure:** Imports, Properties, Lifecycle, Public Methods, Private Methods, Extensions
- **Naming:** PascalCase matching primary type

### State Management
- **Services:** `@Published` for observable state
- **Persistence:** `@AppStorage` only (no raw UserDefaults in views)
- **View state:** `@ObservedObject` / `@EnvironmentObject` (no `@StateObject` in non-owning views)

### Error Handling
- Use `try/catch` for throwing APIs
- Never `try!` — handle or propagate gracefully
- Permission failures are non-fatal; log and degrade gracefully
- Prefix logs with `[ClassName]`

### Logging
- Use `os.Logger` with subsystem `"app.booster.sim"`
- Log levels: `.debug` (state), `.info` (lifecycle), `.warning` (recoverable), `.error` (crashes)
- Never log sensitive data (UDIDs, file paths, tokens)

---

## 9. Phased Rollout for Network Tools (Phase 5)

Based on existing patterns, Network Tools should follow this sequence:

### Phase 5.1: Network Throttle Service
```swift
@MainActor
final class NetworkThrottleService: ObservableObject {
  @Published var throttleMode: ThrottleMode = .none  // none, 2g, 3g, lte, custom
  @Published var isApplying = false
  
  let simCtl: SimCtlService
  
  func apply(_ mode: ThrottleMode, udid: String) {
    // simctl emuctl set_simulator_network_throttle ...
  }
}
```

### Phase 5.2: NetworkThrottleSectionView
```swift
struct NetworkThrottleSectionView: View {
  @EnvironmentObject var service: NetworkThrottleService
  let udid: String?
  
  // 4 preset buttons (2G, 3G, LTE, Custom)
  // Custom slider for Mbps upload/download
  // Toggle enable/disable
}
```

### Phase 5.3: Block Requests Service
```swift
@MainActor
final class RequestBlockService: ObservableObject {
  @Published var rules: [BlockRule] = []
  @Published var isEnabled = false
  
  // Uses network proxy or URL protocol manipulation
  // May require companion app or system-level interception
}
```

### Phase 5.4: Network Log Service
```swift
@MainActor
final class NetworkLogService: ObservableObject {
  @Published var requests: [NetworkRequest] = []  // Last 100
  
  func startCapture(udid: String) { ... }
  func stopCapture() { ... }
  // Uses system.log, tcpdump, or Instruments integration
}
```

---

## 10. Summary: Patterns Checklist for Network Tools

### Service Class
- [ ] `@MainActor final class Service: ObservableObject`
- [ ] `@Published` properties for reactive state
- [ ] Inject `SimCtlService` if command execution needed
- [ ] Private `Set<AnyCancellable>` for subscriptions
- [ ] `init(simCtl: SimCtlService)` dependency injection
- [ ] Public methods return `AnyPublisher<Output, SimCtlError>` or manipulate @Published state
- [ ] `[weak self]` captures in Combine sinks
- [ ] Error handling: log errors, don't crash the app

### Section View
- [ ] Use `CollapsibleSection<Content>` for expandable sections
- [ ] Or follow StatusBarSectionView pattern (no disclosure)
- [ ] Header: icon + title + optional status
- [ ] Rows: 32pt height (use `SideWindowMetrics.rowHeight`)
- [ ] Controls: Toggles, Buttons, Pickers, Sliders
- [ ] Disabled state when `udid == nil`
- [ ] Bind to service `@Published` properties via `@EnvironmentObject`
- [ ] Use DesignTokens for all spacing/sizing

### AppDelegate Wiring
- [ ] Lazy init new service: `lazy var networkService = NetworkService(simCtl: simCtlService)`
- [ ] Pass to SideWindowController constructor
- [ ] SideWindowController injects as `@EnvironmentObject`
- [ ] View accesses via `@EnvironmentObject` 

### SimCtl Usage
- [ ] Route all xcrun commands through `SimCtlService.run()` or `runVoid()`
- [ ] Check UDID availability before calling (may be nil without Screen Recording)
- [ ] Parse output as String or JSON
- [ ] Handle non-zero exit codes gracefully
- [ ] No direct subprocess spawning

### View Composition
- [ ] Keep section views under 150 LOC
- [ ] Extract helper sub-views for complex rows
- [ ] Respect `@Environment(\.accessibilityReduceMotion)`
- [ ] Use spring animation for expand/collapse (linear if reduce motion)
- [ ] Semantic colors: `.primary`, `.secondary`, `.tertiary`
- [ ] SF Symbols only (no custom icons)

---

## File Summary Table

| File | LOC | Purpose | Pattern |
|---|---|---|---|
| SimCtlService.swift | 78 | xcrun executor | Publisher-returning methods |
| StatusBarService.swift | 110 | Status bar config | @Published state + sink pattern |
| EnvironmentOverrideService.swift | 279 | Accessibility toggles | Tier 1+2 commands, Darwin notifications |
| HealthDataService.swift | 116 | Companion app trigger | State machine: idle → installing → generating → done |
| SimulatorWindowTracker.swift | 199 | Simulator detection | Published simulators + activeSimulator |
| SideWindowController.swift | 224 | Panel lifecycle + spring tracking | Observable + Combine sink to tracker |
| PositionCalculator.swift | 90 | Frame math | Pure enum with static methods |
| SideWindowView.swift | 128 | Root composition | Content-driven height callback |
| StatusBarSectionView.swift | 129 | Status bar UI | Preset buttons + custom expander |
| EnvironmentOverridesView.swift | 145 | A11y toggles | KeyPath-based binding factory |
| HealthDataSectionView.swift | 156 | Health presets UI | LazyVGrid + status state machine |
| BuildStatsSectionView.swift | 92 | Build history UI | Service data mapping + chart |
| FeatureSectionView.swift | 90 | Collapsible section | Custom DisclosureGroupStyle |
| CollapsibleSection.swift | 47 | Reusable section wrapper | Generic ViewBuilder content |
| DesignTokens.swift | 51 | Layout constants | Single source of truth |
| AppSettings.swift | 52 | Persisted settings | @AppStorage only |
| SimulatorWindow.swift | 36 | Window data model | Struct with Identifiable |
| AppDelegate.swift | 107 | Service orchestration | Lazy init + dependency injection |

---

## Open Questions

1. **Network interception strategy:** Will Network Tools use:
   - `simctl emuctl` commands (if available)?
   - iOS companion app with URLProtocol?
   - System-level proxy or tcpdump integration?
   - Third-party network proxy (mitmproxy, Charles)?

2. **Request blocking implementation:** Does blocking require:
   - Simulator-level network configuration?
   - Companion app request filtering?
   - Mac-level firewall rules?

3. **TLS certificate management:** How to trust/untrust certificates?
   - Simulator Keychain direct manipulation?
   - iOS companion app with SecTrust APIs?

4. **Throttle commands:** What simctl commands exist?
   - `emuctl -d <udid> network throttle` or similar?
   - Custom iptables rules on simulator?

5. **Logging capture:** Source of truth for network logs?
   - App network activity via URLSession observer?
   - System-level packet capture (tcpdump)?
   - Instruments integration?

---

**Report Generated:** 2026-04-05 23:08  
**Scope:** Comprehensive architectural patterns, not implementation details  
**Next Steps:** Review existing service patterns, then prototype Network Throttle service following StatusBarService structure
