// BoosterCommand.swift — Command snapshot payload, framing codec, and pure verdict for the command channel
import Foundation

// MARK: - Guard Marker

/// Key for the URLProtocol property marking tool-internal requests that must
/// never be intercepted (anti-recursion, Pitfall 2). Also sent as a literal
/// header on inner pass-through requests as double defense.
enum BoosterInternalGuard {
    static let markerKey = "X-Booster-Internal"
}

// MARK: - Payload

/// Full-state condition snapshot pushed Mac → Simulator app. Idempotent: every
/// frame carries the complete desired state, so a lost frame self-heals on the
/// next push or reconnect reconcile.
struct BoosterCommand: Codable, Equatable {
    /// Current payload schema version. Bump on breaking change; clients ignore
    /// snapshots with unknown versions whole (no partial application).
    static let version = 1

    let version: Int
    var airplane: Bool
    var throttle: ThrottleSpec?
    var blockRules: [BlockRule]

    init(airplane: Bool = false, throttle: ThrottleSpec? = nil, blockRules: [BlockRule] = []) {
        self.version = Self.version
        self.airplane = airplane
        self.throttle = throttle
        self.blockRules = blockRules
    }

    /// Schema gate shared by both ends of the channel.
    static func isKnownVersion(_ version: Int) -> Bool {
        version == Self.version
    }
}

/// Throttle profile values. Upload is approximated by the latency phase in v1
/// (research A5/Pitfall 8); the field is kept for schema stability.
struct ThrottleSpec: Codable, Equatable {
    let latencyMs: Int
    let downloadKbps: Int
    let uploadKbps: Int?
}

// MARK: - Framing

/// Length-prefixed frame codec: 4-byte big-endian UInt32 payload length + body.
/// Pure value type — used by CommandServer; BoosterSimConnect carries a
/// schema-synced mirror (partial TCP reads never half-apply, Pitfall 11).
enum CommandFrame {

    static let prefixLength = 4
    /// 10 MB safety cap — a declared length beyond this is malformed input.
    static let maxPayloadSize = 10 * 1024 * 1024

    enum DecodeError: Error, Equatable {
        /// More bytes needed before a full frame is buffered.
        case incomplete
        /// Declared length beyond the cap — caller drops the connection.
        case payloadTooLarge
    }

    /// Encodes `payload` as a single length-prefixed frame.
    static func encode(_ payload: Data) -> Data {
        var frame = Data(capacity: prefixLength + payload.count)
        withUnsafeBytes(of: UInt32(payload.count).bigEndian) { frame.append(contentsOf: $0) }
        frame.append(payload)
        return frame
    }

    /// Decodes one frame from the front of `buffer`, removing it on success.
    /// Throws `.incomplete` when more bytes are needed and `.payloadTooLarge`
    /// when the declared length violates the cap.
    static func decodeOne(from buffer: inout Data) throws -> Data {
        guard buffer.count >= prefixLength else { throw DecodeError.incomplete }
        // Copy into a re-based index space: a Data produced by removeFirst can
        // keep a non-zero startIndex, and subdata(in:)/raw offsets then trap
        // (the Data-slice alignment trap — connect-transport-rewrite precedent).
        let bytes = [UInt8](buffer)
        var length = UInt32(0)
        for byte in bytes[0..<prefixLength] {
            length = (length << 8) | UInt32(byte)
        }
        guard Int(length) <= maxPayloadSize else { throw DecodeError.payloadTooLarge }
        let totalLength = prefixLength + Int(length)
        guard bytes.count >= totalLength else { throw DecodeError.incomplete }
        let payload = Data(bytes[prefixLength..<totalLength])
        buffer = Data(bytes[totalLength...])
        return payload
    }
}

// MARK: - Verdict

/// Enforcement decision for a request under a condition snapshot.
enum ConditionVerdict: Equatable {
    case passThrough
    case fail(URLError.Code)
    /// Pace this request per the spec: latency delay before the first
    /// response callback, then chunked body delivery (plan 05-02).
    case throttle(ThrottleSpec)
}

/// Pure, synchronous decision function. Order is contract: guard marker
/// first (anti-recursion), then airplane
/// (`NSURLErrorNotConnectedToInternet`, -1009), then first enabled matching
/// rule (`NSURLErrorCannotConnectToHost`, -1004), then throttle (when a
/// spec is set), then pass-through.
func evaluate(request: URLRequest, snapshot: BoosterCommand) -> ConditionVerdict {
    if URLProtocol.property(forKey: BoosterInternalGuard.markerKey, in: request) != nil {
        return .passThrough
    }
    if snapshot.airplane {
        return .fail(.notConnectedToInternet)
    }
    if snapshot.blockRules.first(where: { $0.isEnabled && $0.matches(request) }) != nil {
        return .fail(.cannotConnectToHost)
    }
    if let throttle = snapshot.throttle {
        return .throttle(throttle)
    }
    return .passThrough
}
