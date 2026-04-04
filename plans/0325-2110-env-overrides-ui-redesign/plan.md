# Plan: Environment Overrides UI Redesign

**Dir:** `plans/0325-2110-env-overrides-ui-redesign/`
**Branch:** main
**Status:** Ready

## Goal

Redesign `EnvironmentOverridesView` to match the RocketSim reference (accessibility-tab.png):
- Toggle switches (SwiftUI `Toggle`) instead of checkmark button indicator pattern
- Three section headers: Accessibility, Appearance, Dynamic Type
- Dynamic Type slider (A–A) instead of +/- stepper
- Reorganized row order matching the reference

## Reference

`accessibility-tab.png` — RocketSim side panel accessibility tab.

## What's Already Done

`plans/0325-1657-env-overrides-instant-toggles/` — service layer + all 11 toggles wired.
No service changes needed except one addition (see Phase 1).

## Phases

| Phase | File | Status |
|---|---|---|
| 1 | phase-01-ui-redesign.md | Pending |

## Files to Modify

- `BoosterSimApp/Views/SideWindow/EnvironmentOverridesView.swift`
- `BoosterSimApp/Services/EnvironmentOverrideService.swift` (add `setContentSizeIndex`)
