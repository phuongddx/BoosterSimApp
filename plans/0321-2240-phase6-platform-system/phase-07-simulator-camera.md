# Phase 07 — Simulator Camera (Live Mac Camera Feed)

**Priority:** P2 | **Status:** Complete | **Effort:** 3h

**Context:** [Plan](./plan.md)

## Overview

Enable Mac built-in camera as Simulator camera input via AX menu automation on the Simulator app. The Simulator (Xcode 14+) has a built-in `Features → Camera` menu that routes camera feeds. We automate clicking this menu using the Accessibility API (already permitted). Label in UI: "Simulator Camera (Beta)".

## Key Insights

**Why AX automation:**
- CMIO Camera Extension (virtual driver): requires sandboxed System Extension — incompatible with non-sandboxed architecture
- CoreSimulator.framework private API: fragile, breaks on Xcode updates
- `xcrun simctl io` stream: records FROM simulator, not injects INTO it
- AX menu automation: uses `AXUIElement` (already have permission), no private APIs, leverages Simulator's own built-in camera support

**Simulator menu path (to verify at implementation time):**
```
Simulator.app menubar → Features → Camera → Front Camera → Mac Built-In Camera
                                           → Back Camera  → Mac Built-In Camera
```
Menu structure may vary by Xcode version — **probe at runtime before enabling button**.

**AX menu automation pattern:**
```swift
let simulatorApp = AXUIElementCreateApplication(simulatorPID)
// Navigate: menubar → "Features" → "Camera" → "Front Camera" → "Mac Built-In Camera"
// AXPress each submenu item
```

**Camera permission:** App needs `NSCameraUsageDescription` in `Info.plist` to access the Mac camera preview for confirmation UI (optional). The Simulator app itself handles camera access after the menu click — we may not need the camera entitlement at all since we're just clicking a menu.

**Graceful degradation:** If `Features → Camera` menu item not found (older Xcode or menu structure changed), disable the button and show tooltip: "Camera control requires Xcode 14 or later."

## Requirements

- **Research step first:** Before writing production code, write a small diagnostic script / inline code that walks Simulator's AX menu tree and prints all item titles — confirm exact menu path for current Xcode version
- Single toggle per camera (Front / Back) — "Use Mac Camera" on/off
- Probe Simulator menu structure at launch; disable feature gracefully if not found
- Show current state: whether Mac camera is active (best-effort — read menu item `kAXMenuItemMarkCharAttribute`)
- Works for iOS Simulator; hidden for watchOS (Watch has no camera)
- Label as "Beta" with info tooltip

## Architecture

```
CameraService            — AX menu navigation + state probing
CameraView               — Front/Back toggle buttons (hidden for Watch)
```

**`CameraService`** (`Services/CameraService.swift`):
```swift
@MainActor final class CameraService: ObservableObject {
    @Published var isFrontCameraEnabled = false
    @Published var isBackCameraEnabled = false
    @Published var isSupported = false   // false if Simulator menu not found

    func probeSimulatorMenuSupport(pid: pid_t)
    func toggleFrontCamera(pid: pid_t)
    func toggleBackCamera(pid: pid_t)

    private func findMenuItem(in appEl: AXUIElement, path: [String]) -> AXUIElement?
    private func pressMenuItem(_ item: AXUIElement)
    private func readMenuItemState(_ item: AXUIElement) -> Bool  // kAXMenuItemMarkCharAttribute
}
```

**AX menu navigation pattern:**
```swift
private func findMenuItem(in appEl: AXUIElement, path: [String]) -> AXUIElement? {
    var current: AXUIElement = appEl
    for title in path {
        guard let children = axChildren(of: current) else { return nil }
        guard let match = children.first(where: { axTitle(of: $0) == title }) else { return nil }
        current = match
    }
    return current
}

// Usage:
let macCameraItem = findMenuItem(in: simApp, path: [
    "Features", "Camera", "Front Camera", "Mac Built-In Camera"
])
```

**State reading:**
```swift
private func readMenuItemState(_ item: AXUIElement) -> Bool {
    var ref: CFTypeRef?
    AXUIElementCopyAttributeValue(item, kAXMenuItemMarkCharAttribute as CFString, &ref)
    return (ref as? String) == "✓"   // checkmark = enabled
}
```

**`CameraView`** (`Views/SideWindow/CameraView.swift`):
```
CameraView
├── if !service.isSupported → "Requires Xcode 14+" info row
├── Toggle row: "Front Camera" → toggleFrontCamera()
└── Toggle row: "Back Camera"  → toggleBackCamera()
    (+ "Beta" badge on section header)
```

## Related Code Files

