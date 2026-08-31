// OverlayGeometry.swift — The single pure mapper for overlay coordinate math (window/content/device/pixel spaces)
// Centralizes the AppKit bottom-origin ↔ CGImage top-origin flip and all scale math (RESEARCH Pitfall 2);
// call sites never re-derive the flip or a backing scale. Scale is always a parameter, never a literal.
import Foundation
import CoreGraphics

enum OverlayGeometry {

    // MARK: - Window → Content

    /// Simulator window content rect: frame minus the title bar from the top (bezels-off assumption A4).
    static func contentRect(windowFrame: CGRect) -> CGRect {
        CGRect(
            x: windowFrame.minX,
            y: windowFrame.minY,
            width: windowFrame.width,
            height: windowFrame.height - SideWindowMetrics.titleBarHeight
        )
    }

    /// Window-points-per-device-point: content width over the device's logical width.
    static func scale(contentRect: CGRect, deviceLogicalSize: CGSize) -> CGFloat {
        guard deviceLogicalSize.width > 0 else { return 1 }
        return contentRect.width / deviceLogicalSize.width
    }

    // MARK: - Grid (D-01)

    /// Dual 8pt/4pt grid in window points: 8pt majors emphasized, 4pt minors subdued.
    static func gridSpacings(scale: CGFloat) -> (major: CGFloat, minor: CGFloat) {
        (major: 8 * scale, minor: 4 * scale)
    }

    // MARK: - Device Points

    static func devicePoint(forWindowPoint point: CGPoint, contentRect: CGRect, scale: CGFloat) -> CGPoint {
        guard scale > 0 else { return point }
        return CGPoint(
            x: (point.x - contentRect.minX) / scale,
            y: (point.y - contentRect.minY) / scale
        )
    }

    static func windowPoint(fromDevicePoint point: CGPoint, contentRect: CGRect, scale: CGFloat) -> CGPoint {
        CGPoint(
            x: point.x * scale + contentRect.minX,
            y: point.y * scale + contentRect.minY
        )
    }

    // MARK: - Image Pixels (CGImage top-origin vs AppKit bottom-origin)

    /// Y flipped against the window frame height, then multiplied by scale.
    static func imagePixel(forWindowPoint point: CGPoint, frameHeight: CGFloat, scale: CGFloat) -> CGPoint {
        CGPoint(x: point.x * scale, y: (frameHeight - point.y) * scale)
    }

    // MARK: - Measurement

    static func distance(_ first: CGPoint, _ second: CGPoint) -> CGFloat {
        hypot(first.x - second.x, first.y - second.y)
    }
}
