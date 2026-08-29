// NetworkConditionProfile.swift — throttle profile presets + pure pacing math
import Foundation

// MARK: - Profile

/// Selectable network-speed presets for the Network tab. Values are chosen
/// approximations (research A2 — RocketSim names are the baseline, numbers are
/// ours), not compliance targets. Upload is approximated by the latency phase
/// in v1 (research A5 / Pitfall 8); `uploadKbps` stays nil until a later
/// schema needs it.
enum NetworkConditionProfile: String, Codable, CaseIterable, Identifiable {
    case off
    case edge
    case threeG
    case lte
    case wifi

    var id: String { rawValue }

    /// Short picker label (RocketSim naming baseline per research).
    var displayName: String {
        switch self {
        case .off: "Off"
        case .edge: "EDGE"
        case .threeG: "3G"
        case .lte: "LTE"
        case .wifi: "Wi-Fi"
        }
    }

    /// Latency + download-bandwidth spec, or nil when throttling is off.
    var throttleSpec: ThrottleSpec? {
        switch self {
        case .off: nil
        case .edge: ThrottleSpec(latencyMs: 800, downloadKbps: 200, uploadKbps: nil)
        case .threeG: ThrottleSpec(latencyMs: 400, downloadKbps: 750, uploadKbps: nil)
        case .lte: ThrottleSpec(latencyMs: 100, downloadKbps: 10000, uploadKbps: nil)
        case .wifi: ThrottleSpec(latencyMs: 20, downloadKbps: 25000, uploadKbps: nil)
        }
    }

    /// Picker caption like "3G · 400ms · 750 Kbps".
    var caption: String {
        guard let spec = throttleSpec else { return "No throttle" }
        return "\(displayName) · \(spec.latencyMs)ms · \(spec.downloadKbps) Kbps"
    }
}

// MARK: - Pacing Schedule

/// Pure pacing schedule: when the first response callback fires and when each
/// body chunk lands. Deterministic arithmetic on TimeInterval — no Date,
/// clock, queue, or sleep references. The framework-side ThrottlePacing
/// mirrors this math verbatim (schema-synced pair); these tests guard both.
///
/// Contract (plan 05-02 truths #1–#2):
/// `chunkInterval = chunkBytes * 8 / kbps` seconds, so completion lands at
/// `latencyMs + totalBytes * 8 / downloadKbps` within one chunk interval.
struct ThrottleSchedule: Equatable {
    /// Seconds before the first `didReceive` response callback.
    let firstByteDelay: TimeInterval
    /// Number of body chunks (`totalBytes / chunkBytes`, rounding up).
    let chunkCount: Int
    /// Seconds between consecutive chunk deliveries.
    let chunkInterval: TimeInterval
    /// Offset (seconds from pacing start) of the final chunk delivery.
    let lastChunkAt: TimeInterval

    /// Failable on invalid input (T-05-07): `downloadKbps <= 0`,
    /// `chunkBytes <= 0`, `totalBytes < 0`, or `latencyMs < 0` return nil —
    /// malformed wire specs are rejected, never trusted, never trapped.
    /// Zero latency (pure bandwidth pacing) and empty bodies (headers-only
    /// responses) stay valid.
    init?(spec: ThrottleSpec, chunkBytes: Int, totalBytes: Int) {
        guard spec.downloadKbps > 0, spec.latencyMs >= 0,
              chunkBytes > 0, totalBytes >= 0 else { return nil }

        firstByteDelay = TimeInterval(spec.latencyMs) / 1000
        chunkCount = totalBytes == 0 ? 0 : (totalBytes + chunkBytes - 1) / chunkBytes
        chunkInterval = TimeInterval(chunkBytes * 8) / TimeInterval(spec.downloadKbps)
        lastChunkAt = firstByteDelay + TimeInterval(chunkCount) * chunkInterval
    }
}
