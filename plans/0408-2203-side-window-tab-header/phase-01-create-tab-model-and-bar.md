---
title: "Phase 1: Create Tab Model + TabBarView"
description: "Define SideTab enum and build icon-only tab bar with amber underline + collapse button"
phase: 1
status: pending
effort: 45m
---

# Phase 1: Create Tab Model + TabBarView

## Context

- Plan: `plans/0408-2203-side-window-tab-header/plan.md`
- Design tokens: `Utilities/DesignTokens.swift` — use `Spacing`, `SideWindowMetrics`
- Existing collapse logic: `SideWindowController.toggleCollapsed()`

## Overview

Create the tab enum model and the visual tab bar. These are foundational — Phase 2 and 3 depend on them.

## Requirements

### SideTab enum (~15 lines)

**File:** `BoosterSimApp/Views/SideWindow/SideTab.swift`

```
enum SideTab: String, CaseIterable {
    case capture, design, actions, network

    var icon: String    // SF Symbol name (filled variant)
    var label: String   // Human-readable, used for accessibility
}
```

- `capture` → `camera.fill`, "Capture"
- `design` → `paintbrush.fill`, "Design"
- `actions` → `bolt.fill`, "Actions"
- `network` → `globe`, "Network"

### TabBarView (~60 lines)

**File:** `BoosterSimApp/Views/SideWindow/TabBarView.swift`

Layout:
```
[camera.fill] [paintbrush.fill] [bolt.fill] [globe]     [chevron.left]
 ←────── equal width tabs ──────────────────→             ← collapse
```

- Height: `SideWindowMetrics.headerHeight` (36pt)
- Background: `.bar`
- Bottom border: `Divider()` overlay
- Tab buttons: icon-only, `.imageScale(.small)`, foreground `.secondary` (inactive) / `.accent` (active)
- Active indicator: 2pt `Color.accentColor` bar below active tab, width = icon frame (~24pt)
- Collapse button: `chevron.left`, trailing edge, `.secondary`, `.buttonStyle(.plain)`
- Accessibility: each button gets `.accessibilityLabel(tab.label)`
- `reduceMotion`: indicator transition uses `.linear(duration: 0.1)` when true, `.spring(response: 0.2)` otherwise

Signature:
```swift
struct TabBarView: View {
    @Binding var selectedTab: SideTab
    let onCollapse: () -> Void
    @Environment(\.accessibilityReduceMotion) var reduceMotion
}
```

## Files to CREATE

| File | LOC |
|------|-----|
| `BoosterSimApp/Views/SideWindow/SideTab.swift` | ~15 |
| `BoosterSimApp/Views/SideWindow/TabBarView.swift` | ~60 |

## Files to READ for context

- `BoosterSimApp/Utilities/DesignTokens.swift` — spacing/metrics constants
- `BoosterSimApp/Views/SideWindow/SideWindowTitleBar.swift` — collapse button pattern to replicate

## Implementation Steps

1. Create `SideTab.swift` with enum, 4 cases, `icon` and `label` computed properties
2. Create `TabBarView.swift` with HStack layout:
   - `ForEach(SideTab.allCases)` to render tab buttons
   - Each button: `Image(systemName: tab.icon)`, foreground based on `tab == selectedTab`
   - Active indicator: `Rectangle().fill(Color.accentColor).frame(height: 2)` positioned below active tab using `overlay(alignment: .bottom)`
   - Trailing `Spacer()` + collapse `Button`
3. Apply `.accessibilityLabel` to all buttons
4. Add `#Preview` block

## Todo

- [ ] Create `SideTab.swift`
- [ ] Create `TabBarView.swift`
- [ ] Verify builds with `xcodebuild`

## Success Criteria

- `SideTab.allCases.count == 4`
- `TabBarView` renders 4 icon buttons + collapse button in 36pt bar
- Active tab shows amber underline
- Builds with zero errors
