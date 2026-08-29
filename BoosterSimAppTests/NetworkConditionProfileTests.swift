import Foundation
import Testing
@testable import BoosterSimApp

struct NetworkConditionProfileTests {

    // MARK: - Presets

    @Test func allFivePresetsExistWithExactSpecs() {
        #expect(NetworkConditionProfile.allCases.map(\.rawValue) == ["off", "edge", "threeG", "lte", "wifi"])
        #expect(NetworkConditionProfile.off.throttleSpec == nil)
        #expect(NetworkConditionProfile.edge.throttleSpec == ThrottleSpec(latencyMs: 800, downloadKbps: 200, uploadKbps: nil))
        #expect(NetworkConditionProfile.threeG.throttleSpec == ThrottleSpec(latencyMs: 400, downloadKbps: 750, uploadKbps: nil))
        #expect(NetworkConditionProfile.lte.throttleSpec == ThrottleSpec(latencyMs: 100, downloadKbps: 10000, uploadKbps: nil))
        #expect(NetworkConditionProfile.wifi.throttleSpec == ThrottleSpec(latencyMs: 20, downloadKbps: 25000, uploadKbps: nil))
    }

    // MARK: - Pacing Schedule

    @Test func threeGPacingScheduleOver15000Bytes() {
        let spec = ThrottleSpec(latencyMs: 400, downloadKbps: 750, uploadKbps: nil)
        let schedule = ThrottleSchedule(spec: spec, chunkBytes: 1500, totalBytes: 15000)

        #expect(schedule != nil)
        let pacing = schedule!
        #expect(pacing.firstByteDelay == TimeInterval(400) / 1000)
        #expect(pacing.chunkCount == 10)
        #expect(pacing.chunkInterval == TimeInterval(1500 * 8) / 750)
        // Truth #1 invariant: completion = latency + totalBytes * 8 / kbps.
        #expect(pacing.lastChunkAt == TimeInterval(400) / 1000 + TimeInterval(15000 * 8) / 750)
        #expect(pacing.lastChunkAt == pacing.firstByteDelay + TimeInterval(pacing.chunkCount) * pacing.chunkInterval)
    }

    @Test func chunkIntervalScalesInverselyWithKbps() {
        let base = ThrottleSchedule(
            spec: ThrottleSpec(latencyMs: 400, downloadKbps: 750, uploadKbps: nil),
            chunkBytes: 1500,
            totalBytes: 15000
        )!
        let doubledKbps = ThrottleSchedule(
            spec: ThrottleSpec(latencyMs: 400, downloadKbps: 1500, uploadKbps: nil),
            chunkBytes: 1500,
            totalBytes: 15000
        )!

        #expect(doubledKbps.chunkInterval == base.chunkInterval / 2)
        #expect(doubledKbps.lastChunkAt < base.lastChunkAt)

        // Partial trailing chunk rounds chunkCount up.
        let partial = ThrottleSchedule(
            spec: ThrottleSpec(latencyMs: 400, downloadKbps: 750, uploadKbps: nil),
            chunkBytes: 1500,
            totalBytes: 15001
        )!
        #expect(partial.chunkCount == 11)
    }

    @Test func pacingConstructorRejectsInvalidInput() {
        let valid = ThrottleSpec(latencyMs: 400, downloadKbps: 750, uploadKbps: nil)

        // Chosen behavior (T-05-07): failable init — reject, never trust, never trap.
        #expect(ThrottleSchedule(spec: ThrottleSpec(latencyMs: 400, downloadKbps: 0, uploadKbps: nil), chunkBytes: 1500, totalBytes: 15000) == nil)
        #expect(ThrottleSchedule(spec: ThrottleSpec(latencyMs: 400, downloadKbps: -5, uploadKbps: nil), chunkBytes: 1500, totalBytes: 15000) == nil)
        #expect(ThrottleSchedule(spec: ThrottleSpec(latencyMs: -1, downloadKbps: 750, uploadKbps: nil), chunkBytes: 1500, totalBytes: 15000) == nil)
        #expect(ThrottleSchedule(spec: valid, chunkBytes: 0, totalBytes: 15000) == nil)
        #expect(ThrottleSchedule(spec: valid, chunkBytes: -1500, totalBytes: 15000) == nil)
        #expect(ThrottleSchedule(spec: valid, chunkBytes: 1500, totalBytes: -1) == nil)

        // Degenerate-but-meaningful inputs stay valid: zero latency (pure
        // bandwidth pacing) and empty bodies (headers-only response).
        #expect(ThrottleSchedule(spec: ThrottleSpec(latencyMs: 0, downloadKbps: 750, uploadKbps: nil), chunkBytes: 1500, totalBytes: 15000) != nil)
        let headersOnly = ThrottleSchedule(spec: valid, chunkBytes: 1500, totalBytes: 0)
        #expect(headersOnly != nil)
        #expect(headersOnly!.chunkCount == 0)
        #expect(headersOnly!.lastChunkAt == headersOnly!.firstByteDelay)
    }

    // MARK: - Codable

    @Test func profileAndCustomSpecSurviveCodableRoundTrip() throws {
        for profile in NetworkConditionProfile.allCases {
            let data = try JSONEncoder().encode(profile)
            #expect(try JSONDecoder().decode(NetworkConditionProfile.self, from: data) == profile)
        }

        let custom = ThrottleSpec(latencyMs: 333, downloadKbps: 1234, uploadKbps: 567)
        let specData = try JSONEncoder().encode(custom)
        #expect(try JSONDecoder().decode(ThrottleSpec.self, from: specData) == custom)
    }

    // MARK: - Display Metadata

    @Test func presetsExposeDisplayNameAndCaption() {
        #expect(NetworkConditionProfile.allCases.map(\.displayName) == ["Off", "EDGE", "3G", "LTE", "Wi-Fi"])
        #expect(NetworkConditionProfile.allCases.allSatisfy { $0.id == $0.rawValue })

        #expect(NetworkConditionProfile.off.caption == "No throttle")
        #expect(NetworkConditionProfile.edge.caption == "EDGE · 800ms · 200 Kbps")
        #expect(NetworkConditionProfile.threeG.caption == "3G · 400ms · 750 Kbps")
        #expect(NetworkConditionProfile.lte.caption == "LTE · 100ms · 10000 Kbps")
        #expect(NetworkConditionProfile.wifi.caption == "Wi-Fi · 20ms · 25000 Kbps")
    }
}
