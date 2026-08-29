import Foundation
import Testing
@testable import BoosterSimApp

/// Matcher contract for `BlockRule.matches` — string-ops only (no regex,
/// threat T-05-02). Ten edge cases pinned by plan 05-03 Task 1.
struct BlockRuleTests {

    private func makeRequest(_ urlString: String) -> URLRequest {
        URLRequest(url: URL(string: urlString)!)
    }

    private func makeRule(
        domain: String,
        pathPrefix: String? = nil,
        isEnabled: Bool = true
    ) -> BlockRule {
        BlockRule(id: UUID(), domain: domain, pathPrefix: pathPrefix, isEnabled: isEnabled)
    }

    // MARK: - Host Matching

    @Test func exactHostMatches() {
        let rule = makeRule(domain: "api.example.com")
        #expect(rule.matches(makeRequest("https://api.example.com/v1/feed")))
    }

    @Test func wildcardSuffixMatchesDotBoundarySubdomain() {
        let rule = makeRule(domain: "*.example.com")
        #expect(rule.matches(makeRequest("https://cdn.example.com/img.png")))
        // The bare apex matches too (explicit convenience).
        #expect(rule.matches(makeRequest("https://example.com/")))
    }

    @Test func wildcardSuffixRejectsNonDotBoundaryLookalike() {
        let rule = makeRule(domain: "*.example.com")
        // "badexample.com" ends with "example.com" but NOT ".example.com" —
        // the negative case separating hasSuffix(".example.com") from a
        // naive hasSuffix("example.com").
        #expect(!rule.matches(makeRequest("https://badexample.com/")))
    }

    // MARK: - Path Prefix

    @Test func pathPrefixNarrowsMatch() {
        let rule = makeRule(domain: "example.com", pathPrefix: "/api")
        #expect(rule.matches(makeRequest("https://example.com/api/v1")))
        #expect(!rule.matches(makeRequest("https://example.com/docs")))
    }

    @Test func ruleWithoutPathPrefixMatchesEveryPath() {
        let rule = makeRule(domain: "example.com")
        #expect(rule.matches(makeRequest("https://example.com/api/v1")))
        #expect(rule.matches(makeRequest("https://example.com/docs")))
    }

    // MARK: - Rule State

    @Test func disabledRuleNeverMatchesEvenOnExactHost() {
        let rule = makeRule(domain: "api.example.com", isEnabled: false)
        #expect(!rule.matches(makeRequest("https://api.example.com/v1/feed")))
    }

    // MARK: - Input Hardening

    @Test func hostComparisonIsCaseInsensitive() {
        let rule = makeRule(domain: "API.Example.COM")
        #expect(rule.matches(makeRequest("https://api.example.com/v1/feed")))
    }

    @Test func nilHostRequestNeverMatches() {
        let rule = makeRule(domain: "example.com")
        // file URLs have no host component.
        #expect(!rule.matches(makeRequest("file:///tmp/some-file.txt")))
    }

    @Test func whitespaceTrimmedRuleDomainStillMatches() {
        // Rule strings typed into a text field may carry stray whitespace.
        let rule = makeRule(domain: " api.example.com ")
        #expect(rule.matches(makeRequest("https://api.example.com/v1/feed")))
    }

    @Test func emptyDomainRuleNeverMatches() {
        // Defensive: an empty (or whitespace-only) domain must never act as
        // an accidental match-all (threat T-05-08).
        #expect(!makeRule(domain: "").matches(makeRequest("https://anything.example.com/")))
        #expect(!makeRule(domain: "   ").matches(makeRequest("https://anything.example.com/")))
        #expect(!makeRule(domain: "*.").matches(makeRequest("https://anything.example.com/")))
    }
}
