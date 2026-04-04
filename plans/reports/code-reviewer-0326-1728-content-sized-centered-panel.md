# Code Review: Content-Sized + Centered SideWindow Panel

## Scope
- Files: 5 Swift files (3 core: PositionCalculator, SideWindowController, SideWindowView; 2 adjacent: EnvironmentOverrideService, EnvironmentOverridesView)
- LOC changed: ~152 insertions, ~74 deletions
- Focus: recent commit (content-sized panel + env overrides UI refinements)
- Scout: checked SpringAnimator, SideWindowPanel, DesignTokens, all updatePosition callers

## Overall Assessment

Solid implementation. The three-phase plan is well-executed with correct centering math, proper fallback handling, and clean closure-based height change propagation. Build succeeds. No critical issues found.

## Critical Issues

None.

## High Priority

### 1. Layout loop risk with `onGeometryChange` + `updatePosition(animated: true)`

**File:** `SideWindowView.swift:93-97`, `SideWindowController.swift:171-173`

The `onHeightChanged` callback fires on every height change and calls `updatePosition(animated: true)`. The `animated: true` path uses `panel.animator().setFrame()` which triggers AppKit layout, which could invalidate `NSHostingView` layout, which fires `.onGeometryChange` again.

**Current safety:** The plan notes this should be safe because `setFrame` only repositions the window, not the SwiftUI content tree. This is *mostly* correct -- `NSHostingView.intrinsicContentSize` is driven by SwiftUI content, not the window frame. However, if the panel frame change causes the scroll view or any view to resize (e.g., the `ScrollView` adapting to new height), the geometry could change, firing the callback again.

**Risk level:** Low in practice (SwiftUI `onGeometryChange` coalesces), but worth guarding.

**Recommended fix:** Add a debounce or guard against re-entrant calls:

```swift
private var isUpdatingFromHeightChange = false

// In onHeightChanged closure:
onHeightChanged: { [weak self] in
    guard let self, !self.isUpdatingFromHeightChange else { return }
    self.isUpdatingFromHeightChange = true
    self.updatePosition(animated: true)
    DispatchQueue.main.async { self.isUpdatingFromHeightChange = false }
}
```

### 2. `onHeightChanged` fires with ignored value

**File:** `SideWindowView.swift:93-97`

```swift
.onGeometryChange(for: CGFloat.self) { proxy in
    proxy.size.height
} action: { _ in
    onHeightChanged?()
}
```

The height value is captured but discarded (`_`). If you passed the height directly to the controller, you could avoid reading `hostingView.intrinsicContentSize` entirely and eliminate the timing dependency where `intrinsicContentSize` might not yet reflect the new height when `updatePosition` reads it.

**Recommended:** Pass height through the closure:

```swift
var onHeightChanged: ((CGFloat) -> Void)?

// In .onGeometryChange:
action: { newHeight in onHeightChanged?(newHeight) }

// In controller:
private var lastContentHeight: CGFloat = SideWindowMetrics.minHeight
onHeightChanged: { [weak self] height in
    self?.lastContentHeight = height
    self?.updatePosition(animated: true)
}
```

This would be more reliable than reading `intrinsicContentSize` which has a timing dependency with SwiftUI layout.

## Medium Priority

### 3. `centeredY` edge case: panel taller than screen

**File:** `PositionCalculator.swift:51-53`

```swift
private static func centeredY(sim: CGRect, height: CGFloat, screen: CGRect) -> CGFloat {
    let ideal = sim.midY - height / 2
    return max(screen.minY, min(ideal, screen.maxY - height))
}
```

When `height > screen.height`, `screen.maxY - height` is negative relative to `screen.minY`, so `max(screen.minY, negativeValue)` returns `screen.minY`. Panel will overflow bottom of screen. Unlikely with current content (few toggles + slider), but as more sections are added this could happen on a small laptop screen.

**Fix:** Add explicit floor: `return max(screen.minY, min(ideal, screen.maxY - height))` is already correct for the common case. For the overflow case, consider capping `height` to `screen.height` in `panelFrame` before passing to frame helpers.

### 4. Commented-out `.frame` width constraint

**File:** `SideWindowView.swift:89`

```swift
//                .frame(width: SideWindowMetrics.expandedWidth)
```

