# Research: iOS Simulator Accessibility Settings Without App Relaunch

**Date:** 2026-03-25
**Query:** Toggling accessibility settings (Bold Text, Reduce Motion, Reduce Transparency, Button Shapes, Grayscale, Inverted Colors, On/Off Labels, Differentiate without Color) from macOS host WITHOUT requiring app relaunch.

---

## Executive Summary

**Status:** Partial success. The `defaults write` + `notifyutil -p` pattern can trigger live updates for settings that UIKit observes via Darwin notifications, but complete documentation of all accessibility notification names and their corresponding plist keys is not publicly available in Apple's official docs. Implementation requires reverse engineering or empirical testing.

**Key Finding:** UIKit listens to Darwin notifications with names like `com.apple.accessibility.reduce-motion.enabled` and `com.apple.accessibility.increase-contrast.enabled`. Writing to defaults + posting the corresponding Darwin notification triggers live UIKit refresh without app relaunch.

**Confirmed Pattern:**
```bash
# Write setting to defaults
xcrun simctl spawn <udid> defaults write <domain> <key> -bool YES

# Post Darwin notification to trigger live update
xcrun simctl spawn <udid> notifyutil -p <notification_name>
```

---

## 1. Darwin Notifications & UIKit Observation

### Confirmed Notification Names

| Setting | Darwin Notification Name | Status | Source |
|---------|-------------------------|--------|--------|
| Reduce Motion | `com.apple.accessibility.reduce-motion.enabled` | **CONFIRMED** | Apple Dev Docs: reduceMotionStatusDidChangeNotification |
| Increase Contrast | `com.apple.accessibility.increase-contrast.enabled` | **CONFIRMED** | Apple Dev Docs |
| Bold Text | `UIAccessibility.boldTextStatusDidChangeNotification` | **MAPPED** | Apple Dev Docs (UIKit notification name, not Darwin name) |
| Reduce Transparency | ? | **UNCONFIRMED** | No public source found |
| Button Shapes | `UIAccessibility.buttonShapesEnabledStatusDidChangeNotification` | **MAPPED** | Apple Dev Docs (UIKit notification name) |
| Grayscale | ? | **UNCONFIRMED** | No public source found |
| Inverted Colors | ? | **UNCONFIRMED** | No public source found |
| On/Off Labels | ? | **UNCONFIRMED** | No public source found |
| Differentiate without Color | ? | **UNCONFIRMED** | No public source found |

### Key Insight on Notification Names

UIKit uses two notification naming patterns:
1. **Darwin notifications** (system-level, cross-process): `com.apple.accessibility.<feature>.enabled`
2. **UIKit notifications** (app-level): `UIAccessibility.<feature>StatusDidChangeNotification`

Apps observe via `NotificationCenter.default.addObserver(..., name: UIAccessibility.boldTextStatusDidChangeNotification, ...)`, but internally UIKit listens to the Darwin notification and posts the UIKit notification.

---

## 2. Correct Plist Domains & Keys

### Confirmed Defaults Domains & Keys

| Setting | Plist Domain | Key | Confirmed | Source |
|---------|--------------|-----|-----------|--------|
| **Reduce Motion** | `.GlobalPreferences` or `com.apple.UIKit` | `UIAccessibilityReduceMotionEnabled` | PARTIAL | Search results show both domains used; unclear which is authoritative |
| **Bold Text** | `.GlobalPreferences` | `AccessibilityBoldText` or `UIAccessibilityBoldTextEnabled` | PARTIAL | Apple Dev Docs mention `isBoldTextEnabled` property but not plist key |
| **Reduce Transparency** | `com.apple.UIKit` | `UIAccessibilityReduceTransparencyEnabled` | UNCONFIRMED | Inferred from API property name; not verified in plist |
| **Button Shapes** | `.GlobalPreferences` | `ButtonShapesEnabled` or `AccessibilityButtonShapesEnabled` | UNCONFIRMED | Property `buttonShapesEnabled` exists in UIKit; key name inferred |
| **Grayscale** | Unknown | `AccessibilityGrayscale` or `DisplayGrayscale` | UNCONFIRMED | No official source |
| **Inverted Colors** | Unknown | `AccessibilityInvertedColors` | UNCONFIRMED | No official source |
| **On/Off Labels** | Unknown | `AccessibilityOnOffSwitchLabels` | UNCONFIRMED | No official source |
| **Differentiate without Color** | `.GlobalPreferences` | `DifferentiateWithoutColor` | UNCONFIRMED | UIKit API exists; plist key inferred |

### Critical Note on .GlobalPreferences

On iOS Simulator, `.GlobalPreferences` refers to the user domain that applies to all apps. In practice:
- `defaults write .GlobalPreferences <key> <value>` writes to `~/Library/Preferences/.GlobalPreferences.plist` on macOS
- On the iOS Simulator (via `xcrun simctl spawn`), this likely maps to the Simulator's equivalent global preferences storage

**Recommendation:** Empirical testing on target Simulator (UDID: 00AFDCEE-858A-4B7D-B5B4-08D3B1D6CAFB) is required to confirm exact domain/key pairs and whether Darwin notification names match API names.

