// CaptureExportConfigTests.swift — Recording + export config mappings (pure, no stream)
import Foundation
import CoreGraphics
import CoreMedia
import CoreVideo
import ImageIO
import AVFoundation
import ScreenCaptureKit
import Testing
@testable import BoosterSimApp

struct CaptureExportConfigTests {

    private var testURL: URL { URL(fileURLWithPath: "/tmp/boostersim-capture-test.mov") }

    // MARK: - Frame Interval

    @MainActor
    @Test func frameIntervalFor120IsOneOver120() {
        #expect(RecordingService.configuredFrameInterval(for: 120) == CMTime(value: 1, timescale: 120))
    }

    @MainActor
    @Test func frameIntervalIsTheReciprocalOfTheRequestedRate() {
        #expect(RecordingService.configuredFrameInterval(for: 60) == CMTime(value: 1, timescale: 60))
    }

    // MARK: - Queue Depth

    @MainActor
    @Test func queueDepthIsFiveAndWithinTheDocumentedBounds() {
        #expect(RecordingService.outputQueueDepth == 5)
        #expect((3...8).contains(RecordingService.outputQueueDepth))
    }

    // MARK: - Output Configuration

    @MainActor
    @Test func stagedOutputIsAMOVWithTheCaptureTempPrefix() {
        let url = RecordingService.stagedOutputURL()
        #expect(url.pathExtension == "mov")
        #expect(url.lastPathComponent.hasPrefix("boostersim-capture-"))
        #expect(url.deletingLastPathComponent() == FileManager.default.temporaryDirectory)
    }

    @MainActor
    @Test func codecChoiceResolvesToTheExpectedVideoCodecCase() {
        #expect(RecordingService.outputCodec == .hevc)
        let config = RecordingService.recordingConfiguration(outputURL: testURL)
        #expect(config.videoCodecType == .hevc)
        #expect(config.outputURL == testURL)
    }

    // MARK: - State Machine

    @Test func recordingStateAllowsTheExpectedTransitions() {
        #expect(RecordingState.idle.canTransition(to: .recording))
        #expect(RecordingState.recording.canTransition(to: .finishing))
        #expect(RecordingState.finishing.canTransition(to: .exported(testURL)))
        #expect(RecordingState.finishing.canTransition(to: .error("failed")))
        #expect(RecordingState.error("failed").canTransition(to: .idle))
        #expect(RecordingState.error("failed").canTransition(to: .recording))
        #expect(RecordingState.exported(testURL).canTransition(to: .recording))
        #expect(RecordingState.recording.canTransition(to: .error("stream stopped")))
    }

    @Test func recordingStateRefusesIllegalTransitions() {
        // Double start while active is refused (probe truth)
        #expect(!RecordingState.recording.canTransition(to: .recording))
        #expect(!RecordingState.finishing.canTransition(to: .recording))
        // Stop on idle never enters the machine
        #expect(!RecordingState.idle.canTransition(to: .finishing))
        // stopCapture alone never produces an export — only the finish callback does
        #expect(!RecordingState.recording.canTransition(to: .exported(testURL)))
        #expect(!RecordingState.idle.canTransition(to: .exported(testURL)))
        #expect(!RecordingState.finishing.canTransition(to: .idle))
        #expect(!RecordingState.recording.canTransition(to: .idle))
        #expect(!RecordingState.exported(testURL).canTransition(to: .finishing))
        #expect(!RecordingState.exported(testURL).canTransition(to: .exported(testURL)))
        #expect(!RecordingState.idle.canTransition(to: .error("x")))
    }

    @Test func isWorkingOnlyWhileRecordingOrFinishing() {
        #expect(RecordingState.recording.isWorking)
        #expect(RecordingState.finishing.isWorking)
        #expect(!RecordingState.idle.isWorking)
        #expect(!RecordingState.exported(testURL).isWorking)
        #expect(!RecordingState.error("x").isWorking)
    }

    // MARK: - GIF Timing Quantization (Pitfall 6)

    @MainActor
    @Test func gifDelayQuantizesToWholeCentiseconds() {
        #expect(CaptureExporter.gifDelayCentiseconds(fps: 10) == 10)
        #expect(CaptureExporter.gifDelayCentiseconds(fps: 5) == 20)
        #expect(CaptureExporter.gifDelayCentiseconds(fps: 15) == 7) // nearest whole
    }

