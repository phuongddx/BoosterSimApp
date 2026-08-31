// UserDefaultsEditorService.swift — Typed UserDefaults editor: on-disk plist read + validated spawn writes
// Read path resolves the app's data container and reads Library/Preferences/<bundle>.plist
// DIRECTLY (NSDictionary) — NEVER the `defaults export` verb, which silently does nothing in
// the simulator (RESEARCH Pitfall 5, prohibition). Writes/deletes go through validated
// spawn-defaults argv. Logging carries domain and key names only — never values (T-03-10).
import Foundation
import Combine
import OSLog

// MARK: - Operation & Error

/// Editor operation state (CertificateService shell, minimal subset).
enum UserDefaultsEditorOperation: Equatable {
    case idle
    case loading
    case writing
    case error(String)

    var isWorking: Bool { self == .loading || self == .writing }
}

/// Typed validation failures — surfaced BEFORE any argv exists (T-03-11).
enum DefaultsEditorError: Error, Equatable {
    case noDevice
    case invalidDomain
    case invalidKey

    var message: String {
        switch self {
        case .noDevice:       return "No active Simulator — defaults editing needs a running device."
        case .invalidDomain:  return "App domains may only contain letters, numbers, dot, underscore, and hyphen."
        case .invalidKey:     return "Keys may only contain letters, numbers, dot, underscore, and hyphen."
        }
    }
}

// MARK: - Service

@MainActor
final class UserDefaultsEditorService: ObservableObject {

    // MARK: - Published State

    @Published private(set) var entries: [DefaultsEntry] = []
    @Published private(set) var loadError: String?
    @Published private(set) var operation: UserDefaultsEditorOperation = .idle
    /// The most recently written or deleted key NAME — captions carry key names only (T-03-10).
    @Published private(set) var lastEditedKey: String?

    // MARK: - Private

    private let simCtl: any SimCtlRunning
    private var cancellables = Set<AnyCancellable>()
    /// A load requested while another is in flight — the newest target wins (03-REVIEW WR-02).
    private var pendingLoad: (udid: String, bundle: String)?

    // MARK: - Lifecycle

    init(simCtl: any SimCtlRunning) {
        self.simCtl = simCtl
    }

    // MARK: - Load (plist FILE through the app container)

    /// Reads the active app's on-disk Preferences plist via its data container. An app that
    /// has never written a default has no plist file — that renders an EMPTY list, not an
    /// error. A request made while a load is in flight SUPERSEDES it (03-REVIEW WR-02): the
    /// newest (udid, bundle) target re-runs when the pipeline frees, and the stale domain's
    /// result is never published.
    func loadDomain(udid: String, bundle: String) {
        guard !udid.isEmpty else {
            loadError = DefaultsEditorError.noDevice.message
            return
        }
        guard operation != .loading else {
            pendingLoad = (udid, bundle)         // never drop the newest target mid-load
            return
        }
        startLoad(udid: udid, bundle: bundle)
    }

