// AppSettings.swift — Persisted user settings via @AppStorage
import SwiftUI
import Combine
import OSLog
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

// MARK: - Capture Export Format

/// Export format for recorded captures — plan 03's CaptureExporter consumes it from here.
enum CaptureExportFormat: String, CaseIterable {
    case gif, mp4, mov

    var label: String {
        switch self {
        case .gif: return "GIF"
        case .mp4: return "MP4"
        case .mov: return "MOV"
        }
    }
}

// MARK: - Capture Destination Kind

/// Persistence-friendly destination selection (raw values are defaults keys);
/// the runtime `CaptureDestination` carries the resolved custom URL.
enum CaptureDestinationKind: String, CaseIterable {
    case desktop, clipboard, custom, ask

    var label: String {
        switch self {
        case .desktop: return "Desktop"
        case .clipboard: return "Clipboard"
        case .custom: return "Custom"
        case .ask: return "Ask"
        }
    }
}

// MARK: - App Settings

final class AppSettings: ObservableObject {
    @AppStorage("sideWindowPosition") var position: SideWindowPosition = .dynamic
    @AppStorage("showSideWindow") var showSideWindow: Bool = true
    @AppStorage("launchAtLogin") var launchAtLogin: Bool = false
    @AppStorage("xcodePath") var xcodePath: String = ""

    // Capture settings (key strings are persistence keys — final names, plan 02-01)
    @AppStorage("captureDestination") var captureDestination: CaptureDestinationKind = .desktop
    @AppStorage("captureASCFramePreset") var captureASCFramePreset: ASCFramePreset = .iphone69x1320
    @AppStorage("captureBezelMode") var captureBezelMode: BezelMode = .simulatorNative
    @AppStorage("captureBackground") var captureBackground: CaptureBackground = .solid
    @AppStorage("captureExportFormat") var captureExportFormat: CaptureExportFormat = .mp4
    @AppStorage("captureGIFSize") var captureGIFSize: Int = 480
    @AppStorage("captureGIFFps") var captureGIFFps: Int = 10
    @AppStorage("captureShowTouchIndicators") var captureShowTouchIndicators: Bool = false

    private enum CaptureStorageKey {
        static let customFolderPath = "captureCustomFolderPath"
    }

    private let captureDefaults: UserDefaults

    /// - Parameter defaults: persistence store; inject an isolated suite in tests.
    init(defaults: UserDefaults = .standard) {
        captureDefaults = defaults
        // Re-bind every @AppStorage key to the injected suite (isolated-suite tests).
        _position = AppStorage(wrappedValue: .dynamic, "sideWindowPosition", store: defaults)
        _showSideWindow = AppStorage(wrappedValue: true, "showSideWindow", store: defaults)
        _launchAtLogin = AppStorage(wrappedValue: false, "launchAtLogin", store: defaults)
        _xcodePath = AppStorage(wrappedValue: "", "xcodePath", store: defaults)
        _captureDestination = AppStorage(wrappedValue: .desktop, "captureDestination", store: defaults)
        _captureASCFramePreset = AppStorage(wrappedValue: .iphone69x1320, "captureASCFramePreset", store: defaults)
        _captureBezelMode = AppStorage(wrappedValue: .simulatorNative, "captureBezelMode", store: defaults)
        _captureBackground = AppStorage(wrappedValue: .solid, "captureBackground", store: defaults)
        _captureExportFormat = AppStorage(wrappedValue: .mp4, "captureExportFormat", store: defaults)
        _captureGIFSize = AppStorage(wrappedValue: 480, "captureGIFSize", store: defaults)
        _captureGIFFps = AppStorage(wrappedValue: 10, "captureGIFFps", store: defaults)
        _captureShowTouchIndicators = AppStorage(wrappedValue: false, "captureShowTouchIndicators", store: defaults)
    }

    /// Custom capture folder as a plain string path (non-sandboxed, REQ-nfr-04).
    var customCaptureFolder: URL? {
        get {
            captureDefaults.string(forKey: CaptureStorageKey.customFolderPath)
                .map { URL(fileURLWithPath: $0) }
        }
        set {
            if let newValue {
                captureDefaults.set(newValue.path, forKey: CaptureStorageKey.customFolderPath)
            } else {
                captureDefaults.removeObject(forKey: CaptureStorageKey.customFolderPath)
            }
        }
    }

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
            AppLogger.settings.error("Launch at login error: \(error, privacy: .public)")
        }
    }
}
