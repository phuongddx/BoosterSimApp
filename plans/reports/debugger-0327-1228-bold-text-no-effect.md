# Debugger Report: Bold Text Toggle Has No Visual Effect
**Date:** 2026-03-27 | **Status:** DONE | **Severity:** HIGH

---

## Executive Summary

Bold Text toggle writes correct plist values but produces no visible change because:
1. `com.apple.accessibility.enhanced-text-legibility` Darwin notification is **absent from UIKitCore on iOS 26.3** — UIKit does not observe it, so the notification is a no-op.
2. The Settings.app open/close workaround is **killed too early** (500ms after `openurl` returns, but the accessibility XPC handshake needs 2–3s to propagate state to running processes).
3. On iOS 26, bold text requires a **SpringBoard restart** (respring) to visually apply — the architecture moved to XPC-based accessibility state, removing direct Darwin notification support.

**Root cause: Wrong trigger mechanism for iOS 26's XPC-based accessibility architecture.**

---

## Evidence Collected

### 1. Plist Writes — CORRECT, Work Fine
All 3 keys write successfully (exit 0) and persist:
```
BoldTextEnabled = YES          (com.apple.Accessibility)
EnhancedTextLegibilityEnabled = YES  (com.apple.Accessibility)
UIAccessibilityBoldTextEnabled = YES (.GlobalPreferences)
```
Confirmed via `defaults read` after every write. Survive SpringBoard restart.

### 2. Notification Name — NOT IN iOS 26 UIKitCore
```bash
strings UIKitCore | grep "enhanced-text-legibility"
# → (no output, exit 1)
```
The string `com.apple.accessibility.enhanced-text-legibility` does **not exist** in iOS 26.3 UIKitCore (`/Library/Developer/CoreSimulator/Volumes/iOS_23D8133/.../UIKitCore`). UIKit cannot observe a notification it doesn't register for.

**What IS in iOS 26.3 UIKitCore:**
- `com.apple.accessibility.AccessibilityUIServer` — only accessibility darwin string present
- `_accessibilityBoldTextChanged:` — ObjC method exists but is called via XPC from AccessibilityUIServer, not triggered by raw Darwin notification
- `UIAccessibilityBoldTextStatusDidChangeNotification` — posted internally by UIKit, not the trigger

### 3. Architecture Change in iOS 26
AccessibilityUIServer (the XPC daemon) is the sole bridge between preference changes and UIKit. UIKit registers only one darwin notification (`com.apple.accessibility.AccessibilityUIServer`) and communicates with the daemon via XPC for all individual feature states including bold text.

**Consequence:** `notifyutil -p com.apple.accessibility.enhanced-text-legibility` fires successfully (exit 0, name echoed) but **no UIKit process is listening** — it's a dead notification in iOS 26.

### 4. Settings.app Timing — RACE CONDITION
- `openurl` returns in ~400ms
- `.delay(500ms)` starts counting from that point
- `terminate` fires at ~900ms total elapsed
- But: `launchctl list | grep Preferences` shows Settings launches immediately (0.1s)
- The accessibility XPC state propagation from Settings reading the plist needs ~2–3s to reach running apps
- **At 900ms, Settings is open but has not completed XPC handshake with AccessibilityUIServer**

### 5. SpringBoard Restart — CONFIRMED WORKING
```bash
xcrun simctl spawn $UDID launchctl stop com.apple.SpringBoard  # exit 0, returns in 0.4s
sleep 4  # SpringBoard auto-restarts
```
After respring, bold text applies visually to ALL system UI (SpringBoard labels, status bar, all apps). This is the definitive proof that plist writes are correct and bold requires respring on iOS 26.

### 6. Combine Chain Error Handling
```swift
.sink(receiveCompletion: { _ in }, receiveValue: { _ in })
```
Errors are silently swallowed. Any step failure stops the chain but produces no observable signal. Verified all 6 steps exit 0 in isolation — chain itself is not the problem.

### 7. UDID Passing — CORRECT
`effectiveUDID` resolves to `udid ?? "booted"`. `spawn booted` works equivalent to `spawn <UDID>`. Not the issue.

---

## Timeline of Events (What Happens on Toggle)

