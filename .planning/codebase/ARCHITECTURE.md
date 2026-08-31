# Architecture

**Analysis Date:** 2026-08-31

## System Overview

BoosterSimApp is a macOS menu-bar (LSUIElement) utility that attaches a floating tool panel and design overlays to the iOS Simulator window. It is a SwiftUI-App + AppKit-service hybrid: the `@main` SwiftUI struct owns only the menu-bar and Preferences scenes; an `AppDelegate` composition root constructs every service and panel; SwiftUI views render inside AppKit `NSPanel`s fed by `ObservableObject` services over Combine.

```text
┌────────────────────────────────────────────────────────────────────┐
│              SwiftUI Scenes — BoosterSimAppApp.swift               │
│    MenuBarExtra → MenuBarView    Settings scene → PreferencesView  │
│                    `BoosterSimApp/BoosterSimAppApp.swift`          │
└──────────────────────────────┬─────────────────────────────────────┘
                               │ @NSApplicationDelegateAdaptor
┌──────────────────────────────▼─────────────────────────────────────┐
│        AppDelegate — composition root (@MainActor)                 │
│        `BoosterSimApp/App/AppDelegate.swift`                       │
│   Constructs all services, panels, controllers; wires Combine;     │
│   owns the first-launch onboarding NSWindow                        │
└───────┬──────────────────────┬─────────────────────┬───────────────┘
        │                      │                     │
        ▼                      ▼                     ▼
┌───────────────────┐ ┌───────────────────┐ ┌─────────────────────────┐
│ Window Controllers│ │ Feature Services  │ │ Companion runtime       │
│ `Windows/`        │ │ `Services/`       │ │ BoosterSimConnect       │
│ SideWindow…       │ │ tracker, capture, │ │ framework (loads into   │
│ DesignOverlay…    │ │ design overlay,   │ │ Simulator app, DEBUG)   │
│ AXHighlight…      │ │ connect, actions  │ │ `BoosterSimConnect/`    │
└────────┬──────────┘ └─────────┬─────────┘ └─────────────────────────┘
         │ hosts SwiftUI        │ Combine @Published
         ▼                      ▼
┌────────────────────────────────────────────────────────────────────┐
│  SwiftUI Views — `Views/` (SideWindow tabs, Overlay tools,         │
│  MenuBar, Preferences, Onboarding, Shared atoms)                   │
└──────────────────────────────┬─────────────────────────────────────┘
                               ▼
┌────────────────────────────────────────────────────────────────────┐
│  Persistence & seams: UserDefaults/@AppStorage, `xcrun simctl`     │
│  via `Services/SimCtlService.swift`, ScreenCaptureKit, NWListener  │
└────────────────────────────────────────────────────────────────────┘
```

## Component Responsibilities

