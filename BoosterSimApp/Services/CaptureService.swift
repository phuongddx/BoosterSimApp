// CaptureService.swift — Sync Combine facade over the screenshot + recording pipelines
import Foundation
import AppKit
import Combine
import CoreGraphics
import OSLog

@MainActor
final class CaptureService: ObservableObject {

    // MARK: - Private

    private let screenshotService: ScreenshotService
    private let thumbnailPanel: CaptureThumbnailPanel
    private let permissionManager: PermissionManager
    private let tracker: SimulatorWindowTracker
    /// Persisted capture options; shares .standard with AppDelegate's instance.
    private let settings = AppSettings()
    private var cancellables = Set<AnyCancellable>()

    /// Destination routing + save-panel flow (plan 03's export reuses this).
    private lazy var saveRouter = CaptureSaveRouter(
        settings: settings, thumbnailPanel: thumbnailPanel,
        onSaved: { [weak self] url in self?.lastSavedURL = url },
        onError: { [weak self] message in self?.lastError = message }
    )

    /// Options snapshot at capture start — mid-flight UI changes never tear a capture.
    private struct CapturePlan {
        let preset: ASCFramePreset
        let bezel: BezelMode
        let background: CaptureBackground
    }

    // MARK: - Recording

    let recordingService = RecordingService()
    let touchIndicatorController = TouchIndicatorController()
    let exporter = CaptureExporter()

    // MARK: - Published State

    @Published private(set) var permissionGranted = false
    /// TCC grants apply only after relaunch (Pitfall 2) — drives the quit-and-reopen prompt.
    @Published private(set) var needsRelaunch = false
    @Published private(set) var isCapturing = false
    @Published private(set) var lastError: String?
    @Published private(set) var lastSavedURL: URL?
    /// Staged .mov from the last finished recording — drives export (plan 03) + reveal.
    @Published private(set) var stagedRecordingURL: URL?
    /// Simulator-relaunch hint (A6) or the degrade notice when enabling failed.
    @Published private(set) var touchIndicatorHint: String?

