// SafeAreaOverlayView.swift — Xcode-guide-style safe-area bands over the Simulator content rect (D-02/D-03)
// draw(_:)-based AppKit view (GridOverlayView anatomy): translucent fill + stroke bands at device-correct insets,
// adaptive systemBlue — never the accent amber (D-03). Hairline width quantized via backingScaleFactor (Pitfall 7).
import AppKit

final class SafeAreaOverlayView: NSView {

    // MARK: - Properties

    private var contentRect: CGRect?
    private var scale: CGFloat = 1
    private var insets: SafeAreaCatalog.Insets = SafeAreaCatalog.manualDefaults

    // MARK: - Geometry Injection

    /// Content rect (screen coords) plus window-points-per-device-point scale, pushed by the controller.
    func update(contentRect: CGRect, scale: CGFloat) {
        self.contentRect = contentRect
        self.scale = scale
        needsDisplay = true
    }

    /// Effective (manual-aware) insets, pushed on every service change.
    func updateInsets(_ insets: SafeAreaCatalog.Insets) {
        self.insets = insets
        needsDisplay = true
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        guard let contentRect, let window else { return }
        let localRect = convert(window.convertFromScreen(contentRect), from: nil)
        let backing = window.backingScaleFactor
        for band in bandRects(in: localRect) where band.width > 0 && band.height > 0 {
            let path = NSBezierPath(rect: band)
            NSColor.systemBlue.withAlphaComponent(0.15).setFill()
            path.fill()
            NSColor.systemBlue.withAlphaComponent(0.6).setStroke()
            path.lineWidth = 1.0 / backing
            path.stroke()
        }
    }

    // MARK: - Private

    /// The four inset bands in window points (device insets × scale): top/bottom/leading/trailing.
    private func bandRects(in rect: CGRect) -> [CGRect] {
        [
            CGRect(x: rect.minX, y: rect.maxY - insets.top * scale,
                   width: rect.width, height: insets.top * scale),
            CGRect(x: rect.minX, y: rect.minY,
                   width: rect.width, height: insets.bottom * scale),
            CGRect(x: rect.minX, y: rect.minY,
                   width: insets.left * scale, height: rect.height),
            CGRect(x: rect.maxX - insets.right * scale, y: rect.minY,
                   width: insets.right * scale, height: rect.height)
        ]
    }
}
