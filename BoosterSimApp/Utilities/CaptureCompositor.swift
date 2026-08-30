// CaptureCompositor.swift — Pure CoreGraphics ASC-preset compositing (no SCK, no AppKit)
import Foundation
import CoreGraphics

// MARK: - Compositor

enum CaptureCompositor {

    // MARK: - Types

    struct FramingResult: Equatable {
        let canvas: CGSize
        let contentRect: CGRect
        let scale: CGFloat
    }

    // MARK: - Constants

    /// Default inset between canvas edge and content (or bezel ring in drawn mode).
    static let defaultPadding: CGFloat = 24

    /// Drawn-bezel ring thickness as a fraction of canvas width, rounded to whole pixels.
    static func bezelThickness(for canvas: CGSize) -> CGFloat {
        (canvas.width * 0.03).rounded()
    }

    // MARK: - Framing

    /// Scales content uniformly to fit the preset canvas — never stretches (Pitfall 10).
    /// - Parameters:
    ///   - content: Captured content size in pixels
    ///   - preset: ASC output canvas preset
    ///   - padding: Inset between canvas edge and content (plus bezel ring in drawn mode)
    ///   - mode: Bezel mode; `.drawn` reserves a ring around the content
    static func frame(content: CGSize, preset: ASCFramePreset, padding: CGFloat, mode: BezelMode) -> FramingResult {
        let canvas = preset.pixelSize
        let bezel = mode == .drawn ? bezelThickness(for: canvas) : 0
        let inset = padding + bezel
        let available = CGSize(width: canvas.width - inset * 2, height: canvas.height - inset * 2)
        guard content.width > 0, content.height > 0,
              available.width > 0, available.height > 0 else {
            return FramingResult(canvas: canvas, contentRect: .zero, scale: 0)
        }
        let scale = min(available.width / content.width, available.height / content.height)
        let scaled = CGSize(
            width: (content.width * scale).rounded(.down),
            height: (content.height * scale).rounded(.down)
        )
        let origin = CGPoint(
            x: ((canvas.width - scaled.width) / 2).rounded(),
            y: ((canvas.height - scaled.height) / 2).rounded()
        )
        return FramingResult(canvas: canvas, contentRect: CGRect(origin: origin, size: scaled), scale: scale)
    }

    // MARK: - Rendering

    /// Composites captured content onto an opaque ASC canvas — alpha always flattened
    /// (ASC rejects transparency, Pitfall 7).
    /// - Parameters:
    ///   - content: Raw captured window image (may carry alpha)
    ///   - preset: ASC output canvas preset
    ///   - bezel: Bezel mode; `.drawn` renders a rounded-rect device silhouette
    ///   - background: Background fill
    ///   - padding: Inset between canvas edge and content
    /// - Returns: Opaque sRGB image at exactly `preset.pixelSize` (no alpha channel)
    static func render(
        content: CGImage,
        preset: ASCFramePreset,
        bezel: BezelMode,
        background: CaptureBackground,
        padding: CGFloat
    ) -> CGImage {
        let framing = frame(
            content: CGSize(width: content.width, height: content.height),
            preset: preset, padding: padding, mode: bezel
        )
        // Alpha-skipped bitmap: every draw composites onto opaque pixels by construction.
        guard let context = CGContext(
            data: nil,
            width: Int(framing.canvas.width),
            height: Int(framing.canvas.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else {
            // Fixed, valid parameters — allocation only fails on resource exhaustion.
            fatalError("CaptureCompositor: output bitmap allocation failed")
        }
        drawBackground(background, in: context, canvas: framing.canvas)
        if bezel == .drawn {
            drawBezel(framing: framing, family: preset.deviceFamily, in: context)
        }
        context.interpolationQuality = .high
        if bezel == .drawn {
            let radius = cornerRadius(family: preset.deviceFamily, width: framing.contentRect.width)
            context.saveGState()
            context.addPath(CGPath(
                roundedRect: framing.contentRect,
                cornerWidth: radius,
                cornerHeight: radius,
                transform: nil
            ))
            context.clip()
            context.draw(content, in: framing.contentRect)
            context.restoreGState()
        } else {
            context.draw(content, in: framing.contentRect)
        }
        // makeImage() cannot fail for a context we own with fixed valid parameters.
        return context.makeImage()!
    }

    // MARK: - Drawing Helpers

    private static func drawBackground(_ background: CaptureBackground, in context: CGContext, canvas: CGSize) {
        let rect = CGRect(origin: .zero, size: canvas)
        let colors = background.fillColors
        guard colors.count > 1, let gradient = CGGradient(
            colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
            colors: colors as CFArray,
            locations: nil
        ) else {
            context.setFillColor(colors.first ?? CGColor(red: 1, green: 1, blue: 1, alpha: 1))
            context.fill(rect)
            return
        }
        context.drawLinearGradient(
            gradient,
            start: CGPoint(x: 0, y: 0),
            end: CGPoint(x: 0, y: canvas.height),
            options: []
        )
    }

    private static func drawBezel(framing: FramingResult, family: ASCDeviceFamily, in context: CGContext) {
        let thickness = bezelThickness(for: framing.canvas)
        let outer = framing.contentRect.insetBy(dx: -thickness, dy: -thickness)
        let radius = cornerRadius(family: family, width: framing.contentRect.width) + thickness
        context.setFillColor(CGColor(red: 0.09, green: 0.09, blue: 0.10, alpha: 1))
        context.addPath(CGPath(roundedRect: outer, cornerWidth: radius, cornerHeight: radius, transform: nil))
        context.fillPath()
    }

    /// Content corner radius by device family (fraction of content width, whole pixels).
    static func cornerRadius(family: ASCDeviceFamily, width: CGFloat) -> CGFloat {
        let ratio: CGFloat
        switch family {
        case .iphone69: ratio = 0.15
        case .iphone65: ratio = 0.14
        case .ipad13: ratio = 0.06
        }
        return (width * ratio).rounded()
    }
}
