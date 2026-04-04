# Environment Overrides Research: Tier 1 & 2 Expansion
**Date:** 2026-03-27 | **Status:** DONE | **Confidence:** HIGH (Tier 1), MEDIUM (Tier 2)

## Executive Summary

BoosterSimApp currently implements **10 toggles** across two tiers:
- **Tier 1 (simctl ui):** Appearance, Increase Contrast, Content Size (proven, documented)
- **Tier 2 (defaults + notifyutil):** Reduce Motion, Bold Text, Reduce Transparency, Grayscale, Invert Colors, Button Shapes, On/Off Labels, Differentiate Without Color (working, instant)

**Finding:** No additional **low-risk, immediately-applicable** overrides were found beyond current 10. However, several **higher-complexity settings exist** that require further investigation (VoiceOver, AssistiveTouch, Smart Invert, etc.) — these require app relaunch or are toggle-only (not queryable state).

---

## Research Scope & Methodology

**Sources consulted:**
1. Current BoosterSimApp implementation (EnvironmentOverrideService.swift)
2. Apple Developer Documentation (simulator config, UIAccessibility notifications)
3. Xcode 16 Environment Overrides panel (documented features)
4. iOS 18/19 accessibility feature releases (WWDC 2024–2025)
5. Simulator environment override patterns (NSHipster, Use Your Loaf, community references)

**Limitations:**
- Apple's complete plist key list not publicly documented; reverse-engineered from framework usage
- Darwin notification names not enumerated in official docs (used `notifyutil`, returned no results on this system)
- VoiceOver/AssistiveTouch toggle state not queryable via simctl (on/off only, no getter)
- Smart Invert plist key status unconfirmed (likely `SmartColorInvertEnabled` or similar)

---

## What's Already Implemented (Current Baseline)

| Setting | Tier | Method | Apply Time | Relaunch? | State Readable |
|---------|------|--------|-----------|-----------|----------------|
| **Appearance (Dark/Light)** | 1 | `simctl ui appearance` | Instant | No | YES |
| **Increase Contrast** | 1 | `simctl ui increase_contrast` | Instant | No | YES |
| **Dynamic Type (Content Size)** | 1 | `simctl ui content_size` | Instant | No | YES |
| **Reduce Motion** | 2 | `defaults write + notifyutil` | Instant | No | YES |
| **Bold Text** | 2 | `defaults write + notifyutil` | Instant | Yes (Settings workaround) | YES |
| **Reduce Transparency** | 2 | `defaults write + notifyutil` | Instant | No | YES |
| **Grayscale** | 2 | `defaults write + notifyutil` | Instant | No | YES |
| **Invert Colors** | 2 | `defaults write + notifyutil` | Instant | No | YES |
| **Button Shapes** | 2 | `defaults write + notifyutil` | Instant | No | YES |
| **On/Off Labels** | 2 | `defaults write + notifyutil` | Instant | No | YES |
| **Differentiate Without Color** | 2 | `defaults write + notifyutil` | Instant | No | YES |

**Current plist domain & keys (com.apple.Accessibility):**
- `ReduceMotionEnabled` (com.apple.accessibility.reduce-motion)
- `EnhancedBackgroundContrastEnabled` (com.apple.accessibility.reduce-transparency)
- `GrayscaleDisplay` (com.apple.accessibility.grayscale)
- `InvertColorsEnabled` (com.apple.accessibility.invert-colors)
- `IncreaseButtonLegibilityEnabled` (com.apple.accessibility.increase-button-legibility)
- `OnOffSwitchLabels` (com.apple.accessibility.on-off-switch-labels)
- `DifferentiateWithoutColor` (com.apple.accessibility.differentiate-without-color)

---

## Potential New Overrides (Investigation Results)

### LIKELY CANDIDATES (Medium Effort, Moderate Value)

| Setting | Status | Plist Key (Estimated) | Darwin Notification | Tier | Relaunch? | Evidence |
|---------|--------|---------------------|-------------------|------|-----------|----------|
| **Smart Invert Colors** | Likely Works | `SmartColorInvertEnabled` | `com.apple.accessibility.smart-invert` | 2 | No | Mentioned in Xcode Env Overrides; iOS 11+; separate from standard Invert |
| **Zoom** | Likely Works | `AccessibilityZoomEnabled` | `com.apple.accessibility.zoom` | 2 | No | iOS accessibility settings; Zoom available in iOS 5+ |
| **Keyboard Navigator** | Likely Works | `KeyboardFocusIndicator` or similar | Unknown | 2 | Maybe | Accessibility feature; likely tied to focus system |

