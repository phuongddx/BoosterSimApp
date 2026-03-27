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
│  └── Onboarding NSWindow (first-launch only)        │
└───────────────┬─────────────────────────────────────┘
                │ Combine @Published
┌───────────────▼─────────────────────────────────────┐
│  Services Layer                                     │
│  ├── WindowEnumerator — CGWindowListCopyWindowInfo  │
│  ├── WindowObserver — AXObserver C callbacks        │
│  ├── PermissionManager — Accessibility/SR/DData     │
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
- Owns all services: `tracker`, `settings`, `sideWindowController`
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

### Windows

**`SideWindowPanel`** (`Windows/SideWindowPanel.swift`)
- `NSPanel` subclass, level `.floating`, `hidesOnDeactivate = false`
- `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]`
- `isReleasedWhenClosed = false` — lifecycle managed by SideWindowController

**`SideWindowController`** (`Windows/SideWindowController.swift`)
- `@MainActor final class ObservableObject`
- Subscribes to `tracker.$activeSimulator` via Combine sink
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

**`AppSettings`** (`Models/AppSettings.swift`)
- `ObservableObject` backed entirely by `@AppStorage`
- Keys: `sideWindowPosition`, `showSideWindow`, `launchAtLogin`, `xcodePath`
- `setLaunchAtLogin(_:)` syncs with `SMAppService.mainApp`

### Views

**`MenuBarView`** — Show/hide toggle (Cmd+B), simulator list, Settings link, Quit
**`SideWindowView`** — Root: collapsed strip or expanded panel with 4 feature sections
**`PreferencesView`** — Tab container for General and About tabs
**`OnboardingContainerView`** — 4-step flow: welcome, Accessibility, Screen Recording, done
**`CollapsedStripView`**, **`SideWindowTitleBar`**, **`DeviceHeaderView`**, **`SideWindowFooter`** — Side panel sub-views
**`FeatureSectionView`** / **`FeatureRowView`** — Feature list rows (MVP: "Coming soon" state)
**`AccentButton`**, **`StatusBadge`** — Shared UI atoms

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
| NSPanel over NSWindow | Floating utility window behavior, `hidesOnDeactivate = false` |
| Dual-mode tracking (poll + AXObserver) | Graceful degradation without Accessibility permission |
| Zero external dependencies | Minimal footprint, no SPM overhead, pure Apple framework stability |
| Non-sandboxed | Required for Accessibility API and CGWindowList enumeration |
