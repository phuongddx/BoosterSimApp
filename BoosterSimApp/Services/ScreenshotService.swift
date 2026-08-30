// ScreenshotService.swift — One-shot window screenshot via ScreenCaptureKit
// Async internals live here and in capture services only (CONVENTIONS exception).
import AppKit
import Foundation
import CoreGraphics
import ImageIO
import ScreenCaptureKit
import UniformTypeIdentifiers

@MainActor
final class ScreenshotService {

    enum CaptureError: Error {
        case windowNotFound
        case screenRecordingDenied
        case captureFailed(String)

        /// User-facing failure text — never raw error strings at the UI.
        var userMessage: String {
            switch self {
            case .windowNotFound: return "Simulator window not found — reopen it and retry"
            case .screenRecordingDenied: return "Screen Recording permission required"
            case .captureFailed(let reason): return "Capture failed: \(reason)"
            }
        }
    }

    // MARK: - Capture

    /// Captures exactly the tracked Simulator window through a desktop-independent
    /// filter — display filters would record the whole desktop, including
    /// BoosterSimApp's own panel (recursive self-capture, Pitfall 1).
    /// - Parameters:
    ///   - windowID: Tracked CGWindowID of the Simulator window
    ///   - windowFrame: Tracked window frame (screen coordinates) sizing the output
    /// - Returns: Raw window pixels at the display's backing scale; may carry
    ///   alpha (flattened later)
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
        let scale = Self.backingScale(for: windowFrame, screens: NSScreen.screens)
        let pixels = Self.pixelSize(for: windowFrame, scale: scale)
        configuration.width = Int(pixels.width)
        configuration.height = Int(pixels.height)
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

    // MARK: - Encoding

    /// Encodes a composited capture to in-memory PNG data.
    static func pngData(from image: CGImage) -> Data? {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data, UTType.png.identifier as CFString, 1, nil
        ) else { return nil }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }

    // MARK: - Pixel Scale

    /// Pixel dimensions for a capture of `frame` at `scale` — the display's
    /// backing scale decides the output size, never a hardcoded 2×
    /// (02 review WR-03; a 1× external monitor would otherwise upscale).
    static func pixelSize(for frame: CGRect, scale: CGFloat) -> CGSize {
        CGSize(width: (frame.width * scale).rounded(),
               height: (frame.height * scale).rounded())
    }

    /// Backing scale of the screen containing `frame` (screen coordinates);
    /// the main screen, else 2×.
    static func backingScale(for frame: CGRect, screens: [NSScreen]) -> CGFloat {
        if let containing = screens.first(where: { $0.frame.intersects(frame) }) {
            return containing.backingScaleFactor
        }
        return NSScreen.main?.backingScaleFactor ?? 2
    }
}
