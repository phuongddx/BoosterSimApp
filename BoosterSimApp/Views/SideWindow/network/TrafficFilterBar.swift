// TrafficFilterBar.swift — Horizontal filter pills for method, status, and search
import SwiftUI

struct TrafficFilterBar: View {

    @Binding var filter: TrafficFilter
    let eventCount: Int
    var onClear: (() -> Void)?

    @State private var showSearch = false
    @State private var searchText = ""

    var body: some View {
        VStack(spacing: 0) {
            // Filter row
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    // Method filters
                    methodPill(.GET)
                    methodPill(.POST)
                    methodPill(.PUT)
                    methodPill(.DELETE)

                    Divider().frame(height: 14).padding(.horizontal, 2)

                    // Status filters
                    statusPill(.success)
                    statusPill(.clientError)
                    statusPill(.serverError)

                    Spacer(minLength: 0)

                    // Search toggle
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showSearch.toggle()
                            if !showSearch { searchText = ""; filter.searchText = "" }
                        }
                    } label: {
                        Image(systemName: showSearch ? "xmark.circle.fill" : "magnifyingglass")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)

                    // Clear all
                    if eventCount > 0 {
                        Button {
                            onClear?()
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, Spacing.md)
            }
            .frame(height: SideWindowMetrics.compactRowHeight)

            // Search field (collapsible)
            if showSearch {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                    TextField("Filter URL...", text: $searchText)
                        .font(.system(size: 11, design: .monospaced))
                        .textFieldStyle(.plain)
                        .onChange(of: searchText) { _, newValue in
                            filter.searchText = newValue
                        }
                }
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.xxs)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }

    // MARK: - Method Filter Pill

    private func methodPill(_ method: HTTPMethod) -> some View {
        let isActive = filter.methods.contains(method)
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                if isActive {
                    filter.methods.remove(method)
                } else {
                    filter.methods.insert(method)
                }
                // Ensure at least one method selected
                if filter.methods.isEmpty {
                    filter.methods = Set(HTTPMethod.allCases)
                }
            }
        } label: {
            Text(method.rawValue)
                .font(.system(size: 9, weight: isActive ? .bold : .regular, design: .monospaced))
                .foregroundStyle(isActive ? Color.accentColor : .secondary)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(isActive ? Color.accentColor.opacity(0.12) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 3))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Status Filter Pill

    private func statusPill(_ range: StatusRange) -> some View {
        let isActive = filter.statusRange == range
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                filter.statusRange = isActive ? .all : range
            }
        } label: {
            Text(range.rawValue)
                .font(.system(size: 9, weight: isActive ? .bold : .regular, design: .monospaced))
                .foregroundStyle(isActive ? Color.accentColor : .secondary)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(isActive ? Color.accentColor.opacity(0.12) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 3))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    TrafficFilterBar(filter: .constant(TrafficFilter()), eventCount: 42)
        .frame(width: SideWindowMetrics.expandedWidth)
}
