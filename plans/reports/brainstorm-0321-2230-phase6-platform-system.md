# Brainstorm: Phase 6 — Platform & System

**Date:** 2026-03-21 | **Branch:** main

---

## Problem Statement

Implement all 6 Phase 6 features in BoosterSimApp:
1. Configurable status bar (time, battery, signal)
2. Simulator Camera (live Mac camera feed)
3. Apple Watch Simulator support
4. VoiceOver navigator (interactive accessibility tree)
5. Environment overrides (appearance, accessibility settings)
6. Xcode build statistics (build count, time graphs)

Constraints: Swift 6 strict concurrency, no external dependencies, Combine-only (no async/await), all `@MainActor` for UI, non-sandboxed app.

---

## Key Research Findings

### simctl APIs (verified via `xcrun simctl help`)

**Status bar** (`xcrun simctl status_bar <udid> override`):
- `--time <string>` | `--dataNetwork` (wifi/3g/4g/lte/5g/5g+/...) | `--wifiMode` | `--wifiBars` (0-3)
- `--cellularMode` | `--cellularBars` (0-4) | `--operatorName` | `--batteryState` | `--batteryLevel` (0-100)
- `list` and `clear` subcommands available

**UI overrides** (`xcrun simctl ui <device>`):
- `appearance [light|dark]` — fully supported
- `increase_contrast [enabled|disabled]` — fully supported
- `content_size [extra-small...accessibility-extra-extra-extra-large | increment | decrement]` — fully supported

**Other useful**: `location`, `privacy`, `push`, `spawn`, `pbsync` — relevant to other phases

### Build Statistics Breakthrough

`LogStoreManifest.plist` (plain XML plist in `DerivedData/<Project>/Logs/Build/`) contains per-build metadata:
- `timeStartedRecording`, `timeStoppedRecording` — Core Data timestamps (seconds since 2001-01-01)
- `highLevelStatus` — "S" = success, others = failure
- `totalNumberOfErrors`, `totalNumberOfWarnings`
- `schemeIdentifier-schemeName` — e.g., "BoosterSimApp"
- Duration = `timeStoppedRecording - timeStartedRecording` (seconds)

**No xcactivitylog parsing needed.** The manifest gives everything needed for build graphs.

### Watch Simulator

Device type identifiers contain "Watch" (e.g., `com.apple.CoreSimulator.SimDeviceType.Apple-Watch-Series-11-46mm`). Devices have `productFamily: "Apple Watch"`. Can enumerate via `xcrun simctl list devices --json`.

### Simulator Camera (Live Feed)

Simulator app (Xcode 14+) has built-in "Features → Camera" menu for using Mac camera. AX automation via `AXUIElementCreateApplication(simulatorPID)` can click this menu. No private APIs needed for MVP.

---

## Shared Architecture: `SimCtlService`

All 6 features share a central `xcrun simctl` command executor:

```swift
@MainActor final class SimCtlService: ObservableObject {
    // Wraps Process execution on background queue
    // Returns via Combine Future publisher
    func run(_ args: [String]) -> AnyPublisher<String, SimCtlError>
}
```

**Process execution pattern** (Combine, no async/await, Swift 6 safe):
```swift
func run(_ args: [String]) -> AnyPublisher<String, SimCtlError> {
    Future { promise in
        DispatchQueue.global(qos: .userInitiated).async {
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
            proc.arguments = ["simctl"] + args
            let pipe = Pipe()
            proc.standardOutput = pipe
            try? proc.run()
            proc.waitUntilExit()
            let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            DispatchQueue.main.async {
                proc.terminationStatus == 0
                    ? promise(.success(output))
                    : promise(.failure(.commandFailed(output)))
            }
        }
    }.eraseToAnyPublisher()
}
```

---

## Feature-by-Feature Analysis

---

### 1. Configurable Status Bar ✅ Easy

**API:** `xcrun simctl status_bar <udid> override [flags]` / `clear`

