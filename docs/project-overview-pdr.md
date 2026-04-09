# BoosterSimApp — Project Overview & PDR

## Product Summary

BoosterSimApp is a macOS menu bar companion app that attaches a floating side panel to the iOS Simulator. It provides developers with quick-access tools — screenshot capture, network throttling, deep links, push notifications, and design overlays — without switching away from their simulator session.

**Inspired by:** RocketSim (commercial reference). BoosterSimApp is an independent, open implementation targeting MVP feature parity.

## Problem Statement

iOS developers spend significant time switching between the Simulator and external tools to capture screenshots, test push notifications, manage app state, or inspect design layouts. No native solution exists for a persistent, context-aware side panel alongside the Simulator.

## Target Users

- iOS/macOS developers running Xcode Simulator during daily development
- Single user (developer) operating on macOS 15+ with Xcode 16.3+

## Scope (Phase 1 + Phase 6 Complete)

### Implemented
- Menu bar app with bolt icon (connected/disconnected state)
- Floating side panel with 4 position modes (left, right, bottom, dynamic)
- Collapse/expand animation (respects Reduce Motion)
- Spring-physics panel position tracking (CADisplayLink)
- Simulator detection with real-time position sync; panel hides on Simulator focus loss
- Permission onboarding (Accessibility, Screen Recording, DerivedData)
- Preferences window (position, launch at login)
- **Tab-based UI:** Capture, Design, Actions, Network tabs with icon-only floating header
- **Phase 6 features:** Status bar config (4 presets + custom), environment overrides (11 a11y toggles), build history chart, accessibility tree inspector with element highlighting, Mac camera input
- **Certificate Trust Management:** CA generation, Simulator keychain install/rotate/reset via side panel; persists trust state across sessions

### Out of Scope (Phases 2–5, 7)
- Screenshot capture / screen recording / GIF export
- App actions (reset, clear keychain, push notifications, deep links)
- Design overlays (grid, safe area, color picker, ruler)
- Network tools (throttle, block requests) — *Certificate trust management implemented*
- Distribution & code signing

## Requirements

### Functional
- FR-01: Detect running iOS Simulator windows via CGWindowListCopyWindowInfo
- FR-02: Real-time position tracking via AXObserver callbacks (move, resize, minimize events)
- FR-03: Side panel floats above all windows including Simulator (NSPanel level .floating)
- FR-04: Panel repositions when Simulator moves or resizes
- FR-05: Panel hides when no Simulator is detected
- FR-06: Supports 4 position modes: left, right, bottom, dynamic
- FR-07: Collapse to 28pt strip; expand to 260pt panel
- FR-08: Menu bar icon shows Simulator connection status
- FR-09: First-launch onboarding flow (4 steps, permission setup)
- FR-10: Preferences (position, launch at login, Xcode path)
- FR-11: Cmd+B toggles panel; Cmd+W hides it; Cmd+, opens Preferences
- FR-12: Panel hides when Simulator loses focus (app activation change)
- FR-13: Tab-based navigation (Capture, Design, Actions, Network)
- FR-14: Environment overrides apply instantly (no app relaunch) via `xcrun simctl spawn`
- FR-15: Spring-physics tracking for smooth panel position following (CADisplayLink, reducedMotion-aware)
- FR-16: Certificate trust management (CA generation, install, rotate, reset in Simulator keychain)

### Non-Functional
- NFR-01: macOS 15+ only (no backwards compat shims)
- NFR-02: Swift 6 strict concurrency (no data races)
- NFR-03: Zero external dependencies (Apple frameworks only)
- NFR-04: Non-sandboxed (runtime permissions via AXIsProcessTrusted, CGPreflightScreenCaptureAccess)
- NFR-05: LSUIElement = true (no Dock icon)
- NFR-06: 0.5s polling fallback when Accessibility permission not granted

## Permissions Required

| Permission | Purpose | API |
|---|---|---|
| Accessibility | AXObserver real-time window events | `AXIsProcessTrusted()` |
| Screen Recording | Read window names (device names) | `CGPreflightScreenCaptureAccess()` |
| DerivedData (security-scoped bookmark) | Future: build logs, crash reports | `URL.bookmarkData(options: .withSecurityScope)` |

## Success Criteria

- Side panel appears and tracks Simulator position within 0.5s
- Collapse/expand animation is smooth (0.2s, respects reduced motion)
- Onboarding completes and permissions are granted before first use
- App stays running when all windows closed (menu bar only)
- Zero crashes on Simulator launch/quit/move/resize lifecycle
