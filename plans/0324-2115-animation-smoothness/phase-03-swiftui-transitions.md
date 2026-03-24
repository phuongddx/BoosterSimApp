# Phase 3 — SwiftUI Transitions + Spring Polish

<!-- Updated: Validation Session 1 - Merged Phase 3+4 into single phase -->

**Priority:** Medium
**Status:** done
**Files:** `Views/SideWindow/FeatureSectionView.swift`, `Views/SideWindow/SideWindowView.swift`, `Windows/SideWindowController.swift`

## Problem

1. Section expand/collapse and panel collapse/expand use `withAnimation` but no `.transition()` — content pops in/out
2. All animations use `.easeInOut(duration: 0.2)` — mechanical feel; spring physics feel more natural

## Fix — Part A: Add Transitions

### 1. Section content — slide + fade

Add `.transition(.opacity.combined(with: .move(edge: .top)))` to the content block in both `SectionDisclosureStyle` and `CollapsibleSectionWrapper`.

```swift
// Before (FeatureSectionView.swift line 65-67)
if configuration.isExpanded {
    configuration.content
}

// After
if configuration.isExpanded {
    configuration.content
        .transition(.opacity.combined(with: .move(edge: .top)))
}
```

Apply identical change in `CollapsibleSectionWrapper` (SideWindowView.swift line 161).

### 2. Panel collapse/expand — fade both branches

Add `.transition(.opacity)` to both branches of `SideWindowView.body`:

```swift
if controller.isCollapsed {
    CollapsedStripView(onExpand: { controller.toggleCollapsed() })
        .transition(.opacity)
} else {
    VStack(spacing: 0) { ... }
        .transition(.opacity)
}
```

Wrap in `Group { }.animation(.spring(response: 0.3, dampingFraction: 0.8), value: controller.isCollapsed)`.

## Fix — Part B: Spring Animations

Replace `.easeInOut` with `.spring` where interaction is user-initiated.

### Substitution map

| Location | Current | Proposed |
|---|---|---|
| Section header chevron rotation | `.easeInOut(duration: 0.2)` | `.spring(response: 0.3, dampingFraction: 0.75)` |
| Section content reveal (`withAnimation`) | `.easeInOut(duration: 0.2)` | `.spring(response: 0.35, dampingFraction: 0.85)` |
| Panel collapse toggle (SwiftUI) | `.easeInOut(duration: 0.2)` | `.spring(response: 0.3, dampingFraction: 0.8)` |
| Panel collapse toggle (NSPanel frame) | `CAMediaTimingFunction(.easeInEaseOut), 0.2s` | `duration: 0.3` (AppKit doesn't support spring — keep easing, lengthen slightly) |
| `FeatureRowView` tap press | `.easeIn(duration: 0.15)` | `.spring(response: 0.2, dampingFraction: 0.7)` |
| `FeatureRowView` tap release | `.easeOut(duration: 0.2)` | `.spring(response: 0.3, dampingFraction: 0.8)` |
| AXTree node expand | `.easeInOut(duration: 0.15)` | `.spring(response: 0.25, dampingFraction: 0.85)` |

### Respect `reducedMotion`

Add `@Environment(\.accessibilityReduceMotion)` to modified SwiftUI views:

```swift
@Environment(\.accessibilityReduceMotion) var reduceMotion

// Usage:
.animation(reduceMotion ? .linear(duration: 0.1) : .spring(response: 0.3, dampingFraction: 0.8), value: isExpanded)
```

Add to: `SectionDisclosureStyle`, `CollapsibleSectionWrapper`, `FeatureRowView`.

`SideWindowController` already reads `NSWorkspace.shared.accessibilityDisplayShouldReduceMotion` for the NSPanel frame animation — no change needed there.

## Todo

- [x] Add `.transition(.opacity.combined(with: .move(edge: .top)))` to `SectionDisclosureStyle` content
- [x] Add same transition to `CollapsibleSectionWrapper` content
- [x] Add `.transition(.opacity)` to both branches in `SideWindowView` body
- [x] Wrap body branches with `.animation(value: controller.isCollapsed)`
- [x] Replace chevron `.easeInOut` with `.spring` in `SectionDisclosureStyle`
- [x] Replace chevron `.easeInOut` with `.spring` in `CollapsibleSectionWrapper`
- [x] Replace `withAnimation` easing with spring in section button actions
- [x] Replace panel collapse animation with spring in `SideWindowView`
- [x] Update `FeatureRowView` tap animations to spring
- [x] Update `AXTreeView` expand animation to spring
- [x] Lengthen NSPanel frame animation 0.2s -> 0.3s in `SideWindowController`
- [x] Add `@Environment(\.accessibilityReduceMotion)` checks in all modified views
- [x] Build and verify: transitions smooth, springs feel snappy

## Notes

- `.move(edge: .top)` clips content as it appears from under the header — natural for disclosure groups
- Spring `response` = duration feel (lower = faster), `dampingFraction` = bounciness (1.0 = no bounce, 0.6 = bouncy)
- 0.75-0.85 damping = subtle overshoot, natural feel without looking "playful"
- Do NOT apply spring to `NSAnimationContext` frame animation — AppKit animator doesn't support spring
