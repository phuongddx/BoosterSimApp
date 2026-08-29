// ThrottlePacing.swift — framework-side paced-delivery helper for throttle enforcement
// Mirrors the Mac-side ThrottleSchedule math (BoosterSimApp/Models/
// NetworkConditionProfile.swift) verbatim — schema-synced pair guarded by
// NetworkConditionProfileTests on the Mac side.
// Loaded into Simulator app via Bundle.load() in DEBUG builds.
#if DEBUG && targetEnvironment(simulator)

import Foundation

/// Paced delivery scheduler: one instance per in-flight request. Holds a
/// serial queue that fires response + chunk callbacks at their computed
/// delivery times (research Pattern 4). NOT @MainActor — URLProtocol
/// callbacks arrive on session queues (Pitfall 6); all mutable state is
/// confined to the serial queue (`@unchecked Sendable` per Pulse's
/// NetworkDebugger precedent). Scheduling is bounded by response body size
/// and every pending item is dropped by `cancel()` from stopLoading (T-05-06).
final class ThrottlePacing: @unchecked Sendable {

    /// Delivery plan for one throttled response, computed from the mirrored
    /// Mac-side math.
    struct Plan {
        /// Seconds before the first `didReceive` response callback.
        let firstByteDelay: TimeInterval
        /// Offsets (seconds from pacing start) of each body-chunk delivery.
        let chunkDelays: [TimeInterval]
    }

    /// Mirrors ThrottleSchedule verbatim: `chunkInterval = chunkBytes * 8 /
    /// kbps` seconds; chunk j of chunkCount lands at
    /// `firstByteDelay + j * chunkInterval`, so completion equals
    /// `latencyMs + totalBytes * 8 / downloadKbps` (truths #1–#2). Returns
    /// nil for invalid specs (T-05-07) — callers degrade to unpaced delivery
    /// rather than trusting malformed input.
    static func plan(spec: ThrottleSpec, chunkBytes: Int, totalBytes: Int) -> Plan? {
        guard spec.downloadKbps > 0, spec.latencyMs >= 0,
              chunkBytes > 0, totalBytes >= 0 else { return nil }

        let firstByteDelay = TimeInterval(spec.latencyMs) / 1000
        let chunkCount = totalBytes == 0 ? 0 : (totalBytes + chunkBytes - 1) / chunkBytes
        let chunkInterval = TimeInterval(chunkBytes * 8) / TimeInterval(spec.downloadKbps)

        var chunkDelays: [TimeInterval] = []
        chunkDelays.reserveCapacity(chunkCount)
        if chunkCount > 0 {
            for chunk in 1...chunkCount {
                chunkDelays.append(firstByteDelay + TimeInterval(chunk) * chunkInterval)
            }
        }
        return Plan(firstByteDelay: firstByteDelay, chunkDelays: chunkDelays)
    }

    // MARK: - Properties

    /// Serial delivery queue; also the isolation domain for `pendingItems`.
    private let queue: DispatchQueue
    /// Pending scheduled items; only touched on `queue`.
    private var pendingItems: [DispatchWorkItem] = []

    // MARK: - Lifecycle

    init() {
        queue = DispatchQueue(label: "com.boostersimconnect.throttle.\(UUID().uuidString)")
    }

    // MARK: - Scheduling

    /// Schedules steps at fixed offsets from now. Each action runs on the
    /// serial queue; a step with an earlier offset enqueued earlier fires
    /// earlier, so response-then-chunks ordering holds by construction.
    /// A snapshot switch mid-download affects the NEXT request only — an
    /// already-scheduled plan is never mutated (snapshot semantics).
    func schedule(_ steps: [(delay: TimeInterval, action: () -> Void)]) {
        let start = DispatchTime.now()
        queue.async { [weak self] in
            guard let self else { return }
            for step in steps {
                let item = DispatchWorkItem(block: step.action)
                self.pendingItems.append(item)
                self.queue.asyncAfter(deadline: start + step.delay, execute: item)
            }
        }
    }

    /// Drops all pending paced work — called from stopLoading so a cancelled
    /// request never delivers further callbacks.
    func cancel() {
        queue.async { [weak self] in
            guard let self else { return }
            self.pendingItems.forEach { $0.cancel() }
            self.pendingItems.removeAll()
        }
    }
}

#endif