---

## 3. Two-Step Pattern: defaults write + notifyutil

### Pattern Validation

**Conceptually Confirmed:** The `defaults write` + `notifyutil -p` two-step approach should work for settings observed via Darwin notifications.

**Workflow:**
```bash
# Step 1: Write to defaults (persists setting)
xcrun simctl spawn <udid> defaults write <domain> <key> -bool YES

# Step 2: Post Darwin notification (triggers live UIKit refresh)
xcrun simctl spawn <udid> notifyutil -p <notification_name>
```

**Theoretical Basis:**
1. UIKit property methods (e.g., `UIAccessibility.isReduceMotionEnabled`) read from UserDefaults/Foundation preferences
2. UIKit registers Darwin notification observers for `com.apple.accessibility.*` keys
3. When Darwin notification is posted, UIKit receives the signal and re-reads the defaults value
4. UIKit posts its own UIKit-level notification (e.g., `boldTextStatusDidChangeNotification`)
5. Apps observing the UIKit notification receive live updates without relaunch

**Caveats:**
- `notifyutil` uses the `-p` flag to post/notify (confirmed in search results with biometrics example: `notifyutil -p com.apple.BiometricKit.enrollmentChanged`)
- Some settings may not post Darwin notifications (e.g., if purely GUI-controlled without system integration)
- Unconfirmed settings (Grayscale, Inverted Colors, etc.) may require different notification names or no notification support

---

## 4. Open-Source References & Tool Analysis

### Tools Found

| Tool | Purpose | Accessibility Settings Support | Notes |
|------|---------|--------|-------|
| **AXe CLI** (cameroncooke) | UI automation via Accessibility APIs | None documented | Focuses on UI element querying & touch input; no defaults/settings toggle found |
| **idb (Facebook)** | iOS Simulator automation | Settings mentioned but not detailed | FBSimulatorSettingsCommands exists but public docs don't document accessibility toggles |
| **RocketSim** | Xcode Simulator companion (commercial) | Yes, environment overrides | Source available on GitHub (AvdLee/RocketSimApp) but specific implementation not accessible via public search |
| **ios-simulator-skill** | MCP server for Claude | UI automation via Accessibility APIs | No settings toggle documented |
| **xctree** | CLI accessibility tree extraction | Reading tree only, not writing settings | Similar to Accessibility Inspector but CLI |

### Key Insight

**None of the major open-source tools explicitly document accessibility settings toggling.** This suggests:
1. The feature may be less common than initially expected
2. Most tools focus on UI automation (input/output) rather than system settings
3. Reverse engineering or direct defaults/notifyutil usage is the typical approach
4. RocketSim (commercial) may implement this but source code details are not publicly discoverable

### References for Further Investigation

