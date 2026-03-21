// SideWindowPanel.swift — NSPanel subclass that floats above all windows including Simulator
import AppKit

final class SideWindowPanel: NSPanel {

    // MARK: - Init

    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: SideWindowMetrics.expandedWidth, height: SideWindowMetrics.minHeight),
            styleMask: [.titled, .closable, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        configure()
    }

    // MARK: - Configuration

    private func configure() {
        level = .floating
        isFloatingPanel = true
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        isMovableByWindowBackground = false
        animationBehavior = .utilityWindow
        backgroundColor = .windowBackgroundColor
        isReleasedWhenClosed = false    // We manage lifecycle manually
        hidesOnDeactivate = false       // Stay visible when BoosterSim loses focus
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    }

    // MARK: - Key/Main window behavior

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
