# Brainstorm: Health Data Generator Feature

**Date:** 2026-03-28
**Status:** APPROVED

---

## Problem Statement

BoosterSimApp needs to let developers seed the iOS Simulator's Health app with test data. `xcrun simctl` has no health-related commands. HealthKit data can only be written by an iOS app via `HKHealthStore`.

---

## Evaluated Approaches

| Approach | Verdict | Reason |
|---|---|---|
| SimCtlService alone | Rejected | simctl has no health CLI |
| XCTHealthKit (UI tests) | Rejected | Requires Xcode test runner, heavy |
| HealthKitUtility package | Considered | External dep adds risk |
| **Bundled companion iOS app** | **Selected** | Full control, zero runtime deps, works offline |

---

## Agreed Solution: Bundled Companion App

### Architecture

```
BoosterSimApp.app/
  └── Contents/Resources/
        └── BoosterHealth.app   ← iOS companion (Simulator slice)

Flow:
  1. simctl install <udid> BoosterHealth.app
  2. simctl openurl <udid> boosterhealth://generate?data=<base64-json>
  3. Companion parses JSON → HKHealthStore.save()
```

### New Components

**BoosterHealth** (new iOS target, same xcodeproj)
- No visible UI
- URL scheme: `boosterhealth://`
- Requests all HealthKit write permissions on first launch
- `HealthDataGenerator` service processes JSON spec

**HealthDataService.swift** (macOS)
- State machine: `idle → installing → authorizing → generating → done | error`
- Wraps SimCtlService; checks companion install status before reinstalling

**HealthDataView.swift** (SwiftUI)
- Preset buttons: Active Day, Rest Day, Sick Day, 7-Day History
- Manual mode: type selector + value + date
- Progress indicator with status messages

### URL Payload Schema

```json
{
  "preset": "active_day",
  "date": "2026-03-28",
  "days": 1,
  "samples": {
    "steps": 10000,
    "heartRate": { "min": 62, "max": 145, "restingAvg": 68 },
    "sleep": { "bedtime": "23:00", "wakeTime": "07:00" },
    "workout": { "type": "running", "duration": 1800, "calories": 320 }
  }
}
```

### Supported Data Types

- Steps (`stepCount`)
- Heart Rate (`heartRate`, `restingHeartRate`, `heartRateVariabilitySDNN`)
- Blood Oxygen (`oxygenSaturation`)
- Active Energy (`activeEnergyBurned`)
- Distance (`distanceWalkingRunning`)
- Sleep (`sleepAnalysis`)
- Workouts (`HKWorkout` + associated samples)

### Risks

1. **HealthKit auth dialog** — first companion launch shows system sheet; UX must guide user
2. **Companion rebuild dependency** — scheme dependency needed to ensure companion is always up-to-date
3. **Simulator slice only** — companion .app must not include device slice (breaks distribution)
4. **Large dataset latency** — 7-day heart rate = ~2000 samples; needs async progress feedback

---

## Unresolved Questions

1. Should preset scenarios be configurable (user-editable) or fixed?
2. Does the companion app need to show any status back to BoosterSimApp (e.g., success/failure)? If so, how — push notification? simctl log capture?
3. Should "clear all health data" be in scope? (`simctl erase` nukes everything, but targeted delete needs companion too)
