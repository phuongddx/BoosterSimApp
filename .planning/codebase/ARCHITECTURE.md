# Architecture

**Analysis Date:** 2026-08-29

## System Overview

```text
┌─────────────────────────────────────────────────────────────┐
│                     Menu Bar Layer                          │
│  `BoosterSimApp/BoosterSimAppApp.swift`                     │
│  `BoosterSimApp/Views/MenuBar/MenuBarView.swift`            │
├──────────────────┬──────────────────────────────────────────┤
│  MenuBarExtra    │  Preferences (Settings scene)            │
│  Cmd+B toggle    │  `BoosterSimApp/Views/Preferences/`      │
└────────┬─────────┴────────────────┬─────────────────────────┘
         │                          │
         ▼                          ▼
┌─────────────────────────────────────────────────────────────┐
│               AppDelegate (Service Orchestrator)            │
│       `BoosterSimApp/App/AppDelegate.swift`                 │
│  Instantiates all services; wires to SideWindowController   │
├─────────────────────────────────────────────────────────────┤
│  Services:                                                  │
│  ┌───────────────┐ ┌──────────────┐ ┌────────────────────┐ │
│  │ WindowTracker  │ │ SimCtlService │ │ ConnectService     │ │
│  │ (AX + polling) │ │ (xcrun simctl)│ │ (Pulse TCP server)│ │
│  └───────┬───────┘ └──────┬───────┘ └────────┬───────────┘ │
│  ┌───────────────┐ ┌──────────────┐ ┌────────────────────┐ │
│  │ AXInspector    │ │ CaptureSvc   │ │ CertService        │ │
│  │ (AX tree walk) │ │ (SCStream)   │ │ (CA trust)         │ │
│  └───────┬───────┘ └──────┬───────┘ └────────────────────┘ │
│  ┌───────────────┐ ┌──────────────┐ ┌────────────────────┐ │
│  │ EnvOverride    │ │ DeepLinkSvc  │ │ DesignComparison   │ │
│  │ (simctl ui)    │ │ (URL open)   │ │ (screenshot diff)  │ │
│  └───────────────┘ └──────────────┘ └────────────────────┘ │
└────────────────────────────┬────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────┐
│                 SideWindowController                        │
│       `BoosterSimApp/Windows/SideWindowController.swift`    │
│  Manages SideWindowPanel; injects services as @Environment  │
├─────────────────────────────────────────────────────────────┤
│  SideWindowView → TabBarView → 4 tabs:                     │
│  CaptureTabView, DesignTabView, ActionsTabView,             │
│  NetworkTabView                                             │
└─────────────────────────────────────────────────────────────┘
         │                              │
         ▼                              ▼
┌─────────────────────┐    ┌──────────────────────────────────┐
│  iOS Simulator.app  │    │  BoosterSimConnect (iOS fwk)     │
│  (via AX + simctl)  │    │  `BoosterSimConnect/`            │
│                     │    │  PulseProxy swizzle → TCP        │
└─────────────────────┘    └──────────────────────────────────┘

Separate: boostersim CLI (`booster-sim-cli/`) — standalone SPM binary
```

## Component Responsibilities

