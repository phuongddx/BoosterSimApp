// ComparisonImageView.swift — Imported artboard at the BOTTOM overlay layer (D-04): aspect-fit, opacity, split clip
// draw(_:)-based AppKit view (GridOverlayView anatomy). Guides always paint above: install(at: .comparison) is the
// bottom slot, so no later-added guide can render beneath it regardless of toggle or install order.
import AppKit

final class ComparisonImageView: NSView {

    // MARK: - Properties

    private var image: NSImage?
    private var opacity: CGFloat = 0.5
    private var mode: DesignOverlayService.ComparisonMode = .overlay
    private var splitPosition: CGFloat = 0.5
    private var contentRect: CGRect?

    // MARK: - Content Injection

    /// Everything the renderer needs, pushed by the controller on service and tracker changes.
    func update(image: NSImage?, opacity: CGFloat, mode: DesignOverlayService.ComparisonMode,
                splitPosition: CGFloat, contentRect: CGRect?) {
        self.image = image
        self.opacity = opacity
        self.mode = mode
        self.splitPosition = splitPosition
        self.contentRect = contentRect
        needsDisplay = true
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        guard let image, let contentRect, let window else { return }
        let localRect = convert(window.convertFromScreen(contentRect), from: nil)
        guard let drawRect = aspectFitRect(for: image, in: localRect),
              let context = NSGraphicsContext.current?.cgContext else { return }
        // Split mode keeps the scaffold semantics: image clipped to the trailing portion at the split.
        let clipRect = mode == .split
            ? CGRect(x: localRect.minX + localRect.width * splitPosition, y: localRect.minY,
                     width: localRect.width * (1 - splitPosition), height: localRect.height)
            : localRect
        context.saveGState()
        NSBezierPath(rect: clipRect).addClip()
        context.setAlpha(mode == .overlay ? opacity : 1)   // the D-04 see-through mechanism
        image.draw(in: drawRect)
        context.restoreGState()
    }

    // MARK: - Private

    /// Largest centered fit of the image (in points) inside the content rect.
    private func aspectFitRect(for image: NSImage, in rect: CGRect) -> CGRect? {
        let size = image.size
        guard size.width > 0, size.height > 0, rect.width > 0, rect.height > 0 else { return nil }
        let fit = min(rect.width / size.width, rect.height / size.height)
        let fitted = CGSize(width: size.width * fit, height: size.height * fit)
        return CGRect(
            x: rect.midX - fitted.width / 2,
            y: rect.midY - fitted.height / 2,
            width: fitted.width,
            height: fitted.height
        )
    }
}
