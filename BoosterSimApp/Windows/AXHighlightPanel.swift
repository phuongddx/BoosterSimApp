// AXHighlightPanel.swift — Transparent floating panel that draws an orange highlight
// over a selected accessibility element in the Simulator window.
import AppKit

// MARK: - Highlight View

private final class AXHighlightView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        NSColor.orange.withAlphaComponent(0.9).setStroke()
        let path = NSBezierPath(
            roundedRect: bounds.insetBy(dx: 2, dy: 2),
            xRadius: 4, yRadius: 4
        )
        path.lineWidth = 3
        path.stroke()
    }
}

// MARK: - Panel

final class AXHighlightPanel: NSPanel {

    private let highlightView = AXHighlightView()
    private var dismissTimer: Timer?

    // MARK: - Init

    init() {
        super.init(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isOpaque              = false
        backgroundColor       = .clear
        level                 = .floating
        ignoresMouseEvents    = true
        collectionBehavior    = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isReleasedWhenClosed  = false
        contentView           = highlightView
    }

    // MARK: - Public Methods

    func show(at frame: CGRect) {
        dismissTimer?.invalidate()
        let panelFrame = frame.insetBy(dx: -4, dy: -4)
        setFrame(panelFrame, display: false)
        highlightView.frame = contentView?.bounds ?? panelFrame
        highlightView.needsDisplay = true
        orderFront(nil)
        scheduleDismiss()
    }

    func hide() {
        dismissTimer?.invalidate()
        orderOut(nil)
    }

    // MARK: - Private

    private func scheduleDismiss() {
        dismissTimer = Timer.scheduledTimer(withTimeInterval: 2.5, repeats: false) { [weak self] _ in
            self?.hide()
        }
    }
}