**Option A: Preset system only**
- Presets: "Screenshot Ready" (9:41, 100% battery, full signal), "Low Battery" (9%, discharging), "No Signal", "Custom"
- Pro: Simple UI, covers 90% of use cases
- Con: Less flexible

**Option B: Full individual controls**
- All 9 override flags exposed as sliders/pickers
- Pro: Maximum control
- Con: Busy UI in 260pt panel

**Recommendation: Option A + Custom mode toggle**
- 4 preset buttons + "Custom" expander revealing individual controls
- Per-UDID config stored in `@AppStorage` (encoded JSON, keyed by UDID)
- "Apply on attach" option to auto-set when simulator is detected

**New files:** `StatusBarService.swift` + `StatusBarSectionView.swift`

---

### 2. Environment Overrides ✅ Easy-Medium

**Tier 1 — `simctl ui` (safe, documented):**
- Dark/Light mode toggle
- Increase Contrast toggle
- Dynamic Type size stepper (increment/decrement or named size)

**Tier 2 — `simctl spawn defaults write` (undocumented but stable):**
- Reduce Motion: `xcrun simctl spawn booted defaults write com.apple.UIKit UIAccessibilityReduceMotionEnabled -bool YES`
- Bold Text: `xcrun simctl spawn booted defaults write -g AccessibilityBoldText -bool YES` + respring
- These work on current Simulator but may change between OS versions

**Recommendation:** Implement Tier 1 first. Tier 2 additions with graceful failure + user warning about potential instability.

**UI:** Toggles grid (dark mode, contrast, reduce motion, bold text) + Dynamic Type stepper. All apply immediately per-device.

**New files:** `EnvironmentOverrideService.swift` + `EnvironmentOverridesView.swift`

---

### 3. Apple Watch Simulator ✅ Medium

**Detection strategy:**
1. Extend `SimulatorWindow` model: add `deviceType: SimulatorDeviceType` field
2. Periodic `xcrun simctl list devices --json` call (every 5s, or on Simulator launch via NSWorkspace)
3. Parse running devices, match against CGWindowList by device name in window title
4. Filter `deviceTypeIdentifier` contains "Watch" → `.watchOS`, contains "TV" → `.tvOS`, else `.iOS`

```swift
enum SimulatorDeviceType: String, Sendable { case iOS, watchOS, tvOS, visionOS }
```

**Option A: Extend existing `SimulatorWindowTracker`**
- Add `watchSimulators` published property
- Pro: Reuse existing dual-mode detection (CGWindowList + AXObserver)
- Con: Tracker grows in scope

**Option B: Separate `WatchSimulatorTracker`**
- Con: Duplicates window detection logic (violates DRY)

**Recommendation: Option A** — add `deviceType` to `SimulatorWindow`, tracker classifies automatically.

**Side panel changes:**
- `DeviceHeaderView` shows device type icon (applewatch vs iphone)
- Feature sections adapt: Watch hides camera, push notification, some app actions
- Multi-device picker in panel header if multiple simulators are running

**New files:** Extend `SimulatorWindow.swift`, extend `SimulatorWindowTracker.swift`, `SimulatorDeviceTypeView.swift`

---

### 4. Xcode Build Statistics ✅ Medium (easier than expected)

**Data source:** `LogStoreManifest.plist` — plain XML plist, no binary parsing.

Fields available per build:
- Duration (computed), start time (Date), success/fail, scheme name, error/warning count

**Architecture:**
```swift
struct BuildRecord: Identifiable, Sendable {
    let id: String          // UUID from plist key
    let schemeName: String
    let startDate: Date     // from timeStartedRecording (CoreData epoch)
    let duration: TimeInterval
    let succeeded: Bool
    let errorCount: Int
    let warningCount: Int
}
```

`BuildStatsService`:
- FSEvents watcher on `~/Library/Developer/Xcode/DerivedData/` (or user-selected paths)
- On `LogStoreManifest.plist` change → re-parse → publish `[BuildRecord]`
- Limit to recent 50 builds across all projects
- Filter by project if user selects one

