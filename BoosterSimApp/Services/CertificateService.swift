import Foundation
import Combine
import OSLog

private enum RetryAction {
    case generate
    case install
    case rotate
    case reset
}

@MainActor
final class CertificateService: ObservableObject {

    @Published private(set) var status: CertificateStatus = .notGenerated
    @Published private(set) var operation: CertificateOperation = .idle

    private enum StorageKey {
        static let installedFingerprint = "cert.lastInstalledFingerprint"
        static let installedUDID = "cert.lastInstalledUDID"
        static let installedDeviceName = "cert.lastInstalledDeviceName"
    }

    private let simCtl: SimCtlService
    private let store = CertificateStore()
    private let defaults: UserDefaults

    private var cancellables = Set<AnyCancellable>()
    private var lastFailedAction: RetryAction?

    init(simCtl: SimCtlService, defaults: UserDefaults = .standard) {
        self.simCtl = simCtl
        self.defaults = defaults
        reconcileStatus(udid: nil)
    }

    func generateCA() {
        guard begin(.generating) else { return }
        lastFailedAction = .generate
        store.generate { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let metadata):
                self.clearPersistedInstall()
                self.finish(with: .generated(cn: metadata.commonName, expiry: metadata.expiry, sha256: metadata.sha256))
            case .failure(let error):
                self.fail(error)
            }
        }
    }

    func install(udid: String, deviceName: String) {
        guard !udid.isEmpty, udid != "booted" else { fail(.noUDIDSelected); return }
        guard let metadata = store.storedMetadata() else { fail(.noCertificateOnDisk); return }
        guard begin(.installing) else { return }
        lastFailedAction = .install
        runSimCtl(["keychain", udid, "add-root-cert", store.certURL.path], retryAction: .install) { [weak self] in
            self?.defaults.set(metadata.sha256, forKey: StorageKey.installedFingerprint)
            self?.defaults.set(udid, forKey: StorageKey.installedUDID)
            self?.defaults.set(deviceName, forKey: StorageKey.installedDeviceName)
            self?.finish(with: .installed(cn: metadata.commonName, expiry: metadata.expiry, sha256: metadata.sha256, deviceName: deviceName, udid: udid))
        }
    }

    func rotate(udid: String, deviceName: String) {
        guard !udid.isEmpty, udid != "booted" else { fail(.noUDIDSelected); return }
        guard store.storedMetadata() != nil else { fail(.noCertificateOnDisk); return }
        guard begin(.rotating) else { return }
        lastFailedAction = .rotate
        runSimCtl(["keychain", udid, "reset"], retryAction: .rotate) { [weak self] in
            guard let self else { return }
            self.clearPersistedInstall()
            self.store.deleteStoredFiles()
            self.store.generate { [weak self] result in
                guard let self else { return }
                switch result {
                case .success(let metadata):
                    self.runSimCtl(["keychain", udid, "add-root-cert", self.store.certURL.path], retryAction: .rotate) { [weak self] in
                        self?.defaults.set(metadata.sha256, forKey: StorageKey.installedFingerprint)
                        self?.defaults.set(udid, forKey: StorageKey.installedUDID)
                        self?.defaults.set(deviceName, forKey: StorageKey.installedDeviceName)
                        self?.finish(with: .installed(cn: metadata.commonName, expiry: metadata.expiry, sha256: metadata.sha256, deviceName: deviceName, udid: udid))
                    }
                case .failure(let error):
                    self.fail(error)
                }
            }
        }
    }

    func resetKeychain(udid: String) {
        guard !udid.isEmpty, udid != "booted" else { fail(.noUDIDSelected); return }
        guard begin(.resetting) else { return }
        lastFailedAction = .reset
        runSimCtl(["keychain", udid, "reset"], retryAction: .reset) { [weak self] in
            guard let self else { return }
            self.clearPersistedInstall()
            if let metadata = self.store.storedMetadata() {
                self.finish(with: .generated(cn: metadata.commonName, expiry: metadata.expiry, sha256: metadata.sha256))
            } else {
                self.finish(with: .notGenerated)
            }
        }
    }

    func retry(udid: String, deviceName: String) {
        let action = lastFailedAction
        transition(to: .idle)
        switch action {
        case .generate:
            generateCA()
        case .install:
            install(udid: udid, deviceName: deviceName)
        case .rotate:
            rotate(udid: udid, deviceName: deviceName)
        case .reset:
            resetKeychain(udid: udid)
        case nil:
            reconcileStatus(udid: udid.isEmpty ? nil : udid)
        }
    }

    func reconcileStatus(udid: String?) {
        guard !operation.isWorking else { return }
        guard let metadata = store.storedMetadata() else {
            clearPersistedInstall()
            status = .notGenerated
            return
        }
        let persistedFP = defaults.string(forKey: StorageKey.installedFingerprint)
        if persistedFP == metadata.sha256 {
            // Previously installed — check if UDID still matches
            let persistedUDID = defaults.string(forKey: StorageKey.installedUDID)
            if let udid, persistedUDID == udid {
                // Fingerprint + UDID match — high confidence still installed
                let name = defaults.string(forKey: StorageKey.installedDeviceName) ?? "Simulator"
                status = .installed(cn: metadata.commonName, expiry: metadata.expiry, sha256: metadata.sha256, deviceName: name, udid: udid)
            } else {
                // Installed to a different Simulator — uncertain state
                status = .unknown(cn: metadata.commonName, expiry: metadata.expiry, sha256: metadata.sha256, reason: "Installed to a different Simulator. Reinstall to verify.")
            }
        } else {
            // No matching install record — just generated
            status = .generated(cn: metadata.commonName, expiry: metadata.expiry, sha256: metadata.sha256)
        }
    }

    private func begin(_ next: CertificateOperation) -> Bool {
        guard !operation.isWorking else { return false }
        transition(to: next)
        return true
    }

    private func finish(with newStatus: CertificateStatus) {
        status = newStatus
        lastFailedAction = nil
        transition(to: .idle)
    }

    private func fail(_ error: CertificateError) {
        let message = store.redactPaths(in: error.errorDescription ?? "Unknown certificate error.")
        AppLogger.certificates.error("\(message, privacy: .public)")
        transition(to: .error(message))
    }

    private func transition(to next: CertificateOperation) {
        if operation != next, !operation.canTransition(to: next) {
            assertionFailure("Illegal certificate transition: \(operation) -> \(next)")
        }
        operation = next
    }

    private func runSimCtl(_ args: [String], retryAction: RetryAction, onSuccess: @escaping () -> Void) {
        simCtl.run(args)
            .timeout(.seconds(30), scheduler: DispatchQueue.main, customError: { .timeout })
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    guard let self else { return }
                    if case .failure(let error) = completion {
                        self.lastFailedAction = retryAction
                        self.fail(.simctlFailed(self.store.redactPaths(in: error.localizedDescription)))
                    }
                },
                receiveValue: { _ in onSuccess() }
            )
            .store(in: &cancellables)
    }

    private func clearPersistedInstall() {
        defaults.removeObject(forKey: StorageKey.installedFingerprint)
        defaults.removeObject(forKey: StorageKey.installedUDID)
        defaults.removeObject(forKey: StorageKey.installedDeviceName)
    }
}
