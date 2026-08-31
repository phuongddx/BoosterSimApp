// DesignOverlayService.swift — Design overlay tool state: per-tool toggles, comparison image, picked color, versioned presets
// Cut-over of the deleted design-comparison scaffold: persistence shape and color helpers kept verbatim in shape,
// the fake pickColor core and the single-spacing grid model deleted (D-01). Grid spacing is computed, not stored.
import Foundation
import SwiftUI
import UniformTypeIdentifiers
import AppKit
import Combine
import OSLog

@MainActor
final class DesignOverlayService: ObservableObject {

    // MARK: - Published State

    @Published var overlayImage: NSImage?
    @Published var overlayOpacity: Double = 0.5
    @Published var comparisonMode: ComparisonMode = .overlay
    @Published var splitPosition: Double = 0.5
    @Published var showGrid: Bool = false { didSet { defaults.set(showGrid, forKey: Keys.showGrid) } }
    @Published var gridColor: SwiftUI.Color = .blue
    @Published var gridOpacity: Double = 1.0
    @Published var showRuler: Bool = false { didSet { defaults.set(showRuler, forKey: Keys.showRuler) } }
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
        let showGrid: Bool
        let showRuler: Bool
    }

    /// Tolerant decode shape for imported preset data: every field optional so a missing key —
    /// or unknown extras like the deleted legacy spacing field — never fails the whole array (Pitfall 5).
    private struct ImportedEntry: Decodable {
        let id: UUID?
        let name: String?
        let mode: ComparisonMode?
        let opacity: Double?
        let showGrid: Bool?
        let showRuler: Bool?
    }

    // MARK: - Private

    private let defaults: UserDefaults

    private enum Keys {
        static let presets = "DesignOverlayPresets"
        static let legacyPresets = "DesignComparisonPresets"
        static let legacyImported = "DesignOverlayLegacyImported"
        static let showGrid = "DesignOverlayShowGrid"
        static let showRuler = "DesignOverlayShowRuler"
    }

    // MARK: - Init

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        showGrid = defaults.bool(forKey: Keys.showGrid)
        showRuler = defaults.bool(forKey: Keys.showRuler)
        importLegacyPresets()
        loadPresets()
        AppLogger.design.debug("[DesignOverlayService] initialized with \(self.presets.count) presets")
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
            showGrid: showGrid,
            showRuler: showRuler
        )
        presets.append(preset)
        savePresets()
    }

    func loadPreset(_ preset: DesignPreset) {
        comparisonMode = preset.mode
        overlayOpacity = preset.opacity
        showGrid = preset.showGrid
        showRuler = preset.showRuler
    }

    func deletePreset(_ preset: DesignPreset) {
        presets.removeAll { $0.id == preset.id }
        savePresets()
    }

    // MARK: - Private

    private func loadPresets() {
        guard let data = defaults.data(forKey: Keys.presets),
              let decoded = try? JSONDecoder().decode([DesignPreset].self, from: data) else { return }
        presets = decoded
    }

    private func savePresets() {
        guard let data = try? JSONEncoder().encode(presets) else { return }
        defaults.set(data, forKey: Keys.presets)
    }

    /// One-shot legacy import (Pitfall 5): read the scaffold key once behind the flag, map tolerantly,
    /// write the versioned key, set the flag. Re-running imports nothing; importing replaces, never appends.
    private func importLegacyPresets() {
        guard !defaults.bool(forKey: Keys.legacyImported) else { return }
        defer { defaults.set(true, forKey: Keys.legacyImported) }
        guard let data = defaults.data(forKey: Keys.legacyPresets),
              let entries = try? JSONDecoder().decode([ImportedEntry].self, from: data) else { return }
        let imported = importedPresets(from: entries)
        guard !imported.isEmpty,
              let encoded = try? JSONEncoder().encode(imported) else { return }
        defaults.set(encoded, forKey: Keys.presets)
        AppLogger.design.info("[DesignOverlayService] imported \(imported.count) legacy presets")
    }

    /// Maps tolerant decoded entries into the versioned schema; absent fields take safe defaults.
    private func importedPresets(from entries: [ImportedEntry]) -> [DesignPreset] {
        entries.map { entry in
            DesignPreset(
                id: entry.id ?? UUID(),
                name: entry.name ?? "Imported preset",
                mode: entry.mode ?? .overlay,
                opacity: entry.opacity ?? 0.5,
                showGrid: entry.showGrid ?? false,
                showRuler: entry.showRuler ?? false
            )
        }
    }

}
