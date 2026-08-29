# Architecture

**Analysis Date:** 2026-08-29

## System Overview

```text
┌──────────────────────────────────────────────────────────────┐
│                    Menu Bar Layer (SwiftUI)                   │
│           `BoosterSimApp/BoosterSimAppApp.swift`              │
│  ┌─────────────────┐  ┌──────────────────────────────────┐   │
│  │  MenuBarExtra   │  │  Settings scene (Cmd+,)          │   │
│  │ `MenuBarView`    │  │  `PreferencesView`              │   │
│  └─────────────────┘  └──────────────────────────────────┘   │
├──────────────────────────────────────────────────────────────┤
│                  AppDelegate (AppKit Hub)                     │
│              `BoosterSimApp/App/AppDelegate.swift`             │
│  Instantiates & owns all services; bridges AppKit ↔ SwiftUI   │
├──────────┬──────────┬──────────┬──────────┬─────────────────┤
│ Tracker  │ Services │ Services │ Services │ Windows          │
│          │ (simctl) │ (AX/OS)  │ (Network)│                  │
│ SimWin-  │ StatusBar│ AXIns-   │ Connect  │ SideWindow-      │
│ dowTrack-│ Service  │ pector   │ Service  │ Controller       │
│ er       │ EnvOver- │ Camera   │ Pulse-   │ SideWindowPanel  │
│          │ rideSrv  │ Capture  │ Server   │ AXHighlight-     │
│          │ BuildSt- │ Design-  │ Pulse-   │ Panel            │
│          │ ats      │ Compar-  │ Client   │                  │
│          │ Cert-    │ ison     │ Connect  │                  │
│          │ ificate  │ DeepLink │          │                  │
│          │ Service  │ Service  │          │                  │
├──────────┴──────────┴──────────┴──────────┴─────────────────┤
│                    View Layer (SwiftUI)                       │
│         `BoosterSimApp/Views/SideWindow/`                     │
│  SideWindowView → TabBarView → [Capture|Design|Actions|      │
│                                   Network]TabView             │
└──────────────────────────────────────────────────────────────┘
         │                                     │
         ▼                                     ▼
┌────────────────────┐          ┌──────────────────────────┐
│  macOS System APIs │          │  iOS Simulator (remote)  │
│  CGWindowList      │          │  BoosterSimConnect SPM   │
│  AXUIElement       │◄────────│  (PulseProxy swizzling)  │
│  ScreenCaptureKit  │  TCP    │  Bonjour _pulse._tcp     │
│  xcrun simctl      │          │  Pulse binary protocol   │
└────────────────────┘          └──────────────────────────┘
```

## Component Responsibilities

