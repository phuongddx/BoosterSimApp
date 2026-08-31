// DesignOverlayService+Presets.swift — Versioned preset persistence + one-shot tolerant legacy import (Pitfall 5)
// Split from DesignOverlayService.swift to hold the file-size standard (docs/code-standards); same type, same module.
import Foundation
import OSLog

extension DesignOverlayService {

    // MARK: - Preset API

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

    // MARK: - Persistence

    // Internal: the class init in DesignOverlayService.swift calls these across files.
    func loadPresets() {
        guard let data = defaults.data(forKey: Keys.presets),
              let decoded = try? JSONDecoder().decode([DesignPreset].self, from: data) else { return }
        presets = decoded
    }

    private func savePresets() {
        guard let data = try? JSONEncoder().encode(presets) else { return }
        defaults.set(data, forKey: Keys.presets)
    }

    // MARK: - Legacy Import (Pitfall 5)

    /// One-shot legacy import: read the scaffold key once behind the flag, map tolerantly,
    /// write the versioned key, set the flag. Re-running imports nothing; importing replaces, never appends.
    func importLegacyPresets() {
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
}
