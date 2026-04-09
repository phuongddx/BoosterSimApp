---
title: "Phase 3: Integrate into SideWindowView"
description: "Wire tab bar + tab content into SideWindowView, remove old flat layout"
phase: 3
status: pending
effort: 30m
depends_on: [1, 2]
---

# Phase 3: Integrate into SideWindowView

## Context

- Plan: `plans/0408-2203-side-window-tab-header/plan.md`
- Phase 1 provides: `SideTab`, `TabBarView`
- Phase 2 provides: `CaptureTabView`, `DesignTabView`, `ActionsTabView`, `NetworkTabView`

## Overview

Rewrite the expanded branch of `SideWindowView.body` to use tab bar + switch-based content instead of flat VStack.

## Current Layout (DELETE from body)

```swift
VStack(spacing: 0) {
    SideWindowTitleBar(onCollapse: { ... })
    DeviceHeaderView(tracker: tracker, selectedIndex: $selectedSimIndex)
    EnvironmentOverridesView(udid: activeUDID)
        .environmentObject(envOverrideService)
    CertificateSectionView(...)
        .environmentObject(certificateService)
    SideWindowFooter()
}
```

## Target Layout

```swift
VStack(spacing: 0) {
    TabBarView(selectedTab: $selectedTab, onCollapse: { controller.toggleCollapsed() })

    switch selectedTab {
    case .capture:
        CaptureTabView(captureItems: captureItems)
    case .design:
        DesignTabView(designItems: designItems)
    case .actions:
        ActionsTabView(actionItems: actionItems, udid: activeUDID)
            .environmentObject(envOverrideService)
    case .network:
        NetworkTabView(
            networkItems: networkItems,
            udidProvider: { selectedSim?.udid },
            deviceNameProvider: { selectedSim?.displayName ?? "Simulator" }
        )
        .environmentObject(certificateService)
    }

    SideWindowFooter()
}
```

## Files to MODIFY

| File | Change |
|------|--------|
| `BoosterSimApp/Views/SideWindow/SideWindowView.swift` | Add `@State private var selectedTab: SideTab = .actions`, replace body expanded branch |

## Changes Detail

### SideWindowView.swift

1. **Add state:** `@State private var selectedTab: SideTab = .actions` (default to Actions since it has the live EnvOverrides)
2. **Remove from body:** `SideWindowTitleBar(...)` call
3. **Remove from body:** `DeviceHeaderView(...)` call
4. **Remove from body:** `EnvironmentOverridesView(...)` call
5. **Remove from body:** `CertificateSectionView(...)` call
6. **Add:** `TabBarView(selectedTab: $selectedTab, onCollapse: { controller.toggleCollapsed() })`
7. **Add:** `switch selectedTab` block with 4 cases
8. **Keep:** `SideWindowFooter()` unchanged
9. **Keep:** `CollapsedStripView` branch unchanged
10. **Keep:** All feature item arrays and computed helpers (used by tab views)
11. **Keep:** `selectedSimIndex` state (still needed for multi-sim in future)
12. **Update preview:** Add `.environmentObject` calls for new tab views

### What stays

- All `@EnvironmentObject` declarations — still needed for forwarding to tab views
- `selectedSimIndex`, `selectedSim`, `activeUDID`, `activePID`, `deviceType` computed props
- All 4 feature item arrays
- `onGeometryChange` and `animation` modifiers
- Preview block

## Implementation Steps

1. Add `@State private var selectedTab: SideTab = .actions` property
2. Replace expanded VStack content: remove old components, add TabBarView + switch
3. Verify EnvironmentObjects propagate to tab content views
4. Build and run

## Todo

- [ ] Add `selectedTab` state
- [ ] Replace expanded layout with tabbed layout
- [ ] Verify EnvironmentObject propagation
- [ ] Build and verify

## Success Criteria

- Tab bar renders at top of expanded panel
- Default tab is Actions (shows EnvironmentOverridesView)
- Switching tabs changes content below tab bar
- Collapse/expand still works
- Footer visible on all tabs
- No EnvironmentObject runtime warnings
- Builds with zero errors
