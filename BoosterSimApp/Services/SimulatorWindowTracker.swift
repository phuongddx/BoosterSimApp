// SimulatorWindowTracker.swift — Detects and tracks Simulator windows; classifies device types.
// Combines CGWindowList polling with AXObserver real-time callbacks.
import AppKit
import Combine

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

    // MARK: - Private

    private var observers: [pid_t: WindowObserver] = [:]
    private var pollTimer: Timer?
    private var workspaceObservers: [NSObjectProtocol] = []

    // Device info cache: device name → (type, UDID) from simctl list devices --json
    private var deviceInfoCache: [String: DeviceInfo] = [:]

    // MARK: - Public API

    func startTracking() {
        refreshDeviceTypeCache()
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
        activeSimulator = classified.first

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
        obs.startObserving { [weak self] _ in
            self?.scanAndUpdate()
        }
        observers[pid] = obs
    }

    // MARK: - Polling Fallback

    private func startPolling() {
        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
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

        workspaceObservers = [launchObs, terminateObs]
    }
}