| Component | Responsibility | File |
|-----------|----------------|------|
| `BoosterSimAppApp` | SwiftUI `@main` entry; declares `MenuBarExtra` + `Settings` scenes | `BoosterSimApp/BoosterSimAppApp.swift` |
| `AppDelegate` | Service orchestrator: instantiates all services, starts tracking/monitoring/server, manages onboarding | `BoosterSimApp/App/AppDelegate.swift` |
| `SideWindowController` | NSPanel lifecycle, position tracking (spring-animated), collapse/expand, SwiftUI hosting, keyboard shortcuts | `BoosterSimApp/Windows/SideWindowController.swift` |
| `SideWindowPanel` | `NSPanel` subclass: floating level, non-activating, no title bar | `BoosterSimApp/Windows/SideWindowPanel.swift` |
| `PositionCalculator` | Pure frame math for 4 panel positions (left/right/bottom/dynamic) | `BoosterSimApp/Windows/PositionCalculator.swift` |
| `SpringAnimator` | Display-link driven spring physics for panel position tracking | `BoosterSimApp/Utilities/SpringAnimator.swift` |
| `SimulatorWindowTracker` | Detects Simulator windows via `CGWindowList` + `AXObserver`; classifies device type via `simctl list devices --json` | `BoosterSimApp/Services/SimulatorWindowTracker.swift` |
| `WindowObserver` | Per-PID `AXObserver` wrapper for real-time window move/resize notifications | `BoosterSimApp/Services/WindowObserver.swift` |
| `SimCtlService` | Shared async `xcrun simctl` process executor (Combine `Future`) | `BoosterSimApp/Services/SimCtlService.swift` |
| `EnvironmentOverrideService` | Appearance/accessibility overrides via `simctl ui` commands | `BoosterSimApp/Services/EnvironmentOverrideService.swift` |
| `StatusBarService` | Carrier/wifi/battery status via `simctl status_bar` | `BoosterSimApp/Services/StatusBarService.swift` |
| `BuildStatsService` | Xcode build time monitoring from `LogStoreManifest.plist` | `BoosterSimApp/Services/BuildStatsService.swift` |
| `AXInspectorService` | Accessibility tree walker for Simulator (background queue, depth-limited) | `BoosterSimApp/Services/AXInspectorService.swift` |
| `CaptureService` | Screen recording via `ScreenCaptureKit` (`SCStream`); MP4/GIF export | `BoosterSimApp/Services/CaptureService.swift` |
| `ConnectService` | Manages Pulse TCP server, buffers decoded network events (max 500) | `BoosterSimApp/Services/ConnectService.swift` |
| `PulseServer` | `NWListener` TCP server with Bonjour registration (`_pulse._tcp`) | `BoosterSimApp/Services/PulseServer.swift` |
| `PulsePacketDecoder` | Decodes Pulse protocol packets from connected clients | `BoosterSimApp/Services/PulsePacketDecoder.swift` |
| `PulseClientConnection` | Single TCP client connection handler, feeds decoded events to publisher | `BoosterSimApp/Services/PulseClientConnection.swift` |
| `CertificateService` | CA certificate generation, install, rotation, and keychain reset for Simulator | `BoosterSimApp/Services/CertificateService.swift` |
| `CertificateStore` | Keychain-backed certificate data persistence | `BoosterSimApp/Services/CertificateStore.swift` |
| `CertificateModels` | Certificate status and operation enum types | `BoosterSimApp/Services/CertificateModels.swift` |
| `DeepLinkService` | Deep link testing: URL parsing, history/favorites persistence, `simctl openurl` | `BoosterSimApp/Services/DeepLinkService.swift` |
| `DesignComparisonService` | Screenshot capture and visual diff comparison | `BoosterSimApp/Services/DesignComparisonService.swift` |
| `CameraService` | Simulator camera simulation via `simctl` | `BoosterSimApp/Services/CameraService.swift` |
| `PermissionManager` | macOS permission checks/requests: Accessibility, Screen Recording, Xcode, DerivedData | `BoosterSimApp/Services/PermissionManager.swift` |
| `WindowEnumerator` | `CGWindowListCopyWindowInfo` wrapper for window discovery | `BoosterSimApp/Services/WindowEnumerator.swift` |
| `XcodeDetector` | Locates Xcode via `xcode-select -p` | `BoosterSimApp/Services/XcodeDetector.swift` |
| `BoosterSimConnect` | iOS framework loaded into Simulator app; activates PulseProxy URL swizzling | `BoosterSimConnect/BoosterSimConnect.swift` |
| `boostersim` CLI | Standalone SPM tool for AI agents to control Simulator (tap/swipe/type/screenshot) | `booster-sim-cli/Sources/boostersim/boostersim.swift` |

## Pattern Overview

**Overall:** Service-orchestrator with `ObservableObject`/`@EnvironmentObject` injection

