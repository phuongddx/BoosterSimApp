// SideWindowController.swift — Manages SideWindowPanel lifecycle, position sync, and collapse state
import AppKit
import SwiftUI
import Combine

final class SideWindowController: ObservableObject {

    // MARK: - Published State

    @Published private(set) var isVisible = false
    @Published var isCollapsed = false

    // MARK: - Private

    private let panel = SideWindowPanel()
    private var currentSimulator: SimulatorWindow?
    private var settings: AppSettings
    private var trackerCancellable: AnyCancellable?
    private var reducedMotion: Bool {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    // MARK: - Init

    init(
        settings: AppSettings,
        tracker: SimulatorWindowTracker,
        statusBarService: StatusBarService,
        envOverrideService: EnvironmentOverrideService,
        buildStatsService: BuildStatsService,
        axInspectorService: AXInspectorService,
        cameraService: CameraService
    ) {
        self.settings = settings
        embedSwiftUIContent(
            tracker: tracker,
            statusBarService: statusBarService,
            envOverrideService: envOverrideService,
            buildStatsService: buildStatsService,
            axInspectorService: axInspectorService,
            cameraService: cameraService
        )
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
        if settings.showSideWindow { show() }
    }

    private func detach() {
        currentSimulator = nil
        hide()
    }

    // MARK: - Position Update

    func updatePosition(animated: Bool = false) {
        guard let sim = currentSimulator else { return }
        let screen = PositionCalculator.screen(containing: sim.frame)
        let frame  = PositionCalculator.panelFrame(
            simulatorFrame: sim.frame,
            position: settings.position,
            screenFrame: screen.visibleFrame,
            isCollapsed: isCollapsed
        )
        if animated { panel.animator().setFrame(frame, display: true) }
        else        { panel.setFrame(frame, display: true) }
    }

    // MARK: - SwiftUI Hosting

    private func embedSwiftUIContent(
        tracker: SimulatorWindowTracker,
        statusBarService: StatusBarService,
        envOverrideService: EnvironmentOverrideService,
        buildStatsService: BuildStatsService,
        axInspectorService: AXInspectorService,
        cameraService: CameraService
    ) {
        let content = SideWindowView(tracker: tracker, controller: self)
            .environmentObject(statusBarService)
            .environmentObject(envOverrideService)
            .environmentObject(buildStatsService)
            .environmentObject(axInspectorService)
            .environmentObject(cameraService)
        panel.contentView = NSHostingView(rootView: content)
    }

    // MARK: - Keyboard Shortcut (Cmd+W hides side window)

    private func setupKeyboardShortcut() {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
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
}
