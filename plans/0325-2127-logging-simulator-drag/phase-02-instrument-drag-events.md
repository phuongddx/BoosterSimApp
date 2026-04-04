# Phase 2: Instrument Drag Events

## Status: complete

## Overview

Add `.debug` log in `WindowObserver.handleNotification` when `kAXWindowMovedNotification` fires. This covers every frame update during a simulator drag.

## Implementation

**File:** `BoosterSimApp/Services/WindowObserver.swift`

<!-- Updated: Validation Session 1 - move-only, .public privacy, setupObserver log confirmed -->

In `handleNotification(_:element:)`, log only `kAXWindowMovedNotification` (not resize):

```swift
if name == kAXWindowMovedNotification as String || name == kAXWindowResizedNotification as String {
    if let frame = readWindowFrame(from: element) {
        if name == kAXWindowMovedNotification as String {
            AppLogger.windowTracking.debug("Simulator moved: pid=\(self.pid, privacy: .public) frame=\(frame.debugDescription, privacy: .public)")
        }
        onFrameChanged?(frame)
    }
    return
}
```

**File:** `BoosterSimApp/Services/SimulatorWindowTracker.swift` — log AX observer setup

```swift
private func setupObserver(for pid: pid_t) {
    AppLogger.windowTracking.info("AX observer set up for pid=\(pid, privacy: .public)")
    // ... existing code
}
```

## Steps

- [ ] In `WindowObserver.handleNotification`, add `AppLogger.windowTracking.debug(...)` for move events only (skip resize)
- [ ] Use `privacy: .public` on all dynamic values in log messages
- [ ] In `WindowObserver.startObserving`, replace `print(...)` error with `AppLogger.windowTracking.error(...)`
- [ ] Log `setupObserver(for:)` at `.info` in `SimulatorWindowTracker`

## Log Levels Summary

| Event | Level | Rationale |
|-------|-------|-----------|
| Simulator moved (per drag frame) | `.debug` | High freq — move only, not resize |
| AX observer created | `.info` | One-time per PID |
| AX observer creation failed | `.error` | Failure path |
| AppSettings launch-at-login error | `.error` | Failure path |

## Verification

Open Console.app → filter: `subsystem:com.nextlabs.BoosterSimApp` → drag simulator → confirm `debug` messages stream in real time.