| Component | Responsibility | File |
|-----------|----------------|------|
| `BoosterSimAppApp` | `@main` SwiftUI entry; defines `MenuBarExtra` scene and `Settings` scene; adapts `AppDelegate` | `BoosterSimApp/BoosterSimAppApp.swift` |
| `AppDelegate` | Service container (lazy init); wires services to `SideWindowController`; starts tracking/monitoring/server; manages onboarding; singleton enforcement | `BoosterSimApp/App/AppDelegate.swift` |
| `SimulatorWindowTracker` | Detects iOS/watchOS/tvOS/visionOS Simulator windows via `CGWindowList` + `AXObserver`; publishes `activeSimulator` and `simulators`; classifies device types via `simctl list devices --json` | `BoosterSimApp/Services/SimulatorWindowTracker.swift` |
| `WindowObserver` | Wraps `AXObserver` C API for real-time window move/resize events on a specific Simulator PID; delivers fast-path `onFrameChanged` callback bypassing full CGWindowList scans | `BoosterSimApp/Services/WindowObserver.swift` |
| `WindowEnumerator` | Pure static scanner: `CGWindowListCopyWindowInfo` → `[SimulatorWindow]`; converts Quartz to AppKit coordinates | `BoosterSimApp/Services/WindowEnumerator.swift` |
| `SimCtlService` | Shared `xcrun simctl` process executor; returns `AnyPublisher<String, SimCtlError>` on background queue, delivered on main | `BoosterSimApp/Services/SimCtlService.swift` |
| `StatusBarService` | Applies status bar presets/configs via `simctl status_bar` | `BoosterSimApp/Services/StatusBarService.swift` |
| `EnvironmentOverrideService` | Reads/writes appearance, contrast, content size, and 8 accessibility toggles via `simctl ui` + `simctl spawn defaults` | `BoosterSimApp/Services/EnvironmentOverrideService.swift` |
| `BuildStatsService` | Polls `DerivedData/Logs/Build/LogStoreManifest.plist` every 5s for Xcode build history; caches by mtime; keeps top 30 sorted builds | `BoosterSimApp/Services/BuildStatsService.swift` |
| `AXInspectorService` | Walks Simulator AX tree lazily to max depth 5; publishes `rootNodes` and `highlightFrame`; dispatches AX calls to background queue | `BoosterSimApp/Services/AXInspectorService.swift` |
| `CameraService` | AX menu automation to toggle Simulator's Features → Camera → Front/Back Mac camera | `BoosterSimApp/Services/CameraService.swift` |
| `CertificateService` | Orchestrates CA certificate generation (via OpenSSL), installation (via `simctl addrootcert`), rotation, and status reconciliation per simulator UDID | `BoosterSimApp/Services/CertificateService.swift` |
| `CertificateStore` | Manages `ca.pem`/`ca.key` on disk in `~/Library/Application Support/BoosterSimApp/Certificates/`; atomic install via stage-then-rename; reads cert metadata via Security framework | `BoosterSimApp/Services/CertificateStore.swift` |
| `CaptureService` | Screen recording via `ScreenCaptureKit` with configurable quality/FPS; supports MP4/GIF export and device bezel overlay | `BoosterSimApp/Services/CaptureService.swift` |
| `DesignComparisonService` | Manages design overlay image, opacity, split-view comparison, grid overlay, color picker, and saved presets | `BoosterSimApp/Services/DesignComparisonService.swift` |
| `DeepLinkService` | Opens URLs in Simulator via `xcrun simctl openurl`; manages URL history and favorites with `@AppStorage` persistence | `BoosterSimApp/Services/DeepLinkService.swift` |
| `ConnectService` | Hosts `PulseServer`; converts `PulseDecodedEvent` → `NetworkEvent`; manages connection state machine (disconnected → searching → connected); caps events at 500 | `BoosterSimApp/Services/ConnectService.swift` |
| `PulseServer` | `NWListener` TCP server with Bonjour `_pulse._tcp.` service; accepts connections, wraps each in `PulseClientConnection`; publishes decoded events via `PassthroughSubject` | `BoosterSimApp/Services/PulseServer.swift` |
| `PulseClientConnection` | Per-client state machine (connecting → waitingHello → active → disconnected); receive loop with buffer; dispatches packet codes (0=clientHello, 6=ping, 8=taskCreated, 10=taskCompleted) | `BoosterSimApp/Services/PulseClientConnection.swift` |
| `PulsePacketDecoder` | Pure static functions for Pulse binary protocol: 5-byte header parsing, zlib decompression, JSON decoding of `PulseNetworkEvent`, serverHello/pong encoding | `BoosterSimApp/Services/PulsePacketDecoder.swift` |
| `SideWindowController` | Manages `SideWindowPanel` lifecycle, position sync with Simulator window, collapse/expand state, keyboard shortcuts; hosts SwiftUI content via `NSHostingView` | `BoosterSimApp/Windows/SideWindowController.swift` |
| `SideWindowPanel` | `NSPanel` subclass: floating level, non-activating, hidesOnDeactivate=false, canJoinAllSpaces | `BoosterSimApp/Windows/SideWindowPanel.swift` |
| `AXHighlightPanel` | Transparent floating `NSPanel` that draws orange rounded-rect highlight over selected AX element; auto-dismisses after 2.5s | `BoosterSimApp/Windows/AXHighlightPanel.swift` |
| `PositionCalculator` | Pure static frame math for 4 side-window positions (left/right/bottom/dynamic) | `BoosterSimApp/Windows/PositionCalculator.swift` |
| `PermissionManager` | Checks/requests Accessibility, Screen Recording, Xcode detection, DerivedData security-scoped bookmark | `BoosterSimApp/Services/PermissionManager.swift` |
| `XcodeDetector` | Detects Xcode installation path via filesystem checks at common paths | `BoosterSimApp/Services/XcodeDetector.swift` |

## Pattern Overview

**Overall:** Service-Container + Observable-Object Injection

