// PixelSamplerTests.swift — Cached-capture sampling: point→pixel mapping, late-result discard, degraded preflight
// Headless: synthetic CGImages injected through internal seams — no SCK, no windows (CaptureFramingTests style).
import Foundation
import CoreGraphics
import AppKit
import Testing
@testable import BoosterSimApp

@MainActor
struct PixelSamplerTests {

    // MARK: - Builders

    private func makeSampler() -> PixelSamplerService {
        PixelSamplerService(screenshotService: ScreenshotService(), tracker: SimulatorWindowTracker())
    }

    /// 4×4 quadrant image (2×2 px blocks): top-left red, top-right green, bottom-left blue, bottom-right yellow.
    /// CGContext fills bottom-left origin; image row 0 is TOP — quadrant rects are drawn accordingly.
    private func makeQuadrantImage() -> CGImage {
        let ctx = CGContext(
            data: nil, width: 4, height: 4,
            bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        )!
        let red   = CGColor(red: 1, green: 0, blue: 0, alpha: 1)
        let green = CGColor(red: 0, green: 1, blue: 0, alpha: 1)
        let blue  = CGColor(red: 0, green: 0, blue: 1, alpha: 1)
        let yellow = CGColor(red: 1, green: 1, blue: 0, alpha: 1)
        ctx.setFillColor(red);    ctx.fill(CGRect(x: 0, y: 2, width: 2, height: 2))    // image top-left
        ctx.setFillColor(green);  ctx.fill(CGRect(x: 2, y: 2, width: 2, height: 2))    // image top-right
        ctx.setFillColor(blue);   ctx.fill(CGRect(x: 0, y: 0, width: 2, height: 2))    // image bottom-left
        ctx.setFillColor(yellow); ctx.fill(CGRect(x: 2, y: 0, width: 2, height: 2))    // image bottom-right
        return ctx.makeImage()!
    }

    /// Vertically graded image: image row 0 → (0, 0.2, 1), last row → (1, 0.2, 0) — distinct per row (Y-flip probe).
    private func makeGradedImage(width: Int, height: Int) -> CGImage {
        let ctx = CGContext(
            data: nil, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        )!
        for row in 0..<height {
            let value = CGFloat(row) / CGFloat(max(height - 1, 1))
            ctx.setFillColor(CGColor(red: value, green: 0.2, blue: 1 - value, alpha: 1))
            // CG bottom-left origin: image row `row` sits at CG y = height - 1 - row.
            ctx.fill(CGRect(x: 0, y: height - 1 - row, width: width, height: 1))
        }
        return ctx.makeImage()!
    }

    private func expectColor(_ color: NSColor, red: CGFloat, green: CGFloat, blue: CGFloat) {
        #expect(abs(color.redComponent - red) < 0.01)
        #expect(abs(color.greenComponent - green) < 0.01)
        #expect(abs(color.blueComponent - blue) < 0.01)
    }

    // MARK: - Synthetic Sampling (injected cache → exact color)

    @Test func sampledPixelIsTheExactInjectedColor() throws {
        let sampler = makeSampler()
        sampler.injectCache(makeQuadrantImage(), frameHeight: 2, scale: 2)

        // Window (0.5, 1.5) → pixel (1, 1) → top-left quadrant → red.
        expectColor(try #require(sampler.sampleColor(at: CGPoint(x: 0.5, y: 1.5))), red: 1, green: 0, blue: 0)
        // Window (1.5, 0.5) → pixel (3, 3) → bottom-right quadrant → yellow.
        expectColor(try #require(sampler.sampleColor(at: CGPoint(x: 1.5, y: 0.5))), red: 1, green: 1, blue: 0)
    }

    @Test func pointOutsideImageReturnsNilWithoutTrapping() {
        let sampler = makeSampler()
        sampler.injectCache(makeQuadrantImage(), frameHeight: 2, scale: 2)

        // Window x 5 → pixel x 10 — outside the 4-px image.
        #expect(sampler.sampleColor(at: CGPoint(x: 5, y: 1)) == nil)
    }

    // MARK: - Y-Flip Mapping (frameHeight 200, scale 2)

    @Test func topEdgeSamplesRowZeroAndBottomEdgeSamplesLastRow() throws {
        let sampler = makeSampler()
        sampler.injectCache(makeGradedImage(width: 4, height: 400), frameHeight: 200, scale: 2)

        // TOP edge (window y 200) → pixel y 0 → image row 0 → (0, 0.2, 1).
        let top = try #require(sampler.sampleColor(at: CGPoint(x: 1, y: 200)))
        expectColor(top, red: 0, green: 0.2, blue: 1)

        // BOTTOM edge (window y 0.25 → pixel y 399) → last row → (1, 0.2, 0).
        let bottom = try #require(sampler.sampleColor(at: CGPoint(x: 1, y: 0.25)))
        expectColor(bottom, red: 1, green: 0.2, blue: 0)

        // The flip is proven: same column, opposite ends, different rows.
        #expect(abs(top.blueComponent - bottom.blueComponent) > 0.9)
    }

    // MARK: - 1x Displays (Pitfall 7)

    @Test func oneXScaleMappingStaysCorrect() throws {
        let sampler = makeSampler()
        sampler.injectCache(makeQuadrantImage(), frameHeight: 4, scale: 1)

        // Window (1, 3) → pixel (1, 1) → top-left red — no doubled offsets at scale 1.
        expectColor(try #require(sampler.sampleColor(at: CGPoint(x: 1, y: 3))), red: 1, green: 0, blue: 0)
        expectColor(try #require(sampler.sampleColor(at: CGPoint(x: 3, y: 1))), red: 1, green: 1, blue: 0)
    }

    // MARK: - Late-Result Discard

    @Test func staleGenerationResultIsDiscardedAfterDisarm() {
        let sampler = makeSampler()
        sampler.injectCache(makeQuadrantImage(), frameHeight: 2, scale: 2)
        sampler.disarm() // bumps the generation; clears the cache

        // A capture completing after disarm carries the pre-bump token — stale by construction.
        sampler.handleCaptureResult(makeQuadrantImage(), generation: 0)

        #expect(sampler.sampleColor(at: CGPoint(x: 0.5, y: 0.5)) == nil) // cache stayed empty
        #expect(sampler.isArmed == false)
        #expect(sampler.samplerError == nil) // published nothing
    }

    // MARK: - Degraded Preflight

    @Test func deniedPermissionPublishesCaptionAndIssuesNoCapture() {
        let sampler = makeSampler()
        sampler.preflightPermission = { false }
        sampler.arm()

        #expect(sampler.samplerError == "Screen Recording permission required")
        #expect(sampler.isArmed == false)
        #expect(sampler.isCapturing == false) // no capture issued
        #expect(sampler.sampleColor(at: CGPoint(x: 1, y: 1)) == nil) // state clean
    }
}
