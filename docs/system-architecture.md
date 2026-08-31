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
│  ├── AppActionService — app-action facade (Ph. 3)   │
│  ├── DerivedDataAppScanner — DerivedData .app scan  │
│  ├── UserDefaultsEditorService — defaults editor    │
│  ├── DeepLinkService — openurl deep links on seam   │
│  └── XcodeDetector — filesystem path detection     │
├─────────────────────────────────────────────────────┤
│  Capture Services (Phase 2)                         │
│  ├── CaptureService — sync Combine facade           │
│  ├── ScreenshotService — SCScreenshotManager        │
│  ├── RecordingService — SCStream + SCRecordingOutput│
│  ├── CaptureExporter — GIF/MP4/MOV export           │
│  ├── TouchIndicatorController — ShowSingleTouches   │
│  └── CaptureCompositor — ASC-preset geometry (pure) │
├─────────────────────────────────────────────────────┤
│  Design Overlay (Phase 4)                           │
│  ├── DesignOverlayService — tool state + presets    │
│  ├── SafeAreaCatalog — device inset constants       │
│  ├── OverlayGeometry — pure coordinate mapper       │
│  ├── PixelSamplerService — cached-capture sampling  │
│  ├── DesignOverlayPanel — click-through NSPanel     │
│  └── DesignOverlayController — tracker/input sync   │
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
- Centralized executor for `xcrun simctl` commands — StatusBarService, EnvironmentOverrideService, CertificateService, DeepLinkService, and AppActionService all ride it
- Seam-hardened (Phase 3): stdout and stderr drain concurrently with process exit (outputs past the 64 KB pipe buffer — `listapps` is already ~33 KB — would deadlock the child against `waitUntilExit`), optional `stdin: Data?` (serves `push <udid> -`), and a machine-wide serial invocation queue (one simctl pipeline at a time, never interleaved)
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

**`DesignOverlayPanel`** (`Windows/DesignOverlayPanel.swift`)
- Persistent borderless `.nonactivatingPanel` exactly covering the tracked Simulator frame; click-through by default (`ignoresMouseEvents = true`)
- `hidesOnDeactivate = false` + `[.canJoinAllSpaces, .fullScreenAuxiliary]` — overlays survive BoosterSimApp focus loss (roadmap criterion 4)
- Never becomes key: shown via `orderFront` only, so arming a tool never steals focus from the Simulator
- `install(_:at: OverlayLayer)` locks D-04 z-order as subview order: comparison < interactive < safeArea < grid (bottom → top) — deterministic regardless of install/toggle sequence
- `setCaptureMode(_:)` flips `ignoresMouseEvents`/`acceptsMouseMovedEvents` for interactive tools; the container's `hitTest` routes events to the interactive band only

**`DesignOverlayController`** (`Windows/DesignOverlayController.swift` + `+InputMode.swift`)
- `@MainActor final class ObservableObject`, Combine-only (zero coroutine keywords)
- Sink 1: `tracker.$activeSimulator` → `panel.setFrame(sim.frame)` + geometry push + visibility refresh; nil Simulator → `orderOut`
- Sink 2: `service.objectWillChange` (main-queue hop) → `refreshVisibility()` reading post-mutation state
- Resolves device geometry every tracker emission: calibrated content rect → orientation → logical size (`SafeAreaCatalog`) → scale (`OverlayGeometry`) → resolved insets pushed into the service
- Owns the capture-mode input machine (`OverlayInputMode`): arming installs Esc + hover monitors, every disarm path funnels through one `exitToClickThrough`, `deinit` removes all monitors

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

- Keys: `sideWindowPosition`, `showSideWindow`, `launchAtLogin`, `xcodePath`, plus eight capture keys — `captureDestination`, `captureASCFramePreset`, `captureBezelMode`, `captureBackground`, `captureExportFormat`, `captureGIFSize`, `captureGIFFps`, `captureShowTouchIndicators` — and the custom-folder path (`captureCustomFolderPath`)
- `ObservableObject` backed entirely by `@AppStorage`
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

