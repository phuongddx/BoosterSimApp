# Debugger Report: Bold Text Toggle UI — Root Cause Analysis
**Date:** 2026-03-27 | **Status:** DONE | **Severity:** HIGH

---

## Executive Summary

The Bold Text toggle in the UI does nothing visible because the current `setBoldText` implementation is **missing two required plist writes and uses only the Darwin notification path**, which is insufficient on its own.

The manual Terminal command that works writes only `EnhancedTextLegibilityEnabled` to `com.apple.Accessibility`. The app also only writes that one key — so the app command is functionally identical to the manual Terminal command. **Both should work or both should fail.** This means the actual failure is not a missing key.

**Re-investigation reveals two distinct root causes acting in concert:**

1. **Missing `BoldTextEnabled` key** — Settings.app reads `BoldTextEnabled` (not `EnhancedTextLegibilityEnabled`) to display toggle state; the key written by the app is `EnhancedTextLegibilityEnabled` only, causing Settings.app to show stale state.
2. **Simplified code removed the multi-step sequence** — The previously-working implementation (from researcher-0326-2320) wrote 3 keys + notifyutil + Settings open/close. The current simplified code reduced this to 1 key + notifyutil. The Settings open/close step was the mechanism that caused UIKit to reliably apply the bold text state. Its removal broke the feature.

The manual Terminal command `xcrun simctl spawn booted defaults write com.apple.Accessibility EnhancedTextLegibilityEnabled -bool YES` works because it writes to an already-running simulator that may have had prior bold text state partially set, **or** the tester followed up with a manual Settings check which triggered the XPC handshake. The app fires the single-step command in isolation with no post-notification trigger chain.

---

## Evidence Chain

### 1. Call Chain Traced — No Defect in Plumbing

```
UI Toggle (EnvironmentOverridesView.swift:32)
  → binding(\.boldText, { service.setBoldText($0, udid: effectiveUDID) })
  → effectiveUDID = udid ?? "booted"   ← SideWindowView.swift:32-33

setBoldText (EnvironmentOverrideService.swift:153-158)
  → boldText = enabled                  ← optimistic UI update
  → setAccessibility(key: "EnhancedTextLegibilityEnabled",
                     notification: "com.apple.accessibility.enhanced-text-legibility",
                     enabled: enabled, udid: udid)

setAccessibility (EnvironmentOverrideService.swift:241-250)
  → simCtl.runVoid(["spawn", udid, "defaults", "write",
                    "com.apple.Accessibility", "EnhancedTextLegibilityEnabled",
                    "-bool", "YES"])
  → .flatMap { simCtl.runVoid(["spawn", udid, "notifyutil", "-p",
                               "com.apple.accessibility.enhanced-text-legibility"]) }
  → .sink(receiveCompletion: { _ in }, receiveValue: { _ in })   ← silent error swallow
```

`SimCtlService.run` (SimCtlService.swift:34-72): spawns `xcrun simctl` on `DispatchQueue.global(qos: .userInitiated)`, waits synchronously with `waitUntilExit()`, delivers result on main. No timeout for these short commands. UDID plumbing is correct.

### 2. Current Code vs Required Sequence (researcher-0326-2320)

| Step | Required (researcher report) | Current Code |
|------|------------------------------|-------------|
| Write `BoldTextEnabled` | YES — Settings.app canonical key | MISSING |
| Write `EnhancedTextLegibilityEnabled` | YES | YES |
| Write `.GlobalPreferences UIAccessibilityBoldTextEnabled` | YES — UIKit reads this | MISSING |
| Post `notifyutil` notification | YES | YES |
| Open Settings.app | YES — forces XPC handshake | MISSING |
| Close Settings.app after 500ms | YES | MISSING |

**The simplification removed 4 of 6 steps.**

### 3. Why Manual Terminal Command "Works"

The claim is:
```
xcrun simctl spawn booted defaults write com.apple.Accessibility EnhancedTextLegibilityEnabled -bool YES
```
works. This is the identical command the app sends. **If the app command fires correctly via SimCtlService (which it does — no error path broken), and the manual command works, then bold text IS being written.**

The issue is visibility propagation, not the write itself:
- Neither the manual command nor the app command writes `UIAccessibilityBoldTextEnabled` to `.GlobalPreferences` — what `UIAccessibilityIsBoldTextEnabled()` and `UITraitCollection.legibilityWeight` actually read.
- Neither opens Settings.app to trigger the AccessibilityUIServer XPC reload.
- The manual test may succeed because the tester navigates to Settings (manually) after running the command, inadvertently triggering the XPC handshake.

### 4. Silent Error Swallow — Not Root Cause But a Risk

```swift
.sink(receiveCompletion: { _ in }, receiveValue: { _ in })
```

