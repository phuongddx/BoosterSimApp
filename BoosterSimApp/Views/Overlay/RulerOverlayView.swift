// RulerOverlayView.swift — Interactive drag-measure over the Simulator: line, endpoint markers, live device-point readout
// Receives capture-mode mouse events (panel.setCaptureMode + panel hit-test routing to the interactive layer).
// The readout converts through OverlayGeometry.devicePoint + distance — DEVICE points, never window points or pixels.
// Overlay chrome uses adaptive system blue, never the accent amber (D-03).
import AppKit

final class RulerOverlayView: NSView {

    // MARK: - Callbacks

    /// Drag committed: window-local start/end plus the geometry-converted device-point distance.
    var onCommit: ((_ start: CGPoint, _ end: CGPoint, _ deviceDistance: CGFloat) -> Void)?

    // MARK: - State

    private var contentRect: CGRect?
    private var scale: CGFloat = 1
    private var dragStart: CGPoint?
    private var dragEnd: CGPoint?

    // MARK: - Geometry Injection (as in GridOverlayView)

    func update(contentRect: CGRect, scale: CGFloat) {
        self.contentRect = contentRect
        self.scale = scale
        needsDisplay = true
    }

    /// Clears any in-progress drag; called on arm so a fresh measurement starts clean.
    func reset() {
        dragStart = nil
        dragEnd = nil
        needsDisplay = true
    }

    // MARK: - Mouse (capture mode only)

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        dragStart = convert(event.locationInWindow, from: nil)
        dragEnd = dragStart
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard dragStart != nil else { return }
        dragEnd = convert(event.locationInWindow, from: nil)
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        guard let start = dragStart else { return }
        let end = convert(event.locationInWindow, from: nil)
        let distance = deviceDistance(from: start, to: end)
        dragStart = nil
        dragEnd = nil
        needsDisplay = true
        onCommit?(start, end, distance)
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        guard let start = dragStart, let end = dragEnd, let window else { return }
        let backing = window.backingScaleFactor

        let path = NSBezierPath()
        path.move(to: start)
        path.line(to: end)
        path.lineWidth = 1.5 / backing
        NSColor.systemBlue.setStroke()
        path.stroke()
        drawMarker(at: start)
        drawMarker(at: end)
        drawReadout(from: start, to: end)
    }

    // MARK: - Private

    private func localContentRect() -> CGRect? {
        guard let contentRect, let window else { return nil }
        return convert(window.convertFromScreen(contentRect), from: nil)
    }

    /// Device-point distance via the single mapper — no second distance implementation.
    private func deviceDistance(from start: CGPoint, to end: CGPoint) -> CGFloat {
        guard let rect = localContentRect() else { return OverlayGeometry.distance(start, end) }
        let deviceStart = OverlayGeometry.devicePoint(forWindowPoint: start, contentRect: rect, scale: scale)
        let deviceEnd = OverlayGeometry.devicePoint(forWindowPoint: end, contentRect: rect, scale: scale)
        return OverlayGeometry.distance(deviceStart, deviceEnd)
    }

    private func drawMarker(at point: CGPoint) {
        let rect = CGRect(x: point.x - OverlayMetrics.markerRadius,
                          y: point.y - OverlayMetrics.markerRadius,
                          width: OverlayMetrics.markerRadius * 2,
                          height: OverlayMetrics.markerRadius * 2)
        NSColor.systemBlue.setFill()
        NSBezierPath(ovalIn: rect).fill()
    }

    private func drawReadout(from start: CGPoint, to end: CGPoint) {
        let distance = deviceDistance(from: start, to: end)
        let text = String(format: "%.0f pt", distance)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize(for: .small), weight: .medium),
            .foregroundColor: NSColor.labelColor
        ]
        let textSize = text.size(withAttributes: attributes)
        let origin = readoutOrigin(near: end, textSize: textSize)
        let pill = NSBezierPath(
            roundedRect: NSRect(
                x: origin.x - OverlayMetrics.readoutInset,
                y: origin.y - OverlayMetrics.readoutInset / 2,
                width: textSize.width + OverlayMetrics.readoutInset * 2,
                height: textSize.height + OverlayMetrics.readoutInset),
            xRadius: CornerRadius.small, yRadius: CornerRadius.small)
        NSColor.controlBackgroundColor.withAlphaComponent(0.9).setFill()
        pill.fill()
        (text as NSString).draw(at: origin, withAttributes: attributes)
    }

    /// Readout trails the end marker, flipping side to stay inside the panel.
    private func readoutOrigin(near end: CGPoint, textSize: CGSize) -> CGPoint {
        let inset = OverlayMetrics.readoutInset
        var origin = CGPoint(x: end.x + inset, y: end.y + inset)
        if origin.x + textSize.width + inset > bounds.maxX {
            origin.x = end.x - inset - textSize.width - inset
        }
        if origin.y + textSize.height + inset > bounds.maxY {
            origin.y = end.y - inset - textSize.height - inset
        }
        return CGPoint(x: max(origin.x, bounds.minX + inset), y: max(origin.y, bounds.minY + inset))
    }
}
