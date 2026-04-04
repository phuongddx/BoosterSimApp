# Phase 1: Fix setBoldText Key Mapping + Delay

**Priority:** High
**Status:** Pending
**Effort:** ~15 min

## Context

- Research: `plans/reports/researcher-0326-2320-bold-text-override.md`
- File: `BoosterSimApp/Services/EnvironmentOverrideService.swift`
- Method: `setBoldText(_:udid:)` (lines 153–182)

## Key Insight

Bold Text is the only accessibility toggle that requires 3 plist keys across 2 domains. All other toggles use a single key + notification. The Settings.app open/close workaround is also unique to Bold Text (used by RocketSim too).

## Implementation Steps

1. **Add `BoldTextEnabled` write as first step** in the Combine chain:
   ```swift
   simCtl.runVoid(["spawn", udid, "defaults", "write",
                   "com.apple.Accessibility", "BoldTextEnabled",
                   "-bool", enabled ? "YES" : "NO"])
   ```

2. **Chain order after fix:**
   - Step 1: Write `BoldTextEnabled` to `com.apple.Accessibility` (NEW)
   - Step 2: Write `EnhancedTextLegibilityEnabled` to `com.apple.Accessibility` (existing)
   - Step 3: Write `UIAccessibilityBoldTextEnabled` to `.GlobalPreferences` (existing)
   - Step 4: Post `com.apple.accessibility.enhanced-text-legibility` notification (existing)
   - Step 5: Open Settings URL (existing)
   - Step 6: Delay 500ms → terminate Settings (reduce from 1s)

3. **Reduce delay** from `.seconds(1)` to `.milliseconds(500)`

## Code Change

Replace the entire `setBoldText` Combine chain starting at line 156:

```swift
func setBoldText(_ enabled: Bool, udid: String) {
    boldText = enabled
    let value = enabled ? "YES" : "NO"
    // Bold Text requires 3 plist keys across 2 domains + Settings.app workaround
    simCtl.runVoid(["spawn", udid, "defaults", "write",
                    "com.apple.Accessibility", "BoldTextEnabled",
                    "-bool", value])
        .flatMap { [weak self] _ -> AnyPublisher<Void, SimCtlError> in
            guard let self else { return Empty().eraseToAnyPublisher() }
            return self.simCtl.runVoid(["spawn", udid, "defaults", "write",
                                       "com.apple.Accessibility",
                                       "EnhancedTextLegibilityEnabled",
                                       "-bool", value])
        }
        .flatMap { [weak self] _ -> AnyPublisher<Void, SimCtlError> in
            guard let self else { return Empty().eraseToAnyPublisher() }
            return self.simCtl.runVoid(["spawn", udid, "defaults", "write",
                                       ".GlobalPreferences",
                                       "UIAccessibilityBoldTextEnabled",
                                       "-bool", value])
        }
        .flatMap { [weak self] _ -> AnyPublisher<Void, SimCtlError> in
            guard let self else { return Empty().eraseToAnyPublisher() }
            return self.simCtl.runVoid(["spawn", udid, "notifyutil", "-p",
                                       "com.apple.accessibility.enhanced-text-legibility"])
        }
        .flatMap { [weak self] _ -> AnyPublisher<Void, SimCtlError> in
            guard let self else { return Empty().eraseToAnyPublisher() }
            return self.simCtl.runVoid(["openurl", udid,
                                       "App-prefs:ACCESSIBILITY&path=DISPLAY_AND_TEXT"])
        }
        .delay(for: .milliseconds(500), scheduler: DispatchQueue.main)
        .flatMap { [weak self] _ -> AnyPublisher<Void, SimCtlError> in
            guard let self else { return Empty().eraseToAnyPublisher() }
            return self.simCtl.runVoid(["terminate", udid, "com.apple.Preferences"])
        }
        .sink(receiveCompletion: { _ in }, receiveValue: { _ in })
        .store(in: &cancellables)
}
```

## Todo

- [ ] Add `BoldTextEnabled` key write as first step
- [ ] Reduce delay from 1s to 500ms
- [ ] Build & verify compilation
- [ ] Test on booted simulator: toggle Bold Text ON, verify Settings.app shows ON
- [ ] Test toggle Bold Text OFF, verify Settings.app shows OFF

## Risk Assessment

- **Low risk** — additive change, no existing behavior removed
- The `BoldTextEnabled` key is confirmed in researcher report via plist inspection
- 500ms delay confirmed sufficient by researcher (RocketSim uses same timing)
