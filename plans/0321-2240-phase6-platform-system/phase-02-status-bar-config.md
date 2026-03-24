# Phase 02 — Status Bar Config

**Priority:** P1 | **Status:** Complete | **Effort:** 2h

**Context:** [Plan](./plan.md) | [Phase 01](./phase-01-simctl-service-foundation.md)

## Overview

Configurable status bar via `xcrun simctl status_bar`. Preset system (Screenshot-ready, Low Battery, No Signal) + Custom expander. Per-UDID config persisted in `AppSettings`.

## Key Insights

**Verified simctl API** (`xcrun simctl status_bar <udid> override`):
- `--time <string>` | `--dataNetwork` (wifi/3g/4g/lte/5g/5g+/5g-uwb/5g-uc/hide)
- `--wifiMode` (searching/failed/active) | `--wifiBars` (0-3)
- `--cellularMode` (notSupported/searching/failed/active) | `--cellularBars` (0-4)
- `--operatorName <string>` | `--batteryState` (charging/charged/discharging) | `--batteryLevel` (0-100)
- `xcrun simctl status_bar <udid> clear` — reset all overrides
- `xcrun simctl status_bar <udid> list` — read current overrides

**Preset definitions:**
- "Screenshot Ready": `--time "9:41" --wifiBars 3 --wifiMode active --cellularBars 4 --cellularMode active --batteryState charged --batteryLevel 100`
- "Low Battery": `--batteryLevel 9 --batteryState discharging`
- "No Signal": `--cellularMode searching --cellularBars 0 --wifiMode failed --wifiBars 0`
- "Custom": reveals individual controls

## Requirements

- Apply preset in <500ms (simctl is fast for status_bar)
- Per-UDID persistence: store last-applied preset + custom values
- "Apply on Attach" toggle — auto-apply on simulator detection
- "Clear Overrides" button — calls `simctl status_bar <udid> clear`
- Custom mode: time text field, battery slider (0–100), network pickers
- Disable controls when no active simulator

## Architecture

```
StatusBarService           — builds args arrays, calls SimCtlService
StatusBarSectionView       — section UI (replaces "Coming soon" row)
  └── StatusBarPresetRow   — 4 preset buttons (private sub-view)
  └── StatusBarCustomView  — collapsible custom controls (private sub-view)
```

**`StatusBarConfig` model** (Codable for AppStorage):
```swift
struct StatusBarConfig: Codable, Equatable {
    var time: String = "9:41"
    var batteryLevel: Int = 100
    var batteryState: String = "charged"    // charging | charged | discharging
    var wifiBars: Int = 3
    var wifiMode: String = "active"         // searching | failed | active
    var cellularBars: Int = 4
    var cellularMode: String = "active"
    var dataNetwork: String = "wifi"        // wifi | 5g | lte | 4g | 3g | hide
    var operatorName: String = ""
}
```

**`StatusBarService`:**
```swift
@MainActor final class StatusBarService: ObservableObject {
    @Published var isApplying = false
    @Published var lastError: String?

    private let simCtl: SimCtlService

    func applyPreset(_ preset: StatusBarPreset, to udid: String)
    func applyCustom(_ config: StatusBarConfig, to udid: String)
    func clearOverrides(for udid: String)
    private func buildArgs(from config: StatusBarConfig) -> [String]
}
```

## Related Code Files

| File | Action | Description |
|------|--------|-------------|
| `Services/StatusBarService.swift` | Create | Preset/config logic + simctl calls |
| `Views/SideWindow/StatusBarSectionView.swift` | Create | Section UI (~100 LOC) |
| `Models/AppSettings.swift` | Modify | Add `statusBarConfig: [String: Data]` (@AppStorage, UDID-keyed) |
| `App/AppDelegate.swift` | Modify | Own `StatusBarService`, inject into side window view |
| `Views/SideWindow/SideWindowView.swift` | Modify | Replace "Platform" Coming-soon section with `StatusBarSectionView` |

## Implementation Steps

1. Define `StatusBarConfig` struct (Codable) and `StatusBarPreset` enum in `StatusBarService.swift`
2. Implement `StatusBarService` — `buildArgs(from:)` converts config to simctl flag array
3. `applyPreset` → map preset to `StatusBarConfig` → call `simCtl.runVoid(["status_bar", udid] + args)`
4. `clearOverrides` → `simCtl.runVoid(["status_bar", udid, "clear"])`
5. Add `@AppStorage` key to `AppSettings` for per-UDID JSON storage
6. Create `StatusBarSectionView.swift`:
   - 4 preset buttons in HStack (SF Symbol + label each)
   - "Clear" button
   - Disclosure group for Custom controls
7. Wire `StatusBarService` to `AppDelegate` and inject into `SideWindowView`
8. Build + test with a booted simulator

## Todo

- [x] Create `StatusBarService.swift` with `StatusBarConfig`, `StatusBarPreset`, service class
- [x] Implement `buildArgs(from:)` mapping all config fields to simctl flags
- [x] Implement `applyPreset`, `applyCustom`, `clearOverrides`
- [x] Add `statusBarConfig` storage to `AppSettings`
- [x] Create `StatusBarSectionView.swift` — presets + custom expander
- [x] Wire into `AppDelegate` + `SideWindowView`
- [x] Build + manual test: apply each preset, verify Simulator status bar changes

## Success Criteria

- All 4 presets apply visible changes in Simulator within 1s
- Custom controls update individual values
- "Clear" resets status bar to default
- No Swift 6 concurrency warnings
- Both service files under 100 LOC, view under 120 LOC

## Risk Assessment

| Risk | Mitigation |
|------|-----------|
| UDID not available when no simulator | Disable all controls; show "No simulator detected" |
| `AppStorage` JSON encode/decode failure | Use `try?` with silent fallback to defaults |
