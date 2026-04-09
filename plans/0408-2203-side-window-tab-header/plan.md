---
title: "Side Window Tab-Based UI"
description: "Replace flat SideWindowView layout with icon tab bar + tab content switching"
status: pending
priority: P1
effort: 3h
branch: main
tags: [ui, side-window, tabs, swiftui]
created: 2026-04-08
---

# Side Window Tab-Based UI

## Overview

Replace the current flat VStack layout (TitleBar -> DeviceHeader -> EnvOverrides -> Certs -> Footer) with a tab-based UI: icon tab bar at top, content switching below, footer unchanged.

## Current State

- `SideWindowView.swift` — flat VStack with 5 sections stacked vertically
- `SideWindowTitleBar.swift` — app label + collapse button (DELETE)
- `DeviceHeaderView.swift` — removed from layout, file kept for future use
- `CollapsedStripView.swift` — 28pt collapsed state (UNCHANGED)

## Target State

- 4 tabs: Capture, Design, Actions, Network — icon-only with amber underline
- Collapse button moves to tab bar trailing edge
- EnvOverridesView moves into Actions tab
- CertificateSectionView moves into Network tab
- All "Coming soon" items use existing FeatureSectionView

## Phases

| # | Phase | Status | Effort | Files |
|---|-------|--------|--------|-------|
| 1 | Create tab model + TabBarView | pending | 45m | `SideTab.swift`, `TabBarView.swift` |
| 2 | Create tab content views | pending | 45m | `tabs/CaptureTabView.swift`, `tabs/DesignTabView.swift`, `tabs/ActionsTabView.swift`, `tabs/NetworkTabView.swift` |
| 3 | Integrate into SideWindowView | pending | 30m | `SideWindowView.swift` |
| 4 | Cleanup | pending | 15m | Delete `SideWindowTitleBar.swift` |

## Dependency Graph

```
Phase 1 (SideTab + TabBarView)
    ↓
Phase 2 (tab content views — parallel, depends on SideTab enum)
    ↓
Phase 3 (SideWindowView integration — depends on Phase 1 + 2)
    ↓
Phase 4 (delete SideWindowTitleBar.swift)
```

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Tab bar height mismatch with existing layout | Low | Medium | Use SideWindowMetrics.headerHeight (36pt) |
| Missing EnvironmentObject in tab views | Medium | High | Pass env objects through from SideWindowView |
| pbxproj not picking up new files | Low | Medium | Project uses folder reference — new files auto-included |
| EnvironmentOverridesView too tall for Actions tab | Medium | Low | ScrollView wraps tab content |

## Rollback

Each phase is self-contained. Revert by restoring SideWindowView.swift from git. Deleted SideWindowTitleBar.swift is in git history.

## Success Criteria

- [ ] 4 icon tabs render in 36pt bar with amber underline on active tab
- [ ] Clicking tabs switches content below
- [ ] Collapse button works from tab bar
- [ ] EnvironmentOverridesView appears in Actions tab only
- [ ] CertificateSectionView appears in Network tab only
- [ ] All "Coming soon" items render via FeatureSectionView
- [ ] CollapsedStripView behavior unchanged
- [ ] Footer unchanged
- [ ] ReduceMotion respected
- [ ] Builds with zero errors
