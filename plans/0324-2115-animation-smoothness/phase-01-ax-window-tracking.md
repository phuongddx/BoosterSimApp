# Phase 1 — Fix AX Window-Element Tracking

**Priority:** High
**Status:** done
**File:** `BoosterSimApp/Services/WindowObserver.swift`

## Problem

`WindowObserver` registers notifications on the **application element** with wrong notification names:
- `kAXMovedNotification` ("AXMoved") — element-level, not window-level
- `kAXResizedNotification` ("AXResized") — element-level, not window-level

Window move/resize during drag never fires these callbacks. Panel falls back to 0.5s `pollTimer` → visible lag.

## Fix

### Step 1 — Change notification names

Replace element-level with window-level notification names for move/resize:
- `kAXMovedNotification` → `kAXWindowMovedNotification` ("AXWindowMoved")
- `kAXResizedNotification` → `kAXWindowResizedNotification` ("AXWindowResized")

### Step 2 — Register on window elements, not app element

After creating `AXObserver`, enumerate `kAXWindowsAttribute` from the app element.
Register `kAXWindowMovedNotification` + `kAXWindowResizedNotification` on **each window element**.

Keep app-element registration for lifecycle events:
- `kAXWindowCreatedNotification` — app element (correct)
- `kAXWindowMiniaturizedNotification` — app element (correct)
- `kAXWindowDeminiaturizedNotification` — app element (correct)
- `kAXUIElementDestroyedNotification` — app element (correct)

### Step 3 — Handle new windows

When `kAXWindowCreatedNotification` fires, re-enumerate windows and register on any newly-created window elements.

## Implementation Steps

1. In `WindowObserver`, split `notifications` into two sets:
   - `appNotifications`: lifecycle events (created, miniaturized, destroyed)
   - `windowNotifications`: moved, resized

2. In `startObserving()`, after registering app-level notifications:
   ```
   - Call AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute, &windows)
   - For each window in the array, call AXObserverAddNotification(obs, windowElement, kAXWindowMovedNotification, selfPtr)
   - Store window elements for later use in position queries (Phase 2)
   ```

3. In `handleNotification()`, when `kAXWindowCreatedNotification` fires:
   - Re-enumerate windows and register on any new window elements

## Related Code Files

- `BoosterSimApp/Services/WindowObserver.swift` — primary change
- `BoosterSimApp/Services/SimulatorWindowTracker.swift` — no change needed in this phase

## Todo

- [x] Split notification sets (app-level vs window-level)
- [x] Enumerate window elements in `startObserving()`
- [x] Register moved/resized on each window element
- [x] Re-register on `kAXWindowCreatedNotification`
- [x] Build and test: drag Simulator → panel should follow in real-time

## Risk

- If Accessibility permission not granted, `AXUIElementCopyAttributeValue` returns no windows → graceful fallback to poll-only mode (no crash, just same behavior as before)
- `selfPtr` refcount: each `AXObserverAddNotification` call uses the same `selfPtr` — no additional retain needed (AX does not retain refcon)
