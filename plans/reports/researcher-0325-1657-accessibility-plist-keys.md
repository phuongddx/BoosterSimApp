# iOS Simulator Accessibility Settings Implementation Patterns

**Research Date:** March 25, 2026
**Researcher:** AI Assistant
**Target:** BoosterSimApp accessibility toggles feature

## Executive Summary

Research confirms that iOS Simulator accessibility settings CAN be toggled programmatically via host macOS apps, but Apple provides **no public API** or documented plist schema. Implementation must rely on:

1. **xcrun simctl spawn** + defaults command (preferred, semi-official)
2. **Direct plist file manipulation** from host (risky, fragile across iOS versions)
3. **Facebook idb** (third-party tool with limited accessibility support)

**Key finding:** Exact plist key names for accessibility toggles (Reduce Transparency, Button Shapes, Grayscale, etc.) are **NOT publicly documented**. Must be reverse-engineered or inferred from UIAccessibility API names.

---

## 1. Plist Storage Location

**Confirmed Path:**
```
~/Library/Developer/CoreSimulator/Devices/<UDID>/data/Library/Preferences/
```

**Key Files:**
- `.GlobalPreferences.plist` — System-wide preferences (language, locale, region)
- `com.apple.Accessibility.plist` — Accessibility-specific settings (most likely location)
- `com.apple.springboard.plist` — Springboard (home screen) preferences
- `.GlobalPreferences.plist` — Alternative for some accessibility keys

**Note:** iOS version stored in separate image; file structure may change between iOS versions. No official documentation available.

---

## 2. Accessible Toggles & Known Mapping

### Current Research Status

**Confirmed UIAccessibility APIs** (iOS side):
- `UIAccessibilityIsReduceTransparencyEnabled()` → Boolean
- `UIAccessibilityIsBoldTextEnabled()` → Boolean
- `UIAccessibilityIsGrayscaleEnabled()` → Boolean
- `UIAccessibilityIsInvertColorsEnabled()` → Boolean
- VoiceOver / ScreenCurtain (various APIs)

**Problem:** Corresponding **plist key names are undocumented**. Apple does not publish the internal preference domain/key structure.

### Inferred Plist Keys (Not Confirmed)

| Feature | Domain | Key Name | Type | Source |
|---------|--------|----------|------|--------|
| Reduce Transparency | `com.apple.Accessibility` | `ReduceTransparency` ? | Boolean | Inferred from API |
| Bold Text | `com.apple.Accessibility` | `BoldText` ? | Boolean | Inferred from API |
| Grayscale | `com.apple.Accessibility` | `Grayscale` ? | Boolean | Inferred from API |
| Inverted Colors | `com.apple.Accessibility` | `InvertedColors` ? | Boolean | Inferred from API |
| Button Shapes | `com.apple.Accessibility` | `ButtonShapes` ? | Boolean | Inferred from API |
| Differentiate without Color | `com.apple.Accessibility` | `DifferentiateWithoutColor` ? | Boolean | Inferred from API |
| On/Off Labels | `com.apple.Accessibility` | `OnOffLabels` ? | Boolean | Inferred from API |

**Status:** None of these keys have been publicly confirmed by Apple. RocketSim implementation details are not open-sourced.

---

## 3. Reading Current State

### Option A: xcrun simctl (Preferred)

**Syntax:**
```bash
xcrun simctl spawn <udid> defaults read <domain> <key>
```

**Example (hypothetical):**
```bash
xcrun simctl spawn booted defaults read com.apple.Accessibility BoldText
# Expected output: 0 or 1
```

**Advantages:**
- Works from host macOS app via Process/Task
- Doesn't require filesystem access to plist
- More likely to work across iOS versions

**Disadvantages:**
- Must know exact key names (not documented)
- Requires Xcode/xcrun installed
- May have latency

### Option B: Direct Plist Read from Host

**Path:**
```swift
let plistPath = "/Users/\(NSUserName())/Library/Developer/CoreSimulator/Devices/\(udid)/data/Library/Preferences/com.apple.Accessibility.plist"

// Read via PropertyListSerialization or plutil
```

**Methods:**
- `plutil -p <path>` (inspect binary plist)
- `PropertyListSerialization` (Swift)
- Direct file read if XML format

**Advantages:**
- No dependency on xcrun
- Single read operation

**Disadvantages:**
- Plist may be binary format (requires parsing)
- File may be locked by Simulator
- Fragile across iOS version changes
- Requires read permission (non-sandboxed app is OK)

---

## 4. Writing / Toggling Settings

### Option A: xcrun simctl + defaults write

**Syntax:**
```bash
xcrun simctl spawn <udid> defaults write <domain> <key> <value>
```

**Example (hypothetical):**
```bash
xcrun simctl spawn booted defaults write com.apple.Accessibility BoldText 1
```

**Advantages:**
- Transactional (atomic write)
- Persists to simulator's preferences