**Key Characteristics:**
- Single `AppDelegate` class owns and wires all service singletons — manual dependency injection at construction time
- All services are `final class: ObservableObject` with `@Published` state; consumed by SwiftUI views via `@EnvironmentObject` or `@ObservedObject`
- Views are pure SwiftUI; no view models — services serve as view models
- `@MainActor` isolation on all services and the side window controller
- Combine used for async `simctl` process execution and service-to-service communication
- `NSPanel` (not `NSWindow`) for the side window, hosted via `NSHostingView`
- Separate Swift Package (`booster-sim-cli`) for the CLI tool, sharing no code with the app target

## Layers

**App Entry Layer:**
- Purpose: SwiftUI scene declaration, app lifecycle
- Location: `BoosterSimApp/BoosterSimAppApp.swift`, `BoosterSimApp/App/AppDelegate.swift`
- Contains: `@main` struct, `NSApplicationDelegate` implementation, service wiring, onboarding
- Depends on: All services, `SideWindowController`
- Used by: macOS runtime

**Service Layer:**
- Purpose: Business logic, system integration, external process management
- Location: `BoosterSimApp/Services/`
- Contains: 21 service files covering window tracking, simctl commands, network capture, certificates, accessibility, screen recording
- Depends on: `Models/`, `Utilities/`, macOS frameworks (AppKit, ScreenCaptureKit, Network, ApplicationServices)
- Used by: `AppDelegate`, `SideWindowController`, SwiftUI views via `@EnvironmentObject`

**View Layer:**
- Purpose: SwiftUI UI declarations
- Location: `BoosterSimApp/Views/`
- Contains: SideWindow tabs (capture, design, actions, network), menu bar, preferences, onboarding, shared components
- Depends on: Services (via `@EnvironmentObject`), `Models/`, `Utilities/DesignTokens.swift`
- Used by: `SideWindowController` (hosts `SideWindowView`), `BoosterSimAppApp` (hosts `MenuBarView`)

**Window Management Layer:**
- Purpose: NSPanel lifecycle, positioning math, spring animation
- Location: `BoosterSimApp/Windows/`
- Contains: `SideWindowController`, `SideWindowPanel`, `PositionCalculator`, `AXHighlightPanel`
- Depends on: `Utilities/SpringAnimator.swift`, `SimulatorWindowTracker`, `DesignTokens`
- Used by: `AppDelegate`

**Model Layer:**
- Purpose: Value types and persisted settings
- Location: `BoosterSimApp/Models/`
- Contains: `AppSettings`, `SimulatorWindow`, `AXNode`, `BuildRecord`
- Depends on: Foundation, CoreGraphics, SwiftUI (for `@AppStorage`)
- Used by: Services and views

**Utility Layer:**
- Purpose: Cross-cutting helpers
- Location: `BoosterSimApp/Utilities/`
- Contains: `AppLogger` (os.Logger), `DesignTokens` (spacing/radii/metrics), `SpringAnimator` (CADisplayLink physics)
- Depends on: OSLog, QuartzCore, Foundation
- Used by: All layers

**iOS Framework Layer (separate target):**
- Purpose: Network capture injection into Simulator apps
- Location: `BoosterSimConnect/`
- Contains: `BoosterSimConnect.swift` — activates PulseProxy swizzling in DEBUG builds
- Depends on: Pulse, PulseProxy (SPM dependencies, simulator-only)
- Used by: Loaded into Simulator app via `Bundle.load()`/`dlopen`

**CLI Layer (separate SPM package):**
- Purpose: AI-agent-friendly Simulator control
- Location: `booster-sim-cli/`
- Contains: ArgumentParser commands, standalone `SimCtlService` (synchronous, no Combine)
- Depends on: ArgumentParser, Foundation
- Used by: Terminal invocation (`boostersim tap --udid ... --x ... --y ...`)

## Data Flow

### Primary Request Path — Simulator Detection → Side Window Display

1. `SimulatorWindowTracker.startTracking()` (`BoosterSimApp/Services/SimulatorWindowTracker.swift`) begins `CGWindowList` scan + `AXObserver` registration
2. Simulator window found → publishes `activeSimulator` change
3. `SideWindowController.attach(to:)` (`BoosterSimApp/Windows/SideWindowController.swift`) receives via Combine `sink`
4. `attachToSimulator(_:)` calls `updatePosition()` → `PositionCalculator.panelFrame(...)` computes frame → `SpringAnimator.setTarget(frame:)` animates panel
5. `SideWindowView` renders tab content with `@EnvironmentObject` services

