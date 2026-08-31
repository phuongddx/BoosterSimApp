// DeepLinkServiceTests.swift — Parse, validation, argv builder, and history/favorites persistence contracts
import Foundation
import Testing
@testable import BoosterSimApp

/// Pins the DeepLinkService contract across the SimCtlService seam migration (03-02 Task 1):
/// parse/history/favorites behavior must stay byte-for-byte identical while the open path
/// stops spawning subprocesses directly.
struct DeepLinkServiceTests {

    // MARK: - URL Parsing

    @MainActor
    @Test func parseURLExtractsComponentsOfFullHTTPSURL() {
        let parsed = makeService().parseURL("https://api.example.com/v1/users?page=2&sort=name#results")
        #expect(parsed?.scheme == "https")
        #expect(parsed?.host == "api.example.com")
        #expect(parsed?.path == "/v1/users")
        #expect(parsed?.query == "page=2&sort=name")
        #expect(parsed?.fragment == "results")
    }

    @MainActor
    @Test func parseURLExtractsCustomSchemeURL() {
        let parsed = makeService().parseURL("myapp://product/42?ref=push")
        #expect(parsed?.scheme == "myapp")
        #expect(parsed?.host == "product")
        #expect(parsed?.path == "/42")
        #expect(parsed?.query == "ref=push")
        #expect(parsed?.fragment == nil)
    }

    @MainActor
    @Test func parseURLReturnsNilForInvalidInput() {
        #expect(makeService().parseURL("") == nil)
        #expect(makeService().parseURL("not a url with spaces") == nil)
    }

    // MARK: - Validation (before any subprocess runs)

    @Test func validationRejectsEmptyURLWithPinnedMessage() {
        #expect(DeepLinkService.validationMessage(for: "") == "URL is empty")
        #expect(DeepLinkService.validationMessage(for: "   ") == "URL is empty")
    }

    @Test func validationRejectsSchemelessURLWithPinnedMessage() {
        #expect(DeepLinkService.validationMessage(for: "example.com/path") == "Invalid URL format")
    }

    @Test func validationAcceptsSchemeBearingURL() {
        #expect(DeepLinkService.validationMessage(for: "https://example.com") == nil)
        #expect(DeepLinkService.validationMessage(for: "myapp://open") == nil)
    }

    @MainActor
    @Test func openRejectsInvalidInputSynchronouslyWithoutSpawning() {
        let service = makeService()

        // Empty URL: rejected before the seam ever runs — the result lands synchronously.
        service.currentURL = ""
        service.openInSimulator(udid: "UDID")
        #expect(service.lastResult == .error(message: "URL is empty"))

        // Scheme-less URL: same synchronous rejection.
        service.currentURL = "example.com/path"
        service.openInSimulator(udid: "UDID")
        #expect(service.lastResult == .error(message: "Invalid URL format"))
    }

    // MARK: - openurl Argv Builder

    @Test func openURLCommandProducesExactArgv() {
        #expect(DeepLinkService.openURLCommand(udid: "UDID-1234", urlString: "https://example.com/x")
                == ["openurl", "UDID-1234", "https://example.com/x"])
    }

    @Test func openURLCommandFallsBackToBootedWhenUDIDIsNil() {
        #expect(DeepLinkService.openURLCommand(udid: nil, urlString: "myapp://open")
                == ["openurl", "booted", "myapp://open"])
    }

    // MARK: - History Persistence (isolated suite — never the shared standard suite)

    @MainActor
    @Test func historyPersistsAcrossServiceReInitMostRecentFirst() throws {
        let (defaults, suiteName) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let first = makeService(defaults: defaults)
        first.addToHistory(url: "https://first.example.com")
        first.addToHistory(url: "myapp://second")

        // Re-init from the same suite: entries survive, most-recent-first ordering preserved.
        let second = makeService(defaults: defaults)
        #expect(second.history.map(\.url) == ["myapp://second", "https://first.example.com"])
    }

    @MainActor
    @Test func historyCapsAtFiftyEntriesAndKeepsNewest() throws {
        let (defaults, suiteName) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let service = makeService(defaults: defaults)
        for index in 0..<55 {
            service.addToHistory(url: "https://example.com/\(index)")
        }
        #expect(service.history.count == 50)
        #expect(service.history.first?.url == "https://example.com/54")

        let reloaded = makeService(defaults: defaults)
        #expect(reloaded.history.count == 50)
        #expect(reloaded.history.first?.url == "https://example.com/54")
    }

    // MARK: - Favorites Persistence (toggle dedupe)

    @MainActor
    @Test func favoritesRoundTripAndToggleDedupe() throws {
        let (defaults, suiteName) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let entry = DeepLinkService.DeepLinkEntry(url: "https://favorite.example.com")

        let first = makeService(defaults: defaults)
        first.toggleFavorite(entry)                       // add
        #expect(first.favorites.count == 1)
        #expect(first.favorites.first?.isFavorite == true)

        // Re-init: the favorite survives persistence.
        let second = makeService(defaults: defaults)
        #expect(second.favorites.map(\.url) == ["https://favorite.example.com"])

        // Toggle the persisted favorite again: removed (dedupe), not duplicated.
        let persisted = second.favorites[0]
        second.toggleFavorite(persisted)
        #expect(second.favorites.isEmpty)

        let third = makeService(defaults: defaults)
        #expect(third.favorites.isEmpty)
    }

    // MARK: - Helpers

    @MainActor
    private func makeService(defaults: UserDefaults = .standard) -> DeepLinkService {
        DeepLinkService(simCtl: SimCtlService(), defaults: defaults)
    }

    private func makeDefaults() throws -> (defaults: UserDefaults, suiteName: String) {
        let suiteName = "DeepLinkServiceTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        return (defaults, suiteName)
    }
}