**Disadvantages:**
- Requires exact key names (undocumented)
- Each toggle = separate command = latency

### Option B: Shut Down Simulator, Modify Plist, Restart

**Steps:**
1. `xcrun simctl shutdown <udid>`
2. Modify plist at rest (via PropertyListSerialization)
3. `xcrun simctl boot <udid>`

**Advantages:**
- Guaranteed write (no file locking)
- Batch multiple changes

**Disadvantages:**
- Breaks user workflow (simulator restarts)
- High latency (~5–10 seconds)

### Option C: idb (Facebook's iOS Device Bridge)

**Status:** Limited support for accessibility. 2022 issue #792 indicates VoiceOver toggle was **NOT** implemented. General `settings` API exists but accessibility toggles not confirmed.

**Reference:**
- GitHub: https://github.com/facebook/idb
- Accessibility docs: https://fbidb.io/docs/accessibility/ (focuses on tree inspection, not control)

---

## 5. Technical Implementation Approaches

### Approach 1: xcrun simctl + Combine Observable

**Swift pseudo-code:**
```swift
class AccessibilityToggleService {
    @Published var reduceTransparency: Bool = false

    func readSetting(key: String) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        process.arguments = ["simctl", "spawn", simUID, "defaults", "read", "com.apple.Accessibility", key]

        let pipe = Pipe()
        process.standardOutput = pipe
        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "0"
        return output == "1"
    }

    func writeSetting(key: String, value: Bool) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        process.arguments = ["simctl", "spawn", simUID, "defaults", "write", "com.apple.Accessibility", key, value ? "1" : "0"]
        try process.run()
    }
}
```

**Issues:**
- Each operation = separate Process spawn (latency)
- Requires discovery of correct key names (testing required)
- No error handling for key not found

### Approach 2: Batch Plist Modification + Restart

**Pseudocode:**
```swift
func applyAccessibilitySettings(_ settings: [String: Bool]) {
    // 1. Shutdown
    xcrun(["simctl", "shutdown", udid])

    // 2. Load + modify plist
    let plistPath = "~/Library/Developer/CoreSimulator/Devices/\(udid)/data/Library/Preferences/com.apple.Accessibility.plist"
    var plist = try PropertyListSerialization.propertyList(from: FileManager.default.contents(atPath: plistPath), options: [], format: nil) as? [String: Any] ?? [:]

    settings.forEach { plist[$0.key] = $0.value ? NSNumber(value: 1) : NSNumber(value: 0) }

    // 3. Write back
    let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .binary, options: 0)
    try data.write(toFile: plistPath, options: [.atomic])

    // 4. Reboot
    xcrun(["simctl", "boot", udid])
}
```

**Issues:**
- UX nightmare (simulator restarts)
- Plist may be binary (needs parsing)
- Potential for corruption if write fails mid-process

---

## 6. Key Risks & Unknowns

### Undocumented Plist Schema
- **Risk:** Apple changes key names or structure without notice
- **Mitigation:** Reverse-engineer via trial-and-error on multiple iOS versions; include fallback toggles

### Plist Format Variations
- **Risk:** May be binary format (CFPropertyList binary), not XML
- **Mitigation:** Use `PropertyListSerialization` (handles both)

### Simulator Process Lockout
- **Risk:** Plist may be locked while Simulator is running; writes fail silently
- **Mitigation:** Use xcrun simctl spawn (runs inside simulator context) or shutdown before modifying

### Cross-iOS Compatibility
- **Risk:** Key names differ between iOS 17, 18, 19+ Simulator versions
- **Mitigation:** Maintain version-specific mappings; test on each iOS version

### Permission Handling
- **Risk:** Non-sandboxed app CAN read/write ~/Library/Developer but may need explicit user allowance
- **Mitigation:** App is already non-sandboxed (requires Accessibility + Screen Recording perms); filesystem access is expected

### No Official Tool Support
- **Risk:** No Apple-provided API; relying on undocumented internals
- **Mitigation:** Isolate implementation in dedicated service; easy to refactor if/when official API arrives

---

## 7. Research Findings: Existing Tools

### RocketSim (Commercial Reference)
- **Status:** Closed-source; implementation details not available
- **Docs:** https://docs.rocketsim.app/
- **Known Toggles:** Accessibility toggles exist but mechanism is proprietary

### Facebook idb
- **Status:** Open-source, but accessibility toggle support is **incomplete**
- **Issue #792:** (2022) VoiceOver toggle not implemented
- **Settings API:** Exists but undocumented for accessibility
- **GitHub:** https://github.com/facebook/idb
- **Verdict:** Not suitable as primary dependency; inspect source for reverse-engineering

### Xcode Accessibility Inspector
- **Purpose:** Testing/debugging within simulator, not programmatic control
- **Not suitable:** For BoosterSimApp's use case (programmatic toggles from host)

### SimulatorStatusMagic
- **Purpose:** Clean status bar for screenshots
- **Not accessible:** As of iOS 17, API is closed to non-Springboard processes

