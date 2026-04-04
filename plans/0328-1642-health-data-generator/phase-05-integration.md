---
phase: 05
title: Integration
status: completed
effort: 2h
---

# Phase 05 — Integration

## Overview

Wire `HealthDataService` into `AppDelegate` → `SideWindowController` → `SideWindowView`. Follows the exact same pattern as every other service (e.g., `CameraService`).

## Files to Modify

1. `BoosterSimApp/App/AppDelegate.swift`
2. `BoosterSimApp/Windows/SideWindowController.swift`
3. `BoosterSimApp/Views/SideWindow/SideWindowView.swift`

---

## 1. AppDelegate.swift

Add `healthDataService` alongside other feature services:

```swift
// Add after cameraService
lazy var healthDataService = HealthDataService(simCtl: simCtlService)
```

Pass to `SideWindowController` init:

```swift
lazy var sideWindowController = SideWindowController(
    settings: settings,
    tracker: tracker,
    statusBarService: statusBarService,
    envOverrideService: envOverrideService,
    buildStatsService: buildStatsService,
    axInspectorService: axInspectorService,
    cameraService: cameraService,
    healthDataService: healthDataService   // ← add
)
```

---

## 2. SideWindowController.swift

Add parameter to `init` and pass to `embedSwiftUIContent`:

```swift
init(
    settings: AppSettings,
    tracker: SimulatorWindowTracker,
    statusBarService: StatusBarService,
    envOverrideService: EnvironmentOverrideService,
    buildStatsService: BuildStatsService,
    axInspectorService: AXInspectorService,
    cameraService: CameraService,
    healthDataService: HealthDataService   // ← add
) {
    // ...existing...
    embedSwiftUIContent(
        tracker: tracker,
        statusBarService: statusBarService,
        envOverrideService: envOverrideService,
        buildStatsService: buildStatsService,
        axInspectorService: axInspectorService,
        cameraService: cameraService,
        healthDataService: healthDataService   // ← add
    )
}
```

In `embedSwiftUIContent`, add `.environmentObject(healthDataService)` to the hosting view chain (find where other `.environmentObject` calls are made and append).

---

## 3. SideWindowView.swift

Add `@EnvironmentObject`:

```swift
@EnvironmentObject var healthDataService: HealthDataService
```

Add section to the expanded `VStack` body, after `EnvironmentOverridesView`:

```swift
HealthDataSectionView(udid: activeUDID ?? "booted")
    .environmentObject(healthDataService)
```

Update the `#Preview` macro:

```swift
let healthService = HealthDataService(simCtl: simCtl)
let controller = SideWindowController(
    // ...existing...
    healthDataService: healthService
)
SideWindowView(tracker: tracker, controller: controller)
    // ...existing environmentObjects...
    .environmentObject(healthService)
```

---

## Build Verification

After integration, run:

```bash
xcodebuild -project BoosterSimApp.xcodeproj \
           -scheme BoosterSimApp \
           -configuration Debug \
           build 2>&1 | grep -E "error:|warning:|BUILD"
```

Expected: `BUILD SUCCEEDED` with no errors.

---

## Success Criteria

- [ ] Project compiles with no errors
- [ ] `HealthDataSectionView` appears in side panel below `EnvironmentOverridesView`
- [ ] Preset buttons trigger install + openurl flow
- [ ] `BoosterHealth.app` present in built `BoosterSimApp.app/Contents/Resources/`
- [ ] On booted Simulator: opening `boosterhealth://generate?preset=active_day&date=2026-03-28` manually via `simctl openurl booted boosterhealth://...` populates Health app
- [ ] State machine: idle → installing → generating → done (auto-reset after 3s)

## Risk: `activeUDID` is nil

If `Screen Recording` permission not granted, `activeUDID` falls back to `"booted"`. `simctl install booted` and `simctl openurl booted` work as long as exactly one Simulator is booted. Handle gracefully — no crash, but instruct user to boot exactly one Simulator.
