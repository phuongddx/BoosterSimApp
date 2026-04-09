# Docs Sync: Side Window Tab-Based UI Refactor

**Date:** 2026-04-08
**Trigger:** Side window refactored from flat VStack to tab-based layout; BoosterHealth companion removed.

## Files Updated

| Doc | Changes |
|---|---|
| `docs/codebase-summary.md` | Removed `SideWindowTitleBar.swift`, `HealthDataService.swift`, `HealthDataSectionView.swift`, entire `BoosterHealth/` dir. Added `SideTab.swift` (27 LOC), `TabBarView.swift` (71 LOC), `tabs/CaptureTabView.swift` (23 LOC), `tabs/DesignTabView.swift` (23 LOC), `tabs/ActionsTabView.swift` (25 LOC), `tabs/NetworkTabView.swift` (28 LOC). Updated `SideWindowView.swift` LOC to 108. Updated project stats (55+ files, ~4,700 LOC, removed HealthKit framework). Reorganized Feature Sections table by tab grouping. Noted 4 unassigned views (StatusBarSectionView, BuildStatsSectionView, AXTreeView, CameraView) that exist on disk but are not wired into any tab yet. |
| `docs/system-architecture.md` | Removed `HealthDataService` from Core Services layer diagram and service descriptions. Removed `BoosterHealth bundled companion` from Key Design Decisions table. Updated Views section: added `SideTab`, `TabBarView`, 4 tab content views; removed `SideWindowTitleBar`, `HealthDataSectionView`. Updated `SideWindowView` description to reflect tab-based layout. |
| `docs/design-guidelines.md` | Replaced `Title bar height: 28pt` with `Tab bar height: 36pt (matches Header height)`. Added Tab Bar component pattern section (icon layout, amber underline, collapse button, animation specs, accessibility). Removed 8 Health-related SF Symbol entries from Key Symbols table. Updated CollapsibleSection "Used by" list to remove `HealthDataSectionView`. |

## Additional Discovery

While verifying the tab refactor, found that BoosterHealth companion app was also deleted from the codebase (not just the side window refactor). Removed all Health-related references from the 3 docs. Other docs still containing stale Health references:
- `docs/deployment-guide.md` (lines 17, 27, 92)
- `docs/code-standards.md` (lines 146-154)
- `docs/project-overview-pdr.md` (lines 29, 55)

## Stale References Remaining (Out of Scope)

The 4 views below exist on disk but are not referenced by any tab view or SideWindowView. They need to be wired into the appropriate tabs or removed:
- `StatusBarSectionView.swift` (129 LOC)
- `BuildStatsSectionView.swift` (92 LOC) + `BuildChartView.swift` (42 LOC)
- `AXTreeView.swift` (141 LOC)
- `CameraView.swift` (99 LOC)

## Unresolved Questions

- Which tab(s) should absorb the 4 unassigned views? Likely candidates: Actions (StatusBar, Camera), Network (none), or new tabs needed?
- Should `DeviceHeaderView` be integrated into the tab bar or displayed above it? Currently not referenced in `SideWindowView` either.
- `docs/deployment-guide.md`, `docs/code-standards.md`, `docs/project-overview-pdr.md` still reference BoosterHealth -- need separate sync pass.
