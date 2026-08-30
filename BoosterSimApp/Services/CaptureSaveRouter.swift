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
}
