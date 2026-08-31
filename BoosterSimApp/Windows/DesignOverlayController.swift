// DesignOverlayController.swift — Owns DesignOverlayPanel: tracker frame sync, tool visibility, geometry push
// Combine only (repo convention): sink one = tracker.$activeSimulator sets the panel to the Simulator frame;
// sink two = service.objectWillChange refreshes tool visibility and panel ordering.
// Capture-mode input (OverlayInputMode, Esc/mouse monitors) lives in DesignOverlayController+InputMode.swift.
import AppKit
import Combine
import SwiftUI

@MainActor
final class DesignOverlayController: ObservableObject {

    // MARK: - Private
    // Internal: the +InputMode extension file shares these (file < 200 LOC, docs/code-standards).

    let panel: DesignOverlayPanel
    private let comparisonImageView = ComparisonImageView()
    private let safeAreaOverlayView = SafeAreaOverlayView()
    private let gridOverlayView = GridOverlayView()
    let rulerView = RulerOverlayView()
    var service: DesignOverlayService?
    var pixelSampler: PixelSamplerService?
    var inputMode: OverlayInputMode = .clickThrough
    var escMonitor: Any?
    var globalMouseMonitor: Any?
    var localMouseMonitor: Any?
    var currentSimulator: SimulatorWindow?
    var currentContentRect: CGRect?
    var currentScale: CGFloat = 1
    var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    init(panel: DesignOverlayPanel) {
        self.panel = panel
        comparisonImageView.isHidden = true
        safeAreaOverlayView.isHidden = true
        gridOverlayView.isHidden = true
        rulerView.isHidden = true
        panel.install(comparisonImageView, at: .comparison)   // bottom slot — guides always above (D-04)
        panel.install(safeAreaOverlayView, at: .safeArea)
        panel.install(gridOverlayView, at: .grid)
        panel.install(rulerView, at: .interactive)            // ruler/magnifier band: above image, below guides
        rulerView.onCommit = { [weak self] start, end, distance in
            self?.commitRuler(start: start, end: end, deviceDistance: distance)
        }
    }

    // MARK: - Attach

    /// Injection seam (plan-checker W2): the sampler arrives WITH its tracker/screenshot dependencies at
    /// attach time — the controller stores it, never constructs one. Attach runs at launch, before any tool arms.
    func attach(to tracker: SimulatorWindowTracker, service: DesignOverlayService,
                pixelSampler: PixelSamplerService) {
        self.service = service
        self.pixelSampler = pixelSampler

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

        // Armed flags drive the input-mode machine (every disarm path funnels back through here).
        service.$isRulerArmed
            .receive(on: DispatchQueue.main)
            .sink { [weak self] armed in self?.setRulerMode(armed) }
            .store(in: &cancellables)

        // Sampler captions (permission denied / no Simulator / capture failed) mirror into the service
        // so the Design tab can degrade honestly — verbs and outcomes only, never pixel data (T-04-06).
        pixelSampler.$samplerError
            .receive(on: DispatchQueue.main)
            .sink { [weak self] error in self?.service?.samplerError = error }
            .store(in: &cancellables)
    }

    deinit {
        // Monitor lifetime == controller lifetime at the latest (T-04-08): no ambient tracking survives.
        if let escMonitor { NSEvent.removeMonitor(escMonitor) }
        if let globalMouseMonitor { NSEvent.removeMonitor(globalMouseMonitor) }
        if let localMouseMonitor { NSEvent.removeMonitor(localMouseMonitor) }
    }

    // MARK: - Private
    /// Any tool on with a tracked Simulator → panel front; otherwise out. Drawn tool views toggle here.
    private func refreshVisibility() {
        guard let service else { return }
        gridOverlayView.isHidden = !service.showGrid
        gridOverlayView.updateStyle(color: NSColor(service.gridColor), opacity: service.gridOpacity)
        safeAreaOverlayView.isHidden = !service.showSafeArea
        safeAreaOverlayView.updateInsets(service.effectiveInsets)
        comparisonImageView.isHidden = (service.overlayImage == nil)
        comparisonImageView.update(
            image: service.overlayImage,
            opacity: CGFloat(service.overlayOpacity),
            mode: service.comparisonMode,
            splitPosition: CGFloat(service.splitPosition),
            contentRect: currentContentRect
        )
        // An armed interactive tool keeps the panel front even with every render tool off.
        let anyToolOn = service.showGrid || service.showSafeArea || service.overlayImage != nil
            || service.isRulerArmed
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
        currentScale = scale
        if let service {
            service.resolvedInsets = SafeAreaCatalog.insets(
                forDeviceName: sim.deviceName, logicalSize: portraitSize, orientation: orientation)
            service.resolvedDeviceName = sim.deviceName ?? sim.displayName
        }
        gridOverlayView.update(contentRect: contentRect, scale: scale)
        safeAreaOverlayView.update(contentRect: contentRect, scale: scale)
        rulerView.update(contentRect: contentRect, scale: scale)
        // The magnifier's armed re-capture rule (frame change → fresh capture, A5) arrives with its tool.
    }

    /// Content rect + persisted calibration offsets — the bezel escape hatch (Pitfall 3 / Open Question 5).
    private func calibratedContentRect(for sim: SimulatorWindow) -> CGRect {
        let base = OverlayGeometry.contentRect(windowFrame: sim.frame)
        guard let service else { return base }
        return base.offsetBy(dx: service.calibrationX, dy: service.calibrationY)
    }
}