    // Option mirrors synced to AppSettings on every change (relaunch persistence)
    @Published var selectedPreset: ASCFramePreset { didSet { settings.captureASCFramePreset = selectedPreset } }
    @Published var bezelMode: BezelMode { didSet { settings.captureBezelMode = bezelMode } }
    @Published var background: CaptureBackground { didSet { settings.captureBackground = background } }
    @Published var destinationKind: CaptureDestinationKind { didSet { settings.captureDestination = destinationKind } }
    @Published var exportFormat: CaptureExportFormat { didSet { settings.captureExportFormat = exportFormat } }
    @Published var gifSize: Int { didSet { settings.captureGIFSize = gifSize } }
    @Published var gifFPS: Int { didSet { settings.captureGIFFps = gifFPS } }
    @Published var showTouchIndicators: Bool {
        didSet {
            settings.captureShowTouchIndicators = showTouchIndicators
            touchIndicatorHint = showTouchIndicators
                ? "Relaunch Simulator for touch indicators to appear in recordings" : nil
        }
    }

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
        exportFormat = settings.captureExportFormat
        gifSize = settings.captureGIFSize
        gifFPS = settings.captureGIFFps
        destinationKind = settings.captureDestination
        showTouchIndicators = settings.captureShowTouchIndicators
        // Re-preflight: grants since last quit only apply now (Pitfall 2).
        permissionManager.checkScreenRecording()
        permissionGranted = permissionManager.screenRecordingGranted
        recordingService.$state.sink { [weak self] state in
            guard let self else { return }
            if case .recording = state { self.stagedRecordingURL = nil }
            if case .exported(let url) = state {
                self.stagedRecordingURL = url
                self.touchIndicatorController.restore() // every exit path (T-02-02)
            }
            if case .error(let message) = state {
                self.lastError = message
                self.touchIndicatorController.restore() // every exit path (T-02-02)
            }
        }.store(in: &cancellables)
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
        guard !isCapturing, !recordingService.state.isWorking else { return }
        guard let target = captureTarget() else { return }
        isCapturing = true
        let plan = CapturePlan(preset: selectedPreset, bezel: bezelMode, background: background)
        Task { [weak self] in
            await self?.performCapture(windowID: target.windowID, windowFrame: target.frame,
                                       plan: plan, deviceName: target.deviceName)
        }
    }

    // MARK: - Recording

    /// Single active capture at a time: the recording state machine refuses a
    /// start while recording/finishing; the screenshot guard covers the rest.
    func startRecording() {
        guard !isCapturing, !recordingService.state.isWorking else { return }
        guard let target = captureTarget() else { return }
        // Indicators BEFORE the stream starts; enable failure degrades to
        // recording-without-indicators (never blocks the recording).
        if showTouchIndicators {
            touchIndicatorController.enable()
            if case .error = touchIndicatorController.state {
                touchIndicatorHint = "Touch indicators unavailable — recording without them"
            } else {
                touchIndicatorHint = "Relaunch Simulator for touch indicators to appear in recordings"
            }
        }
        recordingService.start(windowID: target.windowID, frame: target.frame)
    }

    /// Stop is a no-op while idle (state machine guard); finalization waits
    /// for the recording-output finish callback (Pitfall 9).
    func stopRecording() {
        recordingService.stop()
        touchIndicatorController.restore() // every exit path (T-02-02)
    }

    // MARK: - Export

    /// Exports the staged recording in the chosen format. Routing failures and
    /// cancellations leave the staged file intact for retry; the staged file is
    /// deleted only after the destination write succeeds (retention rule).
    func exportRecording(as format: CaptureExportFormat) {
        guard let staged = stagedRecordingURL, !exporter.exportState.isWorking else { return }
        exporter.export(source: staged, format: format,
                        gifWidth: gifSize, gifFPS: gifFPS) { [weak self] result in
            self?.handleExportResult(result, staged: staged)
        }
    }

    func cancelExport() {
        exporter.cancel()
    }

    private func handleExportResult(_ result: Result<URL, ExportError>, staged: URL) {
        switch result {
        case .success(let output):
            saveRouter.route(fileAt: output, anchor: tracker.activeSimulator?.frame ?? .zero) { [weak self] in
                self?.deleteStagedRecording(at: staged)
            }
        case .failure(let error):
            if case .cancelled = error {} else { lastError = error.userMessage }
        }
    }

    /// Lifecycle close: the staged temp recording dies after the durable write.
    private func deleteStagedRecording(at url: URL) {
        try? FileManager.default.removeItem(at: url)
        if stagedRecordingURL == url { stagedRecordingURL = nil }
    }

    // MARK: - Capture Flow

    /// Shared session entry: TCC preflight + tracked-window resolution.
    private func captureTarget() -> (windowID: CGWindowID, frame: CGRect, deviceName: String?)? {
        guard CGPreflightScreenCaptureAccess() else {
            permissionGranted = false
            return nil
        }
        permissionGranted = true
        guard let simulator = tracker.activeSimulator, !simulator.isMinimized else {
            lastError = "No Simulator window is being tracked"
            return nil
        }
        return (simulator.id, simulator.frame, simulator.deviceName)
    }

    private func performCapture(windowID: CGWindowID, windowFrame: CGRect,
                                plan: CapturePlan, deviceName: String?) async {
        defer { isCapturing = false }
        do {
            let raw = try await screenshotService.capture(windowID: windowID, windowFrame: windowFrame)
            let framed = CaptureCompositor.render(content: raw, preset: plan.preset, bezel: plan.bezel,
                                                  background: plan.background,
                                                  padding: CaptureCompositor.defaultPadding)
            guard let png = ScreenshotService.pngData(from: framed) else {
                lastError = "Failed to encode PNG"
                return
            }
            let filename = CaptureFilename.captureFilename(device: deviceName, preset: plan.preset, date: Date())
            saveRouter.route(pngData: png, filename: filename,
                             suggestedURL: CaptureDestination.defaultDesktopFolder().appendingPathComponent(filename),
                             anchor: windowFrame)
        } catch let error as ScreenshotService.CaptureError {
            lastError = error.userMessage
        } catch {
            lastError = error.localizedDescription
        }
    }
}
