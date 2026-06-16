// SimulatorWindowTracker.swift — Detects and tracks Simulator windows; classifies device types.
// Combines CGWindowList polling with AXObserver real-time callbacks.
import AppKit
import Combine
import OSLog

// MARK: - Device Info Cache Entry

private struct DeviceInfo {
    let type: SimulatorDeviceType
    let udid: String
}

// MARK: - Tracker

final class SimulatorWindowTracker: ObservableObject {

    // MARK: - Published State

    @Published private(set) var simulators: [SimulatorWindow] = []
    @Published private(set) var activeSimulator: SimulatorWindow?
    /// True when Simulator.app or BoosterSimApp is the frontmost application.
    @Published private(set) var isSimulatorFocused = false

    // MARK: - Private

    private var observers: [pid_t: WindowObserver] = [:]
    private var pollTimer: Timer?
    private var workspaceObservers: [NSObjectProtocol] = []

    // Device info cache: device name → (type, UDID) from simctl list devices --json
    private var deviceInfoCache: [String: DeviceInfo] = [:]

    // MARK: - Public API

    deinit {
        stopTracking()
    }

    func startTracking() {
        refreshDeviceTypeCache()
        scanAndUpdate()
        setupWorkspaceNotifications()
        startPolling()
        // Seed initial focus state from current frontmost app
        let frontName = NSWorkspace.shared.frontmostApplication?.localizedName ?? ""
        isSimulatorFocused = (frontName == "Simulator" || frontName == "BoosterSimApp")
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

    // MARK: - Device Classification

    /// Refresh cache of device name → (type, UDID) from simctl list devices --json.
    /// Runs process on background queue; updates cache on main.
    func refreshDeviceTypeCache() {
        DispatchQueue.global(qos: .background).async { [weak self] in
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
            proc.arguments = ["simctl", "list", "devices", "--json"]
            let pipe = Pipe()
            proc.standardOutput = pipe
            proc.standardError  = Pipe()
            guard (try? proc.run()) != nil else { return }
            proc.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let runtimes = json["devices"] as? [String: [[String: Any]]] else { return }

            var cache: [String: DeviceInfo] = [:]
            for deviceList in runtimes.values {
                for device in deviceList {
                    guard let name   = device["name"] as? String,
                          let udid   = device["udid"] as? String,
                          let typeId = device["deviceTypeIdentifier"] as? String else { continue }
                    let type: SimulatorDeviceType
                    if typeId.contains("Watch") {
                        type = .watchOS
                    } else if typeId.contains("AppleTV") || typeId.contains("-TV") {
                        type = .tvOS
                    } else if typeId.contains("XR") || typeId.contains("Vision") {
                        type = .visionOS
                    } else {
                        type = .iOS
                    }
                    cache[name] = DeviceInfo(type: type, udid: udid)
                }
            }
            DispatchQueue.main.async {
                self?.deviceInfoCache = cache
                self?.scanAndUpdate()
            }
        }
    }

    // MARK: - Scanning

    private func scanAndUpdate() {
        let found = WindowEnumerator.enumerateSimulatorWindows()

        // Apply device type + UDID from cache
        let classified = found.map { window -> SimulatorWindow in
            var w = window
            if let name = window.deviceName, let info = deviceInfoCache[name] {
                w.deviceType = info.type
                w.udid       = info.udid
            }
            return w
        }

        simulators      = classified
        let newActive = classified.first
        if activeSimulator != newActive {
            activeSimulator = newActive
        }

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
        AppLogger.windowTracking.info("AX observer set up for pid=\(pid, privacy: .public)")
        let obs = WindowObserver(pid: pid)
        // Lifecycle events (created, destroyed, miniaturized) → full scan
        // Move/resize events are handled by onFrameChanged fast path below
        obs.startObserving { [weak self] _, _ in
            self?.scanAndUpdate()
        }
        // Fast path: update frame directly without CGWindowList scan during drag
        obs.onFrameChanged = { [weak self] frame in
            guard let self else { return }
            guard let idx = self.simulators.firstIndex(where: { $0.pid == pid }) else { return }
            self.simulators[idx].frame = frame
            if self.activeSimulator?.pid == pid {
                self.activeSimulator = self.simulators[idx]
            }
        }
        observers[pid] = obs
    }

    // MARK: - Polling Fallback

    private func startPolling() {
        // AX observer handles real-time updates; poll is fallback for edge cases
        pollTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.scanAndUpdate()
        }
    }

    // MARK: - Workspace Notifications

    private func setupWorkspaceNotifications() {
        let center = NSWorkspace.shared.notificationCenter

        let launchObs = center.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification,
            object: nil, queue: .main
        ) { [weak self] note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  app.localizedName == "Simulator" else { return }
            self?.refreshDeviceTypeCache()
        }

        let terminateObs = center.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification,
            object: nil, queue: .main
        ) { [weak self] note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  app.localizedName == "Simulator" else { return }
            self?.scanAndUpdate()
        }

        // Track which app is frontmost — hide panel when Simulator loses focus
        let activateObs = center.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil, queue: .main
        ) { [weak self] note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            let name = app.localizedName ?? ""
            self?.isSimulatorFocused = (name == "Simulator" || name == "BoosterSimApp")
        }

        workspaceObservers = [launchObs, terminateObs, activateObs]
    }
}