| Component | Responsibility | File |
|-----------|----------------|------|
| `BoosterSimAppApp` | `@main`; declares `MenuBarExtra` + `Settings` scenes; adapts `AppDelegate` | `BoosterSimApp/BoosterSimAppApp.swift` |
| `AppDelegate` | Composition root; owns every service/panel/controller; lifecycle wiring in `applicationDidFinishLaunching` | `BoosterSimApp/App/AppDelegate.swift` |
| `SimulatorWindowTracker` | Detects/tracks Simulator windows (CGWindowList poll + AXObserver); publishes `activeSimulator`, `isSimulatorFocused` | `BoosterSimApp/Services/SimulatorWindowTracker.swift` |
| `WindowEnumerator` | `CGWindowListCopyWindowInfo` scan filtered to Simulator, layer 0; Quartz→AppKit Y-flip | `BoosterSimApp/Services/WindowEnumerator.swift` |
| `WindowObserver` | Per-PID `AXObserver` C-callback bridge (move/resize/minimize/created/destroyed) | `BoosterSimApp/Services/WindowObserver.swift` |
| `PermissionManager` | Accessibility / Screen Recording / DerivedData permission checks, polling, security-scoped bookmarks | `BoosterSimApp/Services/PermissionManager.swift` |
| `SideWindowController` | Side panel lifecycle, Simulator attach/detach, position sync (spring/rigid), collapse, Cmd+W, SwiftUI hosting + environment injection | `BoosterSimApp/Windows/SideWindowController.swift` |
| `SideWindowPanel` / `SideWindowView` | Floating NSPanel (`.floating`, canJoinAllSpaces) / root SwiftUI tab view (Capture, Design, Actions, Network) | `BoosterSimApp/Windows/SideWindowPanel.swift`, `BoosterSimApp/Views/SideWindow/SideWindowView.swift` |
| `PositionCalculator` | Pure frame math: left/right/bottom/dynamic panel placement, screen containment | `BoosterSimApp/Windows/PositionCalculator.swift` |
| `SpringAnimator` | CADisplayLink damped-spring frame animation (stiffness 600, damping 45, rest 0.5pt) | `BoosterSimApp/Utilities/SpringAnimator.swift` |
| `DesignOverlayService` | Phase 4 tool state: grid/safe-area/ruler/picker toggles, comparison image, arming, picked color; write-through persistence | `BoosterSimApp/Services/DesignOverlayService.swift` (+`+Presets.swift`, `+Import.swift`) |
| `DesignOverlayController` | Overlay panel frame sync, geometry push, tool visibility, capture-mode input machine | `BoosterSimApp/Windows/DesignOverlayController.swift` (+`+InputMode.swift`) |
| `DesignOverlayPanel` | Persistent click-through `.nonactivatingPanel` covering the Simulator frame; locked `OverlayLayer` subview order | `BoosterSimApp/Windows/DesignOverlayPanel.swift` |
| `PixelSamplerService` | Cached-capture pixel sampling: one SCK capture per arming, memory-only CGImage cache, sync reads | `BoosterSimApp/Services/PixelSamplerService.swift` |
| `SafeAreaCatalog` / `OverlayGeometry` | Pure device-inset constants / pure window↔device-point coordinate mapper | `BoosterSimApp/Services/SafeAreaCatalog.swift`, `BoosterSimApp/Services/OverlayGeometry.swift` |
| Overlay tool views | Comparison image, grid, safe-area bands, ruler, magnifier (installed at `OverlayLayer` slots) | `BoosterSimApp/Views/Overlay/*.swift` |
| `CaptureService` | Sync Combine facade over screenshot + recording pipelines; option mirrors synced to `AppSettings` | `BoosterSimApp/Services/CaptureService.swift` |
| `ScreenshotService` / `RecordingService` | SCK one-shot window capture / `SCStream`+`SCRecordingOutput` direct-to-disk recording | `BoosterSimApp/Services/ScreenshotService.swift`, `BoosterSimApp/Services/RecordingService.swift` |
| `CaptureCompositor` / `CaptureExporter` / `CaptureSaveRouter` | Pure CG framing+render / GIF-MP4-MOV export / destination routing + save panels | `BoosterSimApp/Utilities/CaptureCompositor.swift`, `BoosterSimApp/Services/CaptureExporter.swift`, `BoosterSimApp/Services/CaptureSaveRouter.swift` |
| `TouchIndicatorController` | CFPreferences snapshot/set/restore of Simulator's `ShowSingleTouches` | `BoosterSimApp/Services/TouchIndicatorController.swift` |
| `SimCtlService` | The single `xcrun simctl` seam: serialized queue, concurrent pipe drains, optional stdin | `BoosterSimApp/Services/SimCtlService.swift` |
| `AppActionService` | Actions-tab facade: app discovery/reset/uninstall, keychain, privacy, push, locale, location, clipboard; pure argv builders | `BoosterSimApp/Services/AppActionService.swift` |
| `DerivedDataAppScanner` / `UserDefaultsEditorService` / `DeepLinkService` | DerivedData `.app` scan / typed defaults editor / openurl deep links | `BoosterSimApp/Services/DerivedDataAppScanner.swift`, `BoosterSimApp/Services/UserDefaultsEditorService.swift`, `BoosterSimApp/Services/DeepLinkService.swift` |
| `ConnectService` + `PulseServer`/`PulseClientConnection`/`PulsePacketDecoder` | Network telemetry: NWListener TCP (`_pulse._tcp.` Bonjour), per-client receive loop, binary decode → `@Published networkEvents` | `BoosterSimApp/Services/ConnectService.swift`, `BoosterSimApp/Services/PulseServer.swift`, `BoosterSimApp/Services/PulseClientConnection.swift`, `BoosterSimApp/Services/PulsePacketDecoder.swift` |
| `NetworkConditionService` + `CommandServer` | Single writer for airplane/throttle/block-rule state; broadcasts full `BoosterCommand` snapshots over loopback `_booster-cmd._tcp.` | `BoosterSimApp/Services/NetworkConditionService.swift`, `BoosterSimApp/Services/CommandServer.swift` |
| Other feature services | StatusBar presets, a11y overrides, build stats, AX tree, camera routing, CA certificates, env overrides | `BoosterSimApp/Services/StatusBarService.swift`, `EnvironmentOverrideService.swift`, `BuildStatsService.swift`, `AXInspectorService.swift`, `CameraService.swift`, `CertificateService.swift`, `CertificateStore.swift` |
| `BoosterSimConnect` framework | DEBUG-only iOS framework loaded into the Simulator app: PulseProxy swizzle, `URLProtocol` condition enforcement, command client | `BoosterSimConnect/BoosterSimConnect.swift`, `BoosterNetworkProtocol.swift`, `BoosterCommandClient.swift`, `NetworkConditionController.swift` |
| `AppSettings` | `@AppStorage`-backed settings singleton (window position, capture options, launch-at-login) | `BoosterSimApp/Models/AppSettings.swift` |
| `AppLogger` | Static `os.Logger` namespace, subsystem `com.nextlabs.BoosterSimApp` | `BoosterSimApp/Utilities/AppLogger.swift` |
| `DesignTokens` | Layout constants: `Spacing`, `CornerRadius`, `SideWindowMetrics`, `OnboardingMetrics`, `PreferencesMetrics`, `OverlayMetrics` | `BoosterSimApp/Utilities/DesignTokens.swift` |