Commented-out code left in. Either remove it or add a `// TODO:` explaining why it's kept. With `sizingOptions = [.minSize, .intrinsicContentSize]`, the panel width is set by `PositionCalculator` and `setFrame`, so this SwiftUI constraint is correctly unnecessary -- but the comment should be cleaned up.

### 5. `hostingView` stored as `NSView?` -- correct decision, minor documentation gap

**File:** `SideWindowController.swift:21`

Storing as `NSView?` is the right call to avoid generic type-erasure complexity. `intrinsicContentSize` is on `NSView` so it works. Worth a one-line comment explaining the choice for future readers:

```swift
/// Stored as NSView (not NSHostingView<T>) to avoid generic type constraints.
/// intrinsicContentSize is available on NSView.
private var hostingView: NSView?
```

## Low Priority

### 6. `bottomFrame` ignores `contentHeight`

**File:** `PositionCalculator.swift:56-59`

`bottomFrame` hardcodes `200pt` height regardless of `contentHeight`. This is noted as intentional in the plan. Fine for now but creates inconsistency -- when bottom position is used, the panel will not be content-sized.

### 7. Removed sections from SideWindowView

Build Stats and VoiceOver sections were removed from the view (lines 85-92 in the diff). The services (`buildStatsService`, `axInspectorService`) are still injected as `@EnvironmentObject` in SideWindowView (lines 14-15) and still passed in `embedSwiftUIContent`. Dead code -- these environment objects are injected but never consumed in the current view tree.

Not a bug, but adds unused dependencies. Consider removing when confirmed these sections won't return soon.

## Edge Cases Found by Scout

1. **SpringAnimator + content height change interaction:** When `onHeightChanged` fires with `animated: true`, it enters the `panel.animator().setFrame()` path. But the non-animated path (simulator move) goes through `springAnimator.setTarget()`. These two animation systems could conflict if a simulator move and content height change happen simultaneously. The spring targets a frame based on stale content height, then the animated resize sets a different frame, then the spring overwrites it on next CADisplayLink tick.

2. **`currentContentHeight` timing:** `hostingView.intrinsicContentSize` is read synchronously in `updatePosition`, but SwiftUI layout is async. When `onGeometryChange` fires, the hosting view's `intrinsicContentSize` may not yet be updated to match the new SwiftUI geometry. This is the same issue as High Priority #2 above.

3. **Multi-screen:** `centeredY` clamps to `screen.visibleFrame`, which is correct. But if the user moves the simulator from one screen to another while the panel is spring-animating, the screen reference could change mid-animation. The spring would still animate toward the old screen's target until the next `updatePosition` call recomputes.

## Positive Observations

- Clean separation: closure prop instead of environment object for height change notification
- `hostingView` as `NSView?` avoids generics complexity -- pragmatic
- `centeredY` screen clamping prevents off-screen panel
- `bottomFrame` left untouched (correct -- different layout paradigm)
- Plan validation log shows good decision-making process
- `[weak self]` in closure prevents retain cycle
- `setContentSizeIndex` bounds check is clean
- Dynamic type slider with step=1 is the right UX pattern for discrete values

## Recommended Actions

1. **Guard against re-entrant height updates** (High #1) -- add boolean flag or debounce
2. **Pass height through closure** instead of re-reading `intrinsicContentSize` (High #2) -- eliminates timing race
3. **Remove commented-out `.frame`** on line 89 of SideWindowView (Medium #4) -- dead code
4. **Add comment on `hostingView: NSView?`** explaining the type choice (Medium #5) -- one line

## Metrics

- Type Coverage: N/A (no formal TypeScript; Swift 6 strict concurrency provides strong guarantees)
- Test Coverage: 0% (test targets empty -- pre-existing, not introduced by this change)
- Linting Issues: 0 (build succeeds clean)
- Build: PASS

## Plan TODO Completion

All 3 phases marked completed. All TODOs checked. Validation action items on lines 74-76 of plan.md are NOT checked -- these were "action items from validation" but the actual implementation matches them, so they should be checked off.

## Unresolved Questions

1. Should `onHeightChanged` fire during collapse/expand animation too? Currently `.onGeometryChange` will fire during the collapse transition (height changes dramatically). This calls `updatePosition(animated: true)` while `toggleCollapsed()` is already animating. Could cause competing animations.
2. Is the hardcoded `200pt` in `bottomFrame` intentional long-term, or should it also become content-driven eventually?
