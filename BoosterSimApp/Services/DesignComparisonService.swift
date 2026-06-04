// DesignComparisonService.swift — Manages design comparison overlays and presets
import Foundation
import SwiftUI
import AppKit
import Combine

final class DesignComparisonService: ObservableObject {

    // MARK: - Published State

    @Published var overlayImage: NSImage?
    @Published var overlayOpacity: Double = 0.5
    @Published var comparisonMode: ComparisonMode = .overlay
    @Published var splitPosition: Double = 0.5
    @Published var showGrid: Bool = false
    @Published var gridSpacing: CGFloat = 20
    @Published var gridColor: SwiftUI.Color = .blue
    @Published var showRuler: Bool = false
    @Published var rulerStart: CGPoint?
    @Published var rulerEnd: CGPoint?
    @Published var pickedColor: NSColor?
    @Published var presets: [DesignPreset] = []

    // MARK: - Types

    enum ComparisonMode: String, CaseIterable, Codable {
        case overlay = "Overlay"
        case split = "Split"
    }

    struct DesignPreset: Identifiable, Codable {
        let id: UUID
        let name: String
        let mode: ComparisonMode
        let opacity: Double
        let gridSpacing: CGFloat
        let showGrid: Bool
        let showRuler: Bool
    }

    // MARK: - Private

    private let presetsKey = "DesignComparisonPresets"

    // MARK: - Init

    init() {
        loadPresets()
    }

    // MARK: - Public API

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
    }

    func pickColor(at point: CGPoint) {
        // Color picker via screen capture — requires ScreenCaptureKit on macOS 15+
        // For now, sample from the screen's CGImage context
        guard let screen = NSScreen.main else { return }
        let screenPoint = CGPoint(x: point.x, y: screen.frame.height - point.y)
        // Use NSBitmapImageRep screenshot approach
        let rect = CGRect(origin: screenPoint, size: CGSize(width: 1, height: 1))
        guard let bitmapRep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1, pixelsHigh: 1,
                                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                               isPlanar: false, colorSpaceName: .calibratedRGB,
                                               bytesPerRow: 4, bitsPerPixel: 32) else { return }
        let ctx = NSGraphicsContext(bitmapImageRep: bitmapRep)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = ctx
        // This only captures our own window content; for full screen color picking,
        // ScreenCaptureKit async API would be needed
        NSGraphicsContext.restoreGraphicsState()
        pickedColor = bitmapRep.colorAt(x: 0, y: 0)
    }

    func copyColorToClipboard() {
        guard let color = pickedColor else { return }
        let hex = colorToHex(color)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(hex, forType: .string)
    }

    func colorToHex(_ color: NSColor) -> String {
        let r = Int(color.redComponent * 255)
        let g = Int(color.greenComponent * 255)
        let b = Int(color.blueComponent * 255)
        return String(format: "#%02X%02X%02X", r, g, b)
    }

    func colorToRGB(_ color: NSColor) -> String {
        let r = Int(color.redComponent * 255)
        let g = Int(color.greenComponent * 255)
        let b = Int(color.blueComponent * 255)
        return "rgb(\(r), \(g), \(b))"
    }

    func savePreset(name: String) {
        let preset = DesignPreset(
            id: UUID(),
            name: name,
            mode: comparisonMode,
            opacity: overlayOpacity,
            gridSpacing: gridSpacing,
            showGrid: showGrid,
            showRuler: showRuler
        )
        presets.append(preset)
        savePresets()
    }

    func loadPreset(_ preset: DesignPreset) {
        comparisonMode = preset.mode
        overlayOpacity = preset.opacity
        gridSpacing = preset.gridSpacing
        showGrid = preset.showGrid
        showRuler = preset.showRuler
    }

    func deletePreset(_ preset: DesignPreset) {
        presets.removeAll { $0.id == preset.id }
        savePresets()
    }

    // MARK: - Private

    private func loadPresets() {
        guard let data = UserDefaults.standard.data(forKey: presetsKey),
              let decoded = try? JSONDecoder().decode([DesignPreset].self, from: data) else { return }
        presets = decoded
    }

    private func savePresets() {
        guard let data = try? JSONEncoder().encode(presets) else { return }
        UserDefaults.standard.set(data, forKey: presetsKey)
    }
}
