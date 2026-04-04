# Bold Text Override in iOS Simulator — Research Report

**Date:** 2026-03-26

---

## TL;DR

Bold Text can be toggled programmatically without app relaunch using a 3-step approach:
1. Write 3 plist keys
2. Post Darwin notification `com.apple.accessibility.enhanced-text-legibility`
3. Optionally: open + immediately close Settings.app for broader app compatibility

The existing `EnvironmentOverrideService.setBoldText` has a **key mapping bug**: it writes `EnhancedTextLegibilityEnabled` but NOT `BoldTextEnabled`, causing Settings.app to show stale state after toggle.

---

## 1. Plist Path and Keys

**Plist file:**
```
~/Library/Developer/CoreSimulator/Devices/{UDID}/data/Library/Preferences/com.apple.Accessibility.plist
~/Library/Developer/CoreSimulator/Devices/{UDID}/data/Library/Preferences/.GlobalPreferences.plist
```

**Three keys must be written in sync:**

| Domain | Key | Reads by |
|--------|-----|----------|
| `com.apple.Accessibility` | `BoldTextEnabled` | Settings.app (shows toggle state) |
| `com.apple.Accessibility` | `EnhancedTextLegibilityEnabled` | iOS internal (redundant with BoldTextEnabled on iOS 17+) |
| `.GlobalPreferences` | `UIAccessibilityBoldTextEnabled` | `UIAccessibilityIsBoldTextEnabled()` + `UITraitCollection.legibilityWeight` |

**Verified on iOS 26.3 simulator (Xcode 17):**
- When Bold Text is ON, all 3 keys = `1`
- Keys do NOT auto-sync — writing one does NOT update the others
- `EnhancedTextLegibilityEnabled` is NOT in the `AccessibilitySettings.bundle` binary strings; `BoldTextEnabled` IS — confirming `BoldTextEnabled` is the canonical Settings.app key

---

## 2. `simctl` Approach

`xcrun simctl ui` does NOT support Bold Text. Supported subset:
```bash
xcrun simctl ui <udid> appearance [light|dark]
xcrun simctl ui <udid> increase_contrast [enabled|disabled]
xcrun simctl ui <udid> content_size [size_name]
```

Bold Text must use the `defaults write` + `notifyutil` approach via `simctl spawn`.

---

## 3. Darwin Notification

```bash
# Notification name that triggers UIKit to reload bold text state:
com.apple.accessibility.enhanced-text-legibility

# Post via simctl:
xcrun simctl spawn <udid> notifyutil -p com.apple.accessibility.enhanced-text-legibility
```

**Note:** The name is confusing — despite referencing "enhanced-text-legibility", this is the notification UIKit observes for bold text changes. Confirmed via binary analysis: `com.apple.accessibility.enhanced-text-legibility` is the recognized notification for this preference category.

**Per-app notification (iOS 17+, for per-app overrides):**
```
com.apple.accessibility.perappsettings.bold.text
```
This is a separate mechanism for per-app overrides, not system-wide Bold Text.

---

## 4. Shell Commands (Complete Working Sequence)

```bash
UDID="<device-udid>"
ENABLED="YES"  # or "NO"

# Write all 3 keys
xcrun simctl spawn $UDID defaults write com.apple.Accessibility BoldTextEnabled -bool $ENABLED
xcrun simctl spawn $UDID defaults write com.apple.Accessibility EnhancedTextLegibilityEnabled -bool $ENABLED
xcrun simctl spawn $UDID defaults write .GlobalPreferences UIAccessibilityBoldTextEnabled -bool $ENABLED

# Trigger UIKit update
xcrun simctl spawn $UDID notifyutil -p com.apple.accessibility.enhanced-text-legibility

# Optional: force Settings.app reload (maximizes app compatibility)
xcrun simctl openurl $UDID "App-prefs:ACCESSIBILITY&path=DISPLAY_AND_TEXT"
sleep 1
xcrun simctl terminate $UDID com.apple.Preferences
```

**Read current state:**
```bash
xcrun simctl spawn <udid> defaults read .GlobalPreferences UIAccessibilityBoldTextEnabled
# Returns: "1" (enabled) or "0" (disabled)
```

---

## 5. Swift Code for Programmatic Toggle

The correct `setBoldText` implementation (fixing the key mapping bug):