    private func startLoad(udid: String, bundle: String) {
        operation = .loading
        entries = []                             // never render the previous domain's rows under this header
        loadError = nil
        simCtl.run(Self.containerArgs(udid: udid, bundle: bundle))
            .timeout(.seconds(30), scheduler: DispatchQueue.main, customError: { .timeout })
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    guard let self, case .failure(let error) = completion else { return }
                    AppLogger.actions.error("defaults load failed for \(bundle, privacy: .public)")
                    if let pending = self.pendingLoad {  // a newer load supersedes this stale failure
                        self.pendingLoad = nil
                        self.startLoad(udid: pending.udid, bundle: pending.bundle)
                        return
                    }
                    self.entries = []
                    self.loadError = "Could not read the app's preferences: \(error.localizedDescription)"
                    self.operation = .error(self.loadError!)
                },
                receiveValue: { [weak self] containerPath in
                    guard let self else { return }
                    if let pending = self.pendingLoad {  // the stale domain's result is never published
                        self.pendingLoad = nil
                        self.startLoad(udid: pending.udid, bundle: pending.bundle)
                        return
                    }
                    let plistPath = Self.preferencesPlistPath(containerPath: containerPath, bundleID: bundle)
                    self.entries = Self.parseEntries(fromPlistAt: plistPath)
                    // Keys-count only — key names and values stay out of the log line.
                    let keyCount = self.entries.count
                    AppLogger.actions.info("defaults loaded — \(keyCount) key(s) in \(bundle, privacy: .public)")
                    self.loadError = nil   // an empty plist renders an empty list, not an error
                    self.operation = .idle
                }
            )
            .store(in: &cancellables)
    }

    // MARK: - Write / Delete (validated typed verbs, then reload)

    /// Writes one typed entry. Validation runs BEFORE any argv is built (T-03-11); on success
    /// the domain reloads so the list reflects the new value (writes land on disk instantly —
    /// RESEARCH Verified Surface). Identical typed writes are idempotent.
    func write(entry: DefaultsEntry, udid: String, bundle: String) {
        guard !operation.isWorking else { return }
        switch Self.writeArgs(entry: entry, udid: udid, domain: bundle) {
        case .failure(let error):
            operation = .error(error.message)
        case .success(let args):
            runEditorVerb(args, key: entry.key, verb: "write", udid: udid, bundle: bundle)
        }
    }

    /// Deletes one key, then reloads the domain.
    func delete(key: String, udid: String, bundle: String) {
        guard !operation.isWorking else { return }
        switch Self.deleteArgs(key: key, udid: udid, domain: bundle) {
        case .failure(let error):
            operation = .error(error.message)
        case .success(let args):
            runEditorVerb(args, key: key, verb: "delete", udid: udid, bundle: bundle)
        }
    }

    /// One editor verb: 30s timeout, main delivery, key-name-only logging, reload on success.
    private func runEditorVerb(_ args: [String], key: String, verb: String, udid: String, bundle: String) {
        operation = .writing
        simCtl.run(args)
            .timeout(.seconds(30), scheduler: DispatchQueue.main, customError: { .timeout })
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    guard let self, case .failure(let error) = completion else { return }
                    AppLogger.actions.error("defaults \(verb) failed for key \(key, privacy: .public)")
                    self.operation = .error("Could not \(verb) key \(key): \(error.localizedDescription)")
                },
                receiveValue: { [weak self] _ in
                    guard let self else { return }
                    AppLogger.actions.info("defaults \(verb) completed for key \(key, privacy: .public)")
                    self.lastEditedKey = key
                    self.loadDomain(udid: udid, bundle: bundle)
                }
            )
            .store(in: &cancellables)
    }

    // MARK: - Pure Builders & Parsers (unit-tested — no subprocess anywhere near these)

    /// `get_app_container <udid> <bundle> data` — the container resolution verb.
    nonisolated static func containerArgs(udid: String, bundle: String) -> [String] {
        ["get_app_container", udid, bundle, "data"]
    }

    /// Composes the on-disk Preferences plist path from the container `get_app_container` prints.
    nonisolated static func preferencesPlistPath(containerPath: String, bundleID: String) -> String {
        let trimmed = containerPath.trimmingCharacters(in: .whitespacesAndNewlines)
        return (trimmed as NSString).appendingPathComponent("Library/Preferences/\(bundleID).plist")
    }

    /// Allowlist for domain and key names: `[A-Za-z0-9._-]`, non-empty (ASVS V5 — the argv
    /// shape is the only injection surface; argv-only invocation, never a shell).
    nonisolated static func isValidName(_ name: String) -> Bool {
        !name.isEmpty && name.allSatisfy { Self.allowedNameCharacters.contains($0) }
    }

    /// Typed write argv — `spawn <udid> defaults write <domain> <key> <type> <value(s)>`.
    /// Invalid names produce NO argv at all (typed error path).
    nonisolated static func writeArgs(entry: DefaultsEntry, udid: String, domain: String)
        -> Result<[String], DefaultsEditorError> {
        guard !udid.isEmpty else { return .failure(.noDevice) }
        guard isValidName(domain) else { return .failure(.invalidDomain) }
        guard isValidName(entry.key) else { return .failure(.invalidKey) }
        return .success(["spawn", udid, "defaults", "write", domain, entry.key] + entry.simctlTypeArg)
    }

    /// Typed delete argv — `spawn <udid> defaults delete <domain> <key>`.
    nonisolated static func deleteArgs(key: String, udid: String, domain: String)
        -> Result<[String], DefaultsEditorError> {
        guard !udid.isEmpty else { return .failure(.noDevice) }
        guard isValidName(domain) else { return .failure(.invalidDomain) }
        guard isValidName(key) else { return .failure(.invalidKey) }
        return .success(["spawn", udid, "defaults", "delete", domain, key])
    }

    /// Reads and parses a Preferences plist FILE. A missing file (app never wrote a default)
    /// is an empty list, not an error. Entries sort by key so rows never shuffle between loads.
    nonisolated static func parseEntries(fromPlistAt path: String) -> [DefaultsEntry] {
        guard let dictionary = NSDictionary(contentsOfFile: path) as? [String: Any] else { return [] }
        return dictionary
            .map { DefaultsEntry(key: $0.key, value: entryValue(from: $0.value)) }
            .sorted { $0.key < $1.key }
    }

    /// Maps one property-list object to the typed wrapper. The CFBoolean check MUST come
    /// first: plain `as? Bool` also succeeds for integers 0/1 via NSNumber bridging.
    nonisolated static func entryValue(from plistValue: Any) -> DefaultsEntryValue {
        if let number = plistValue as? NSNumber,
           CFGetTypeID(number as CFTypeRef) == CFBooleanGetTypeID() {
            return .bool(number.boolValue)
        }
        if let number = plistValue as? Int { return .int(number) }
        if let text = plistValue as? String { return .string(text) }
        if let items = plistValue as? [String] { return .array(items) }
        if let payload = plistValue as? Data { return .json(payload) }
        // Nested dicts, mixed arrays, dates, floats — carried losslessly as a plist capsule.
        if let capsule = try? PropertyListSerialization.data(
            fromPropertyList: plistValue, format: .binary, options: 0) {
            return .json(capsule)
        }
        return .string(String(describing: plistValue))
    }

    private nonisolated static let allowedNameCharacters =
        Set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-")
}
