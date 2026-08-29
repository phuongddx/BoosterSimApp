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
    func matches(_ request: URLRequest) -> Bool {
        guard let url = request.url, let host = url.host?.lowercased() else { return false }
        let path = url.path

        let pattern = domain.lowercased()
        if pattern.hasPrefix("*.") {
            // Dot-boundary suffix match: "a.example.com" matches "*.example.com",
            // "a-example.com" does not; the bare apex matches too.
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
