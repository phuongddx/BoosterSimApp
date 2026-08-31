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
    private let gridOverlayView = GridOverlayView()
    private var service: DesignOverlayService?
    private var currentSimulator: SimulatorWindow?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    init(panel: DesignOverlayPanel) {
        self.panel = panel
        gridOverlayView.isHidden = true
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
        let anyToolOn = service.showGrid || service.showRuler
        if anyToolOn, currentSimulator != nil {
            panel.orderFront(nil)
        } else {
            panel.orderOut(nil)
        }
    }

    /// Device resolution chain: frame → content rect; deviceName → logical size → scale (Pattern 5).
    private func pushGeometry(for sim: SimulatorWindow) {
        let contentRect = OverlayGeometry.contentRect(windowFrame: sim.frame)
        let scale = SafeAreaCatalog.logicalSize(forDeviceName: sim.deviceName)
            .map { OverlayGeometry.scale(contentRect: contentRect, deviceLogicalSize: $0) } ?? 1
        gridOverlayView.update(contentRect: contentRect, scale: scale)
    }
}