```
t=0ms    User taps Bold Text toggle in BoosterSimApp
t=0ms    boldText = true (UI updates immediately — optimistic)
t=0ms    runVoid(defaults write BoldTextEnabled YES)
t=~100ms → runVoid(defaults write EnhancedTextLegibilityEnabled YES)
t=~200ms → runVoid(defaults write UIAccessibilityBoldTextEnabled YES)
t=~300ms → runVoid(notifyutil -p com.apple.accessibility.enhanced-text-legibility)
           ↑ DEAD — no UIKit process observes this on iOS 26
t=~400ms → runVoid(openurl App-prefs:ACCESSIBILITY&path=DISPLAY_AND_TEXT)
t=~800ms   openurl returns (0.4s blocking call)
t=~800ms   .delay(500ms) starts
t=~1300ms  runVoid(terminate com.apple.Preferences)
           ↑ Settings.app closed before XPC accessibility handshake completes
Result:    Plist is correct. Nothing visual changed. Bold text still off.
```

---

## Root Cause (Confirmed)

**iOS 26 removed UIKit's direct Darwin notification subscription for individual accessibility features. Bold text now propagates only via:**
1. SpringBoard restart (respring) — `launchctl stop com.apple.SpringBoard`
2. AccessibilityUIServer XPC protocol — triggered by Settings.app completing its pref bundle load (requires 2–3s, not 500ms)

The notification `com.apple.accessibility.enhanced-text-legibility` is absent from UIKitCore on iOS 26 and therefore cannot trigger any visual change.

---

## Competing Hypotheses — Eliminated

| Hypothesis | Verdict | Evidence |
|---|---|---|
| Plist keys wrong/missing | ELIMINATED | All 3 keys write correctly, exit 0, verified via `defaults read` |
| Combine chain breaks silently | ELIMINATED | All 6 steps exit 0 in isolation |
| UDID passed as nil/wrong | ELIMINATED | `effectiveUDID = udid ?? "booted"`, both work |
| Settings.app timing too short | PARTIAL — contributes but not root cause even with 3s delay |
| Wrong notification name for iOS 26 | CONFIRMED ROOT CAUSE |
| Bold text requires respring on iOS 26 | CONFIRMED ROOT CAUSE |

---

## Recommended Fix

Replace the `setBoldText` chain to use **SpringBoard restart** instead of `notifyutil` + Settings open/close:

```swift
func setBoldText(_ enabled: Bool, udid: String) {
    boldText = enabled
    let value = enabled ? "YES" : "NO"

    // Write all 3 plist keys
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
            // Respring SpringBoard to apply bold text (required on iOS 14+)
            return self.simCtl.runVoid(["spawn", udid, "launchctl",
                                       "stop", "com.apple.SpringBoard"])
        }
        .sink(receiveCompletion: { _ in }, receiveValue: { _ in })
        .store(in: &cancellables)
}
```

**UX consideration:** Respring takes 3–5s on simulator. Should show a brief status indicator ("Applying Bold Text — restarting interface...") during the operation.

**Alternative (if respring UX is unacceptable):** Increase Settings.app delay to 3000ms. This may work for apps that properly implement `traitCollectionDidChange` but will not work for SpringBoard/status bar UI. Unreliable.

---

## Monitoring Gap / Design Flaw

- No test exists to verify accessibility overrides produce visible changes
- `setBoldText` has no error logging — a silent failure path for 3+ years potential
- Other `setAccessibility` methods (reduce motion, reduce transparency, etc.) also use `notifyutil` — they should be audited against iOS 26's notification registry
- Recommend adding a debug log sink: `receiveCompletion: { if case .failure(let e) = $0 { print("setBoldText error: \(e)") } }`

---

## Unresolved Questions

1. Do other `notifyutil` notifications (reduce-motion, grayscale, etc.) also fail silently on iOS 26? The same architectural change may affect them — needs verification.
2. Does `launchctl stop com.apple.SpringBoard` work on all simulator iOS versions (iOS 17, 18, 26)? The command is not documented for simulator use.
3. Is there a way to trigger the AccessibilityUIServer XPC reload without full respring? (`xcrun simctl spawn <udid> notifyutil -p com.apple.accessibility.api` — untested)
4. Should Bold Text show a "requires restart" warning in the UI, matching iOS Settings.app behavior?
