// AppActionService.swift — Facade for simulator app actions (refresh, reset, uninstall) over the simctl seam
import Foundation
import Combine
import OSLog

@MainActor
final class AppActionService: ObservableObject {

    // MARK: - Published State

    @Published private(set) var operation: AppActionOperation = .idle
    @Published private(set) var statusCaption: String?
    @Published private(set) var candidates: [DiscoveredApp] = []
    @Published private(set) var runningBundleIDs: Set<String> = []
    @Published private(set) var installedBundleIDs: Set<String> = []
    @Published var activeBundleID: String?
    @Published private(set) var privacyCaption: String?

    // MARK: - Private

    private let simCtl: SimCtlService
    private let certificateService: any AppKeychainResetting
    private let keychainEvents: AnyPublisher<CertificateOperation, Never>
    private var cancellables = Set<AnyCancellable>()
    private var scannedApps: [DiscoveredApp] = []

    // MARK: - Lifecycle

    convenience init(simCtl: SimCtlService, certificateService: CertificateService) {
        self.init(simCtl: simCtl,
                  certificateService: certificateService,
                  keychainEvents: certificateService.$operation.eraseToAnyPublisher())
    }

    init(simCtl: SimCtlService,
         certificateService: any AppKeychainResetting,
         keychainEvents: AnyPublisher<CertificateOperation, Never>) {
        self.simCtl = simCtl
        self.certificateService = certificateService
        self.keychainEvents = keychainEvents
    }

    // MARK: - App Discovery