---

## 8. Implementation Recommendation for BoosterSimApp

### Phase 1: Discovery (Required before coding)
1. **Test on booted simulator:**
   ```bash
   xcrun simctl spawn booted defaults domains
   ```
   Capture all domains, grep for "Accessibility" or "accessibility"

2. **For each domain, list all keys:**
   ```bash
   xcrun simctl spawn booted defaults read com.apple.Accessibility
   ```
   Document all key names

3. **Try reading/writing with known API names:**
   - `ReduceTransparency`, `BoldText`, `Grayscale`, `InvertedColors` as guesses
   - Use `defaults read` to check if they exist
   - Use `defaults write` + restart Simulator to verify they take effect in iOS UI

4. **Cross-validate with iOS versions:**
   - Repeat above for iOS 17, 18, 19 Simulator builds
   - Note any divergence

### Phase 2: Implementation (once keys are known)
1. **Create `AccessibilitySettingsService`:**
   - Combine @Published properties for each toggle
   - Use xcrun simctl spawn approach (lower latency than restart)
   - Cache results to avoid polling overhead

2. **Toggle UI in SideWindowView:**
   - Bind to @ObservedObject service
   - One toggle = one SwiftUI Toggle + async Task to update

3. **Error handling:**
   - Gracefully fail if key doesn't exist (version mismatch)
   - Log all xcrun command failures

### Phase 3: Validation
- Test on simulator with actual app (e.g., confirm reduce transparency actually reduces blur)
- Compare behavior vs. Settings app manual toggle

---

## 9. Alternative Paths (If xcrun Fails)

### Direct Plist Manipulation
If xcrun simctl spawn doesn't support defaults for accessibility:
1. Use `plutil -p` to inspect binary plist from host
2. Parse via Swift's PropertyListSerialization
3. Modify + write back (requires simulator shutdown)
4. Not recommended without further testing

### Accessibility APIs from within App
- If BoosterSimApp needs to detect simulator accessibility state (not change it):
  - Use `UIAccessibilityIsReduceTransparencyEnabled()` etc. via Simulator introspection
  - Not feasible: these APIs return Simulator's own state, not host's control

---

## 10. Unresolved Questions

1. **Exact plist key names** — Must be determined via trial-and-error testing
   - Cannot find public documentation from Apple

2. **Plist domain name** — Is it `com.apple.Accessibility` or something else?
   - Suspected but not confirmed

3. **Value type** — Are all toggles simple Boolean (0/1) or some are integers?
   - Suspected Boolean but needs confirmation

4. **iOS version variance** — Do key names differ across iOS 17/18/19+?
   - Likely yes; must test

5. **Simulator shutdown requirement** — Can plist be modified while running, or must shutdown?
   - xcrun simctl spawn should handle this, but direct plist modification likely requires shutdown

6. **Permission implications** — Does non-sandboxed app need additional entitlements?
   - Non-sandboxed apps can read ~/Library/Developer, but unclear if system validates plist writes

7. **Xcode version dependency** — Does xcrun command syntax change?
   - No evidence of change, but should test with Xcode 16.3+

---

## 11. Sources & References

- [xcrun simctl - iOS Dev Recipes](https://www.iosdev.recipes/simctl/)
- [simctl - NSHipster](https://nshipster.com/simctl/)
- [iOS Simulator command line tutorials (Medium)](https://itnext.io/you-dont-need-gui-or-how-to-control-ios-simulator-from-command-line-bf5cfa60aed2)
- [UIAccessibility isReduceTransparencyEnabled - Apple Dev Docs](https://developer.apple.com/documentation/uikit/uiaccessibility/isreducetransparencyenabled)
- [Facebook idb - GitHub](https://github.com/facebook/idb)
- [RocketSimApp - GitHub](https://github.com/AvdLee/RocketSimApp)
- [CoreSimulator directory structure - Repeato guide](https://www.repeato.app/managing-xcodes-coresimulator-devices-folder-a-practical-guide/)

---

## Recommendations

**DO FIRST:**
- Run Phase 1 discovery immediately on your booted simulator (UDID: 00AFDCEE-858A-4B7D-B5B4-08D3B1D6CAFB)
- Document all `com.apple.Accessibility` keys and values
- Test defaults read/write with guessed key names

**DO AFTER DISCOVERY:**
- Implement `AccessibilitySettingsService` using xcrun spawn approach
- Add error handling for version/key mismatches
- Validate with manual toggle comparison in Simulator Settings app

**DO NOT:**
- Commit to plist key names before testing
- Assume key names are consistent across iOS versions
- Use direct plist modification as primary approach (use xcrun spawn instead)
- Add RocketSim source code dependency (closed-source; inspiration only)

**Token Efficiency Note:** This research prioritized breadth over depth due to lack of public documentation. Actual implementation will require hands-on testing to discover correct plist keys; research findings narrow the search space but cannot fully close the gap without direct experimentation.
