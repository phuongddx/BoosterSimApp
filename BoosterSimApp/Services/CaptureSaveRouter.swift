// CaptureSaveRouter.swift — Destination routing and save-panel flow for captures
import Foundation
import AppKit
import CoreGraphics
import OSLog
import UniformTypeIdentifiers

/// Routes finished captures to their destination (desktop / clipboard /
/// custom / ask). Plan 03's export pipeline reuses this for movies.
@MainActor
final class CaptureSaveRouter {

    // MARK: - Properties

    private let settings: AppSettings
    private let thumbnailPanel: CaptureThumbnailPanel
    /// Publishes the saved URL (nil clears the last-saved marker).
    private let onSaved: (URL?) -> Void
    private let onError: (String) -> Void

    // MARK: - Lifecycle

    init(settings: AppSettings, thumbnailPanel: CaptureThumbnailPanel,
         onSaved: @escaping (URL?) -> Void, onError: @escaping (String) -> Void) {
        self.settings = settings
        self.thumbnailPanel = thumbnailPanel
        self.onSaved = onSaved
        self.onError = onError
    }

    // MARK: - Routing

    /// Destination routing (in-memory PNG data, no temp files to clean up).
    func route(pngData: Data, filename: String, suggestedURL: URL, anchor: CGRect) {
        switch resolvedDestination() {
        case .desktop:
            finishSave(url: suggestedURL, pngData: pngData, anchor: anchor)
        case .clipboard:
            // Clipboard receives captures only via this user-selected destination (T-02-03).
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setData(pngData, forType: .png)
            onSaved(nil)
        case .custom(let folder):
            presentSavePanel(directory: folder, filename: filename, pngData: pngData, anchor: anchor)
        case .ask:
            presentSavePanel(directory: nil, filename: filename, pngData: pngData, anchor: anchor)
        }
    }

    /// Routes an on-disk exported file (GIF/MP4/MOV). `onPersisted` fires once
    /// the destination write succeeds — the caller then deletes the staged
    /// recording (retention rule). Clipboard keeps the temp payload as the
    /// paste object; abandoned save panels delete it.
    func route(fileAt sourceURL: URL, anchor: CGRect, onPersisted: @escaping () -> Void) {
        switch resolvedDestination() {
        case .desktop:
            persistFile(from: sourceURL,
                        to: CaptureDestination.defaultDesktopFolder()
                            .appendingPathComponent(sourceURL.lastPathComponent),
                        anchor: anchor, onPersisted: onPersisted)
        case .clipboard:
            // Clipboard receives a file URL only via this user-selected
            // destination (T-02-03) — paste into Finder reveals the movie.
            NSPasteboard.general.clearContents()
            NSPasteboard.general.writeObjects([sourceURL as NSURL])
            onSaved(sourceURL)
            onPersisted()
        case .custom(let folder):
            presentFilePanel(directory: folder, sourceURL: sourceURL,
                             anchor: anchor, onPersisted: onPersisted)
        case .ask:
            presentFilePanel(directory: nil, sourceURL: sourceURL,
                             anchor: anchor, onPersisted: onPersisted)
        }
    }

    // MARK: - Private

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
            onSaved(url)
            thumbnailPanel.show(url: url, anchorNear: anchor)
            AppLogger.capture.info("Saved capture")
        } catch {
            onError(error.localizedDescription)
        }
    }

    /// Non-modal save panel for exported files; the format-correct extension
    /// rides the pre-populated name. Cancel deletes the abandoned export.
    private func presentFilePanel(directory: URL?, sourceURL: URL, anchor: CGRect,
                                  onPersisted: @escaping () -> Void) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = panelContentTypes(forExtension: sourceURL.pathExtension)
        panel.nameFieldStringValue = sourceURL.lastPathComponent
        panel.directoryURL = directory
        panel.begin { [weak self] response in
            guard let self, response == .OK, let url = panel.url else {
                try? FileManager.default.removeItem(at: sourceURL)
                return
            }
            if self.settings.captureDestination == .custom {
                self.settings.customCaptureFolder = url.deletingLastPathComponent()
            }
            self.persistFile(from: sourceURL, to: url, anchor: anchor, onPersisted: onPersisted)
        }
    }

    /// Deterministic replacement (T-02-07): the export overwrites only its own
    /// name; the temp source is deleted once the durable write lands.
    private func persistFile(from sourceURL: URL, to destination: URL,
                             anchor: CGRect, onPersisted: @escaping () -> Void) {
        do {
            try? FileManager.default.removeItem(at: destination)
            try FileManager.default.copyItem(at: sourceURL, to: destination)
            try? FileManager.default.removeItem(at: sourceURL)
            onSaved(destination)
            thumbnailPanel.show(url: destination, anchorNear: anchor)
            AppLogger.capture.info("Saved export")
            onPersisted()
        } catch {
            // Routing failure keeps the exported source for retry (02 review
            // WR-02): deleting it here would destroy a completed export — for
            // GIF, a full re-encode — on a transient destination error. The
            // 24h stale-temp sweep bounds its lifetime instead; the staged
            // recording is deleted only after onPersisted fires.
            onError(error.localizedDescription)
        }
    }

    private func panelContentTypes(forExtension pathExtension: String) -> [UTType] {
        switch pathExtension {
        case "gif": return [.gif]
        case "mp4": return [.mpeg4Movie]
        case "mov": return [.quickTimeMovie]
        default: return []
        }
    }
}
