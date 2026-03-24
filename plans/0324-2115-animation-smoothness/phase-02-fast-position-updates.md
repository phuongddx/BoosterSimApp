# Phase 2 — Fast Position Update Path

**Priority:** High
**Status:** done
**Files:** `Services/WindowObserver.swift`, `Services/SimulatorWindowTracker.swift`

## Problem

Every AX move/resize callback calls `scanAndUpdate()` → `WindowEnumerator.enumerateSimulatorWindows()` → full `CGWindowListCopyWindowInfo` system-wide scan. During a drag, this fires many times per second with full scan overhead each time. Expensive and unnecessary.

<!-- Updated: Validation Session 1 - Pass element from callback instead of stored refs; add poll timer reduction -->

## Fix

Add a lightweight position-only update path that reads frame directly from the AX element delivered in the callback, bypassing the full CGWindowList scan.

### Approach

1. Change `WindowObserver` callback signature from `(String) -> Void` to `(String, AXUIElement) -> Void` — pass the element that fired the notification
2. On move/resize callback, read `kAXPositionAttribute` + `kAXSizeAttribute` from the callback element → compute `CGRect`
3. Add `onFrameChanged: ((CGRect) -> Void)?` callback on `WindowObserver`
4. `SimulatorWindowTracker` handles `onFrameChanged` to directly update `activeSimulator.frame` without full scan
5. Reduce poll timer from 0.5s to 2s (AX now handles real-time; poll is just a fallback)

Full `scanAndUpdate()` is still called for lifecycle events (created, destroyed, miniaturized).

## Implementation Steps

1. **In `WindowObserver`:**
   - Change `callback` type: `((String, AXUIElement) -> Void)?`
   - Update `axCallback` to pass element through: `windowObserver.handleNotification(notification as String, element: element)`
   - Update `handleNotification(_ name: String, element: AXUIElement)` signature
   - Add `onFrameChanged: ((CGRect) -> Void)?` property
   - In `handleNotification()`, for `kAXWindowMovedNotification`/`kAXWindowResizedNotification`: read position+size from the callback element, compute `CGRect`, call `onFrameChanged`
   - Helper: `private func readWindowFrame(from element: AXUIElement) -> CGRect?`

2. **In `SimulatorWindowTracker.setupObserver(for:)`:**
   - Update callback usage: `obs.startObserving { [weak self] name, _ in ... }` (element unused in generic callback)
   - Set `obs.onFrameChanged` closure: update matching `SimulatorWindow.frame` in `simulators` array, update `activeSimulator` if it matches — no full scan
   - Keep existing callback for lifecycle events → still calls `scanAndUpdate()`

3. **In `SimulatorWindowTracker.startPolling()`:**
   - Change interval from `0.5` to `2.0`

4. **Quartz → AppKit coordinate conversion:**
   - `WindowEnumerator` already has the Y-flip logic; extract it into a shared helper or duplicate the one-liner in the fast path

## Implementation Notes

- Quartz Y-axis is top-origin; AppKit is bottom-origin. Must flip: `appKitY = screenHeight - quartzY - height`
- AXUIElement position is also in screen coordinates (top-origin); same flip needed
- No stored AXUIElement references — element comes from callback, eliminating stale reference risk
- For multi-window Simulator: match by PID (all windows in `observers[pid]` belong to that pid's simulators)

## Todo

- [x] Change `WindowObserver.callback` signature to `(String, AXUIElement) -> Void`
- [x] Update `axCallback` and `handleNotification` to pass element through
- [x] Add `onFrameChanged` callback property
- [x] Implement `readWindowFrame(from:)` helper
- [x] Route moved/resized to `onFrameChanged` in `handleNotification()`
- [x] Wire `onFrameChanged` in `SimulatorWindowTracker.setupObserver(for:)`
- [x] Reduce poll timer from 0.5s to 2.0s
- [x] Verify coordinate flip is correct
- [x] Build and test: panel position should update with no CGWindowList scan during drag

## Risk

- AX queries (`AXUIElementCopyAttributeValue`) are synchronous on main thread — but they're fast (single element lookup, no enumeration)
- If callback element refers to a closed window, query returns error → handle gracefully, fall back to scan (no stale stored refs to manage)
