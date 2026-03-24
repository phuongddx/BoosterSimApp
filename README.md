# BoosterSimApp

macOS menu bar companion app that attaches a floating side panel to the iOS Simulator. Built with AppKit + SwiftUI, zero external dependencies, targeting macOS 15+.

## Features

**Core Panel**
- Bolt icon in menu bar — shows Simulator connection status
- Floating side panel attaches to active Simulator window
- Auto-positioning: left, right, bottom, or dynamic
- Collapse to 28pt strip; expand to 260pt panel
- Device header with simulator name and OS version
- Preferences window (Cmd+,)

**Inspection & Debugging** *(implemented)*
- AX Inspector — browse live accessibility tree with element highlighting
- Build Stats — chart of recent build times via Xcode derived data
- Environment Overrides — appearance, contrast, motion, bold text toggles
- Status Bar — 4 presets + custom time/battery/signal via simctl
- Camera — use Mac camera as Simulator input via AX menu automation

**Planned**
- Captures — screenshot, screen recording, GIF/MP4 export
- App Actions — reset app, clear keychain, push notifications, deep link
- Design Tools — grid overlay, safe area overlay, color picker
- Network — throttle, block requests, view traffic logs

**Onboarding**
- Permission onboarding (Accessibility, Screen Recording)
- Graceful fallback to 0.5s polling when Accessibility is denied

## Requirements

- macOS 15 Sequoia+
- Xcode 16.3+
- iOS Simulator (for live testing)

## Build & Run

```bash
cd BoosterSimApp
open BoosterSimApp.xcodeproj
# Press Cmd+R in Xcode
```

Or from terminal:

```bash
xcodebuild -project BoosterSimApp.xcodeproj -scheme BoosterSimApp -configuration Debug build
```

## Permissions

On first launch, the onboarding flow guides you through:

| Permission | Purpose |
|---|---|
| Accessibility | Real-time window move/resize events via AXObserver; AX tree inspection |
| Screen Recording | Read Simulator device names from window list |

Without Accessibility, the app falls back to 0.5s polling — still functional, less responsive. AX Inspector requires Accessibility permission.

## Architecture

SwiftUI `@main` App + `@NSApplicationDelegateAdaptor` for AppKit interop. Services use Combine `@Published` for state. Swift 6 strict concurrency throughout. 44 Swift files, ~2,500 LOC, zero external dependencies.

```
BoosterSimAppApp (@main)
└── AppDelegate
    ├── SimulatorWindowTracker      — CGWindowList poll + AXObserver
    ├── SideWindowController        — NSPanel lifecycle + positioning
    │   └── AXHighlightPanel        — floating overlay for AX element highlight
    ├── PermissionManager           — Accessibility / Screen Recording checks
    ├── AppSettings                 — @AppStorage persistence
    ├── AXInspectorService          — lazy AX tree walker + element selection
    ├── BuildStatsService           — poll DerivedData build timing logs
    ├── CameraService               — Mac camera input via AX menu automation
    ├── EnvironmentOverrideService  — appearance / a11y env overrides
    ├── SimCtlService               — xcrun simctl executor
    └── StatusBarService            — status bar preset + custom config
```

See [`docs/system-architecture.md`](docs/system-architecture.md) for full details.

## Keyboard Shortcuts

| Shortcut | Action |
|---|---|
| Cmd+B | Toggle side panel |
| Cmd+W | Hide side panel |
| Cmd+, | Open Preferences |

## Docs

| Document | Description |
|---|---|
| [`docs/project-overview-pdr.md`](docs/project-overview-pdr.md) | Product requirements |
| [`docs/system-architecture.md`](docs/system-architecture.md) | Architecture & data flow |
| [`docs/codebase-summary.md`](docs/codebase-summary.md) | File map & stats |
| [`docs/code-standards.md`](docs/code-standards.md) | Coding conventions |
| [`docs/design-guidelines.md`](docs/design-guidelines.md) | Design system |
| [`docs/project-roadmap.md`](docs/project-roadmap.md) | Feature roadmap |
| [`docs/deployment-guide.md`](docs/deployment-guide.md) | Build & distribution |
