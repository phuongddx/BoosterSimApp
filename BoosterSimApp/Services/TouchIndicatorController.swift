// TouchIndicatorController.swift — Simulator ShowSingleTouches snapshot/set/restore via in-process CFPreferences
import Foundation
import Combine

// MARK: - State Machine

enum TouchIndicatorState: Equatable {
    case idle
    case applying
    case active
    case restoring
    case error(String)

    /// True while a session is open or moving — `active` holds a pref override.
    var isWorking: Bool {
        switch self {
        case .applying, .active, .restoring: true
        case .idle, .error: false
        }
    }

    func canTransition(to next: TouchIndicatorState) -> Bool {
        switch self {
        case .idle:
            switch next {
            case .applying: return true
            case .idle, .active, .restoring, .error: return false
            }
        case .applying:
            switch next {
            case .active, .error: return true
            case .applying, .idle, .restoring: return false
            }
        case .active:
            switch next {
            case .restoring: return true
            case .idle, .applying, .active, .error: return false
            }
        case .restoring:
            switch next {
            case .idle, .error: return true
            case .applying, .active, .restoring: return false
            }
        case .error:
            switch next {
            case .applying, .idle: return true
            case .active, .restoring, .error: return false
            }
        }
    }
}

// MARK: - Preferences Store

/// In-process read/write access to one foreign preference domain
/// (never a `defaults` subprocess — repo rule).
protocol TouchPreferencesStore: AnyObject {
    func copyValue(forKey key: String, domain: String) -> Any?
    func setValue(_ value: Any?, forKey key: String, domain: String)
    func synchronize(domain: String) -> Bool
}

/// Production store over CFPreferences (RESEARCH Pattern 6 verbatim).
final class CFPreferencesTouchStore: TouchPreferencesStore {
    func copyValue(forKey key: String, domain: String) -> Any? {
        CFPreferencesCopyAppValue(key as CFString, domain as CFString)
    }

    func setValue(_ value: Any?, forKey key: String, domain: String) {
        CFPreferencesSetAppValue(key as CFString, value as? CFPropertyList, domain as CFString)
    }

    func synchronize(domain: String) -> Bool {
        CFPreferencesAppSynchronize(domain as CFString)
    }
}

// MARK: - Controller

@MainActor
final class TouchIndicatorController: ObservableObject {

    // MARK: - Properties

    /// Simulator's preference domain — the only domain this controller touches (T-02-02).
    static let preferenceDomain = "com.apple.iphonesimulator"
    /// Single scoped key (T-02-02): Simulator renders the touch dots inside its
    /// own window, so captured frames contain them for free.
    static let preferenceKey = "ShowSingleTouches"

    @Published private(set) var state: TouchIndicatorState = .idle

    private let store: any TouchPreferencesStore

    /// Prior value snapshotted before the write; `.unset` restores by clearing.
    private enum Snapshot {
        case unset
        case bool(Bool)
    }
    private var snapshot: Snapshot = .unset

    // MARK: - Lifecycle

    init(store: any TouchPreferencesStore = CFPreferencesTouchStore()) {
        self.store = store
    }

    // MARK: - Session

    /// Snapshots the prior value, writes `true`, synchronizes. Double-enable
    /// while a session is open is refused by the state machine.
    func enable() {
        guard state.canTransition(to: .applying) else { return }
        transition(to: .applying)
        snapshot = Self.snapshotCurrentValue(in: store)
        store.setValue(NSNumber(value: true), forKey: Self.preferenceKey, domain: Self.preferenceDomain)
        guard store.synchronize(domain: Self.preferenceDomain) else {
            restoreSnapshotValue() // errored sessions still restore (T-02-02)
            transition(to: .error("Failed to update Simulator preferences"))
            return
        }
        transition(to: .active)
    }

    /// Puts the snapshotted value back (kCFNull when it was previously unset).
    /// No-op unless a session is open.
    func restore() {
        guard state.canTransition(to: .restoring) else { return }
        transition(to: .restoring)
        restoreSnapshotValue()
        guard store.synchronize(domain: Self.preferenceDomain) else {
            transition(to: .error("Failed to restore Simulator preferences"))
            return
        }
        transition(to: .idle)
    }

    // MARK: - Private

    private func restoreSnapshotValue() {
        switch snapshot {
        case .unset:
            store.setValue(kCFNull, forKey: Self.preferenceKey, domain: Self.preferenceDomain)
        case .bool(let value):
            store.setValue(NSNumber(value: value), forKey: Self.preferenceKey, domain: Self.preferenceDomain)
        }
        _ = store.synchronize(domain: Self.preferenceDomain)
        snapshot = .unset
    }

    private static func snapshotCurrentValue(in store: any TouchPreferencesStore) -> Snapshot {
        guard let number = store.copyValue(forKey: preferenceKey, domain: preferenceDomain) as? NSNumber else {
            return .unset
        }
        return .bool(number.boolValue)
    }

    private func transition(to next: TouchIndicatorState) {
        if state != next, !state.canTransition(to: next) {
            assertionFailure("Illegal touch-indicator transition: \(state) -> \(next)")
        }
        state = next
    }
}
