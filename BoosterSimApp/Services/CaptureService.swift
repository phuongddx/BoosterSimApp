// CaptureService.swift — Sync Combine facade over the async screenshot pipeline
import Foundation
import AppKit
import Combine
import CoreGraphics
import ImageIO
import OSLog
import UniformTypeIdentifiers

@MainActor
final class CaptureService: ObservableObject {

    // MARK: - Private

    private let screenshotService: ScreenshotService
    private let thumbnailPanel: CaptureThumbnailPanel
    private let permissionManager: PermissionManager
    private let tracker: SimulatorWindowTracker
    /// Persisted capture options; shares .standard with AppDelegate's instance.
    private let settings = AppSettings()

    /// Options snapshot at capture start — mid-flight UI changes never tear a capture.
    private struct CapturePlan {
        let preset: ASCFramePreset
        let bezel: BezelMode
        let background: CaptureBackground
    }

    // MARK: - Published State

    @Published private(set) var permissionGranted = false
    /// TCC grants apply only after relaunch (Pitfall 2) — drives the quit-and-reopen prompt.
    @Published private(set) var needsRelaunch = false
    @Published private(set) var isCapturing = false
    @Published private(set) var lastError: String?
    @Published private(set) var lastSavedURL: URL?

    // Option mirrors synced to AppSettings on every change (relaunch persistence)
    @Published var selectedPreset: ASCFramePreset { didSet { settings.captureASCFramePreset = selectedPreset } }
    @Published var bezelMode: BezelMode { didSet { settings.captureBezelMode = bezelMode } }
    @Published var background: CaptureBackground { didSet { settings.captureBackground = background } }
    @Published var destinationKind: CaptureDestinationKind { didSet { settings.captureDestination = destinationKind } }

    var customCaptureFolder: URL? { settings.customCaptureFolder }

    // MARK: - Lifecycle

    /// Production entry point with fresh dependencies (convenience-init precedent).
    convenience init(tracker: SimulatorWindowTracker = SimulatorWindowTracker()) {
        self.init(screenshotService: ScreenshotService(), thumbnailPanel: CaptureThumbnailPanel(),
                  permissionManager: PermissionManager(), tracker: tracker)
    }

    /// Injects every dependency; previews and tests construct each piece directly.
    init(screenshotService: ScreenshotService, thumbnailPanel: CaptureThumbnailPanel,
         permissionManager: PermissionManager, tracker: SimulatorWindowTracker) {
        self.screenshotService = screenshotService
        self.thumbnailPanel = thumbnailPanel
        self.permissionManager = permissionManager
        self.tracker = tracker
        selectedPreset = settings.captureASCFramePreset
        bezelMode = settings.captureBezelMode
        background = settings.captureBackground
        destinationKind = settings.captureDestination
        // Re-preflight: grants since last quit only apply now (Pitfall 2).
        permissionManager.checkScreenRecording()
        permissionGranted = permissionManager.screenRecordingGranted
    }

    // MARK: - Permission

    /// Opens System Settings and polls (1s); on grant, publish the quit-and-reopen hint.
    func requestPermission() {
        permissionManager.requestScreenRecording()
        permissionManager.openScreenRecordingSettings()
        permissionManager.startScreenRecordingPolling { [weak self] in
            self?.permissionGranted = true
            self?.needsRelaunch = true
        }
    }

    // MARK: - Screenshot

    /// One-click capture; never throws at the UI — failures land in `lastError`.
    func takeScreenshot() {
        guard !isCapturing else { return }
        guard CGPreflightScreenCaptureAccess() else {
            permissionGranted = false
            return
        }
        permissionGranted = true
        guard let simulator = tracker.activeSimulator, !simulator.isMinimized else {
            lastError = "No Simulator window is being tracked"
            return
        }
        isCapturing = true
        let plan = CapturePlan(preset: selectedPreset, bezel: bezelMode, background: background)
        let deviceName = simulator.deviceName
        Task { [weak self] in
            await self?.performCapture(windowID: simulator.id, windowFrame: simulator.frame,
                                       plan: plan, deviceName: deviceName)
        }
    }

    // MARK: - Capture Flow

    private func performCapture(windowID: CGWindowID, windowFrame: CGRect,
                                plan: CapturePlan, deviceName: String?) async {
        defer { isCapturing = false }
        do {
            let raw = try await screenshotService.capture(windowID: windowID, windowFrame: windowFrame)
            let framed = CaptureCompositor.render(content: raw, preset: plan.preset, bezel: plan.bezel,
                                                  background: plan.background,
                                                  padding: CaptureCompositor.defaultPadding)
            guard let png = Self.pngData(from: framed) else {
                lastError = "Failed to encode PNG"
                return
            }
            let filename = CaptureFilename.captureFilename(device: deviceName, preset: plan.preset, date: Date())
            route(pngData: png, filename: filename,
                  suggestedURL: CaptureDestination.defaultDesktopFolder().appendingPathComponent(filename),
                  anchor: windowFrame)
        } catch let error as ScreenshotService.CaptureError {
            lastError = Self.message(for: error)
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// Destination routing (in-memory PNG data, no temp files to clean up).
    private func route(pngData: Data, filename: String, suggestedURL: URL, anchor: CGRect) {
        switch resolvedDestination() {
        case .desktop:
            finishSave(url: suggestedURL, pngData: pngData, anchor: anchor)
        case .clipboard:
            // Clipboard receives captures only via this user-selected destination (T-02-03).
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setData(pngData, forType: .png)
            lastSavedURL = nil
        case .custom(let folder):
            presentSavePanel(directory: folder, filename: filename, pngData: pngData, anchor: anchor)
        case .ask:
            presentSavePanel(directory: nil, filename: filename, pngData: pngData, anchor: anchor)
        }
    }

    private func resolvedDestination() -> CaptureDestination {
        let folder = settings.customCaptureFolder ?? CaptureDestination.defaultDesktopFolder()
        switch settings.captureDestination {
        case .desktop: return .desktop
        case .clipboard: return .clipboard
        case .custom: return .custom(folder)
        case .ask: return .ask
        }
    }

    /// Non-modal save panel (begin + completion handler) with a pre-populated name field.
    private func presentSavePanel(directory: URL?, filename: String, pngData: Data, anchor: CGRect) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = filename
        panel.directoryURL = directory
        panel.begin { [weak self] response in
            guard let self, response == .OK, let url = panel.url else { return }
            if self.settings.captureDestination == .custom {
                self.settings.customCaptureFolder = url.deletingLastPathComponent()
            }
            self.finishSave(url: url, pngData: pngData, anchor: anchor)
        }
    }

    private func finishSave(url: URL, pngData: Data, anchor: CGRect) {
        do {
            try pngData.write(to: url, options: .atomic)
            lastSavedURL = url
            thumbnailPanel.show(url: url, anchorNear: anchor)
            AppLogger.capture.info("Saved capture")
        } catch {
            lastError = error.localizedDescription
        }
    }

    private static func pngData(from image: CGImage) -> Data? {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data, UTType.png.identifier as CFString, 1, nil
        ) else { return nil }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }

    private static func message(for error: ScreenshotService.CaptureError) -> String {
        switch error {
        case .windowNotFound: return "Simulator window not found — reopen it and retry"
        case .screenRecordingDenied: return "Screen Recording permission required"
        case .captureFailed(let reason): return "Capture failed: \(reason)"
        }
    }
}
