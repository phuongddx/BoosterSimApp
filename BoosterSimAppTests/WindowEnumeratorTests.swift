// WindowEnumeratorTests.swift — CGWindowList dictionary → SimulatorWindow parse contract
// Synthetic fixtures only (never the live window list — no Screen Recording dependency).
// Excludes enumerateSimulatorWindows() — it scans live on-screen windows (needs a booted Simulator).
// @MainActor: parseSimulatorWindow reads NSScreen.main for the Quartz→AppKit Y flip.
import AppKit
import CoreGraphics
import Foundation
import Testing
@testable import BoosterSimApp

@MainActor
struct WindowEnumeratorTests {

    /// Valid CGWindowList-shaped dictionary: 800×600 window at Quartz (100, 50).
    private func validWindow(
        owner: String = "Simulator",
        layer: Int = 0,
        bounds: [String: CGFloat]? = ["X": 100, "Y": 50, "Width": 800, "Height": 600],
        includeWindowID: Bool = true,
        includePID: Bool = true
    ) -> [String: Any] {
        var info: [String: Any] = [
            kCGWindowOwnerName as String: owner,
            kCGWindowLayer as String: layer,
        ]
        if let bounds { info[kCGWindowBounds as String] = bounds }
        if includeWindowID { info[kCGWindowNumber as String] = CGWindowID(42) }
        if includePID { info[kCGWindowOwnerPID as String] = pid_t(1234) }
        return info
    }

    // MARK: - Accept Path

    @Test func validDictionaryParsesWithFlippedY() throws {
        let window = try #require(WindowEnumerator.parseSimulatorWindow(from: validWindow()))
        // Quartz (Y=0 at top) → AppKit (Y=0 at bottom), flipped against the live primary height
        let primaryHeight = NSScreen.main?.frame.height ?? 0
        #expect(window.frame == CGRect(x: 100, y: primaryHeight - 50 - 600, width: 800, height: 600))
        #expect(window.id == 42)
        #expect(window.pid == 1234)
        #expect(window.isOnScreen)
        #expect(!window.isMinimized)
    }

    @Test func missingWindowNameDegradesToNilDeviceName() throws {
        // No kCGWindowName key — the no-Screen-Recording degradation passes through as nil
        var info = validWindow()
        #expect(!info.keys.contains(kCGWindowName as String))
        let window = try #require(WindowEnumerator.parseSimulatorWindow(from: info))
        #expect(window.deviceName == nil)
        #expect(window.displayName == "Simulator (ID: 42)")
    }

    // MARK: - Rejection Rules

    @Test func rejectsNonSimulatorOwner() {
        #expect(WindowEnumerator.parseSimulatorWindow(from: validWindow(owner: "Finder")) == nil)
    }

    @Test func rejectsNonZeroLayer() {
        // Menu-bar items and overlays live on non-zero layers
        #expect(WindowEnumerator.parseSimulatorWindow(from: validWindow(layer: 25)) == nil)
    }

    @Test func rejectsMissingWindowID() {
        #expect(WindowEnumerator.parseSimulatorWindow(from: validWindow(includeWindowID: false)) == nil)
    }

    @Test func rejectsMissingOwnerPID() {
        #expect(WindowEnumerator.parseSimulatorWindow(from: validWindow(includePID: false)) == nil)
    }

    @Test func rejectsMissingBoundsDictionary() {
        #expect(WindowEnumerator.parseSimulatorWindow(from: validWindow(bounds: nil)) == nil)
    }

    // MARK: - Size Gate

    @Test func rejectsExactlyFiftyByFifty() {
        // Strictly-greater contract: 50×50 (menu bar icon scale) is rejected
        let info = validWindow(bounds: ["X": 0, "Y": 0, "Width": 50, "Height": 50])
        #expect(WindowEnumerator.parseSimulatorWindow(from: info) == nil)
    }

    @Test func acceptsFiftyOneByFiftyOne() throws {
        let info = validWindow(bounds: ["X": 0, "Y": 0, "Width": 51, "Height": 51])
        let window = try #require(WindowEnumerator.parseSimulatorWindow(from: info))
        #expect(window.frame.width == 51 && window.frame.height == 51)
    }
}
