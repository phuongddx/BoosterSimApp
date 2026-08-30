// RecordingService.swift — SCStream + SCRecordingOutput recording straight to disk
// Async internals live here and in capture services only (CONVENTIONS exception).
import Foundation
import Combine
import CoreGraphics
import CoreMedia
import AVFoundation
import ScreenCaptureKit
import OSLog

@MainActor
final class RecordingService: ObservableObject {

    // MARK: - Properties

    /// Configured frame-rate ceiling — delivered frames are bounded by the
    /// host display refresh (Pitfall 5); the UI must present "up to".
    static let frameRate = 120
    /// Apple sample guidance: default 3, never above 8.
    static let outputQueueDepth = 5
    /// Hardware codec SCRecordingOutput writes (.mov container, research A2).
    static let outputCodec: AVVideoCodecType = .hevc

    @Published private(set) var state: RecordingState = .idle
    @Published private(set) var elapsed: TimeInterval = 0
    @Published private(set) var outputBytes: Int64 = 0

    private var stream: SCStream?
    private var recordingOutput: SCRecordingOutput?
    private var stagedURL: URL?
    private var startedAt: Date?
    private var statsTimer: Timer?
    private lazy var streamDelegate = StreamDelegate(owner: self)
    private lazy var recordingOutputDelegate = RecordingOutputDelegate(owner: self)

    // MARK: - Pure Configuration

    /// `minimumFrameInterval` is the reciprocal of the maximum frame rate.
    static func configuredFrameInterval(for fps: Int) -> CMTime {
        CMTime(value: 1, timescale: CMTimeScale(fps))
    }

