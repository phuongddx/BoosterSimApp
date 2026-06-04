// CaptureService.swift — Screen recording and capture for Simulator
import Foundation
import AppKit
import AVFoundation
import ScreenCaptureKit
import Combine

final class CaptureService: ObservableObject {

    // MARK: - Published State

    @Published var isRecording = false
    @Published var recordingDuration: TimeInterval = 0
    @Published var outputFileURL: URL?
    @Published var exportFormat: ExportFormat = .mp4
    @Published var quality: CaptureQuality = .medium
    @Published var showTouchIndicators = true
    @Published var selectedBezel: DeviceBezel = .none
    @Published var lastError: String?

    // MARK: - Types

    enum ExportFormat: String, CaseIterable {
        case mp4 = "MP4"
        case gif = "GIF"
    }

    enum CaptureQuality: String, CaseIterable {
        case low = "Low (320px)"
        case medium = "Medium (480px)"
        case high = "High (640px)"

        var fps: Int {
            switch self {
            case .low: return 8
            case .medium: return 12
            case .high: return 15
            }
        }

        var width: Int {
            switch self {
            case .low: return 320
            case .medium: return 480
            case .high: return 640
            }
        }
    }

    enum DeviceBezel: String, CaseIterable {
        case none = "None"
        case iPhone15 = "iPhone 15"
        case iPhone15Pro = "iPhone 15 Pro"
        case iPadPro = "iPad Pro"
    }

    // MARK: - Private

    private var stream: SCStream?
    private var streamOutput: CaptureStreamOutput?
    private var recordingStartTime: Date?
    private var timer: Timer?
    private var capturedFrames: [CMSampleBuffer] = []
    private var touchPoints: [TouchPoint] = []

    struct TouchPoint {
        let position: CGPoint
        let timestamp: Date
    }

    // MARK: - Public API

    func startRecording() async {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            guard let display = content.displays.first else {
                lastError = "No display found"
                return
            }

            let filter = SCContentFilter(display: display, excludingApplications: [], exceptingWindows: [])
            let config = SCStreamConfiguration()
            config.width = display.width * 2
            config.height = display.height * 2
            config.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(quality.fps))
            config.capturesAudio = false

            streamOutput = CaptureStreamOutput(onFrame: { [weak self] frame in
                self?.capturedFrames.append(frame)
            })

            stream = SCStream(filter: filter, configuration: config, delegate: nil)
            try stream?.addStreamOutput(streamOutput!, type: .screen, sampleHandlerQueue: .main)
            try await stream?.startCapture()

            await MainActor.run {
                isRecording = true
                recordingStartTime = Date()
                capturedFrames.removeAll()
                touchPoints.removeAll()
                startTimer()
            }
        } catch {
            await MainActor.run {
                lastError = error.localizedDescription
            }
        }
    }

    func stopRecording() async {
        do {
            try await stream?.stopCapture()
            stream = nil
            streamOutput = nil

            await MainActor.run {
                isRecording = false
                stopTimer()
                Task {
                    await exportCapture()
                }
            }
        } catch {
            await MainActor.run {
                lastError = error.localizedDescription
            }
        }
    }

    func addTouchPoint(at position: CGPoint) {
        guard isRecording && showTouchIndicators else { return }
        let point = TouchPoint(position: position, timestamp: Date())
        touchPoints.append(point)
    }

    func saveToFile() {
        guard let url = outputFileURL else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = exportFormat == .gif ? [.gif] : [.movie]
        panel.nameFieldStringValue = "BoosterSim-Capture.\(exportFormat == .gif ? "gif" : "mp4")"

        if panel.runModal() == .OK, let saveURL = panel.url {
            do {
                try FileManager.default.copyItem(at: url, to: saveURL)
            } catch {
                lastError = error.localizedDescription
            }
        }
    }

    // MARK: - Private

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self, let start = self.recordingStartTime else { return }
            self.recordingDuration = Date().timeIntervalSince(start)
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func exportCapture() async {
        guard !capturedFrames.isEmpty else {
            lastError = "No frames captured"
            return
        }

        if exportFormat == .gif {
            await exportAsGIF()
        } else {
            await exportAsMP4()
        }
    }

    private func exportAsMP4() async {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("boostersim-capture-\(UUID().uuidString).mp4")

        do {
            guard let firstFrame = capturedFrames.first,
                  let formatDesc = CMSampleBufferGetFormatDescription(firstFrame),
                  let dimensions = CMVideoFormatDescriptionGetDimensions(formatDesc) else {
                lastError = "Invalid frame format"
                return
            }

            let writer = try AVAssetWriter(url: tempURL, fileType: .mp4)
            let settings: [String: Any] = [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: dimensions.width,
                AVVideoHeightKey: dimensions.height
            ]
            let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
            let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: nil)

            writer.add(input)
            writer.startWriting()
            writer.startSession(atTime: .zero)

            for (index, frame) in capturedFrames.enumerated() {
                if let buffer = CMSampleBufferGetImageBuffer(frame) {
                    let time = CMTime(value: CMTimeValue(index), timescale: CMTimeScale(quality.fps))
                    while !input.isReadyForMoreMediaData {
                        try await Task.sleep(nanoseconds: 10_000_000)
                    }
                    adaptor.append(buffer, withPresentationTime: time)
                }
            }

            input.markAsFinished()
            await writer.finishWriting()

            await MainActor.run {
                outputFileURL = tempURL
            }
        } catch {
            await MainActor.run {
                lastError = error.localizedDescription
            }
        }
    }

    private func exportAsGIF() async {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("boostersim-capture-\(UUID().uuidString).gif")

        guard let destination = CGImageDestinationCreateWithURL(tempURL as CFURL, "com.compuserve.gif" as CFTypeRef, capturedFrames.count, nil) else {
            lastError = "Failed to create GIF destination"
            return
        }

        let frameProperties = [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: 1.0 / Double(quality.fps)]] as CFDictionary

        for frame in capturedFrames {
            if let buffer = CMSampleBufferGetImageBuffer(frame) {
                let ciImage = CIImage(cvPixelBuffer: buffer)
                let context = CIContext()
                if let cgImage = context.createCGImage(ciImage, from: ciImage.extent) {
                    CGImageDestinationAddImage(destination, cgImage, frameProperties)
                }
            }
        }

        let gifProperties = [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary
        CGImageDestinationSetProperties(destination, gifProperties)

        if CGImageDestinationFinalize(destination) {
            await MainActor.run {
                outputFileURL = tempURL
            }
        } else {
            await MainActor.run {
                lastError = "Failed to finalize GIF"
            }
        }
    }
}

// MARK: - Stream Output

private class CaptureStreamOutput: NSObject, SCStreamOutput {
    let onFrame: (CMSampleBuffer) -> Void

    init(onFrame: @escaping (CMSampleBuffer) -> Void) {
        self.onFrame = onFrame
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen else { return }
        onFrame(sampleBuffer)
    }
}
