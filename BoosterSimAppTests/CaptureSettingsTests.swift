// CaptureSettingsTests.swift — Capture option persistence, filename builder, touch-indicator restore machine
import CoreFoundation
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

    // MARK: - Touch Indicator State Machine

    @Test func touchIndicatorStateAllowsExpectedTransitions() {
        #expect(TouchIndicatorState.idle.canTransition(to: .applying))
        #expect(TouchIndicatorState.applying.canTransition(to: .active))
        #expect(TouchIndicatorState.active.canTransition(to: .restoring))
        #expect(TouchIndicatorState.restoring.canTransition(to: .idle))
        #expect(TouchIndicatorState.applying.canTransition(to: .error("failed")))
        #expect(TouchIndicatorState.restoring.canTransition(to: .error("failed")))
        #expect(TouchIndicatorState.error("failed").canTransition(to: .applying))
        #expect(!TouchIndicatorState.idle.canTransition(to: .active))
        #expect(!TouchIndicatorState.idle.canTransition(to: .restoring))
        #expect(!TouchIndicatorState.applying.canTransition(to: .restoring))
    }

    @Test func touchIndicatorIsWorkingWhileHoldingOrTransitioning() {
        #expect(TouchIndicatorState.applying.isWorking)
        #expect(TouchIndicatorState.active.isWorking)
        #expect(TouchIndicatorState.restoring.isWorking)
        #expect(!TouchIndicatorState.idle.isWorking)
        #expect(!TouchIndicatorState.error("x").isWorking)
    }

    // MARK: - Touch Preference Constants

    @Test func productionPreferenceConstantsMatchSimulatorDomain() {
        #expect(TouchIndicatorController.preferenceDomain == "com.apple.iphonesimulator")
        #expect(TouchIndicatorController.preferenceKey == "ShowSingleTouches")
    }

    // MARK: - Touch Indicator Restore Semantics

    @MainActor
    @Test func doubleEnableWhileActiveIsRefused() throws {
        let controller = TouchIndicatorController(store: InMemoryTouchStore())
        controller.enable()
        controller.enable()
        #expect(controller.state == .active)
    }

    @MainActor
    @Test func restoreSemanticsCoverTrueFalseAndUnset() throws {
        // Previously true: override then restore lands back on true.
        let trueStore = InMemoryTouchStore()
        trueStore.set(true)
        let trueController = TouchIndicatorController(store: trueStore)
        trueController.enable()
        #expect(trueStore.bool() == true)
        trueController.restore()
        #expect(trueController.state == .idle)
        #expect(trueStore.bool() == true)

        // Previously false: restore lands back on false, not on unset.
        let falseStore = InMemoryTouchStore()
        falseStore.set(false)
        let falseController = TouchIndicatorController(store: falseStore)
        falseController.enable()
        #expect(falseStore.bool() == true)
        falseController.restore()
        #expect(falseStore.bool() == false)

        // Previously unset: restore clears the key entirely (kCFNull sentinel).
        let unsetStore = InMemoryTouchStore()
        let unsetController = TouchIndicatorController(store: unsetStore)
        unsetController.enable()
        #expect(unsetStore.bool() == true)
        unsetController.restore()
        #expect(unsetStore.bool() == nil)
    }

    @MainActor
    @Test func erroredSessionStillRestoresTheSnapshot() throws {
        let store = InMemoryTouchStore()
        store.set(false)
        store.failNextSynchronize = true
        let controller = TouchIndicatorController(store: store)
        controller.enable()
        if case .error = controller.state {} else {
            Issue.record("expected error state after synchronize failure")
        }
        #expect(store.bool() == false)
    }
}

/// Isolated in-memory preference store — Simulator's real domain is never touched.
private final class InMemoryTouchStore: TouchPreferencesStore {
    private var values: [String: Any?] = [:]
    /// Single-shot failure injection for the errored-session restore test.
    var failNextSynchronize = false

    func copyValue(forKey key: String, domain: String) -> Any? {
        values[key].flatMap { $0 }
    }

    func setValue(_ value: Any?, forKey key: String, domain: String) {
        // Identity compare — `is CFNull` compiles to always-true for CF types.
        if let value, (value as AnyObject) !== (kCFNull as AnyObject) {
            values[key] = value
        } else {
            values.removeValue(forKey: key)
        }
    }

    func synchronize(domain: String) -> Bool {
        if failNextSynchronize {
            failNextSynchronize = false
            return false
        }
        return true
    }

    // Typed test helpers
    func set(_ value: Bool) {
        setValue(NSNumber(value: value), forKey: TouchIndicatorController.preferenceKey,
                 domain: TouchIndicatorController.preferenceDomain)
    }

    func bool() -> Bool? {
        (copyValue(forKey: TouchIndicatorController.preferenceKey,
                   domain: TouchIndicatorController.preferenceDomain) as? NSNumber)?.boolValue
    }
}
