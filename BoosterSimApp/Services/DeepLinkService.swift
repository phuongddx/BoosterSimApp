// DeepLinkService.swift — Manages deep link testing and history
import Foundation
import Combine

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

    private let historyKey = "DeepLinkHistory"
    private let favoritesKey = "DeepLinkFavorites"
    private let maxHistory = 50

    // MARK: - Init

    init() {
        loadHistory()
        loadFavorites()
    }

    // MARK: - Public API

    func openInSimulator(udid: String?) {
        Task { await openInSimulatorAsync(udid: udid) }
    }

    func openInSimulatorAsync(udid: String?) async {
        let urlString = currentURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !urlString.isEmpty else {
            await MainActor.run { self.lastResult = .error(message: "URL is empty") }
            return
        }

        guard let url = URL(string: urlString), url.scheme != nil else {
            await MainActor.run { self.lastResult = .error(message: "Invalid URL format") }
            return
        }

        let deviceUDID = udid ?? "booted"
        let result: DeepLinkResult = await Task.detached(priority: .userInitiated) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
            process.arguments = ["simctl", "openurl", deviceUDID, urlString]

            do {
                try process.run()
                process.waitUntilExit()

                if process.terminationStatus == 0 {
                    return DeepLinkResult.success(url: urlString)
                } else {
                    return DeepLinkResult.error(message: "simctl exited with code \(process.terminationStatus)")
                }
            } catch {
                return DeepLinkResult.error(message: error.localizedDescription)
            }
        }.value

        await MainActor.run {
            self.lastResult = result
            if case .success = result {
                self.addToHistory(url: urlString)
            }
        }
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

    // MARK: - Presets

    static let schemePresets = ["https://", "http://", "myapp://", "deeplink://", "app://"]

    // MARK: - Private

    private func addToHistory(url: String) {
        let entry = DeepLinkEntry(url: url)
        history.insert(entry, at: 0)
        if history.count > maxHistory {
            history = Array(history.prefix(maxHistory))
        }
        saveHistory()
    }

    private func loadHistory() {
        guard let data = UserDefaults.standard.data(forKey: historyKey),
              let decoded = try? JSONDecoder().decode([DeepLinkEntry].self, from: data) else { return }
        history = decoded
    }

    private func saveHistory() {
        guard let data = try? JSONEncoder().encode(history) else { return }
        UserDefaults.standard.set(data, forKey: historyKey)
    }

    private func loadFavorites() {
        guard let data = UserDefaults.standard.data(forKey: favoritesKey),
              let decoded = try? JSONDecoder().decode([DeepLinkEntry].self, from: data) else { return }
        favorites = decoded
    }

    private func saveFavorites() {
        guard let data = try? JSONEncoder().encode(favorites) else { return }
        UserDefaults.standard.set(data, forKey: favoritesKey)
    }
}

// MARK: - URL Extension

private extension URL {
    var queryItems: [URLQueryItem]? {
        URLComponents(url: self, resolvingAgainstBaseURL: false)?.queryItems
    }
}
