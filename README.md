# BoosterSimApp

macOS menu bar companion app that attaches a floating side panel to the iOS Simulator. Built with AppKit + SwiftUI, zero external dependencies, targeting macOS 15+.

## Features (MVP)

- Bolt icon in menu bar — shows Simulator connection status
- Floating side panel attaches to active Simulator window
- Auto-positioning: left, right, bottom, or dynamic
- Collapse to 28pt strip; expand to 260pt panel
- Permission onboarding (Accessibility, Screen Recording)
- Preferences window (Cmd+,)

**Coming in later phases:** Screenshot/recording, app actions (reset, keychain, push notifications, deep links), design overlays, network tools.

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
| Accessibility | Real-time window move/resize events via AXObserver |
| Screen Recording | Read Simulator device names from window list |

Without Accessibility, the app falls back to 0.5s polling — still functional, less responsive.

## Architecture

SwiftUI `@main` App + `@NSApplicationDelegateAdaptor` for AppKit interop. Services use Combine `@Published` for state. Swift 6 strict concurrency throughout.

```
BoosterSimAppApp (@main)
└── AppDelegate
    ├── SimulatorWindowTracker  — CGWindowList poll + AXObserver
    ├── SideWindowController    — NSPanel lifecycle + positioning
    ├── PermissionManager       — Accessibility / Screen Recording
    └── AppSettings             — @AppStorage persistence
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
