// AppDelegate.swift — NSApplicationDelegate hosting all AppKit services
import AppKit
import SwiftUI
import Combine

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {

    // MARK: - Core Services

    let tracker      = SimulatorWindowTracker()
    let settings     = AppSettings()
    let simCtlService = SimCtlService()

    // MARK: - Feature Services

    lazy var statusBarService    = StatusBarService(simCtl: simCtlService)
    lazy var envOverrideService  = EnvironmentOverrideService(simCtl: simCtlService)
    lazy var buildStatsService   = BuildStatsService()
    lazy var axInspectorService  = AXInspectorService()
    lazy var cameraService       = CameraService()
    lazy var certificateService  = CertificateService(simCtl: simCtlService)
    lazy var connectService      = ConnectService()
    lazy var axHighlightPanel    = AXHighlightPanel()

    // MARK: - Windows

    lazy var sideWindowController = SideWindowController(
        settings: settings,
        tracker: tracker,
        statusBarService: statusBarService,
        envOverrideService: envOverrideService,
        buildStatsService: buildStatsService,
        axInspectorService: axInspectorService,
        cameraService: cameraService,
        certificateService: certificateService,
        connectService: connectService
    )

    // MARK: - Private

    private var onboardingWindow: NSWindow?
    private var cancellables = Set<AnyCancellable>()
    @AppStorage("completedOnboarding") private var completedOnboarding = false

    // MARK: - NSApplicationDelegate

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Terminate if another instance is already running (LSUIElement hides duplicates)
        let runningInstances = NSRunningApplication.runningApplications(
            withBundleIdentifier: Bundle.main.bundleIdentifier ?? ""
        )
        if runningInstances.count > 1 {
            NSApp.terminate(nil)
            return
        }

        // Wire side window to simulator tracker
        sideWindowController.attach(to: tracker)

        // Start simulator detection + build monitoring
        tracker.startTracking()
        buildStatsService.startMonitoring()
        connectService.startServer()

        // NOTE: envOverrideService.loadCurrentState is called from
        // EnvironmentOverridesView (onAppear + onChange) — no need to duplicate here.

        // Drive AXHighlightPanel from AXInspectorService
        axInspectorService.$highlightFrame
            .receive(on: DispatchQueue.main)
            .sink { [weak self] frame in
                if let frame { self?.axHighlightPanel.show(at: frame) }
                else          { self?.axHighlightPanel.hide() }
            }
            .store(in: &cancellables)

        // Show onboarding on first launch
        if !completedOnboarding {
            openOnboardingWindow()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    func applicationWillTerminate(_ notification: Notification) {
        tracker.stopTracking()
        buildStatsService.stopMonitoring()
        connectService.stopServer()
    }

    // MARK: - Onboarding Window

    private func openOnboardingWindow() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: OnboardingMetrics.width, height: OnboardingMetrics.height),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Welcome to BoosterSim"
        window.contentView = NSHostingView(rootView: OnboardingContainerView())
        window.center()
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        onboardingWindow = window
    }
}
