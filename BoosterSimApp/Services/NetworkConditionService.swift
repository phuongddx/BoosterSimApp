// NetworkConditionService.swift — @MainActor hub for network condition state; pushes snapshots via CommandServer
import Foundation
import Combine

// MARK: - State Machine

enum NetworkConditionState: Equatable {
    case idle
    case applying
    case applied
    case error(String)

    var isWorking: Bool {
        switch self {
        case .idle, .applied, .error:
            false
        case .applying:
            true
        }
    }

    func canTransition(to next: NetworkConditionState) -> Bool {
        switch self {
        case .idle:
            switch next {
            case .idle, .applying: return true
            case .applied, .error: return false
            }
        case .applying:
            switch next {
            case .applied, .error: return true
            case .idle, .applying: return false
            }
        case .applied:
            switch next {
            case .applying, .idle: return true
            case .applied, .error: return false
            }
        case .error:
            switch next {
            case .applying, .idle: return true
            case .applied, .error: return false
            }
        }
    }
}

// MARK: - Service

@MainActor
final class NetworkConditionService: ObservableObject {

    // MARK: - Properties

    @Published private(set) var state: NetworkConditionState = .idle
    @Published private(set) var airplane: Bool
    @Published private(set) var rules: [BlockRule]
    @Published private(set) var selectedProfile: NetworkConditionProfile

    private let commandServer = CommandServer()
    private let defaults: UserDefaults

    private enum StorageKey {
        static let airplane = "networkConditionAirplane"
        static let rules = "networkBlockRules"
        static let profile = "networkConditionProfile"
    }

    // MARK: - Lifecycle

    /// Reads persisted condition state (persist + re-apply, Open Question 2)
    /// Reads persisted condition state (persist + re-apply, Open Question 2)
    /// and starts the command channel. The first client connect triggers the
    /// reconcile push of the persisted snapshot.
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.airplane = defaults.bool(forKey: StorageKey.airplane)
        self.rules = Self.decodeRules(from: defaults.data(forKey: StorageKey.rules))
        self.selectedProfile = NetworkConditionProfile(
            rawValue: defaults.string(forKey: StorageKey.profile) ?? ""
        ) ?? .off

        commandServer.onClientConnect = { [weak self] in
            self?.pushSnapshot()
        }
        commandServer.start()
    }

    // MARK: - Airplane

    /// Builds the full-state snapshot (single writer — airplane and rules
    /// travel together, never torn), marks applying → broadcast → applied.
    func setAirplane(_ enabled: Bool) {
        guard begin() else { return }
        airplane = enabled
        defaults.set(enabled, forKey: StorageKey.airplane)
        pushSnapshot()
        finish()
    }

    // MARK: - Throttle Profile

    /// Single-tap selection: persists under the user-facing key
    /// "networkConditionProfile" (renaming strands stored selections) and
    /// broadcasts the full snapshot — `off` maps to a nil throttle. The
    /// switch applies to the NEXT request; in-flight paced responses keep
    /// their original spec (snapshot semantics).
    func selectProfile(_ profile: NetworkConditionProfile) {
        guard begin() else { return }
        selectedProfile = profile
        defaults.set(profile.rawValue, forKey: StorageKey.profile)
        pushSnapshot()
        finish()
    }

    // MARK: - Block Rules

    func addRule(_ rule: BlockRule) {
        guard begin() else { return }
        rules.append(rule)
        persistRules()
        pushSnapshot()
        finish()
    }

    func removeRule(id: UUID) {
        guard begin() else { return }
        rules.removeAll { $0.id == id }
        persistRules()
        pushSnapshot()
        finish()
    }

    func setRuleEnabled(id: UUID, enabled: Bool) {
        guard let index = rules.firstIndex(where: { $0.id == id }) else { return }
        guard begin() else { return }
        rules[index].isEnabled = enabled
        persistRules()
        pushSnapshot()
        finish()
    }

    // MARK: - Snapshot

    /// Total snapshot build: airplane + throttle profile + rules in one
    /// BoosterCommand (single writer — never torn).
    func snapshot() -> BoosterCommand {
        BoosterCommand(airplane: airplane, throttle: selectedProfile.throttleSpec, blockRules: rules)
    }

    // MARK: - State Machine

    private func begin() -> Bool {
        guard !state.isWorking else { return false }
        transition(to: .applying)
        return true
    }

    private func finish() {
        transition(to: .applied)
    }

    private func transition(to next: NetworkConditionState) {
        if state != next, !state.canTransition(to: next) {
            assertionFailure("Illegal network condition transition: \(state) -> \(next)")
        }
        state = next
    }

    // MARK: - Private

    private func pushSnapshot() {
        commandServer.broadcast(snapshot())
    }

    private func persistRules() {
        if let data = try? JSONEncoder().encode(rules) {
            defaults.set(data, forKey: StorageKey.rules)
        }
    }

    private static func decodeRules(from data: Data?) -> [BlockRule] {
        guard let data else { return [] }
        return (try? JSONDecoder().decode([BlockRule].self, from: data)) ?? []
    }
}
