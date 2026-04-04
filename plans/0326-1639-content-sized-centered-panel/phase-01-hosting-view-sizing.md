---
phase: 1
title: Configure NSHostingView sizingOptions
status: completed
priority: high
effort: XS
completed: 2026-03-26
---

# Phase 01 — Configure NSHostingView sizingOptions

## Overview

Set `sizingOptions` on the `NSHostingView` so AppKit's layout system tracks the SwiftUI content's intrinsic size automatically. This makes `hostingView.intrinsicContentSize` reflect the actual SwiftUI content height on every layout pass.

## Context

- `NSHostingView.sizingOptions` available macOS 13+ (project targets 15+)
- Default `sizingOptions` = `[.minSize, .intrinsicContentSize, .maxSize]` — already tracks intrinsic size
- Setting explicitly to `[.minSize, .intrinsicContentSize]` removes `.maxSize` so the view doesn't impose a maximum constraint (allows panel to shrink freely)
- `intrinsicContentSize` is invalidated automatically when SwiftUI view tree re-renders

## Related Files

- `BoosterSimApp/Windows/SideWindowController.swift` — `embedSwiftUIContent` creates the `NSHostingView`
- `BoosterSimApp/Windows/SideWindowPanel.swift` — panel init (no changes needed here)

## Implementation Steps

1. In `SideWindowController.embedSwiftUIContent`, after creating `NSHostingView`:

```swift
let hostingView = NSHostingView(rootView: content)
// Explicitly configure sizing: track intrinsic content size, allow free shrink
hostingView.sizingOptions = [.minSize, .intrinsicContentSize]
panel.contentView = hostingView
```

2. Store the hosting view reference for later intrinsic size reads:

```swift
// Add to SideWindowController private properties:
private var hostingView: NSHostingView<AnyView>?
```

Or cast `panel.contentView` as `NSHostingView` when needed (simpler, avoids stored property).

**Recommended:** cast at call site — avoids type-erased `AnyView` stored property complexity.

## Todo

- [x] In `embedSwiftUIContent`: create `NSHostingView`, set `sizingOptions = [.minSize, .intrinsicContentSize]`, assign to `panel.contentView`
- [x] Verify `panel.contentView as? NSHostingView<AnyView>` cast is accessible in `updatePosition`

## Success Criteria

- `panel.contentView` is an `NSHostingView` with explicit `sizingOptions`
- Casting `panel.contentView as? NSHostingView<_>` succeeds at runtime
- No compile errors

## Risk

- `NSHostingView` is generic (`NSHostingView<Content: View>`). Casting via `panel.contentView as? NSHostingView<AnyView>` only works if the root view is wrapped in `AnyView`. If not, use `(panel.contentView as? NSHostingView<some View>)` — not valid Swift. **Mitigation:** wrap root view in `AnyView` OR store the hosting view as an `any NSView`-typed property and read `intrinsicContentSize` via protocol extension. Simplest: store as untyped `NSView` and call `intrinsicContentSize` (it's on `NSView`).
