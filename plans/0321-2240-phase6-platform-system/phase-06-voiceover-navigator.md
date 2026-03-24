# Phase 06 — VoiceOver Navigator (Interactive AX Inspector)

**Priority:** P2 | **Status:** Complete | **Effort:** 4h

**Context:** [Plan](./plan.md)

## Overview

Interactive accessibility tree inspector for the active Simulator. Walks AXUIElement hierarchy lazily, displays in a SwiftUI tree with expand/collapse. Clicking a node draws an orange highlight overlay on the Simulator window at the element's screen frame.

## Key Insights

- `ApplicationServices` framework already linked — `AXUIElement` C API available
- `AXUIElementCreateApplication(pid_t)` → root element for Simulator app
- Attribute reads: `AXUIElementCopyAttributeValue(el, kAXChildrenAttribute as CFString, &ref)`
- `kAXFrameAttribute` returns `CGRect` in screen coordinates (top-left origin, mixed with AppKit bottom-left — need conversion)
- Full tree walk = potentially 500–2000+ elements on a complex app → **must be lazy**
- AX calls can block for ~100ms each on slow/frozen apps → **must dispatch to background queue**
- Max depth: 5 levels (prevents exponential walk on deep hierarchies)
- `AXHighlightPanel` follows `SideWindowPanel` pattern: `NSPanel` subclass, `.floating` level, transparent background

## Requirements

- Tree loads lazily: children fetched only when node is expanded
- Background dispatch for all AX calls; publish results on main
- Clicking a node shows orange border overlay on Simulator at element's frame
- Overlay auto-dismisses after 2.5s or on new selection
- Refresh button to re-walk root
- Shows: role, label (title/description), value, frame
- Disable when no active simulator or no Accessibility permission
- Respects Reduce Motion (no overlay fade animation when enabled)

## Architecture

**`AXNode` model** (`Models/AXNode.swift`):
```swift
struct AXNode: Identifiable, Sendable {
    let id: UUID
    let role: String          // kAXRoleAttribute
    let label: String         // kAXTitleAttribute ?? kAXDescriptionAttribute ?? ""
    let value: String         // kAXValueAttribute ?? ""
    let frame: CGRect         // kAXFrameAttribute (screen space, AppKit coords)
    var hasChildren: Bool     // whether node has children (checked without fetching them)
    var children: [AXNode]?   // nil = not yet loaded; [] = loaded, leaf node
}
```

**`AXInspectorService`** (`Services/AXInspectorService.swift`):
```swift
@MainActor final class AXInspectorService: ObservableObject {
    @Published var rootNodes: [AXNode] = []
    @Published var isLoading = false
    @Published var highlightFrame: CGRect? = nil   // drives AXHighlightPanel

    func loadRoot(for pid: pid_t)
    func loadChildren(of node: AXNode, completion: @escaping ([AXNode]) -> Void)
    func highlight(node: AXNode)
    func clearHighlight()

    private func readNode(from element: AXUIElement, depth: Int) -> AXNode?
    private func readString(_ attr: String, from el: AXUIElement) -> String
    private func readFrame(_ el: AXUIElement) -> CGRect
}
```

**Key AX reading pattern** (background queue):
```swift
func loadRoot(for pid: pid_t) {
    isLoading = true
    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
        let appEl = AXUIElementCreateApplication(pid)
        var childrenRef: CFTypeRef?
        AXUIElementCopyAttributeValue(appEl, kAXChildrenAttribute as CFString, &childrenRef)
        let children = (childrenRef as? [AXUIElement] ?? [])
            .compactMap { self?.readNode(from: $0, depth: 0) }
        DispatchQueue.main.async {
            self?.rootNodes = children
            self?.isLoading = false
        }
    }
}
```

**Frame coordinate conversion** (Quartz → AppKit, same as `WindowEnumerator`):
```swift
private func readFrame(_ el: AXUIElement) -> CGRect {
    var ref: CFTypeRef?
    AXUIElementCopyAttributeValue(el, kAXFrameAttribute as CFString, &ref)
    guard let value = ref, CFGetTypeID(value) == AXValueGetTypeID() else { return .zero }
    var rect = CGRect.zero
    AXValueGetValue(value as! AXValue, .cgRect, &rect)
    // Convert Quartz Y to AppKit Y
    if let screenHeight = NSScreen.screens.first?.frame.height {
        rect.origin.y = screenHeight - rect.origin.y - rect.height
    }
    return rect
}
```