- `CaptureTabView` — Capture tab: screenshot framing options (ASC preset, bezel, background, destination pills), `RecordingSectionView` (record/stop, touch-indicator toggle, staged-recording reveal), `ExportSectionView` (format/GIF pills, progress + cancel) — see § Capture Tools
- `DesignTabView` — Design tab mount: `DesignComparisonView` (grid controls + import row) with typed image drag-and-drop — see § Design Tools
- `ActionsTabView` — Catalog-driven searchable Actions tab: 9 sections in fixed `AppActionCatalog` order, section visibility routed through the pure filter (see § App Actions)

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
- `AppPickerBar` — Active-app candidate pills (DerivedData ∩ installed, running badge, explicit selection; alternatives in tooltip)
- `AppResetSectionView` — Reset App Data / Uninstall / Clear Keychain; the D-02 wipe sits only inside a blast-radius destructive dialog
- `PushNotificationSectionView` — Payload editor + template pills + live byte counter + D-01 guided-grant block (caption, Open Settings, Send-as-probe)
- `PrivacySectionView` — 12 TCC service grant/revoke rows scoped to the active app + device-wide reset behind a confirm
- `LocaleSectionView` / `LocationSectionView` — Relaunch-captioned locale presets and manual rows; validated coordinates + tz-syncing city presets with a state-driven Stop
- `ClipboardSectionView` — Exactly two manual pbsync buttons (Mac ↔ Simulator); direction-status captions only
- `UserDefaultsEditorView` — Searchable typed key list, inline edit/add/delete, type-only value capsules
- `ActionSearchBar` — Collapsible quick search over `AppActionCatalog`; clearing on collapse
- `DesignComparisonView` — Design tab root: import row (Open…/Paste/Clear + rejection caption + drop hint) and grid color/opacity controls; mounts the three design sections
- `DesignSafeAreaSection` — Safe-area toggle, resolved-device caption, four manual inset fields, Use Manual Insets, Reset to Device Values, x/y bezel-calibration fields
- `DesignPresetsSection` — Comparison preset save/load/delete (versioned `DesignOverlayPresets` store)
- `DesignToolsSection` — Ruler arm/disarm CTA with device-point distance readout + Color Picker arm/disarm with magnification stepper, live swatch, hex/RGB strings, and Copy

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

## Capture Tools

Phase 2 turns the Capture tab into the real tool: framed screenshots at exact App Store Connect sizes, direct-to-disk window recording at a 120 fps configured ceiling with Simulator-native touch indicators, and GIF/MP4/MOV export — all scoped to the tracked Simulator window through ScreenCaptureKit, all Apple frameworks (no new dependencies).

**Service split.** One sync facade over small single-concern services plus two AppKit surfaces:

| Unit | Role |
|---|---|
| `CaptureService` (`Services/CaptureService.swift`) | `@MainActor` sync Combine facade — TCC preflight, option mirrors synced to AppSettings on every change, published state, export routing, staged-file lifecycle. Async SCK internals hide behind it; views never see async |
| `ScreenshotService` (`Services/ScreenshotService.swift`) | One-shot `SCScreenshotManager.captureImage` through a `SCContentFilter(desktopIndependentWindow:)` matched to the tracked `CGWindowID`; Retina-scale output; DEBUG guard that the matched window belongs to Simulator |
| `RecordingService` (`Services/RecordingService.swift`) | `SCStream` + `SCRecordingOutput` (attached via `addRecordingOutput(_:)`) writing straight to disk — `minimumFrameInterval = CMTime(1, 120)`, `queueDepth` 5, audio off, HEVC in a staged `.mov`; `RecordingState` machine (idle → recording → finishing → exported/error); the file is final only after the recording-output finish callback passes an `AVAsset` duration > 0 gate — `stopCapture()` returning is never "file ready" |
| `CaptureCompositor` (`Utilities/CaptureCompositor.swift`) | Pure CoreGraphics geometry + rendering (no SCK, no AppKit) — ASC-preset canvas, uniform scale-to-fit/center (never stretches), bezel modes (none / simulatorNative / drawn), solid/gradient background, alpha-skipped opaque output (ASC rejects transparency) |
| `CaptureExporter` (`Services/CaptureExporter.swift`) | GIF via `AVAssetReader` → ImageIO (integer-centisecond delays, `kCGImagePropertyGIFLoopCount: 0`, one hoisted `CIContext`); MP4/MOV via `AVAssetExportSession` passthrough with a single `AVAssetExportPresetHighestQuality` re-encode fallback for MP4. DispatchQueue + Combine only — no async bridge in this unit |
| `TouchIndicatorController` (`Services/TouchIndicatorController.swift`) | In-process CFPreferences snapshot/set/restore of Simulator's `ShowSingleTouches` (see cross-app note below) |
| `CaptureThumbnailPanel` (`Windows/CaptureThumbnailPanel.swift`) | Borderless floating NSPanel (AXHighlightPanel pattern) — shows the saved capture near the Simulator window, auto-hides after 3 s, click reveals in Finder |
| `CaptureSaveRouter` (`Services/CaptureSaveRouter.swift`) | Destination routing — Desktop folder (`~/Desktop/BoosterSim Captures/`), clipboard, custom path, ask-every-time — plus the non-modal save panels for PNG data and exported files |

