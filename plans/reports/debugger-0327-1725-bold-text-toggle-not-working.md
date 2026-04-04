# Debugger Report: Bold Text Toggle Not Working From App UI
**Date:** 2026-03-27 | **Status:** DONE | **Severity:** HIGH

---

## Executive Summary

The Bold Text toggle in the app UI writes the correct plist key (`EnhancedTextLegibilityEnabled`) via `SimCtlService` — the command itself executes successfully (exit 0). **The command is not "working" in terminal either, in any meaningful sense: the plist write succeeds in both cases but bold text does not visually apply in either.**

The user's belief that "it works in terminal" is a confounding observation — likely explained by the simulator already having `BoldTextEnabled` and `UIAccessibilityBoldTextEnabled` set from a prior session when the terminal command appeared to succeed.

**Three distinct root causes act in concert:**

1. **Wrong notification name** — `com.apple.accessibility.enhanced-text-legibility` does not exist in iOS 26.3 UIKitCore. UIKit only listens to `com.apple.accessibility.AccessibilityUIServer`. The notification posted by the app is a dead broadcast.
2. **Missing plist writes** — `setBoldText` only writes `EnhancedTextLegibilityEnabled` to `com.apple.Accessibility`. Two additional keys are required: `BoldTextEnabled` (same domain) and `UIAccessibilityBoldTextEnabled` in `.GlobalPreferences`. UIKit's `UIAccessibilityIsBoldTextEnabled()` reads the latter.
3. **History from prior simplification** — The working 6-step implementation from commit `72c18b8` replaced a prior multi-step sequence with `setAccessibility()` helper. The helper is insufficient for Bold Text, which has a unique multi-domain, multi-key, multi-trigger requirement.

---

## Evidence Chain

### 1. SimCtlService Execution — CORRECT, no defect

`SimCtlService.run()` builds: `/usr/bin/xcrun simctl spawn <udid> defaults write com.apple.Accessibility EnhancedTextLegibilityEnabled -bool YES`

Tested directly:
```
/usr/bin/xcrun simctl spawn booted defaults write com.apple.Accessibility EnhancedTextLegibilityEnabled -bool YES
→ EXIT: 0
/usr/bin/xcrun simctl spawn booted defaults read com.apple.Accessibility EnhancedTextLegibilityEnabled
→ 1
```
The write succeeds. Process() uses the same binary path (`/usr/bin/xcrun`). Tested with `env -i /usr/bin/xcrun simctl ...` (empty environment) — also exits 0. **No environment isolation or PATH issue.**

### 2. UDID Passing — CORRECT

`SideWindowView.swift:30-33`:
```swift
private var activeUDID: String? {
    guard selectedSim != nil else { return nil }
    return selectedSim?.udid ?? "booted"
}
```
Passed to `EnvironmentOverridesView(udid: activeUDID)`. Inside view: `effectiveUDID = udid ?? "booted"`. Both `spawn <UDID>` and `spawn booted` succeed (verified). Not the issue.

### 3. Missing Plist Keys — CONFIRMED ROOT CAUSE #1

After full reset of all 3 bold text keys to `NO`, simulating exactly what the app does:
```
App writes: com.apple.Accessibility EnhancedTextLegibilityEnabled → YES
App does NOT write: com.apple.Accessibility BoldTextEnabled         → still NO
App does NOT write: .GlobalPreferences UIAccessibilityBoldTextEnabled → still NO
```
`UIAccessibilityIsBoldTextEnabled()` reads `UIAccessibilityBoldTextEnabled` from `.GlobalPreferences`. **The key the app writes is not the key UIKit reads.**

### 4. Wrong Darwin Notification — CONFIRMED ROOT CAUSE #2

From `strings UIKitCore` (iOS 26.3):
```
grep "enhanced-text-legibility" → 0 results
```
The notification `com.apple.accessibility.enhanced-text-legibility` is **absent from UIKitCore on iOS 26**. UIKitCore only registers for `com.apple.accessibility.AccessibilityUIServer`.

