// WindowObserver.swift — Wraps AXObserver to get real-time window move/resize events
// Phase 1: registers kAXWindowMoved/Resized on individual window elements (not app element)
// Phase 2: onFrameChanged fast path bypasses CGWindowList scan during drag
import AppKit
import ApplicationServices
import OSLog

final class WindowObserver {

    // MARK: - Properties

    private var observer: AXObserver?
    private let pid: pid_t
    private var callback: ((String, AXUIElement) -> Void)?
    var onFrameChanged: ((CGRect) -> Void)?
    private var selfPtr: UnsafeMutableRawPointer?  // retained pointer; released in stopObserving()

    // Lifecycle notifications — registered on the app element
    private static let appNotifications: [String] = [
        kAXWindowCreatedNotification as String,
        kAXWindowMiniaturizedNotification as String,
        kAXWindowDeminiaturizedNotification as String,
        kAXUIElementDestroyedNotification as String
    ]

    // Positional notifications — registered on each window element individually
    // kAXWindowMoved/Resized fire during drag; element-level kAXMoved/Resized do not
    private static let windowNotifications: [String] = [
        kAXWindowMovedNotification as String,
        kAXWindowResizedNotification as String
    ]

    // MARK: - Init

    init(pid: pid_t) {
        self.pid = pid
    }

    deinit {
        stopObserving()
    }

    // MARK: - Public API

    /// Start observing window notifications for the given PID.
    /// Callback receives the AX notification name and the element that fired it.
    /// Move/resize events bypass callback and are delivered via onFrameChanged instead.
    func startObserving(callback: @escaping (String, AXUIElement) -> Void) {
        self.callback = callback

        let result = AXObserverCreate(pid, axCallback, &observer)
        guard result == .success, let obs = observer else {
            AppLogger.windowTracking.error("Failed to create AXObserver for pid=\(self.pid, privacy: .public): \(result.rawValue, privacy: .public)")
            return
        }

        let appElement = AXUIElementCreateApplication(pid)
        selfPtr = Unmanaged.passRetained(self).toOpaque()  // balanced by release() in stopObserving()

        // Register lifecycle notifications on the app element
        for notification in Self.appNotifications {
            AXObserverAddNotification(obs, appElement, notification as CFString, selfPtr)
        }

        // Register positional notifications on each existing window element
        registerWindowNotifications(obs: obs, appElement: appElement)

        CFRunLoopAddSource(
            CFRunLoopGetMain(),
            AXObserverGetRunLoopSource(obs),
            .defaultMode
        )
    }

    func stopObserving() {
        guard let obs = observer else { return }
        CFRunLoopRemoveSource(
            CFRunLoopGetMain(),
            AXObserverGetRunLoopSource(obs),
            .defaultMode
        )
        if let ptr = selfPtr {
            Unmanaged<WindowObserver>.fromOpaque(ptr).release()
            selfPtr = nil
        }
        observer = nil
        callback = nil
        onFrameChanged = nil
    }

    // MARK: - Internal callback trigger

    fileprivate func handleNotification(_ name: String, element: AXUIElement) {
        // Fast path: read frame directly from callback element, skip CGWindowList scan
        if name == kAXWindowMovedNotification as String || name == kAXWindowResizedNotification as String {
            if let frame = readWindowFrame(from: element) {
                if name == kAXWindowMovedNotification as String {
                    AppLogger.windowTracking.debug("Simulator moved: pid=\(self.pid, privacy: .public) frame=\(frame.debugDescription, privacy: .public)")
                }
                onFrameChanged?(frame)
            }
            return
        }
        // When a new window is created, register positional notifications on it
        if name == kAXWindowCreatedNotification as String, let obs = observer {
            registerWindowNotifications(obs: obs, appElement: AXUIElementCreateApplication(pid))
        }
        callback?(name, element)
    }

    // MARK: - Private Helpers

    /// Enumerate kAXWindowsAttribute and register windowNotifications on each window element.
    private func registerWindowNotifications(obs: AXObserver, appElement: AXUIElement) {
        var windowsRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsRef) == .success,
              let windows = windowsRef as? [AXUIElement] else { return }
        for windowElement in windows {
            for notification in Self.windowNotifications {
                // Duplicate registration is a no-op — safe to call on existing windows
                AXObserverAddNotification(obs, windowElement, notification as CFString, selfPtr)
            }
        }
    }

    /// Read window frame from AX element.
    /// AX position uses Quartz coordinates (top-origin); flips to AppKit (bottom-origin).
    private func readWindowFrame(from element: AXUIElement) -> CGRect? {
        var posRef: CFTypeRef?
        var sizeRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &posRef) == .success,
              AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeRef) == .success,
              let posVal = posRef, let sizeVal = sizeRef else { return nil }

        var quartzOrigin = CGPoint.zero
        var size = CGSize.zero
        guard CFGetTypeID(posVal) == AXValueGetTypeID(),
              AXValueGetValue(posVal as! AXValue, .cgPoint, &quartzOrigin),
              CFGetTypeID(sizeVal) == AXValueGetTypeID(),
              AXValueGetValue(sizeVal as! AXValue, .cgSize, &size) else { return nil }

        // Flip Y: Quartz counts from top of primary screen; AppKit counts from bottom
        let screenHeight = NSScreen.screens.first?.frame.height ?? 0
        let appKitY = screenHeight - quartzOrigin.y - size.height
        return CGRect(x: quartzOrigin.x, y: appKitY, width: size.width, height: size.height)
    }
}

// MARK: - C-style AXObserver callback (must be a free function)

private func axCallback(
    _ observer: AXObserver,
    _ element: AXUIElement,
    _ notification: CFString,
    _ refcon: UnsafeMutableRawPointer?
) {
    guard let refcon else { return }
    let windowObserver = Unmanaged<WindowObserver>.fromOpaque(refcon).takeUnretainedValue()
    windowObserver.handleNotification(notification as String, element: element)
}
