// AXInspectorService.swift — Accessibility tree walker for active Simulator
// Reads AXUIElement hierarchy lazily; dispatches all AX calls to background queue.
// Uses raw AX attribute string constants for macOS 26 SDK compatibility.
import AppKit
import Combine
import ApplicationServices

// MARK: - AX Attribute Strings (raw, avoids kAX* scope issues)

private enum AXAttr {
    static let children:     CFString = "AXChildren" as CFString
    static let role:         CFString = "AXRole" as CFString
    static let title:        CFString = "AXTitle" as CFString
    static let description:  CFString = "AXDescription" as CFString
    static let value:        CFString = "AXValue" as CFString
    static let frame:        CFString = "AXFrame" as CFString
    static let markChar:     CFString = "AXMenuItemMarkChar" as CFString
}

// MARK: - Service

@MainActor
final class AXInspectorService: ObservableObject {

    // MARK: - Published State

    @Published var rootNodes: [AXNode] = []
    @Published var isLoading = false
    @Published var highlightFrame: CGRect? = nil

    private static let maxDepth = 5

    // MARK: - Public Methods

    func loadRoot(for pid: pid_t) {
        isLoading = true
        rootNodes = []
        let screenHeight = NSScreen.screens.first?.frame.height ?? 0
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let appEl = AXUIElementCreateApplication(pid)
            AXUIElementSetMessagingTimeout(appEl, 2.0)
            let children = Self.fetchChildren(of: appEl, depth: 0, screenHeight: screenHeight)
            DispatchQueue.main.async {
                self?.rootNodes  = children
                self?.isLoading  = false
            }
        }
    }

    func highlight(node: AXNode) {
        highlightFrame = node.frame
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
            if self?.highlightFrame == node.frame { self?.highlightFrame = nil }
        }
    }

    func clearHighlight() { highlightFrame = nil }

    // MARK: - Private Helpers (file-scope for background-queue callability)

    nonisolated fileprivate static func fetchChildren(of element: AXUIElement, depth: Int, screenHeight: CGFloat) -> [AXNode] {
        guard depth < maxDepth else { return [] }
        var ref: CFTypeRef?
        AXUIElementCopyAttributeValue(element, AXAttr.children, &ref)
        guard let elements = ref as? [AXUIElement] else { return [] }
        return elements.compactMap { readNode(from: $0, depth: depth, screenHeight: screenHeight) }
    }

    nonisolated fileprivate static func readNode(from element: AXUIElement, depth: Int, screenHeight: CGFloat) -> AXNode? {
        let role = readString(AXAttr.role, from: element)
        guard !role.isEmpty else { return nil }
        let label = readString(AXAttr.title, from: element).nilIfEmpty
            ?? readString(AXAttr.description, from: element)
        let value    = readString(AXAttr.value, from: element)
        let frame    = readFrame(element, screenHeight: screenHeight)
        let hasKids  = hasChildren(element)
        return AXNode(id: UUID(), role: role, label: label,
                      value: value, frame: frame, hasChildren: hasKids)
    }

    nonisolated fileprivate static func readString(_ attr: CFString, from el: AXUIElement) -> String {
        var ref: CFTypeRef?
        AXUIElementCopyAttributeValue(el, attr, &ref)
        return (ref as? String) ?? ""
    }

    nonisolated fileprivate static func readFrame(_ el: AXUIElement, screenHeight: CGFloat) -> CGRect {
        var ref: CFTypeRef?
        AXUIElementCopyAttributeValue(el, AXAttr.frame, &ref)
        guard let val = ref else { return .zero }
        guard CFGetTypeID(val) == AXValueGetTypeID() else { return .zero }
        var rect = CGRect.zero
        withUnsafeMutablePointer(to: &rect) { ptr in
            // AXValueGetValue expects UnsafeMutableRawPointer
            _ = AXValueGetValue(val as! AXValue, AXValueType.cgRect, ptr)  // swiftlint:disable:this force_cast
        }
        // Convert Quartz Y (top-origin) → AppKit Y (bottom-origin)
        if screenHeight > 0 {
            rect.origin.y = screenHeight - rect.origin.y - rect.height
        }
        return rect
    }

    nonisolated fileprivate static func hasChildren(_ el: AXUIElement) -> Bool {
        var ref: CFTypeRef?
        AXUIElementCopyAttributeValue(el, AXAttr.children, &ref)
        return (ref as? [AXUIElement])?.isEmpty == false
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