Supporting models: `ASCFramePreset` (seven exact ASC portrait pixel sizes across the 6.9″/6.5″ iPhone and 13″ iPad families, per Apple's screenshot specifications), `BezelMode` + `CaptureBackground`, `CaptureDestination`/`CaptureDestinationKind`, `RecordingState`, `ExportState`, `CaptureExportFormat` (defined in `Models/AppSettings.swift`), and `CaptureFilename` (sanitized, timestamp-unique names). Eight `@AppStorage` capture keys plus the custom-folder path persist every option across relaunch.

**Data flow — Capture tab to destination routing.**

```
CaptureTabView (framing pills) / RecordingSectionView / ExportSectionView
        ↓ sync facade calls
CaptureService (@MainActor facade, Combine @Published state)
        ├─ takeScreenshot() → ScreenshotService.capture (SCK one-shot, window filter)
        │        ↓ CGImage
        │   CaptureCompositor.render (pure CG: preset canvas + bezel + background → opaque PNG)
        │        ↓
        │   CaptureSaveRouter.route(pngData:) → Desktop / clipboard / custom / ask
        │        ↓                                            + CaptureThumbnailPanel (3 s auto-hide)
        ├─ startRecording() / stopRecording() → RecordingService (SCStream + SCRecordingOutput)
        │        ↓ finish callback + AVAsset duration gate
        │   stagedRecordingURL (temp boostersim-capture-*.mov, HEVC)
        │        ↓ exportRecording(as:)
        │   CaptureExporter.export → .gif (AVAssetReader → ImageIO) / .mp4 / .mov (AVAssetExportSession)
        │        ↓ routed output file
        │   CaptureSaveRouter.route(fileAt:) → destination; staged .mov deleted only after the write
        └─ TouchIndicatorController.enable()/restore() bracket every recording exit path
```

**Screen Recording permission (required) and degraded behavior.** Every capture path preflights `CGPreflightScreenCaptureAccess()`. When denied, the Capture tab degrades instead of failing: capture attempts surface a permission error (never a crash), `requestPermission()` opens System Settings and polls for the grant, and — because a TCC grant applies only after relaunch — the facade publishes `needsRelaunch` to drive the quit-and-reopen prompt. `deviceName` also degrades without the grant (window titles are unreadable), so capture filenames fall back to preset-based naming. Simulator-window tracking itself keeps working via the polling enumerator.

**Cross-app preference — scope and restore.** Touch indicators are Simulator's own rendering, not an overlay we composite: `TouchIndicatorController` writes exactly one scoped key — `ShowSingleTouches` on the `com.apple.iphonesimulator` domain — via in-process CFPreferences (no `defaults` subprocess). The prior value is snapshotted before the write and restored on every recording exit path (finish, stream error, stop), clearing the key with `kCFNull` when it was previously unset. Simulator reads the preference at launch, so enabling indicators surfaces a relaunch hint; a failed enable never blocks the recording (it degrades to recording without dots).

**Temp lifecycle (retention).** Staged recordings live in the temp folder under the `boostersim-capture-` prefix. The staged file is deleted only after its destination write succeeds (routing failures and cancellations leave it for retry); partial export output is deleted on every exit path; and a launch sweep (`CaptureExporter.sweepStaleCaptures()`, wired in `applicationDidFinishLaunching`) removes `boostersim-capture-*` files older than 24 h. Captured content never outlives the user-requested output.

**Frame rate, stated honestly.** 120 is the configured ceiling (`minimumFrameInterval = CMTime(1, 120)`); delivered frames are bounded by the host display's refresh rate — the Recording section captions it "Up to 120 fps". True 120 delivery needs a ProMotion-class display.

## App Actions

Phase 3 turns the Actions tab into the real tool: **14 searchable actions across 9 sections** — app picker + reset/uninstall/keychain (D-02), deep links, push (D-01), privacy (12 TCC services), locale/timezone, location, clipboard, and a UserDefaults editor — all over one hardened `xcrun simctl` seam, all Apple frameworks (zero new packages; `Package.resolved` unchanged from Phase 5).

**Service split.** One `@MainActor` Combine facade over small single-concern units, mirroring the Capture split:

| Unit | Role |
|---|---|
| `AppActionService` (`Services/AppActionService.swift`) | The facade: `refreshApps` reconcile, `resetApp`/`uninstallApp`, `clearKeychain` (D-02 delegate), `setPrivacy`/`resetAllPrivacy`/`openDeviceSettings`, `sendPush`, locale/timezone/location/clipboard verbs. Every argv lives in pure `nonisolated static` builders (unit-tested without spawning a subprocess); multi-verb chains ride the `AppActionOperation` state machine, single-hop verbs publish dedicated captions |
| `DerivedDataAppScanner` (`Services/DerivedDataAppScanner.swift`) | Pure filesystem scan of `~/Library/Developer/Xcode/DerivedData/*/Build/Products/*-iphonesimulator/*.app` — Info.plist read (skipping corrupt/missing), symlink resolution before dedupe, newest-wins per bundle ID with losers retained as visible `alternativePaths` |
| `UserDefaultsEditorService` (`Services/UserDefaultsEditorService.swift`) | Typed defaults editor for the active app — on-disk plist read + validated `spawn defaults` writes (data path below) |
| `DeepLinkService` (`Services/DeepLinkService.swift`) | The pre-existing openurl service with history/favorites, migrated onto the seam in Phase 3 — the last out-of-seam `Process` spawn in phase-owned code is gone (pre-existing exception: `SimulatorWindowTracker` still spawns `simctl list devices` directly from Phase 1 — migration recorded as a follow-up); the async-exemption list is now `CaptureService` alone |
| Models | `AppActionModels.swift` (`AppActionOperation`, `ResetOutcome` incl. the honest `reinstallFailed` degrade, argv builders + listapps/launchctl parsers, `AppKeychainResetting` protocol), `PrivacyPermission` (12 verbatim TCC service strings — no notifications case, D-01), `PushPayload` (typed parse + 4096-byte gate), `DefaultsEntry` (`DefaultsEntryValue` typed plist kinds), `AppAction`/`AppActionCatalog` (pure searchable catalog) |

**Seam hardening — why each property exists.** `SimCtlService.run(_:stdin:)` (signature-compatible with Phase 1) gained three properties:
- **Concurrent pipe drains** — stdout and stderr drain concurrently with process exit (lock-guarded accumulators + DispatchGroup; the promise resolves only after exit AND both EOFs). Without this, output past the 64 KB pipe buffer deadlocks the child against `waitUntilExit` — `listapps` already emits ~33 KB on a near-stock device.
- **Optional `stdin: Data?`** — written to the child's standard input and closed after; serves `simctl push <udid> <bundle> -` without a temp file.
- **Machine-wide serialization** — one static serial queue; one simctl pipeline at a time, queued and never interleaved. An interrupted verb leaves the seam idle-recoverable; plist writes land as single `spawn defaults` verbs the OS keeps cfprefsd-coherent (never half-written).

**Active-app reconcile — no frontmost verb exists.** `simctl` cannot report the frontmost app, and a DerivedData scan alone lists apps that may not be installed on the booted device. The picker reconciles three sources — **DerivedData scan ∩ `listapps` installed ∩ `launchctl` running badge** — and requires explicit selection (`AppPickerBar`); a bundle ID built in several build trees resolves to exactly one candidate (the newest) with the older paths visible as alternatives.

**Effect-latency caption contract.** Relaunch-domain writes are never presented as instant; captions follow this (research-verified, UI-matched) table:

| Action | Effect timing | Scope | Relaunch? |
|---|---|---|---|
| Reset / uninstall | immediate | per-app | user relaunches (reinstall from DerivedData when a build exists; a failed reinstall degrades honestly) |
| Keychain clear (D-02) | immediate | **whole device** — wipes every app's keychains incl. the Phase 5 local CA | — |
| Privacy grant/revoke | immediate | per-service, scoped to the active app (`reset all` = device) | may terminate the running app (Apple help verbatim) |
| Push send / deep link | immediate | per-app / device | — |
| Appearance / Dynamic Type | immediate (existing Environment section) | device | no |
| Locale / timezone | **next app launch** | device — global defaults domain | **yes** → `launch --terminate-running-process` in the same chain |
| Location set/clear | immediate | device | no (Clear stays visible while a simulation is active) |
| Clipboard `pbsync` | immediate | host ↔ device | no |
| Defaults write/delete | immediate via cfprefsd; launch-time keys need relaunch | per-domain | only launch-time keys |

**UserDefaults editor data path.** Reads come from the on-disk plist — `<data container>/Library/Preferences/<bundle>.plist`, the container resolved via `get_app_container data` — because `defaults export` **silently does nothing in the simulator**. Writes/deletes build validated `spawn defaults` argv (allowlist `[A-Za-z0-9._-]` on domain AND key; typed error and NO argv on violation) and every write reloads the domain. Value privacy holds end to end: rows show the value KIND (type capsule), captions and `AppLogger.actions` lines carry domain + key names only — values never reach logs or captions. JSON-capsule entries are read-only in the UI (binary-plist capsules corrupt under text editing).

**Platform limits — stated honestly, not hidden (user decisions D-01/D-02, 03-CONTEXT.md):**
- **D-01 — notification permission is managed by iOS.** `simctl privacy` has no `notifications` service (research-proven against positive controls; TCC.db has no UserNotifications row), so no control anywhere claims to grant or revoke push authorization. The Push section ships a guided-grant block instead: the caption *"Notification permission is managed by iOS — it cannot be set from here."*, an Open Settings verb (`launch com.apple.Preferences`), the inline manual-grant steps, and the Send button doubling as the delivery probe. The Privacy section carries the matching pointer caption.
- **D-02 — keychain clear is device-wide only.** Per-app keychain clear does not exist on Simulator. Clear Keychain sits behind a red destructive dialog naming the full blast radius — *"Erases EVERY app's keychain … and removes the BoosterSimApp local CA. The CA is re-installed automatically afterward … No undo."* — and the wipe composes the existing `CertificateService` verbs (`resetKeychain → reconcileStatus → install` when a CA exists) so certificate trust is restored automatically with zero manual steps.

**Quick search.** `AppActionCatalog` — 14 actions, 9 sections, fixed mount order — owns BOTH the tab's section order and search visibility (`AppActionCatalog.filter(query:)`, the TrafficFilter discipline: one pure matching point, zero per-view `contains` chains). Empty query renders every section through the same table; a query narrows to matching sections in catalog order with a matched-actions disclosure; no match renders an honest empty state; collapsing `ActionSearchBar` clears the query so a hidden filter can never silently narrow the tab.

**Known logging gap (pre-existing, tracked).** `SimCtlService` prints `xcrun simctl <argv>` before every invocation (a Phase-1 diagnostic). Phase 3 verbs carry full openurl URLs and defaults VALUES in argv, so that echo brushes the never-log-values/URLs prohibitions at the seam. All Phase-3 `AppLogger.actions` lines are verb/size/outcome-only; redacting the seam echo is a tracked review item (03-02 deviation 6, 03-04 deviation 7).

## Design Tools

Phase 4 turns the Design tab from a dead scaffold into real overlay tooling: a dual 8pt/4pt grid, orientation-aware safe-area guides with manual override, a drag-measure ruler with device-point readout, a magnifier loupe with click-to-commit color picking, and artboard comparison import — all composited over the live Simulator window through **one persistent transparent panel**, all Apple frameworks (no new dependencies; `Package.resolved` unchanged).

The scaffold's fake core was cut over (04-01): `DesignComparisonService` (empty-bitmap `pickColor`, single-spacing grid state no window consumed) is **deleted**; its persistence shape and hex/RGB helpers carried into `DesignOverlayService`. Zero `DesignComparisonService` tokens remain in the repo.

**Architecture — one panel, ordered subviews (locked decision D-04).** All five tools ride a single `DesignOverlayPanel` exactly covering the tracked Simulator frame. Paint order is **subview order, never window order**: `install(_:at: OverlayLayer)` maps the four layer roles to deterministic indices via `addSubview(_:positioned:.below, relativeTo:)` (AppKit has no `insertSubview(at:)`), so toggling tools in any sequence can never put the artboard above the guides.

| Layer (bottom → top) | View | Role |
|---|---|---|
| `.comparison` | `ComparisonImageView` | Aspect-fit artboard with opacity/split — the see-through mechanism; guides always render above it |
| `.interactive` | `RulerOverlayView`, `MagnifierView` | Capture-mode input band — the only layer that receives mouse events |
| `.safeArea` | `SafeAreaOverlayView` | Xcode-guide-style translucent bands (fixed `systemBlue` fill 0.15 / stroke 0.6, hairline ÷ `backingScaleFactor`) |
| `.grid` | `GridOverlayView` | Dual grid, topmost: 8pt majors at full alpha (1.5/backing) over 4pt minors at half alpha (1.0/backing), drawn in device points, adaptive-blue default with tunable color/opacity |

**Service split.**

| Unit | Role |
|---|---|
| `DesignOverlayService` (`Services/DesignOverlayService.swift` + `+Presets.swift` + `+Import.swift`) | `@MainActor ObservableObject` — per-tool toggles (write-through `didSet` persistence), comparison image/mode/split, safe-area state, tool arming, picked color, magnification. Presets and import live in same-type extension files to hold the <200 LOC standard |
| `SafeAreaCatalog` (`Services/SafeAreaCatalog.swift`) | Pure constants — 34 name-keyed device rows + 15 logical-size fallback rows + `manualDefaults` (59/34). Name-keying first because sizes collide (`375×812` = both iPhone X-class 44 and mini-class 50); `landscape(from:)` derives the verified landscape shape (home-indicator rows → top 0, bottom 21, sides = portrait top; classic 20/0 rows → all-zero). Provenance is split honestly: 13/15/16-series rows verified, legacy and iPad rows ASSUMED (header comment) |
| `OverlayGeometry` (`Services/OverlayGeometry.swift`) | The single pure mapper — content rect (frame − 28pt title bar), orientation-from-aspect, window↔device-point round trip, `gridSpacings` (8×/4× scale), `imagePixel` (AppKit bottom-origin ↔ CGImage top-origin Y-flip × backing scale), `distance`. Scale is always a parameter, never a literal; no call site re-derives the flip |
| `PixelSamplerService` (`Services/PixelSamplerService.swift`) | Cached-capture sampling — see below |
| `DesignOverlayController` (`Windows/`) | Tracker/service sinks, geometry push, capture-mode input machine — see Windows section |

**Cached-capture sampling (magnifier + picker).** `PixelSamplerService` is the second sanctioned async site, copying the `CaptureService` shape exactly (sync public API → one private `Task` bridge → async `ScreenshotService.capture`). `arm()` preflights `CGPreflightScreenCaptureAccess()` and the tracker, then issues **one** ScreenCaptureKit capture of the tracked window (`desktopIndependentWindow` filter — never self-capture); every cursor read afterwards is a local `NSBitmapImageRep` pixel read (µs, no TCC traffic). An arming-generation token discards late capture results after disarm by construction; the cache is memory-only (cleared on every disarm — never written to disk, never logged as pixel data). `refreshIfFrameChanged` re-captures on resize/orientation change only; pure window translation never does (content pixels are translation-invariant — no per-move captures during Simulator drags).

**Capture-mode input.** Interactive tools temporarily flip the panel: `setCaptureMode(true)` clears `ignoresMouseEvents` and enables `acceptsMouseMovedEvents`. Because render layers sit above the interactive slot by design, the panel container's `hitTest` routes events to the first visible interactive-band view only — the grid stays visually on top without swallowing ruler/picker events. Hover tracking pairs an observe-only **global** `mouseMoved` monitor (cursor over the Simulator — never an event tap) with a **panel-local** monitor (global monitors never fire for own-app events); Esc-cancel rides a local `keyDown` monitor (keyCode 53) since the panel never becomes key. Monitor lifetime == armed lifetime: installed on arm, removed on every disarm path and in `deinit` — no ambient tracking survives. Exactly one capture-mode tool may be armed at a time (the service disarms the other on arming). Per-move loupe state is pushed directly to `MagnifierView`; `service.liveHex` publishes only at pick, so a cursor move never redraws the render tools.

**Permission degradation — honest captions, never crashes.** Denied Screen Recording or no tracked Simulator refuses the arm with the reason mirrored into the Design tab (`samplerError`); the panel auto-reverts to click-through without installing monitors. Imported images over 16384 px on either pixel edge are rejected before caching with a caption (decompression-bomb guard); pasteboard reads accept typed image payloads only. Window tracking itself keeps working via the polling enumerator.

**Persistence (UserDefaults; user-facing keys — renaming strands stored state).** `DesignOverlayPresets` (JSON `[DesignPreset]`), per-tool toggles `DesignOverlayShowGrid` / `DesignOverlayShowRuler` / `DesignOverlayShowSafeArea`, safe-area overrides `DesignOverlayUseManualInsets` + `DesignOverlayManual{Top,Bottom,Leading,Trailing}`, bezel calibration `DesignOverlayCalibration{X,Y}`, and `DesignOverlayMagnification` (default 8, range 2…16 via `OverlayMetrics`). The scaffold's `DesignComparisonPresets` payloads import **once** behind the `DesignOverlayLegacyImported` flag using a tolerant all-optional decode shape — re-running imports nothing, importing replaces rather than appends, and corrupted data degrades to an empty list.

**Safe-area resolution + bezel calibration.** The controller resolves insets on every tracker emission: device name → `SafeAreaCatalog` row → orientation transform, pushed into `resolvedInsets`/`resolvedDeviceName` (the service stays tracker-free). Manual fields win while `useManualInsets` is set; `resetInsetsToDevice()` restores auto-resolution. The content rect assumes bezels OFF (frame − 28pt title bar); persisted x/y calibration offsets — applied by the controller before all geometry math — are the escape hatch for bezel-on windows.

**Data flow — Design tab to overlay pixels.**

```
Design tab (SwiftUI: DesignComparisonView + SafeArea/Presets/Tools sections)
        ↓ toggles / arm-disarm / open-paste-drop import
DesignOverlayService (@MainActor state; write-through versioned persistence)
        ↓ objectWillChange → main-queue hop
DesignOverlayController ←── tracker.$activeSimulator (frame authority)
   ├─ refreshVisibility — tool views hidden/visible; orderFront iff anyToolOn ∧ Simulator tracked
   ├─ pushGeometry — calibrated contentRect → orientation → logicalSize → scale → resolvedInsets
   ├─ armed-flag sinks → OverlayInputMode (capture mode + Esc/hover monitors)
   └─ pixelSampler.$samplerError → service caption (honest degradation)
DesignOverlayPanel (click-through NSPanel; D-04 subview order)
   ├─ .comparison  ComparisonImageView      (artboard bottom — guides always above)
   ├─ .interactive RulerOverlayView / MagnifierView (the only event-receiving band)
   ├─ .safeArea    SafeAreaOverlayView      (systemBlue bands)
   └─ .grid        GridOverlayView          (dual 8/4, topmost)
PixelSamplerService (arm → single Task bridge → ScreenshotService SCK capture → memory cache)
   └─ sampleColor / sampleRegion ← OverlayGeometry.imagePixel (Y-flip × backing scale)
```

**Import funnel.** All three artboard entry points — `NSOpenPanel` open, typed pasteboard paste, `UTType.image` drag-and-drop on the Design tab — funnel through the single `accept(image:)` gate (dimension cap + single-slot replace + caption). Re-importing replaces; nothing accumulates. No network client exists anywhere in the design-overlay path (Figma API rejected for v1 — file/drag/paste only).

**Overlay chrome tokens.** `OverlayMetrics` (`Utilities/DesignTokens.swift`): marker radius 3, readout inset `Spacing.sm`, loupe diameter 96, magnification default 8 (range 2…16). Overlay content renders system blue — the amber accent stays reserved for side-panel active controls (D-03).

## Concurrency Model

- All UI and service code runs on `@MainActor` (AppDelegate, SideWindowController are explicit)
- Combine sinks and Timer callbacks run on `.main` queue
- AXObserver callbacks fire on CFRunLoopGetMain (main thread by design)
- No async/await in general code — Combine `@Published` + Timer for all async patterns. The sanctioned exception is the **ScreenCaptureKit bridge pattern** (sync public API → single private `Task {}` bridge → TCC preflight), instantiated by exactly two services: `CaptureService` (Phase 2) and `PixelSamplerService` (Phase 4); views and controllers stay synchronous

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
| Serialized, concurrently-drained simctl seam with optional stdin (Phase 3) | One simctl pipeline machine-wide (never interleaved); >64 KB outputs — `listapps` ≈33 KB — can never deadlock; push payloads stream over stdin with no temp file |
| Pulse/PulseProxy SPM exception to the Apple-only policy (user-resolved 2026-08-29) | Powers Connect network inspection. Declared on BOTH the app target (`project.pbxproj:199-202`) and `BoosterSimConnect` (`:271-274`) — the app target links them because its `fileSystemSynchronizedGroups` includes `BoosterSimConnect/`, so it compiles those sources. Only `BoosterSimConnect.swift` imports them, behind `#if DEBUG && targetEnvironment(simulator)`, so a macOS app build compiles the imports out while still linking the products |
| Non-sandboxed | Required for Accessibility API, CGWindowList enumeration, and Simulator control via simctl |
| One persistent click-through overlay NSPanel with locked subview-order layers (Phase 4, D-04) | Subview order makes guide-above-artboard z-order deterministic; per-tool windows would make it orderFront-call-order dependent |
| Cached-capture sampling — one ScreenCaptureKit capture per arming (Phase 4) | Per-move captures are ~10–30 ms async and hammer a TCC-gated API; cached local pixel reads are µs and need no permission traffic |
