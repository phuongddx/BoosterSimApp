// AppActionModels.swift — App action operation state machine, reset outcomes, and pure simctl argv/parsers
import Foundation

// MARK: - Operation

enum AppActionOperation: Equatable {
    case idle
    case refreshing
    case resetting
    case uninstalling
    case clearingKeychain
    case error(String)

    var isWorking: Bool {
        switch self {
        case .idle, .error: false
        default: true
        }
    }

    func canTransition(to next: AppActionOperation) -> Bool {
        switch self {
        case .idle:
            // Idle may start any verb or land a typed refusal error directly.
            return true
        case .refreshing, .resetting, .uninstalling, .clearingKeychain:
            // One action pipeline at a time — reentrant work is rejected.
            if case .idle = next { return true }
            if case .error = next { return true }
            return false
        case .error:
            // Recoverable: an error may return to idle or start any verb.
            return true
        }
    }
}

// MARK: - Reset Outcome

/// Terminal outcome of a Reset App Data run — the status-caption source. Keeps the
/// reinstall-degrade honest (flagged assumption A6): a failed reinstall is never reported as success.
enum ResetOutcome: Equatable {
    case absent                                  // was not installed — nothing erased
    case uninstalled                             // container erased; no DerivedData build to reinstall
    case reset                                   // terminated + uninstalled + reinstalled from DerivedData
    case reinstallFailed(String)                 // container erased; the reinstall leg failed (honest degrade)
}

// MARK: - Pure Command Builders (simctl argv — 03-RESEARCH Verified Surface)

extension AppActionService {

    nonisolated static func terminateCommand(udid: String, bundleID: String) -> [String] {
        ["terminate", udid, bundleID]
    }

    nonisolated static func listAppsCommand(udid: String) -> [String] {
        ["listapps", udid]
    }

    nonisolated static func uninstallCommand(udid: String, bundleID: String) -> [String] {
        ["uninstall", udid, bundleID]
    }

    nonisolated static func installCommand(udid: String, productPath: String) -> [String] {
        ["install", udid, productPath]
    }

    nonisolated static func launchctlCommand(udid: String) -> [String] {
        ["spawn", udid, "launchctl", "list"]
    }

    /// Destructive verbs act only on a concrete UDID — never the ambiguous `booted` default.
    nonisolated static func isDestructiveUDID(_ udid: String) -> Bool {
        !udid.isEmpty && udid != "booted"
    }

    /// Parses `simctl listapps` XML plist output into the installed bundle-ID set.
    /// Root keys are bundle IDs; values carry CFBundleIdentifier — accept either shape.
    nonisolated static func parseInstalledApps(fromListAppsXML output: String) -> Set<String> {
        guard let data = output.data(using: .utf8),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        else { return [] }
        var bundleIDs = Set<String>()
        for (key, value) in plist {
            if let info = value as? [String: Any],
               let id = info["CFBundleIdentifier"] as? String, !id.isEmpty {
                bundleIDs.insert(id)
            } else if !key.isEmpty {
                bundleIDs.insert(key)
            }
        }
        return bundleIDs
    }

    /// Parses `launchctl list` output — apps run under `UIKitApplication:<bundle>[<pid>][rb-legacy]` rows.
    nonisolated static func parseRunningApps(fromLaunchctlOutput output: String) -> Set<String> {
        var running = Set<String>()
        for line in output.split(separator: "\n") {
            guard let prefix = line.range(of: "UIKitApplication:") else { continue }
            let afterPrefix = line[prefix.upperBound...]
            guard let bracket = afterPrefix.firstIndex(of: "[") else { continue }
            let bundleID = String(afterPrefix[..<bracket])
            if !bundleID.isEmpty { running.insert(bundleID) }
        }
        return running
    }

    /// Pure picker reconcile: DerivedData scan ∩ installed, order preserved (newest first);
    /// the running set is reduced to badges on surviving candidates.
    nonisolated static func reconcileCandidates(
        scanned: [DiscoveredApp], installed: Set<String>, running: Set<String>
    ) -> (candidates: [DiscoveredApp], runningBadges: Set<String>) {
        let candidates = scanned.filter { installed.contains($0.bundleID) }
        let badges = Set(candidates.map(\.bundleID)).intersection(running)
        return (candidates, badges)
    }

    /// Caption for a reset terminal outcome — honesty contract for the A6 degrade path.
    nonisolated static func resetCaption(_ outcome: ResetOutcome, appName: String) -> String {
        switch outcome {
        case .absent:
            return "\(appName) was not installed — nothing to reset."
        case .uninstalled:
            return "\(appName) data erased; app left uninstalled (no DerivedData build to reinstall)."
        case .reset:
            return "\(appName) reset — reinstalled from your latest build."
        case .reinstallFailed(let message):
            return "\(appName) data erased, app left uninstalled — reinstall failed: \(message)"
        }
    }
}

// MARK: - Keychain Seam (D-02)

/// Subset of CertificateService that AppActionService drives for the device-wide keychain clear.
/// Declared as a protocol so tests pin the reset → reconcile delegate order with a scripted double;
/// CertificateService conforms for free — every member already exists.
@MainActor
protocol AppKeychainResetting: AnyObject {
    var operation: CertificateOperation { get }
    var status: CertificateStatus { get }
    func resetKeychain(udid: String)
    func reconcileStatus(udid: String?)
    func install(udid: String, deviceName: String)
}

extension CertificateService: AppKeychainResetting {}