**Key Characteristics:**
- `AppDelegate` is the **single service container** — every service is `lazy var`-instantiated there and injected downward
- All services are `@MainActor final class: ObservableObject` — views observe published state via `@EnvironmentObject` or `@ObservedObject`
- Services communicate outward via **Combine `@Published` properties**, not delegates
- `SideWindowController` receives all services in its `init` and hosts a single `NSHostingView<SideWindowView>` where services are injected as `.environmentObject()`
- The app uses `LSUIElement = true` (no Dock icon); `applicationShouldTerminateAfterLastWindowClosed` returns `false`
- Singleton enforcement on launch: terminates duplicate instances

## Layers

**App Layer:**
- Purpose: Application lifecycle, service wiring, onboarding
- Location: `BoosterSimApp/App/`
- Contains: `AppDelegate.swift`, `BoosterSimAppApp.swift` (at `BoosterSimApp/` root)
- Depends on: All service and window layers
- Used by: SwiftUI scene system

**Services Layer:**
- Purpose: Business logic, external process orchestration, protocol handling
- Location: `BoosterSimApp/Services/`
- Contains: 21 service files covering simulator control (via `simctl`), accessibility inspection, screen capture, certificate management, network protocol, deep links, design comparison, permissions
- Depends on: Models, macOS system APIs (`AXUIElement`, `CGWindowList`, `ScreenCaptureKit`, `Network` framework, `Security`)
- Used by: AppDelegate, Views (via environment objects)

**Windows Layer:**
- Purpose: AppKit window management, panel configuration, position math, spring animation
- Location: `BoosterSimApp/Windows/`
- Contains: `SideWindowController`, `SideWindowPanel`, `AXHighlightPanel`, `PositionCalculator`
- Depends on: Services (for data binding), Utilities (`SpringAnimator`, `DesignTokens`)
- Used by: AppDelegate

**Views Layer:**
- Purpose: SwiftUI presentation — side window tabs, menu bar, preferences, onboarding, shared components
- Location: `BoosterSimApp/Views/`
- Contains: `SideWindow/` (main UI with 4 tabs + tab content), `MenuBar/`, `Preferences/`, `Onboarding/`, `Shared/`
- Depends on: Services (via `@EnvironmentObject`), Models, DesignTokens
- Used by: SideWindowController (hosted), SwiftUI scene system (MenuBar, Preferences)

**Models Layer:**
- Purpose: Value types and data structures
- Location: `BoosterSimApp/Models/`
- Contains: `SimulatorWindow`, `AXNode`, `BuildRecord`, `AppSettings`, `SideWindowPosition` enum
- Depends on: Foundation, CoreGraphics
- Used by: Services and Views

**Utilities Layer:**
- Purpose: Cross-cutting helpers — logging, animation, design constants
- Location: `BoosterSimApp/Utilities/`
- Contains: `AppLogger`, `SpringAnimator`, `DesignTokens`
- Depends on: OSLog, QuartzCore, Foundation
- Used by: Services, Windows, Views

## Data Flow

### Primary Request Path (e.g., Apply Status Bar Preset)

1. User taps preset in `StatusBarSectionView` (`BoosterSimApp/Views/SideWindow/StatusBarSectionView.swift`)
2. Calls `statusBarService.applyPreset(_:to:)` (`BoosterSimApp/Services/StatusBarService.swift`)
3. `StatusBarService` calls `simCtl.run(["status_bar", udid, ...])` (`BoosterSimApp/Services/SimCtlService.swift`)
4. `SimCtlService` spawns `Process("/usr/bin/xcrun", ["simctl", ...])` on background queue, delivers stdout/stderr via Combine publisher

### Simulator Window Detection Flow

1. `AppDelegate.applicationDidFinishLaunching` calls `tracker.startTracking()` (`BoosterSimApp/App/AppDelegate.swift:60`)
2. `SimulatorWindowTracker.startTracking` calls `WindowEnumerator.enumerateSimulatorWindows()` for initial scan, then sets up `AXObserver` via `WindowObserver` for real-time move/resize, plus a polling fallback timer
3. On detection, publishes `activeSimulator: SimulatorWindow?` via `@Published`
4. `SideWindowController` subscribes to `tracker.$activeSimulator` → calls `attachToSimulator()` → `updatePosition()` to snap the floating panel to the Simulator window

### Network Event Capture Flow (BoosterSimConnect)

