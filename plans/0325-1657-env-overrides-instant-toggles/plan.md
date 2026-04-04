# Plan: Instant Accessibility Toggles (No Relaunch)

**Dir:** `plans/0325-1657-env-overrides-instant-toggles/`
**Branch:** main
**Status:** Complete

## Problem

Current `EnvironmentOverrideService` has 3 critical bugs:
1. Writes to `com.apple.UIKit` domain (doesn't exist → silent failure for Reduce Motion, Bold Text)
2. Wrong key names (`UIAccessibilityReduceMotionEnabled` vs `ReduceMotionEnabled`)
3. No Darwin notification sent after write → changes don't apply without app relaunch

Also missing 6 toggles that RocketSim exposes.

## Root Cause (Empirically Confirmed)

Direct plist inspection of booted Simulator (UDID: 00AFDCEE-858A-4B7D-B5B4-08D3B1D6CAFB):
- All accessibility settings live in `com.apple.Accessibility` domain
- Two-step pattern achieves instant (no-relaunch) updates:
  ```
  xcrun simctl spawn <udid> defaults write com.apple.Accessibility <key> -bool YES
  xcrun simctl spawn <udid> notifyutil -p <darwin-notification>
  ```

## Key Map (Confirmed)

| Toggle | Domain | Key | Darwin Notification |
|---|---|---|---|
| Reduce Motion | `com.apple.Accessibility` | `ReduceMotionEnabled` | `com.apple.accessibility.reduce-motion` |
| Bold Text | `com.apple.Accessibility` | `EnhancedTextLegibilityEnabled` | `com.apple.accessibility.enhanced-text-legibility` |
| Reduce Transparency | `com.apple.Accessibility` | `EnhancedBackgroundContrastEnabled` | `com.apple.accessibility.reduce-transparency` |
| Grayscale | `com.apple.Accessibility` | `GrayscaleDisplay` | `com.apple.accessibility.grayscale` |
| Inverted Colors | `com.apple.Accessibility` | `InvertColorsEnabled` | `com.apple.accessibility.invert-colors` |
| Button Shapes | `com.apple.Accessibility` | `IncreaseButtonLegibilityEnabled` | `com.apple.accessibility.increase-button-legibility` |
| On/Off Labels | `com.apple.Accessibility` | `OnOffSwitchLabels` | `com.apple.accessibility.on-off-switch-labels` |
| Differentiate w/o Color | `com.apple.Accessibility` | `DifferentiateWithoutColor` | `com.apple.accessibility.differentiate-without-color` |

Note: Dark Mode, Increase Contrast, Dynamic Type remain on `xcrun simctl ui` (official, instant).

## Phases

| Phase | File | Status |
|---|---|---|
| 1 | phase-01-service-overhaul.md | Complete |
| 2 | phase-02-ui-expansion.md | Complete |

## Files to Modify

- `BoosterSimApp/Services/EnvironmentOverrideService.swift`
- `BoosterSimApp/Views/SideWindow/EnvironmentOverridesView.swift`
