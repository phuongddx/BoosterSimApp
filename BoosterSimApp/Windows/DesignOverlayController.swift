// DesignOverlayController.swift — Owns DesignOverlayPanel: tracker frame sync, tool visibility, geometry push
// Combine only (repo convention): sink one = tracker.$activeSimulator sets the panel to the Simulator frame;
// sink two = service.objectWillChange refreshes tool visibility and panel ordering.
import AppKit
import Combine
import SwiftUI

@MainActor
final class DesignOverlayController: ObservableObject {

    // MARK: - Private

    private let panel: DesignOverlayPanel
    private let safeAreaOverlayView = SafeAreaOverlayView()
    private let gridOverlayView = GridOverlayView()
    private var service: DesignOverlayService?
    private var currentSimulator: SimulatorWindow?
    private var currentContentRect: CGRect?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    init(panel: DesignOverlayPanel) {
        self.panel = panel
        safeAreaOverlayView.isHidden = true
        gridOverlayView.isHidden = true
        panel.install(safeAreaOverlayView, at: .safeArea)   // grid stays above; comparison image below (D-04)
        panel.install(gridOverlayView, at: .grid)
    }

    // MARK: - Attach

    func attach(to tracker: SimulatorWindowTracker, service: DesignOverlayService) {
        self.service = service

        tracker.$activeSimulator
            .sink { [weak self] simulator in
                guard let self else { return }
                guard let sim = simulator else {
                    self.currentSimulator = nil
                    self.panel.orderOut(nil)
                    return
                }
                self.currentSimulator = sim
                self.panel.setFrame(sim.frame, display: true)
                self.pushGeometry(for: sim)
                self.refreshVisibility()
            }
            .store(in: &cancellables)

        // objectWillChange fires before mutations land; the main-queue hop reads post-mutation state.
        service.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refreshVisibility() }
            .store(in: &cancellables)
    }

    // MARK: - Private
    /// Any tool on with a tracked Simulator → panel front; otherwise out. Drawn tool views toggle here.
    private func refreshVisibility() {
        guard let service else { return }
        gridOverlayView.isHidden = !service.showGrid
        gridOverlayView.updateStyle(color: NSColor(service.gridColor), opacity: service.gridOpacity)
        safeAreaOverlayView.isHidden = !service.showSafeArea
        safeAreaOverlayView.updateInsets(service.effectiveInsets)
        let anyToolOn = service.showGrid || service.showRuler || service.showSafeArea
        if anyToolOn, currentSimulator != nil {
            panel.orderFront(nil)
        } else {
            panel.orderOut(nil)
        }
    }

    /// Device resolution chain (Pattern 5): frame → calibrated content rect → orientation-aware logical size →
    /// scale + insets; safe-area resolution consumes the tracker device (the service stays tracker-free).
    private func pushGeometry(for sim: SimulatorWindow) {
        let contentRect = calibratedContentRect(for: sim)
        currentContentRect = contentRect
        let orientation = OverlayGeometry.orientation(contentRect: contentRect)
        let portraitSize = SafeAreaCatalog.logicalSize(forDeviceName: sim.deviceName)
        let scale = portraitSize.map {
            let size = orientation == .landscape ? CGSize(width: $0.height, height: $0.width) : $0
            return OverlayGeometry.scale(contentRect: contentRect, deviceLogicalSize: size)
        } ?? 1
        if let service {
            service.resolvedInsets = SafeAreaCatalog.insets(
                forDeviceName: sim.deviceName, logicalSize: portraitSize, orientation: orientation)
            service.resolvedDeviceName = sim.deviceName ?? sim.displayName
        }
        gridOverlayView.update(contentRect: contentRect, scale: scale)
        safeAreaOverlayView.update(contentRect: contentRect, scale: scale)
    }

    /// Content rect + persisted calibration offsets — the bezel escape hatch (Pitfall 3 / Open Question 5).
    private func calibratedContentRect(for sim: SimulatorWindow) -> CGRect {
        let base = OverlayGeometry.contentRect(windowFrame: sim.frame)
        guard let service else { return base }
        return base.offsetBy(dx: service.calibrationX, dy: service.calibrationY)
    }
}
