// CaptureDestination.swift — Where a finished capture lands
import Foundation

// MARK: - Destination

enum CaptureDestination: Equatable {
    /// Fixed folder ~/Desktop/BoosterSim Captures/
    case desktop
    /// NSPasteboard PNG data — user-selected destination only
    case clipboard
    /// User-chosen folder surfaced through a save panel
    case custom(URL)
    /// Save panel with the default directory on every capture
    case ask

    var label: String {
        switch self {
        case .desktop: return "Desktop"
        case .clipboard: return "Clipboard"
        case .custom: return "Custom"
        case .ask: return "Ask"
        }
    }

    /// Resolves ~/Desktop/BoosterSim Captures/, creating it on demand.
    static func defaultDesktopFolder() -> URL {
        let desktop = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask)[0]
        let folder = desktop.appendingPathComponent("BoosterSim Captures")
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }
}