## Pattern Overview

**Overall:** Service-oriented MVVM — `ObservableObject` services are the view models; `NSPanel` controllers in `Windows/` bind AppKit windows to those services; SwiftUI views are thin, state-less consumers via `@EnvironmentObject`. A small set of pure static enums (`PositionCalculator`, `OverlayGeometry`, `CaptureCompositor`, command builders) holds all testable math and argv construction.

**Key Characteristics:**
- One composition root (`AppDelegate`) constructs everything explicitly; no service locator, no DI framework — constructor injection all the way down (`SideWindowController.init` takes all 15 collaborators, `BoosterSimApp/Windows/SideWindowController.swift:59-75`).
- All state lives in `@MainActor final class … ObservableObject` services publishing `@Published` properties; views never own shared state (`@State` is local UI state only, e.g. `selectedTab` in `BoosterSimApp/Views/SideWindow/SideWindowView.swift`).
- Combine is the only general async mechanism; Combine `sink` + main-queue hops connect tracker → controllers → panels (`attach(to:)` in both controllers).
- Pure/static seams for everything unit-testable: argv builders (`nonisolated static func` in `AppActionService` extensions), geometry (`OverlayGeometry`), placement (`PositionCalculator`), rendering (`CaptureCompositor`), catalog filtering (`AppActionCatalog`).
- Graceful degradation is a first-class pattern: missing permissions or a missing Simulator disable features with honest captions rather than error paths (e.g. `samplerError` mirroring in `BoosterSimApp/Windows/DesignOverlayController.swift`).
- Explicit protocol seams for tests: `SimCtlRunning`, `AppKeychainResetting` (consumed by `AppActionService`), injectable closures like `PixelSamplerService.preflightPermission`.

## Layers

**Entry/Scenes:**
- Purpose: SwiftUI app lifecycle, menu bar icon, native Preferences window
- Location: `BoosterSimApp/BoosterSimAppApp.swift`, views in `BoosterSimApp/Views/MenuBar/`, `BoosterSimApp/Views/Preferences/`
- Depends on: `AppDelegate` only
- Used by: macOS

**Composition Root:**
- Purpose: Construct and wire all services, controllers, panels; app lifecycle (single-instance guard, onboarding, temp sweep, shutdown restore)
- Location: `BoosterSimApp/App/AppDelegate.swift`
- Depends on: every service and window controller
- Used by: SwiftUI scenes, onboarding

**Service Layer (state + domain):**
- Purpose: Feature state machines, simulator tracking, process seams, persistence
- Location: `BoosterSimApp/Services/` (36 files), value types in `BoosterSimApp/Models/` (17 files)
- Depends on: Combine, AppKit/CoreGraphics, `SimCtlService` for all simctl work
- Used by: controllers and views

