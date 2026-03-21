// SimulatorWindow.swift — Data model for a detected iOS Simulator window
import Foundation
import CoreGraphics

struct SimulatorWindow: Identifiable, Equatable {
    let id: CGWindowID       // kCGWindowNumber
    let pid: pid_t           // kCGWindowOwnerPID
    var deviceName: String?  // kCGWindowName (nil without Screen Recording permission)
    var frame: CGRect        // kCGWindowBounds in screen coords
    var isOnScreen: Bool
    var isMinimized: Bool

    // Fallback display name when Screen Recording not granted
    var displayName: String {
        deviceName ?? "Simulator (ID: \(id))"
    }
}
