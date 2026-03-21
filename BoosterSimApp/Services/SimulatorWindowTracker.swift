// SimulatorWindowTracker.swift — Detects and tracks iOS Simulator windows
// Combines CGWindowList polling with AXObserver real-time callbacks.
import AppKit
import Combine

final class SimulatorWindowTracker: ObservableObject {

    // MARK: - Published State

    @Published private(set) var simulators: [SimulatorWindow] = []
    @Published private(set) var activeSimulator: SimulatorWindow?

    // MARK: - Private

    private var observers: [pid_t: WindowObserver] = [:]
    private var pollTimer: Timer?
    private var workspaceObservers: [NSObjectProtocol] = []

    // MARK: - Public API

    func startTracking() {
        scanAndUpdate()
        setupWorkspaceNotifications()
        startPolling()
    }

    func stopTracking() {
        pollTimer?.invalidate()
        pollTimer = nil
        observers.values.forEach { $0.stopObserving() }
        observers.removeAll()
        workspaceObservers.forEach {
            NSWorkspace.shared.notificationCenter.removeObserver($0)
        }
        workspaceObservers.removeAll()
    }

    // MARK: - Scanning

    private func scanAndUpdate() {
        let found = WindowEnumerator.enumerateSimulatorWindows()
        simulators = found
        activeSimulator = found.first

        // Setup AX observers for any new PIDs
        let foundPIDs = Set(found.map(\.pid))
        for pid in foundPIDs where observers[pid] == nil {
            setupObserver(for: pid)
        }

        // Remove observers for PIDs no longer active
        for pid in observers.keys where !foundPIDs.contains(pid) {
            observers[pid]?.stopObserving()
            observers.removeValue(forKey: pid)
        }
    }

    private func setupObserver(for pid: pid_t) {
        let obs = WindowObserver(pid: pid)
        obs.startObserving { [weak self] notification in
            self?.handleAXNotification(notification, pid: pid)
        }
        observers[pid] = obs
    }

    // MARK: - AX Notification Handler

    private func handleAXNotification(_ notification: String, pid: pid_t) {
        // Re-scan on any structural change to keep our model accurate
        scanAndUpdate()
    }

    // MARK: - Polling Fallback

    private func startPolling() {
        // 0.5s poll as fallback when AXObserver is unavailable (no Accessibility permission)
        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.scanAndUpdate()
        }
    }

    // MARK: - Workspace Notifications (Simulator launch/quit)

    private func setupWorkspaceNotifications() {
        let center = NSWorkspace.shared.notificationCenter

        let launchObs = center.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  app.localizedName == "Simulator" else { return }
            self?.scanAndUpdate()
        }

        let terminateObs = center.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  app.localizedName == "Simulator" else { return }
            self?.scanAndUpdate()
        }

        workspaceObservers = [launchObs, terminateObs]
    }
}
