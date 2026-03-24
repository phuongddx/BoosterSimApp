# Phase 04 — Apple Watch Simulator Support

**Priority:** P1 | **Status:** Complete | **Effort:** 3h

**Context:** [Plan](./plan.md) | [Phase 01](./phase-01-simctl-service-foundation.md)

## Overview

Extend simulator detection to classify device types (iOS, watchOS, tvOS, visionOS). Watch Simulator windows appear as standard `Simulator.app` windows — already captured by `WindowEnumerator`. We add classification logic and adapt the UI accordingly.

## Key Insights

- `xcrun simctl list devices --json` returns `deviceTypeIdentifier` per device:
  - Watch: contains `"Watch"` → `com.apple.CoreSimulator.SimDeviceType.Apple-Watch-Series-11-46mm`
  - TV: contains `"TV"`
  - Vision: contains `"XR"` or `"Vision"`
  - iOS: everything else
- `productFamily` field: `"Apple Watch"` / `"iPhone"` / `"Apple TV"` / `"Apple Vision Pro"`
- Match booted devices against `CGWindowListCopyWindowInfo` by device name (window title == device name, e.g., "Apple Watch Series 11 (46mm)")
- Watch Simulator windows are visually smaller (≈200×240 pt) but same `kCGWindowOwnerName == "Simulator"`
- `xcrun simctl list devices --json` call: run every 5s (same interval as polling) OR on `NSWorkspace.didLaunchApplicationNotification` for Simulator

## Requirements

- `SimulatorWindow` model gains `deviceType: SimulatorDeviceType` field
- `SimulatorWindowTracker` classifies each window on detection
- Side panel `DeviceHeaderView` shows appropriate SF Symbol (applewatch, tv, visionpro, iphone)
- Feature sections that are irrelevant to Watch are hidden/disabled:
  - Hide: Camera, Push Notification, Locale switcher
  - Show: Status Bar (watchOS status bar is limited but simctl still works), Environment Overrides
- Multi-device picker if multiple simulators running (iOS + Watch at same time)

## Architecture

**Model change** (`SimulatorWindow.swift`):
```swift
enum SimulatorDeviceType: String, Codable, Sendable {
    case iOS, watchOS, tvOS, visionOS

    var sfSymbol: String {
        switch self {
        case .iOS: return "iphone"
        case .watchOS: return "applewatch"
        case .tvOS: return "tv"
        case .visionOS: return "visionpro"
        }
    }
}

struct SimulatorWindow {
    // existing fields...
    var deviceType: SimulatorDeviceType = .iOS  // NEW
}
```

**Device type resolution** (new private method in `SimulatorWindowTracker`):
```swift
// Cache from simctl list — refresh every 5s or on Simulator launch
private var deviceTypeCache: [String: SimulatorDeviceType] = [:]  // keyed by device name

private func refreshDeviceTypeCache() {
    // runs simctl list devices --json on background queue
    // parses deviceTypeIdentifier: contains "Watch" → .watchOS, etc.
    // maps device name → device type
}

private func classifyDevice(named name: String) -> SimulatorDeviceType {
    deviceTypeCache[name] ?? .iOS
}
```

**UI changes:**
- `DeviceHeaderView`: replace static "iPhone" icon with `Image(systemName: deviceType.sfSymbol)`
- `SideWindowView`: pass `deviceType` to feature sections; each section accepts optional `deviceType` and hides irrelevant rows

## Related Code Files

| File | Action | Description |
|------|--------|-------------|
| `Models/SimulatorWindow.swift` | Modify | Add `SimulatorDeviceType` enum + `deviceType` field |
| `Services/SimulatorWindowTracker.swift` | Modify | Add `refreshDeviceTypeCache()`, `classifyDevice(named:)`, wire into scan loop |
| `Views/SideWindow/DeviceHeaderView.swift` | Modify | Dynamic SF Symbol based on `deviceType` |
| `Views/SideWindow/SideWindowView.swift` | Modify | Pass `deviceType` to sections; device picker if multiple sims |
| `Views/SideWindow/FeatureSectionView.swift` | Modify | Accept optional `hiddenForDeviceType: SimulatorDeviceType` |

## Implementation Steps

1. **Model:** Open `SimulatorWindow.swift`
   - Add `SimulatorDeviceType` enum (raw `String`, `Codable`, `Sendable`) with `sfSymbol` computed var
   - Add `var deviceType: SimulatorDeviceType = .iOS` to `SimulatorWindow` struct

2. **Tracker — cache:** Open `SimulatorWindowTracker.swift`
   - Add `private var deviceTypeCache: [String: SimulatorDeviceType] = [:]`
   - Add `private func refreshDeviceTypeCache()`:
     - Runs `simCtlService.run(["list", "devices", "--json"])` via Combine
     - Parses JSON: `devices` dict → iterate all runtimes → all devices
     - For each device: check `deviceTypeIdentifier` for "Watch"/"TV"/"XR"/"Vision"
     - Map `device.name → deviceType` into cache
   - Call `refreshDeviceTypeCache()` in `startTracking()` and on `NSWorkspace.didLaunchApplicationNotification`

3. **Tracker — classification:** In `WindowEnumerator`/scan loop where `SimulatorWindow` is created, set `.deviceType = classifyDevice(named: window.deviceName)`

4. **DeviceHeaderView:** Replace hardcoded `iphone` symbol with `Image(systemName: tracker.activeSimulator?.deviceType.sfSymbol ?? "iphone")`

5. **SideWindowView:** If `simulators.count > 1`, show device picker (segmented control or menu) above feature sections

6. **Feature visibility:** Add `var isHiddenForWatch: Bool` to relevant `FeatureRowView` entries; wrap in `if deviceType != .watchOS` where needed

7. Build + test: boot a Watch simulator, confirm detection + correct icon

## Todo

- [x] Add `SimulatorDeviceType` enum + `deviceType` to `SimulatorWindow.swift`
- [x] Add `deviceTypeCache` + `refreshDeviceTypeCache()` to tracker
- [x] Wire cache refresh on startup + simulator launch notification
- [x] Classify windows during scan/detection
- [x] Update `DeviceHeaderView` — dynamic SF Symbol
- [x] Update `SideWindowView` — multi-device picker
- [x] Hide Watch-irrelevant feature rows
- [x] Build + test with booted Watch simulator

## Success Criteria

- Watch Simulator window detected and `deviceType == .watchOS`
- `applewatch` SF Symbol shown in panel header when Watch active
- Camera/Push rows hidden for Watch
- iOS simulators still work exactly as before
- No regressions in existing detection logic

## Risk Assessment

| Risk | Mitigation |
|------|-----------|
| Device name in CGWindowList doesn't match simctl `name` exactly | Use `.contains` or normalize whitespace; log mismatches |
| `simctl list --json` format changes | Wrap parse in `do/catch`; fallback `.iOS` on failure |
| Both iOS + Watch booted: which is "active"? | Active = most recently focused (existing `activeSimulator` logic); Watch shown separately in picker |
| Tracker grows past 200 LOC with new methods | Extract `SimCtlDeviceClassifier` helper if needed |

## Next Steps

Phase 05 (Build Stats) is independent of device type — can proceed after this completes.
