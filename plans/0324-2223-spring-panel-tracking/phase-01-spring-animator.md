---
phase: 1
status: complete
priority: high
completed: 2026-03-24
---

# Phase 1: Spring Animator Engine

## Overview
Create a reusable `@MainActor` spring physics engine driven by `CADisplayLink` (macOS 14+). Animates an `NSPanel` frame toward a target with configurable stiffness/damping.

## Key Insights
- macOS 15+ target means `CADisplayLink` is available (added macOS 14)
- Spring math: `force = -stiffness * displacement - damping * velocity`
- Must handle continuous target updates (target moves every AX frame during drag)
- At-rest detection: stop display link when displacement + velocity below threshold
- `@MainActor` required — `CADisplayLink` callback sets panel frame on main thread

## Architecture

```
SpringAnimator
├── Properties
│   ├── targetOrigin: CGPoint         — updated on every AX callback
│   ├── targetSize: CGSize            — updated on every AX callback
│   ├── currentOrigin: CGPoint        — current animated position
│   ├── velocity: CGPoint             — current spring velocity
│   ├── stiffness: CGFloat = 280      — spring constant (higher = snappier)
│   ├── damping: CGFloat = 22         — friction (higher = less bounce)
│   ├── restThreshold: CGFloat = 0.5  — px threshold for at-rest
│   └── displayLink: CADisplayLink?
├── Methods
│   ├── setTarget(frame:) → update target, start link if needed
│   ├── snapTo(frame:) → instantly set position, zero velocity (for side-switch)
│   └── stop() → invalidate display link
└── Callback
    └── onFrameUpdate: ((CGRect) -> Void)?  — called per tick with new frame
```

## Spring Constants (tuned to match video)
- **Stiffness 280**: Responsive but not instant — visible tracking lag
- **Damping 22**: Underdamped — allows 1-2 oscillations before settling
- **Rest threshold 0.5px**: Stop animating when close enough

## Implementation Steps
1. Create `Utilities/SpringAnimator.swift`
2. Implement `CADisplayLink` setup/teardown
3. Implement spring physics step function
4. Add at-rest detection to auto-stop display link
5. Add `snapTo(frame:)` for instant repositioning (side-switch)

## Related Code Files
- Create: `BoosterSimApp/Utilities/SpringAnimator.swift`

## Todo
- [x] Create SpringAnimator class with CADisplayLink
- [x] Implement spring physics math
- [x] Add at-rest detection
- [x] Add snapTo for instant repositioning

## Success Criteria
- SpringAnimator drives smooth frame updates at display refresh rate
- At-rest detection stops display link (no idle CPU cost)
- snapTo immediately positions without animation
- Clean Swift 6 strict concurrency (@MainActor)
