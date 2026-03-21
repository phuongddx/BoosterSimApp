# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run

```bash
# Build (terminal)
xcodebuild -project BoosterSimApp.xcodeproj -scheme BoosterSimApp -configuration Debug build

# Open in Xcode
open BoosterSimApp.xcodeproj
```

**Requirements:** Xcode 16.3+, macOS 15 Sequoia. Run with an iOS Simulator open to see live panel behavior.

**No tests, linting, or package manager configured.** Pure Apple frameworks only (AppKit, SwiftUI, Combine, CoreGraphics, ApplicationServices, ServiceManagement).

## Architecture

SwiftUI `@main` entry point + `@NSApplicationDelegateAdaptor` for AppKit interop. AppDelegate owns all services; views observe via `@ObservedObject` / `@EnvironmentObject`.

**Service ownership (AppDelegate):**
- `SimulatorWindowTracker` — detects Simulator windows; publishes `simulators` + `activeSimulator`
- `SideWindowController` — owns `SideWindowPanel` (NSPanel); positions/shows/hides it
- `AppSettings` — `@AppStorage`-backed settings shared to Preferences scene
- `PermissionManager` — Accessibility, Screen Recording, DerivedData checks

**Simulator detection is dual-mode:**
1. `WindowEnumerator` polls `CGWindowListCopyWindowInfo` every 0.5s (fallback)
2. `WindowObserver` wraps `AXObserver` per PID for real-time move/resize events

**Data flow:**
```
CGWindowList poll + AXObserver events
        ↓
SimulatorWindowTracker (@Published activeSimulator)
        ↓  Combine sink in SideWindowController.attach(to:)
SideWindowController → PositionCalculator → panel.setFrame()
        ↓  @ObservedObject in SwiftUI views
SideWindowView / MenuBarView
```

**Window coordinates:** `WindowEnumerator` converts Quartz Y (top-origin) to AppKit Y (bottom-origin) using primary screen height. `PositionCalculator` operates entirely in AppKit space.

## Key Constraints

- **Non-sandboxed** — required for `AXIsProcessTrusted()` and `CGWindowListCopyWindowInfo`
- **Swift 6 strict concurrency** — `@MainActor` on AppDelegate and SideWindowController; all UI/service work on main thread
- **No async/await** — use Combine `@Published` + Timer only
- **`isReleasedWhenClosed = false`** on SideWindowPanel — SideWindowController owns lifecycle
- **`hidesOnDeactivate = false`** on SideWindowPanel — panel stays visible when app loses focus
- `WindowObserver` uses `Unmanaged.passRetained` / `.release()` for the AXObserver refcon — must be balanced

## Design Tokens

All layout values come from `Utilities/DesignTokens.swift`. Never hardcode sizes or spacing. Key enums: `Spacing`, `CornerRadius`, `SideWindowMetrics`, `OnboardingMetrics`, `PreferencesMetrics`.

Accent color: amber `#E8720C` (light) / `#F59E0B` (dark) via `AccentColor` asset. SF Pro + SF Symbols exclusively.

## Docs

**`docs/` is the single source of truth** for all project decisions — architecture, code standards, design system, roadmap. Always read before implementing a feature; update after significant changes.

- `system-architecture.md` — layer diagram, component responsibilities
- `code-standards.md` — MARK structure, concurrency rules, prohibited patterns
- `design-guidelines.md` — spacing system, color palette, SF Symbols reference
- `project-roadmap.md` — phase status, planned features
- `codebase-summary.md` — file map with LOC

## Reference Implementation

`../RocketSimApp/dev-docs/` contains the reference app's documentation (RocketSim — commercial app this project is inspired by). Read-only. Use it to understand how features are designed, named, and structured before implementing anything new in BoosterSimApp.
