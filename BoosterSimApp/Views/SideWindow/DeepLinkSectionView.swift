// DeepLinkSectionView.swift — UI for testing deep links in Simulator
import SwiftUI

struct DeepLinkSectionView: View {

    @ObservedObject var deepLinkService: DeepLinkService
    let udid: String?

    @State private var showParsed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // MARK: - URL Input
            HStack(spacing: 8) {
                TextField("Enter URL or deep link", text: $deepLinkService.currentURL)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))

                Button("Open") {
                    deepLinkService.openInSimulator(udid: udid)
                }
                .buttonStyle(.borderedProminent)
                .disabled(deepLinkService.currentURL.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            // MARK: - Scheme Presets
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(DeepLinkService.schemePresets, id: \.self) { scheme in
                        Button(scheme) {
                            deepLinkService.currentURL = scheme
                        }
                        .font(.system(.caption, design: .monospaced))
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            }

            // MARK: - Result
            if let result = deepLinkService.lastResult {
                HStack(spacing: 6) {
                    Image(systemName: result.isSuccess ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundColor(result.isSuccess ? .green : .orange)
                    Text(result.message)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(8)
                .background(result.isSuccess ? Color.green.opacity(0.1) : Color.orange.opacity(0.1))
                .cornerRadius(6)
            }

            // MARK: - Parsed URL
            if showParsed, !deepLinkService.currentURL.isEmpty,
               let parsed = deepLinkService.parseURL(deepLinkService.currentURL) {
                VStack(alignment: .leading, spacing: 4) {
                    Label("URL Components", systemImage: "doc.text.magnifyingglass")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)

                    if let scheme = parsed.scheme {
                        parsedRow("Scheme", scheme)
                    }
                    if let host = parsed.host {
                        parsedRow("Host", host)
                    }
                    if !parsed.path.isEmpty && parsed.path != "/" {
                        parsedRow("Path", parsed.path)
                    }
                    if let query = parsed.query {
                        parsedRow("Query", query)
                    }
                    if let fragment = parsed.fragment {
                        parsedRow("Fragment", fragment)
                    }
                    if let items = parsed.queryItems, !items.isEmpty {
                        ForEach(items, id: \.name) { item in
                            parsedRow(item.name, item.value ?? "")
                        }
                    }
                }
                .padding(8)
                .background(Color.blue.opacity(0.05))
                .cornerRadius(6)
            }

            // MARK: - Toggle Parsed View
            Button(showParsed ? "Hide URL Components" : "Show URL Components") {
                showParsed.toggle()
            }
            .font(.caption)
            .buttonStyle(.plain)
            .foregroundColor(.accentColor)

            Divider()

            // MARK: - Favorites
            if !deepLinkService.favorites.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Label("Favorites", systemImage: "star.fill")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)

                    ForEach(deepLinkService.favorites) { entry in
                        linkRow(entry, isFavorite: true)
                    }
                }
            }

            // MARK: - History
            if !deepLinkService.history.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Label("History", systemImage: "clock")
                            .font(.caption.bold())
                            .foregroundColor(.secondary)
                        Spacer()
                        Button("Clear") { deepLinkService.clearHistory() }
                            .font(.caption)
                            .buttonStyle(.plain)
                            .foregroundColor(.red)
                    }

                    ForEach(deepLinkService.history.prefix(10)) { entry in
                        linkRow(entry, isFavorite: false)
                    }
                }
            }
        }
        .padding(12)
    }

    // MARK: - Helpers

    @ViewBuilder
    private func parsedRow(_ key: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(key)
                .font(.system(.caption2, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 60, alignment: .trailing)
            Text(value)
                .font(.system(.caption2, design: .monospaced))
                .textSelection(.enabled)
        }
    }

    @ViewBuilder
    private func linkRow(_ entry: DeepLinkService.DeepLinkEntry, isFavorite: Bool) -> some View {
        HStack(spacing: 6) {
            Button {
                deepLinkService.selectURL(entry.url)
            } label: {
                Text(entry.url)
                    .font(.system(.caption, design: .monospaced))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            Button {
                deepLinkService.toggleFavorite(entry)
            } label: {
                Image(systemName: entry.isFavorite ? "star.fill" : "star")
                    .font(.caption)
                    .foregroundColor(entry.isFavorite ? .yellow : .gray)
            }
            .buttonStyle(.plain)

            if !isFavorite {
                Button {
                    deepLinkService.removeHistory(entry)
                } label: {
                    Image(systemName: "xmark.circle")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Result Extension

private extension DeepLinkService.DeepLinkResult {
    var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }

    var message: String {
        switch self {
        case .success(let url): return "Opened: \(url)"
        case .error(let msg): return msg
        }
    }
}
