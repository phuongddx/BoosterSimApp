// PrivacyPermission.swift — simctl privacy TCC service contract (verbatim argv strings) + arg builders
import Foundation

// MARK: - Service Enum

/// The TCC services `simctl privacy` supports. Raw values are the EXACT service strings from
/// `simctl privacy` help (03-RESEARCH Verified Surface, Xcode 26.3) — an exec-argv contract,
/// NOT presentation (SideWindowPosition discipline). There is deliberately NO case for
/// notifications: simctl has no such service (D-01) — PrivacyPermissionTests locks this set.
enum PrivacyPermission: String, CaseIterable, Sendable {
    case calendar
    case contactsLimited = "contacts-limited"
    case contacts
    case location
    case locationAlways = "location-always"
    case photosAdd = "photos-add"
    case photos
    case mediaLibrary = "media-library"
    case microphone
    case motion
    case reminders
    case siri

    var label: String {
        switch self {
        case .calendar:         return "Calendar"
        case .contactsLimited:  return "Contacts (Limited)"
        case .contacts:         return "Contacts"
        case .location:         return "Location"
        case .locationAlways:   return "Location (Always)"
        case .photosAdd:        return "Photos (Add)"
        case .photos:           return "Photos"
        case .mediaLibrary:     return "Media Library"
        case .microphone:       return "Microphone"
        case .motion:           return "Motion"
        case .reminders:        return "Reminders"
        case .siri:             return "Siri"
        }
    }
}

// MARK: - Action

enum PrivacyAction: String, Sendable {
    case grant
    case revoke

    var label: String {
        switch self {
        case .grant:  return "Grant"
        case .revoke: return "Revoke"
        }
    }
}

// MARK: - Argv Builders

extension PrivacyPermission {

    /// `privacy <udid> grant|revoke <service>` — exactly; the optional trailing bundle arg is
    /// appended by the facade when the action is scoped to the picker's active app.
    func simctlArgs(udid: String, action: PrivacyAction) -> [String] {
        ["privacy", udid, action.rawValue, rawValue]
    }

    /// `privacy <udid> reset all` — the help text's reset-everything shortcut; NOT a per-app
    /// case (TCC services only — notification permission is unaffected; it is managed by iOS).
    static func resetAllArgs(udid: String) -> [String] {
        ["privacy", udid, "reset", "all"]
    }
}
