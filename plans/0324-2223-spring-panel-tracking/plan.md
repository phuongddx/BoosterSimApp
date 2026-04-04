---
status: complete
created: 2026-03-24
completed: 2026-03-24
slug: spring-panel-tracking
---

# Spring Panel Tracking Plan

Add spring physics to side panel position tracking so the panel follows the simulator window with elastic lag and settles with bounce — matching RocketSim behavior observed in `animation-movement.mov`.

## Current Behavior
- `WindowObserver.onFrameChanged` fires per AX move event
- `SimulatorWindowTracker` updates `activeSimulator` frame
- `SideWindowController.attach(to:)` Combine sink → `updatePosition()` → rigid `panel.setFrame()`
- Panel moves 1:1 rigidly with simulator — no lag, no spring, no overshoot

## Target Behavior (from video analysis)
1. **Smooth tracking with lag** — Panel follows with slight delay during drag
2. **Spring overshoot** — Panel overshoots target then springs back when drag stops
3. **Side-switching snap** — In dynamic mode, panel instantly snaps to opposite side with spring settle

## Phases

| # | Phase | Priority | Status |
|---|---|---|---|
| 1 | [Spring animator engine](phase-01-spring-animator.md) | High | complete |
| 2 | [Controller integration](phase-02-controller-integration.md) | High | complete |

## Files to Create
- `Utilities/SpringAnimator.swift` — Display-link driven spring physics engine

## Files to Modify
- `Windows/SideWindowController.swift` — Use SpringAnimator instead of direct setFrame

## Success Criteria
- Panel follows simulator with visible elastic lag during drag
- Panel overshoots and springs back when simulator stops
- Dynamic mode side-switch is instant followed by spring settle
- Respects `accessibilityDisplayShouldReduceMotion` (rigid tracking when on)
- No jank, no visible frame drops
- Builds clean under Swift 6 strict concurrency
