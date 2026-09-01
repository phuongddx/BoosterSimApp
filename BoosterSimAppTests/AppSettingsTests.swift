// AppSettingsTests.swift — Persisted-settings contract over an injected UserDefaults suite
// Excludes setLaunchAtLogin — it writes .standard AND drives SMAppService.mainApp on the test
// host (would register a real login item on this machine).
import Foundation
import Testing
@testable import BoosterSimApp

struct AppSettingsTests {

    /// Isolated suite: wiped on entry (leftover-plist guard) and removed on exit — no .standard pollution.
    private func withIsolatedDefaults(_ body: (UserDefaults) -> Void) {
        let suiteName = "AppSettingsTests-isolated"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            Issue.record("Could not create isolated defaults suite")
            return
        }
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }
        body(defaults)
    }

    // MARK: - Fresh-Suite Defaults

    @Test func freshSuiteYieldsCaptureDefaults() {
        withIsolatedDefaults { defaults in
            let settings = AppSettings(defaults: defaults)
            #expect(settings.captureDestination == .desktop)
            #expect(settings.captureExportFormat == .mp4)
            #expect(settings.captureGIFSize == 480)
            #expect(settings.captureGIFFps == 10)
            #expect(settings.captureShowTouchIndicators == false)
        }
    }

    // MARK: - Write-Then-Read Round-Trips (each capture key, re-read via a fresh instance)

    @Test func captureKeysRoundTripThroughTheSuite() {
        withIsolatedDefaults { defaults in
            let writer = AppSettings(defaults: defaults)
            writer.captureDestination = .custom
            writer.captureASCFramePreset = .ipad13x2048
            writer.captureBezelMode = .drawn
            writer.captureBackground = .gradient
            writer.captureExportFormat = .gif
            writer.captureGIFSize = 720
            writer.captureGIFFps = 15
            writer.captureShowTouchIndicators = true

            // A fresh instance reads the persisted values — proves suite persistence, not in-memory echo
            let reader = AppSettings(defaults: defaults)
            #expect(reader.captureDestination == .custom)
            #expect(reader.captureASCFramePreset == .ipad13x2048)
            #expect(reader.captureBezelMode == .drawn)
            #expect(reader.captureBackground == .gradient)
            #expect(reader.captureExportFormat == .gif)
            #expect(reader.captureGIFSize == 720)
            #expect(reader.captureGIFFps == 15)
            #expect(reader.captureShowTouchIndicators == true)
        }
    }

    @Test func nonCaptureKeysRoundTripThroughTheSuite() {
        withIsolatedDefaults { defaults in
            let writer = AppSettings(defaults: defaults)
            writer.position = .left
            writer.showSideWindow = false
            writer.xcodePath = "/Applications/Xcode.app"

            let reader = AppSettings(defaults: defaults)
            #expect(reader.position == .left)
            #expect(reader.showSideWindow == false)
            #expect(reader.xcodePath == "/Applications/Xcode.app")
        }
    }

    // MARK: - Custom Capture Folder

    @Test func customCaptureFolderSetGetNilCycle() {
        withIsolatedDefaults { defaults in
            let settings = AppSettings(defaults: defaults)
            #expect(settings.customCaptureFolder == nil)

            let folder = URL(fileURLWithPath: "/tmp/booster-caps")
            settings.customCaptureFolder = folder
            #expect(settings.customCaptureFolder == folder)

            settings.customCaptureFolder = nil
            #expect(settings.customCaptureFolder == nil)
        }
    }

    // MARK: - Pure Data Contracts (raw values are final persistence keys)

    @Test func sideWindowPositionContractIsStable() {
        #expect(!SideWindowPosition.allCases.isEmpty)
        #expect(SideWindowPosition.allCases.map(\.rawValue) == ["left", "right", "bottom", "dynamic"])
        for position in SideWindowPosition.allCases {
            #expect(!position.label.isEmpty)
            #expect(!position.icon.isEmpty)
        }
    }

    @Test func captureExportFormatContractIsStable() {
        #expect(!CaptureExportFormat.allCases.isEmpty)
        #expect(CaptureExportFormat.allCases.map(\.rawValue) == ["gif", "mp4", "mov"])
        for format in CaptureExportFormat.allCases {
            #expect(!format.label.isEmpty)
        }
    }

    @Test func captureDestinationKindContractIsStable() {
        #expect(!CaptureDestinationKind.allCases.isEmpty)
        #expect(CaptureDestinationKind.allCases.map(\.rawValue) == ["desktop", "clipboard", "custom", "ask"])
        for kind in CaptureDestinationKind.allCases {
            #expect(!kind.label.isEmpty)
        }
    }
}
