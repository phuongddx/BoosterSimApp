// DesignOverlayPanel.swift — Persistent transparent click-through panel exactly covering the Simulator window frame
// Hosts overlay tool views as ordered subviews: install(_:at:) maps D-04 layer roles to subview order, so z-order
// can never depend on toggle or orderFront sequence (RESEARCH Pitfall 1). Never key — orderFront only (Pitfall 4).
import AppKit

final class DesignOverlayPanel: NSPanel {

    // MARK: - Types

    /// D-04 layer order, bottom → top: comparison image < ruler/magnifier < safe area < grid.
    /// Guides are never hidden by the comparison image regardless of install or toggle order.
    enum OverlayLayer: CaseIterable {
        case comparison, interactive, safeArea, grid

        /// Deterministic subview index derived from the locked layer order.
        var index: Int {
            Self.allCases.firstIndex(of: self) ?? 0
        }
    }

    // MARK: - Properties

    private let container = NSView()

    // MARK: - Init

    init() {
        super.init(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isOpaque             = false
        backgroundColor      = .clear
        level                = .floating
        ignoresMouseEvents   = true                      // click-through; false only in capture mode (04-03)
        collectionBehavior   = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isReleasedWhenClosed = false                     // controller owns lifecycle
        hidesOnDeactivate    = false                     // criterion 4: survives app focus loss
        contentView          = container
    }

    // MARK: - Layer Install (D-04)

    /// Inserts a view at its layer's deterministic position; reinstalling a view repositions it, never duplicates it.
    func install(_ view: NSView, at layer: OverlayLayer) {
        view.removeFromSuperview()
        let index = min(layer.index, container.subviews.count)
        if index == container.subviews.count {
            container.addSubview(view)
        } else {
            container.addSubview(view, positioned: .below, relativeTo: container.subviews[index])
        }
        view.frame = container.bounds
        view.autoresizingMask = [.width, .height]
    }

    // MARK: - Capture Mode (04-03 seam; inert until then)

    /// Flips click-through off and mouse-moved on so interactive tools can read the overlay panel.
    func setCaptureMode(_ active: Bool) {
        ignoresMouseEvents = !active
        acceptsMouseMovedEvents = active
    }
}
