// GridGeometryTests.swift — Content-rect/scale math and the dual 8pt/4pt grid spacings (pure math, no windows)
import Foundation
import CoreGraphics
import Testing
@testable import BoosterSimApp

struct GridGeometryTests {

    // MARK: - Builders

    private func makeRect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> CGRect {
        CGRect(x: x, y: y, width: w, height: h)
    }

    /// CGFloat comparisons through a small epsilon (survives scale-multiply round trips).
    private func close(_ a: CGFloat, _ b: CGFloat) -> Bool {
        abs(a - b) < 0.0001
    }

    // MARK: - Grid Spacings (D-01: 8pt major / 4pt minor, scaled to window points)

    @Test func gridSpacingsScaleExactly() {
        #expect(OverlayGeometry.gridSpacings(scale: 1.0) == (major: 8, minor: 4))
        #expect(OverlayGeometry.gridSpacings(scale: 2.0) == (major: 16, minor: 8))
        #expect(OverlayGeometry.gridSpacings(scale: 3.0) == (major: 24, minor: 12))
    }

    // MARK: - Content Rect (frame minus title bar; bezels-off assumption A4)

    @Test func contentRectSubtractsTitleBarFromTheTopOnly() {
        let frame = makeRect(100, 200, 393, 880)
        let content = OverlayGeometry.contentRect(windowFrame: frame)
        #expect(content.minX == frame.minX)
        #expect(content.minY == frame.minY)
        #expect(content.width == frame.width)
        #expect(content.height == frame.height - SideWindowMetrics.titleBarHeight)
    }

    // MARK: - Scale

    @Test func scaleIsContentWidthOverLogicalWidth() {
        #expect(OverlayGeometry.scale(contentRect: makeRect(0, 0, 393, 852), deviceLogicalSize: CGSize(width: 393, height: 852)) == 1)
        #expect(OverlayGeometry.scale(contentRect: makeRect(0, 0, 786, 1704), deviceLogicalSize: CGSize(width: 393, height: 852)) == 2)
    }

    // MARK: - Device-Point Mapping Round Trip

    @Test func devicePointMappingRoundTripsAcrossSyntheticFrames() {
        let cases: [(rect: CGRect, logical: CGSize, point: CGPoint)] = [
            (makeRect(100, 200, 393, 852), CGSize(width: 393, height: 852), CGPoint(x: 250, y: 500)),
            (makeRect(0, 0, 786, 1704), CGSize(width: 393, height: 852), CGPoint(x: 12.5, y: 1600)),
            (makeRect(-40, 33, 375, 724), CGSize(width: 375, height: 812), CGPoint(x: 0, y: 0))
        ]
        for c in cases {
            let scale = OverlayGeometry.scale(contentRect: c.rect, deviceLogicalSize: c.logical)
            let device = OverlayGeometry.devicePoint(forWindowPoint: c.point, contentRect: c.rect, scale: scale)
            let back = OverlayGeometry.windowPoint(fromDevicePoint: device, contentRect: c.rect, scale: scale)
            #expect(close(back.x, c.point.x))
            #expect(close(back.y, c.point.y))
        }
    }
}
