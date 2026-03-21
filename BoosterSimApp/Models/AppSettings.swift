// AppSettings.swift — Persisted user settings via @AppStorage
import SwiftUI
import Combine
import ServiceManagement

// MARK: - Side Window Position

enum SideWindowPosition: String, CaseIterable {
    case left, right, bottom, dynamic

    var label: String {
        switch self {
        case .left: return "Left"
        case .right: return "Right"
        case .bottom: return "Bottom"
        case .dynamic: return "Dynamic"
        }
    }

    var icon: String {
        switch self {
        case .left: return "sidebar.left"
        case .right: return "sidebar.right"
        case .bottom: return "dock.rectangle"
        case .dynamic: return "arrow.left.arrow.right"
        }
    }
}

// MARK: - App Settings

final class AppSettings: ObservableObject {
    @AppStorage("sideWindowPosition") var position: SideWindowPosition = .dynamic
    @AppStorage("showSideWindow") var showSideWindow: Bool = true
    @AppStorage("launchAtLogin") var launchAtLogin: Bool = false
    @AppStorage("xcodePath") var xcodePath: String = ""

    // Sync launch-at-login toggle with SMAppService
    func setLaunchAtLogin(_ enabled: Bool) {
        launchAtLogin = enabled
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            // SMAppService may fail in unsigned dev builds
            print("[AppSettings] Launch at login error: \(error)")
        }
    }
}