1. iOS app links `BoosterSimConnect` SPM framework in DEBUG builds → `URLSessionProxyDelegate.enableAutomaticRegistration()` swizzles all `URLSession` traffic
2. `RemoteLogger.shared.enable()` starts Bonjour broadcasting on `_pulse._tcp.`
3. `ConnectService.startServer()` creates `PulseServer` (NWListener TCP, ephemeral port, Bonjour `_pulse._tcp.`)
4. iOS client connects → `PulseClientConnection` runs receive loop → parses 5-byte header + zlib-compressed JSON body via `PulsePacketDecoder`
5. Decoded `PulseDecodedEvent` flows: `PulseClientConnection.onEvent` → `PulseServer.eventSubject` → `ConnectService.handleDecodedEvent` → converts to `NetworkEvent` → appends to `networkEvents` array
6. `NetworkTabView` reads `connectService.networkEvents` and `connectService.connectionState` via `@EnvironmentObject`

**State Management:**
- All mutable state lives in `@MainActor ObservableObject` services
- Persistence: `@AppStorage` for user settings (position, launch-at-login, onboarding flag) and `UserDefaults` for deep link history/favorites, design presets
- Certificate files on disk at `~/Library/Application Support/BoosterSimApp/Certificates/`
- No database; no external state store

## Key Abstractions

**BoosterNetworkProtocol (Pulse):**
- Purpose: Binary TCP protocol for capturing iOS URLSession traffic from Simulator apps
- Wire format: 5-byte header `[code: UInt8][contentSize: UInt32 BE]` + zlib-compressed JSON body
- Packet codes: 0=clientHello, 1=serverHello, 6=ping, 7=messageStored, 8=networkTaskCreated, 9=taskProgressUpdated, 10=networkTaskCompleted
- `networkTaskCompleted` body: 12-byte manifest (3×UInt32 BE: messageSize, requestBodySize, responseBodySize) followed by concatenated payloads
- Examples: `BoosterSimApp/Services/PulsePacketDecoder.swift`, `BoosterSimApp/Services/PulseClientConnection.swift`
- Pattern: State machine per connection (`connecting → waitingHello → active → disconnected`)

**SimCtlService (Command Executor):**
- Purpose: Centralized `xcrun simctl` process execution with Combine-based async delivery
- All simulator control services (`StatusBarService`, `EnvironmentOverrideService`, `CertificateService`) delegate to this
- Examples: `BoosterSimApp/Services/SimCtlService.swift`
- Pattern: `AnyPublisher<String, SimCtlError>` returned; background `Process` execution, main-queue delivery

**SimulatorWindowTracker (Window Detection Hub):**
- Purpose: Detects and tracks Simulator windows using dual strategy: `CGWindowList` polling + `AXObserver` real-time callbacks
- Classifies device type (iOS/watchOS/tvOS/visionOS) via `simctl list devices --json` cache
- Publishes `activeSimulator`, `simulators`, `isSimulatorFocused`
- Examples: `BoosterSimApp/Services/SimulatorWindowTracker.swift`
- Pattern: ObservableObject with Combine publishers; owns `WindowObserver` instances keyed by PID

## Entry Points

**`BoosterSimAppApp` (@main SwiftUI App):**
- Location: `BoosterSimApp/BoosterSimAppApp.swift`
- Triggers: Automatic on app launch
- Responsibilities: Defines `MenuBarExtra` scene (with `MenuBarView`) and `Settings` scene (with `PreferencesView`); bridges `AppDelegate` via `@NSApplicationDelegateAdaptor`

**`AppDelegate.applicationDidFinishLaunching`:**
- Location: `BoosterSimApp/App/AppDelegate.swift:54`
- Triggers: System call on launch
- Responsibilities: Singleton enforcement, attaches side window to tracker, starts tracking/build monitoring/connect server, wires AX highlight panel, shows onboarding on first launch

**BoosterSimConnect (iOS framework activation):**
- Location: `BoosterSimConnect/BoosterSimConnect.swift`
- Triggers: `Bundle.load()` / `dlopen` in DEBUG Simulator builds
- Responsibilities: Activates PulseProxy URLSession swizzling, configures sensitive header redaction, enables Bonjour remote logging

**`boostersim` CLI:**
- Location: `booster-sim-cli/Sources/boostersim/boostersim.swift`
- Triggers: `boostersim <subcommand>` in terminal
- Responsibilities: ArgumentParser-based CLI with 8 subcommands (tap, swipe, type, screenshot, list-elements, list-devices, press, doctor) for AI agent simulator control

