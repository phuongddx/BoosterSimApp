// DesignOverlayService.swift — Design overlay tool state: per-tool toggles, comparison image, picked color, versioned presets
// Cut-over of the deleted design-comparison scaffold: persistence shape and color helpers kept verbatim in shape,
// the fake pickColor core and the single-spacing grid model deleted (D-01). Grid spacing is computed, not stored.
// Preset persistence + legacy import live in DesignOverlayService+Presets.swift; image import in +Import.swift.
import Foundation
import SwiftUI
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

    // Safe-area tool state (D-02): auto-resolved insets pushed by the controller (service stays tracker-free),
    // manual override as the escape hatch, calibration offsets for bezel drift (Pitfall 3 / Open Question 5).
    @Published var showSafeArea: Bool = false { didSet { defaults.set(showSafeArea, forKey: Keys.showSafeArea) } }
    @Published var resolvedInsets: SafeAreaCatalog.Insets = SafeAreaCatalog.manualDefaults
    @Published var resolvedDeviceName: String?
    @Published var useManualInsets: Bool = false { didSet { defaults.set(useManualInsets, forKey: Keys.useManualInsets) } }
    @Published var manualTop: CGFloat = SafeAreaCatalog.manualDefaults.top { didSet { defaults.set(manualTop, forKey: Keys.manualTop) } }
    @Published var manualBottom: CGFloat = SafeAreaCatalog.manualDefaults.bottom { didSet { defaults.set(manualBottom, forKey: Keys.manualBottom) } }
    @Published var manualLeading: CGFloat = SafeAreaCatalog.manualDefaults.left { didSet { defaults.set(manualLeading, forKey: Keys.manualLeading) } }
    @Published var manualTrailing: CGFloat = SafeAreaCatalog.manualDefaults.right { didSet { defaults.set(manualTrailing, forKey: Keys.manualTrailing) } }
    @Published var calibrationX: CGFloat = 0 { didSet { defaults.set(calibrationX, forKey: Keys.calibrationX) } }
    @Published var calibrationY: CGFloat = 0 { didSet { defaults.set(calibrationY, forKey: Keys.calibrationY) } }
    @Published var importError: String?

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

    // MARK: - Safe-Area Resolution (D-02)

    /// Manual values win while flagged; resetInsetsToDevice() restores catalog auto-resolution.
    var effectiveInsets: SafeAreaCatalog.Insets {
        guard useManualInsets else { return resolvedInsets }
        return SafeAreaCatalog.Insets(top: manualTop, bottom: manualBottom, left: manualLeading, right: manualTrailing)
    }

    func resetInsetsToDevice() {
        useManualInsets = false
    }

    // MARK: - Private

    let defaults: UserDefaults

    // Internal: the Presets/Import extension files share these keys (file < 200 LOC, docs/code-standards).
    enum Keys {
        static let presets = "DesignOverlayPresets"
        static let legacyPresets = "DesignComparisonPresets"
        static let legacyImported = "DesignOverlayLegacyImported"
        static let showGrid = "DesignOverlayShowGrid"
        static let showRuler = "DesignOverlayShowRuler"
        static let showSafeArea = "DesignOverlayShowSafeArea"
        static let useManualInsets = "DesignOverlayUseManualInsets"
        static let manualTop = "DesignOverlayManualTop"
        static let manualBottom = "DesignOverlayManualBottom"
        static let manualLeading = "DesignOverlayManualLeading"
        static let manualTrailing = "DesignOverlayManualTrailing"
        static let calibrationX = "DesignOverlayCalibrationX"
        static let calibrationY = "DesignOverlayCalibrationY"
    }

    // MARK: - Init

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        showGrid = defaults.bool(forKey: Keys.showGrid)
        showRuler = defaults.bool(forKey: Keys.showRuler)
        showSafeArea = defaults.bool(forKey: Keys.showSafeArea)
        useManualInsets = defaults.bool(forKey: Keys.useManualInsets)
        manualTop = Self.read(defaults, Keys.manualTop, SafeAreaCatalog.manualDefaults.top)
        manualBottom = Self.read(defaults, Keys.manualBottom, SafeAreaCatalog.manualDefaults.bottom)
        manualLeading = Self.read(defaults, Keys.manualLeading, SafeAreaCatalog.manualDefaults.left)
        manualTrailing = Self.read(defaults, Keys.manualTrailing, SafeAreaCatalog.manualDefaults.right)
        calibrationX = Self.read(defaults, Keys.calibrationX, 0)
        calibrationY = Self.read(defaults, Keys.calibrationY, 0)
        importLegacyPresets()
        loadPresets()
        AppLogger.design.debug("[DesignOverlayService] initialized with \(self.presets.count) presets")
    }

    // MARK: - Color Helpers

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

    // MARK: - Defaults Read Helpers

    private static func read(_ defaults: UserDefaults, _ key: String, _ fallback: CGFloat) -> CGFloat {
        guard let stored = defaults.object(forKey: key) as? Double else { return fallback }
        return CGFloat(stored)
    }
}
