# System Architecture

## Overview

BoosterSimApp uses a SwiftUI App + AppKit hybrid architecture. The `@main` SwiftUI entry point owns the menu bar and preferences scenes; AppKit services handle all window management, system integration, and Simulator tracking.

## Layer Diagram

```
┌─────────────────────────────────────────────────────┐
│  SwiftUI Scenes (BoosterSimAppApp)                  │
│  ├── MenuBarExtra → MenuBarView                     │
│  └── Settings scene → PreferencesView              │
└───────────────┬─────────────────────────────────────┘
                │ @NSApplicationDelegateAdaptor
┌───────────────▼─────────────────────────────────────┐
│  AppDelegate (@MainActor)                           │
│  ├── SimulatorWindowTracker (owns Combine state)    │
│  ├── SideWindowController (owns NSPanel)            │
│  ├── AppSettings (@AppStorage persistence)          │
│  ├── CertificateService (CA trust management)       │
│  └── Onboarding NSWindow (first-launch only)        │
└───────────────┬─────────────────────────────────────┘
                │ Combine @Published
┌───────────────▼─────────────────────────────────────┐
│  Core Services                                      │
│  ├── WindowEnumerator — CGWindowListCopyWindowInfo  │
│  ├── WindowObserver — AXObserver C callbacks        │
│  ├── PermissionManager — Accessibility/SR/DData     │
│  └── SimulatorWindowTracker orchestrator            │
├─────────────────────────────────────────────────────┤
│  Feature Services (Phases 5+)                       │
│  ├── ConnectService — Pulse server, event pipeline  │
│  ├── PulseServer — NWListener TCP, Bonjour advert   │
│  ├── PulseClientConnection — per-client protocol    │
│  ├── PulsePacketDecoder — binary protocol parser    │
│  ├── CommandServer — _booster-cmd._tcp. snapshots  │
│  ├── NetworkConditionService — condition state hub │
│  ├── EnvironmentOverrideService — a11y toggles      │
│  ├── StatusBarService — status presets + config     │
│  ├── BuildStatsService — build history polling      │
│  ├── AXInspectorService — accessibility tree walk   │
│  ├── CameraService — camera routing automation      │
│  ├── CertificateService — CA generation/trust mgmt  │
│  ├── SimCtlService — xcrun simctl executor          │
│  └── XcodeDetector — filesystem path detection     │
├─────────────────────────────────────────────────────┤
│  iOS Framework Source                               │
│  └── BoosterSimConnect — PulseProxy activation,     │
│       command client + URLProtocol conditions       │
│       (loaded into Simulator app via Bundle.load)   │
└─────────────────────────────────────────────────────┘
```

## Component Responsibilities

### Entry Point

**`BoosterSimAppApp`** (`BoosterSimAppApp.swift`)
- `@main` SwiftUI App struct
- Declares `MenuBarExtra` (bolt icon, `.menu` style) and `Settings` scene
- Adapts AppDelegate via `@NSApplicationDelegateAdaptor`

### App Delegate

**`AppDelegate`** (`App/AppDelegate.swift`)
- `@MainActor final class`, conforms to `NSApplicationDelegate` + `ObservableObject`
- Owns core services: `tracker`, `settings`, `simCtlService`, `sideWindowController`, and feature services
- Wires services on `applicationDidFinishLaunching`
- Shows onboarding NSWindow on first launch (persisted via `@AppStorage("completedOnboarding")`)

### Services

**`SimulatorWindowTracker`** (`Services/SimulatorWindowTracker.swift`)
- Dual-mode detection:
  1. `WindowEnumerator` polling every 0.5s (fallback when no Accessibility permission)
  2. `WindowObserver` (AXObserver) per-PID for real-time move/resize/minimize events
- `NSWorkspace` notifications for Simulator launch/quit events
- Publishes `simulators: [SimulatorWindow]` and `activeSimulator: SimulatorWindow?`

**`PermissionManager`** (`Services/PermissionManager.swift`)
- Checks and requests macOS permissions: Accessibility, Screen Recording, DerivedData
- Polls for Screen Recording/Accessibility grant after user opens System Settings
- Manages DerivedData via security-scoped bookmarks (`URL.bookmarkData(.withSecurityScope)`)