| File | Action | Description |
|------|--------|-------------|
| `Services/CameraService.swift` | Create | AX menu automation + state (~120 LOC) |
| `Views/SideWindow/CameraView.swift` | Create | Front/Back toggles (~60 LOC) |
| `App/AppDelegate.swift` | Modify | Own `CameraService`, probe on simulator attach |
| `Views/SideWindow/SideWindowView.swift` | Modify | Wire Camera section (hidden for watchOS) |

## Implementation Steps

### Step 0 — Research (Do First, ~30 min)
Before writing production code, write a quick diagnostic in a scratch function or playground:
```swift
// Walk Simulator AX menu tree and print all item titles to console
func dumpMenuTree(_ el: AXUIElement, depth: Int = 0) {
    let indent = String(repeating: "  ", count: depth)
    var titleRef: CFTypeRef?
    AXUIElementCopyAttributeValue(el, kAXTitleAttribute as CFString, &titleRef)
    print("\(indent)\(titleRef as? String ?? "(no title)")")
    var childrenRef: CFTypeRef?
    AXUIElementCopyAttributeValue(el, kAXChildrenAttribute as CFString, &childrenRef)
    (childrenRef as? [AXUIElement] ?? []).forEach { dumpMenuTree($0, depth: depth + 1) }
}
// Call with: dumpMenuTree(AXUIElementCreateApplication(simulatorPID))
```
→ Confirm the exact menu path before hardcoding it in `CameraService`.

### Step 1 — Create `CameraService.swift`
1. Implement `probeSimulatorMenuSupport(pid:)`:
   - Build `AXUIElementCreateApplication(pid)`
   - Try `findMenuItem(in:path:)` for `["Features", "Camera"]`
   - Set `isSupported = (item != nil)`
2. Implement `findMenuItem(in:path:)` — recursive AX child search by `kAXTitleAttribute`
3. Implement `pressMenuItem(_:)` → `AXUIElementPerformAction(item, kAXPressAction as CFString)`
4. Implement `readMenuItemState(_:)` → reads `kAXMenuItemMarkCharAttribute` for checkmark
5. Implement `toggleFrontCamera(pid:)`:
   - Find item at `["Features", "Camera", "Front Camera", "Mac Built-In Camera"]`
   - `pressMenuItem` it
   - Re-read state → update `isFrontCameraEnabled`
6. Same for `toggleBackCamera`

### Step 2 — Create `CameraView.swift`
- `if !service.isSupported`: show info text "Camera control requires Xcode 14+"
- Two toggle rows with `service.isFrontCameraEnabled` / `isBackCameraEnabled`
- "Beta" badge on section or button

### Step 3 — Wire into AppDelegate + SideWindowView
- `AppDelegate`: own `CameraService`, call `probeSimulatorMenuSupport` when `activeSimulator` changes
- `SideWindowView`: show `CameraView` only when `deviceType == .iOS`

### Step 4 — Info.plist (if needed)
- Add `NSCameraUsageDescription` only if the camera preview UI requires it
- Likely not needed since we automate the Simulator menu (no AVCapture in our app)

## Todo

- [x] **Research:** Run `dumpMenuTree` diagnostic on running Simulator to confirm menu path
- [x] Create `Services/CameraService.swift` — probe, find, press, read state
- [x] Confirm `kAXMenuItemMarkCharAttribute` checkmark reading works
- [x] Create `Views/SideWindow/CameraView.swift` — front/back toggles + fallback
- [x] Wire into `AppDelegate` (probe on attach) + `SideWindowView` (iOS only)
- [x] Test: click Front Camera toggle, verify Simulator camera switches to Mac camera
- [x] Test: on Xcode 15 and Xcode 16 (menu path stability check)

## Success Criteria

- Single button click enables Mac camera in Simulator
- Toggling off returns to simulated camera
- `isSupported = false` shown gracefully (no crash) on unsupported Xcode
- Feature hidden for watchOS simulators
- Both files under 130 LOC

## Risk Assessment

| Risk | Severity | Mitigation |
|------|----------|-----------|
| Menu path changes between Xcode versions | High | Probe at runtime; `isSupported = false` on mismatch; log actual path |
| `kAXMenuItemMarkCharAttribute` unreliable | Medium | Fall back to optimistic toggle (press = enable, press again = disable) |
| AX press opens menu but doesn't select | Medium | After `pressMenuItem`, send `kAXCancelAction` to close menu if item was already open |
| Camera requires `NSCameraUsageDescription` | Low | Add to Info.plist as precaution; app may not need it |
| Feature misrepresents itself as BoosterSimApp feature | Low | Label clearly as "Beta — uses Simulator's built-in camera support" in tooltip |

## Security Considerations

- No camera data passes through BoosterSimApp — we only click a menu in Simulator.app
- AX automation is scoped to the Simulator process only (existing Accessibility permission)
- No additional entitlements or permissions required beyond what Phase 1 already grants
