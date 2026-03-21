// WindowEnumerator.swift — Enumerates iOS Simulator windows via CGWindowListCopyWindowInfo
import AppKit
import CoreGraphics

enum WindowEnumerator {

    // MARK: - Public API

    /// Scan all on-screen windows and return those owned by the iOS Simulator process.
    static func enumerateSimulatorWindows() -> [SimulatorWindow] {
        guard let windowList = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else { return [] }

        return windowList.compactMap { info in
            parseSimulatorWindow(from: info)
        }
    }

    // MARK: - Private

    private static func parseSimulatorWindow(from info: [String: Any]) -> SimulatorWindow? {
        // Filter by owner name = "Simulator"
        guard let ownerName = info[kCGWindowOwnerName as String] as? String,
              ownerName == "Simulator" else { return nil }

        // Only normal windows (layer 0), skip menu bar items etc.
        guard let layer = info[kCGWindowLayer as String] as? Int, layer == 0 else { return nil }

        guard let windowID = info[kCGWindowNumber as String] as? CGWindowID,
              let pid = info[kCGWindowOwnerPID as String] as? pid_t else { return nil }

        // kCGWindowBounds is a CFDictionary in Quartz space (Y=0 at top, Y increases downward).
        // NSWindow/NSPanel use AppKit space (Y=0 at bottom). Convert using primary screen height.
        let frame: CGRect
        if let boundsDict = info[kCGWindowBounds as String] as? [String: CGFloat] {
            let quartzX = boundsDict["X"] ?? 0
            let quartzY = boundsDict["Y"] ?? 0
            let width   = boundsDict["Width"] ?? 0
            let height  = boundsDict["Height"] ?? 0
            // Primary screen height is the reference for the Quartz→AppKit flip
            let primaryHeight = NSScreen.main?.frame.height ?? 0
            let appKitY = primaryHeight - quartzY - height
            frame = CGRect(x: quartzX, y: appKitY, width: width, height: height)
        } else {
            return nil
        }

        // kCGWindowName requires Screen Recording permission; may be nil without it
        let deviceName = info[kCGWindowName as String] as? String

        // Skip zero-size windows (menu bar icon, dock thumbnail, etc.)
        guard frame.width > 50, frame.height > 50 else { return nil }

        return SimulatorWindow(
            id: windowID,
            pid: pid,
            deviceName: deviceName,
            frame: frame,
            isOnScreen: true,
            isMinimized: false
        )
    }
}
