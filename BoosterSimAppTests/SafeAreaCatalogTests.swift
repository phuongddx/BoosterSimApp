// SafeAreaCatalogTests.swift — Name-first/size-second safe-area inset lookups (pure data, no windows)
import Foundation
import CoreGraphics
import Testing
@testable import BoosterSimApp

struct SafeAreaCatalogTests {

    // MARK: - Builders

    private func makeInsets(_ top: CGFloat, _ bottom: CGFloat) -> SafeAreaCatalog.Insets {
        SafeAreaCatalog.Insets(top: top, bottom: bottom, left: 0, right: 0)
    }

    private func makeSize(_ width: CGFloat, _ height: CGFloat) -> CGSize {
        CGSize(width: width, height: height)
    }

    // MARK: - Name-Keyed Lookup (verified rows)

    @Test func nameKeyedLookupReturnsVerifiedPortraitRows() {
        #expect(SafeAreaCatalog.insets(forDeviceName: "iPhone 16 Pro", logicalSize: nil) == makeInsets(62, 34))
        #expect(SafeAreaCatalog.insets(forDeviceName: "iPhone 15", logicalSize: nil) == makeInsets(59, 34))
        #expect(SafeAreaCatalog.insets(forDeviceName: "iPhone 13 mini", logicalSize: nil) == makeInsets(50, 34))
    }

    // MARK: - Size Fallback

    @Test func unknownNameFallsBackToLogicalSizeKey() {
        #expect(SafeAreaCatalog.insets(forDeviceName: "Unrecognized Device", logicalSize: makeSize(390, 844)) == makeInsets(47, 34))
        #expect(SafeAreaCatalog.insets(forDeviceName: nil, logicalSize: makeSize(393, 852)) == makeInsets(59, 34))
    }

    @Test func iPadLogicalSizeHitsFallbackRow() {
        #expect(SafeAreaCatalog.insets(forDeviceName: nil, logicalSize: makeSize(820, 1180)) == makeInsets(20, 20))
    }

    // MARK: - 375x812 Disambiguation

    @Test func nameKeyResolvesThe375x812Collision() {
        #expect(SafeAreaCatalog.insets(forDeviceName: "iPhone X", logicalSize: nil) == makeInsets(44, 34))
        #expect(SafeAreaCatalog.insets(forDeviceName: "iPhone 13 mini", logicalSize: nil) == makeInsets(50, 34))
        // Size-only fallback: the mini family wins the size key; the name key resolves the collision.
        #expect(SafeAreaCatalog.insets(forDeviceName: nil, logicalSize: makeSize(375, 812)) == makeInsets(50, 34))
    }

    // MARK: - Manual Defaults

    @Test func unknownNameAndSizeFallsBackToManualDefaults() {
        #expect(SafeAreaCatalog.insets(forDeviceName: "Unheard Of", logicalSize: makeSize(500, 900)) == SafeAreaCatalog.manualDefaults)
        #expect(SafeAreaCatalog.insets(forDeviceName: nil, logicalSize: nil) == SafeAreaCatalog.manualDefaults)
    }

    // MARK: - Logical Size

    @Test func logicalSizeLookupCoversKnownNamesOnly() {
        #expect(SafeAreaCatalog.logicalSize(forDeviceName: "iPhone 16 Pro") == makeSize(402, 874))
        #expect(SafeAreaCatalog.logicalSize(forDeviceName: "Unheard Of") == nil)
        #expect(SafeAreaCatalog.logicalSize(forDeviceName: nil) == nil)
    }
}
