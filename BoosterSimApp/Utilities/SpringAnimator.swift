// SpringAnimator.swift — Display-link driven spring physics for panel position tracking
// Animates toward a target frame with configurable stiffness/damping, auto-stops at rest.
import AppKit
import QuartzCore

@MainActor
final class SpringAnimator {

    // MARK: - Spring Constants

    private let stiffness: CGFloat = 280
    private let damping: CGFloat = 22
    private let restThreshold: CGFloat = 0.5

    // MARK: - State

    private var targetOrigin: CGPoint = .zero
    private var targetSize: CGSize = .zero
    private var currentOrigin: CGPoint = .zero
    private var velocity: CGPoint = .zero
    private var hasInitialPosition = false
    private var displayLink: CADisplayLink?

    /// Called each display-link tick with the interpolated frame.
    var onFrameUpdate: ((CGRect) -> Void)?

    // MARK: - Public API

    /// Update target frame; starts display link if not running.
    func setTarget(frame: CGRect) {
        targetOrigin = frame.origin
        targetSize = frame.size
        startDisplayLinkIfNeeded()
    }

    /// Instantly reposition without animation (e.g. side-switch snap).
    func snapTo(frame: CGRect) {
        targetOrigin = frame.origin
        targetSize = frame.size
        currentOrigin = frame.origin
        velocity = .zero
        stopDisplayLink()
        onFrameUpdate?(frame)
    }

    /// Stop all animation and invalidate display link.
    func stop() {
        stopDisplayLink()
        velocity = .zero
        hasInitialPosition = false
    }

    deinit {
        displayLink?.invalidate()
    }

    // MARK: - Display Link

    private func startDisplayLinkIfNeeded() {
        guard displayLink == nil else { return }
        if !hasInitialPosition {
            currentOrigin = targetOrigin
            hasInitialPosition = true
        }
        guard let screen = NSScreen.main else { return }
        let link = screen.displayLink(target: self, selector: #selector(displayLinkTick))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    private func stopDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
    }

    // MARK: - Physics Step

    @objc private func displayLinkTick(_ link: CADisplayLink) {
        let dt = CGFloat(link.targetTimestamp - link.timestamp)
        guard dt > 0, dt < 0.1 else { return } // skip degenerate frames

        // Spring force: F = -k * displacement - c * velocity
        let dx = currentOrigin.x - targetOrigin.x
        let dy = currentOrigin.y - targetOrigin.y

        let ax = -stiffness * dx - damping * velocity.x
        let ay = -stiffness * dy - damping * velocity.y

        velocity.x += ax * dt
        velocity.y += ay * dt
        currentOrigin.x += velocity.x * dt
        currentOrigin.y += velocity.y * dt

        // Emit interpolated frame
        let frame = CGRect(origin: currentOrigin, size: targetSize)
        onFrameUpdate?(frame)

        // At-rest detection: stop when displacement and velocity are both tiny
        let atRest = abs(dx) < restThreshold
            && abs(dy) < restThreshold
            && abs(velocity.x) < restThreshold
            && abs(velocity.y) < restThreshold

        if atRest {
            // Snap exactly to target and stop
            currentOrigin = targetOrigin
            velocity = .zero
            onFrameUpdate?(CGRect(origin: targetOrigin, size: targetSize))
            stopDisplayLink()
        }
    }
}
