// PrivacyPermissionTests.swift — Verbatim simctl privacy service-string contract (D-01 lock)
import Foundation
import Testing
@testable import BoosterSimApp

/// Locks the exec-argv contract: raw values are the EXACT service strings from
/// `simctl privacy` help (03-RESEARCH Verified Surface, Xcode 26.3) — and there is
/// deliberately NO case for the unsupported notification service (D-01).
struct PrivacyPermissionTests {

    // MARK: - Verbatim Service Set

    @Test func allCasesMatchVerbatimSimctlServiceStrings() {
        #expect(PrivacyPermission.allCases.map(\.rawValue) == [
            "calendar",
            "contacts-limited",
            "contacts",
            "location",
            "location-always",
            "photos-add",
            "photos",
            "media-library",
            "microphone",
            "motion",
            "reminders",
            "siri"
        ])
    }

    @Test func enumIsNotConstructibleForUnsupportedNotificationService() {
        // simctl privacy has no notifications service (research-proven 2026-08-30;
        // `grant notifications` exits 1 "Operation not permitted"). The enum must not
        // be constructible for it so a fake notification toggle can never appear.
        #expect(PrivacyPermission(rawValue: "notifications") == nil)
    }

    @Test func resetAllTokenIsNotAPerAppCase() {
        // The help text's reset-everything shortcut lives only in resetAllArgs.
        #expect(PrivacyPermission(rawValue: "all") == nil)
        #expect(!PrivacyPermission.allCases.map(\.rawValue).contains("all"))
    }

    // MARK: - Argv Composition

    @Test func simctlArgsComposeGrantExactly() {
        #expect(PrivacyPermission.calendar.simctlArgs(udid: "UDID", action: .grant)
                == ["privacy", "UDID", "grant", "calendar"])
        #expect(PrivacyPermission.siri.simctlArgs(udid: "UDID", action: .grant)
                == ["privacy", "UDID", "grant", "siri"])
    }

    @Test func simctlArgsComposeRevokeExactly() {
        #expect(PrivacyPermission.contactsLimited.simctlArgs(udid: "UDID", action: .revoke)
                == ["privacy", "UDID", "revoke", "contacts-limited"])
        #expect(PrivacyPermission.locationAlways.simctlArgs(udid: "UDID", action: .revoke)
                == ["privacy", "UDID", "revoke", "location-always"])
    }

    @Test func resetAllArgsComposeResetAllExactly() {
        #expect(PrivacyPermission.resetAllArgs(udid: "UDID")
                == ["privacy", "UDID", "reset", "all"])
    }

    // MARK: - Presentation

    @Test func everyCaseHasAHumanReadableLabel() {
        for permission in PrivacyPermission.allCases {
            #expect(!permission.label.isEmpty)
        }
    }
}