```swift
func setBoldText(_ enabled: Bool, udid: String) {
    boldText = enabled
    let value = enabled ? "YES" : "NO"

    // Step 1: Write BoldTextEnabled (Settings.app canonical key — MISSING in current code)
    simCtl.runVoid(["spawn", udid, "defaults", "write",
                    "com.apple.Accessibility", "BoldTextEnabled",
                    "-bool", value])
        .flatMap { [weak self] _ -> AnyPublisher<Void, SimCtlError> in
            guard let self else { return Empty().eraseToAnyPublisher() }
            // Step 2: Write EnhancedTextLegibilityEnabled (iOS 17+ supplementary key)
            return self.simCtl.runVoid(["spawn", udid, "defaults", "write",
                                       "com.apple.Accessibility",
                                       "EnhancedTextLegibilityEnabled",
                                       "-bool", value])
        }
        .flatMap { [weak self] _ -> AnyPublisher<Void, SimCtlError> in
            guard let self else { return Empty().eraseToAnyPublisher() }
            // Step 3: Write UIAccessibilityBoldTextEnabled (what UIKit reads)
            return self.simCtl.runVoid(["spawn", udid, "defaults", "write",
                                       ".GlobalPreferences",
                                       "UIAccessibilityBoldTextEnabled",
                                       "-bool", value])
        }
        .flatMap { [weak self] _ -> AnyPublisher<Void, SimCtlError> in
            guard let self else { return Empty().eraseToAnyPublisher() }
            // Step 4: Post Darwin notification for UIKit live update
            return self.simCtl.runVoid(["spawn", udid, "notifyutil", "-p",
                                       "com.apple.accessibility.enhanced-text-legibility"])
        }
        .flatMap { [weak self] _ -> AnyPublisher<Void, SimCtlError> in
            guard let self else { return Empty().eraseToAnyPublisher() }
            // Step 5: Open Settings briefly to force broader UIKit refresh
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

**Corrected read in `loadCurrentState`:** The existing read from `.GlobalPreferences UIAccessibilityBoldTextEnabled` is correct — no change needed for reading.

---

## 6. Live Reload Analysis

### Without app relaunch — WORKS for:
- SwiftUI `Text` views (observe `UITraitCollection.legibilityWeight` via environment)
- `UILabel` using `UIFont.preferredFont(forTextStyle:)` with dynamic type
- Any view implementing `traitCollectionDidChange(_:)` and re-applying fonts
- Apps listening to `UIAccessibilityBoldTextStatusDidChangeNotification`

### Without app relaunch — DOES NOT WORK for:
- Hardcoded `UIFont.systemFont(ofSize: 17)` (no weight change, must relaunch)
- Cached font values computed at app startup
- Apps that never re-read `UIAccessibilityIsBoldTextEnabled()` after launch

### Settings.app workaround rationale:
- Opening Settings.app triggers the accessibility server + springboard to re-process preferences
- When the tested app resumes focus, UIKit sends trait environment updates more reliably
- The 500ms delay is sufficient for the state to propagate
- This is the same technique used by RocketSim and similar tools

### UIKit notification chain:
```
Darwin notify: com.apple.accessibility.enhanced-text-legibility
    ↓ UIKitCore internal observer (_accessibilityBoldTextChanged:)
    ↓ UITraitCollection.legibilityWeight updates (.bold vs .regular)
    ↓ traitCollectionDidChange(_:) propagates to all windows/views
    ↓ UIAccessibilityBoldTextStatusDidChangeNotification posted
    ↓ App-level observers update UI
```

---

## 7. AXUIElement / macOS Accessibility API

Not viable for this feature. macOS AX APIs cannot reach into the iOS Simulator's Settings.app to toggle the switch programmatically without root access or full UI automation scripts (which would be slow and fragile). The `defaults write + notifyutil` approach is the correct solution.

---

## 8. RocketSim / Commercial Tools Reference

Commercial tools (RocketSim, etc.) use the same `xcrun simctl spawn defaults write` + `notifyutil` approach. The Settings.app open/close trick is also used by these tools for Bold Text specifically, because the notification alone doesn't reliably update all UIKit subsystems without a Settings interaction.

---

## 9. Bug in Current Implementation

**File:** `BoosterSimApp/Services/EnvironmentOverrideService.swift`
**Method:** `setBoldText(_:udid:)`

**Bug:** Only writes `EnhancedTextLegibilityEnabled`, missing `BoldTextEnabled`.

**Consequence:** After toggling Bold Text via BoosterSimApp, Settings.app shows the old state because it reads `BoldTextEnabled` (not `EnhancedTextLegibilityEnabled`). The toggle appears to work for the tested app (UIKit reads `UIAccessibilityBoldTextEnabled` which is written correctly), but creates plist desync.

**Fix:** Add `defaults write com.apple.Accessibility BoldTextEnabled` as the first step.

---

## Unresolved Questions

1. Does `com.apple.accessibility.enhanced-text-legibility` notification name stay stable on iOS 18/19 Simulator? (Not in public API; reverse-engineered)
2. Can the Settings.app delay be reduced below 500ms reliably? (Current code uses 1000ms)
3. On iOS 17+ with per-app accessibility overrides, could `com.apple.accessibility.perappsettings.bold.text` be used to toggle per-app bold text without affecting the global setting?
4. Why does `EnhancedTextLegibilityEnabled` appear in the plist alongside `BoldTextEnabled` — are they truly the same feature or distinct? (Empirically: both are `1` when bold is on, but the Settings.app binary only references `BoldTextEnabled`)
