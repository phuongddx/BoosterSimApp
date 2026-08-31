// PixelSamplerService.swift — Cached-capture pixel sampling over the tracked Simulator window
// The second sanctioned async site (CaptureService shape exactly, RESEARCH Pitfall 6): sync public API,
// one private Task bridge → ScreenshotService.capture. One capture per arming; every cursor read hits the
// cached CGImage locally (memory-only, threat T-04-06 — never written to disk, never logged as pixel data).
import AppKit
import Combine
import CoreGraphics
import OSLog

@MainActor
final class PixelSamplerService: ObservableObject {

    // MARK: - Published State

    @Published private(set) var isArmed = false
    @Published private(set) var isCapturing = false
    @Published private(set) var samplerError: String?

    // MARK: - Private

    private let screenshotService: ScreenshotService
    private let tracker: SimulatorWindowTracker

    /// Memory-only cache (T-04-06): the CGImage plus its pixel reader, cleared on every disarm.
    private var cachedImage: CGImage?
    private var cachedBitmap: NSBitmapImageRep?
    private var cachedFrameHeight: CGFloat = 0
    private var cachedScale: CGFloat = 1
    private var armedFrameSize: CGSize?
    private var armingGeneration = 0

    // Internal seams keep tests SCK-free and headless.
    var preflightPermission: () -> Bool = CGPreflightScreenCaptureAccess

    // MARK: - Init

    init(screenshotService: ScreenshotService, tracker: SimulatorWindowTracker) {
        self.screenshotService = screenshotService
        self.tracker = tracker
    }

    // MARK: - Arming (one capture per arm; RESEARCH Pattern 3)

    func arm() {
        guard preflightPermission() else {
            samplerError = "Screen Recording permission required"
            AppLogger.design.info("[PixelSamplerService] arm refused — screen recording permission")
            return
        }
        guard let sim = tracker.activeSimulator, !sim.isMinimized else {
            samplerError = "No Simulator window is being tracked"
            AppLogger.design.info("[PixelSamplerService] arm refused — no tracked Simulator")
            return
        }
        guard !isCapturing else { return } // an in-flight capture supersedes re-arm attempts
        samplerError = nil
        isArmed = true
        isCapturing = true
        cachedImage = nil
        cachedBitmap = nil
        cachedFrameHeight = sim.frame.height
        cachedScale = ScreenshotService.backingScale(for: sim.frame, screens: NSScreen.screens)
        armedFrameSize = sim.frame.size
        armingGeneration += 1
        let generation = armingGeneration
        let windowID = sim.id
        let windowFrame = sim.frame
        Task { [weak self] in
            guard let self else { return }
            let result = await self.performCapture(windowID: windowID, windowFrame: windowFrame)
            self.handleCaptureResult(result, generation: generation)
        }
        AppLogger.design.info("[PixelSamplerService] armed — capture issued")
    }

    func disarm() {
        armingGeneration += 1 // results from the just-ended arming are stale by construction
        isArmed = false
        isCapturing = false
        cachedImage = nil
        cachedBitmap = nil
        armedFrameSize = nil
        AppLogger.design.info("[PixelSamplerService] disarmed — cache cleared")
    }

    /// Frame-change re-arm (flagged assumption A5): a resize/orientation change re-captures;
    /// pure translation does not (content pixels are translation-invariant — no per-move captures).
    func refreshIfFrameChanged(_ frame: CGRect) {
        guard isArmed, !isCapturing, frame.size != armedFrameSize else { return }
        arm()
    }

    // MARK: - Sampling (sync, main thread — no per-move captures)

    /// Window point → cached-image pixel through the single tested mapper (OverlayGeometry).
    func imagePixel(forWindowPoint point: CGPoint) -> CGPoint? {
        guard cachedImage != nil else { return nil }
        return OverlayGeometry.imagePixel(forWindowPoint: point, frameHeight: cachedFrameHeight, scale: cachedScale)
    }

    func sampleColor(at windowPoint: CGPoint) -> NSColor? {
        guard let bitmap = cachedBitmap, let image = cachedImage else { return nil }
        let pixel = OverlayGeometry.imagePixel(
            forWindowPoint: windowPoint, frameHeight: cachedFrameHeight, scale: cachedScale)
        guard pixel.x >= 0, pixel.y >= 0,
              pixel.x < CGFloat(image.width), pixel.y < CGFloat(image.height) else { return nil }
        guard let color = bitmap.colorAt(x: Int(pixel.x), y: Int(pixel.y)) else { return nil }
        return color.usingColorSpace(.deviceRGB) ?? color
    }

    /// Square loupe source crop around a window point, sized in window points then scaled to pixels.
    func sampleRegion(aroundWindowPoint point: CGPoint, sideInWindowPoints side: CGFloat) -> CGImage? {
        guard let image = cachedImage else { return nil }
        let center = OverlayGeometry.imagePixel(
            forWindowPoint: point, frameHeight: cachedFrameHeight, scale: cachedScale)
        let sidePx = side * cachedScale
        let rect = CGRect(x: center.x - sidePx / 2, y: center.y - sidePx / 2,
                          width: sidePx, height: sidePx)
        return image.cropping(to: rect) // cropping clamps to the image bounds
    }

    // MARK: - Test Seams (internal: headless cache/result injection — no SCK, no windows)

    func injectCache(_ image: CGImage?, frameHeight: CGFloat, scale: CGFloat) {
        cachedImage = image
        cachedBitmap = image.map { NSBitmapImageRep(cgImage: $0) }
        cachedFrameHeight = frameHeight
        cachedScale = scale
    }

    /// Capture completion: only the current arming generation may land; late or disarmed results discard.
    func handleCaptureResult(_ image: CGImage?, generation: Int) {
        guard generation == armingGeneration, isArmed else { return }
        isCapturing = false
        guard let image else {
            samplerError = "Screen capture failed"
            AppLogger.design.info("[PixelSamplerService] capture failed")
            return
        }
        cachedImage = image
        cachedBitmap = NSBitmapImageRep(cgImage: image)
        AppLogger.design.info("[PixelSamplerService] capture cached")
    }

    // MARK: - Private (the single Task bridge body — the only async site in this file)

    private func performCapture(windowID: CGWindowID, windowFrame: CGRect) async -> CGImage? {
        try? await screenshotService.capture(windowID: windowID, windowFrame: windowFrame)
    }
}