**Window/Controller Layer (AppKit surfaces):**
- Purpose: NSPanel lifecycle, frame tracking, input-mode machines, SwiftUI hosting
- Location: `BoosterSimApp/Windows/` (`SideWindowController`, `DesignOverlayController`, `AXHighlightPanel`, `CaptureThumbnailPanel`, panels)
- Depends on: `SimulatorWindowTracker`, feature services, `SpringAnimator`, `PositionCalculator`
- Used by: `AppDelegate`

**View Layer (SwiftUI):**
- Purpose: All user-facing UI, organized by tab then section; shared atoms
- Location: `BoosterSimApp/Views/` — `SideWindow/` (root, `tabs/`, `actions/`, `capture/`, `network/`, design sections), `Overlay/`, `MenuBar/`, `Onboarding/`, `Preferences/`, `Shared/`
- Depends on: services via `@EnvironmentObject`, `DesignTokens` constants
- Used by: window controllers (hosted in `NSHostingView`)

**Companion Runtime (separate target):**
- Purpose: In-app network capture + condition enforcement inside Simulator apps
- Location: `BoosterSimConnect/` (Xcode framework target)
- Depends on: Pulse/PulseProxy SPM packages (the only external dependency, isolated to this target)
- Used by: developer apps loaded via `Bundle.load()` in DEBUG simulator builds; talks back to `PulseServer`/`CommandServer` over TCP/Bonjour

## Data Flow

### Primary Request Path — Simulator tracking → panel attachment

1. `NSWorkspace` Simulator launch/quit notifications, 0.5s `CGWindowList` poll, and per-PID `AXObserver` callbacks all feed `SimulatorWindowTracker` (`BoosterSimApp/Services/SimulatorWindowTracker.swift`)
2. Tracker publishes `@Published activeSimulator: SimulatorWindow?` and `isSimulatorFocused`
3. `SideWindowController.attach(to:)` sinks the tracker: attach → `updatePosition()` → show (focus-gated); detach → hide (`BoosterSimApp/Windows/SideWindowController.swift`)
4. `updatePosition()` computes the target frame via pure `PositionCalculator.panelFrame`, then routes by motion policy: reduced-motion → rigid `setFrame`; side-switch → `SpringAnimator.snapTo`; otherwise `setTarget` (display-link spring)
5. Same tracker emission drives `DesignOverlayController.attach` sink two: panel `setFrame(sim.frame)`, `pushGeometry` (calibrated content rect → orientation → `SafeAreaCatalog` logical size → `OverlayGeometry` scale → resolved insets), `refreshVisibility`

### Capture flow (Phase 2)

1. `CaptureTabView` pills/sections → sync facade calls on `CaptureService` (`BoosterSimApp/Services/CaptureService.swift`)
2. `takeScreenshot()` → TCC preflight + tracked-window resolution → `ScreenshotService.capture` (SCK `desktopIndependentWindow` filter) → `CaptureCompositor.render` (pure CG: ASC preset canvas + bezel + opaque background) → `CaptureSaveRouter.route` → `CaptureThumbnailPanel` 3s flash
3. `startRecording()`/`stopRecording()` → `RecordingService` (SCStream + `SCRecordingOutput`, staged `.mov`) with `TouchIndicatorController.enable()/restore()` bracketing every exit path
4. `exportRecording(as:)` → `CaptureExporter` (GIF via AVAssetReader→ImageIO; MP4/MOV via AVAssetExportSession) → `CaptureSaveRouter`; staged temp file deleted only after destination write succeeds; `CaptureExporter.sweepStaleCaptures()` runs at launch

### Design overlay flow (Phase 4)

1. Design tab (`BoosterSimApp/Views/SideWindow/tabs/DesignTabView.swift`) mutates `DesignOverlayService` (toggles, import via open/paste/drop → single `accept(image:)` gate, arm/disarm)
2. `service.objectWillChange` → main-queue hop → `DesignOverlayController.refreshVisibility()`; `$isRulerArmed`/`$isMagnifierArmed` sinks drive the `OverlayInputMode` capture-mode machine (Esc + hover monitors, `DesignOverlayController+InputMode.swift`)
3. Arming the magnifier/picker: `PixelSamplerService.arm()` → one `Task` bridge → `ScreenshotService.capture` → memory-only `NSBitmapImageRep` cache; every cursor read is a local pixel read through `OverlayGeometry.imagePixel` (Y-flip × backing scale)
4. Tool views render inside `DesignOverlayPanel` at locked `OverlayLayer` slots: `.comparison` → `.interactive` (only event-receiving band) → `.safeArea` → `.grid` (`BoosterSimApp/Windows/DesignOverlayPanel.swift:12-13`)