    /// Refreshes picker candidates: DerivedData scan ∩ listapps-installed, running apps badged.
    func refreshApps(udid: String?) {
        guard let udid, !udid.isEmpty else { return }
        guard begin(.refreshing) else { return }
        scannedApps = DerivedDataAppScanner.scan(root: DerivedDataAppScanner.defaultRoot)
        AppLogger.actions.info("Scanned DerivedData — \(self.scannedApps.count) iOS app(s)")
        simCtl.run(Self.listAppsCommand(udid: udid))
            .flatMap { [weak self] listAppsXML -> AnyPublisher<String, SimCtlError> in
                guard let self else { return Empty().eraseToAnyPublisher() }
                self.installedBundleIDs = Self.parseInstalledApps(fromListAppsXML: listAppsXML)
                return self.simCtl.run(Self.launchctlCommand(udid: udid))
            }
            .timeout(.seconds(30), scheduler: DispatchQueue.main, customError: { .timeout })
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.fail("Could not load apps: \(error.localizedDescription)")
                    }
                },
                receiveValue: { [weak self] launchctlOutput in
                    guard let self else { return }
                    self.runningBundleIDs = Self.parseRunningApps(fromLaunchctlOutput: launchctlOutput)
                    self.publishCandidates()
                    self.finish(with: nil)
                }
            )
            .store(in: &cancellables)
    }

    // MARK: - Reset

    /// Reset App Data: terminate → listapps presence check → uninstall (erases the data container)
    /// → reinstall from DerivedData when a build exists (A6: degrade honestly if that leg fails).
    func resetApp(udid: String, bundleID: String) {
        guard Self.isDestructiveUDID(udid) else { failWithAmbiguousUDID(); return }
        guard begin(.resetting) else { return }
        statusCaption = nil
        simCtl.run(Self.terminateCommand(udid: udid, bundleID: bundleID))
            .catch { _ in Empty<String, SimCtlError>().eraseToAnyPublisher() }  // not-running terminate fails; harmless
            .flatMap { [weak self] _ -> AnyPublisher<String, SimCtlError> in
                guard let self else { return Empty().eraseToAnyPublisher() }
                return self.simCtl.run(Self.listAppsCommand(udid: udid))
            }
            .flatMap { [weak self] listApps -> AnyPublisher<ResetOutcome, SimCtlError> in
                guard let self else { return Empty().eraseToAnyPublisher() }
                self.installedBundleIDs = Self.parseInstalledApps(fromListAppsXML: listApps)
                guard self.installedBundleIDs.contains(bundleID) else {
                    return Just(.absent).setFailureType(to: SimCtlError.self).eraseToAnyPublisher()
                }
                return self.simCtl.run(Self.uninstallCommand(udid: udid, bundleID: bundleID))
                    .map { _ in ResetOutcome.uninstalled }
                    .eraseToAnyPublisher()
            }
            .flatMap { [weak self] outcome -> AnyPublisher<ResetOutcome, SimCtlError> in
                guard let self, case .uninstalled = outcome,
                      let path = self.scannedApps.first(where: { $0.bundleID == bundleID })?.productPath.path
                else {
                    return Just(outcome).setFailureType(to: SimCtlError.self).eraseToAnyPublisher()
                }
                return self.simCtl.run(Self.installCommand(udid: udid, productPath: path))
                    .map { _ in ResetOutcome.reset }
                    .catch { error in
                        // Flagged assumption A6: the reinstall may fail — degrade honestly, never claim success.
                        Just(ResetOutcome.reinstallFailed(error.localizedDescription))
                            .setFailureType(to: SimCtlError.self)
                            .eraseToAnyPublisher()
                    }
                    .eraseToAnyPublisher()
            }
            .timeout(.seconds(30), scheduler: DispatchQueue.main, customError: { .timeout })
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    guard let self, case .failure(let error) = completion else { return }
                    self.fail("Reset failed before completion: \(error.localizedDescription)")
                },
                receiveValue: { [weak self] outcome in
                    guard let self else { return }
                    self.installedBundleIDs.remove(bundleID)
                    if outcome == .reset { self.installedBundleIDs.insert(bundleID) }
                    self.publishCandidates()
                    self.finish(with: Self.resetCaption(outcome, appName: self.appName(for: bundleID)))
                }
            )
            .store(in: &cancellables)
    }

    /// Plain Uninstall: removes the app and its data container (behind its own confirmation).
    func uninstallApp(udid: String, bundleID: String) {
        guard Self.isDestructiveUDID(udid) else { failWithAmbiguousUDID(); return }
        guard begin(.uninstalling) else { return }
        statusCaption = nil
        simCtl.run(Self.uninstallCommand(udid: udid, bundleID: bundleID))
            .timeout(.seconds(30), scheduler: DispatchQueue.main, customError: { .timeout })
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.fail("Uninstall failed: \(error.localizedDescription)")
                    }
                },
                receiveValue: { [weak self] _ in
                    guard let self else { return }
                    self.installedBundleIDs.remove(bundleID)
                    self.publishCandidates()
                    self.finish(with: "\(self.appName(for: bundleID)) removed from the Simulator.")
                }
            )
            .store(in: &cancellables)
    }

    // MARK: - Keychain (D-02)

    /// Device-wide keychain wipe + automatic local-CA reconcile (D-02). DELEGATES — never re-implements:
    /// resetKeychain already runs the device verb, clears the persisted-install record, and lands its own
    /// state machine. On completion this triggers reconcileStatus (the same entry point SideWindowController
    /// drives on simulator change) and re-installs the CA when one exists, so certificate trust needs no
    /// manual steps. The AppResetSectionView dialog names the blast radius before this ever runs.
    func clearKeychain(udid: String, deviceName: String) {
        guard Self.isDestructiveUDID(udid) else { failWithAmbiguousUDID(); return }
        guard !certificateService.operation.isWorking else {
            fail("Certificate service is busy — try again in a moment.")
            return
        }
        guard begin(.clearingKeychain) else { return }
        statusCaption = nil
        keychainEvents
            .dropFirst()                             // skip the current idle value
            .first { !$0.isWorking }                 // terminal state of this reset run
            .flatMap { [weak self] terminal -> AnyPublisher<String, Never> in
                guard let self else { return Empty().eraseToAnyPublisher() }
                self.certificateService.reconcileStatus(udid: udid)
                if case .error(let message) = terminal {
                    return Just("Keychain wipe failed: \(message)").eraseToAnyPublisher()
                }
                guard self.certificateService.status.certificateMetadata != nil else {
                    return Just("Keychain cleared — no local CA on disk to reconcile.").eraseToAnyPublisher()
                }
                self.certificateService.install(udid: udid, deviceName: deviceName)
                return self.keychainEvents.dropFirst().first { !$0.isWorking }
                    .map { installTerminal -> String in
                        if case .error(let message) = installTerminal {
                            return "Keychain cleared, but re-installing the local CA failed: \(message)"
                        }
                        return "Keychain cleared — local CA re-installed automatically."
                    }
                    .eraseToAnyPublisher()
            }
            .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] caption in
                AppLogger.actions.info("Keychain clear finished — CA reconcile completed")  // verb + outcome only
                self?.finish(with: caption)
            })
            .store(in: &cancellables)
        certificateService.resetKeychain(udid: udid)
    }

    // MARK: - Privacy (12 TCC services — D-01 companion)

    /// Grants/revokes one TCC service for the active app (`privacy <udid> grant|revoke <service> [<bundle>]`).
    /// One shared single-hop verb runner: 30s timeout, main delivery, verb+outcome logging only.
    func setPrivacy(_ permission: PrivacyPermission, action: PrivacyAction, udid: String, bundleID: String? = nil) {
        guard !udid.isEmpty else {
            privacyCaption = "No active Simulator — privacy changes need a running device."
            return
        }
        var args = permission.simctlArgs(udid: udid, action: action)
        if let bundleID { args.append(bundleID) }   // scoped to the picker's active app
        runVerb(args) { [weak self] result in
            switch result {
            case .success:
                AppLogger.actions.info("privacy \(action.rawValue) completed")   // verb + outcome only
                self?.privacyCaption = "\(permission.label) \(action == .grant ? "granted" : "revoked")"
                    + (bundleID != nil ? " for the active app." : ".")
            case .failure(let error):
                AppLogger.actions.error("privacy \(action.rawValue) failed")
                self?.privacyCaption = "\(permission.label) \(action.label.lowercased()) failed: "
                    + "\(error.localizedDescription)"
            }
        }
    }

    /// `privacy <udid> reset all` — resets TCC services device-wide (NOT notification permission;
    /// that is managed by iOS per D-01). Destructive: the call site sits only inside a
    /// confirmationDialog, and the verb refuses the ambiguous `booted`/empty UDIDs.
    func resetAllPrivacy(udid: String) {
        guard Self.isDestructiveUDID(udid) else { failWithAmbiguousUDID(); return }
        runVerb(PrivacyPermission.resetAllArgs(udid: udid)) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success:
                AppLogger.actions.info("privacy reset all completed")
                self.privacyCaption = "All TCC privacy services reset on the device."
            case .failure(let error):
                AppLogger.actions.error("privacy reset all failed")
                self.privacyCaption = "Privacy reset failed: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Device Settings (D-01 Settings link)

    /// Launches the device's Settings app so the user can perform the manual notification
    /// grant D-01 guides them through. simctl cannot set notification permission — this verb
    /// only opens the destination; the Send button in the Push section is the verify probe.
    func openDeviceSettings(udid: String) {
        guard !udid.isEmpty else { return }
        runVerb(["launch", udid, "com.apple.Preferences"]) { [weak self] result in
            if case .failure(let error) = result {
                AppLogger.actions.error("open device settings failed")
                self?.privacyCaption = "Could not open Settings: \(error.localizedDescription)"
            } else {
                AppLogger.actions.info("opened device settings")
            }
        }
    }

    // MARK: - Single-Hop Verb Runner

    /// Thin shared runner for one-hop verbs (privacy, device settings, later push): 30s timeout,
    /// main-thread delivery, single sink stored in the facade's cancellables.
    private func runVerb(
        _ args: [String], stdin: Data? = nil,
        onResult: @escaping (Result<String, SimCtlError>) -> Void
    ) {
        simCtl.run(args, stdin: stdin)
            .timeout(.seconds(30), scheduler: DispatchQueue.main, customError: { .timeout })
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion { onResult(.failure(error)) }
                },
                receiveValue: { onResult(.success($0)) }
            )
            .store(in: &cancellables)
    }

    // MARK: - State Machine (CertificateService quartet shape)

    private func begin(_ next: AppActionOperation) -> Bool {
        guard !operation.isWorking else { return false }
        transition(to: next)
        return true
    }

    private func finish(with caption: String?) {
        statusCaption = caption
        transition(to: .idle)
    }

    private func fail(_ message: String) {
        AppLogger.actions.error("App action failed: \(message, privacy: .public)")
        statusCaption = message
        transition(to: .error(message))
    }

    private func transition(to next: AppActionOperation) {
        if operation != next, !operation.canTransition(to: next) {
            assertionFailure("Illegal app action transition: \(operation) -> \(next)")
        }
        operation = next
    }

    // MARK: - Private Helpers

    /// Every destructive verb refuses the ambiguous default UDID and empty input
    /// (CertificateService discipline — never act on "booted").
    private func failWithAmbiguousUDID() {
        fail("No active Simulator with a concrete UDID — destructive actions need an exact device.")
    }

    private func publishCandidates() {
        let picked = Self.reconcileCandidates(
            scanned: scannedApps, installed: installedBundleIDs, running: runningBundleIDs
        )
        candidates = picked.candidates
        runningBundleIDs = picked.runningBadges
        let stillValid = activeBundleID.map { id in
            picked.candidates.contains(where: { $0.bundleID == id })
        } ?? false
        if !stillValid {
            activeBundleID = picked.candidates.first?.bundleID  // default to the newest build
        }
    }

    private func appName(for bundleID: String) -> String {
        scannedApps.first(where: { $0.bundleID == bundleID })?.name ?? bundleID
    }
}
