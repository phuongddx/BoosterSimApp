// CaptureExportConfigTests.swift — Recording + export config mappings (pure, no stream)
import Foundation
import CoreGraphics
import CoreMedia
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
        #expect(CaptureExporter.outputURL(for: testURL, format: .mov).pathExtension == "mov")
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
}