### Network telemetry flow (Phase 5)

1. Simulator app loads `BoosterSimConnect.framework` → `BoosterSimConnect.activate()` enables PulseProxy swizzle + `RemoteLogger` (`BoosterSimConnect/BoosterSimConnect.swift`)
2. RemoteLogger connects to `PulseServer` (NWListener, `_pulse._tcp.` Bonjour, `BoosterSimApp/Services/PulseServer.swift`) → per-client `PulseClientConnection` receive loop → `PulsePacketDecoder` (5-byte header + zlib + JSON)
3. `ConnectService` converts decoded events to `NetworkEvent` and publishes `networkEvents` (500-event cap) → `NetworkTabView` filter/list/detail + `CurlExporter`

### Network manipulation flow (Phase 5)

1. `NetworkConditionService` (single writer: airplane flag, throttle profile, block rules) persists to UserDefaults and broadcasts a full `BoosterCommand` JSON snapshot through `CommandServer` (loopback-bound NWListener, `_booster-cmd._tcp.`)
2. Framework-side `BoosterCommandClient` discovers the channel, decodes frames, and applies into the `NSLock`-guarded `NetworkConditionController` store
3. `BoosterNetworkProtocol` (URLProtocol, chained with Pulse's exchange) evaluates each request: guard marker → airplane → block rules → throttle pacing (`ThrottlePacing`) → pass-through

**State Management:**
- Services own all domain state as `@Published`; persistence is `@AppStorage` (`AppSettings`, overlay toggle keys) or JSON-in-UserDefaults (presets, block rules)
- Explicit state machines guard multi-step work: `RecordingState`, `ExportState`, `AppActionOperation`, `NetworkConditionState`, `CertificateOperation` — each with `begin/finish/fail` transitions and `canTransition` assertions
- Side-window and overlay UI state (collapsed, side, arming) lives in the controllers, never in views

## Key Abstractions

**ObservableObject services:**
- Purpose: Single source of truth for one feature's state + verbs
- Examples: `BoosterSimApp/Services/SimulatorWindowTracker.swift`, `CaptureService.swift`, `DesignOverlayService.swift`, `ConnectService.swift`, `AppActionService.swift`
- Pattern: `@MainActor final class`, `@Published private(set)` state, sync public API, cancellables set, `[weak self]` sinks

**Pure static helpers ("calculator/compositor/geometry"):**
- Purpose: All placement math, coordinate mapping, image composition, argv construction — no state, fully unit-testable
- Examples: `BoosterSimApp/Windows/PositionCalculator.swift`, `BoosterSimApp/Services/OverlayGeometry.swift`, `BoosterSimApp/Utilities/CaptureCompositor.swift`, `nonisolated static` builders in `BoosterSimApp/Services/AppActionService.swift:724-808`

**NSPanel subclasses + owning controllers:**
- Purpose: Floating overlay surfaces that outlive focus changes
- Examples: `BoosterSimApp/Windows/SideWindowPanel.swift`, `DesignOverlayPanel.swift`, `AXHighlightPanel.swift`, `CaptureThumbnailPanel.swift` (all borderless `.nonactivatingPanel`-style, `isReleasedWhenClosed = false`, `.canJoinAllSpaces`)
- Pattern: controller owns lifetime; panel is dumb; `install(_:at:)`/contentView composition

**The simctl seam:**
- Purpose: Every `xcrun simctl` invocation funnels through one serialized, deadlock-proof executor
- Examples: `BoosterSimApp/Services/SimCtlService.swift` (concurrent stdout/stderr drains, `stdin: Data?`, static serial queue); consumers: StatusBar, EnvironmentOverride, Certificate, DeepLink, AppAction, UserDefaultsEditor services
- Pattern: services depend on `any SimCtlRunning`; pure `nonisolated static` builders produce argv; chains run verb-by-verb via `runChain`

**Cross-process framework mirror:**
- Purpose: Wire-contract types duplicated (semantics byte-for-byte) between Mac app and framework because the framework cannot import the app target
- Examples: `BoosterSimApp/Models/BoosterCommand.swift` ↔ `BoosterSimConnect/NetworkConditionController.swift`; guarded by `CommandPayloadTests` in `BoosterSimAppTests/`

## Entry Points

**App launch:**
- Location: `BoosterSimApp/BoosterSimAppApp.swift` (`@main`), `BoosterSimApp/App/AppDelegate.swift`
- Triggers: macOS app activation (LSUIElement — no Dock icon, `INFOPLIST_KEY_LSUIElement = YES` in `BoosterSimApp.xcodeproj/project.pbxproj`)
- Responsibilities: duplicate-instance termination; `sideWindowController.attach(to: tracker)`; `designOverlayController.attach(to:service:pixelSampler:)`; `tracker.startTracking()` + `buildStatsService.startMonitoring()` + `connectService.startServer()`; `CaptureExporter.sweepStaleCaptures()`; AX highlight wiring; first-launch onboarding NSWindow (`completedOnboarding` `@AppStorage`)
- Shutdown: `applicationWillTerminate` stops tracker/build monitoring/connect server and restores `TouchIndicatorController` (never leak `ShowSingleTouches`)

**Menu bar:**
- Location: `BoosterSimApp/Views/MenuBar/MenuBarView.swift` via `MenuBarExtra` (`.menu` style)
- Triggers: user click on bolt icon
- Responsibilities: show/hide side window, simulator list, Settings link, quit

**Preferences (Cmd+,):**
- Location: `BoosterSimApp/Views/Preferences/PreferencesView.swift` via `Settings` scene, sharing `AppDelegate.settings`

## Architectural Constraints

- **Threading:** Everything UI/service is `@MainActor`; Combine sinks hop to `.main`; AXObserver callbacks fire on the main run loop. No general async/await — the single sanctioned pattern is the SCK bridge (sync public API → one private `Task {}`), instantiated by exactly two services: `CaptureService` and `PixelSamplerService`. Framework-side classes in `BoosterSimConnect/` are deliberately NOT `@MainActor` (URLProtocol queue callbacks) and use `NSLock`/serial queues instead
- **Single instance:** `applicationDidFinishLaunching` terminates when another instance with the same bundle ID is running (`BoosterSimApp/App/AppDelegate.swift`)
- **Non-sandboxed:** required for Accessibility APIs, `CGWindowList`, CFPreferences writes into Simulator's domain, and simctl; entitlements file `BoosterHealth-Entitlements.plist` at repo root
- **One seam for subprocesses:** all `xcrun simctl` goes through `SimCtlService`; direct `Process` spawns are prohibited in phase-owned code
- **Schema sync duplication:** `BoosterCommand` semantics must be mirrored identically in `BoosterSimConnect/NetworkConditionController.swift`; every change is a two-side change
- **Dependency isolation:** Pulse/PulseProxy (SPM) link only into the `BoosterSimConnect` framework target; the app target itself is Apple-frameworks-only
- **Project settings:** `MACOSX_DEPLOYMENT_TARGET = 26.2`, `SWIFT_VERSION = 5.0` language mode with strict-concurrency upcoming features, 4 Xcode targets (app, unit tests, UI tests, framework) in `BoosterSimApp.xcodeproj/project.pbxproj`
- **Global state:** `AppSettings()` instances intentionally share `.standard` UserDefaults so convenience-instantiated services and the AppDelegate's instance agree (`BoosterSimApp/Services/CaptureService.swift:18`); no other module-level singletons

## Anti-Patterns

### Per-tool overlay windows

**What happens:** Each overlay tool gets its own window and manages visibility with `orderFront`/`orderOut` calls.
**Why it's wrong:** Z-order becomes call-order dependent; the artboard can end up above the guides.
**Do this instead:** One persistent panel with locked subview order — `DesignOverlayPanel.install(_:at: OverlayLayer)` using `addSubview(_:positioned:.below, relativeTo:)`; reference `BoosterSimApp/Windows/DesignOverlayPanel.swift:12-27`.

### Direct subprocess spawning

**What happens:** A service shells out to `/usr/bin/xcrun simctl …` itself.
**Why it's wrong:** Bypasses the serialized seam, pipe-drain deadlock protection, and stdin support; risks interleaved simctl pipelines.
**Do this instead:** Depend on `SimCtlService` (or `any SimCtlRunning` in tests); put argv in pure `nonisolated static` builders; reference `BoosterSimApp/Services/SimCtlService.swift`, `BoosterSimApp/Services/AppActionService.swift:580-625`.

### Re-deriving geometry at call sites

**What happens:** A view or controller computes scale or the window↔bitmap Y-flip inline.
**Why it's wrong:** The flip/scale is subtle (AppKit bottom-origin vs CGImage top-origin, Retina backing scale); duplicates drift.
**Do this instead:** Route through `OverlayGeometry` (`BoosterSimApp/Services/OverlayGeometry.swift`) with scale always an explicit parameter; `PixelSamplerService.imagePixel(forWindowPoint:)` is the reference consumer.

### Shared state in views / raw UserDefaults in views

**What happens:** `@State` or direct `UserDefaults.standard` reads for feature state.
**Why it's wrong:** Breaks the single-writer model; schema changes strand stored values.
**Do this instead:** Lift to an `ObservableObject` service; persist via `@AppStorage` in `AppSettings` or write-through `didSet` in the service; version renamed keys and import old payloads once behind a flag (`DesignOverlayService` legacy import is the reference, `BoosterSimApp/Services/DesignOverlayService+Presets.swift`).

### Hardcoded layout values

**What happens:** Literal paddings/sizes in view bodies.
**Why it's wrong:** Violates the token system; breaks panel metrics consistency.
**Do this instead:** Use `Spacing`/`CornerRadius`/`SideWindowMetrics`/`OverlayMetrics` from `BoosterSimApp/Utilities/DesignTokens.swift`.

## Error Handling

**Strategy:** Degrade honestly, never crash — user-facing captions describe what is possible; failures are published state, not thrown errors at the UI.

**Patterns:**
- Preflight before act: `CGPreflightScreenCaptureAccess()` in `CaptureService.captureTarget()` and `PixelSamplerService.arm()`; `PermissionManager` polls for grants and publishes `needsRelaunch` because TCC grants apply after relaunch (`BoosterSimApp/Services/CaptureService.swift:112-121`)
- State machines funnel every exit through typed transitions with `assertionFailure` on illegal moves (`AppActionService.transition`, `BoosterSimApp/Services/AppActionService.swift:647-651`)
- Pure validation gates before any subprocess: coordinate/payload/defaults-key validators return typed errors and never build argv on failure (`coordinatePair`, `sendPush` gates in `BoosterSimApp/Services/AppActionService.swift`)
- Late async results are discarded by generation token (`PixelSamplerService.handleCaptureResult`, `BoosterSimApp/Services/PixelSamplerService.swift`)
- Service errors surface as `lastError`/`samplerError`/`statusCaption` strings mirrored into the owning tab

## Cross-Cutting Concerns

**Logging:** `AppLogger` (`BoosterSimApp/Utilities/AppLogger.swift`) — static `Logger` per concern (`windowTracking`, `permissions`, `settings`, `certificates`, `network`, `actions`), subsystem `com.nextlabs.BoosterSimApp`; verb/outcome-only logging; payload bodies, pixel data, clipboard content, and defaults values never reach logs

**Validation:** Pure static builders/caps (`AppActionCatalog.filter`, `TrafficFilter`, `BlockRule.matches`, `OverlayGeometry`) own all matching/derivation so views contain no per-view logic chains

**Authentication/Permissions:** No auth anywhere; macOS TCC permissions (Accessibility, Screen Recording, DerivedData bookmark) managed by `BoosterSimApp/Services/PermissionManager.swift`; certificate trust for Simulator is a developer-tool feature (`CertificateService` + `CertificateStore`, files under Application Support with `0o600`)

**Accessibility/Reduce Motion:** `NSWorkspace.shared.accessibilityDisplayShouldReduceMotion` switches springs to rigid tracking (`BoosterSimApp/Windows/SideWindowController.swift:26-27`); icon-only buttons carry `accessibilityLabel`s

---

*Architecture analysis: 2026-08-31*
