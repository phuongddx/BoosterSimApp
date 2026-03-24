// CameraService.swift — AX menu automation to route Mac camera into Simulator
// Uses Accessibility API (already permitted) to click Simulator's Features → Camera menu.
import AppKit
import Combine
import ApplicationServices

// MARK: - AX Helpers (file-scope, callable from any context)

private func axFindMenuItem(in el: AXUIElement, path: [String]) -> AXUIElement? {
    var current = el
    for title in path {
        var ref: CFTypeRef?
        AXUIElementCopyAttributeValue(current, kAXChildrenAttribute as CFString, &ref)
        guard let children = ref as? [AXUIElement] else { return nil }
        var titleRef: CFTypeRef?
        guard let match = children.first(where: {
            AXUIElementCopyAttributeValue($0, kAXTitleAttribute as CFString, &titleRef)
            return (titleRef as? String) == title
        }) else { return nil }
        current = match
    }
    return current
}

private func axReadCheckmark(_ item: AXUIElement) -> Bool {
    var ref: CFTypeRef?
    AXUIElementCopyAttributeValue(item, kAXMenuItemMarkCharAttribute as CFString, &ref)
    return (ref as? String) == "✓"
}

// MARK: - Service

@MainActor
final class CameraService: ObservableObject {

    // MARK: - Published State

    @Published var isFrontEnabled = false
    @Published var isBackEnabled  = false
    @Published var isSupported    = false

    // MARK: - Menu Paths

    private let frontPath = ["Features", "Camera", "Front Camera", "Mac Built-In Camera"]
    private let backPath  = ["Features", "Camera", "Back Camera",  "Mac Built-In Camera"]

    // MARK: - Public Methods

    func probeSupport(pid: pid_t) {
        let front = frontPath
        let back  = backPath
        DispatchQueue.global(qos: .userInitiated).async {
            let app       = AXUIElementCreateApplication(pid)
            let supported = axFindMenuItem(in: app, path: ["Features", "Camera"]) != nil
            let frontOn   = axFindMenuItem(in: app, path: front).map { axReadCheckmark($0) } ?? false
            let backOn    = axFindMenuItem(in: app, path: back).map  { axReadCheckmark($0) } ?? false
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.isSupported    = supported
                self.isFrontEnabled = frontOn
                self.isBackEnabled  = backOn
            }
        }
    }

    func toggleFront(pid: pid_t) {
        pressItem(pid: pid, path: frontPath) { [weak self] state in
            self?.isFrontEnabled = state
        }
    }

    func toggleBack(pid: pid_t) {
        pressItem(pid: pid, path: backPath) { [weak self] state in
            self?.isBackEnabled = state
        }
    }

    // MARK: - Private

    private func pressItem(pid: pid_t, path: [String], completion: @escaping @MainActor (Bool) -> Void) {
        let pathCopy = path
        DispatchQueue.global(qos: .userInitiated).async {
            let app = AXUIElementCreateApplication(pid)
            guard let item = axFindMenuItem(in: app, path: pathCopy) else { return }
            AXUIElementPerformAction(item, kAXPressAction as CFString)
            Thread.sleep(forTimeInterval: 0.15)
            let state = axReadCheckmark(item)
            DispatchQueue.main.async {
                Task { @MainActor in completion(state) }
            }
        }
    }
}
