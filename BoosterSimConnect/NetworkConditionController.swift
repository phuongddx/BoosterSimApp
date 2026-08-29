// NetworkConditionController.swift — framework-side snapshot store (schema-synced mirror of Mac-side payloads)
// Loaded into Simulator app via Bundle.load() in DEBUG builds.
#if DEBUG && targetEnvironment(simulator)

import Foundation

// MARK: - Schema Mirror
// The framework cannot import the Mac app target. These definitions mirror
// BoosterSimApp/Models/{BoosterCommand,BlockRule}.swift byte-for-byte in
// semantics; CommandPayloadTests on the Mac side guards the shared contract.

struct BoosterCommand: Codable, Equatable {
    static let version = 1

    let version: Int
    let airplane: Bool
    let throttle: ThrottleSpec?
    let blockRules: [BlockRule]

    static func isKnownVersion(_ version: Int) -> Bool {
        version == BoosterCommand.version
    }
}

struct ThrottleSpec: Codable, Equatable {
    let latencyMs: Int
    let downloadKbps: Int
    let uploadKbps: Int?
}

struct BlockRule: Codable, Identifiable, Equatable {
    let id: UUID
    var domain: String
    var pathPrefix: String?
    var isEnabled: Bool = true

    func matches(_ request: URLRequest) -> Bool {
        guard let url = request.url, let host = url.host?.lowercased() else { return false }
        let path = url.path

        let pattern = domain.lowercased()
        if pattern.hasPrefix("*.") {
            let base = pattern.dropFirst(2)
            if host != base && !host.hasSuffix("." + base) { return false }
        } else {
            if host != pattern { return false }
        }

        if let prefix = pathPrefix, !prefix.isEmpty {
            return path.hasPrefix(prefix)
        }
        return true
    }
}

// MARK: - Verdict Mirror

enum ConditionVerdict: Equatable {
    case passThrough
    case fail(URLError.Code)
    /// Pace this request per the spec: latency delay before the first
    /// response callback, then chunked body delivery (plan 05-02).
    case throttle(ThrottleSpec)
}

/// Marker for tool-internal requests that must never be intercepted
/// (anti-recursion, Pitfall 2). Mirrors the Mac-side constant.
enum BoosterInternalGuard {
    static let markerKey = "X-Booster-Internal"
}

/// Same decision order as the Mac-side pure evaluate: guard marker, airplane
/// (NSURLErrorNotConnectedToInternet, -1009), first enabled matching rule
/// (NSURLErrorCannotConnectToHost, -1004), throttle (when a spec is set),
/// then pass-through. Named `evaluateCondition` (not `evaluate`) so it never
/// collides with the controller method of the same shape.
func evaluateCondition(request: URLRequest, snapshot: BoosterCommand) -> ConditionVerdict {
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

// MARK: - Controller

/// Lock-protected snapshot store consulted by BoosterNetworkProtocol from
/// URLSession session queues. NOT @MainActor — URLProtocol callbacks arrive
/// off-main (Pitfall 6). `@unchecked Sendable` is justified: the single
/// stored property is only touched while holding `lock` (Pulse's
/// NetworkDebugger precedent).
final class NetworkConditionController: @unchecked Sendable {

    static let shared = NetworkConditionController()

    private let lock = NSLock()
    private var snapshotValue: BoosterCommand?

    private init() {}

    var snapshot: BoosterCommand? {
        lock.lock()
        defer { lock.unlock() }
        return snapshotValue
    }

    /// Applies a snapshot only when its schema version is known; unknown
    /// versions are ignored whole — never partially applied.
    func update(_ command: BoosterCommand) {
        guard BoosterCommand.isKnownVersion(command.version) else { return }
        lock.lock()
        defer { lock.unlock() }
        snapshotValue = command
    }

    func evaluate(request: URLRequest) -> ConditionVerdict {
        guard let snapshot else { return .passThrough }
        return evaluateCondition(request: request, snapshot: snapshot)
    }
}

#endif
