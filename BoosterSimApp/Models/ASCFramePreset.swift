// ASCFramePreset.swift — App Store Connect screenshot pixel presets (portrait table)
// Raw values are persistence keys — renaming strands stored selections.
import Foundation
import CoreGraphics

// MARK: - Device Family

enum ASCDeviceFamily: String, CaseIterable {
    case iphone69
    case iphone65
    case ipad13

    var label: String {
        switch self {
        case .iphone69: return "6.9\" iPhone"
        case .iphone65: return "6.5\" iPhone"
        case .ipad13: return "13\" iPad"
        }
    }
}

// MARK: - Preset
enum ASCFramePreset: String, CaseIterable {
    case iphone69x1320
    case iphone69x1290
    case iphone69x1260
    case iphone65x1284
    case iphone65x1242
    case ipad13x2064
    case ipad13x2048

    /// Exact ASC portrait pixel size (Apple screenshot specifications).
    var pixelSize: CGSize {
        switch self {
        case .iphone69x1320: return CGSize(width: 1320, height: 2868)
        case .iphone69x1290: return CGSize(width: 1290, height: 2796)
        case .iphone69x1260: return CGSize(width: 1260, height: 2736)
        case .iphone65x1284: return CGSize(width: 1284, height: 2778)
        case .iphone65x1242: return CGSize(width: 1242, height: 2688)
        case .ipad13x2064: return CGSize(width: 2064, height: 2752)
        case .ipad13x2048: return CGSize(width: 2048, height: 2732)
        }
    }

    var displayName: String {
        switch self {
        case .iphone69x1320: return "1320×2868"
        case .iphone69x1290: return "1290×2796"
        case .iphone69x1260: return "1260×2736"
        case .iphone65x1284: return "1284×2778"
        case .iphone65x1242: return "1242×2688"
        case .ipad13x2064: return "2064×2752"
        case .ipad13x2048: return "2048×2732"
        }
    }

    var deviceFamily: ASCDeviceFamily {
        switch self {
        case .iphone69x1320, .iphone69x1290, .iphone69x1260: return .iphone69
        case .iphone65x1284, .iphone65x1242: return .iphone65
        case .ipad13x2064, .ipad13x2048: return .ipad13
        }
    }
}
