// BezelMode.swift — Compositing option models for bezel and background
// Raw values are persistence keys — renaming strands stored selections.
import Foundation
import CoreGraphics

// MARK: - Bezel Mode

enum BezelMode: String, CaseIterable {
    /// Content composites directly onto the background.
    case none
    /// Simulator renders its own device bezel; captured pixels pass through untouched.
    case simulatorNative
    /// CoreGraphics rounded-rect device silhouette drawn around the content.
    case drawn

    var label: String {
        switch self {
        case .none: return "None"
        case .simulatorNative: return "Simulator"
        case .drawn: return "Drawn"
        }
    }
}

// MARK: - Background

enum CaptureBackground: String, CaseIterable {
    /// Opaque single-color fill.
    case solid
    /// Vertical gradient riding the house amber accent.
    case gradient

    var label: String {
        switch self {
        case .solid: return "Solid"
        case .gradient: return "Gradient"
        }
    }

    /// Fill colors for the compositor (CGColor — the renderer stays CoreGraphics-only).
    /// Amber values mirror the asset-catalog accent (#F59E0B) from design-guidelines.
    var fillColors: [CGColor] {
        switch self {
        case .solid:
            return [CGColor(red: 1, green: 1, blue: 1, alpha: 1)]
        case .gradient:
            return [
                CGColor(red: 0.996, green: 0.953, blue: 0.780, alpha: 1),
                CGColor(red: 0.961, green: 0.620, blue: 0.043, alpha: 1)
            ]
        }
    }
}
