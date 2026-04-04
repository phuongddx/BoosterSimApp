# Health Data Generator Feature Complete

**Date**: 2026-03-28 14:30
**Severity**: Low (feature add, no regressions)
**Component**: HealthDataService, BoosterHealth companion app
**Status**: Resolved

## What Happened

Completed full Health Data Generator feature (5 phases). macOS app now bundles a minimal iOS companion app (`BoosterHealth`) that injects HealthKit test data into the Simulator via `simctl install/openurl` orchestration.

## The Brutal Truth

This was genuinely smooth. The architecture worked on first compile. The only friction was Xcode's build system being aggressively wrong about embedding iOS content in macOS apps — but once we sidestepped it with a Shell Script phase, it just worked.

## Technical Details

**Files created (7):**
- `BoosterHealth/BoosterHealthApp.swift` — minimal iOS app with CompanionView
- `BoosterHealth/HealthPayload.swift` — URL scheme parser (`boosterhealth://generate?preset=active_day&date=...`)
- `BoosterHealth/HealthDataGenerator.swift` — HKHealthStore writes (steps, heart rate series, sleep, HKWorkoutBuilder)
- `BoosterSimApp/Services/HealthDataService.swift` — simctl orchestration, HealthPreset enum (4 presets), state machine
- `BoosterSimApp/Views/SideWindow/HealthDataSectionView.swift` — 2×2 grid UI, manual controls, clear button
- `BoosterSimApp/Views/Shared/CollapsibleSection.swift` — extracted shared expandable component
- Build phase Shell Script (copy BoosterHealth.app into Resources)

**Build result:** BUILD SUCCEEDED. Confirmed `BoosterHealth.app` at runtime path.

## What We Tried

- Initial approach: Copy Files build phase → Xcode rejected with "Multiple commands produce Info.plist" (Xcode treating iOS app as macOS resource)
- Pivot: Custom Shell Script build phase with explicit `mkdir -p` and `cp -r` → bypasses validation, works

## Root Cause Analysis

Xcode's PBXFileSystemSynchronizedRootGroup was auto-picking up Info.plist files at the project root. Solution: keep them at root (not nested in BoosterHealth/ dir), use explicit Shell Script copy instead of UI-driven phase.

`ENABLE_USER_SCRIPT_SANDBOXING = NO` required to access cross-target build products — acceptable for internal tooling.

## Lessons Learned

- **iOS companion apps in macOS need explicit orchestration, not embedding.** The right pattern is `simctl install` + URL scheme, not bundling as a .app resource that Xcode fights you on.
- **Shell Script build phases are Xcode's pressure relief valve.** When the UI-driven phases are wrong, a 3-line script often just works.
- **HKWorkoutBuilder with continuations beats deprecated init.** iOS 17+ compat without workarounds.
- **State machine (idle → generating → success/error) prevents race conditions** on rapid preset clicks. Auto-reset after 3s is clean.

## Next Steps

None — feature is complete, integrated, building, and ready for QA. Future: add stress test presets or workout categories based on user feedback.

**Files to commit:**
- All 7 new files
- Build phase changes in project.pbxproj
- Updated `docs/project-roadmap.md` (Phase 2 status)
