---
title: "Phase 4: Cleanup"
description: "Delete SideWindowTitleBar.swift, verify build, final validation"
phase: 4
status: pending
effort: 15m
depends_on: [3]
---

# Phase 4: Cleanup

## Context

- Plan: `plans/0408-2203-side-window-tab-header/plan.md`
- Phase 3 completed: SideWindowView no longer references SideWindowTitleBar

## Overview

Remove the now-unused `SideWindowTitleBar.swift` and do final build verification.

## Files to DELETE

| File | Reason |
|------|--------|
| `BoosterSimApp/Views/SideWindow/SideWindowTitleBar.swift` | Functionality replaced by `TabBarView` (collapse button moved there, app label removed per design) |

## Files NOT deleted

| File | Reason |
|------|--------|
| `DeviceHeaderView.swift` | Kept for future use (multi-device picker may return in a different form) |
| `FeatureSectionView.swift` | Reused in all 4 tab views |
| `FeatureRowView.swift` | Reused by FeatureSectionView |

## Implementation Steps

1. Verify no references to `SideWindowTitleBar` remain in codebase
2. Delete `SideWindowTitleBar.swift`
3. Full clean build: `xcodebuild clean build`
4. Visual verification checklist (manual):
   - [ ] Tab bar shows 4 icons with amber underline on active
   - [ ] Clicking each tab switches content
   - [ ] Collapse button (chevron.left) collapses panel
   - [ ] Expanding shows last-selected tab
   - [ ] Actions tab shows EnvOverrides
   - [ ] Network tab shows Certificates
   - [ ] Capture and Design tabs show "Coming soon" items
   - [ ] Footer visible on all tabs
   - [ ] CollapsedStripView behavior unchanged
   - [ ] No console warnings about missing EnvironmentObjects

## Rollback

If build breaks after deletion:
```bash
git checkout -- BoosterSimApp/Views/SideWindow/SideWindowTitleBar.swift
```

## Success Criteria

- `SideWindowTitleBar.swift` deleted
- Zero build errors
- Zero references to `SideWindowTitleBar` in codebase
- All Phase 3 success criteria still pass
