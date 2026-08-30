// ScreenshotService.swift — One-shot window screenshot via ScreenCaptureKit
// Async internals live here and in capture services only (CONVENTIONS exception).
import Foundation
import CoreGraphics
import ScreenCaptureKit

@MainActor
final class ScreenshotService {

    // MARK: - Types

    enum CaptureError: Error {
        case windowNotFound
        case screenRecordingDenied
        case captureFailed(String)
    }

    // MARK: - Capture

    /// Captures exactly the tracked Simulator window through a desktop-independent
    /// filter — display filters would record the whole desktop, including
    /// BoosterSimApp's own panel (recursive self-capture, Pitfall 1).
    /// - Parameters:
    ///   - windowID: Tracked CGWindowID of the Simulator window
    ///   - windowFrame: Tracked window frame (screen coordinates) sizing the output
    /// - Returns: Raw window pixels at Retina scale; may carry alpha (flattened later)
    func capture(windowID: CGWindowID, windowFrame: CGRect) async throws -> CGImage {
        guard CGPreflightScreenCaptureAccess() else {
            throw CaptureError.screenRecordingDenied
        }
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let window = content.windows.first(where: { $0.windowID == windowID }) else {
            throw CaptureError.windowNotFound
        }
        #if DEBUG
        // Pitfall 1 self-capture guard: the matched window must belong to Simulator.
        assert(
            window.owningApplication?.bundleIdentifier == "com.apple.iphonesimulator",
            "Capture matched a window that does not belong to Simulator"
        )
        #endif
        let filter = SCContentFilter(desktopIndependentWindow: window)
        let configuration = SCStreamConfiguration()
        configuration.width = Int(windowFrame.width) * 2
        configuration.height = Int(windowFrame.height) * 2
        configuration.scalesToFit = false
        configuration.showsCursor = false
        configuration.ignoreShadowsSingleWindow = true
        configuration.captureResolution = .best
        do {
            return try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)
        } catch {
            throw CaptureError.captureFailed(error.localizedDescription)
        }
    }
}
