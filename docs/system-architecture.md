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
│  ├── EnvironmentOverrideService — a11y toggles      │
│  ├── StatusBarService — status presets + config     │
│  ├── BuildStatsService — build history polling      │
│  ├── AXInspectorService — accessibility tree walk   │
│  ├── CameraService — camera routing automation      │
│  ├── HealthDataService — companion install/trigger  │
│  ├── CertificateService — CA generation/trust mgmt  │
│  ├── SimCtlService — xcrun simctl executor          │
│  └── XcodeDetector — filesystem path detection     │
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

**`HealthDataService`** (`Services/HealthDataService.swift`)
- Installs bundled `BoosterHealth.app` onto active Simulator via `simctl install`
- Triggers companion via `boosterhealth://` URL scheme (`simctl openurl`) with preset/manual parameters
- Manages state: idle → installing → generating → done/error
- Auto-resets to idle after 3s on success; publishes `@Published` state for UI feedback
- Delegates to `SimCtlService` for command execution

**`CertificateService`** (`Services/CertificateService.swift`)
- Generates a local CA, installs it into the active Simulator keychain, and supports rotate/reset flows
- Persists install state so the UI can distinguish generated, installed, and unknown trust states
- Delegates certificate file creation to `CertificateStore` and shell execution to `SimCtlService`

**`CertificateStore`** (`Services/CertificateStore.swift`)
- Runs `/usr/bin/openssl` to create the CA key and certificate
- Stores generated files under Application Support/BoosterSimApp/Certificates with restrictive permissions
- Reads certificate metadata and redacts local paths in user-facing error messages

**`SimCtlService`** (`Services/SimCtlService.swift`)
- Centralized executor for `xcrun simctl` commands
- Parses boot arguments, environment overrides, status bar config
- Error handling with logged diagnostics

### Windows

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

**`AXHighlightPanel`** (`Windows/AXHighlightPanel.swift`)
- Borderless floating NSPanel overlay for accessibility element highlighting
- Draws orange border around selected element frame
- Stays on top of all windows; auto-hides after 2.5s

### Models

**`SimulatorWindow`** (`Models/SimulatorWindow.swift`)
- Value type (`struct`): id (`CGWindowID`), pid, deviceName, frame, isOnScreen, isMinimized
- `deviceName` is nil without Screen Recording permission; `displayName` provides fallback

**`CertificateModels.swift`**
- `CertificateMetadata` stores CA common name, expiry, and SHA-256 fingerprint
- `CertificateStatus` tracks generated, installed, unknown, and not-generated states
- `CertificateOperation` guards generate/install/rotate/reset transitions; `CertificateError` carries user-facing failures

**`AppSettings`** (`Models/AppSettings.swift`)
- `ObservableObject` backed entirely by `@AppStorage`
- Keys: `sideWindowPosition`, `showSideWindow`, `launchAtLogin`, `xcodePath`
- `setLaunchAtLogin(_:)` syncs with `SMAppService.mainApp`

**`AXNode`** (`Models/AXNode.swift`)
- Accessibility tree node: role, description, frame, attributes
- Hashable for list rendering; supports equality comparison

**`BuildRecord`** (`Models/BuildRecord.swift`)
- Build history record: timestamp, duration, device name
- Decoded from Xcode `IDEActivityLog` JSON logs

### Views

**`MenuBarView`** — Show/hide toggle (Cmd+B), simulator list, Settings link, Quit
**`SideWindowView`** — Root: collapsed strip or expanded panel with content-driven height
**`PreferencesView`** — Tab container for General and About tabs
**`OnboardingContainerView`** — 4-step flow: welcome, Accessibility, Screen Recording, done
**`CollapsedStripView`**, **`SideWindowTitleBar`**, **`DeviceHeaderView`**, **`SideWindowFooter`** — Side panel chrome
**`DeviceHeaderView`** — Active simulator name, OS version, battery/signal status
**`StatusBarSectionView`** — Status bar preset picker + custom controls
**`EnvironmentOverridesView`** — Accessibility toggles (appearance, contrast, motion, bold text, smart invert, etc.)
**`CertificateSectionView`** — CA generation, Simulator keychain install/rotate/reset, trust-state messaging
**`BuildStatsSectionView`** / **`BuildChartView`** — Build history + Canvas bar chart
**`AXTreeView`** — Accessibility tree browser with element highlight
**`CameraView`** — Front/back camera toggle for iOS Simulator
**`HealthDataSectionView`** — Health data preset buttons, manual mode row, status, auth hint
**`FeatureSectionView`** / **`FeatureRowView`** — Feature list rows
**`AccentButton`**, **`StatusBadge`**, **`CollapsibleSection`** — Shared UI atoms

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
| Zero external dependencies | Minimal footprint, no SPM overhead, pure Apple framework stability |
| Non-sandboxed | Required for Accessibility API, CGWindowList enumeration, and companion app installation |
| BoosterHealth bundled companion | Simulator-only iOS app inside macOS bundle; uses `simctl install` + URL scheme for HealthKit writes |
