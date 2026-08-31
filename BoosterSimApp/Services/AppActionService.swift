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
    @Published private(set) var pushResult: PushActionResult?
    @Published private(set) var isSendingPush = false
    @Published private(set) var localeCaption: String?
    @Published private(set) var currentLanguages: [String] = []
    @Published private(set) var currentLocaleID: String?
    @Published private(set) var currentTimezone: String?
    @Published private(set) var locationCaption: String?
    @Published private(set) var hasSimulatedLocation = false
    @Published private(set) var clipboardCaption: String?

    // MARK: - Private

    private let simCtl: any SimCtlRunning
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

    init(simCtl: any SimCtlRunning,
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
            // A not-running app fails terminate (exit 3) — emit a dummy value so the chain
            // CONTINUES to the listapps presence check, which owns the absent/apparent
            // decision. `Empty` here aborted the whole reset and faked a 30s timeout (CR-01).
            .catch { _ in Just("").setFailureType(to: SimCtlError.self).eraseToAnyPublisher() }
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
        // Both waits are bounded (03-REVIEW WR-06): a CertificateService run that never
        // transitions would otherwise pin this machine in .clearingKeychain forever — the
        // fallback caption lands via finish() and reentrancy recovers. Logging reflects the
        // ACTUAL outcome of each branch, never an unconditional success line.
        keychainEvents
            .dropFirst()                             // skip the current idle value
            .first { !$0.isWorking }                 // terminal state of this reset run
            .setFailureType(to: SimCtlError.self)
            .timeout(.seconds(30), scheduler: DispatchQueue.main, customError: { .timeout })
            .flatMap { [weak self] terminal -> AnyPublisher<String, Never> in
                guard let self else { return Empty().eraseToAnyPublisher() }
                self.certificateService.reconcileStatus(udid: udid)
                if case .error(let message) = terminal {
                    AppLogger.actions.error("keychain clear failed — wipe errored")
                    return Just("Keychain wipe failed: \(message)").eraseToAnyPublisher()
                }
                guard self.certificateService.status.certificateMetadata != nil else {
                    AppLogger.actions.info("keychain clear completed — no CA to reconcile")
                    return Just("Keychain cleared — no local CA on disk to reconcile.").eraseToAnyPublisher()
                }
                self.certificateService.install(udid: udid, deviceName: deviceName)
                return self.keychainEvents.dropFirst().first { !$0.isWorking }
                    .setFailureType(to: SimCtlError.self)
                    .timeout(.seconds(30), scheduler: DispatchQueue.main, customError: { .timeout })
                    .map { installTerminal -> String in
                        if case .error(let message) = installTerminal {
                            AppLogger.actions.error("keychain clear failed — CA install errored")
                            return "Keychain cleared, but re-installing the local CA failed: \(message)"
                        }
                        AppLogger.actions.info("keychain clear finished — CA reconcile completed")
                        return "Keychain cleared — local CA re-installed automatically."
                    }
                    .catch { error in
                        AppLogger.actions.error("keychain clear failed — CA install wait timed out")
                        return Just("Keychain clear did not finish: \(error.localizedDescription).")
                    }
                    .eraseToAnyPublisher()
            }
            .catch { error in
                AppLogger.actions.error("keychain clear failed — wipe wait timed out")
                return Just("Keychain clear did not finish: \(error.localizedDescription).")
            }
            .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] caption in
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

    // MARK: - Push (stdin seam, SC2)

    /// Parses, validates, and sends a push payload to the selected app via the stdin seam.
    /// The gate runs BEFORE any subprocess (T-03-12): empty text, malformed JSON, non-object
    /// roots, missing aps, and over-cap sizes all fail with typed captions. Logging carries
    /// verb + encoded byte size + outcome only — payload bodies never reach AppLogger (T-03-05).
    func sendPush(udid: String, bundleID: String?, payloadText: String) {
        guard !udid.isEmpty else {
            pushResult = .failed("No active Simulator — push needs a running device.")
            return
        }
        let payload: PushPayload
        switch PushPayload.parse(payloadText) {
        case .failure(let error):
            pushResult = .failed(error.message)
            return
        case .success(let parsed):
            payload = parsed
        }
        guard let encoded = try? JSONEncoder().encode(payload) else {
            pushResult = .failed("The payload could not be encoded.")
            return
        }
        if let error = payload.validate(encodedByteCount: encoded.count) {
            pushResult = .failed(error.message)
            return
        }

        let size = encoded.count
        isSendingPush = true
        // Explicit bundle arg overrides the payload's embedded target (research: arg beats key).
        runVerb(["push", udid, bundleID ?? "-", "-"], stdin: encoded) { [weak self] result in
            guard let self else { return }
            self.isSendingPush = false
            switch result {
            case .success(let output):
                AppLogger.actions.info("push sent (\(size) bytes)")
                self.pushResult = .sent(Self.pushCaption(from: output))
            case .failure(let error):
                AppLogger.actions.error("push failed (\(size) bytes)")
                self.pushResult = .failed(error.localizedDescription)
            }
        }
    }

    /// Maps simctl's confirmation line ("Notification sent to '<bundle>'") to the success caption.
    private nonisolated static func pushCaption(from output: String) -> String {
        let line = output.trimmingCharacters(in: .whitespacesAndNewlines)
        return line.isEmpty ? "Notification sent." : line
    }

    // MARK: - Locale & Region (SC3 — relaunch domain, device-wide global writes)

    /// Reads the device's current global locale state (three typed spawn-defaults reads,
    /// EnvironmentOverrideService pattern). Fields update as each read lands; a key that is
    /// unset on the device stays nil. Every read carries the house 30s timeout + failure
    /// caption (03-REVIEW WR-05) — a hung read on the serialized seam must never starve silently.
    func readLocaleState(udid: String) {
        guard !udid.isEmpty else { return }
        currentLanguages = []
        currentLocaleID = nil
        currentTimezone = nil
        readLocaleKey(Self.languagesKey, udid: udid) { [weak self] output in
            self?.currentLanguages = Self.parseLanguagesArray(from: output)
        }
        readLocaleKey(Self.localeKey, udid: udid) { [weak self] output in
            self?.currentLocaleID = Self.parseScalarValue(from: output)
        }
        readLocaleKey(Self.timezoneKey, udid: udid) { [weak self] output in
            self?.currentTimezone = Self.parseScalarValue(from: output)
        }
    }

    /// One global-domain read with the same timeout + failure-caption discipline as runVerb.
    private func readLocaleKey(
        _ key: String, udid: String,
        apply: @escaping (String) -> Void
    ) {
        simCtl.run(Self.readKeyArgs(udid: udid, key: key))
            .timeout(.seconds(30), scheduler: DispatchQueue.main, customError: { .timeout })
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    guard let self, case .failure(let error) = completion else { return }
                    self.localeCaption = "Could not read the current locale state: \(error.localizedDescription)"
                },
                receiveValue: { output in apply(output) }
            )
            .store(in: &cancellables)
    }

    /// Writes AppleLanguages + AppleLocale (+ AppleTimeZone when given) on the global domain,
    /// then relaunches the selected app in the SAME chain (EnvironmentOverrideService chain
    /// shape). Pitfall 6: a bare write looks like a no-op — the relaunch hop makes the effect
    /// deterministic for the selected app. Re-apply is idempotent (identical device state).
    func applyLocale(languages: [String], locale: String, timezone: String? = nil,
                     udid: String, bundleID: String?) {
        guard !udid.isEmpty else {
            localeCaption = "No active Simulator — locale changes need a running device."
            return
        }
        let trimmedLanguages = languages
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let trimmedLocale = locale.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedLanguages.isEmpty, !trimmedLocale.isEmpty else {
            localeCaption = "Enter both a language code and a locale identifier."
            return
        }
        let trimmedTimezone = timezone?.trimmingCharacters(in: .whitespacesAndNewlines)
        localeCaption = nil
        simCtl.run(Self.languageArgs(languages: trimmedLanguages, udid: udid))
            .flatMap { [weak self] _ -> AnyPublisher<String, SimCtlError> in
                guard let self else { return Empty().eraseToAnyPublisher() }
                return self.simCtl.run(Self.localeArgs(locale: trimmedLocale, udid: udid))
            }
            .flatMap { [weak self] _ -> AnyPublisher<String, SimCtlError> in
                guard let self, let trimmedTimezone else {
                    return Just("").setFailureType(to: SimCtlError.self).eraseToAnyPublisher()
                }
                return self.simCtl.run(Self.timezoneArgs(timezone: trimmedTimezone, udid: udid))
            }
            .flatMap { [weak self] _ -> AnyPublisher<String, SimCtlError> in
                guard let self, let bundleID else {
                    return Just("").setFailureType(to: SimCtlError.self).eraseToAnyPublisher()
                }
                return self.simCtl.run(Self.relaunchArgs(udid: udid, bundleID: bundleID))
            }
            .timeout(.seconds(30), scheduler: DispatchQueue.main, customError: { .timeout })
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    guard let self, case .failure(let error) = completion else { return }
                    AppLogger.actions.error("locale apply failed")   // verb + outcome only
                    self.localeCaption = "Locale change failed: \(error.localizedDescription)"
                },
                receiveValue: { [weak self] _ in
                    guard let self else { return }
                    AppLogger.actions.info("locale apply completed — app relaunched")
                    self.localeCaption = bundleID == nil
                        ? "Locale written — takes effect on the next app launch."
                        : "Locale applied and the app relaunched — effective on this launch."
                    self.readLocaleState(udid: udid)
                }
            )
            .store(in: &cancellables)
    }

    /// Writes AppleTimeZone on the global domain, then relaunches — same relaunch-required
    /// semantics as the locale chain (Pitfall 6).
    func setTimezone(tz: String, udid: String, bundleID: String?) {
        guard !udid.isEmpty else {
            localeCaption = "No active Simulator — timezone changes need a running device."
            return
        }
        let trimmed = tz.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            localeCaption = "Enter a timezone identifier (e.g. Asia/Tokyo)."
            return
        }
        localeCaption = nil
        simCtl.run(Self.timezoneArgs(timezone: trimmed, udid: udid))
            .flatMap { [weak self] _ -> AnyPublisher<String, SimCtlError> in
                guard let self, let bundleID else {
                    return Just("").setFailureType(to: SimCtlError.self).eraseToAnyPublisher()
                }
                return self.simCtl.run(Self.relaunchArgs(udid: udid, bundleID: bundleID))
            }
            .timeout(.seconds(30), scheduler: DispatchQueue.main, customError: { .timeout })
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    guard let self, case .failure(let error) = completion else { return }
                    AppLogger.actions.error("timezone apply failed")
                    self.localeCaption = "Timezone change failed: \(error.localizedDescription)"
                },
                receiveValue: { [weak self] _ in
                    guard let self else { return }
                    AppLogger.actions.info("timezone apply completed — app relaunched")
                    self.localeCaption = "Timezone applied and the app relaunched — effective on this launch."
                    self.readLocaleState(udid: udid)
                }
            )
            .store(in: &cancellables)
    }

    // MARK: - Location Simulation (SC3 — immediate, with a paired visible Stop)

    /// Sets the simulated location after pure validation — invalid coordinates surface a
    /// typed caption and never spawn a verb (T-03-13). On success the active-simulation
    /// flag publishes so the section's Stop/Clear stays visible (Pitfall 10 pairing).
    func setLocation(lat: String, lon: String, udid: String) {
        guard !udid.isEmpty else {
            locationCaption = "No active Simulator — location simulation needs a running device."
            return
        }
        switch Self.locationSetCommand(udid: udid, lat: lat, lon: lon) {
        case .failure(let error):
            locationCaption = error.message
        case .success(let args):
            locationCaption = nil
            runVerb(args) { [weak self] result in
                guard let self else { return }
                switch result {
                case .success:
                    AppLogger.actions.info("location set completed")
                    self.hasSimulatedLocation = true
                    self.locationCaption = "Location set — applies immediately to CoreLocation consumers."
                case .failure(let error):
                    AppLogger.actions.error("location set failed")
                    self.locationCaption = "Setting location failed: \(error.localizedDescription)"
                }
            }
        }
    }

    /// Stops the simulation — the visible Stop's action; clears the flag on success.
    func clearLocation(udid: String) {
        guard !udid.isEmpty else {
            locationCaption = "No active Simulator — clearing needs a running device."
            return
        }
        runVerb(Self.locationClearCommand(udid: udid)) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success:
                AppLogger.actions.info("location clear completed")
                self.hasSimulatedLocation = false
                self.locationCaption = "Location simulation cleared — real/none location restored."
            case .failure(let error):
                AppLogger.actions.error("location clear failed")
                self.locationCaption = "Clearing location failed: \(error.localizedDescription)"
            }
        }
    }

    /// City preset: sets coordinates (immediate) AND writes the matching AppleTimeZone, then
    /// relaunches for the timezone half — GPS + timezone sync in one action (research OQ4).
    /// The same Pitfall-10 pairing as setLocation: the flag publishes on success.
    func applyLocationPreset(preset: CityPreset, udid: String, bundleID: String?) {
        guard !udid.isEmpty else {
            locationCaption = "No active Simulator — location presets need a running device."
            return
        }
        let setArgs: [String]
        switch Self.locationSetCommand(udid: udid, lat: preset.lat, lon: preset.lon) {
        case .success(let args):
            setArgs = args                       // preset coordinates are test-pinned valid
        case .failure(let error):
            locationCaption = error.message      // defensive: typed refusal, never bad argv
            return
        }
        locationCaption = nil
        simCtl.run(setArgs)
            .flatMap { [weak self] _ -> AnyPublisher<String, SimCtlError> in
                guard let self else { return Empty().eraseToAnyPublisher() }
                return self.simCtl.run(Self.timezoneArgs(timezone: preset.timezone, udid: udid))
            }
            .flatMap { [weak self] _ -> AnyPublisher<String, SimCtlError> in
                guard let self, let bundleID else {
                    return Just("").setFailureType(to: SimCtlError.self).eraseToAnyPublisher()
                }
                return self.simCtl.run(Self.relaunchArgs(udid: udid, bundleID: bundleID))
            }
            .timeout(.seconds(30), scheduler: DispatchQueue.main, customError: { .timeout })
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    guard let self, case .failure(let error) = completion else { return }
                    AppLogger.actions.error("location preset failed")
                    self.locationCaption = "Location preset failed: \(error.localizedDescription)"
                },
                receiveValue: { [weak self] _ in
                    guard let self else { return }
                    self.hasSimulatedLocation = true
                    // Caption honesty (03-REVIEW WR-01): the relaunch hop runs only when an
                    // app is active — with none selected nothing relaunches, so neither the
                    // log nor the caption may claim it (mirrors applyLocale's branch).
                    if bundleID != nil {
                        AppLogger.actions.info("location preset completed — app relaunched")
                        self.locationCaption = "\(preset.name) set — location applies immediately; "
                            + "timezone takes effect on the next app launch (app relaunched automatically)."
                    } else {
                        AppLogger.actions.info("location preset completed")
                        self.locationCaption = "\(preset.name) set — location applies immediately; "
                            + "timezone takes effect on every app's next launch."
                    }
                }
            )
            .store(in: &cancellables)
    }

    // MARK: - Clipboard Sync (SC3 — manual pbsync, both directions)

    /// Syncs the pasteboard in one direction via pbsync. Manual-trigger only by design:
    /// no timer, no polling, and clipboard CONTENT is never read, stored, or logged (T-03-08) —
    /// logging carries the direction and outcome only.
    func syncClipboard(direction: ClipboardDirection, udid: String) {
        guard !udid.isEmpty else {
            clipboardCaption = "No active Simulator — clipboard sync needs a running device."
            return
        }
        runVerb(Self.pbsyncCommand(direction: direction, udid: udid)) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success:
                AppLogger.actions.info("pbsync \(direction.logLabel) completed")
                self.clipboardCaption = direction == .macToDevice
                    ? "Mac clipboard copied to the Simulator."
                    : "Simulator clipboard copied to the Mac."
            case .failure(let error):
                AppLogger.actions.error("pbsync \(direction.logLabel) failed")
                self.clipboardCaption = "Clipboard sync failed: \(error.localizedDescription)"
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

// MARK: - Locale Preset Model (SC3)

/// One-tap locale triple — the global-domain values a preset writes together.
/// Raw values are the AppleLanguages codes; `locale` uses the underscore form Apple expects.
enum LocalePreset: String, CaseIterable, Identifiable, Sendable {
    case englishUS = "en-US"
    case englishUK = "en-GB"
    case vietnameseVN = "vi-VN"
    case japaneseJP = "ja-JP"

    var id: String { rawValue }

    var name: String {
        switch self {
        case .englishUS: return "English (US)"
        case .englishUK: return "English (UK)"
        case .vietnameseVN: return "Vietnamese (VN)"
        case .japaneseJP: return "Japanese (JP)"
        }
    }

    var languages: [String] { [rawValue] }

    var locale: String {
        switch self {
        case .englishUS: return "en_US"
        case .englishUK: return "en_GB"
        case .vietnameseVN: return "vi_VN"
        case .japaneseJP: return "ja_JP"
        }
    }

    /// Optional third member of the triple — a preset may leave the timezone untouched.
    var timezone: String? {
        switch self {
        case .englishUS: return "America/New_York"
        case .englishUK: return "Europe/London"
        case .vietnameseVN: return "Asia/Ho_Chi_Minh"
        case .japaneseJP: return "Asia/Tokyo"
        }
    }
}

// MARK: - Pure Locale Command Builders (global domain — 03-RESEARCH Verified Surface)

extension AppActionService {

    /// The single global-domain token every locale/timezone verb targets (live-verified
    /// read round-trip on iOS 26.3; the EnvironmentOverrideService `.GlobalPreferences`
    /// precedent). One constant — never forked per call site.
    static let globalDefaultsDomain = ".GlobalPreferences"

    static let languagesKey = "AppleLanguages"
    static let localeKey = "AppleLocale"
    static let timezoneKey = "AppleTimeZone"

    /// `spawn defaults write <global domain> AppleLanguages -array <codes…>`
    nonisolated static func languageArgs(languages: [String], udid: String) -> [String] {
        ["spawn", udid, "defaults", "write", globalDefaultsDomain,
         languagesKey, "-array"] + languages
    }

    /// `spawn defaults write <global domain> AppleLocale -string <id>`
    nonisolated static func localeArgs(locale: String, udid: String) -> [String] {
        ["spawn", udid, "defaults", "write", globalDefaultsDomain,
         localeKey, "-string", locale]
    }

    /// `spawn defaults write <global domain> AppleTimeZone -string <id>`
    nonisolated static func timezoneArgs(timezone: String, udid: String) -> [String] {
        ["spawn", udid, "defaults", "write", globalDefaultsDomain,
         timezoneKey, "-string", timezone]
    }

    /// Restore-to-unset: deletes the key from the global domain (reversibility path, T-03-09).
    nonisolated static func deleteKeyArgs(udid: String, key: String) -> [String] {
        ["spawn", udid, "defaults", "delete", globalDefaultsDomain, key]
    }

    /// Current-state read for one of the three keys.
    nonisolated static func readKeyArgs(udid: String, key: String) -> [String] {
        ["spawn", udid, "defaults", "read", globalDefaultsDomain, key]
    }

    /// One-call relaunch (flagged assumption A1): `launch --terminate-running-process`.
    nonisolated static func relaunchArgs(udid: String, bundleID: String) -> [String] {
        ["launch", udid, bundleID, "--terminate-running-process"]
    }

    /// Two-step fallback if the one-call form misbehaves at the smoke: terminate, then launch.
    nonisolated static func fallbackRelaunchArgs(udid: String, bundleID: String) -> [[String]] {
        [["terminate", udid, bundleID], ["launch", udid, bundleID]]
    }

    /// The exact verb sequence a preset application runs — writes first, relaunch hop LAST
    /// (the chain invariant applyLocale executes; idempotent on re-apply by construction).
    nonisolated static func localePresetChain(preset: LocalePreset, udid: String, bundleID: String) -> [[String]] {
        var chain = [languageArgs(languages: preset.languages, udid: udid),
                     localeArgs(locale: preset.locale, udid: udid)]
        if let timezone = preset.timezone {
            chain.append(timezoneArgs(timezone: timezone, udid: udid))
        }
        chain.append(relaunchArgs(udid: udid, bundleID: bundleID))
        return chain
    }

    /// Parses `defaults read` array output (old-style `("en-US", "vi-VN")`) into elements.
    nonisolated static func parseLanguagesArray(from output: String) -> [String] {
        output.split(separator: "\"", omittingEmptySubsequences: false)
            .enumerated()
            .compactMap { index, piece in index % 2 == 1 ? String(piece) : nil }
    }

    /// Parses a scalar `defaults read` value — trimmed; nil when absent or blank.
    nonisolated static func parseScalarValue(from output: String) -> String? {
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

// MARK: - Location & Clipboard Models (SC3)

/// Typed coordinate-validation failures — surfaced inline BEFORE any verb runs (T-03-13).
enum CoordinateError: Error, Equatable, Sendable {
    case latitudeEmpty
    case longitudeEmpty
    case latitudeNotNumeric
    case longitudeNotNumeric
    case latitudeOutOfRange
    case longitudeOutOfRange

    var message: String {
        switch self {
        case .latitudeEmpty: return "Enter a latitude (e.g. 35.6762)."
        case .longitudeEmpty: return "Enter a longitude (e.g. 139.6503)."
        case .latitudeNotNumeric: return "Latitude must be a number (e.g. 35.6762)."
        case .longitudeNotNumeric: return "Longitude must be a number (e.g. 139.6503)."
        case .latitudeOutOfRange: return "Latitude must be between -90 and 90."
        case .longitudeOutOfRange: return "Longitude must be between -180 and 180."
        }
    }
}

/// One-tap city triple: coordinates plus the matching AppleTimeZone, applied together
/// (research Open Question 4 — GPS + timezone sync in one action).
enum CityPreset: String, CaseIterable, Identifiable, Sendable {
    case sanFrancisco = "san-francisco"
    case newYork = "new-york"
    case london = "london"
    case tokyo = "tokyo"
    case singapore = "singapore"
    case sydney = "sydney"

    var id: String { rawValue }

    var name: String {
        switch self {
        case .sanFrancisco: return "San Francisco"
        case .newYork: return "New York"
        case .london: return "London"
        case .tokyo: return "Tokyo"
        case .singapore: return "Singapore"
        case .sydney: return "Sydney"
        }
    }

    var lat: String {
        switch self {
        case .sanFrancisco: return "37.7749"
        case .newYork: return "40.7128"
        case .london: return "51.5074"
        case .tokyo: return "35.6762"
        case .singapore: return "1.3521"
        case .sydney: return "-33.8688"
        }
    }

    var lon: String {
        switch self {
        case .sanFrancisco: return "-122.4194"
        case .newYork: return "-74.0060"
        case .london: return "-0.1278"
        case .tokyo: return "139.6503"
        case .singapore: return "103.8198"
        case .sydney: return "151.2093"
        }
    }

    var timezone: String {
        switch self {
        case .sanFrancisco: return "America/Los_Angeles"
        case .newYork: return "America/New_York"
        case .london: return "Europe/London"
        case .tokyo: return "Asia/Tokyo"
        case .singapore: return "Asia/Singapore"
        case .sydney: return "Australia/Sydney"
        }
    }
}

/// The two research-verified pbsync directions.
enum ClipboardDirection: Sendable {
    case macToDevice      // `pbsync host <udid>`
    case deviceToMac      // `pbsync <udid> host`

    var label: String {
        switch self {
        case .macToDevice: return "Mac → Simulator"
        case .deviceToMac: return "Simulator → Mac"
        }
    }

    /// Log-safe label — the direction only, never any clipboard content (T-03-08).
    var logLabel: String {
        switch self {
        case .macToDevice: return "host-to-device"
        case .deviceToMac: return "device-to-host"
        }
    }
}

// MARK: - Pure Location & Clipboard Command Builders (03-RESEARCH Verified Surface)

extension AppActionService {

    /// Validates free-text coordinates into a "lat,lon" pair — or a typed error.
    /// Input text is used verbatim (trimmed); numeric only, |lat| ≤ 90, |lon| ≤ 180.
    nonisolated static func coordinatePair(lat: String, lon: String) -> Result<String, CoordinateError> {
        let latTrimmed = lat.trimmingCharacters(in: .whitespacesAndNewlines)
        let lonTrimmed = lon.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !latTrimmed.isEmpty else { return .failure(.latitudeEmpty) }
        guard !lonTrimmed.isEmpty else { return .failure(.longitudeEmpty) }
        guard let latValue = Double(latTrimmed) else { return .failure(.latitudeNotNumeric) }
        guard let lonValue = Double(lonTrimmed) else { return .failure(.longitudeNotNumeric) }
        guard abs(latValue) <= 90 else { return .failure(.latitudeOutOfRange) }
        guard abs(lonValue) <= 180 else { return .failure(.longitudeOutOfRange) }
        return .success("\(latTrimmed),\(lonTrimmed)")
    }

    /// `location <udid> set <lat>,<lon>` — only when validation passes (NO args otherwise).
    nonisolated static func locationSetCommand(udid: String, lat: String, lon: String) -> Result<[String], CoordinateError> {
        coordinatePair(lat: lat, lon: lon).map { ["location", udid, "set", $0] }
    }

    /// The visible Stop's argv — stops the simulation, restores real/none location.
    nonisolated static func locationClearCommand(udid: String) -> [String] {
        ["location", udid, "clear"]
    }

    /// City preset sequence: location set (immediate) → AppleTimeZone write (the Task-1
    /// builder) → relaunch hop. Identical output on re-apply by construction (idempotent).
    nonisolated static func cityPresetChain(preset: CityPreset, udid: String, bundleID: String?) -> [[String]] {
        var chain = [["location", udid, "set", "\(preset.lat),\(preset.lon)"],
                     timezoneArgs(timezone: preset.timezone, udid: udid)]
        if let bundleID {
            chain.append(relaunchArgs(udid: udid, bundleID: bundleID))
        }
        return chain
    }

    /// The two pbsync forms — the direction enum maps to exactly these argv.
    nonisolated static func pbsyncCommand(direction: ClipboardDirection, udid: String) -> [String] {
        switch direction {
        case .macToDevice: return ["pbsync", "host", udid]
        case .deviceToMac: return ["pbsync", udid, "host"]
        }
    }
}
