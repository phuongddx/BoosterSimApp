// PushPayloadTests.swift — Push payload encode/validate contract incl. the 4096-byte gate (SC2)
import Foundation
import Testing
@testable import BoosterSimApp

/// Locks the `simctl push` payload contract (03-RESEARCH Verified Surface): top-level object,
/// required `aps` key, ≤4096 encoded bytes, verbatim "Simulator Target Bundle" top-level key.
/// Validation is airtight before any subprocess runs (threat T-03-12).
struct PushPayloadTests {

    // MARK: - Encode Round-Trip

    @Test func encodeRoundTripMapsAllApsFieldsAndTargetBundleKey() throws {
        let payload = PushPayload(
            aps: .init(alert: "Hello", badge: 3, sound: "default"),
            simulatorTargetBundle: "com.example.app"
        )

        let data = try JSONEncoder().encode(payload)
        let object = try #require(
            (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        )
        // CodingKeys pin the verbatim top-level key — never "simulatorTargetBundle".
        #expect(object["Simulator Target Bundle"] as? String == "com.example.app")
        #expect(object["simulatorTargetBundle"] == nil)
        #expect((object["aps"] as? [String: Any])?.count == 3)

        let decoded = try JSONDecoder().decode(PushPayload.self, from: data)
        #expect(decoded == payload)
    }