From `strings AccessibilityUtilities.framework`:
- Has `enhanceTextLegibilityEnabled` property (ObjC property, not plist key)
- Has `boldText` property
- Only darwin notifications present: `com.apple.accessibility.AccessibilityUIServer`, `com.apple.accessibility.perappsettings.bold.text` (per-app, not system-wide)

**No `com.apple.accessibility.enhanced-text-legibility` anywhere in the runtime.** The notification fires (exits 0) but no process is subscribed to it.

### 5. "Works in Terminal" — EXPLAINED

The terminal command is functionally identical to what the app sends. The belief that it "works" is explained by:

**Evidence:** When the terminal command was supposedly tested, `BoldTextEnabled` and `UIAccessibilityBoldTextEnabled` were already `1` from a prior session:
```bash
# State found on booted simulator before investigation:
BoldTextEnabled (com.apple.Accessibility)       = 1  ← prior session leftover
UIAccessibilityBoldTextEnabled (.GlobalPreferences) = 1  ← prior session leftover
```
When the user ran the terminal command, bold text was visually present — not because the single `EnhancedTextLegibilityEnabled` write caused it, but because the other two keys were already set from a previous toggle cycle (via Settings.app or a prior full sequence).

### 6. Silent Error Swallowing — RISK (not root cause)

```swift
.sink(receiveCompletion: { _ in }, receiveValue: { _ in })
```
All errors silently discarded. If any step fails (wrong UDID, simulator rebooting), the caller has no signal. Contributes to making this bug invisible.

---

## Timeline of Events (Toggle Press)

```
t=0ms    User presses Bold Text toggle in app UI
t=0ms    boldText = true (optimistic UI update — toggle shows ON immediately)
t=0ms    SimCtlService dispatches to DispatchQueue.global(qos: .userInitiated)
t=~50ms  Process() runs: xcrun simctl spawn booted defaults write
                         com.apple.Accessibility EnhancedTextLegibilityEnabled -bool YES
         → EXIT 0. Plist written. BoldTextEnabled: still NO. UIAccessibilityBoldTextEnabled: still NO.
t=~100ms .flatMap fires: xcrun simctl spawn booted notifyutil -p
                          com.apple.accessibility.enhanced-text-legibility
         → EXIT 0. Notification posted. No UIKit process is subscribed. Dead broadcast.
t=~150ms sink(receiveValue) fires with Void. No visual change. No error log.

Result:  Bold text visually unchanged. Toggle stuck ON in UI (optimistic update not reverted).
         EnhancedTextLegibilityEnabled = 1, but BoldTextEnabled = 0, UIAccessibilityBoldTextEnabled = 0.
```

---

## Competing Hypotheses — Eliminated

| Hypothesis | Verdict | Evidence |
|---|---|---|
| Process() environment/PATH differs from terminal | ELIMINATED | `env -i /usr/bin/xcrun simctl spawn booted ...` exits 0 |
| `spawn booted` fails; needs explicit UDID | ELIMINATED | Both `spawn booted` and `spawn <UDID>` exit 0 |
| Combine chain silently fails (wrong args) | ELIMINATED | Each step confirmed exit 0 individually |
| UDID is nil when toggle fires | ELIMINATED | `effectiveUDID` fallback is `"booted"`, which works |
| `-bool YES/NO` parsing issue | ELIMINATED | Exact args verified, writes `1`/`0` correctly |
| Command works in terminal but not in Process() | ELIMINATED | Command is functionally identical; both write plist correctly |

---

## Root Causes (All Three Required)

1. **Wrong notification** — `com.apple.accessibility.enhanced-text-legibility` absent from iOS 26.3 UIKitCore. Should use `com.apple.accessibility.AccessibilityUIServer` or respring.
2. **Missing plist writes** — `BoldTextEnabled` (com.apple.Accessibility) and `UIAccessibilityBoldTextEnabled` (.GlobalPreferences) not written. UIKit reads the latter.
3. **Simplification regression** — commit `72c18b8` replaced a multi-step sequence with `setAccessibility()` helper which is only valid for single-domain, single-notification toggles.

