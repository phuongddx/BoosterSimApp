// SideWindowController.swift — Manages SideWindowPanel lifecycle, position sync, and collapse state
import AppKit
import SwiftUI
import Combine

@MainActor
final class SideWindowController: ObservableObject {

    // MARK: - Published State

    @Published private(set) var isVisible = false
    @Published var isCollapsed = false

    // MARK: - Private

    private let panel = SideWindowPanel()
    private let springAnimator = SpringAnimator()
    private var currentSimulator: SimulatorWindow?
    private var settings: AppSettings
    private var trackerCancellable: AnyCancellable?
    private var focusCancellable: AnyCancellable?
    private var certificateCancellable: AnyCancellable?
    private var isSimulatorFocused = true
    private var lastPanelSide: PanelSide = .right
    private var hostingView: NSView?
    private var isUpdatingPosition = false
    private var keyMonitor: Any?
    private var reducedMotion: Bool {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }
    private var currentContentHeight: CGFloat {
        let h = hostingView?.intrinsicContentSize.height ?? 0
        return h > 0 ? h : SideWindowMetrics.minHeight
    }

    /// Which side the panel is currently on relative to the simulator.
    private enum PanelSide {
        case left, right, bottom
    }

    // MARK: - Init

    init(
        settings: AppSettings,
        tracker: SimulatorWindowTracker,
        statusBarService: StatusBarService,
        envOverrideService: EnvironmentOverrideService,
        buildStatsService: BuildStatsService,
        axInspectorService: AXInspectorService,
        cameraService: CameraService,
        certificateService: CertificateService,
        connectService: ConnectService,
        networkConditionService: NetworkConditionService,
        deepLinkService: DeepLinkService,
        designComparisonService: DesignComparisonService,
        captureService: CaptureService
    ) {
        self.settings = settings
        springAnimator.onFrameUpdate = { [weak self] frame in
            self?.panel.setFrame(frame, display: true)
        }
        embedSwiftUIContent(
            tracker: tracker,
            statusBarService: statusBarService,
            envOverrideService: envOverrideService,
            buildStatsService: buildStatsService,
            axInspectorService: axInspectorService,
            cameraService: cameraService,
            certificateService: certificateService,
            connectService: connectService,
            networkConditionService: networkConditionService,
            deepLinkService: deepLinkService,
            designComparisonService: designComparisonService,
            captureService: captureService
        )
        certificateCancellable = tracker.$activeSimulator
            .receive(on: DispatchQueue.main)
            .sink { simulator in
                certificateService.reconcileStatus(udid: simulator?.udid)
            }
        setupKeyboardShortcut()
    }

    // MARK: - Tracker Integration

    func attach(to tracker: SimulatorWindowTracker) {
        trackerCancellable = tracker.$activeSimulator.sink { [weak self] simulator in
            guard let self else { return }
            if let sim = simulator {
                self.attachToSimulator(sim)
            } else {
                self.detach()
            }
        }
        // Hide panel when Simulator loses focus; re-show when it regains focus
        focusCancellable = tracker.$isSimulatorFocused.sink { [weak self] focused in
            guard let self else { return }
            self.isSimulatorFocused = focused
            guard self.currentSimulator != nil else { return }
            if focused {
                if self.settings.showSideWindow { self.show() }
            } else {
                self.hide()
            }
        }
    }

    // MARK: - Show/Hide

    func toggle() { isVisible ? hide() : show() }

    func show() {
        guard currentSimulator != nil else { return }
        panel.orderFront(nil)
        isVisible = true
    }

    func hide() {
        panel.orderOut(nil)
        isVisible = false
    }

    // MARK: - Collapse/Expand

    func toggleCollapsed() {
        springAnimator.stop()
        let duration = reducedMotion ? 0.1 : 0.3
        isCollapsed.toggle()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = duration
            ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            updatePosition(animated: true)
        }
    }

    // MARK: - Simulator Attachment

    private func attachToSimulator(_ simulator: SimulatorWindow) {
        currentSimulator = simulator
        updatePosition()
        if settings.showSideWindow && isSimulatorFocused { show() }
    }

    private func detach() {
        currentSimulator = nil
        springAnimator.stop()
        hide()
    }

    // MARK: - Position Update

    func updatePosition(animated: Bool = false) {
        guard !isUpdatingPosition, let sim = currentSimulator else { return }
        isUpdatingPosition = true
        defer { isUpdatingPosition = false }
        let screen = PositionCalculator.screen(containing: sim.frame)
        let frame  = PositionCalculator.panelFrame(
            simulatorFrame: sim.frame,
            position: settings.position,
            screenFrame: screen.visibleFrame,
            isCollapsed: isCollapsed,
            contentHeight: currentContentHeight
        )

        // Collapse/expand uses AppKit animation context — bypass spring
        if animated {
            panel.animator().setFrame(frame, display: true)
            return
        }

        // Reduced motion — rigid 1:1 tracking, no spring
        if reducedMotion {
            panel.setFrame(frame, display: true)
            return
        }

        // Detect side-switch: snap instantly then let spring settle
        let newSide = panelSide(for: frame, simulator: sim.frame)
        if newSide != lastPanelSide {
            lastPanelSide = newSide
            springAnimator.snapTo(frame: frame)
        } else {
            springAnimator.setTarget(frame: frame)
        }
    }

    /// Determine which side the panel is on relative to the simulator.
    private func panelSide(for panelFrame: CGRect, simulator simFrame: CGRect) -> PanelSide {
        if panelFrame.minY < simFrame.minY { return .bottom }
        if panelFrame.midX < simFrame.midX { return .left }
        return .right
    }

    // MARK: - SwiftUI Hosting

    private func embedSwiftUIContent(
        tracker: SimulatorWindowTracker,
        statusBarService: StatusBarService,
        envOverrideService: EnvironmentOverrideService,
        buildStatsService: BuildStatsService,
        axInspectorService: AXInspectorService,
        cameraService: CameraService,
        certificateService: CertificateService,
        connectService: ConnectService,
        networkConditionService: NetworkConditionService,
        deepLinkService: DeepLinkService,
        designComparisonService: DesignComparisonService,
        captureService: CaptureService
    ) {
        let content = SideWindowView(
            tracker: tracker,
            controller: self,
            onHeightChanged: { [weak self] in
                // Defer off SwiftUI's layout pass to avoid reentrant NSHostingView layout.
                // Use animated:false so the spring animator coalesces rapid updates.
                DispatchQueue.main.async { [weak self] in
                    self?.updatePosition()
                }
            }
        )
            .environmentObject(statusBarService)
            .environmentObject(envOverrideService)
            .environmentObject(buildStatsService)
            .environmentObject(axInspectorService)
            .environmentObject(cameraService)
            .environmentObject(certificateService)
            .environmentObject(networkConditionService)
            .environmentObject(connectService)
            .environmentObject(deepLinkService)
            .environmentObject(designComparisonService)
            .environmentObject(captureService)
        let hv = NSHostingView(rootView: content)
        hv.sizingOptions = [.minSize, .intrinsicContentSize]
        panel.contentView = hv
        hostingView = hv
    }

    // MARK: - Keyboard Shortcut (Cmd+W hides side window)

    private func setupKeyboardShortcut() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            if event.window === self.panel,
               event.modifierFlags.contains(.command),
               event.charactersIgnoringModifiers == "w" {
                self.hide()
                return nil
            }
            return event
        }
    }

    deinit {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
    }
}