    @Test func minimalPayloadDecodesFromUserJSON() throws {
        let payload = try #require(
            try? JSONDecoder().decode(PushPayload.self, from: Data(#"{"aps":{"alert":"Hi"}}"#.utf8))
        )
        #expect(payload.aps.alert == "Hi")
        #expect(payload.aps.badge == nil)
        #expect(payload.aps.sound == nil)
        #expect(payload.simulatorTargetBundle == nil)
    }

    // MARK: - Validation Gate

    @Test func validateAcceptsWellFormedMinimalPayload() throws {
        let payload = PushPayload(aps: .init(alert: "Hi"))
        let encoded = try JSONEncoder().encode(payload)
        #expect(payload.validate(encodedByteCount: encoded.count) == nil)
        #expect(payload.validate() == nil)
    }

    @Test func validateEnforcesTheByteCapAtTheExactBoundary() throws {
        #expect(try payloadWithEncodedSize(4095).validate() == nil)   // just under the cap
        #expect(try payloadWithEncodedSize(4096).validate() == nil)   // at the cap (≤ 4096)
        if case .tooLarge(let size)? = try payloadWithEncodedSize(4097).validate() {
            #expect(size == 4097)
        } else {
            Issue.record("expected .tooLarge(4097) at one byte over the cap")
        }
    }

    // MARK: - Parse Gate (typed errors, never a crash)

    @Test func parseRejectsEmptyInput() {
        if case .failure(.emptyInput) = PushPayload.parse("") {} else {
            Issue.record("expected .emptyInput for empty text")
        }
        if case .failure(.emptyInput) = PushPayload.parse("   \n  ") {} else {
            Issue.record("expected .emptyInput for whitespace-only text")
        }
    }

    @Test func parseRejectsNonObjectRoots() {
        if case .failure(.notObject) = PushPayload.parse("[1,2,3]") {} else {
            Issue.record("expected .notObject for an array root")
        }
        if case .failure(.notObject) = PushPayload.parse("\"just a string\"") {} else {
            Issue.record("expected .notObject for a string root")
        }
        if case .failure(.notObject) = PushPayload.parse("42") {} else {
            Issue.record("expected .notObject for a number root")
        }
    }

    @Test func parseRejectsPayloadsMissingTheAPSKey() {
        if case .failure(.missingAPS) = PushPayload.parse(#"{"Simulator Target Bundle":"com.x"}"#) {} else {
            Issue.record("expected .missingAPS when the aps key is absent")
        }
    }

    @Test func parseRejectsMalformedJSONWithTheTypedError() {
        if case .failure(.invalidJSON) = PushPayload.parse("{oops") {} else {
            Issue.record("expected .invalidJSON for malformed text (never a crash)")
        }
    }

    @Test func parseRejectsWrongShapedValues() {
        if case .failure(.invalidShape) = PushPayload.parse(#"{"aps":"text"}"#) {} else {
            Issue.record("expected .invalidShape when aps is not an object")
        }
    }

    // MARK: - Unknown-Key Rejection (03-REVIEW WR-04 — delivered payload must equal editor text)

    /// A valid APNs key the editor does not support (e.g. mutable-content) would be silently
    /// stripped by the strict re-encode — parse must reject it with the typed error instead.
    @Test func parseRejectsUnknownApsKeysInsteadOfSilentlyStrippingThem() {
        if case .failure(.unsupportedKeys(let keys)) =
            PushPayload.parse(#"{"aps":{"alert":"x","mutable-content":1}}"#) {
            #expect(keys == ["mutable-content"])
        } else {
            Issue.record("expected .unsupportedKeys for an unknown aps key")
        }
    }

    @Test func parseRejectsUnknownTopLevelKeys() {
        if case .failure(.unsupportedKeys(let keys)) =
            PushPayload.parse(#"{"aps":{"alert":"x"},"custom":{"id":5}}"#) {
            #expect(keys == ["custom"])
        } else {
            Issue.record("expected .unsupportedKeys for an unknown top-level key")
        }
    }

    @Test func parseAcceptsTheFullSupportedFieldSet() {
        let json = #"{"aps":{"alert":"x","badge":2,"sound":"default"},"Simulator Target Bundle":"com.example.app"}"#
        if case .success(let payload) = PushPayload.parse(json) {
            #expect(payload.aps.alert == "x")
            #expect(payload.aps.badge == 2)
            #expect(payload.aps.sound == "default")
            #expect(payload.simulatorTargetBundle == "com.example.app")
        } else {
            Issue.record("the fully supported field set must parse cleanly")
        }
    }

    @Test func parseAcceptsAWellFormedPayload() {
        if case .success(let payload) = PushPayload.parse(#"{"aps":{"alert":"Hi","badge":1}}"#) {
            #expect(payload.aps.alert == "Hi")
            #expect(payload.aps.badge == 1)
        } else {
            Issue.record("expected success for a well-formed payload")
        }
    }

    // MARK: - Template Presets

    @Test func templatePresetsEncodeToValidPayloadsUnderTheSizeGate() throws {
        let templates = [
            PushPayload.templateAlert(),
            PushPayload.templateAlertSound(),
            PushPayload.templateBadgeAlert()
        ]
        for template in templates {
            let encoded = try JSONEncoder().encode(template)
            #expect(!encoded.isEmpty)
            #expect(encoded.count <= PushPayload.maxEncodedBytes)
            #expect(template.validate(encodedByteCount: encoded.count) == nil)
            // The template text re-parses cleanly — what the preset pill inserts stays valid.
            if case .success(let reparsed) = PushPayload.parse(String(data: encoded, encoding: .utf8) ?? "") {
                #expect(reparsed == template)
            } else {
                Issue.record("template text must re-parse to the same payload")
            }
        }
    }

    // MARK: - Byte Count Helper (live counter source)

    @Test func encodedByteCountCountsUTF8Bytes() {
        #expect(PushPayload.encodedByteCount(of: "") == 0)
        #expect(PushPayload.encodedByteCount(of: "abcd") == 4)
        #expect(PushPayload.encodedByteCount(of: "héllo") == 6)  // é is 2 UTF-8 bytes
        #expect(PushPayload.maxEncodedBytes == 4096)
    }

    // MARK: - Helpers

    /// Builds a payload whose JSONEncoder output is EXACTLY `target` bytes: encoded size grows
    /// 1:1 with the alert length above the empty-alert skeleton, so padding is deterministic.
    private func payloadWithEncodedSize(_ target: Int) throws -> PushPayload {
        let skeleton = PushPayload(aps: .init(alert: ""))
        let base = try JSONEncoder().encode(skeleton).count
        let padding = target - base
        #expect(padding >= 0, "target \(target) is below the skeleton size \(base)")
        let payload = PushPayload(aps: .init(alert: String(repeating: "a", count: padding)))
        let size = try JSONEncoder().encode(payload).count
        #expect(size == target, "encoded \(size), wanted exactly \(target)")
        return payload
    }
}