### Network Capture Path — Simulator App → BoosterSimApp

1. `BoosterSimConnect` (`BoosterSimConnect/BoosterSimConnect.swift`) activates `URLSessionProxyDelegate.enableAutomaticRegistration()` and `RemoteLogger.shared.enable()` inside Simulator app
2. `PulseServer` (`BoosterSimApp/Services/PulseServer.swift`) listens on TCP with Bonjour `_pulse._tcp`
3. Simulator app connects → `PulseClientConnection` (`BoosterSimApp/Services/PulseClientConnection.swift`) receives raw bytes
4. `PulsePacketDecoder` (`BoosterSimApp/Services/PulsePacketDecoder.swift`) decodes Pulse protocol
5. `ConnectService` (`BoosterSimApp/Services/ConnectService.swift`) receives decoded events via Combine publisher, buffers in `networkEvents` array
6. `NetworkTabView` (`BoosterSimApp/Views/SideWindow/tabs/NetworkTabView.swift`) displays filtered traffic list

### SimCtl Command Path — User Toggle → xcrun simctl

1. User toggles a setting in `EnvironmentOverrideService` view
2. Service calls `simCtl.run(["ui", udid, "appearance", value])` (`BoosterSimApp/Services/SimCtlService.swift`)
3. `SimCtlService` spawns `Process` for `xcrun simctl` on background queue
4. Result delivered to main thread via Combine `Future`

**State Management:**
- All mutable state lives in `@Published` properties on `ObservableObject` services
- Persistence: `@AppStorage` for settings, `UserDefaults` for certificate data and deep link history, Keychain (via `CertificateStore`) for certificate material
- No external database; no server-side state
- `Combine` `Set<AnyCancellable>` for subscription lifecycle management in each service

## Key Abstractions

**SimulatorWindowTracker (window detection):**
- Purpose: Central source of truth for which Simulator windows exist and which is active
- Examples: `BoosterSimApp/Services/SimulatorWindowTracker.swift`
- Pattern: `ObservableObject` with `@Published` arrays; dual detection via `CGWindowList` polling + `AXObserver` real-time callbacks

**SimCtlService (process execution):**
- Purpose: Shared async wrapper around `xcrun simctl` CLI
- Examples: `BoosterSimApp/Services/SimCtlService.swift` (app version), `booster-sim-cli/Sources/boostersim/Services/SimCtlService.swift` (CLI version — synchronous, separate implementation)
- Pattern: Combine `Future` wrapping `Process` execution; app version is `@MainActor`, CLI version is synchronous

**PulseServer + PulseClientConnection + PulsePacketDecoder (network capture):**
- Purpose: TCP server receiving Pulse-protocol network events from Simulator
- Examples: `BoosterSimApp/Services/PulseServer.swift`, `PulseClientConnection.swift`, `PulsePacketDecoder.swift`
- Pattern: `NWListener`-based server; per-connection `NWConnection` handlers; Combine `PassthroughSubject` for event fan-out

**SideWindowController (panel management):**
- Purpose: Orchestrates side window visibility, positioning, and content
- Examples: `BoosterSimApp/Windows/SideWindowController.swift`
- Pattern: `ObservableObject` that owns an `NSPanel`, embeds SwiftUI via `NSHostingView`, uses `CADisplayLink` spring physics for animated tracking

## Entry Points

**macOS App — `@main` SwiftUI:**
- Location: `BoosterSimApp/BoosterSimAppApp.swift`
- Triggers: App launch via `LSUIElement = true` (no Dock icon, agent app)
- Responsibilities: Declares `MenuBarExtra` scene and `Settings` scene; delegates all setup to `AppDelegate`

**CLI Tool — `@main` ParsableCommand:**
- Location: `booster-sim-cli/Sources/boostersim/boostersim.swift`
- Triggers: Terminal invocation (`boostersim <subcommand>`)
- Responsibilities: Argument parsing; delegates to command structs that call `SimCtlService` static methods

