// AppLogger.swift — Centralized os.Logger instances per concern.
// Filter in Console.app by subsystem: com.nextlabs.BoosterSimApp
import OSLog

// MARK: - AppLogger

enum AppLogger {
    private static let subsystem = "com.nextlabs.BoosterSimApp"

    static let windowTracking = Logger(subsystem: subsystem, category: "WindowTracking")
    static let permissions     = Logger(subsystem: subsystem, category: "Permissions")
    static let settings        = Logger(subsystem: subsystem, category: "Settings")
    static let certificates    = Logger(subsystem: subsystem, category: "Certificates")
    static let network         = Logger(subsystem: subsystem, category: "Network")
    static let capture         = Logger(subsystem: subsystem, category: "Capture")
    static let actions         = Logger(subsystem: subsystem, category: "Actions")
    static let design         = Logger(subsystem: subsystem, category: "Design")
}
