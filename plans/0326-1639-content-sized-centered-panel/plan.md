---
title: Content-Sized + Centered SideWindow Panel
status: completed
created: 2026-03-26
completed: 2026-03-26
---

# Content-Sized + Centered SideWindow Panel

## Problem

SideWindowPanel height is currently `max(simulatorFrame.height, 400pt)` — it always stretches to match the simulator. Y origin is `sim.minY` (top-aligned to simulator bottom edge in AppKit coords). This wastes vertical space and looks disconnected from the panel's actual content.

## Goal

- Panel height = SwiftUI content intrinsic height (floor: `SideWindowMetrics.minHeight`)
- Panel vertically centered alongside the simulator window
- Animate content-driven resize to avoid jarring jumps

## Approach

Use `NSHostingView.sizingOptions = [.minSize, .intrinsicContentSize]` (macOS 13+, project targets 15+). Read `hostingView.intrinsicContentSize.height` in `SideWindowController.updatePosition()` and pass as `contentHeight` to `PositionCalculator.panelFrame`. Centering: `y = sim.midY - contentHeight/2`, clamped to screen.

## Phases

| # | Phase | Status | File |
|---|-------|--------|------|
| 1 | Configure NSHostingView sizingOptions | completed | [phase-01-hosting-view-sizing.md](phase-01-hosting-view-sizing.md) |
| 2 | Update PositionCalculator for content height + centering | completed | [phase-02-position-calculator.md](phase-02-position-calculator.md) |
| 3 | Wire SideWindowController | completed | [phase-03-controller-wiring.md](phase-03-controller-wiring.md) |

## Files Modified

- `BoosterSimApp/Windows/SideWindowPanel.swift`
- `BoosterSimApp/Windows/SideWindowController.swift`
- `BoosterSimApp/Windows/PositionCalculator.swift`

## Validation Log

### Session 1 — 2026-03-26
**Trigger:** Pre-implementation validation
**Questions asked:** 4

#### Questions & Answers

1. **[Architecture]** Phase 3 uses `.onGeometryChange` on SideWindowView to call `controller.onContentHeightChanged?()`. How should SideWindowView access SideWindowController?
   - Options: Closure prop on SideWindowView | @EnvironmentObject | NotificationCenter
   - **Answer:** Closure prop on SideWindowView
   - **Rationale:** No new env object needed; `onHeightChanged: (() -> Void)?` passed at init. Clean separation.

2. **[Assumptions]** When `isCollapsed = true`, should content-height logic still apply?
   - Options: Skip content height when collapsed | Always use content height
   - **Answer:** Always use content height
   - **Custom input:** "isCollapsed, remove it"
   - **Rationale:** `isCollapsed` only affects width. Height is always content-driven. Simplifies PositionCalculator — no guard needed.

3. **[Risks]** `hostingView?.intrinsicContentSize.height` may return 0/-1 before first SwiftUI layout. Fallback?
   - Options: Fall back to minHeight | Fall back to simulator height
   - **Answer:** Fall back to minHeight (400pt)
   - **Rationale:** `h > 0 ? h : SideWindowMetrics.minHeight` — panel shows at floor until content renders.

4. **[Tradeoffs]** Should content-driven resizes animate?
   - Options: Always animate | Instant for content
   - **Answer:** Always animate (0.2s ease-in-out)
   - **Rationale:** Consistent animation across all resize triggers. Same `NSAnimationContext` path as collapse.

#### Confirmed Decisions
- Controller access: closure prop `onHeightChanged: (() -> Void)?` on SideWindowView — no env object
- `isCollapsed` removed from height calc — only affects width
- Pre-layout fallback: `SideWindowMetrics.minHeight`
- Animation: always 0.2s ease-in-out for content-driven resize

#### Action Items
- [ ] Phase 2: Remove `isCollapsed` guard from `panelHeight` — already correct in pseudocode, add explicit note
- [ ] Phase 3: Replace `onContentHeightChanged` on controller with `onHeightChanged` closure prop on `SideWindowView`
- [ ] Phase 3: Update `currentContentHeight` to `h > 0 ? h : SideWindowMetrics.minHeight`

#### Impact on Phases
- Phase 2: `isCollapsed` still in signature for width only — clarify in Implementation Steps
- Phase 3: `SideWindowView` init gets `onHeightChanged` param; controller no longer needs `onContentHeightChanged` property