**iOS Framework — `@objc` class:**
- Location: `BoosterSimConnect/BoosterSimConnect.swift`
- Triggers: `Bundle.load()` / `dlopen` injection in DEBUG Simulator builds
- Responsibilities: Activates PulseProxy URL swizzling and RemoteLogger Bonjour broadcasting

## Architectural Constraints

- **Threading:** All app services are `@MainActor` isolated. `AXInspectorService` dispatches AX calls to background queue via `nonisolated fileprivate static` methods. `SimCtlService.run()` spawns `Process` on `DispatchQueue.global(qos: .userInitiated)`. `CaptureService` uses `SCStream` (system-managed threads).
- **Global state:** No module-level mutable singletons. All state is instance-based, owned by `AppDelegate` or individual services. `BoosterSimConnect.shared` is a singleton but only within the Simulator process (separate target).
- **Circular imports:** None detected — clean layering from Models → Utilities → Services → Views → Windows → App.
- **`LSUIElement = true`:** App runs as menu-bar agent, not Dock app. Single-instance enforcement via `NSRunningApplication.runningApplications(withBundleIdentifier:)` check in `applicationDidFinishLaunching`.
- **`@MainActor` on all services:** Required because SwiftUI `@Published` properties and `@EnvironmentObject` injection demand main-thread isolation. Background work dispatched explicitly within services.

## Anti-Patterns

### Service Explosion in AppDelegate Constructor

**What happens:** `AppDelegate` instantiates 12+ services as `lazy var` properties and passes all of them into `SideWindowController.init(...)`. The `SideWindowController` constructor accepts 11 service parameters.
**Why it's wrong:** Adding a new feature service requires modifying both `AppDelegate` and `SideWindowController.init`, plus `embedSwiftUIContent(...)`. The constructor signature grows linearly with feature count.
**Do this instead:** Consider a service container/registry pattern, or pass services via SwiftUI `@EnvironmentObject` injection (already used downstream) rather than constructor threading.

### Dual SimCtlService Implementations

**What happens:** The app target has `BoosterSimApp/Services/SimCtlService.swift` (Combine-based, async, `@MainActor`) and the CLI package has `booster-sim-cli/Sources/boostersim/Services/SimCtlService.swift` (synchronous, `Process`-based). Both wrap `xcrun simctl` with different APIs.
**Why it's wrong:** Divergent implementations of the same concept; changes to one are not reflected in the other.
**Do this instead:** Extract a shared SPM package for `simctl` process execution, used by both targets.

## Error Handling

**Strategy:** Combine-based error propagation with `AnyPublisher<Value, Error>`. `SimCtlError` enum for simctl failures. `CertificateService` uses a state machine (`CertificateOperation`/`CertificateStatus`) with retry support.

**Patterns:**
- `SimCtlService.run()` returns `AnyPublisher<String, SimCtlError>` — callers use `.sink(receiveCompletion:, receiveValue:)` or `.map`/`.tryMap`
- `CaptureService` publishes `lastError: String?` for UI display
- `CertificateService.begin(_:)` guards against concurrent operations and returns `Bool`
- `ConnectService.handleStreamError(_:)` for stream failure reporting
- Many services silently ignore Combine completion errors (e.g., `receiveCompletion: { _ in }`)

## Cross-Cutting Concerns

**Logging:** `os.Logger` via `AppLogger` enum (`BoosterSimApp/Utilities/AppLogger.swift`). Four categories: `windowTracking`, `permissions`, `settings`, `certificates`. Filter in Console.app by subsystem `com.nextlabs.BoosterSimApp`. Some services use bare `print()` for debug output.

**Validation:** Minimal. `DeepLinkService.parseURL(_:)` validates URL format. `PermissionManager` checks system permission status. `SimCtlService` validates `xcrun` existence and process exit code. No input validation framework.

**Authentication:** Not applicable — the app is a local macOS tool with no user accounts. Certificate trust management for HTTPS interception in Simulator is handled by `CertificateService`/`CertificateStore`.

---

*Architecture analysis: 2026-08-29*
