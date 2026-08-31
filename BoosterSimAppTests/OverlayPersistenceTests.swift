// OverlayPersistenceTests.swift — Toggle/preset persistence: versioned schema, one-shot legacy import, tolerance
import Foundation
import CoreGraphics
import AppKit
import Testing
@testable import BoosterSimApp

@MainActor
struct OverlayPersistenceTests {

    // MARK: - Fixtures

    /// The deleted scaffold's Codable shape — includes the legacy spacing field. Test-file fixture ONLY;
    /// the production schema never re-declares it.
    private struct LegacyScaffoldPreset: Codable {
        let id: UUID
        let name: String
        let mode: String
        let opacity: Double
        let gridSpacing: Double
        let showGrid: Bool
        let showRuler: Bool
    }

    private func makeDefaults() throws -> (defaults: UserDefaults, suiteName: String) {
        let suiteName = "OverlayPersistenceTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        return (defaults, suiteName)
    }

    private func plantLegacyPreset(_ defaults: UserDefaults, name: String = "Old profile",
                                   mode: String = "Overlay", opacity: Double = 0.4,
                                   showGrid: Bool = true, showRuler: Bool = true) throws {
        let legacy = [LegacyScaffoldPreset(
            id: UUID(), name: name, mode: mode, opacity: opacity,
            gridSpacing: 20, showGrid: showGrid, showRuler: showRuler
        )]
        defaults.set(try JSONEncoder().encode(legacy), forKey: "DesignComparisonPresets")
    }

    /// Synthetic artboard: real bitmap representation sized in pixels (the dimension-cap input).
    private func makeImage(pixelsWide: Int, pixelsHigh: Int) throws -> NSImage {
        let representation = try #require(NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: pixelsWide, pixelsHigh: pixelsHigh,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0))
        let image = NSImage(size: NSSize(width: pixelsWide, height: pixelsHigh))
        image.addRepresentation(representation)
        return image
    }

    // MARK: - Toggle Round Trip

    @Test func perToolTogglesRoundTripAcrossServiceReInit() throws {
        let (defaults, suiteName) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let standardBefore = UserDefaults.standard.bool(forKey: "DesignOverlayShowGrid")

        let first = DesignOverlayService(defaults: defaults)
        #expect(first.showGrid == false)
        #expect(first.showRuler == false)
        first.showGrid = true
        first.showRuler = true

        // Re-initialize from the same suite: persisted toggles must re-apply; .standard stays untouched.
        let second = DesignOverlayService(defaults: defaults)
        #expect(second.showGrid == true)
        #expect(second.showRuler == true)
        #expect(UserDefaults.standard.bool(forKey: "DesignOverlayShowGrid") == standardBefore)
    }

    // MARK: - Versioned Preset Schema Round Trip

    @Test func newSchemaPresetsRoundTripWithIdenticalFields() throws {
        let (defaults, suiteName) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let first = DesignOverlayService(defaults: defaults)
        first.comparisonMode = .split
        first.overlayOpacity = 0.75
        first.showGrid = true
        first.showRuler = true
        first.savePreset(name: "Profile")

        let second = DesignOverlayService(defaults: defaults)
        let restored = try #require(second.presets.first)
        #expect(restored.name == "Profile")
        #expect(restored.mode == .split)
        #expect(restored.opacity == 0.75)
        #expect(restored.showGrid == true)
        #expect(restored.showRuler == true)
    }

    // MARK: - Legacy Import (Pitfall 5)

    @Test func legacyPayloadImportsOnceIntoVersionedKey() throws {
        let (defaults, suiteName) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        try plantLegacyPreset(defaults, opacity: 0.4, showGrid: true, showRuler: false)

        let service = DesignOverlayService(defaults: defaults)
        let imported = try #require(service.presets.first)
        #expect(imported.mode == .overlay)
        #expect(imported.opacity == 0.4)
        #expect(imported.showGrid == true)
        #expect(imported.showRuler == false)
        #expect(defaults.bool(forKey: "DesignOverlayLegacyImported") == true)

        // The import landed in the versioned key, decodable as the new schema.
        let stored = try #require(defaults.data(forKey: "DesignOverlayPresets"))
        #expect(try JSONDecoder().decode([DesignOverlayService.DesignPreset].self, from: stored).count == 1)
    }

    @Test func legacyImportToleratesMissingAndExtraFields() throws {
        let (defaults, suiteName) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        // Hand-built JSON: entry 1 misses fields entirely; entry 2 carries the extra legacy spacing field.
        let json = """
        [
            {"id": "00000000-0000-0000-0000-000000000001", "name": "Sparse"},
            {"id": "00000000-0000-0000-0000-000000000002", "name": "Full", "mode": "Split",
             "opacity": 0.9, "gridSpacing": 25, "showGrid": true, "showRuler": true}
        ]
        """
        defaults.set(Data(json.utf8), forKey: "DesignComparisonPresets")

        let service = DesignOverlayService(defaults: defaults)
        #expect(service.presets.count == 2)
        #expect(service.presets[0].name == "Sparse")
        #expect(service.presets[0].mode == .overlay)
        #expect(service.presets[1].mode == .split)
        #expect(service.presets[1].opacity == 0.9)
        #expect(service.presets[1].showGrid == true)
        #expect(service.presets[1].showRuler == true)
    }

