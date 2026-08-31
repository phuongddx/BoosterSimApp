// DesignOverlayService+Import.swift — Artboard import: open/paste entry points + the single dimension-capped accept
// Local only: file/pasteboard/drag payloads never leave the machine (T-04-05 — no network client exists in this path).
import AppKit
import UniformTypeIdentifiers
import OSLog

extension DesignOverlayService {

    /// Decompression-bomb guard (T-04-03): either pixel edge over this cap is rejected BEFORE caching.
    static let maxImportedEdge = 16384

    // MARK: - Import Entry Points (all funnel into accept(image:))

    func loadImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        guard panel.runModal() == .OK, let url = panel.url else { return }
        overlayImage = NSImage(contentsOf: url)
    }

    func clearOverlay() {
        overlayImage = nil
        importError = nil
    }

    /// Paste import: typed image payloads only — non-image payloads leave state untouched (T-04-04 spoofing).
    func importImage(from pasteboard: NSPasteboard) {
        guard let types = pasteboard.types,
              types.contains(where: { UTType($0.rawValue)?.conforms(to: .image) == true })
        else { return }
        guard let image = NSImage(pasteboard: pasteboard) else { return }
        accept(image: image)
    }

    // MARK: - Accept Path

    /// The one validation gate: rejects over-cap images with an honest caption (never a crash),
    /// and replaces the single overlay slot — re-importing never accumulates.
    func accept(image: NSImage) {
        guard Self.validateImported(image) else {
            importError = "Rejected: an image edge exceeds \(Self.maxImportedEdge) px"
            AppLogger.design.info("[DesignOverlayService] import rejected — dimension cap")
            return
        }
        overlayImage = image
        importError = nil
        AppLogger.design.info("[DesignOverlayService] imported image \(Int(image.size.width))×\(Int(image.size.height)) pt")
    }

    /// Pixel-edge check over every bitmap representation; non-bitmap (vector) payloads pass.
    static func validateImported(_ image: NSImage) -> Bool {
        for representation in image.representations {
            guard let bitmap = representation as? NSBitmapImageRep else { continue }
            if bitmap.pixelsWide > maxImportedEdge || bitmap.pixelsHigh > maxImportedEdge { return false }
        }
        return true
    }
}