**`AXHighlightPanel`** (`Windows/AXHighlightPanel.swift`):
```swift
final class AXHighlightPanel: NSPanel {
    private let highlightView = AXHighlightView()
    private var dismissTimer: Timer?

    func show(at frame: CGRect) {
        setFrame(frame.insetBy(dx: -4, dy: -4), display: false)
        highlightView.frame = bounds
        contentView = highlightView
        orderFront(nil)
        scheduleDismiss()
    }

    func hide() { orderOut(nil); dismissTimer?.invalidate() }
    private func scheduleDismiss() { /* Timer after 2.5s → hide() */ }
}

// NSView drawing orange border rect:
final class AXHighlightView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        NSColor.orange.withAlphaComponent(0.9).setStroke()
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 2, dy: 2), xRadius: 4, yRadius: 4)
        path.lineWidth = 3
        path.stroke()
    }
}
```

**`AXTreeView`** (`Views/SideWindow/AXTreeView.swift`):
- SwiftUI `List` with recursive `AXNodeRowView`
- `@State var expanded: Set<UUID>` — controls which nodes show children
- On expand: call `service.loadChildren(of: node)` → update node in tree
- On tap: call `service.highlight(node: node)`

## Related Code Files

| File | Action | Description |
|------|--------|-------------|
| `Models/AXNode.swift` | Create | Immutable node model |
| `Services/AXInspectorService.swift` | Create | AX tree walker + highlight state (~130 LOC) |
| `Windows/AXHighlightPanel.swift` | Create | Transparent overlay panel (~60 LOC) |
| `Views/SideWindow/AXTreeView.swift` | Create | SwiftUI recursive tree (~80 LOC) |
| `App/AppDelegate.swift` | Modify | Own `AXInspectorService` + `AXHighlightPanel`; show/hide panel |
| `Views/SideWindow/SideWindowView.swift` | Modify | Wire AX tree section |

## Implementation Steps

1. Create `Models/AXNode.swift` — struct with `Identifiable`, `Sendable`
2. Create `Services/AXInspectorService.swift`:
   - `loadRoot(for pid:)` — background, fetch top-level children, dispatch to main
   - `loadChildren(of:completion:)` — background, fetch children of node, callback on main
   - `readNode(from:depth:)` — reads role/label/value/frame + `hasChildren`; stops at `depth >= 5`
   - `readFrame(_:)` with Quartz→AppKit conversion
   - `highlight(node:)` → sets `highlightFrame = node.frame`
3. Create `Windows/AXHighlightPanel.swift`:
   - Subclass `NSPanel` (`isOpaque = false`, `backgroundColor = .clear`, `.floating` level)
   - `AXHighlightView: NSView` draws orange rounded border
   - `show(at:)` positions + `orderFront`, `scheduleDismiss()` with 2.5s Timer
4. Create `Views/SideWindow/AXTreeView.swift`:
   - `AXNodeRowView`: chevron (expand toggle) + role badge + label + value (truncated)
   - `onTapGesture` → `service.highlight(node:)`
   - Lazy child loading on expand
5. Wire `AXInspectorService` into `AppDelegate`:
   - Observe `tracker.$activeSimulator` → call `loadRoot(for: sim.pid)`
   - Observe `service.$highlightFrame` → show/hide `AXHighlightPanel`
6. Wire `AXHighlightPanel` lifecycle (show on highlight, hide on clear/dismiss)
7. Build + test with a running iOS app in Simulator

## Todo

- [x] Create `Models/AXNode.swift`
- [x] Create `Services/AXInspectorService.swift` — root load, child load, highlight
- [x] Implement frame Quartz→AppKit conversion
- [x] Create `Windows/AXHighlightPanel.swift` — transparent NSPanel + orange NSView
- [x] Create `Views/SideWindow/AXTreeView.swift` — lazy recursive SwiftUI list
- [x] Wire into `AppDelegate` — load root on sim change, show panel on highlight
- [x] Test: expand tree nodes, verify highlight appears in Simulator
- [x] Test: deep app (e.g., Settings app) — confirm max depth 5 stops walk

## Success Criteria

- Root AX nodes load within 1s for typical iOS app
- Children load on demand when node is expanded
- Orange highlight appears on Simulator at correct screen position
- Highlight dismisses after 2.5s
- No deadlocks, no main-thread AX calls
- All files under 140 LOC

## Risk Assessment

| Risk | Mitigation |
|------|-----------|
| AX call blocks indefinitely on frozen app | Set `AXUIElementSetMessagingTimeout` to 2.0s per element |
| Frame coordinates off (mixed Quartz/AppKit) | Mirror `WindowEnumerator`'s Y-flip logic; add unit test for conversion |
| SwiftUI List performance with 50+ expanded nodes | Cap expanded depth at 3 simultaneously; show "..." row if too deep |
| Accessibility permission not granted | Check `AXIsProcessTrusted()` before calling; show permission prompt |

## Security Considerations

- AX tree reads are read-only (no `AXUIElementPerformAction` writing to simulator)
- User data visible in AX tree (text field contents, etc.) — stay within existing Accessibility permission scope