    @Test func doubleInitImportsNothingNewAndDuplicatesNothing() throws {
        let (defaults, suiteName) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        try plantLegacyPreset(defaults)

        let first = DesignOverlayService(defaults: defaults)
        let countAfterFirst = first.presets.count
        let idsAfterFirst = first.presets.map(\.id)
        #expect(countAfterFirst == 1)

        // Flag already set: second init imports nothing — count and ids unchanged.
        let second = DesignOverlayService(defaults: defaults)
        #expect(second.presets.count == countAfterFirst)
        #expect(second.presets.map(\.id) == idsAfterFirst)
    }

    // MARK: - Corrupted Payloads Degrade, Never Trap

    @Test func garbageUnderVersionedKeyLeavesPresetsEmpty() throws {
        let (defaults, suiteName) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(Data("not json at all".utf8), forKey: "DesignOverlayPresets")

        let service = DesignOverlayService(defaults: defaults)
        #expect(service.presets.isEmpty)
    }

    @Test func garbageUnderLegacyKeyCompletesInitWithoutTrapping() throws {
        let (defaults, suiteName) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(Data("definitely not [DesignPreset]".utf8), forKey: "DesignComparisonPresets")

        let service = DesignOverlayService(defaults: defaults)
        #expect(service.presets.isEmpty)
        #expect(defaults.bool(forKey: "DesignOverlayLegacyImported") == true)
    }

    // MARK: - Safe-Area State Persistence (D-02)

    @Test func showSafeAreaToggleRoundTripsLikeShowGrid() throws {
        let (defaults, suiteName) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let first = DesignOverlayService(defaults: defaults)
        #expect(first.showSafeArea == false)
        first.showSafeArea = true

        let second = DesignOverlayService(defaults: defaults)
        #expect(second.showSafeArea == true)
    }

    @Test func manualInsetValuesRoundTripAcrossReInit() throws {
        let (defaults, suiteName) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let first = DesignOverlayService(defaults: defaults)
        first.useManualInsets = true
        first.manualTop = 44
        first.manualBottom = 21
        first.manualLeading = 12
        first.manualTrailing = 13
        first.calibrationX = 3.5
        first.calibrationY = -2

        let second = DesignOverlayService(defaults: defaults)
        #expect(second.useManualInsets == true)
        #expect(second.manualTop == 44)
        #expect(second.manualBottom == 21)
        #expect(second.manualLeading == 12)
        #expect(second.manualTrailing == 13)
        #expect(second.calibrationX == 3.5)
        #expect(second.calibrationY == -2)
    }

    @Test func effectiveInsetsManualWinsUntilReset() throws {
        let (defaults, suiteName) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let service = DesignOverlayService(defaults: defaults)
        let resolved = SafeAreaCatalog.Insets(top: 59, bottom: 34, left: 0, right: 0)
        service.resolvedInsets = resolved
        #expect(service.effectiveInsets == resolved)   // auto-resolution wins by default

        service.useManualInsets = true
        service.manualTop = 44
        #expect(service.effectiveInsets == SafeAreaCatalog.Insets(top: 44, bottom: 34, left: 0, right: 0))

        service.resetInsetsToDevice()
        #expect(service.useManualInsets == false)
        #expect(service.effectiveInsets == resolved)
    }

    // MARK: - Import Accept/Reject (T-04-03 decompression-bomb guard)

    @Test func acceptUnderCapImageReplacesSlotAndClearsError() throws {
        let (defaults, suiteName) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let service = DesignOverlayService(defaults: defaults)

        let first = try makeImage(pixelsWide: 512, pixelsHigh: 512)
        service.accept(image: first)
        #expect(service.overlayImage === first)
        #expect(service.importError == nil)

        // Re-import replaces the single slot — never accumulates (idempotency edge).
        let second = try makeImage(pixelsWide: 256, pixelsHigh: 128)
        service.accept(image: second)
        #expect(service.overlayImage === second)
    }

    @Test func rejectOverCapImageSetsCaptionAndNeverCaches() throws {
        let (defaults, suiteName) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let service = DesignOverlayService(defaults: defaults)

        #expect(DesignOverlayService.validateImported(try makeImage(pixelsWide: 512, pixelsHigh: 512)))
        let bomb = try makeImage(pixelsWide: DesignOverlayService.maxImportedEdge + 1, pixelsHigh: 8)
        #expect(DesignOverlayService.validateImported(bomb) == false)

        service.accept(image: bomb)
        #expect(service.overlayImage == nil)
        #expect(service.importError != nil)

        // A later valid import clears the rejection caption.
        service.accept(image: try makeImage(pixelsWide: 64, pixelsHigh: 64))
        #expect(service.overlayImage != nil)
        #expect(service.importError == nil)
    }
}