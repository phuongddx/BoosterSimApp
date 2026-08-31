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

    // MARK: - Private

    private let simCtl: SimCtlService
    private let certificateService: CertificateService
    private var cancellables = Set<AnyCancellable>()
    private var scannedApps: [DiscoveredApp] = []

    // MARK: - Lifecycle

    init(simCtl: SimCtlService, certificateService: CertificateService) {
        self.simCtl = simCtl
        self.certificateService = certificateService
    }

    // MARK: - App Discovery

    /// Refreshes picker candidates: DerivedData scan ∩ listapps-installed, running apps badged.
    func refreshApps(udid: String?) {
        guard let udid, !udid.isEmpty else { return }
        guard begin(.refreshing) else { return }
        scannedApps = DerivedDataAppScanner.scan(root: DerivedDataAppScanner.defaultRoot)
        AppLogger.actions.info("Scanned DerivedData — \(self.scannedApps.count) iOS app(s)")
        simCtl.run(Self.listAppsCommand(udid: udid))
            .flatMap { [weak self] _ -> AnyPublisher<String, SimCtlError> in
                guard let self else { return Empty().eraseToAnyPublisher() }
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
                    self.installedBundleIDs = Self.parseInstalledApps(fromListAppsXML: launchctlOutput)
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
