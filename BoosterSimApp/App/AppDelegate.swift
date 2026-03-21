// AppDelegate.swift — NSApplicationDelegate hosting all AppKit services
// Owns: SimulatorWindowTracker, SideWindowController, PermissionManager, onboarding window
import AppKit
import SwiftUI
import Combine

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {

    // MARK: - Services (owned here, shared to views via @EnvironmentObject)

    let tracker = SimulatorWindowTracker()
    let settings = AppSettings()
    lazy var sideWindowController = SideWindowController(settings: settings, tracker: tracker)

    // MARK: - Private

    private var onboardingWindow: NSWindow?
    @AppStorage("completedOnboarding") private var completedOnboarding = false

    // MARK: - NSApplicationDelegate

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Wire side window to simulator tracker
        sideWindowController.attach(to: tracker)

        // Start detecting simulators
        tracker.startTracking()

        // Show onboarding on first launch
        if !completedOnboarding {
            openOnboardingWindow()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Menu bar app stays alive even when all windows are closed
        return false
    }

    func applicationWillTerminate(_ notification: Notification) {
        tracker.stopTracking()
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
