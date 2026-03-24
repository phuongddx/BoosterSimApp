// WindowObserver.swift — Wraps AXObserver to get real-time window move/resize events
// AXObserver fires C callbacks on the main run loop; bridged to Swift closure here.
import AppKit
import ApplicationServices

final class WindowObserver {

    // MARK: - Properties

    private var observer: AXObserver?
    private let pid: pid_t
    private var callback: ((String) -> Void)?
    private var selfPtr: UnsafeMutableRawPointer?  // retained pointer; released in stopObserving()

    // Notifications we care about from the Simulator window
    private static let notifications: [String] = [
        kAXMovedNotification as String,
        kAXResizedNotification as String,
        kAXWindowCreatedNotification as String,
        kAXWindowMiniaturizedNotification as String,
        kAXWindowDeminiaturizedNotification as String,
        kAXUIElementDestroyedNotification as String
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
    /// Callback receives the AX notification name string.
    func startObserving(callback: @escaping (String) -> Void) {
        self.callback = callback

        // Create the AXObserver with a C-style callback
        let result = AXObserverCreate(pid, axCallback, &observer)
        guard result == .success, let obs = observer else {
            print("[WindowObserver] Failed to create AXObserver for PID \(pid): \(result.rawValue)")
            return
        }

        let appElement = AXUIElementCreateApplication(pid)
        selfPtr = Unmanaged.passRetained(self).toOpaque()  // balanced by release() in stopObserving()

        for notification in Self.notifications {
            AXObserverAddNotification(obs, appElement, notification as CFString, selfPtr)
        }

        // Add to main run loop so callbacks fire on main thread
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
        // Balance the passRetained from startObserving()
        if let ptr = selfPtr {
            Unmanaged<WindowObserver>.fromOpaque(ptr).release()
            selfPtr = nil
        }
        observer = nil
        callback = nil
    }

    // MARK: - Internal callback trigger

    fileprivate func handleNotification(_ name: String) {
        callback?(name)
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
    // Retrieve WindowObserver from the retained pointer (balance with passRetained)
    let windowObserver = Unmanaged<WindowObserver>.fromOpaque(refcon).takeUnretainedValue()
    windowObserver.handleNotification(notification as String)
}
