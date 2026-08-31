// DesignOverlayController+InputMode.swift — Capture-mode input machine: OverlayInputMode, ruler/magnifier arming
// reactions, Esc-cancel and hover-monitor lifecycle. Split from DesignOverlayController.swift to hold the
// file-size standard. Monitor discipline (SideWindowController keyMonitor precedent, threat T-04-08): every
// monitor is installed on arm and removed on EVERY disarm path AND in deinit — no ambient tracking survives.
import AppKit
import OSLog

extension DesignOverlayController {

    // MARK: - Types

    /// Single input mode by construction: exactly one capture-mode tool may own the panel at a time.
    enum OverlayInputMode {
        case clickThrough, ruler, magnifier
    }

    // MARK: - Ruler

    /// service.isRulerArmed reaction: arm → capture mode + interactive layer; any disarm → click-through.
    func setRulerMode(_ armed: Bool) {
        guard let service else { return }
        if armed {
            enterCaptureMode()
            inputMode = .ruler
            rulerView.reset()
            if let rect = currentContentRect {
                rulerView.update(contentRect: rect, scale: currentScale)
            }
            rulerView.isHidden = false
            AppLogger.design.info("[DesignOverlay] ruler armed — capture mode on")
        } else if inputMode == .ruler {
            exitToClickThrough()
            AppLogger.design.info("[DesignOverlay] ruler disarmed — click-through restored")
        }
    }

    /// Drag commit: the measurement lands in the service and the tool disarms (panel returns to click-through).
    func commitRuler(start: CGPoint, end: CGPoint, deviceDistance: CGFloat) {
        service?.rulerStart = start
        service?.rulerEnd = end
        service?.rulerDistance = String(format: "%.0f pt", deviceDistance)
        service?.disarmRuler()
    }

    // MARK: - Magnifier

    /// service.isMagnifierArmed reaction: arm → capture mode + sampler + hover monitors; disarm → click-through.
    func setMagnifierMode(_ armed: Bool) {
        guard let service else { return }
        if armed {
            enterCaptureMode()
            inputMode = .magnifier
            magnifierView.isHidden = false
            guard let sampler = pixelSampler else { return }
            sampler.arm()
            guard sampler.isArmed else {
                // Refused (permission denied / no tracked Simulator): the caption is already mirrored into
                // the service — return straight to click-through without monitors.
                service.disarmMagnifier()
                return
            }
            installGlobalMouseMonitor()
            installLocalMouseMonitor()
            AppLogger.design.info("[DesignOverlay] magnifier armed — capture mode + monitors on")
        } else if inputMode == .magnifier {
            exitToClickThrough()
            pixelSampler?.disarm()
            AppLogger.design.info("[DesignOverlay] magnifier disarmed — cache cleared")
        }
    }

    /// Click-to-commit (the single path): the color under the cursor lands in pickedColor, then auto-disarm.
    func pickColor(at windowPoint: CGPoint) {
        guard inputMode == .magnifier, let sampler = pixelSampler else { return }
        if let color = sampler.sampleColor(at: windowPoint) {
            service?.pickedColor = color
            service?.liveHex = service?.colorToHex(color)
            AppLogger.design.info("[DesignOverlay] color picked — committed")
        } else {
            AppLogger.design.info("[DesignOverlay] pick outside the cached capture — nothing committed")
        }
        service?.disarmMagnifier()
    }

    // MARK: - Mode Transitions

    func enterCaptureMode() {
        panel.setCaptureMode(true)
        installEscMonitor()
    }

    /// The single exit funnel: every disarm path (commit, pick, button, Esc, arm-switch) lands here.
    func exitToClickThrough() {
        inputMode = .clickThrough
        rulerView.isHidden = true
        magnifierView.isHidden = true
        removeGlobalMouseMonitor()
        removeLocalMouseMonitor()
        removeEscMonitor()
        panel.setCaptureMode(false)
    }

    // MARK: - Esc Monitor (keyCode 53; local monitor — the panel never becomes key, Pitfall 4)

    func installEscMonitor() {
        guard escMonitor == nil else { return }
        escMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.inputMode != .clickThrough, event.keyCode == 53 else { return event }
            self.service?.disarmRuler()
            self.service?.disarmMagnifier()
            return nil
        }
    }

    func removeEscMonitor() {
        if let escMonitor {
            NSEvent.removeMonitor(escMonitor)
            self.escMonitor = nil
        }
    }

    // MARK: - Mouse-Moved Monitors (magnifier hover; armed-lifetime only, T-04-08)

    /// Observe-only global monitor: cursor moves over OTHER apps (the Simulator) — never an event tap.
    func installGlobalMouseMonitor() {
        guard globalMouseMonitor == nil else { return }
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] _ in
            self?.handleCursorAtScreenPoint(NSEvent.mouseLocation)
        }
    }

    func removeGlobalMouseMonitor() {
        if let globalMouseMonitor {
            NSEvent.removeMonitor(globalMouseMonitor)
            self.globalMouseMonitor = nil
        }
    }

    /// Panel-local mouse-moved monitor: global monitors never fire for own-app events (Pitfall 4).
    func installLocalMouseMonitor() {
        guard localMouseMonitor == nil else { return }
        localMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: .mouseMoved) { [weak self] event in
            guard let self, self.inputMode == .magnifier, event.window === self.panel else { return event }
            self.handleCursorAtWindowPoint(event.locationInWindow)
            return event
        }
    }

    func removeLocalMouseMonitor() {
        if let localMouseMonitor {
            NSEvent.removeMonitor(localMouseMonitor)
            self.localMouseMonitor = nil
        }
    }

    // MARK: - Cursor → Loupe Push

    func handleCursorAtScreenPoint(_ screenPoint: NSPoint) {
        guard inputMode == .magnifier else { return }
        let windowPoint = panel.convertFromScreen(CGRect(origin: screenPoint, size: .zero)).origin
        handleCursorAtWindowPoint(windowPoint)
    }

    /// Per-move work is a local cached-pixel read only — never a capture; loupe state is pushed directly to
    /// the view (no per-move @Published churn → no per-move redraw of every render tool).
    func handleCursorAtWindowPoint(_ windowPoint: CGPoint) {
        guard inputMode == .magnifier, let sampler = pixelSampler else { return }
        guard magnifierView.bounds.contains(windowPoint) else {
            magnifierView.update(cursorPoint: nil, crop: nil, hex: nil) // cursor left the panel — hide the loupe
            return
        }
        let magnification = service?.magnification ?? OverlayMetrics.loupeMagnificationDefault
        let crop = sampler.sampleRegion(
            aroundWindowPoint: windowPoint,
            sideInWindowPoints: OverlayMetrics.loupeDiameter / CGFloat(magnification))
        let hex = sampler.sampleColor(at: windowPoint).flatMap { service?.colorToHex($0) }
        magnifierView.update(cursorPoint: windowPoint, crop: crop, hex: hex)
    }
}