## Architectural Constraints

- **Threading:** Single `@MainActor` for all services and UI. Background work dispatched explicitly via `DispatchQueue.global()` (e.g., `SimCtlService` process spawning, `AXInspectorService` tree walking, `CameraService` AX menu automation). `CertificateStore` uses a dedicated serial `DispatchQueue` for OpenSSL file I/O.
- **Global state:** `AppDelegate` is the de facto singleton service container. No other module-level singletons exist (services are instance-based). `AppLogger` is a pure-enum namespace (no mutable state).
- **Circular imports:** None detected. Dependency flows strictly downward: App → Windows → Services → Models/Utilities. Views depend on Services (via environment objects) but services never import Views.
- **Process spawning:** Multiple services spawn external processes (`xcrun simctl`, `openssl`). All use `Process` with timeout handling and stderr capture.

## Anti-Patterns

### `PulseDecodedEvent` Not `Sendable`

**What happens:** `PulseDecodedEvent` enum in `BoosterSimApp/Services/PulseClientConnection.swift` carries `PulseNetworkEvent` (which is `Sendable`) and raw `Data?` but the enum itself is not marked `Sendable`, despite being created on a background `DispatchQueue` and consumed on `@MainActor`.
**Why it's wrong:** Violates Swift 6 concurrency safety; the compiler should diagnose this with strict concurrency checking.
**Do this instead:** Mark `PulseDecodedEvent` as `Sendable` (its associated values are already `Sendable`).

### Domain Model in View Subdirectory

**What happens:** `NetworkEvent`, `HTTPMethod`, `StatusRange`, `TrafficFilter`, and `ConnectionState` are defined in `BoosterSimApp/Views/SideWindow/network/NetworkEventModel.swift` — a view-layer file — but are consumed by `ConnectService` in the Services layer.
**Why it's wrong:** Services import types from Views, creating a reverse dependency. These are domain models, not view code.
**Do this instead:** Move these types to `BoosterSimApp/Models/` (e.g., `NetworkEvent.swift`). The view file can still exist for view-specific helpers, but service-layer types belong in Models.

### Sidebar Types Defined in Service Files

**What happens:** `StatusBarConfig` and `StatusBarPreset` enums are defined inside `BoosterSimApp/Services/StatusBarService.swift`; `AppearanceStyle` is in `BoosterSimApp/Services/EnvironmentOverrideService.swift`; `CertificateMetadata`, `CertificateStatus`, `CertificateOperation`, `CertificateError` are in `BoosterSimApp/Services/CertificateModels.swift`.
**Why it's wrong:** Models co-located with services make reuse and testing harder. Some types (like `CertificateError`) are clearly domain models.
**Do this instead:** Move pure data types to `BoosterSimApp/Models/`. Service files should contain only the service class. Small service-specific enums (like `AppearanceStyle`) are acceptable in-place.

## Error Handling

**Strategy:** Typed error enums per concern with `LocalizedError` conformance.

**Patterns:**
- `SimCtlError` (`.commandFailed`, `.xcrunNotFound`, `.timeout`) — propagated via Combine `Failure` type
- `CertificateError` (`.invalidCertFormat`, `.noUDIDSelected`, `.opensslFailed`, `.simctlFailed`, `.timeout`) — handled in UI with user-facing messages
- `PulseClientConnection` silently drops malformed packets (returns early from buffer processing)
- `CaptureService` publishes `lastError: String?` — displayed in UI when non-nil
- `StatusBarService` publishes `lastError: String?`
- `XcodeDetector` returns `String?` (nil = not found) — no error type

## Cross-Cutting Concerns

**Logging:** `AppLogger` enum in `BoosterSimApp/Utilities/AppLogger.swift` — 4 `os.Logger` instances (`windowTracking`, `permissions`, `settings`, `certificates`) under subsystem `com.nextlabs.BoosterSimApp`. Not all services use it; some use `print()`.

**Validation:** Minimal. `TrafficFilter.matches(_:)` validates network events against filter. `EnvironmentOverrideService` does not validate content size index bounds. `PositionCalculator` clamps panel position within screen bounds.

**Authentication:** None. The app is a local developer tool with no user authentication. Certificate trust is managed via `simctl addrootcert`.

---

*Architecture analysis: 2026-08-29*
