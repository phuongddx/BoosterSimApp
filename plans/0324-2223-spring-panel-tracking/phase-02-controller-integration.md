---
phase: 2
status: complete
priority: high
completed: 2026-03-24
---

# Phase 2: Controller Integration

## Overview
Wire `SpringAnimator` into `SideWindowController` so panel position updates flow through spring physics instead of direct `setFrame()`.

## Key Insights
- `updatePosition()` currently does rigid `panel.setFrame()` — replace with `springAnimator.setTarget(frame:)`
- Side-switch detection needed: when `PositionCalculator` returns a frame on the opposite side, use `snapTo()` then spring-settle
- Reduce Motion: when `accessibilityDisplayShouldReduceMotion` is true, bypass spring entirely → direct setFrame
- Collapse/expand toggle already has its own animation context — keep that separate

## Data Flow (After)

```
AX callback → SimulatorWindowTracker (frame update)
    ↓ Combine sink
SideWindowController.updatePosition()
    ↓ PositionCalculator.panelFrame()
    ↓ side-switch check
    ├── same side → springAnimator.setTarget(frame:)
    └── different side → springAnimator.snapTo(frame:)
    ↓ CADisplayLink tick
    └── panel.setFrame(springFrame, display: true)
```

## Side-Switch Detection
Compare new panel frame's X origin relative to simulator center:
- If panel was on right (panel.minX >= sim.midX) and now on left (newFrame.minX < sim.minX), side switched
- Use `snapTo()` for instant reposition, then `setTarget()` to spring-settle

## Implementation Steps
1. Add `SpringAnimator` property to `SideWindowController`
2. Wire `onFrameUpdate` callback to `panel.setFrame()`
3. Modify `updatePosition()` to route through spring animator
4. Add side-switch detection logic
5. Skip spring when `reducedMotion` is true
6. Ensure collapse/expand animation unchanged (uses its own NSAnimationContext)

## Related Code Files
- Modify: `BoosterSimApp/Windows/SideWindowController.swift`

## Todo
- [x] Add SpringAnimator property
- [x] Wire onFrameUpdate to panel.setFrame
- [x] Modify updatePosition() to use setTarget/snapTo
- [x] Add side-switch detection
- [x] Respect reducedMotion preference
- [x] Verify collapse/expand animation still works

## Risk Assessment
- **CADisplayLink thread safety**: Must be on main thread — `@MainActor` ensures this
- **Stale target**: If AX stops firing mid-drag, spring settles to last known position (correct behavior)
- **Performance**: Display link only runs during active tracking; at-rest auto-stops

## Success Criteria
- Panel tracks simulator with visible elastic lag
- Panel overshoots then settles when simulator stops
- Dynamic mode side-switch is instant + spring settle
- Reduce Motion = rigid 1:1 tracking (no spring)
- Collapse/expand animation unchanged
- Builds clean, no concurrency warnings