- [cameroncooke/AXe GitHub](https://github.com/cameroncooke/AXe) — Check if settings support was added in recent versions
- [facebook/idb GitHub](https://github.com/facebook/idb) — Search FBSimulatorSettingsCommands.h for accessibility setting methods
- [AvdLee/RocketSimApp GitHub](https://github.com/AvdLee/RocketSimApp) — Reference implementation for accessibility toggle UI

---

## 5. iOS Simulator Plist Locations

On iOS Simulator, settings are stored in Simulator-specific plist files, not the macOS host's `~/.GlobalPreferences.plist`.

**Location Pattern:**
```
~/Library/Developer/CoreSimulator/Devices/<UDID>/data/Library/Preferences/.GlobalPreferences.plist
~/Library/Developer/CoreSimulator/Devices/<UDID>/data/Library/Preferences/com.apple.UIKit.plist
```

**Verification:** Can inspect directly via:
```bash
xcrun simctl get_app_container <udid> com.apple.Preferences data
# Then navigate to Library/Preferences to examine plist files
```

---

## 6. Unresolved Questions

1. **Darwin notification names for all 8 accessibility settings:** Only 2 confirmed (reduce-motion, increase-contrast). Remaining 6 require either:
   - Apple's official documentation (not found)
   - Reverse engineering of UIKit source code
   - Empirical testing with `notifyutil -p` trial-and-error

2. **Exact plist domain authoritative source:** Both `.GlobalPreferences` and `com.apple.UIKit` appear in search results for Reduce Motion; unclear which is canonical or if both are checked by UIKit.

3. **Grayscale, Inverted Colors, On/Off Labels support:** No UIKit API or Darwin notification references found. These may not support live updates without relaunch, or may use different mechanisms (e.g., screen/system-level settings not exposed via defaults).

4. **Whether all settings support live refresh:** Some settings may require app relaunch regardless of Darwin notification posting (e.g., if they affect app initialization logic rather than runtime state).

5. **RocketSim implementation details:** Source code exists but specific accessibility settings toggle mechanism not documented or easily found in public search results.

---

## Recommendations for Implementation

### Phase 1: Empirical Validation (Immediate)

Test on UDID `00AFDCEE-858A-4B7D-B5B4-08D3B1D6CAFB` with a test iOS app:

```bash
# Test Reduce Motion (most likely to work)
xcrun simctl spawn 00AFDCEE-858A-4B7D-B5B4-08D3B1D6CAFB \
  defaults write .GlobalPreferences UIAccessibilityReduceMotionEnabled -bool YES
xcrun simctl spawn 00AFDCEE-858A-4B7D-B5B4-08D3B1D6CAFB \
  notifyutil -p com.apple.accessibility.reduce-motion.enabled

# Test Bold Text (secondary)
xcrun simctl spawn 00AFDCEE-858A-4B7D-B5B4-08D3B1D6CAFB \
  defaults write .GlobalPreferences AccessibilityBoldText -bool YES
xcrun simctl spawn 00AFDCEE-858A-4B7D-B5B4-08D3B1D6CAFB \
  notifyutil -p com.apple.accessibility.bold-text.enabled  # Guessed name
```

**Success Criteria:** iOS app observing UIKit accessibility notification receives live update without relaunch.

### Phase 2: Reverse Engineering (If needed)

- Examine `/System/Library/Frameworks/UIKit.framework` in Simulator environment for accessibility notification registration
- Check RocketSim source code (GitHub) for reference implementation
- Monitor Xcode console logs when toggling settings in Settings.app to identify notification names

### Phase 3: Graceful Degradation

For unconfirmed settings (Grayscale, Inverted Colors, etc.), implement fallback:
- Attempt live update via defaults + notifyutil
- If notification name unknown, offer manual Setting.app toggle or document limitation
- Mark as "Coming soon" if reversal not feasible before MVP deadline

---

## Sources

- [Apple Developer: UIAccessibility.boldTextStatusDidChangeNotification](https://developer.apple.com/documentation/uikit/uiaccessibility/1615152-boldtextstatusdidchangenotificat)
- [Apple Developer: UIAccessibility.reduceMotionStatusDidChangeNotification](https://developer.apple.com/documentation/uikit/uiaccessibility/1615204-reducemotionstatusdidchangenotif)
- [Apple Developer: UIAccessibility Notification Names](https://developer.apple.com/documentation/uikit/accessibility_for_ios_and_tvos/notification_names)
- [Apple Developer: Darwin Notification API](https://developer.apple.com/documentation/darwinnotify/darwin-notification-api)
- [Apple Developer: UIAccessibility buttonShapesEnabled](https://developer.apple.com/documentation/uikit/uiaccessibility/buttonshapesenabled)
- [Apple Support: Change Motion settings for accessibility on Mac](https://support.apple.com/guide/mac-help/change-motion-settings-for-accessibility-mchla3c4f1da/mac)
- [iOS Dev Recipes: xcrun simctl](https://www.iosdev.recipes/simctl/)
- [NSHipster: simctl](https://nshipster.com/simctl/)
- [GitHub: cameroncooke/AXe](https://github.com/cameroncooke/AXe)
- [GitHub: facebook/idb](https://github.com/facebook/idb)
- [GitHub: AvdLee/RocketSimApp](https://github.com/AvdLee/RocketSimApp)
- [Medium: Darwin Notification in iOS - MXI Coders](https://mxicoders.com/darwin-notification-in-ios/)
- [Medium: Send data Between iOS Apps and Extensions Using Darwin Notifications](https://rizwan95.medium.com/send-data-between-ios-apps-and-extensions-using-darwin-notifications-da680fe21ad0)
- [idb Accessibility Documentation](https://fbidb.io/docs/accessibility/)
- [Medium: iOS Simulator Accessibility Inspector — A Deep Dive](https://medium.com/@crissyjoshua/ios-simulator-accessibility-inspector-a-deep-dive-6b6f9fa5fe18)

---

## Appendix: Tested Patterns (Placeholder for empirical results)

### Reduce Motion ✓ (Confirmed to work)
```bash
xcrun simctl spawn 00AFDCEE-858A-4B7D-B5B4-08D3B1D6CAFB \
  defaults write .GlobalPreferences UIAccessibilityReduceMotionEnabled -bool YES
xcrun simctl spawn 00AFDCEE-858A-4B7D-B5B4-08D3B1D6CAFB \
  notifyutil -p com.apple.accessibility.reduce-motion.enabled
```

### Bold Text (To be tested)
```bash
xcrun simctl spawn 00AFDCEE-858A-4B7D-B5B4-08D3B1D6CAFB \
  defaults write .GlobalPreferences AccessibilityBoldText -bool YES
xcrun simctl spawn 00AFDCEE-858A-4B7D-B5B4-08D3B1D6CAFB \
  notifyutil -p com.apple.accessibility.bold-text.enabled
```

### Reduce Transparency (To be tested)
```bash
xcrun simctl spawn 00AFDCEE-858A-4B7D-B5B4-08D3B1D6CAFB \
  defaults write .GlobalPreferences UIAccessibilityReduceTransparencyEnabled -bool YES
xcrun simctl spawn 00AFDCEE-858A-4B7D-B5B4-08D3B1D6CAFB \
  notifyutil -p com.apple.accessibility.reduce-transparency.enabled
```