    /// Staged recording target — temp folder, sweepable prefix (plan 03).
    static func stagedOutputURL(date: Date = Date()) -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("boostersim-capture-\(CaptureFilename.stamp(date)).mov")
    }

    static func recordingConfiguration(outputURL: URL) -> SCRecordingOutputConfiguration {
        let config = SCRecordingOutputConfiguration()
        config.outputURL = outputURL
        config.videoCodecType = outputCodec
        return config
    }

    // MARK: - Recording

    /// Starts recording the tracked window; refused while a recording is
    /// already active or finalizing (the state machine is the guard).
    func start(windowID: CGWindowID, frame: CGRect) {
        guard state.canTransition(to: .recording) else { return }
        transition(to: .recording)
        let url = Self.stagedOutputURL()
        stagedURL = url
        startStatsUpdates()
        Task { [weak self] in
            await self?.startStream(windowID: windowID, frame: frame, outputURL: url)
        }
    }

    /// Stops the capture. The file is NOT ready when this returns — only the
    /// recording-output finish callback finalizes it (Pitfall 9).
    func stop() {
        guard state.canTransition(to: .finishing) else { return } // no-op when idle
        transition(to: .finishing)
        Task { [weak self] in
            await self?.stopStream()
        }
    }

    // MARK: - Stream Lifecycle

    private func startStream(windowID: CGWindowID, frame: CGRect, outputURL: URL) async {
        guard CGPreflightScreenCaptureAccess() else {
            fail("Screen Recording permission required")
            return
        }
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            guard let window = content.windows.first(where: { $0.windowID == windowID }) else {
                fail("Simulator window not found — reopen it and retry")
                return
            }
            // Pitfall 1 self-capture guard: the matched window must be Simulator's.
            assert(window.owningApplication?.bundleIdentifier == "com.apple.iphonesimulator",
                   "Recording matched a window that does not belong to Simulator")
            let filter = SCContentFilter(desktopIndependentWindow: window)
            let config = SCStreamConfiguration()
            config.width = Int(frame.width) * 2
            config.height = Int(frame.height) * 2
            config.scalesToFit = false
            config.showsCursor = false
            config.ignoreShadowsSingleWindow = true
            config.captureResolution = .best
            config.minimumFrameInterval = Self.configuredFrameInterval(for: Self.frameRate)
            config.queueDepth = Self.outputQueueDepth
            config.capturesAudio = false
            let output = SCRecordingOutput(configuration: Self.recordingConfiguration(outputURL: outputURL),
                                           delegate: recordingOutputDelegate)
            let stream = SCStream(filter: filter, configuration: config, delegate: streamDelegate)
            // macOS 15 attachment API — the output owns its handler queue internally.
            try stream.addRecordingOutput(output)
            try await stream.startCapture()
            self.stream = stream
            self.recordingOutput = output
            AppLogger.capture.info("[RecordingService] recording started")
        } catch {
            fail(error.localizedDescription)
        }
    }

    private func stopStream() async {
        do {
            try await stream?.stopCapture()
            // Finalization is asynchronous: the finish callback owns the
            // .finishing → .exported/.error transition (Pitfall 9).
        } catch {
            handleStreamError(error.localizedDescription)
        }
    }

    // MARK: - Callbacks (main-actor hops from the delegate wrappers)

    func handleRecordingFinished(successfully: Bool, errorDescription: String?) {
        guard case .finishing = state else { return } // late/duplicate callbacks ignored
        teardownStream()
        guard successfully, let url = stagedURL else {
            transition(to: .error(errorDescription ?? "Recording failed to finalize"))
            return
        }
        Task { [weak self] in
            await self?.finalizeIfPlayable(url: url)
        }
    }

    func handleStreamError(_ message: String) {
        guard state.isWorking else { return }
        teardownStream()
        transition(to: .error(message))
    }

    /// Duration-is-positive gate — reached only from the finish callback.
    private func finalizeIfPlayable(url: URL) async {
        let asset = AVURLAsset(url: url)
        do {
            let duration = try await asset.load(.duration)
            guard duration.seconds > 0 else {
                transition(to: .error("Recorded file is empty"))
                return
            }
            transition(to: .exported(url))
            AppLogger.capture.info("[RecordingService] recording finalized")
        } catch {
            transition(to: .error("Recorded file is not readable"))
        }
    }

    private func fail(_ message: String) {
        teardownStream()
        transition(to: .error(message))
    }

    // MARK: - Live Stats

    private func startStatsUpdates() {
        elapsed = 0
        outputBytes = 0
        startedAt = Date()
        statsTimer?.invalidate()
        statsTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.state.isWorking, let startedAt = self.startedAt else { return }
                self.elapsed = Date().timeIntervalSince(startedAt)
                self.outputBytes = Int64(self.recordingOutput?.recordedFileSize ?? 0)
            }
        }
    }

    private func teardownStream() {
        stream = nil
        recordingOutput = nil
        statsTimer?.invalidate()
        statsTimer = nil
        startedAt = nil
    }

    // MARK: - State Machine

    private func transition(to next: RecordingState) {
        if state != next, !state.canTransition(to: next) {
            assertionFailure("Illegal recording transition: \(state) -> \(next)")
        }
        state = next
    }
}

// MARK: - Delegate Wrappers

/// Non-isolated NSObject wrappers: SCK callbacks arrive on the sample-handler
/// queue and hop to the main actor before touching published state (Pitfall 8).
private final class StreamDelegate: NSObject, SCStreamDelegate {
    weak var owner: RecordingService?

    init(owner: RecordingService) {
        self.owner = owner
    }

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        Task { @MainActor [weak self] in
            self?.owner?.handleStreamError(error.localizedDescription)
        }
    }
}

private final class RecordingOutputDelegate: NSObject, SCRecordingOutputDelegate {
    weak var owner: RecordingService?

    init(owner: RecordingService) {
        self.owner = owner
    }

    func recordingOutput(_ output: SCRecordingOutput, didFinishSuccessfully success: Bool, error: Error?) {
        Task { @MainActor [weak self] in
            self?.owner?.handleRecordingFinished(successfully: success,
                                                 errorDescription: error?.localizedDescription)
        }
    }
}
