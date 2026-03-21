// PermissionManager.swift — Checks and requests macOS permissions (Accessibility, Screen Recording, Xcode, DerivedData)
import AppKit
import CoreGraphics
import ApplicationServices
import Combine
import UniformTypeIdentifiers

final class PermissionManager: ObservableObject {

    // MARK: - Published State

    @Published var accessibilityGranted = false
    @Published var screenRecordingGranted = false
    @Published var xcodeDetected = false
    @Published var derivedDataAccessGranted = false
    @Published var xcodePath: String?
    @Published var derivedDataURL: URL?

    // MARK: - Private

    private var screenRecordingPollTimer: Timer?

    // MARK: - Check All

    func checkAll() {
        checkAccessibility()
        checkScreenRecording()
        checkXcode()
        checkDerivedData()
    }

    // MARK: - Accessibility

    func checkAccessibility() {
        accessibilityGranted = AXIsProcessTrusted()
    }

    func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    // MARK: - Screen Recording

    func checkScreenRecording() {
        screenRecordingGranted = CGPreflightScreenCaptureAccess()
    }

    func requestScreenRecording() {
        CGRequestScreenCaptureAccess()
    }

    func openScreenRecordingSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!
        NSWorkspace.shared.open(url)
    }

    /// Poll every 1s after user taps "Open System Settings" for Screen Recording.
    func startScreenRecordingPolling(onGranted: @escaping () -> Void) {
        screenRecordingPollTimer?.invalidate()
        screenRecordingPollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.checkScreenRecording()
            if self.screenRecordingGranted {
                self.screenRecordingPollTimer?.invalidate()
                self.screenRecordingPollTimer = nil
                onGranted()
            }
        }
    }

    func startAccessibilityPolling(onGranted: @escaping () -> Void) {
        // Poll every 1s for accessibility grant (timer stored to prevent leak)
        screenRecordingPollTimer?.invalidate()
        screenRecordingPollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self else { timer.invalidate(); return }
            self.checkAccessibility()
            if self.accessibilityGranted {
                timer.invalidate()
                onGranted()
            }
        }
    }

    // MARK: - Xcode

    func checkXcode() {
        xcodePath = XcodeDetector.activeXcodePath()
        xcodeDetected = xcodePath != nil
    }

    func selectXcodeManually() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.applicationBundle]
        panel.message = "Select Xcode Application"
        panel.directoryURL = URL(fileURLWithPath: "/Applications")

        if panel.runModal() == .OK, let url = panel.url {
            let path = url.path
            xcodePath = path
            xcodeDetected = true
            UserDefaults.standard.set(path, forKey: "xcodePath")
        }
    }

    // MARK: - DerivedData (Security-Scoped Bookmark)

    func checkDerivedData() {
        guard let data = UserDefaults.standard.data(forKey: "derivedDataBookmark") else { return }
        var stale = false
        if let url = try? URL(resolvingBookmarkData: data, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &stale) {
            if !stale {
                _ = url.startAccessingSecurityScopedResource()
                derivedDataURL = url
                derivedDataAccessGranted = true
            }
        }
    }

    func selectDerivedData() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.message = "Select Xcode DerivedData folder"
        panel.prompt = "Grant Access"
        panel.directoryURL = URL(fileURLWithPath: "\(NSHomeDirectory())/Library/Developer/Xcode/DerivedData")

        if panel.runModal() == .OK, let url = panel.url {
            if let bookmark = try? url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil) {
                UserDefaults.standard.set(bookmark, forKey: "derivedDataBookmark")
                derivedDataURL = url
                derivedDataAccessGranted = true
            }
        }
    }
}
