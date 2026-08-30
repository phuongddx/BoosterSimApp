// CaptureExporter.swift — GIF (ImageIO) + MP4/MOV (AVAssetExportSession) export of staged recordings
// DispatchQueue + Combine only: the async-bridge exception covers the capture services, not this unit.
import Foundation
import Combine
import CoreGraphics
import CoreImage
import CoreMedia
import ImageIO
import AVFoundation
import os
import OSLog

// MARK: - Exporter

@MainActor
final class CaptureExporter: ObservableObject {

    // MARK: - Properties

    @Published private(set) var exportState = ExportState.idle

    /// Resolved output characteristics (nil preset = the ImageIO GIF path).
    struct ExportMapping: Equatable {
        let presetName: String?
        let fileType: AVFileType?
        let pathExtension: String
    }

    /// Lock-guarded cancel flag shared with the worker queue.
    private var activeCancellation: OSAllocatedUnfairLock<Bool>?
    private var activeSession: AVAssetExportSession?
    private var progressTimer: Timer?

    // MARK: - Pure Configuration (tested surface)

    /// GIF delays are integer centiseconds (Pitfall 6): 10 fps → 10, 5 fps → 20,
    /// anything else rounds to the nearest whole centisecond — never alternating.
    nonisolated static func gifDelayCentiseconds(fps: Int) -> Int {
        max(1, Int((100.0 / Double(max(1, fps))).rounded()))
    }

