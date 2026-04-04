# Phase 1: EnvironmentOverrideService Overhaul

**File:** `BoosterSimApp/Services/EnvironmentOverrideService.swift`
**Priority:** High
**Status:** Pending

## Context Links
- Plan: `plans/0325-1657-env-overrides-instant-toggles/plan.md`
- Current service: `BoosterSimApp/Services/EnvironmentOverrideService.swift`
- SimCtlService: `BoosterSimApp/Services/SimCtlService.swift`

## Bugs to Fix

### Bug 1: Wrong domain for Reduce Motion + Bold Text
Current (broken):
```swift
// com.apple.UIKit domain doesn't exist in Simulator → silent failure
simctl spawn booted defaults write com.apple.UIKit UIAccessibilityReduceMotionEnabled -bool YES
simctl spawn booted defaults write -g AccessibilityBoldText -bool YES
```

Fix:
```swift
// com.apple.Accessibility is the correct domain
simctl spawn <udid> defaults write com.apple.Accessibility ReduceMotionEnabled -bool YES
simctl spawn <udid> defaults write com.apple.Accessibility EnhancedTextLegibilityEnabled -bool YES
```

### Bug 2: Hardcoded "booted" ignores udid param
Both `setReduceMotion` and `setBoldText` ignore the passed `udid` parameter.

Fix: replace `"booted"` with `udid` in spawn commands.

### Bug 3: No Darwin notification → changes not live
After writing to defaults, UIKit doesn't update until app restart.

Fix: add second simctl call to post Darwin notification:
```swift
simctl spawn <udid> notifyutil -p com.apple.accessibility.reduce-motion
```

### Bug 4: loadCurrentState only reads appearance
Fix: also read `increase_contrast`, `content_size`, and all accessibility keys from `com.apple.Accessibility` domain.

## New Toggle Pattern

All accessibility toggles (excluding Dark Mode / Dynamic Type / Increase Contrast which use `simctl ui`) follow this two-command pattern:

```swift
private func setAccessibility(key: String, notification: String, enabled: Bool, udid: String) {
    simCtl.runVoid(["spawn", udid, "defaults", "write",
                    "com.apple.Accessibility", key,
                    "-bool", enabled ? "YES" : "NO"])
        .flatMap { [weak self] _ in
            self?.simCtl.runVoid(["spawn", udid, "notifyutil", "-p", notification])
                ?? Empty().eraseToAnyPublisher()
        }
        .sink(receiveCompletion: { _ in }, receiveValue: { _ in })
        .store(in: &cancellables)
}
```

## New @Published Properties to Add

```swift
@Published var reduceTransparency: Bool = false
@Published var grayscale: Bool = false
@Published var invertColors: Bool = false
@Published var buttonShapes: Bool = false
@Published var onOffLabels: Bool = false
@Published var differentiateWithoutColor: Bool = false
```

## Updated loadCurrentState

Read all 8 boolean toggles from `com.apple.Accessibility`:

```swift
func loadCurrentState(udid: String) {
    // Tier 1 — official simctl ui
    simCtl.run(["ui", udid, "appearance"])
        .sink(...) { self.appearance = ... }

    simCtl.run(["ui", udid, "increase_contrast"])
        .sink(...) { self.increaseContrast = $0.contains("enabled") }

    simCtl.run(["ui", udid, "content_size"])
        .sink(...) { /* map to index */ }

    // Tier 2 — com.apple.Accessibility plist
    let a11yKeys: [(String, WritableKeyPath<EnvironmentOverrideService, Bool>)] = [
        ("ReduceMotionEnabled",            \.reduceMotion),
        ("EnhancedTextLegibilityEnabled",  \.boldText),
        ("EnhancedBackgroundContrastEnabled", \.reduceTransparency),
        ("GrayscaleDisplay",               \.grayscale),
        ("InvertColorsEnabled",            \.invertColors),
        ("IncreaseButtonLegibilityEnabled", \.buttonShapes),
        ("OnOffSwitchLabels",              \.onOffLabels),
        ("DifferentiateWithoutColor",      \.differentiateWithoutColor),
    ]
    for (key, path) in a11yKeys {
        simCtl.run(["spawn", udid, "defaults", "read", "com.apple.Accessibility", key])
            .sink(...) { self[keyPath: path] = $0.trimmingCharacters(in: .whitespacesAndNewlines) == "1" }
            .store(in: &cancellables)
    }
}
```

## Public Methods to Add

```swift
func setReduceTransparency(_ enabled: Bool, udid: String)
func setGrayscale(_ enabled: Bool, udid: String)
func setInvertColors(_ enabled: Bool, udid: String)
func setButtonShapes(_ enabled: Bool, udid: String)
func setOnOffLabels(_ enabled: Bool, udid: String)
func setDifferentiateWithoutColor(_ enabled: Bool, udid: String)
```

All call `setAccessibility(key:notification:enabled:udid:)`.

## Remove Tier2Warning System

With correct domain + notification, Reduce Motion and Bold Text now apply without relaunch.
Remove `tier2Warning: String?` property, `runTier2` method, and warning display logic.

If Bold Text proves to still require relaunch in testing (font cache edge case), re-add warning for that toggle only.

## Implementation Steps

1. Add `setAccessibility(key:notification:enabled:udid:)` private method
2. Fix `setReduceMotion` — use `com.apple.Accessibility ReduceMotionEnabled` + notification
3. Fix `setBoldText` — use `com.apple.Accessibility EnhancedTextLegibilityEnabled` + notification
4. Add 6 new `@Published` properties
5. Add 6 new public setter methods (each calls `setAccessibility`)
6. Rewrite `loadCurrentState` to cover all 8 boolean keys
7. Remove `tier2Warning`, `runTier2`
8. Build and verify no compile errors

## Success Criteria

- [ ] All 8 accessibility booleans read correctly from booted Simulator on attach
- [ ] Each toggle applies without app relaunch (test with a running iOS app)
- [ ] No hardcoded "booted" — uses udid parameter throughout
- [ ] File stays under 200 LOC

## Risk

- Bold Text changes font rendering at CTFont cache level; may need app relaunch despite correct notification. Test empirically.
- `notifyutil` available in all Simulator runtimes? Confirmed in iOS 26 (Xcode 16.3). Older runtimes untested.