**UI Options:**

Option A: Simple list (recent builds with colored status dots + duration)
Option B: Bar chart (build durations over time) — requires custom Canvas drawing
Option C: Both (list + collapsible chart) — **Recommended**

Chart drawing: use SwiftUI `Canvas` API (no Charts framework, no external deps). Simple horizontal bar chart or vertical bars for recent 10-20 builds.

**CoreData timestamp conversion:**
```swift
Date(timeIntervalSinceReferenceDate: rawTimestamp)
```

**New files:** `BuildStatsService.swift` + `BuildStatsSectionView.swift` + `BuildChartView.swift`

---

### 5. VoiceOver Navigator (Interactive) ⚠️ Hard

**API:** AXUIElement (ApplicationServices framework — already linked)

```swift
let app = AXUIElementCreateApplication(simulatorPID)
var children: CFTypeRef?
AXUIElementCopyAttributeValue(app, kAXChildrenAttribute as CFString, &children)
```

**Model:**
```swift
struct AXNode: Identifiable, Sendable {
    let id: UUID
    let role: String         // kAXRoleAttribute
    let label: String        // kAXTitleAttribute or kAXDescriptionAttribute
    let value: String        // kAXValueAttribute
    let frame: CGRect        // kAXFrameAttribute
    var children: [AXNode]?  // nil = not yet loaded (lazy)
    var isLeaf: Bool
}
```

**Performance:** Full tree walk on complex apps = 500-2000+ elements. Must be lazy.

**Option A: SwiftUI recursive List with lazy expansion**
- `@State var expanded: Set<UUID>`
- Children loaded on expand (AX call happens then)
- Pro: Pure SwiftUI, consistent style
- Con: 260pt panel is tight; long role+label strings truncate badly

**Option B: NSOutlineView via NSViewRepresentable**
- Virtualized rendering, handles large trees
- Pro: Performance, native UX
- Con: AppKit bridging code, breaks pure SwiftUI pattern

**Recommendation:** Option A for MVP. Add max depth limit (5 levels) to prevent exponential walks.

**Interactive highlighting:**
- Click tree node → draw orange border overlay on Simulator window at element's `kAXFrameAttribute`
- `AXHighlightPanel: NSPanel` — `backgroundColor = .clear`, `isOpaque = false`
- Draw orange rect with `NSBezierPath` in custom NSView
- Auto-dismiss after 2.5s or on next selection

**Critical constraint:** AX calls can block on slow apps. Must dispatch tree-walking to background queue, publish results to main.

**New files:** `AXInspectorService.swift` + `AXNode.swift` + `AXTreeView.swift` + `AXHighlightPanel.swift`

---

### 6. Live Mac Camera Feed ⚠️ Complex

**Reality check:** This is RocketSim's flagship feature and is genuinely hard to implement correctly.

**Option A: AX Menu Automation (Recommended MVP)**
- Simulator app (Xcode 14+) has: `Features → Camera → Front Camera / Rear Camera → Mac Built-In Camera`
- Use `AXUIElementCreateApplication(simulatorPID)` → navigate menu bar → Features → Camera → click Mac Camera option
- We already have Accessibility permission
- Pro: No private APIs, no system extensions, leverages Simulator's built-in feature
- Con: Fragile (menu structure can change per Xcode version), not a "BoosterSimApp" feature per se — just automates Simulator's own UI

**Option B: CMIO Camera Extension (Virtual Camera Driver)**
- macOS 12.3+ supports Camera Extensions (ScreenCaptureKit-style)
- Creates a virtual camera device that Simulator picks up
- Pro: Proper API, robust
- Con: Requires System Extension (sandboxed, separate target), user must grant permission in Privacy settings, fundamentally incompatible with non-sandboxed app architecture

**Option C: Private CoreSimulator.framework**
- SimDevice has APIs for camera simulation
- Risk: private API, breaks without notice, App Store rejection