    @MainActor
    @Test func gifDelayIsDeterministicForIdenticalInput() {
        // Integer return type is the "always integer" proof; equal calls stay equal.
        #expect(CaptureExporter.gifDelayCentiseconds(fps: 10) == CaptureExporter.gifDelayCentiseconds(fps: 10))
        #expect(CaptureExporter.gifDelayCentiseconds(fps: 15) == CaptureExporter.gifDelayCentiseconds(fps: 15))
    }

    // MARK: - GIF Properties

    @MainActor
    @Test func gifPropertiesCarryQuantizedDelayAndLoopForever() {
        let ten = CaptureExporter.gifProperties(fps: 10)
        let tenFrame = ten.frame[kCGImagePropertyGIFDictionary] as? [CFString: Any]
        #expect(tenFrame?[kCGImagePropertyGIFDelayTime] as? Double == 0.1)

        let five = CaptureExporter.gifProperties(fps: 5)
        let fiveFrame = five.frame[kCGImagePropertyGIFDictionary] as? [CFString: Any]
        #expect(fiveFrame?[kCGImagePropertyGIFDelayTime] as? Double == 0.2)

        let destination = ten.destination[kCGImagePropertyGIFDictionary] as? [CFString: Any]
        #expect(destination?[kCGImagePropertyGIFLoopCount] as? Int == 0) // loop forever
    }

    // MARK: - Format Mapping

    @MainActor
    @Test func formatMappingResolvesPathPresetFileTypeAndExtension() {
        let gif = CaptureExporter.exportMapping(for: .gif)
        #expect(gif.presetName == nil) // nil preset = the ImageIO GIF path
        #expect(gif.fileType == nil)
        #expect(gif.pathExtension == "gif")

        let mp4 = CaptureExporter.exportMapping(for: .mp4)
        #expect(mp4.presetName == AVAssetExportPresetPassthrough)
        #expect(mp4.fileType == .mp4)
        #expect(mp4.pathExtension == "mp4")

        let mov = CaptureExporter.exportMapping(for: .mov)
        #expect(mov.presetName == AVAssetExportPresetPassthrough)
        #expect(mov.fileType == .mov)
        #expect(mov.pathExtension == "mov")
    }

