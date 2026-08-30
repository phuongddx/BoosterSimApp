// CaptureSettingsTests.swift — Capture option persistence and filename builder
import Foundation
import Testing
@testable import BoosterSimApp

struct CaptureSettingsTests {

    private func makeDefaults() throws -> (defaults: UserDefaults, suiteName: String) {
        let suiteName = "CaptureSettingsTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        return (defaults, suiteName)
    }

    // MARK: - Capture Keys Round-Trip

    @Test func captureKeysRoundTripAcrossAppSettingsReInit() throws {
        let (defaults, suiteName) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let first = AppSettings(defaults: defaults)
        first.captureDestination = .custom
        first.captureASCFramePreset = .ipad13x2048
        first.captureBezelMode = .drawn
        first.captureBackground = .gradient
        first.captureExportFormat = .mov
        first.captureGIFSize = 320
        first.captureGIFFps = 15
        first.captureShowTouchIndicators = true

        // Re-initialize from the same suite: persisted state must re-apply.
        let second = AppSettings(defaults: defaults)
        #expect(second.captureDestination == .custom)
        #expect(second.captureASCFramePreset == .ipad13x2048)
        #expect(second.captureBezelMode == .drawn)
        #expect(second.captureBackground == .gradient)
        #expect(second.captureExportFormat == .mov)
        #expect(second.captureGIFSize == 320)
        #expect(second.captureGIFFps == 15)
        #expect(second.captureShowTouchIndicators == true)
    }

    // MARK: - Custom Path Persistence

    @Test func customCaptureFolderPersistsAsPlainPathAcrossReInit() throws {
        let (defaults, suiteName) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let folder = URL(fileURLWithPath: "/tmp/booster-captures-\(UUID().uuidString)")
        let first = AppSettings(defaults: defaults)
        first.customCaptureFolder = folder
        #expect(first.customCaptureFolder == folder)

        let second = AppSettings(defaults: defaults)
        #expect(second.customCaptureFolder == folder)

        // Clearing removes the stored path entirely (nil round-trips too).
        second.customCaptureFolder = nil
        let third = AppSettings(defaults: defaults)
        #expect(third.customCaptureFolder == nil)
    }

    // MARK: - Filename Builder

    @MainActor
    @Test func captureFilenameSanitizesPathUnsafeCharacters() {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let name = CaptureFilename.captureFilename(
            device: "iPhone 16 Pro: Max/Test 2", preset: .iphone69x1320, date: date
        )

        #expect(!name.contains("/"))
        #expect(!name.contains(":"))
        #expect(!name.contains(" "))
        #expect(name.contains("iphone-16-pro-max-test-2"))
        #expect(name.hasPrefix("BoosterSim-"))
        #expect(name.hasSuffix(".png"))
    }

    @MainActor
    @Test func captureFilenameIsDeterministicPerInputs() {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let first = CaptureFilename.captureFilename(device: "iPhone 16 Pro", preset: .ipad13x2064, date: date)
        let second = CaptureFilename.captureFilename(device: "iPhone 16 Pro", preset: .ipad13x2064, date: date)
        #expect(first == second)
    }

    @MainActor
    @Test func captureFilenameAdvancesWithTheDate() {
        let earlier = CaptureFilename.captureFilename(device: "iPhone 16", preset: .iphone65x1242,
                                                     date: Date(timeIntervalSince1970: 1_700_000_000))
        let later = CaptureFilename.captureFilename(device: "iPhone 16", preset: .iphone65x1242,
                                                    date: Date(timeIntervalSince1970: 1_700_000_002))
        #expect(earlier != later)
    }
}