    /// Per-frame delay dictionary + loop-forever destination dictionary.
    nonisolated static func gifProperties(fps: Int)
        -> (frame: [CFString: Any], destination: [CFString: Any]) {
        let delay = Double(gifDelayCentiseconds(fps: fps)) / 100
        return (
            [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: delay]],
            [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]]
        )
    }

    nonisolated static func exportMapping(for format: CaptureExportFormat) -> ExportMapping {
        switch format {
        case .gif:
            return ExportMapping(presetName: nil, fileType: nil, pathExtension: "gif")
        case .mp4:
            return ExportMapping(presetName: AVAssetExportPresetPassthrough,
                                 fileType: .mp4, pathExtension: "mp4")
        case .mov:
            return ExportMapping(presetName: AVAssetExportPresetPassthrough,
                                 fileType: .mov, pathExtension: "mov")
        }
    }

    /// Deterministic output: same source + format → same path → clean overwrite.
    /// Same-extension exports (staged .mov → MOV) rename into a sibling export
    /// file instead — the staged file is the export's INPUT and must never
    /// resolve to the output path (02 review CR-01).
    nonisolated static func outputURL(for source: URL, format: CaptureExportFormat) -> URL {
        let ext = exportMapping(for: format).pathExtension
        let stem = source.deletingPathExtension().lastPathComponent
        guard ext == source.pathExtension else {
            return source.deletingPathExtension().appendingPathExtension(ext)
        }
        // "boostersim-capture-<stamp>.mov" → "boostersim-export-<stamp>.mov".
        let exportStem = stem.hasPrefix("boostersim-capture-")
            ? String(stem.dropFirst("boostersim-capture-".count))
            : stem
        return source.deletingLastPathComponent()
            .appendingPathComponent("boostersim-export-\(exportStem).\(ext)")
    }

    /// Uniform downsample scale — never upscales; one scale keeps the aspect.
    nonisolated static func downsampleScale(sourceWidth: Int, targetWidth: Int) -> CGFloat {
        guard sourceWidth > 0, targetWidth > 0 else { return 1 }
        return min(1, CGFloat(targetWidth) / CGFloat(sourceWidth))
    }

    // MARK: - Export

    /// Exports the staged recording. Heavy work runs on a user-initiated global
    /// queue (SimCtlService pattern); state publishes from the main thread only.
    func export(source: URL, format: CaptureExportFormat, gifWidth: Int, gifFPS: Int,
                completion: @escaping (Result<URL, ExportError>) -> Void) {
        guard !exportState.isWorking else { return }
        let output = Self.outputURL(for: source, format: format)
        if output != source { // belt and braces: the staged input is never the output (CR-01)
            try? FileManager.default.removeItem(at: output) // deterministic replacement (T-02-07)
        }
        let cancellation = OSAllocatedUnfairLock(initialState: false)
        activeCancellation = cancellation
        exportState = .running(progress: 0)

        let mapping = Self.exportMapping(for: format)
        if mapping.presetName == nil {
            runGIFExport(source: source, output: output, gifWidth: gifWidth, gifFPS: gifFPS,
                         cancellation: cancellation, completion: completion)
        } else {
            runVideoExport(source: source, output: output, format: format,
                           mapping: mapping, completion: completion)
        }
    }

    /// Requests cancellation. Partial output is deleted; the staged source survives.
    func cancel() {
        activeCancellation?.withLock { $0 = true }
        activeSession?.cancelExport()
    }

    // MARK: - GIF Path (ImageIO)

    private func runGIFExport(source: URL, output: URL, gifWidth: Int, gifFPS: Int,
                              cancellation: OSAllocatedUnfairLock<Bool>,
                              completion: @escaping (Result<URL, ExportError>) -> Void) {
        let properties = Self.gifProperties(fps: gifFPS)
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = Result {
                try CaptureExporter.performGIFExport(
                    source: source, output: output, targetWidth: gifWidth, fps: gifFPS,
                    properties: properties,
                    isCancelled: { cancellation.withLock { $0 } },
                    onProgress: { progress in
                        DispatchQueue.main.async { self?.publish(progress: progress) }
                    }
                )
            }.mapError { $0 as? ExportError ?? ExportError.failed($0.localizedDescription) }
            DispatchQueue.main.async { [weak self] in
                self?.finish(result: result.map { output }, output: output, completion: completion)
            }
        }
    }

    /// AVAssetReader decode → decimation to the requested fps → ImageIO GIF
    /// destination. One CIContext per export, hoisted before the frame loop.
    nonisolated private static func performGIFExport(
        source: URL, output: URL, targetWidth: Int, fps: Int,
        properties: (frame: [CFString: Any], destination: [CFString: Any]),
        isCancelled: () -> Bool, onProgress: (Double) -> Void
    ) throws {
        let asset = AVURLAsset(url: source)
        let reader = try AVAssetReader(asset: asset)
        guard let track = asset.tracks(withMediaType: .video).first else {
            throw ExportError.failed("Recording has no video track")
        }
        let readerOutput = AVAssetReaderTrackOutput(
            track: track,
            outputSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        )
        try reader.add(readerOutput)
        guard reader.startReading() else {
            throw ExportError.failed(reader.error?.localizedDescription ?? "Could not read the recording")
        }
        guard let destination = CGImageDestinationCreateWithURL(
            output as CFURL, "com.compuserve.gif" as CFString, 0, nil
        ) else { throw ExportError.failed("Could not create the GIF encoder") }
        _ = CGImageDestinationSetProperties(destination, properties.destination as CFDictionary)

        let sourceRate = max(1, Double(track.nominalFrameRate))
        let step = max(1, Int((sourceRate / Double(max(1, fps))).rounded()))
        let total = max(1, Int(CMTimeGetSeconds(track.timeRange.duration) * sourceRate))
        let context = CIContext() // hoisted: ONE context per export (scaffold defect removed)
        var processed = 0
        var kept = 0
        while let sample = readerOutput.copyNextSampleBuffer() {
            if isCancelled() { throw ExportError.cancelled }
            processed += 1
            guard processed % step == 0, let buffer = CMSampleBufferGetImageBuffer(sample) else { continue }
            var image = CIImage(cvPixelBuffer: buffer)
            let scale = downsampleScale(sourceWidth: CVPixelBufferGetWidth(buffer), targetWidth: targetWidth)
            if scale < 1 { image = image.transformed(by: CGAffineTransform(scaleX: scale, y: scale)) }
            guard let frame = context.createCGImage(image, from: image.extent) else { continue }
            CGImageDestinationAddImage(destination, frame, properties.frame as CFDictionary)
            kept += 1
            onProgress(min(0.99, Double(processed) / Double(total)))
        }
        guard kept > 0 else { throw ExportError.failed("Recording had no frames to export") }
        guard reader.status == .completed else {
            throw ExportError.failed(reader.error?.localizedDescription ?? "Recording read failed")
        }
        guard CGImageDestinationFinalize(destination) else { throw ExportError.failed("GIF encoding failed") }
    }

    // MARK: - Video Path (AVAssetExportSession passthrough)

    private func runVideoExport(source: URL, output: URL, format: CaptureExportFormat,
                                mapping: ExportMapping,
                                completion: @escaping (Result<URL, ExportError>) -> Void) {
        guard let session = AVAssetExportSession(asset: AVURLAsset(url: source),
                                                 presetName: mapping.presetName ?? AVAssetExportPresetPassthrough),
              let fileType = mapping.fileType else {
            finish(result: .failure(.failed("Could not create the export session")),
                   output: output, completion: completion)
            return
        }
        if output != source { // belt and braces: the staged input is never the output (CR-01)
            try? FileManager.default.removeItem(at: output) // session refuses existing files
        }
        session.outputURL = output
        session.outputFileType = fileType
        activeSession = session
        startProgressPolling(session)
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            session.exportAsynchronously {
                DispatchQueue.main.async { [weak self] in
                    self?.finishVideoExport(session: session, source: source, output: output,
                                            format: format, completion: completion)
                }
            }
        }
    }

    private func finishVideoExport(session: AVAssetExportSession, source: URL, output: URL,
                                   format: CaptureExportFormat,
                                   completion: @escaping (Result<URL, ExportError>) -> Void) {
        switch session.status {
        case .completed:
            finish(result: .success(output), output: output, completion: completion)
        case .cancelled:
            finish(result: .failure(.cancelled), output: output, completion: completion)
        default:
            // Research A2 fallback: passthrough can reject HEVC-in-MP4 — re-encode once.
            if session.presetName == AVAssetExportPresetPassthrough, format == .mp4 {
                stopSessionTracking()
                AppLogger.capture.info("Passthrough MP4 unavailable — re-encoding (research A2)")
                runVideoExport(source: source, output: output, format: format,
                               mapping: ExportMapping(presetName: AVAssetExportPresetHighestQuality,
                                                      fileType: .mp4, pathExtension: "mp4"),
                               completion: completion)
            } else {
                finish(result: .failure(.failed(session.error?.localizedDescription ?? "Export failed")),
                       output: output, completion: completion)
            }
        }
    }

    // MARK: - State

    private func publish(progress: Double) {
        if case .running(let current) = exportState, progress - current < 0.02, progress < 0.99 { return }
        exportState = .running(progress: min(max(progress, 0), 1))
    }

    private func startProgressPolling(_ session: AVAssetExportSession) {
        stopSessionTracking()
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            DispatchQueue.main.async { [weak self] in
                guard let self, self.activeSession === session else { return }
                self.exportState = .running(progress: Double(session.progress))
            }
        }
    }

    private func stopSessionTracking() {
        progressTimer?.invalidate()
        progressTimer = nil
        activeSession = nil
    }

    /// Single exit path: publishes terminal state, deletes partial output on
    /// failure/cancel, then hands the result to the caller for routing.
    private func finish(result: Result<URL, ExportError>, output: URL,
                        completion: @escaping (Result<URL, ExportError>) -> Void) {
        stopSessionTracking()
        activeCancellation = nil
        switch result {
        case .success(let url):
            exportState = .completed(url)
            AppLogger.capture.info("Export finished")
        case .failure(.cancelled):
            exportState = .cancelled
            try? FileManager.default.removeItem(at: output) // partial output never survives (T-02-04)
            AppLogger.capture.info("Export cancelled")
        case .failure(.failed(let message)):
            exportState = .failed(message)
            try? FileManager.default.removeItem(at: output) // intermediates die on every exit path
            AppLogger.capture.error("Export failed") // no message detail — redaction
        }
        completion(result)
    }

    // MARK: - Stale Temp Sweep (threat T-02-04)

    /// Removes boostersim-capture-* temp files older than 24 hours; wired at launch.
    nonisolated static func sweepStaleCaptures(
        olderThan maxAge: TimeInterval = 24 * 60 * 60,
        now: Date = Date(),
        directory: URL = FileManager.default.temporaryDirectory
    ) {
        let keys: [URLResourceKey] = [.contentModificationDateKey]
        let entries = (try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: keys)) ?? []
        for entry in entries where entry.lastPathComponent.hasPrefix("boostersim-capture-") {
            // Unreadable modification date → treat as fresh (never over-delete).
            let modified = (try? entry.resourceValues(forKeys: Set(keys)))?.contentModificationDate ?? now
            if now.timeIntervalSince(modified) > maxAge {
                try? FileManager.default.removeItem(at: entry)
            }
        }
    }
}
