// CommandFrameAssembler.swift — streaming reassembly of length-prefixed
// command frames across partial TCP reads.
// Compiled into BOTH targets (no simulator-only guard, unlike the rest of
// this folder): the framework client buffers split frames with it, and the
// macOS unit target regression-tests the exact reassembly semantics the
// client relies on (05 review CR-01). Wire contract mirrors the Mac-side
// CommandFrame codec: 4-byte big-endian UInt32 payload length + JSON body.
// A frame split across receives is normal stream behavior, never a reason
// to drop; only a declared length beyond the cap is malformed.
import Foundation

/// Accumulates raw receive bytes and yields complete length-prefixed frames.
/// Value type, not actor-confined: owners (BoosterCommandClient) confine it
/// to their serial queue.
struct CommandFrameAssembler {

    static let prefixLength = 4
    /// 10 MB safety cap — a declared length beyond this is malformed input.
    static let maxPayloadSize = 10 * 1024 * 1024

    enum FrameError: Error, Equatable {
        /// Declared length beyond the cap — caller drops the connection.
        case payloadTooLarge
    }

    private(set) var buffer = Data()

    /// Buffers the bytes of one receive for reassembly.
    mutating func append(_ bytes: Data) {
        buffer.append(bytes)
    }

    /// Returns the next complete frame, or nil while the leading frame is
    /// still split across receives (normal stream condition — the partial
    /// bytes stay buffered). The only thrown error is `.payloadTooLarge`.
    mutating func nextFrame() throws -> Data? {
        guard buffer.count >= Self.prefixLength else { return nil }
        // Copy into a re-based index space: a Data produced by removeFirst can
        // keep a non-zero startIndex, and raw offsets then trap (Data-slice
        // alignment trap — connect-transport-rewrite precedent).
        let bytes = [UInt8](buffer)
        var length = UInt32(0)
        for byte in bytes[0..<Self.prefixLength] {
            length = (length << 8) | UInt32(byte)
        }
        guard Int(length) <= Self.maxPayloadSize else { throw FrameError.payloadTooLarge }
        let totalLength = Self.prefixLength + Int(length)
        guard bytes.count >= totalLength else { return nil }
        let payload = Data(bytes[Self.prefixLength..<totalLength])
        buffer = Data(bytes[totalLength...])
        return payload
    }
}
