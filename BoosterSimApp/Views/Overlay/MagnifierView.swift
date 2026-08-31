// MagnifierView.swift — Hover-follow loupe: magnified cached-capture crop, center crosshair, live hex caption
// All state is pushed by the controller (cursor point, crop, hex) — the view tracks no cursor itself; it only
// forwards the pick click. The crop comes from PixelSamplerService's cached image (sampleRegion seam), never a
// per-move capture. Chrome uses system colors — never the accent amber (D-03).
import AppKit

final class MagnifierView: NSView {

    // MARK: - Callbacks

    /// Pick click (capture mode): the window point under the cursor at click time.
    var onPick: ((CGPoint) -> Void)?

    // MARK: - State (controller-pushed)

    private var cursorPoint: CGPoint?
    private var crop: CGImage?
    private var hexCaption: String?

    // MARK: - Input

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        onPick?(convert(event.locationInWindow, from: nil))
    }

    // MARK: - Updates

    /// Cursor left the panel → nil point hides the loupe; crop/hex ride along on every move.
    func update(cursorPoint: CGPoint?, crop: CGImage?, hex: String?) {
        self.cursorPoint = cursorPoint
        self.crop = crop
        self.hexCaption = hex
        needsDisplay = true
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        guard let cursor = cursorPoint else { return }
        let diameter = OverlayMetrics.loupeDiameter
        let center = loupeCenter(for: cursor)
        let circle = CGRect(x: center.x - diameter / 2, y: center.y - diameter / 2,
                            width: diameter, height: diameter)
        let loupe = NSBezierPath(ovalIn: circle)

        if let crop {
            NSGraphicsContext.current?.saveGraphicsState()
            loupe.addClip()
            NSImage(cgImage: crop, size: NSSize(width: diameter, height: diameter)).draw(in: circle)
            NSGraphicsContext.current?.restoreGraphicsState()
        } else {
            // Capture not cached yet (in flight) — an honest empty lens, never stale content.
            NSColor.controlBackgroundColor.withAlphaComponent(0.4).setFill()
            loupe.fill()
        }

        drawCrosshair(at: center)
        let backing = window?.backingScaleFactor ?? 2
        NSColor.systemBlue.setStroke()
        loupe.lineWidth = 1.5 / backing
        loupe.stroke()
        drawCaption(below: circle)
    }

    // MARK: - Private

    /// Above-leading offset, flipping below-trailing near edges — the loupe never covers the sampled point.
    private func loupeCenter(for cursor: CGPoint) -> CGPoint {
        let radius = OverlayMetrics.loupeDiameter / 2
        let offset = radius + OverlayMetrics.readoutInset
        var dx = -offset
        var dy = offset
        if cursor.x + dx - radius < bounds.minX || cursor.y + dy + radius > bounds.maxY {
            dx = offset
            dy = -offset
        }
        let center = CGPoint(x: cursor.x + dx, y: cursor.y + dy)
        return CGPoint(
            x: min(max(center.x, bounds.minX + radius), bounds.maxX - radius),
            y: min(max(center.y, bounds.minY + radius), bounds.maxY - radius))
    }

    private func drawCrosshair(at center: CGPoint) {
        let backing = window?.backingScaleFactor ?? 2
        let half = OverlayMetrics.loupeDiameter / 2 - OverlayMetrics.readoutInset
        let path = NSBezierPath()
        path.move(to: CGPoint(x: center.x - half, y: center.y))
        path.line(to: CGPoint(x: center.x + half, y: center.y))
        path.move(to: CGPoint(x: center.x, y: center.y - half))
        path.line(to: CGPoint(x: center.x, y: center.y + half))
        path.lineWidth = 1.0 / backing
        NSColor.labelColor.withAlphaComponent(0.8).setStroke()
        path.stroke()
    }

    private func drawCaption(below circle: CGRect) {
        guard let hex = hexCaption else { return }
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize(for: .small), weight: .medium),
            .foregroundColor: NSColor.labelColor
        ]
        let textSize = hex.size(withAttributes: attributes)
        var origin = CGPoint(x: circle.midX - textSize.width / 2,
                             y: circle.minY - OverlayMetrics.readoutInset - textSize.height)
        origin.x = max(origin.x, bounds.minX + OverlayMetrics.readoutInset)
        if origin.y < bounds.minY + OverlayMetrics.readoutInset {
            origin.y = circle.maxY + OverlayMetrics.readoutInset
        }
        let pill = NSBezierPath(
            roundedRect: NSRect(
                x: origin.x - OverlayMetrics.readoutInset / 2,
                y: origin.y - OverlayMetrics.readoutInset / 2,
                width: textSize.width + OverlayMetrics.readoutInset,
                height: textSize.height + OverlayMetrics.readoutInset),
            xRadius: CornerRadius.small, yRadius: CornerRadius.small)
        NSColor.controlBackgroundColor.withAlphaComponent(0.9).setFill()
        pill.fill()
        (hex as NSString).draw(at: origin, withAttributes: attributes)
    }
}
