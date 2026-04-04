# Health Data Generator Feature: Brainstorm & Plan

**Date**: 2026-03-28 14:00
**Severity**: Medium
**Component**: Health Data Generation
**Status**: Planning Complete

## What Happened

Brainstormed and planned a new "Health Data Generator" feature for BoosterSimApp. Discovered that `xcrun simctl` provides zero HealthKit commands—HealthKit data can only be written by an iOS app running inside the Simulator via `HKHealthStore`.

## The Brutal Truth

This kills the idea of a single-file solution. We need to build a *companion iOS app* bundled inside BoosterSimApp itself, then install it onto the Simulator and invoke it via URL scheme. It's heavier than I'd hoped, but it's the only path that works.

## Technical Details

**Root constraint:** `simctl` lacks health commands (verified on Xcode 16).

**Solution:** Minimal iOS app `BoosterHealth` bundled in `BoosterSimApp.app/Contents/Resources/`:
- Install via `simctl install booster-health.app`
- Trigger via URL scheme: `boosterhealth://generate?preset=active_day&date=2026-03-28`
- Writes 9 data types: steps, heart rate, HRV, resting HR, blood oxygen, active energy, distance, sleep, workouts

## Rejected Alternatives

1. **XCTHealthKit** — Requires Xcode test runner; too heavy, wrong tool
2. **HealthKitUtility package** — External dependency; risk we wanted to avoid

## Plan Created

`plans/0328-1642-health-data-generator/plan.md` — 5 phases, 12h total:
1. Xcode target setup (1h)
2. iOS companion: HealthPayload, HealthDataGenerator, BoosterHealthApp (4h)
3. macOS HealthDataService: state machine + simctl wrapper (2h)
4. UI: HealthDataSectionView with preset grid + manual rows (3h)
5. Integration wiring (2h)

## Key Risk

HealthKit auth dialog on first companion launch. Need UX guidance in side panel pre-launch.

## Next Steps

1. Delegate to implementation team (phases 2–5)
2. Define HealthKit prompt UX copy
3. Test companion app install/URL scheme flow