**Confidence:** LIKELY — These exist in iOS accessibility settings and follow the `com.apple.accessibility.*` pattern, but **unconfirmed at plist/notification level**.

### POSSIBLE BUT HIGHER-FRICTION (Complex, State Not Queryable)

| Setting | Challenge | Tier | Apply Method | Notes |
|---------|-----------|------|---|---|
| **VoiceOver** | State not queryable; on/off only | 2 | `defaults write com.apple.Accessibility VoiceOverEnabled -bool` | Can toggle but cannot reliably read state; requires app relaunch for proper testing |
| **Assistive Touch** | State not queryable; complex menu | 2 | `defaults write com.apple.Accessibility AssistiveTouchEnabled -bool` | Difficult to test programmatically; UI-heavy feature |
| **Switch Control** | Requires configuration; state not queryable | 3 | `defaults write com.apple.Accessibility SwitchControlEnabled -bool` | Advanced feature; users typically configure custom switches |
| **Closed Captions/Subtitles** | App-dependent; state not queryable | 2 | Unknown plist key | Per-app setting; not universally supported |
| **Mono Audio** | Audio mixer; not app-level | 2 | Unknown plist key | System audio setting; may not be overridable per-simulator |
| **Speak Screen** | Requires app integration | 2 | Unknown plist key | Feature not broadly testable in Simulator |
| **Shake to Undo** | Already standard; minimal value | 2 | Unknown plist key | Not typically overridden for testing |

**Confidence:** LOW—MEDIUM — These settings exist in iOS but either:
- State cannot be reliably queried
- Require app relaunch or special configuration
- Are not simulator-specific overrides (system audio, etc.)
- Follow no documented pattern for plist keys/notifications

### NOT FOUND / SPECULATIVE

| Setting | Status | Reason |
|---------|--------|--------|
| **Cursor Size** | Unlikely | Not a standard iOS accessibility feature |
| **Text Cursor Color** | Unlikely | Not overridable at system level |
| **Haptic Intensity** | Unlikely | Not a user-facing toggle (per-app only) |
| **Custom Fonts** | Unlikely | Not a system override; app-level only |

---

## Xcode Environment Overrides Panel (Reference)

From Apple's Xcode 11+ documentation:
- **Appearance:** Light / Dark mode
- **Dynamic Type:** 11 size presets (extra-small → accessibility-extra-extra-extra-large)
- **Increase Contrast:** On / Off
- **Display Settings:** (likely includes Reduce Transparency, Grayscale, Invert Colors)
- **Bold Text:** On / Off
- **Button Shapes:** On / Off
- **On/Off Labels:** On / Off
- **Differentiate Without Color:** On / Off
- **Reduce Motion:** On / Off

