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

    private func makeLandscape(_ top: CGFloat, _ bottom: CGFloat, _ side: CGFloat) -> SafeAreaCatalog.Insets {
        SafeAreaCatalog.Insets(top: top, bottom: bottom, left: side, right: side)
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

    // MARK: - Landscape Resolution (verified shape: top 0, bottom 21, sides = portrait top)

    @Test func landscapeTransformEncodesVerifiedShape() {
        #expect(SafeAreaCatalog.landscape(from: makeInsets(59, 34)) == makeLandscape(0, 21, 59))
        #expect(SafeAreaCatalog.landscape(from: makeInsets(62, 34)) == makeLandscape(0, 21, 62))
        #expect(SafeAreaCatalog.landscape(from: makeInsets(47, 34)) == makeLandscape(0, 21, 47))
    }

    @Test func seClassLandscapeStaysZeroInset() {
        // Classic 20/0 rows (no notch, no home indicator): landscape is fully zero-inset per the ASSUMED rows.
        #expect(SafeAreaCatalog.landscape(from: makeInsets(20, 0)) == makeLandscape(0, 0, 0))
        #expect(
            SafeAreaCatalog.insets(forDeviceName: "iPhone SE (3rd generation)",
                                   logicalSize: makeSize(375, 667), orientation: .landscape) == makeLandscape(0, 0, 0))
    }

    @Test func landscapeLookupAppliesTransformFor16Series() {
        #expect(
            SafeAreaCatalog.insets(forDeviceName: "iPhone 16", logicalSize: makeSize(393, 852),
                                   orientation: .landscape) == makeLandscape(0, 21, 59))
        #expect(
            SafeAreaCatalog.insets(forDeviceName: "iPhone 15", logicalSize: nil,
                                   orientation: .landscape) == makeLandscape(0, 21, 59))
    }

    // MARK: - Orientation Derivation

    @Test func orientationDerivesFromContentRectAspect() {
        #expect(OverlayGeometry.orientation(contentRect: CGRect(x: 0, y: 0, width: 393, height: 852)) == .portrait)
        #expect(OverlayGeometry.orientation(contentRect: CGRect(x: 10, y: 20, width: 852, height: 393)) == .landscape)
    }

    @Test func orientationRoundTripsThroughCatalogLookup() {
        // The service-facing entry point: a wide tracked content rect resolves landscape bands in one hop.
        let wideContentRect = CGRect(x: 0, y: 0, width: 852, height: 393)
        let orientation = OverlayGeometry.orientation(contentRect: wideContentRect)
        #expect(orientation == .landscape)
        #expect(
            SafeAreaCatalog.insets(forDeviceName: "iPhone 15", logicalSize: makeSize(393, 852),
                                   orientation: orientation) == makeLandscape(0, 21, 59))
    }

    // MARK: - iPad Fallback (ASSUMED rows)

    @Test func iPadFallbackResolvesPortraitAndLandscape() {
        #expect(
            SafeAreaCatalog.insets(forDeviceName: nil, logicalSize: makeSize(768, 1024),
                                   orientation: .portrait) == makeInsets(20, 20))
        let landscape = SafeAreaCatalog.insets(forDeviceName: "Unrecognized iPad",
                                               logicalSize: makeSize(768, 1024), orientation: .landscape)
        #expect(landscape.top == 0)
        #expect(landscape.left == 20)
        #expect(landscape.right == 20)
    }
}