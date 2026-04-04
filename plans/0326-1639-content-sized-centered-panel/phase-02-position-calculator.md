---
phase: 2
title: Update PositionCalculator for content height + centering
status: completed
priority: high
effort: S
completed: 2026-03-26
---

# Phase 02 — Update PositionCalculator

## Overview

Replace the `panelHeight = max(simulatorFrame.height, minHeight)` calculation with `contentHeight` passed from the controller. Compute centered Y origin for left/right/dynamic positions.

## Related Files

- `BoosterSimApp/Windows/PositionCalculator.swift`

## Current Behavior

```swift
let panelHeight = max(simulatorFrame.height, SideWindowMetrics.minHeight)
// Y origin = sim.minY (top-aligned to simulator bottom in AppKit coords)
```

## New Behavior

```swift
// panelHeight = content-driven (passed in), floored by minHeight
let panelHeight = max(contentHeight, SideWindowMetrics.minHeight)

// Centered Y: vertically align panel midpoint with simulator midpoint
let centeredY = sim.midY - panelHeight / 2
let clampedY = max(screen.minY, min(centeredY, screen.maxY - panelHeight))
```

## Implementation Steps

<!-- Updated: Validation Session 1 - isCollapsed only affects width, not height -->

1. Update `panelFrame` signature — add `contentHeight: CGFloat` param:

```swift
static func panelFrame(
    simulatorFrame: CGRect,
    position: SideWindowPosition,
    screenFrame: CGRect,
    isCollapsed: Bool,              // width only — collapsed = 28pt, expanded = 260pt
    contentHeight: CGFloat          // NEW — always drives height regardless of collapse state
) -> CGRect {
    let panelWidth = isCollapsed ? SideWindowMetrics.collapsedWidth : SideWindowMetrics.expandedWidth
    let panelHeight = max(contentHeight, SideWindowMetrics.minHeight)  // isCollapsed does NOT affect height
    // ...
}
```

2. Update `rightFrame` and `leftFrame` helpers — replace `y: sim.minY` with centered Y:

```swift
private static func rightFrame(sim: CGRect, width: CGFloat, height: CGFloat, screen: CGRect) -> CGRect {
    let x = min(sim.maxX, screen.maxX - width)
    let y = centeredY(sim: sim, height: height, screen: screen)
    return CGRect(x: x, y: y, width: width, height: height)
}

private static func leftFrame(sim: CGRect, width: CGFloat, height: CGFloat, screen: CGRect) -> CGRect {
    let x = max(sim.minX - width, screen.minX)
    let y = centeredY(sim: sim, height: height, screen: screen)
    return CGRect(x: x, y: y, width: width, height: height)
}

// New shared helper
private static func centeredY(sim: CGRect, height: CGFloat, screen: CGRect) -> CGFloat {
    let ideal = sim.midY - height / 2
    return max(screen.minY, min(ideal, screen.maxY - height))
}
```

3. `bottomFrame` — no change (bottom position has its own height logic).

4. `dynamicFrame` — delegates to `rightFrame`/`leftFrame`, inherits centering automatically.

## Todo

- [x] Add `contentHeight: CGFloat` param to `panelFrame`
- [x] Compute `panelHeight = max(contentHeight, SideWindowMetrics.minHeight)`
- [x] Add `centeredY(sim:height:screen:)` private helper
- [x] Update `rightFrame` and `leftFrame` to use `centeredY`
- [x] Verify `dynamicFrame` still works (it delegates — no direct change needed)
- [x] Verify `bottomFrame` unaffected

## Success Criteria

- `panelFrame` compiles with new signature
- Panel Y is centered on simulator midpoint when `position` is `.left`, `.right`, `.dynamic`
- Panel never goes off-screen (clamped)
- `bottomFrame` behavior unchanged
