// CaptureExportConfigTests.swift — Recording config + state-machine mappings (pure, no stream)
import Foundation
import CoreMedia
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
}