**`WindowEnumerator`** (`Services/WindowEnumerator.swift`)
- Calls `CGWindowListCopyWindowInfo` to enumerate on-screen windows
- Filters by `kCGWindowOwnerName == "Simulator"` and layer 0 (normal windows)
- Converts Quartz Y coordinates to AppKit space (primary screen height flip)

**`WindowObserver`** (`Services/WindowObserver.swift`)
- Wraps `AXObserver` C API per PID
- Observes: moved, resized, windowCreated, miniaturized, deminiaturized, UIElementDestroyed
- Bridges C callback to Swift closure; manages `UnsafeMutableRawPointer` retain/release

**`XcodeDetector`** (`Services/XcodeDetector.swift`)
- Pure filesystem checks against known Xcode paths (no process execution)
- Returns `.app` path or nil; derives Developer directory path

**`EnvironmentOverrideService`** (`Services/EnvironmentOverrideService.swift`)
- Instant accessibility toggles via `xcrun simctl spawn`
- Controls: appearance (dark/light), bold text, reduce motion, increase contrast, smart invert, reduce transparency, on/off labels, button shapes, differentiate without color, grayscale
- No app relaunch required; toggles apply immediately

**`StatusBarService`** (`Services/StatusBarService.swift`)
- 4 presets: Screenshot Ready, Low Battery, No Signal, Normal
- Custom config: time, battery percentage, signal bars via `xcrun simctl ui`

**`BuildStatsService`** (`Services/BuildStatsService.swift`)
- Polls Xcode DerivedData build timing logs every 5s
- Stores last 30 build records with duration, timestamp, device
- Powers Canvas bar chart in side panel

**`AXInspectorService`** (`Services/AXInspectorService.swift`)
- Lazy walks accessibility tree from app under test
- Element selection, frame detection, properties inspection
- Highlights selected element via `AXHighlightPanel` overlay

**`CameraService`** (`Services/CameraService.swift`)
- Toggles Mac camera input via AX menu automation
- Targets Simulator menu: I/O → Camera → FaceTime HD Camera

**`CertificateModels.swift`** (`Services/CertificateModels.swift`)
- `CertificateMetadata` — CA common name, expiry, SHA-256 fingerprint
- `CertificateStatus` — tracks generated, installed, unknown, not-generated states
- `CertificateOperation` — guards generate/install/rotate/reset transitions
- `CertificateError` — user-facing error messages

**`CertificateService`** (`Services/CertificateService.swift`)
- Generates a local CA, installs it into the active Simulator keychain, and supports rotate/reset flows
- Persists install state so the UI can distinguish generated, installed, and unknown trust states
- Delegates certificate file creation to `CertificateStore` and shell execution to `SimCtlService`

**`CertificateStore`** (`Services/CertificateStore.swift`)
- Runs `/usr/bin/openssl` to create the CA key and certificate
- Stores generated files under Application Support/BoosterSimApp/Certificates with restrictive permissions (0o600)
- Reads certificate metadata and redacts local paths in user-facing error messages
- Single source of truth for CA file persistence

**`ConnectService`** (`Services/ConnectService.swift`)
- `@MainActor ObservableObject` — hosts Pulse TCP server to receive network events from Simulator apps
- Owns `PulseServer` instance; subscribes to its `eventPublisher` via Combine
- Converts `PulseDecodedEvent` to `NetworkEvent` (maps taskCompleted; skips taskCreated)
- Publishes `connectionState: ConnectionState` (.disconnected / .searching / .connected) and `networkEvents: [NetworkEvent]`
- Caps stored events at 500; transitions from .searching to .connected on first decoded event
- Wired through: AppDelegate → SideWindowController → SideWindowView → NetworkTabView

**`PulseServer`** (`Services/PulseServer.swift`)
- `@MainActor final class` — NWListener TCP server advertising `_pulse._tcp.` via Bonjour
- Accepts inbound connections; wraps each in `PulseClientConnection`
- Publishes decoded events via `PassthroughSubject<PulseDecodedEvent, Never>`
- Manages connection lifecycle (add on connect, remove on disconnect)

