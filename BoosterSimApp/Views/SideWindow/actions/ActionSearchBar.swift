// ActionSearchBar.swift — Collapsible quick-search field over AppActionCatalog (TrafficFilterBar analog)
// Collapsing search clears the query, so a hidden filter never silently narrows the tab.
import SwiftUI

struct ActionSearchBar: View {

    @Binding var query: String

    @State private var showSearch = false

    var body: some View {
        VStack(spacing: 0) {
            // Toggle row (compactRowHeight — the TrafficFilterBar search-toggle anatomy)
            HStack(spacing: Spacing.xs) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showSearch.toggle()
                        if !showSearch { query = "" }   // clear-on-collapse
                    }
                } label: {
                    HStack(spacing: Spacing.xxs) {
                        Image(systemName: showSearch ? "xmark.circle.fill" : "magnifyingglass")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                        Text(showSearch ? "Hide search" : "Search actions")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(showSearch ? "Hide the action search" : "Search actions")

                Spacer()
            }
            .padding(.horizontal, Spacing.md)
            .frame(height: SideWindowMetrics.compactRowHeight)

            // Search field (collapsible)
            if showSearch {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                    TextField("Filter actions...", text: $query)
                        .font(.system(size: 11, design: .monospaced))
                        .textFieldStyle(.plain)
                    if !query.isEmpty {
                        Button {
                            query = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Clear the search")
                    }
                }
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.xxs)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ActionSearchBar(query: .constant("push"))
        .frame(width: SideWindowMetrics.expandedWidth)
}