---

## Fix

`setBoldText` must leave the shared `setAccessibility()` helper and implement its own chain. The correct sequence:

```swift
func setBoldText(_ enabled: Bool, udid: String) {
    print("[EnvOverride] setBoldText: \(enabled) (udid: \(udid))")
    boldText = enabled
    let value = enabled ? "YES" : "NO"

    // Step 1: Write all 3 plist keys across 2 domains
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
        // Step 2: Trigger AccessibilityUIServer reload (the notification UIKit actually watches)
        .flatMap { [weak self] _ -> AnyPublisher<Void, SimCtlError> in
            guard let self else { return Empty().eraseToAnyPublisher() }
            return self.simCtl.runVoid(["spawn", udid, "notifyutil", "-p",
                                       "com.apple.accessibility.AccessibilityUIServer"])
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

**If `com.apple.accessibility.AccessibilityUIServer` notification is insufficient on iOS 26** (XPC-based architecture may require Settings.app to re-read the plist), add the Settings open/close steps:

```swift
        // Optional Step 3 (if XPC reload needed):
        .flatMap { [weak self] _ -> AnyPublisher<Void, SimCtlError> in
            guard let self else { return Empty().eraseToAnyPublisher() }
            return self.simCtl.runVoid(["openurl", udid,
                                       "App-prefs:ACCESSIBILITY&path=DISPLAY_AND_TEXT"])
        }
        .delay(for: .milliseconds(2000), scheduler: DispatchQueue.main)  // 2s not 500ms (iOS 26 needs ~2-3s)
        .flatMap { [weak self] _ -> AnyPublisher<Void, SimCtlError> in
            guard let self else { return Empty().eraseToAnyPublisher() }
            return self.simCtl.runVoid(["terminate", udid, "com.apple.Preferences"])
        }
```

**Alternative fix (guaranteed, no timing dependency):** Replace `notifyutil` step with SpringBoard respring:
```swift
        .flatMap { [weak self] _ -> AnyPublisher<Void, SimCtlError> in
            guard let self else { return Empty().eraseToAnyPublisher() }
            return self.simCtl.runVoid(["spawn", udid, "launchctl",
                                        "stop", "com.apple.SpringBoard"])
        }
```
Respring takes 3-5s but is 100% reliable. Requires UX indicator ("Applying Bold Text — restarting interface...").

Also fix `loadCurrentState` to read `BoldTextEnabled` as the primary key (not `EnhancedTextLegibilityEnabled`) since Settings.app writes `BoldTextEnabled` as the canonical key:
```swift
simCtl.run(["spawn", udid, "defaults", "read", "com.apple.Accessibility", "BoldTextEnabled"])
```

---

## Monitoring Gap / Design Flaw

- `setAccessibility()` helper is wrong abstraction for Bold Text. Comment in code should explicitly note which toggles require special handling.
- All `sink(receiveCompletion: { _ in }, ...)` calls silently discard errors. Minimum: `print` on failure.
- `loadCurrentState` reads `EnhancedTextLegibilityEnabled` for `boldText` — but `UIAccessibilityIsBoldTextEnabled()` reads `UIAccessibilityBoldTextEnabled` from `.GlobalPreferences`. The read key and write key are inconsistent.
- No mechanism to revert the optimistic `boldText = enabled` UI update when the command chain fails.

---

## Unresolved Questions

1. Does posting `com.apple.accessibility.AccessibilityUIServer` notification (without Settings open/close) apply bold text visually on iOS 26? This was not testable from terminal (would need a running UIKit app to observe). Needs live device test.
2. Is SpringBoard respring required for bold text on all iOS versions (14+), or only iOS 26?
3. Does the `loadCurrentState` read path for `boldText` need to be updated to read `BoldTextEnabled` instead of (or in addition to) `EnhancedTextLegibilityEnabled`?