**`PulseClientConnection`** (`Services/PulseClientConnection.swift`)
- `@MainActor final class` — per-client NWConnection handler with receive loop
- State machine: connecting → waitingHello → active → disconnected
- Accumulates data in buffer (10 MB cap); parses packets via `PulsePacketDecoder`
- Handles handshake (clientHello → serverHello), ping/pong, network task events
- Callbacks: `onEvent`, `onDisconnect`, `onStateChange`

**`PulsePacketDecoder`** (`Services/PulsePacketDecoder.swift`)
- Pure static enum — binary protocol parser for Pulse wire format
- 5-byte header: `[code: UInt8][contentSize: UInt32 BE]`
- Zlib compress/decompress for all payloads
- Codable structs: `PulseNetworkEvent`, `PulseRequest`, `PulseResponse`, `PulseMetrics`, etc.
- Encodes outgoing packets (serverHello, pong)

**`CommandServer`** (`Services/CommandServer.swift`)
- `@MainActor final class` — NWListener TCP server advertising `_booster-cmd._tcp.` via Bonjour (mirrors `PulseServer`'s shape on a second channel)
- Loopback-only bind (`requiredLocalEndpoint` = 127.0.0.1): Simulator apps share the host stack and reach the Mac's loopback; nothing else on the LAN can connect
- Broadcasts full-state `BoosterCommand` JSON snapshots to every connected client — frames are length-prefixed (4-byte big-endian UInt32 + body, 10 MB cap)
- Reconcile-on-connect: `onClientConnect` fires so `NetworkConditionService` can push the current snapshot to a newly connected (or relaunched) app
- Never accepts client frames; the receive loop exists only to detect malformed input and drop that connection. `deinit` cancels listener and connections (NWListener must be cancelled)

**`NetworkConditionService`** (`Services/NetworkConditionService.swift`)
- `@MainActor ObservableObject` — single writer for all condition state: airplane flag, throttle profile selection, block rules
- `NetworkConditionState` machine (idle → applying → applied, error recovery) around every mutation
- Builds total snapshots (`snapshot()`) so airplane + throttle + rules always travel together — never torn
- Owns the `CommandServer`; every mutation persists to UserDefaults and broadcasts a fresh `BoosterCommand`

**`SimCtlService`** (`Services/SimCtlService.swift`)
- Centralized executor for `xcrun simctl` commands
- Parses boot arguments, environment overrides, status bar config
- Error handling with logged diagnostics

### Windows

**`AXHighlightPanel`** (`Windows/AXHighlightPanel.swift`)
- Borderless floating NSPanel overlay for accessibility element highlighting
- Draws orange border around selected element frame
- Stays on top of all windows; auto-hides after 2.5s

**`SideWindowPanel`** (`Windows/SideWindowPanel.swift`)
- `NSPanel` subclass, level `.floating`, `hidesOnDeactivate = false`
- `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]`
- `isReleasedWhenClosed = false` — lifecycle managed by SideWindowController
- Panel hides when Simulator loses focus (active app changes); re-shows on Simulator re-focus

**`SideWindowController`** (`Windows/SideWindowController.swift`)
- `@MainActor final class ObservableObject`
- Subscribes to `tracker.$activeSimulator` via Combine sink
- Reconciles certificate trust state when the active Simulator changes
- Delegates position math to `PositionCalculator`
- Uses `SpringAnimator` for smooth position tracking (CADisplayLink-driven physics)
- Detects panel side-switches; snaps instantly on switch, then springs to rest
- Respects `reducedMotion` — disables spring, uses rigid 1:1 tracking
- Animates collapse/expand with `NSAnimationContext`
- Reads SwiftUI content intrinsic height; passes to PositionCalculator for content-driven sizing
- Animates content-driven resizes via `onGeometryChange` callback (0.2s ease-in-out)
- Intercepts Cmd+W keyboard shortcut when panel is key window

**`PositionCalculator`** (`Windows/PositionCalculator.swift`)
- Pure enum with static methods — no state, easily testable
- Computes panel frame for left, right, bottom, dynamic modes
- Dynamic mode: prefers right side; falls back to left if insufficient space
- Uses NSScreen intersection area to find best-containing screen
- Panel height driven by SwiftUI content intrinsic size (min floor: 400pt)
- Vertically centers panel on simulator for left/right/dynamic positions

### Models

**`SimulatorWindow`** (`Models/SimulatorWindow.swift`)
- Value type (`struct`): id (`CGWindowID`), pid, deviceName, frame, isOnScreen, isMinimized
- `deviceName` is nil without Screen Recording permission; `displayName` provides fallback

**`BuildRecord`** (`Models/BuildRecord.swift`)
- Build history record: timestamp, duration, device name
- Decoded from Xcode `IDEActivityLog` JSON logs

**`AXNode`** (`Models/AXNode.swift`)
- Accessibility tree node: role, description, frame, attributes
- Hashable for list rendering; supports equality comparison

**`AppSettings`** (`Models/AppSettings.swift`)
- `ObservableObject` backed entirely by `@AppStorage`
- Keys: `sideWindowPosition`, `showSideWindow`, `launchAtLogin`, `xcodePath`
- `setLaunchAtLogin(_:)` syncs with `SMAppService.mainApp`

**`NetworkEvent`** (`Views/SideWindow/network/NetworkEventModel.swift`)
- Captured network request/response: method, URL, path, host, statusCode, headers, body, timing, error
- `HTTPMethod` enum (GET/POST/PUT/DELETE/PATCH/HEAD/OPTIONS) with tint color for badges
- `TrafficFilter` struct for method set + status range + search text matching
- `StatusRange` enum (All/2xx/3xx/4xx/5xx) with `contains(_:)` predicate

**`BoosterCommand`** (`Models/BoosterCommand.swift`)
- Full-state condition snapshot, schema `version` 1: `airplane`, `throttle: ThrottleSpec?`, `blockRules: [BlockRule]` — idempotent; clients ignore unknown versions whole (no partial application)
- `ThrottleSpec` — `latencyMs` + `downloadKbps` (+ `uploadKbps` reserved; approximated by the latency phase in v1)
- `CommandFrame` — length-prefix codec (encode/decodeOne); decode copies to a re-based `[UInt8]` before offset math (Data-slice index trap avoidance)
- `ConditionVerdict` + pure `evaluate(request:snapshot:)` — ordered verdict: guard marker → airplane → rules → throttle → pass-through
- `BoosterInternalGuard` — `X-Booster-Internal` marker key for tool-internal requests (anti-recursion)

**`BlockRule`** (`Models/BlockRule.swift`)
- Domain/path block rule: exact host or `*.suffix` wildcard (dot-boundary), optional `pathPrefix`, `isEnabled`
- Pure matcher using string operations only (no regex — ReDoS impossible); case-insensitive host, nil-host never matches, fields trimmed, empty domains never match

**`NetworkConditionProfile`** (`Models/NetworkConditionProfile.swift`)
- Throttle presets: off / EDGE (800 ms · 200 Kbps) / 3G (400 ms · 750 Kbps) / LTE (100 ms · 10000 Kbps) / Wi-Fi (20 ms · 25000 Kbps) with display names and picker captions
- `ThrottleSchedule` — pure, deterministic pacing math (see Network Manipulation)
- `ConnectionState` enum (.disconnected / .searching / .connected(deviceName))

### Views

**`MenuBarView`** — Show/hide toggle (Cmd+B), simulator list, Settings link, Quit

**`SideWindowView`** — Root: collapsed strip or expanded panel with tab-based layout (4 tabs: Capture, Design, Actions, Network)

**`SideTab`** — Enum: `capture`, `design`, `actions`, `network` with icon and label

**`TabBarView`** — Icon-only horizontal tab bar (36pt height)
- Selected indicator: 2pt amber underline
- Icons: camera, paintbrush, bolt, network (filled when selected, outlined when inactive)
- Right-aligned collapse button: chevron.left
- Background: `.bar` material with bottom divider
- Tab spacing: 12pt horizontal padding per tab
- Accessibility: tooltip, accessibilityLabel, isSelected trait

**Tab Content Views** (`tabs/` subdirectory)
- `CaptureTabView` — Screenshot, recording, GIF (placeholders)
- `DesignTabView` — Grid, safe area, ruler, color picker (placeholders)
- `ActionsTabView` — Environment overrides + quick actions container
- `NetworkTabView` — Live traffic viewer + network conditions + block rules + certificates; receives `ConnectService` as `@ObservedObject`; shows ConnectStatusBanner, ConnectSetupView, TrafficFilterBar, TrafficList, NetworkConditionsSectionView, BlockRulesView, CertificateSectionView; opens TrafficDetailView as sheet

**Side Panel Components**
- `ConnectStatusBanner` — Slim banner showing connection state (dot + label + setup/searching indicator); pulse animation on .searching
- `ConnectSetupView` — 3-step setup instructions for loading BoosterSimConnect into Simulator app; copy-to-clipboard code snippet
- `TrafficFilterBar` — Horizontal filter pills (method, status range) + collapsible search field; uses TrafficFilter binding
- `TrafficList` — Scrollable LazyVStack of TrafficRowView; auto-scrolls to latest; empty state placeholder
- `TrafficRowView` — Single request row: method badge, truncated path, status code, duration; amber highlight on selection
- `TrafficDetailView` — Sheet with tabbed sections (Summary, Headers, Body, Metrics); footer with Copy as cURL button
- `CurlExporter` — Pure enum: converts NetworkEvent to cURL command string; redacts sensitive headers
- `NetworkConditionsSectionView` — Airplane toggle, throttle profile pills (Off/EDGE/3G/LTE/Wi-Fi), effective-condition caption, state-machine status row, URLSession-scope disclosure
- `BlockRulesView` — Block-rule editor: add/toggle/delete rows, path-prefix capsule badges, 50-rule cap with caption, URLSession-scope disclosure
- `DeviceHeaderView` — Active device info (name, OS, battery, signal)
- `CollapsedStripView` — 28pt collapsed state with chevron + 2pt amber stripe
- `SideWindowFooter` — Version/status footer
- `StatusBarSectionView` — Status bar preset UI (4 presets + custom)
- `EnvironmentOverridesView` — A11y toggles (appearance, contrast, motion, bold text, smart invert, reduce transparency, grayscale, on/off labels, button shapes, differentiate, grayscale)
- `CertificateSectionView` — CA generation, install/rotate/reset, trust-state messaging
- `BuildStatsSectionView` / `BuildChartView` — Build history + Canvas bar chart
- `AXTreeView` — Accessibility tree browser with lazy loading + element highlight
- `CameraView` — Mac camera input toggle

**Shared Components**
- `FeatureSectionView` — Collapsible section container
- `FeatureRowView` — Individual feature row with toggle
- `AccentButton`, `StatusBadge`, `CollapsibleSection` — Reusable atoms

**Preferences & Onboarding**
- `PreferencesView` — Tab container for General and About
- `OnboardingContainerView` — 4-step flow: welcome, Accessibility, Screen Recording, done

### Utilities

**`DesignTokens`** (`Utilities/DesignTokens.swift`)
- Enums: `Spacing`, `CornerRadius`, `SideWindowMetrics`, `OnboardingMetrics`, `PreferencesMetrics`
- Single source of truth for all layout constants

**`SpringAnimator`** (`Utilities/SpringAnimator.swift`)
- `@MainActor final class` — CADisplayLink-driven spring physics
- Damped harmonic motion: stiffness=280, damping=22, rest threshold=0.5pt
- Smoothly animates panel position toward target frame
- Auto-stops at rest (displacement and velocity both < threshold)
- `snapTo()` for instant repositioning (used on panel side-switches)

**`AppLogger`** (`Utilities/AppLogger.swift`)
- Enum with static `Logger` instances per concern (windowTracking, permissions, settings, certificates, network)
- Subsystem: `com.nextlabs.BoosterSimApp`
- Replaces raw `os.Logger` initialization across services

## Data Flow

```
NSWorkspace notification (Simulator launch/quit)
CGWindowListCopyWindowInfo poll (0.5s)              ─┐
AXObserver callback (move/resize/minimize/quit)     ─┤→ SimulatorWindowTracker
                                                      │   @Published activeSimulator
                                                      ↓
                                               SideWindowController
                                               .attach(to: tracker) [Combine sink]
                                                      │
                                          ┌───────────┴───────────┐
                                    attachToSimulator()        detach()
                                          │                        │
                                   updatePosition()           panel.orderOut()
                                          ↓                   springAnimator.stop()
                         ┌────────────────────────┐
                         │ Check reducedMotion    │
                         └────────────────────────┘
                    NO  /          |          \  YES
                  Spring       Collapse    Rigid 1:1
                    │          NSAnimation     │
                    ↓                          ↓
            Detect side-switch?        panel.setFrame()
                 /          \
              YES            NO
               │              │
          snap() then    setTarget()
          spring()       (CADisplayLink)
               │              │
               └──────┬───────┘
                      ↓
            SpringAnimator.onFrameUpdate
                      ↓
            panel.setFrame(animated frame)
```

### Network Traffic Data Flow

```
Simulator app loads BoosterSimConnect.framework (Contents/Resources/)
        ↓
BoosterSimConnect activates PulseProxy (URLSession swizzle) + RemoteLogger
        ↓
RemoteLogger connects to PulseServer (NWListener, _pulse._tcp. Bonjour)
        ↓
PulseServer accepts connection → PulseClientConnection
        ↓
PulseClientConnection: receive loop → buffer → dispatchPacket()
        ↓
PulsePacketDecoder: parseHeader → decompress → decode JSON
        ↓
PulseClientConnection.onEvent → PulseServer.eventSubject
        ↓
ConnectService: convertToNetworkEvent() → @Published networkEvents
        ↓
NetworkTabView (TrafficFilterBar + TrafficList)
        ↓
TrafficDetailView (sheet) → CurlExporter (copy)
```

### Network Manipulation Command Flow

```
NetworkConditionService (Mac, single writer: airplane + profile + rules)
        ↓  total BoosterCommand snapshot (JSON, length-prefixed frame)
CommandServer (NWListener, "_booster-cmd._tcp.", loopback bind)
        ↓  broadcast to all clients; reconcile on every connect
BoosterCommandClient (framework: NWBrowser → NWConnection, buffered decode)
        ↓  version-gated apply
NetworkConditionController (framework: NSLock-guarded snapshot store)
        ↓  evaluateCondition(request:snapshot:) per request
BoosterNetworkProtocol (framework: URLProtocol verdict enforcement)
```

## Network Manipulation

Phase 5 ships three condition tools — **Airplane Mode**, **throttle profiles**, and **block rules** — pushed from the Network tab into Simulator apps over a second Bonjour channel (`_booster-cmd._tcp.`), independent of the `_pulse._tcp.` telemetry stream. Both channels stay connected exactly when the app under test is "offline": airplane never touches the Mac's connectivity or BoosterSimApp's own sessions (proven by the plan-01 live-Simulator smoke).

**Scope — stated honestly.** Conditions apply to **URLSession HTTP(S) requests of DEBUG apps embedding BoosterSimConnect, on sessions created after `BoosterSimConnect.activate()`, only**:
- WebSocket, WKWebView, and Network.framework traffic are unaffected
- URLSession sessions created before framework load are unaffected
- `NWPathMonitor`/reachability still reports satisfied — airplane is enforced per request (`NSURLErrorNotConnectedToInternet` on the app's requests), not at the interface level, and the Mac browses normally while it is on

**Enforcement chain.** `BoosterSimConnect.activate()` calls `BoosterNetworkProtocol.enableAutomaticRegistration()`, which exchanges `URLSession.init(configuration:delegate:delegateQueue:)` and **chains with Pulse's exchange** (the exchanged body calls the renamed selector), so both protocols prepend to new sessions. `canInit(with:)` returns true only for requests a condition would actually change (zero overhead while all conditions are off); `startLoading()` re-evaluates against a lock-copied snapshot. Verdict order is contract:

1. Guard marker → pass-through (anti-recursion)
2. Airplane → fail `NSURLErrorNotConnectedToInternet` (-1009)
3. First enabled matching block rule → fail `NSURLErrorCannotConnectToHost` (-1004)
4. Throttle spec set → paced delivery
5. Otherwise pass-through via an inner ephemeral session

**Anti-recursion guard.** Tool-issued inner requests carry the `X-Booster-Internal` URLProtocol property *and* the literal header; the inner session configuration has no protocols of its own (stripped `protocolClasses`). The guard check is first in the verdict order — without it the protocol would intercept its own forwarding requests forever.

**Throttle pacing (as shipped).** `ThrottleSchedule` (Mac, pure + unit-tested) and its framework mirror `ThrottlePacing.plan` compute `chunkInterval = chunkBytes × 8 / downloadKbps` **seconds** with `chunkBytes = 1500`: first response callback after `latencyMs/1000` s, body delivered in 1500-byte chunks at that interval, completion at `latencyMs + totalBytes × 8 / downloadKbps` s. **Known fidelity gap:** the formula omits the ÷1000 kilo factor, so durations far exceed physical network timing — e.g. 3G paces 1500 B at 16 s/chunk (a 15 KB body takes ~160 s instead of ~0.16 s). The formula is plan-pinned; values are declared approximations, and rescaling is a known one-line follow-up. Invalid specs (kbps ≤ 0, negative bytes/latency) return nil — enforcement degrades to unpaced delivery rather than trusting wire data. `uploadKbps` is nil in v1; upload cost is approximated by the latency phase.

**Persistence (UserDefaults; user-facing keys — renaming strands stored state).** `networkConditionAirplane` (Bool), `networkBlockRules` (JSON-encoded `[BlockRule]`), `networkConditionProfile` (raw-value String). All read back on service init and re-applied via the reconcile push when an app (re)connects.

**Schema sync.** The framework cannot import the Mac app target, so `BoosterSimConnect/NetworkConditionController.swift` mirrors `BoosterCommand`/`ThrottleSpec`/`BlockRule` and the verdict function (`evaluateCondition`) byte-for-byte in semantics; Mac-side `CommandPayloadTests` guards the shared wire contract. Every semantic change must mirror identically on both sides (cross-reference comments mark the pairs).

**Concurrency.** The framework-side classes are deliberately NOT `@MainActor` (URLProtocol callbacks arrive on URLSession session queues): `NetworkConditionController` guards its snapshot with an `NSLock`; `BoosterCommandClient` and `ThrottlePacing` confine all state to private serial queues (`@unchecked Sendable`, Pulse precedent).

## Concurrency Model

- All UI and service code runs on `@MainActor` (AppDelegate, SideWindowController are explicit)
- Combine sinks and Timer callbacks run on `.main` queue
- AXObserver callbacks fire on CFRunLoopGetMain (main thread by design)
- Swift 6 strict concurrency enforced at compile time
- No async/await — Combine `@Published` + Timer for all async patterns

## Key Design Decisions

| Decision | Rationale |
|---|---|
| SwiftUI `@main` + `@NSApplicationDelegateAdaptor` | Native SwiftUI lifecycle with full AppKit access |
| `MenuBarExtra` (.menu style) | Native macOS 13+ menu bar integration, no custom popover |
| `Settings` scene | Automatic Cmd+, binding, native Preferences window chrome |
| NSPanel over NSWindow | Floating utility window behavior, hides when Simulator loses focus |
| Dual-mode tracking (poll + AXObserver) | Graceful degradation without Accessibility permission |
| `xcrun simctl spawn` for env overrides | Instant state changes without app relaunch |
| NWListener + Bonjour for Connect | macOS hosts TCP server; Simulator apps connect to it — zero-config |
| Second Bonjour channel (`_booster-cmd._tcp.`, loopback-bound) for condition snapshots | Full-state idempotent snapshots self-heal on reconnect; loopback bind keeps the LAN out while Simulator apps still reach the host |
| Chained URLSession init exchange (Pulse + Booster) | Both protocol prepends compose; guard marker prevents self-interception |
| BoosterSimConnect as loadable framework | Loaded into Simulator app via `Bundle.load()` in DEBUG builds only |
| Apple frameworks only; Pulse/PulseProxy SPM exception via BoosterSimConnect | Sole dependency exception (user-resolved 2026-08-29); powers Connect network inspection |
| Non-sandboxed | Required for Accessibility API, CGWindowList enumeration, and Simulator control via simctl |
