// GridOverlayView.swift — D-01 dual 8pt/4pt grid drawn over the Simulator content area in device points
// draw(_:)-based AppKit view (AXHighlightView precedent); SwiftUI stays in the side panel.
// Minors (4pt) subdued at half alpha with hairline weight; majors (8pt) emphasized at full alpha — adaptive
// system blue by default, never the accent amber (D-03). Widths quantized via window.backingScaleFactor (Pitfall 7).
import AppKit

final class GridOverlayView: NSView {

    // MARK: - Properties

    private var contentRect: CGRect?
    private var scale: CGFloat = 1
    private var lineColor: NSColor = .systemBlue
    private var lineOpacity: CGFloat = 1

    // MARK: - Geometry Injection

    /// Content rect (screen coords) plus window-points-per-device-point scale, pushed by the controller.
    func update(contentRect: CGRect, scale: CGFloat) {
        self.contentRect = contentRect
        self.scale = scale
        needsDisplay = true
    }

    func updateStyle(color: NSColor, opacity: CGFloat) {
        lineColor = color
        lineOpacity = opacity
        needsDisplay = true
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        guard let contentRect, let window else { return }
        let localRect = convert(window.convertFromScreen(contentRect), from: nil)
        let spacings = OverlayGeometry.gridSpacings(scale: scale)
        let backing = window.backingScaleFactor
        strokeGrid(spacing: spacings.minor, in: localRect, width: 1.0 / backing,
                   color: lineColor.withAlphaComponent(lineOpacity * 0.5))
        strokeGrid(spacing: spacings.major, in: localRect, width: 1.5 / backing,
                   color: lineColor.withAlphaComponent(lineOpacity))
    }

    // MARK: - Private

    private func strokeGrid(spacing: CGFloat, in rect: CGRect, width: CGFloat, color: NSColor) {
        guard spacing > 0, rect.width > 0, rect.height > 0 else { return }
        let path = NSBezierPath()
        var x = rect.minX
        while x <= rect.maxX {
            path.move(to: CGPoint(x: x, y: rect.minY))
            path.line(to: CGPoint(x: x, y: rect.maxY))
            x += spacing
        }
        var y = rect.minY
        while y <= rect.maxY {
            path.move(to: CGPoint(x: rect.minX, y: y))
            path.line(to: CGPoint(x: rect.maxX, y: y))
            y += spacing
        }
        path.lineWidth = width
        color.setStroke()
        path.stroke()
    }
}