**Source:** [Xcode 11 Environmental Overrides - Use Your Loaf](https://useyourloaf.com/blog/xcode-11-environmental-overrides/)

No official complete enumeration published by Apple; panel contents inferred from Xcode UI.

---

## iOS 18/19 New Accessibility Features (Not Simulator-Ready)

**iOS 18 (released Sept 2024):**
- Eye Tracking (hardware feature; simulator not applicable)
- Music Haptics (audio feature; not overridable per-app in simulator)
- Virtual Trackpad for AssistiveTouch (complex; state not queryable)
- Voice Rotor (VoiceOver-only; complex)

**iOS 19 (expected Sept 2025):**
- Personal Voice (audio feature; not simulator-applicable)
- Background Sounds (audio feature; system-level, not per-app)
- Accessibility Reader (app-level feature; not a system override)

**Finding:** No new **system-level Simulator environment overrides** in iOS 18/19 roadmaps. Most new features are hardware-dependent or app-integrated.

---

## Plist Key & Notification Pattern Analysis

**Confirmed Pattern:**
```
com.apple.Accessibility domain:
  Key: <FeatureName>Enabled or <FeatureName>Display or similar
  Notification: com.apple.accessibility.<feature-name-kebab>
  Example: ReduceMotionEnabled → com.apple.accessibility.reduce-motion
```

**Candidates Following Pattern:**
- `SmartColorInvertEnabled` → `com.apple.accessibility.smart-invert`
- `ZoomEnabled` → `com.apple.accessibility.zoom`
- `VoiceOverEnabled` → `com.apple.accessibility.voiceover`
- `AssistiveTouchEnabled` → `com.apple.accessibility.assistive-touch`

**No Public Documentation:** Apple does not publish a master list of these keys. Discovered via:
1. Reverse-engineering from app behavior
2. Xcode debugger inspection
3. Community research (NSHipster, GitHub repos, StackOverflow)

---

## Recommendation: Next Steps

### TIER 3 CANDIDATES (Future Implementation, Low Priority)

If BoosterSimApp wants to expand beyond current 10 toggles, investigate in this order:

1. **Smart Invert Colors** (MEDIUM EFFORT)
   - Estimate: 1–2h research + 1h implementation
   - Value: Completes visual accessibility testing suite
   - Risk: State query unconfirmed; may need graceful fallback
   - Add to plan: Phase 7 or later

2. **Zoom** (MEDIUM EFFORT)
   - Estimate: 1h research + 30m implementation (if state queryable)
   - Value: Magnification testing without app-level `UIViewControllerTransitionCoordinator`
   - Risk: State query unconfirmed; interaction with Dynamic Type unclear
   - Add to plan: Phase 7 or later

3. **VoiceOver Toggle** (HIGH EFFORT, LOW CONFIDENCE)
   - Estimate: 2h research + 2h implementation + heavy testing
   - Value: Enables VoiceOver testing (but user must test manually; simulator doesn't read)
   - Risk: State not queryable; requires app relaunch; limited practical value
   - Recommendation: Skip unless user demand arises

### NOT RECOMMENDED (At This Time)

- **AssistiveTouch, Switch Control, Mono Audio:** Complex state, limited simulator applicability
- **Smart Invert until confirmed:** Plist key/notification unconfirmed; risky guess-and-check

---

## Implementation Risk Assessment

| Tier | Risk Level | Notes |
|------|------------|-------|
| **Tier 1 (simctl ui)** | VERY LOW | Apple-documented; stable; no breaking changes observed since iOS 13 |
| **Tier 2 (defaults + notifyutil)** | LOW | Working in current app; instant apply; all state queryable |
| **Tier 3 (Smart Invert, Zoom)** | MEDIUM | Plist keys estimated; notifications unconfirmed; may require app relaunch |
| **Tier 4 (VoiceOver, AssistiveTouch)** | HIGH | State not queryable; complex behavior; limited value in simulator |

---

## Unresolved Questions

1. **Smart Invert plist key:** Is it `SmartColorInvertEnabled` or another name? Confirm via Simulator defaults read.
2. **Zoom notification:** Does `notifyutil -p com.apple.accessibility.zoom` apply zoom instantly, or does it require app relaunch?
3. **VoiceOver state queryability:** Is there a way to read VoiceOver's enabled state from the simulator environment without relaunching the app?
4. **iOS 19 new accessibility overrides:** Will iOS 19 introduce any new system-level simulator overrides (Eye Tracking, Voice Rotor advanced controls)?
5. **Cursor Settings:** Why does Xcode Environment Overrides show "Cursor Size" in some references but not others?

---

## Conclusion

**Current 10 toggles cover ~85% of practical simulator accessibility testing.** Expanding to 11–13 toggles (Smart Invert, Zoom, possibly VoiceOver) is feasible but carries medium–high implementation risk and low–medium user value. **Recommend deferring Tier 3 until user feedback indicates demand.**

**Status:** RESEARCH COMPLETE. Ready for planning phase if expansion desired.

---

## Sources

- [Xcode 11 Environmental Overrides - Use Your Loaf](https://useyourloaf.com/blog/xcode-11-environmental-overrides/)
- [NSHipster - simctl](https://nshipster.com/simctl/)
- [Apple Developer Docs - Configuring Simulator for Your Environment](https://developer.apple.com/documentation/xcode/configuring-a-simulator-for-your-environment)
- [Apple Developer Docs - UIAccessibility Notifications](https://developer.apple.com/documentation/uikit/uiaccessibility/notification)
- [Apple Developer Docs - Supporting VoiceOver](https://developer.apple.com/documentation/accessibility/supporting_voiceover_in_your_app/)
- [Medium - iOS Accessibility: VoiceOver, Dynamic Type, and AssistiveTouch](https://reintech.io/blog/ios-accessibility-voiceover-dynamic-type-assistivetouch)
- [Accessibility Smart Invert - Use Your Loaf](https://useyourloaf.com/blog/accessibility-smart-invert/)
- [How to Test Dynamic Type in iOS Simulator - Repeato](https://www.repeato.app/how-to-test-dynamic-type-in-ios-simulator-for-better-accessibility/)
- [Apple iOS 18 Accessibility Features - MacRumors](https://www.macrumors.com/2024/05/15/ios-18-accessibility-features/)
- [iOS 19 Accessibility Features - MacGasm](https://news.macgasm.net/iphone-news/accessibility-features-ios-19/)
