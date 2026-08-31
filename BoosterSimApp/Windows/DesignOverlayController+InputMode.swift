// DesignOverlayController+InputMode.swift — Capture-mode input machine: OverlayInputMode, ruler arming reaction,
// Esc-cancel monitor lifecycle. Split from DesignOverlayController.swift to hold the file-size standard.
// Monitor discipline (SideWindowController keyMonitor precedent, threat T-04-08): every monitor is installed on
// arm and removed on EVERY disarm path AND in deinit — no ambient tracking survives the tool.
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

    // MARK: - Mode Transitions

    func enterCaptureMode() {
        panel.setCaptureMode(true)
        installEscMonitor()
    }

    /// The single exit funnel: every disarm path (commit, button, Esc, arm-switch) lands here.
    func exitToClickThrough() {
        inputMode = .clickThrough
        rulerView.isHidden = true
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
}