**Honest assessment:** Option A (AX automation) is the only approach compatible with our non-sandboxed architecture and zero-dependencies constraint. Label it "Simulator Camera (Beta)" in UI. Detect if the Simulator app version supports it; gracefully degrade if menu structure changes.

**Research step before implementing:** Walk Simulator's AX menu tree to confirm exact menu item path. Do this first (30 min) before any implementation work.

**New files:** `CameraService.swift` + `CameraView.swift`

---

## Implementation Sequence

| Order | Feature | Complexity | Est. Scope |
|---|---|---|---|
| 1 | `SimCtlService` (shared foundation) | Low | ~60 LOC |
| 2 | Status Bar Config | Low | ~150 LOC (service + view) |
| 3 | Environment Overrides | Low-Med | ~150 LOC |
| 4 | Watch Simulator | Medium | ~100 LOC (model + tracker extension) |
| 5 | Build Statistics | Medium | ~200 LOC (service + views) |
| 6 | VoiceOver Navigator | Hard | ~300 LOC across 4 files |
| 7 | Live Camera | Complex | ~150 LOC + research |

---

## New Files to Create

```
Services/
├── SimCtlService.swift           # shared xcrun simctl wrapper
├── StatusBarService.swift        # preset management + apply
├── EnvironmentOverrideService.swift
├── BuildStatsService.swift       # FSEvents + LogStoreManifest parser
├── AXInspectorService.swift      # AX tree walker
└── CameraService.swift           # AX menu automation for camera

Models/
├── BuildRecord.swift
└── AXNode.swift

Views/SideWindow/
├── StatusBarSectionView.swift
├── EnvironmentOverridesView.swift
├── BuildStatsSectionView.swift
├── BuildChartView.swift           # Canvas-based chart
├── AXTreeView.swift
└── CameraView.swift

Windows/
└── AXHighlightPanel.swift        # overlay for element highlighting
```

**Modified files:** `SimulatorWindow.swift` (add deviceType), `SimulatorWindowTracker.swift` (classify devices), `AppDelegate.swift` (own new services)

---

## Risks

| Risk | Severity | Mitigation |
|---|---|---|
| `simctl` commands block main thread | High | Always dispatch to background queue via Combine Future |
| AX tree walk too slow on large apps | High | Lazy loading, max depth 5, background dispatch |
| Watch Simulator window title matching brittle | Medium | Cross-reference with simctl list, not just title |
| `simctl spawn defaults write` breaks OS version | Medium | Try/catch, graceful fallback, user-visible warning |
| Simulator Camera menu path changes | High | Probe menu at runtime, disable feature if not found |
| `LogStoreManifest.plist` format changes | Low | It's been stable for years; plist parsing is safe |
| FSEvents permissions for DerivedData | Low | User already grants DerivedData access in Phase 1 |

---

## Success Criteria

- [ ] Status bar presets apply in <500ms with visible change in Simulator
- [ ] Environment overrides toggle dark mode immediately
- [ ] Watch Simulator detected and shown in panel with correct device icon
- [ ] Build stats show last 50 builds with duration graph, auto-updating on new builds
- [ ] AX tree loads lazily, highlights elements with orange overlay in Simulator
- [ ] Camera automation enables Mac camera in Simulator with single button press
- [ ] All features respect Swift 6 concurrency (no `@unchecked Sendable`, no UI off main)
- [ ] All new files under 200 LOC

---

## Unresolved Questions

1. **Camera menu path:** Need to AX-inspect current Simulator.app to confirm exact `Features → Camera → ...` menu item hierarchy before implementing.
2. **`simctl spawn defaults write` keys:** Exact defaults domain + key names for Reduce Motion and Bold Text need to be tested against current watchOS/iOS simulators.
3. **FSEvents vs polling for BuildStats:** FSEvents requires `kqueue` or `NSFilePresenter` — does non-sandboxed app need extra entitlements for watching `~/Library/Developer/Xcode/DerivedData/`? Likely no.
4. **Multi-Watch support:** If user has paired Watch + iPhone both visible, should panel show both separately or only the active iOS device's paired Watch?
