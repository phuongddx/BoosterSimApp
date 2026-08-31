// RulerMathTests.swift — Y-flip/scale window-point→image-pixel mapping and distance math (no windows)
import Foundation
import CoreGraphics
import Testing
@testable import BoosterSimApp

struct RulerMathTests {

    // MARK: - Pixel Mapping (CGImage top-origin vs AppKit bottom-origin)

    @Test func topLeftWindowPointMapsToOriginPixel() {
        let pixel = OverlayGeometry.imagePixel(forWindowPoint: CGPoint(x: 0, y: 100), frameHeight: 100, scale: 1)
        #expect(pixel == CGPoint(x: 0, y: 0))
    }

    @Test func bottomLeftWindowPointFlipsAgainstFrameHeightThenScales() {
        #expect(OverlayGeometry.imagePixel(forWindowPoint: CGPoint(x: 0, y: 0), frameHeight: 100, scale: 1) == CGPoint(x: 0, y: 100))
        #expect(OverlayGeometry.imagePixel(forWindowPoint: CGPoint(x: 0, y: 0), frameHeight: 100, scale: 2) == CGPoint(x: 0, y: 200))
    }

    @Test func interiorPointScalesBothAxes() {
        // 1x external display
        #expect(OverlayGeometry.imagePixel(forWindowPoint: CGPoint(x: 30, y: 70), frameHeight: 100, scale: 1) == CGPoint(x: 30, y: 30))
        // 2x Retina
        #expect(OverlayGeometry.imagePixel(forWindowPoint: CGPoint(x: 30, y: 70), frameHeight: 100, scale: 2) == CGPoint(x: 60, y: 60))
    }

    // MARK: - Distance

    @Test func distanceIsHypotenuse() {
        #expect(OverlayGeometry.distance(CGPoint(x: 0, y: 0), CGPoint(x: 3, y: 4)) == 5)
        #expect(OverlayGeometry.distance(CGPoint(x: 10, y: 10), CGPoint(x: 13, y: 14)) == 5)
    }

    @Test func distanceOfEqualPointsIsZero() {
        #expect(OverlayGeometry.distance(CGPoint(x: 7, y: 9), CGPoint(x: 7, y: 9)) == 0)
    }
}
