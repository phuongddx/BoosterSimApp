// SimulatorWindow.swift — Data model for a detected iOS/watchOS/tvOS/visionOS Simulator window
import Foundation
import CoreGraphics

// MARK: - Device Type

enum SimulatorDeviceType: String, Codable, Sendable {
    case iOS, watchOS, tvOS, visionOS

    var sfSymbol: String {
        switch self {
        case .iOS:      return "iphone"
        case .watchOS:  return "applewatch"
        case .tvOS:     return "tv"
        case .visionOS: return "visionpro"
        }
    }
}

// MARK: - Window Model

struct SimulatorWindow: Identifiable, Equatable {
    let id: CGWindowID       // kCGWindowNumber
    let pid: pid_t           // kCGWindowOwnerPID
    var deviceName: String?  // kCGWindowName (nil without Screen Recording permission)
    var frame: CGRect        // kCGWindowBounds in AppKit screen coords
    var isOnScreen: Bool
    var isMinimized: Bool
    var deviceType: SimulatorDeviceType = .iOS   // classified via simctl list devices --json
    var udid: String?                            // simctl UDID, nil if unavailable

    // Fallback display name when Screen Recording not granted
    var displayName: String {
        deviceName ?? "Simulator (ID: \(id))"
    }
}
