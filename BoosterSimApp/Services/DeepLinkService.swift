// DeepLinkService.swift — Manages deep link testing and history over the SimCtlService seam
import Foundation
import Combine

@MainActor
final class DeepLinkService: ObservableObject {

    // MARK: - Published State

    @Published var currentURL: String = ""
    @Published var history: [DeepLinkEntry] = []
    @Published var favorites: [DeepLinkEntry] = []
    @Published var lastResult: DeepLinkResult?

    // MARK: - Types

    struct DeepLinkEntry: Identifiable, Codable, Equatable {
        let id: UUID
        let url: String
        let timestamp: Date
        var isFavorite: Bool

        init(url: String, isFavorite: Bool = false) {
            self.id = UUID()
            self.url = url
            self.timestamp = Date()
            self.isFavorite = isFavorite
        }
    }

    enum DeepLinkResult: Equatable {
        case success(url: String)
        case error(message: String)
    }

    // MARK: - Private

    private let simCtl: SimCtlService
    private let defaults: UserDefaults
    private let historyKey = "DeepLinkHistory"
    private let favoritesKey = "DeepLinkFavorites"
    private let maxHistory = 50
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    init(simCtl: SimCtlService, defaults: UserDefaults = .standard) {
        self.simCtl = simCtl
        self.defaults = defaults
        loadHistory()
        loadFavorites()
    }

    // MARK: - Public API

    /// Opens the current URL on the Simulator through the shared simctl seam (Combine — the
    /// direct subprocess spawn that used to live here was the convention violation Phase 3 deletes).
    func openInSimulator(udid: String?) {
        let urlString = currentURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if let message = Self.validationMessage(for: urlString) {
            lastResult = .error(message: message)
            return
        }

        simCtl.run(Self.openURLCommand(udid: udid, urlString: urlString))
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    guard let self, case .failure(let error) = completion else { return }
                    self.lastResult = .error(message: error.localizedDescription)
                },
                receiveValue: { [weak self] _ in
                    guard let self else { return }
                    self.lastResult = .success(url: urlString)
                    self.addToHistory(url: urlString)
                }
            )
            .store(in: &cancellables)
    }

    func toggleFavorite(_ entry: DeepLinkEntry) {
        if let idx = favorites.firstIndex(where: { $0.id == entry.id }) {
            favorites[idx].isFavorite.toggle()
            if !favorites[idx].isFavorite {
                favorites.remove(at: idx)
            }
        } else {
            var newEntry = entry
            newEntry.isFavorite = true
            favorites.append(newEntry)
        }
        saveFavorites()
    }

    func removeHistory(_ entry: DeepLinkEntry) {
        history.removeAll { $0.id == entry.id }
        saveHistory()
    }

    func clearHistory() {
        history.removeAll()
        saveHistory()
    }

    func selectURL(_ url: String) {
        currentURL = url
    }

    // MARK: - URL Parsing

    func parseURL(_ urlString: String) -> ParsedURL? {
        guard let url = URL(string: urlString) else { return nil }
        return ParsedURL(
            scheme: url.scheme,
            host: url.host,
            path: url.path,
            query: url.query,
            fragment: url.fragment,
            queryItems: url.queryItems
        )
    }

    struct ParsedURL {
        let scheme: String?
        let host: String?
        let path: String
        let query: String?
        let fragment: String?
        let queryItems: [URLQueryItem]?
    }

    // MARK: - Validation & Argv (pure, unit-pinned)

    /// Pure validation — returns the pinned error message for rejectable input, nil when the
    /// URL may be opened. Rejection happens here, before any subprocess is ever built.
    nonisolated static func validationMessage(for urlString: String) -> String? {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "URL is empty" }
        if URL(string: trimmed)?.scheme == nil { return "Invalid URL format" }
        return nil
    }

    /// Pure argv for the open verb — booted-fallback when no concrete UDID is known.
    nonisolated static func openURLCommand(udid: String?, urlString: String) -> [String] {
        ["openurl", udid ?? "booted", urlString]
    }

    // MARK: - Presets

    static let schemePresets = ["https://", "http://", "myapp://", "deeplink://", "app://"]

    // MARK: - History

    /// Records a successfully opened URL. Internal (not private) so the persistence contract
    /// is exercisable in tests without spawning a subprocess.
    func addToHistory(url: String) {
        let entry = DeepLinkEntry(url: url)
        history.insert(entry, at: 0)
        if history.count > maxHistory {
            history = Array(history.prefix(maxHistory))
        }
        saveHistory()
    }

    // MARK: - Private

    private func loadHistory() {
        guard let data = defaults.data(forKey: historyKey),
              let decoded = try? JSONDecoder().decode([DeepLinkEntry].self, from: data) else { return }
        history = decoded
    }

    private func saveHistory() {
        guard let data = try? JSONEncoder().encode(history) else { return }
        defaults.set(data, forKey: historyKey)
    }

    private func loadFavorites() {
        guard let data = defaults.data(forKey: favoritesKey),
              let decoded = try? JSONDecoder().decode([DeepLinkEntry].self, from: data) else { return }
        favorites = decoded
    }

    private func saveFavorites() {
        guard let data = try? JSONEncoder().encode(favorites) else { return }
        defaults.set(data, forKey: favoritesKey)
    }
}

// MARK: - URL Extension

private extension URL {
    var queryItems: [URLQueryItem]? {
        URLComponents(url: self, resolvingAgainstBaseURL: false)?.queryItems
    }
}