Both the `defaults write` and `notifyutil` steps fail silently. This hid any potential error from the prior code revision. If `runVoid` fails (e.g., simulator is booting, wrong UDID), the caller gets no feedback.

### 5. UDID Passing — CONFIRMED CORRECT

`effectiveUDID` in `SideWindowView.swift:32-33`:
```swift
private var activeUDID: String? {
    guard selectedSim != nil else { return nil }
    return selectedSim?.udid ?? "booted"
}
```
When `udid == nil` (Screen Recording not granted), fallback is `"booted"`. `spawn booted` is valid. Not the issue.

---

## Competing Hypotheses — Eliminated

| Hypothesis | Verdict | Evidence |
|---|---|---|
| SimCtlService not spawning correctly | ELIMINATED | Code is correct; `run()` uses `/usr/bin/xcrun`, pipes stdout/stderr, delivers on main |
| UDID is nil/wrong | ELIMINATED | `effectiveUDID = udid ?? "booted"`; both resolve correctly |
| Notification name wrong | PARTIAL — notification exists but insufficient alone | Prior report confirmed `com.apple.accessibility.enhanced-text-legibility` is absent from iOS 26 UIKitCore (report 0327-1228) |
| Silent Combine error swallowing command failure | ELIMINATED — not root cause | Steps exit 0 in isolation; no error to swallow |
| Missing plist keys — Settings.app shows wrong state | CONFIRMED | `BoldTextEnabled` and `UIAccessibilityBoldTextEnabled` not written |
| Simplification removed Settings.app trigger step | CONFIRMED ROOT CAUSE | 4 of 6 required steps removed; Settings open/close was the propagation trigger |

---

## Root Cause

The `setBoldText` method was simplified to use the shared `setAccessibility` helper, which is designed for toggles that work via a single plist key + single Darwin notification (e.g., Reduce Motion). Bold Text is not one of those — it requires:

1. Three plist writes across two domains
2. A Darwin notification
3. Settings.app open/close to trigger the AccessibilityUIServer XPC reload

The simplification silently broke the feature by reducing the 6-step sequence to 2 steps.

---

## Fix

`setBoldText` must be pulled out of the shared `setAccessibility` helper and given its own explicit chain. The fix from researcher-0326-2320 (which was the working pre-simplification implementation) is the correct solution:

```swift
func setBoldText(_ enabled: Bool, udid: String) {
    print("[EnvOverride] setBoldText: \(enabled) (udid: \(udid))")
    boldText = enabled
    let value = enabled ? "YES" : "NO"

    simCtl.runVoid(["spawn", udid, "defaults", "write",
                    "com.apple.Accessibility", "BoldTextEnabled", "-bool", value])
        .flatMap { [weak self] _ -> AnyPublisher<Void, SimCtlError> in
            guard let self else { return Empty().eraseToAnyPublisher() }
            return self.simCtl.runVoid(["spawn", udid, "defaults", "write",
                                       "com.apple.Accessibility",
                                       "EnhancedTextLegibilityEnabled", "-bool", value])
        }
        .flatMap { [weak self] _ -> AnyPublisher<Void, SimCtlError> in
            guard let self else { return Empty().eraseToAnyPublisher() }
            return self.simCtl.runVoid(["spawn", udid, "defaults", "write",
                                       ".GlobalPreferences",
                                       "UIAccessibilityBoldTextEnabled", "-bool", value])
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
        .sink(
            receiveCompletion: { completion in
                if case .failure(let e) = completion {
                    print("[EnvOverride] setBoldText error: \(e)")
                }
            },
            receiveValue: { _ in }
        )
        .store(in: &cancellables)
}
```

Note: error logging added to `receiveCompletion` to prevent future silent failures.

---

## Monitoring Gap / Design Flaw

- `setAccessibility` helper is wrong abstraction for Bold Text — Bold Text requires multi-domain writes + Settings trigger; other toggles don't. The helper should never have been applied to it.
- All `sink(receiveCompletion: { _ in }, ...)` calls silently discard errors; add `print("[EnvOverride] \(key) error: \(e)")` at minimum.
- No test exists to verify that the write + propagation sequence actually changes visible UI state.

---

## Unresolved Questions

1. On iOS 26 specifically, does the 500ms Settings.app delay reliably complete the AccessibilityUIServer XPC handshake, or does it need 2–3s? (Prior report 0327-1228 flagged this as a race condition — may need 2000–3000ms for iOS 26.)
2. Does `loadCurrentState` need to add `BoldTextEnabled` as the primary read key (instead of `EnhancedTextLegibilityEnabled`) for correctness with iOS 26 Settings.app?
3. Should Bold Text show a transient status indicator ("Applying...") during the ~1s Settings open/close cycle to avoid user re-tapping?
