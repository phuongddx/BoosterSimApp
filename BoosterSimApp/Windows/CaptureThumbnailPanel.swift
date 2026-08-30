// CaptureThumbnailPanel.swift — Borderless floating thumbnail after a capture (3s auto-hide)
import AppKit

final class CaptureThumbnailPanel: NSPanel {

    // MARK: - Constants

    /// Longest thumbnail edge (token-derived: 5 × Spacing.xxl = 120pt).
    private static let maxEdge = Spacing.xxl * 5
    private static let autoHideInterval: TimeInterval = 3.0

    // MARK: - Private

    private let imageView = NSImageView()
    private var dismissTimer: Timer?
    private var revealURL: URL?

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
        ignoresMouseEvents    = false   // clickable — reveals the file in Finder
        collectionBehavior    = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isReleasedWhenClosed  = false

        imageView.imageScaling = .scaleProportionallyDown
        imageView.animates = false
        imageView.wantsLayer = true
        imageView.layer?.cornerRadius = CornerRadius.large
        imageView.layer?.masksToBounds = true
        imageView.layer?.shadowOpacity = 0.3
        imageView.layer?.shadowRadius = CornerRadius.large
        imageView.layer?.shadowOffset = NSSize(width: 0, height: -Spacing.xxs)
        imageView.addGestureRecognizer(
            NSClickGestureRecognizer(target: self, action: #selector(revealInFinder(_:)))
        )
        contentView = imageView
    }

    deinit {
        dismissTimer?.invalidate()
    }

    // MARK: - Public Methods

    /// Shows the saved capture anchored near the Simulator window's trailing edge,
    /// auto-hiding after 3 seconds; click reveals the file in Finder.
    func show(url: URL, anchorNear simulatorFrame: CGRect) {
        guard let image = NSImage(contentsOf: url) else { return }
        dismissTimer?.invalidate()

        let aspect = image.size.height > 0 ? image.size.width / image.size.height : 1
        var size = CGSize(width: Self.maxEdge, height: Self.maxEdge)
        if aspect >= 1 {
            size.height = (Self.maxEdge / aspect).rounded()
        } else {
            size.width = (Self.maxEdge * aspect).rounded()
        }

        let screen = PositionCalculator.screen(containing: simulatorFrame).visibleFrame
        let margin = Spacing.sm
        var origin = CGPoint(x: simulatorFrame.maxX + margin, y: simulatorFrame.midY - size.height / 2)
        // Trailing edge unavailable (side panel lives there) — fall back to the leading edge.
        if origin.x + size.width > screen.maxX {
            origin.x = simulatorFrame.minX - size.width - margin
        }
        origin.x = max(screen.minX, min(origin.x, screen.maxX - size.width))
        origin.y = max(screen.minY, min(origin.y, screen.maxY - size.height))

        setFrame(CGRect(origin: origin, size: size), display: false)
        imageView.frame = CGRect(origin: .zero, size: size)
        imageView.image = image
        revealURL = url

        orderFront(nil)
        if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            alphaValue = 1  // Reduce Motion: appear without animation
        } else {
            alphaValue = 0
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.15
                self.animator().alphaValue = 1
            }
        }
        scheduleDismiss()
    }

    func hide() {
        dismissTimer?.invalidate()
        orderOut(nil)
    }

    // MARK: - Private

    @objc private func revealInFinder(_ sender: NSClickGestureRecognizer) {
        guard let url = revealURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
        hide()
    }

    private func scheduleDismiss() {
        dismissTimer = Timer.scheduledTimer(withTimeInterval: Self.autoHideInterval, repeats: false) { [weak self] _ in
            self?.hide()
        }
    }
}
