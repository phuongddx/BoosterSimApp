// SafeAreaCatalog.swift — Safe-area inset + logical-size constants keyed by device name, logical size fallback (D-02)
// Provenance: 13/15/16-series rows verified (useyourloaf screen-size posts); X/11/SE/Plus and iPad rows ASSUMED
// (classic values). Constants are not queryable live per D-02 — manual override is the escape hatch.
import Foundation
import CoreGraphics

/// Pure data lookup: device name first (SimulatorWindow.deviceName), logical size second, manual defaults third.
/// Name-keying is required because sizes collide: 375x812 is both iPhone X/XS/11 Pro (top 44) and 12/13 mini (top 50).
enum SafeAreaCatalog {

    // MARK: - Types

    struct Insets: Equatable {
        let top, bottom, left, right: CGFloat
    }

    /// One named device row: portrait insets plus its logical screen size.
    private struct Device {
        let insets: Insets
        let logicalSize: CGSize
    }

    // MARK: - Lookup

    static func insets(forDeviceName name: String?, logicalSize: CGSize?) -> Insets {
        if let name, let device = byName[name] { return device.insets }
        if let logicalSize, let sizeInsets = byLogicalSize[logicalSize] { return sizeInsets }
        return manualDefaults
    }

    static func logicalSize(forDeviceName name: String?) -> CGSize? {
        guard let name else { return nil }
        return byName[name]?.logicalSize
    }

    /// Fallback when neither name nor size is known (modern default family; override manually for custom devices).
    static let manualDefaults = Insets(top: 59, bottom: 34, left: 0, right: 0)

    // MARK: - Tables (portrait; landscape top 0, sides = portrait top, bottom 21)

    private static func insets(_ top: CGFloat, _ bottom: CGFloat) -> Insets {
        Insets(top: top, bottom: bottom, left: 0, right: 0)
    }

    private static let byName: [String: Device] = [
        // Verified generations (useyourloaf 13/15/16-series)
        "iPhone 16 Pro":         Device(insets: insets(62, 34), logicalSize: CGSize(width: 402, height: 874)),
        "iPhone 16 Pro Max":     Device(insets: insets(62, 34), logicalSize: CGSize(width: 440, height: 956)),
        "iPhone 15":             Device(insets: insets(59, 34), logicalSize: CGSize(width: 393, height: 852)),
        "iPhone 15 Pro":         Device(insets: insets(59, 34), logicalSize: CGSize(width: 393, height: 852)),
        "iPhone 15 Plus":        Device(insets: insets(59, 34), logicalSize: CGSize(width: 430, height: 932)),
        "iPhone 15 Pro Max":     Device(insets: insets(59, 34), logicalSize: CGSize(width: 430, height: 932)),
        "iPhone 16":             Device(insets: insets(59, 34), logicalSize: CGSize(width: 393, height: 852)),
        "iPhone 16 Plus":        Device(insets: insets(59, 34), logicalSize: CGSize(width: 430, height: 932)),
        "iPhone 14 Pro":         Device(insets: insets(59, 34), logicalSize: CGSize(width: 393, height: 852)),
        "iPhone 14 Pro Max":     Device(insets: insets(59, 34), logicalSize: CGSize(width: 430, height: 932)),
        "iPhone 12":             Device(insets: insets(47, 34), logicalSize: CGSize(width: 390, height: 844)),
        "iPhone 12 Pro":         Device(insets: insets(47, 34), logicalSize: CGSize(width: 390, height: 844)),
        "iPhone 13":             Device(insets: insets(47, 34), logicalSize: CGSize(width: 390, height: 844)),
        "iPhone 13 Pro":         Device(insets: insets(47, 34), logicalSize: CGSize(width: 390, height: 844)),
        "iPhone 14":             Device(insets: insets(47, 34), logicalSize: CGSize(width: 390, height: 844)),
        "iPhone 14 Plus":        Device(insets: insets(47, 34), logicalSize: CGSize(width: 428, height: 926)),
        "iPhone 12 Pro Max":     Device(insets: insets(47, 34), logicalSize: CGSize(width: 428, height: 926)),
        "iPhone 13 Pro Max":     Device(insets: insets(47, 34), logicalSize: CGSize(width: 428, height: 926)),
        "iPhone 12 mini":        Device(insets: insets(50, 34), logicalSize: CGSize(width: 375, height: 812)),
        "iPhone 13 mini":        Device(insets: insets(50, 34), logicalSize: CGSize(width: 375, height: 812)),
        // ASSUMED legacy generations (classic pre-13 values)
        "iPhone X":              Device(insets: insets(44, 34), logicalSize: CGSize(width: 375, height: 812)),
        "iPhone XS":             Device(insets: insets(44, 34), logicalSize: CGSize(width: 375, height: 812)),
        "iPhone 11 Pro":         Device(insets: insets(44, 34), logicalSize: CGSize(width: 375, height: 812)),
        "iPhone XR":             Device(insets: insets(48, 34), logicalSize: CGSize(width: 414, height: 896)),
        "iPhone 11":             Device(insets: insets(48, 34), logicalSize: CGSize(width: 414, height: 896)),
        "iPhone XS Max":         Device(insets: insets(48, 34), logicalSize: CGSize(width: 414, height: 896)),
        "iPhone 11 Pro Max":     Device(insets: insets(48, 34), logicalSize: CGSize(width: 414, height: 896)),
        "iPhone SE (3rd generation)": Device(insets: insets(20, 0), logicalSize: CGSize(width: 375, height: 667)),
        "iPhone SE (2nd generation)": Device(insets: insets(20, 0), logicalSize: CGSize(width: 375, height: 667)),
        "iPhone 8":              Device(insets: insets(20, 0), logicalSize: CGSize(width: 375, height: 667)),
        "iPhone 8 Plus":         Device(insets: insets(20, 0), logicalSize: CGSize(width: 414, height: 736)),
        "iPhone 7":              Device(insets: insets(20, 0), logicalSize: CGSize(width: 375, height: 667)),
        "iPhone 7 Plus":         Device(insets: insets(20, 0), logicalSize: CGSize(width: 414, height: 736))
    ]

    private static let byLogicalSize: [CGSize: Insets] = [
        CGSize(width: 393, height: 852): insets(59, 34),
        CGSize(width: 430, height: 932): insets(59, 34),
        CGSize(width: 402, height: 874): insets(62, 34),
        CGSize(width: 440, height: 956): insets(62, 34),
        CGSize(width: 390, height: 844): insets(47, 34),
        CGSize(width: 428, height: 926): insets(47, 34),
        CGSize(width: 375, height: 812): insets(50, 34),  // mini family wins the size key; name key disambiguates
        CGSize(width: 414, height: 896): insets(48, 34),
        CGSize(width: 375, height: 667): insets(20, 0),
        CGSize(width: 414, height: 736): insets(20, 0),
        CGSize(width: 320, height: 568): insets(20, 0),
        CGSize(width: 768, height: 1024): insets(20, 20),
        CGSize(width: 820, height: 1180): insets(20, 20),
        CGSize(width: 834, height: 1194): insets(20, 20),
        CGSize(width: 1024, height: 1366): insets(20, 20)
    ]
}
