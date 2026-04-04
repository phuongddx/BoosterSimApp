---
phase: 3
title: Wire SideWindowController — read contentHeight, animate resize
status: completed
priority: high
effort: S
completed: 2026-03-26
---

# Phase 03 — Wire SideWindowController

## Overview

Store the `NSHostingView` reference in `SideWindowController`, read `intrinsicContentSize.height` in `updatePosition`, pass it to `PositionCalculator.panelFrame`. Animate content-driven resizes with `NSAnimationContext`.

## Related Files

- `BoosterSimApp/Windows/SideWindowController.swift`

## Implementation Steps

### 1. Store hosting view reference

In `embedSwiftUIContent`, store the hosting view:

```swift
// Private property (untyped NSView to avoid generic type issues)
private var hostingView: NSView?

private func embedSwiftUIContent(...) {
    let content = SideWindowView(...).environmentObject(...)...
    let hv = NSHostingView(rootView: content)
    hv.sizingOptions = [.minSize, .intrinsicContentSize]
    panel.contentView = hv
    hostingView = hv          // store for intrinsic size reads
}
```

### 2. Add `currentContentHeight` computed property

<!-- Updated: Validation Session 1 - fallback to minHeight when pre-layout (h <= 0) -->

```swift
private var currentContentHeight: CGFloat {
    let h = hostingView?.intrinsicContentSize.height ?? 0
    return h > 0 ? h : SideWindowMetrics.minHeight
}
```

### 3. Pass `contentHeight` to `PositionCalculator`

In `updatePosition`:

```swift
func updatePosition(animated: Bool = false) {
    guard let sim = currentSimulator else { return }
    let screen = PositionCalculator.screen(containing: sim.frame)
    let frame = PositionCalculator.panelFrame(
        simulatorFrame: sim.frame,
        position: settings.position,
        screenFrame: screen.visibleFrame,
        isCollapsed: isCollapsed,
        contentHeight: currentContentHeight   // NEW
    )
    // ... rest unchanged
}
```

### 4. Animate content-driven resize

When SwiftUI content changes height (e.g. tab toggle, section expand), we need to re-call `updatePosition`. The hosting view's `intrinsicContentSize` is invalidated by SwiftUI automatically, but AppKit won't reposition the panel unless we trigger it.

**Strategy:** Observe `objectWillChange` on the services injected into `SideWindowView`. Since those are all `@Published`-based, their changes already flow through the tracker sink. The existing `attach(to:)` triggers `updatePosition` on simulator change, but content-only changes (e.g. tab switch) don't trigger it.

<!-- Updated: Validation Session 1 - use closure prop on SideWindowView, not property on controller -->

**Approach:** Pass `onHeightChanged: (() -> Void)?` into `SideWindowView` at init. No env object, no controller property needed.

```swift
// SideWindowView:
var onHeightChanged: (() -> Void)?

.onGeometryChange(for: CGFloat.self) { proxy in proxy.size.height } action: { _ in
    onHeightChanged?()
}
```

When embedding in `SideWindowController.embedSwiftUIContent`:
```swift
let content = SideWindowView(onHeightChanged: { [weak self] in
    self?.updatePosition(animated: true)
}, ...)
```

> Note: `.onGeometryChange` available macOS 14+. Project targets 15+ — safe to use.

### 5. Animate the resize

`updatePosition(animated: true)` already uses `panel.animator().setFrame(frame, display: true)` — this handles collapse/expand. For content-driven resize, use the same path with a short duration:

```swift
// In updatePosition when animated == true and triggered by content change:
NSAnimationContext.runAnimationGroup { ctx in
    ctx.duration = reducedMotion ? 0 : 0.2
    ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
    panel.animator().setFrame(frame, display: true)
}
```

This is already the existing animated path — no additional changes needed here.

## Todo

- [x] Add `private var hostingView: NSView?` to `SideWindowController`
- [x] In `embedSwiftUIContent`: set `sizingOptions`, store in `hostingView`
- [x] Add `currentContentHeight` computed property
- [x] Update `updatePosition` to pass `contentHeight: currentContentHeight`
- [x] Add `onHeightChanged: (() -> Void)?` param to `SideWindowView` init
- [x] In `SideWindowView`: add `.onGeometryChange` modifier calling `onHeightChanged?()`
- [x] In `embedSwiftUIContent`: pass closure `{ [weak self] in self?.updatePosition(animated: true) }` as `onHeightChanged`
- [x] Build and verify: panel height tracks content, centers on simulator, no layout loop

## Success Criteria

- Panel height = content height (min 400pt floor) at all times
- Panel vertically centered on simulator
- Resize when content changes is animated (0.2s ease-in-out)
- No layout thrash or infinite loop
- Collapse/expand still works as before

## Risk

- **Layout loop:** `onGeometryChange` fires → `updatePosition` → `setFrame` → layout → `onGeometryChange` → ... If `setFrame` doesn't change intrinsic size (it shouldn't — only moves/resizes the window, not the SwiftUI content), this won't loop. Safe.
- **`onGeometryChange` macOS 14+:** Project targets 15+, confirmed safe.