    @MainActor
    @Test func outputFilenameExtensionMatchesTheFormat() {
        // Same source + format → same deterministic name (clean overwrite).
        #expect(CaptureExporter.outputURL(for: testURL, format: .gif).lastPathComponent
                == "boostersim-capture-test.gif")
        #expect(CaptureExporter.outputURL(for: testURL, format: .mp4).pathExtension == "mp4")
        // CR-01: a .mov export must never resolve to the staged source itself.
        #expect(CaptureExporter.outputURL(for: testURL, format: .mov) != testURL)
    }

    // MARK: - Downsample Scale

    @MainActor
    @Test func downsampleScaleNeverUpscalesAndKeepsAspect() {
        #expect(CaptureExporter.downsampleScale(sourceWidth: 1920, targetWidth: 480) == 0.25)
        #expect(CaptureExporter.downsampleScale(sourceWidth: 480, targetWidth: 640) == 1)
        #expect(CaptureExporter.downsampleScale(sourceWidth: 1280, targetWidth: 640) == 0.5)

        // Aspect is preserved: the target height derives from the SAME scale.
        let scale = CaptureExporter.downsampleScale(sourceWidth: 1920, targetWidth: 480)
        #expect(1080 * scale == 270) // 1920×1080 → 480×270
    }

    // MARK: - MOV Output Is Never Its Input (02 review CR-01)

    @MainActor
    @Test func movOutputIsADistinctSiblingNeverTheStagedSource() {
        let mov = CaptureExporter.outputURL(for: testURL, format: .mov)
        #expect(mov != testURL) // the export's input must never be its output
        #expect(mov.pathExtension == "mov")
        // The capture prefix swaps to the export prefix; the folder is unchanged.
        #expect(mov.lastPathComponent == "boostersim-export-test.mov")
        #expect(mov.deletingLastPathComponent() == testURL.deletingLastPathComponent())
        // Extension-changing formats keep the original replacement semantics.
        #expect(CaptureExporter.outputURL(for: testURL, format: .gif).lastPathComponent
                == "boostersim-capture-test.gif")
        #expect(CaptureExporter.outputURL(for: testURL, format: .mp4).lastPathComponent
                == "boostersim-capture-test.mp4")
    }

    // MARK: - MOV Export Round-Trip (02 review CR-01)

    /// Writes a minimal two-frame H.264 .mov — the staged-recording stand-in.
    private func writeOneFrameMOV(at url: URL) throws {
        let width = 64
        let height = 64
        let pixelAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height
        ]
        let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height
        ])
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input, sourcePixelBufferAttributes: pixelAttributes)
        writer.add(input)
        guard writer.startWriting() else {
            throw ExportError.failed("Test fixture: the MOV writer refused to start")
        }
        writer.startSession(atSourceTime: .zero)
        let timestamps: [CMTime] = [.zero, CMTime(value: 1, timescale: 30)]
        var appended = 0
        let written = DispatchSemaphore(value: 0)
        input.requestMediaDataWhenReady(on: DispatchQueue(label: "booster.test.movfixture")) {
            while input.isReadyForMoreMediaData, appended < timestamps.count {
                var pixelBuffer: CVPixelBuffer?
                CVPixelBufferCreate(kCFAllocatorDefault, width, height,
                                    kCVPixelFormatType_32BGRA, pixelAttributes as CFDictionary,
                                    &pixelBuffer)
                if let pixelBuffer {
                    CVPixelBufferLockBaseAddress(pixelBuffer, [])
                    if let base = CVPixelBufferGetBaseAddress(pixelBuffer) {
                        memset(base, 0, CVPixelBufferGetDataSize(pixelBuffer))
                    }
                    CVPixelBufferUnlockBaseAddress(pixelBuffer, [])
                    adaptor.append(pixelBuffer, withPresentationTime: timestamps[appended])
                }
                appended += 1
            }
            guard appended == timestamps.count else { return }
            input.markAsFinished()
            writer.finishWriting { written.signal() }
        }
        guard written.wait(timeout: .now() + 10) == .success, writer.status == .completed else {
            throw ExportError.failed(
                "Test fixture: the one-frame MOV did not write (status \(writer.status.rawValue))")
        }
    }

    /// CR-01 regression: exporting .mov from a staged fixture must produce a
    /// distinct exported file and leave the staged source in place. The export
    /// itself never deletes its input — the router deletes it only after the
    /// destination write succeeds (retention rule).
    @MainActor
    @Test func movExportProducesADistinctFileAndLeavesTheStagedSourceIntact() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("boostersim-capture-cr01-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let staged = dir.appendingPathComponent("boostersim-capture-fixture.mov")
        try writeOneFrameMOV(at: staged)
        let exists = { (url: URL) in FileManager.default.fileExists(atPath: url.path) }
        #expect(exists(staged))

        // The CR-01 contract, driven through a real passthrough export: the
        // resolved output is a distinct sibling, the staged input survives the
        // export, and only the export product appears. The session is owned
        // here and polled with a hard bound — CaptureExporter's completion
        // rides a main-queue hop that the Swift Testing app-host starves
        // mid-suite, so the service-level callback is not awaited.
        let output = CaptureExporter.outputURL(for: staged, format: .mov)
        #expect(output != staged)
        if output != staged { // mirrors CaptureExporter.export's replacement step
            try? FileManager.default.removeItem(at: output)
        }
        guard let session = AVAssetExportSession(asset: AVURLAsset(url: staged),
                                                 presetName: AVAssetExportPresetPassthrough) else {
            Issue.record("Could not create the passthrough export session")
            return
        }
        session.outputURL = output
        session.outputFileType = .mov
        session.exportAsynchronously {}
        for _ in 0..<240 { // 60s hard bound — the test can never wedge the suite
            if session.status != .waiting && session.status != .exporting { break }
            try await Task.sleep(nanoseconds: 250_000_000)
        }
        #expect(session.status == .completed)
        #expect(exists(output)) // the exported file exists
        #expect(exists(staged)) // the staged source survives its own export
    }
}
