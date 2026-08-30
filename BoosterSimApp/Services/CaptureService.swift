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

    // MARK: - Published State

    @Published private(set) var permissionGranted = false
    /// TCC grants apply only after relaunch (Pitfall 2) — drives the quit-and-reopen prompt.
    @Published private(set) var needsRelaunch = false
    @Published private(set) var isCapturing = false
    @Published private(set) var lastError: String?
    @Published private(set) var lastSavedURL: URL?

    // Session capture options (plan 02-01 task 2 moves these onto AppSettings)
    @Published private(set) var selectedPreset: ASCFramePreset
    @Published private(set) var bezelMode: BezelMode
    @Published private(set) var background: CaptureBackground
    @Published private(set) var destination: CaptureDestination

    /// Options snapshot at capture start — mid-flight UI changes never tear a capture.
    private struct CapturePlan {
        let preset: ASCFramePreset
        let bezel: BezelMode
        let background: CaptureBackground
    }

    // MARK: - Private

    private let screenshotService: ScreenshotService
    private let thumbnailPanel: CaptureThumbnailPanel
    private let permissionManager: PermissionManager
    private let tracker: SimulatorWindowTracker

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
        selectedPreset = .iphone69x1320
        bezelMode = .simulatorNative
        background = .solid
        destination = .desktop
        refreshPermissionState()
    }

    // MARK: - Permission

    /// Re-preflights at launch — grants since last quit only apply now (Pitfall 2).
    func refreshPermissionState() {
        permissionManager.checkScreenRecording()
        permissionGranted = permissionManager.screenRecordingGranted
    }

    /// Opens System Settings and polls (1s); on grant, publish the quit-and-reopen hint.
    func requestPermission() {
        permissionManager.requestScreenRecording()
        permissionManager.openScreenRecordingSettings()
        permissionManager.startScreenRecordingPolling { [weak self] in
            self?.permissionGranted = true
            self?.needsRelaunch = true
        }
    }

    // MARK: - Options

    func selectPreset(_ preset: ASCFramePreset) { selectedPreset = preset }
    func selectBezel(_ mode: BezelMode) { bezelMode = mode }
    func selectBackground(_ fill: CaptureBackground) { background = fill }
    func selectDestination(_ destination: CaptureDestination) { self.destination = destination }

    // MARK: - Screenshot

    /// One-click capture; never throws at the UI — failures land in `lastError`.
    func takeScreenshot() {
        guard !isCapturing else { return }
        guard CGPreflightScreenCaptureAccess() else {
            permissionGranted = false
            lastError = nil
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

    // MARK: - Filename

    /// Sanitized timestamp-unique filename: "BoosterSim-" + device + "-" + preset + "-" + stamp + ".png".
    /// Allowlist is alphanumeric + hyphen; every other character collapses to a single
    /// hyphen (threat T-02-05 — device strings must never reach the path raw).
    static func captureFilename(device: String?, preset: ASCFramePreset, date: Date) -> String {
        let stamp = filenameDateFormatter.string(from: date)
        return "BoosterSim-\(sanitizedDevice(device))-\(preset.rawValue)-\(stamp).png"
    }

    private static let filenameDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    private static func sanitizedDevice(_ device: String?) -> String {
        var result = ""
        var lastWasSeparator = false
        for character in (device ?? "Simulator").lowercased() {
            let isAllowed = (character.isLetter || character.isNumber) && character.isASCII
            if isAllowed {
                result.append(character)
                lastWasSeparator = false
            } else if !lastWasSeparator {
                result.append("-")
                lastWasSeparator = true
            }
        }
        let trimmed = result.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return trimmed.isEmpty ? "simulator" : trimmed
    }

    private func performCapture(windowID: CGWindowID, windowFrame: CGRect,
                                plan: CapturePlan, deviceName: String?) async {
        defer { isCapturing = false }
        do {
            let raw = try await screenshotService.capture(windowID: windowID, windowFrame: windowFrame)
            let framed = CaptureCompositor.render(
                content: raw,
                preset: plan.preset,
                bezel: plan.bezel,
                background: plan.background,
                padding: CaptureCompositor.defaultPadding
            )
            guard let png = Self.pngData(from: framed) else {
                lastError = "Failed to encode PNG"
                return
            }
            let url = try saveToDesktop(png, deviceName: deviceName, preset: plan.preset)
            thumbnailPanel.show(url: url, anchorNear: windowFrame)
        } catch let error as ScreenshotService.CaptureError {
            lastError = Self.message(for: error)
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// Tracer destination: Desktop write with a timestamped name — second captures
    /// never touch the first (in-memory routing, no temp files).
    private func saveToDesktop(_ png: Data, deviceName: String?, preset: ASCFramePreset) throws -> URL {
        let url = CaptureDestination.defaultDesktopFolder()
            .appendingPathComponent(Self.captureFilename(device: deviceName, preset: preset, date: Date()))
        try png.write(to: url, options: .atomic)
        lastSavedURL = url
        AppLogger.capture.info("Saved capture (preset \(preset.rawValue, privacy: .public))")
        return url
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
