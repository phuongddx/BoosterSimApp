// PushPayload.swift — simctl push payload model, validation gate, typed parse errors, send result
import Foundation

// MARK: - Payload

/// A simulated remote-notification payload for `simctl push <udid> <bundle> -` (stdin).
/// Shape per the verified verb spec (03-RESEARCH): top-level object, required `aps` key,
/// ≤4096 encoded bytes; the optional "Simulator Target Bundle" top-level key may carry the
/// target when the bundle arg is "-". No persistence — Codable purity only.
struct PushPayload: Codable, Equatable {

    struct Aps: Codable, Equatable {
        var alert: String?
        var badge: Int?
        var sound: String?
    }

    /// simctl's hard cap on the encoded payload (verified verb spec).
    static let maxEncodedBytes = 4096

    var aps: Aps
    var simulatorTargetBundle: String?

    enum CodingKeys: String, CodingKey {
        case aps
        case simulatorTargetBundle = "Simulator Target Bundle"
    }

    init(aps: Aps, simulatorTargetBundle: String? = nil) {
        self.aps = aps
        self.simulatorTargetBundle = simulatorTargetBundle
    }
}

// MARK: - Errors

/// Typed validation/parse failures — every rejectable input maps to a case; no crash path.
enum PushPayloadError: Error, Equatable {
    case emptyInput
    case invalidJSON          // text is not JSON at all
    case notObject            // valid JSON, but the root is not an object
    case missingAPS           // object without the required aps key
    case invalidShape         // values do not decode into the payload shape
    case unsupportedKeys([String])   // keys outside the supported set — sending would silently drop them
    case tooLarge(Int)        // encoded byte count over the cap

    var message: String {
        switch self {
        case .emptyInput:
            return "The payload is empty."
        case .invalidJSON:
            return "The text is not valid JSON."
        case .notObject:
            return "The payload's root must be a JSON object."
        case .missingAPS:
            return "The payload is missing the required \"aps\" key."
        case .invalidShape:
            return "Values do not match the expected shape — \"aps\" needs string alert, "
                + "integer badge, string sound; \"Simulator Target Bundle\" a string."
        case .unsupportedKeys(let keys):
            let names = keys.map { "\"\($0)\"" }.joined(separator: ", ")
            return "Unsupported key(s) \(names) — delivered pushes must match the editor text, "
                + "so only \"alert\", \"badge\", \"sound\" inside \"aps\" and the top-level "
                + "\"Simulator Target Bundle\" are supported."
        case .tooLarge(let size):
            return "The payload is \(size) bytes — simctl rejects anything over "
                + "\(PushPayload.maxEncodedBytes)."
        }
    }
}

// MARK: - Parse & Validate

extension PushPayload {

    /// Parses editor text into a payload. JSONSerialization guards the top-level shape
    /// (object + aps present) so failures map to precise typed errors; JSONDecoder then
    /// decodes the strict struct shape. Never throws, never crashes.
    static func parse(_ text: String) -> Result<PushPayload, PushPayloadError> {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .failure(.emptyInput) }
        guard let data = trimmed.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
        else { return .failure(.invalidJSON) }
        guard let object = root as? [String: Any] else { return .failure(.notObject) }
        guard object.keys.contains("aps") else { return .failure(.missingAPS) }
        // 03-REVIEW WR-04: the sender re-encodes the strict struct, so any key outside the
        // supported set would be SILENTLY DROPPED in flight — the delivered push would differ
        // from the editor text. Reject instead: what-you-see is what-arrives.
        let supportedAps: Set<String> = ["alert", "badge", "sound"]
        let supportedTopLevel: Set<String> = ["aps", "Simulator Target Bundle"]
        if let apsObject = object["aps"] as? [String: Any] {
            let unknown = Set(apsObject.keys).subtracting(supportedAps)
                .union(Set(object.keys).subtracting(supportedTopLevel))
            if !unknown.isEmpty { return .failure(.unsupportedKeys(unknown.sorted())) }
        }
        do {
            return .success(try JSONDecoder().decode(PushPayload.self, from: data))
        } catch {
            return .failure(.invalidShape)
        }
    }

    /// Pure validation gate, measured on JSONEncoder output bytes (the bytes actually sent).
    /// Pass the count when the caller already encoded; nil encodes internally.
    func validate(encodedByteCount: Int? = nil) -> PushPayloadError? {
        let size = encodedByteCount ?? (try? JSONEncoder().encode(self).count) ?? 0
        return size > Self.maxEncodedBytes ? .tooLarge(size) : nil
    }

    /// UTF-8 byte count of editor text — the live counter's source of truth.
    static func encodedByteCount(of text: String) -> Int {
        text.utf8.count
    }
}

// MARK: - Template Presets

extension PushPayload {

    /// Preset pill payloads — encode under the size gate and re-parse identically.
    static func templateAlert() -> PushPayload {
        PushPayload(aps: .init(alert: "Hello from BoosterSim"))
    }

    static func templateAlertSound() -> PushPayload {
        PushPayload(aps: .init(alert: "Hello from BoosterSim", sound: "default"))
    }

    static func templateBadgeAlert() -> PushPayload {
        PushPayload(aps: .init(alert: "You have new content", badge: 3))
    }
}

// MARK: - Send Result

/// Terminal outcome of a push send — simctl's own summary line, or a typed failure caption.
enum PushActionResult: Equatable {
    case sent(String)
    case failed(String)
}
