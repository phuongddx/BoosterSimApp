# Research: Environment Overrides Implementation

**Date:** 2026-03-26 | **Status:** Already implemented

---

## TL;DR

Environment Overrides is **already fully implemented** in the codebase. The feature uses a two-tier approach via `xcrun simctl` to toggle accessibility settings and appearance on iOS Simulator without app relaunch.

---

## Architecture

```
EnvironmentOverridesView (SwiftUI toggle UI)
        |
        v
EnvironmentOverrideService (@Published state + setters)
        |
        v
SimCtlService (xcrun simctl process executor)
        |
        v
iOS Simulator (defaults write + notifyutil for instant apply)
```

### Key Files

| File | Purpose | LOC |
|------|---------|-----|
| `Services/EnvironmentOverrideService.swift` | State + read/write logic | 207 |
| `Views/SideWindow/EnvironmentOverridesView.swift` | Toggle UI (SwiftUI) | 144 |
| `Services/SimCtlService.swift` | Shared `xcrun simctl` executor | 78 |

### Wiring

- `AppDelegate` owns `envOverrideService` (lazy init with shared `simCtlService`)
- `SideWindowController` passes it as `@EnvironmentObject` to `SideWindowView`
- `SideWindowView` renders it inside a collapsible "Environment" section

---

## Two-Tier Toggle Mechanism

### Tier 1: Official `simctl ui` Commands

For settings with first-class `simctl` support:

```bash
# Read
xcrun simctl ui <udid> appearance        # -> "light" or "dark"
xcrun simctl ui <udid> increase_contrast # -> "enabled" or "disabled"
xcrun simctl ui <udid> content_size      # -> "large", "extra-large", etc.

# Write
xcrun simctl ui <udid> appearance dark
xcrun simctl ui <udid> increase_contrast enabled
xcrun simctl ui <udid> content_size extra-large
```

**Supported settings:** Dark Mode, Increase Contrast, Dynamic Type (content size).

### Tier 2: `defaults write` + `notifyutil` (Instant Apply)

For accessibility toggles NOT supported by `simctl ui`:

```bash
# Step 1: Write to com.apple.Accessibility domain
xcrun simctl spawn <udid> defaults write com.apple.Accessibility <key> -bool YES

# Step 2: Post Darwin notification for instant UIKit refresh (no relaunch)
xcrun simctl spawn <udid> notifyutil -p <notification_name>
```

**Key-to-notification mapping (confirmed working):**

| Setting | Plist Key | Darwin Notification |
|---------|-----------|-------------------|
| Reduce Motion | `ReduceMotionEnabled` | `com.apple.accessibility.reduce-motion` |
| Bold Text | `EnhancedTextLegibilityEnabled` | `com.apple.accessibility.enhanced-text-legibility` |
| Reduce Transparency | `EnhancedBackgroundContrastEnabled` | `com.apple.accessibility.reduce-transparency` |
| Grayscale | `GrayscaleDisplay` | `com.apple.accessibility.grayscale` |
| Invert Colors | `InvertColorsEnabled` | `com.apple.accessibility.invert-colors` |
| Button Shapes | `IncreaseButtonLegibilityEnabled` | `com.apple.accessibility.increase-button-legibility` |
| On/Off Labels | `OnOffSwitchLabels` | `com.apple.accessibility.on-off-switch-labels` |
| Differentiate w/o Color | `DifferentiateWithoutColor` | `com.apple.accessibility.differentiate-without-color` |

All keys use `com.apple.Accessibility` plist domain.

### Why `notifyutil`?

Without the Darwin notification post, writing to defaults alone does NOT trigger live UIKit updates. The notification is what wakes UIKit's internal observers, causing it to re-read the preference and broadcast UIKit-level notifications (e.g., `boldTextStatusDidChangeNotification`) to the running app. This is the same mechanism iOS uses internally when Settings.app changes these values.

---

## Dynamic Type (Content Size)

Uses `simctl ui content_size` with 12 named sizes:

```
extra-small, small, medium, large (default), extra-large,
extra-extra-large, extra-extra-extra-large,
accessibility-medium, accessibility-large,
accessibility-extra-large, accessibility-extra-extra-large,
accessibility-extra-extra-extra-large
```

UI presents a slider (0-11 index) with small/large "A" labels.

---

## State Loading

On `onAppear` or `onChange(of: udid)`, `loadCurrentState(udid:)` fires parallel `simctl` reads:
- Tier 1: `simctl ui <udid> appearance/increase_contrast/content_size`
- Tier 2: `simctl spawn <udid> defaults read com.apple.Accessibility <key>` for each a11y toggle

All reads are Combine publishers that update `@Published` properties on main thread.

---

## UI Structure

`EnvironmentOverridesView` renders three groups inside a collapsible section:

1. **Accessibility** - 9 toggle rows (icon + label + switch)
2. **Appearance** - Dark Mode toggle (maps to appearance light/dark)
3. **Dynamic Type** - Slider with size label

Each toggle uses a helper `binding()` that creates a `Binding<Bool>` from service keyPath + setter closure. Disabled state when `udid == nil` (no simulator detected); falls back to `"booted"` when UDID unavailable but sim is detected.

---

## Risks & Limitations

1. **Undocumented plist keys** - Apple doesn't officially document `com.apple.Accessibility` key names; may break across iOS versions
2. **Notification names** - Darwin notification strings are reverse-engineered, not from public API
3. **No error feedback** - `sink(receiveCompletion:)` silently ignores failures
4. **Per-toggle latency** - Each toggle spawns a separate `xcrun` process (~50-100ms each)
5. **No batch read** - `loadCurrentState` spawns 11 parallel processes (3 tier-1 + 8 tier-2)

---

## Unresolved Questions

1. Are all 8 tier-2 notification names confirmed working on iOS 18/19 Simulator?
2. Should there be user-visible error feedback when `simctl` commands fail?
3. Could batch reads (single `defaults read com.apple.Accessibility` for all keys) reduce process spawn overhead?
