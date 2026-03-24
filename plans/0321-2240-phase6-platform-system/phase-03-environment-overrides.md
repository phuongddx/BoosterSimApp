# Phase 03 — Environment Overrides

**Priority:** P1 | **Status:** Complete | **Effort:** 2h

**Context:** [Plan](./plan.md) | [Phase 01](./phase-01-simctl-service-foundation.md)

## Overview

Appearance and accessibility overrides via `xcrun simctl ui`. Tier 1 (documented simctl commands) + Tier 2 (undocumented `simctl spawn defaults write`). All changes apply immediately to the active simulator.

## Key Insights

**Tier 1 — `simctl ui` (safe, documented, verified):**
```
xcrun simctl ui <udid> appearance [light|dark]
xcrun simctl ui <udid> increase_contrast [enabled|disabled]
xcrun simctl ui <udid> content_size [extra-small|small|medium|large|extra-large|extra-extra-large|extra-extra-extra-large|increment|decrement|accessibility-*]
```

**Tier 2 — `simctl spawn` (undocumented, use with graceful failure):**
```
xcrun simctl spawn booted defaults write com.apple.UIKit UIAccessibilityReduceMotionEnabled -bool YES/NO
xcrun simctl spawn booted defaults write -g AccessibilityBoldText -bool YES/NO
```
- These write into the simulator's user defaults; changes may need app relaunch
- Wrap in try/catch; on failure: show warning badge in UI, do not crash

**Dynamic Type sizes** (11 valid values):
`extra-small | small | medium | large | extra-large | extra-extra-large | extra-extra-extra-large | accessibility-medium | accessibility-large | accessibility-extra-large | accessibility-extra-extra-large | accessibility-extra-extra-extra-large`

## Requirements

- Dark/Light mode toggle (instant, reliable)
- Increase Contrast toggle
- Dynamic Type stepper (increment / decrement, show current level name)
- Reduce Motion toggle (Tier 2 — shows "may require app relaunch" tooltip)
- Bold Text toggle (Tier 2 — same caveat)
- Disable all controls when no active simulator
- Read current state: `xcrun simctl ui <udid> appearance` (returns "light" or "dark")

## Architecture

```
EnvironmentOverrideService   — wraps simctl ui calls + state reading
EnvironmentOverridesView     — toggle grid + Dynamic Type stepper
```

```swift
@MainActor final class EnvironmentOverrideService: ObservableObject {
    @Published var appearance: AppearanceStyle = .light   // .light | .dark | .unknown
    @Published var increaseContrast: Bool = false
    @Published var reduceMotion: Bool = false
    @Published var boldText: Bool = false
    @Published var contentSizeCategory: String = "large"
    @Published var tier2Warning: String? = nil  // shown if spawn command fails

    private let simCtl: SimCtlService

    func loadCurrentState(udid: String)
    func setAppearance(_ style: AppearanceStyle, udid: String)
    func setIncreaseContrast(_ enabled: Bool, udid: String)
    func setContentSize(_ size: String, udid: String)
    func incrementContentSize(udid: String)
    func decrementContentSize(udid: String)
    func setReduceMotion(_ enabled: Bool, udid: String)   // Tier 2
    func setBoldText(_ enabled: Bool, udid: String)       // Tier 2
}
```

**Dynamic Type order** (for stepper navigation):
```swift
static let contentSizeSizes = [
    "extra-small", "small", "medium", "large", "extra-large",
    "extra-extra-large", "extra-extra-extra-large",
    "accessibility-medium", "accessibility-large",
    "accessibility-extra-large", "accessibility-extra-extra-large",
    "accessibility-extra-extra-extra-large"
]
```

## Related Code Files

| File | Action | Description |
|------|--------|-------------|
| `Services/EnvironmentOverrideService.swift` | Create | All override logic (~100 LOC) |
| `Views/SideWindow/EnvironmentOverridesView.swift` | Create | Toggle grid + stepper (~100 LOC) |
| `App/AppDelegate.swift` | Modify | Own `EnvironmentOverrideService` |
| `Views/SideWindow/SideWindowView.swift` | Modify | Wire env overrides section |

## Implementation Steps

1. Define `AppearanceStyle` enum (light, dark, unknown) in `EnvironmentOverrideService.swift`
2. Implement `loadCurrentState(udid:)` — runs `simctl ui <udid> appearance`, parses "light"/"dark"
3. Implement `setAppearance` → `simCtl.runVoid(["ui", udid, "appearance", style.rawValue])`
4. Implement `setIncreaseContrast` → `simCtl.runVoid(["ui", udid, "increase_contrast", enabled ? "enabled" : "disabled"])`
5. Implement `incrementContentSize` / `decrementContentSize` using index in `contentSizeSizes` array
6. Implement `setReduceMotion` (Tier 2): run `simctl spawn booted defaults write ...`, catch failure → set `tier2Warning`
7. Implement `setBoldText` (Tier 2): same pattern as reduce motion
8. Create `EnvironmentOverridesView.swift`:
   - `Toggle("Dark Mode", isOn: binding)` → calls `setAppearance`
   - `Toggle("Increase Contrast", isOn: binding)`
   - `Stepper("Dynamic Type: \(currentSize)", ...)` — increment/decrement
   - `Toggle("Reduce Motion", isOn: binding)` with ⚠️ badge if Tier 2 unavailable
   - `Toggle("Bold Text", isOn: binding)` with ⚠️ badge
9. Call `loadCurrentState` when active simulator changes (observe `tracker.$activeSimulator`)
10. Wire into `AppDelegate` and `SideWindowView`
11. Build + test

## Todo

- [x] Create `EnvironmentOverrideService.swift`
- [x] Implement Tier 1: appearance, contrast, content size
- [x] Implement Tier 2: reduce motion, bold text (with graceful fallback)
- [x] `loadCurrentState` reads appearance from simctl
- [x] Create `EnvironmentOverridesView.swift` — toggles + stepper
- [x] Wire ⚠️ badge for Tier 2 failure
- [x] Wire into `AppDelegate` + `SideWindowView`
- [x] Build + manual test each toggle

## Success Criteria

- Dark/light toggle applies immediately (visible in Simulator)
- Dynamic Type stepper correctly increments/decrements through all 12 sizes
- Tier 2 failures show warning, don't crash
- Both files under 110 LOC

## Risk Assessment

| Risk | Mitigation |
|------|-----------|
| `simctl ui appearance` output format changes | Parse with `.trimmingCharacters` + lowercased match |
| Tier 2 `spawn defaults write` fails silently | Check exit code, set `tier2Warning` on failure |
| Content size reading not supported by simctl | Skip `loadCurrentState` for content size; default to "large" |
