// AXTreeView.swift — Lazy accessibility tree inspector for the active Simulator
import SwiftUI

struct AXTreeView: View {

    @EnvironmentObject var service: AXInspectorService
    let pid: pid_t?

    var body: some View {
        VStack(spacing: 0) {
            sectionHeader
            if pid == nil {
                noSimulatorRow
            } else if service.isLoading {
                loadingRow
            } else if service.rootNodes.isEmpty {
                emptyRow
            } else {
                nodeList
            }
        }
    }

    // MARK: - Sub-views

    private var sectionHeader: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: "accessibility")
                .imageScale(.small).foregroundStyle(.secondary)
            Text("VoiceOver Navigator")
                .font(.subheadline).fontWeight(.medium).foregroundStyle(.secondary)
            Spacer()
            Button {
                if let pid { service.loadRoot(for: pid) }
            } label: {
                Image(systemName: "arrow.clockwise").imageScale(.small)
            }
            .buttonStyle(.plain)
            .disabled(pid == nil)
            .padding(.trailing, Spacing.md)
        }
        .padding(.leading, Spacing.md)
        .frame(height: SideWindowMetrics.compactRowHeight)
    }

    private var nodeList: some View {
        ForEach(service.rootNodes) { node in
            AXNodeRowView(node: node)
        }
    }

    private var loadingRow: some View {
        HStack {
            ProgressView().scaleEffect(0.7)
            Text("Loading accessibility tree…")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(.horizontal, Spacing.md)
        .frame(height: SideWindowMetrics.rowHeight, alignment: .leading)
    }

    private var emptyRow: some View {
        Text("No elements found")
            .font(.caption).foregroundStyle(.secondary)
            .padding(.horizontal, Spacing.md)
            .frame(height: SideWindowMetrics.rowHeight, alignment: .leading)
    }

    private var noSimulatorRow: some View {
        Text("No simulator detected")
            .font(.caption).foregroundStyle(.secondary)
            .padding(.horizontal, Spacing.md)
            .frame(height: SideWindowMetrics.rowHeight, alignment: .leading)
    }
}

// MARK: - Node Row

private struct AXNodeRowView: View {

    @EnvironmentObject var service: AXInspectorService
    let node: AXNode
    @State private var isExpanded = false
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            Button {
                service.highlight(node: node)
                if node.hasChildren { isExpanded.toggle() }
            } label: {
                HStack(spacing: Spacing.xs) {
                    if node.hasChildren {
                        Image(systemName: "chevron.right")
                            .imageScale(.small).foregroundStyle(.tertiary)
                            .rotationEffect(.degrees(isExpanded ? 90 : 0))
                            .animation(
                                reduceMotion ? .linear(duration: 0.1) : .spring(response: 0.25, dampingFraction: 0.85),
                                value: isExpanded
                            )
                    } else {
                        Color.clear.frame(width: 10)
                    }

                    Text(node.role)
                        .font(.caption).fontWeight(.medium)
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 4).padding(.vertical, 1)
                        .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 3))

                    Text(node.label.isEmpty ? node.value : node.label)
                        .font(.caption).foregroundStyle(.primary).lineLimit(1)

                    Spacer()
                }
                .padding(.horizontal, Spacing.md)
                .frame(height: 28)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Children (loaded lazily — currently shows placeholder)
            if isExpanded && node.hasChildren {
                HStack {
                    Color.accentColor.frame(width: 1)
                        .padding(.leading, Spacing.md + 10)
                    Text("Children not yet loaded")
                        .font(.caption2).foregroundStyle(.tertiary)
                        .padding(.vertical, 4)
                    Spacer()
                }
            }
        }
    }
}

#Preview("No simulator") {
    AXTreeView(pid: nil)
        .environmentObject(AXInspectorService())
        .frame(width: SideWindowMetrics.expandedWidth)
}
