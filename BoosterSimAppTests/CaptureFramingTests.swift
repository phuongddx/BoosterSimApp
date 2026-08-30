// CaptureFramingTests.swift — Pure compositing math for ASC framing (no SCK, no windows)
import Foundation
import CoreGraphics
import Testing
@testable import BoosterSimApp

struct CaptureFramingTests {

    // MARK: - Builders

    private func makeSize(_ width: CGFloat, _ height: CGFloat) -> CGSize {
        CGSize(width: width, height: height)
    }

    /// Synthetic headless input image; `transparent` yields a fully transparent bitmap
    /// to prove render() flattens alpha (ASC rejects transparency).
    private func makeImage(width: Int, height: Int, transparent: Bool = false) -> CGImage {
        let alphaInfo: CGImageAlphaInfo = transparent ? .premultipliedLast : .noneSkipLast
        let ctx = CGContext(
            data: nil, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: alphaInfo.rawValue
        )!
        if transparent {
            ctx.clear(CGRect(x: 0, y: 0, width: width, height: height))
        } else {
            ctx.setFillColor(CGColor(red: 0.2, green: 0.4, blue: 0.6, alpha: 1))
            ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
        return ctx.makeImage()!
    }

    // MARK: - ASC Preset Table

    @Test func presetPixelSizesMatchAppleSpecExactly() {
        #expect(ASCFramePreset.iphone69x1320.pixelSize == makeSize(1320, 2868))
        #expect(ASCFramePreset.iphone69x1290.pixelSize == makeSize(1290, 2796))
        #expect(ASCFramePreset.iphone69x1260.pixelSize == makeSize(1260, 2736))
        #expect(ASCFramePreset.iphone65x1284.pixelSize == makeSize(1284, 2778))
        #expect(ASCFramePreset.iphone65x1242.pixelSize == makeSize(1242, 2688))
        #expect(ASCFramePreset.ipad13x2064.pixelSize == makeSize(2064, 2752))
        #expect(ASCFramePreset.ipad13x2048.pixelSize == makeSize(2048, 2732))
    }

    @Test func presetDeviceFamiliesGroupCorrectly() {
        #expect(ASCFramePreset.iphone69x1320.deviceFamily == .iphone69)
        #expect(ASCFramePreset.iphone69x1290.deviceFamily == .iphone69)
        #expect(ASCFramePreset.iphone69x1260.deviceFamily == .iphone69)
        #expect(ASCFramePreset.iphone65x1284.deviceFamily == .iphone65)
        #expect(ASCFramePreset.iphone65x1242.deviceFamily == .iphone65)
        #expect(ASCFramePreset.ipad13x2064.deviceFamily == .ipad13)
        #expect(ASCFramePreset.ipad13x2048.deviceFamily == .ipad13)
    }

    // MARK: - Framing Math

    @Test func frameCentersContentInsidePaddingInsetCanvas() {
        let content = makeSize(100, 200)
        let preset = ASCFramePreset.iphone69x1320
        let padding: CGFloat = 24

        let result = CaptureCompositor.frame(content: content, preset: preset, padding: padding, mode: .none)

        #expect(result.canvas == preset.pixelSize)
        // Inside the padding-inset canvas on every edge
        #expect(result.contentRect.minX >= padding)
        #expect(result.contentRect.minY >= padding)
        #expect(result.contentRect.maxX <= preset.pixelSize.width - padding)
        #expect(result.contentRect.maxY <= preset.pixelSize.height - padding)
        // Centered origin (rounded placement keeps the center within 1px)
        #expect(abs(result.contentRect.midX - preset.pixelSize.width / 2) <= 1)
        #expect(abs(result.contentRect.midY - preset.pixelSize.height / 2) <= 1)
        // Uniform fit scale is the min of the two available ratios
        let availWidth = preset.pixelSize.width - padding * 2
        let availHeight = preset.pixelSize.height - padding * 2
        let expected = min(availWidth / content.width, availHeight / content.height)
        #expect(abs(result.scale - expected) < 0.0001)
    }

    @Test func simulatorNativeFramingMatchesNoBezelFraming() {
        let content = makeSize(400, 800)
        let plain = CaptureCompositor.frame(content: content, preset: .iphone65x1284, padding: 12, mode: .none)
        let native = CaptureCompositor.frame(content: content, preset: .iphone65x1284, padding: 12, mode: .simulatorNative)
        #expect(plain == native)
    }

    // MARK: - No Stretch

    @Test func uniformScaleNeverStretchesContent() {
        let inputs = [makeSize(600, 1200), makeSize(1200, 600), makeSize(800, 800)]
        for preset in ASCFramePreset.allCases {
            for content in inputs {
                let result = CaptureCompositor.frame(content: content, preset: preset, padding: 16, mode: .none)
                let contentAspect = content.width / content.height
                let rectAspect = result.contentRect.width / result.contentRect.height
                #expect(abs(rectAspect - contentAspect) < 0.01)
            }
        }
    }

    // MARK: - Opaque Output

    @Test func renderFlattensTransparentInputOntoSolidBackground() {
        let preset = ASCFramePreset.iphone69x1290
        let output = CaptureCompositor.render(
            content: makeImage(width: 64, height: 128, transparent: true),
            preset: preset, bezel: .none, background: .solid, padding: 12
        )

        #expect(output.width == Int(preset.pixelSize.width))
        #expect(output.height == Int(preset.pixelSize.height))
        #expect([CGImageAlphaInfo.none, .noneSkipFirst, .noneSkipLast].contains(output.alphaInfo))
    }

    @Test func renderFlattensTransparentInputOntoGradientBackground() {
        let preset = ASCFramePreset.ipad13x2048
        let output = CaptureCompositor.render(
            content: makeImage(width: 90, height: 120, transparent: true),
            preset: preset, bezel: .drawn, background: .gradient, padding: 8
        )

        #expect(output.width == Int(preset.pixelSize.width))
        #expect(output.height == Int(preset.pixelSize.height))
        #expect([CGImageAlphaInfo.none, .noneSkipFirst, .noneSkipLast].contains(output.alphaInfo))
    }

    // MARK: - Drawn Bezel Geometry

    @Test func drawnBezelCutoutInsetsContentOnAllSides() {
        let content = makeSize(500, 1000)
        let preset = ASCFramePreset.iphone69x1320
        let padding: CGFloat = 20

        let plain = CaptureCompositor.frame(content: content, preset: preset, padding: padding, mode: .none)
        let beveled = CaptureCompositor.frame(content: content, preset: preset, padding: padding, mode: .drawn)
        let thickness = CaptureCompositor.bezelThickness(for: preset.pixelSize)

        // Content shrinks strictly inside the plain framing…
        #expect(beveled.contentRect.width < plain.contentRect.width)
        #expect(beveled.contentRect.height < plain.contentRect.height)
        // …the cutout keeps it out of the bezel ring on every side (±1px rounding)
        #expect(beveled.contentRect.minX >= padding + thickness - 1)
        #expect(beveled.contentRect.minY >= padding + thickness - 1)
        #expect(beveled.contentRect.maxX <= preset.pixelSize.width - padding - thickness + 1)
        #expect(beveled.contentRect.maxY <= preset.pixelSize.height - padding - thickness + 1)
        // Width is the constrained axis for this aspect — margins land exactly on the cutout
        #expect(abs(beveled.contentRect.minX - (padding + thickness)) <= 1)
        #expect(abs(preset.pixelSize.width - beveled.contentRect.maxX - (padding + thickness)) <= 1)
        // Symmetric centering on both axes (rounded placement stays within 1px of center)
        #expect(abs(beveled.contentRect.midX - preset.pixelSize.width / 2) <= 1)
        #expect(abs(beveled.contentRect.midY - preset.pixelSize.height / 2) <= 1)
        // Uniform scale preserved — the bezel never stretches the content
        let contentAspect = content.width / content.height
        let rectAspect = beveled.contentRect.width / beveled.contentRect.height
        #expect(abs(rectAspect - contentAspect) < 0.01)
        #expect(beveled.scale < plain.scale)
    }
}
