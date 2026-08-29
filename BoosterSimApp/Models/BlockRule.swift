// BlockRule.swift — Domain/path block rule with pure string-only matching
import Foundation

/// A request-blocking rule. `domain` is an exact host (`"api.example.com"`)
/// or a wildcard suffix (`"*.example.com"`); `pathPrefix` optionally narrows
/// the match to a URL path prefix (`"/api"`).
struct BlockRule: Codable, Identifiable, Equatable {
    let id: UUID
    var domain: String
    var pathPrefix: String?
    var isEnabled: Bool = true

    /// Pure matcher using ONLY string operations on URL host/path — no regex
    /// compilation ever (ReDoS impossible by construction; threat T-05-02).
    /// Host comparison is case-insensitive; nil-host requests never match.
    /// Disabled rules and empty/whitespace-only domains never match
    /// (defensive: no accidental match-all, threat T-05-08). Rule fields are
    /// trimmed here so both the UI and the decode path are safe.
    /// NOTE: BoosterSimConnect/NetworkConditionController.swift carries a
    /// schema-synced mirror of this matcher — keep the semantics identical.
    func matches(_ request: URLRequest) -> Bool {
        guard isEnabled else { return false }
        guard let url = request.url, let host = url.host?.lowercased() else { return false }
        let path = url.path

        let pattern = domain.trimmingCharacters(in: .whitespaces).lowercased()
        guard !pattern.isEmpty else { return false }

        if pattern.hasPrefix("*.") {
            // Dot-boundary suffix match: "a.example.com" matches "*.example.com",
            // "badexample.com" does not; the bare apex matches too.
            let base = pattern.dropFirst(2)
            if host != base && !host.hasSuffix("." + base) { return false }
        } else {
            if host != pattern { return false }
        }

        if let prefix = pathPrefix?.trimmingCharacters(in: .whitespaces), !prefix.isEmpty {
            return path.hasPrefix(prefix)
        }
        return true
    }
}
