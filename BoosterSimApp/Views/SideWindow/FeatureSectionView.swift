// FeatureSectionView.swift — Collapsible section with SF Symbol header and feature rows
import SwiftUI

// Simple data model for a feature item (shared across sections)
struct FeatureItem: Identifiable {
    let id = UUID()
    let icon: String
    let label: String
}

struct FeatureSectionView: View {

    let title: String
    let icon: String
    let items: [FeatureItem]

    @State private var isExpanded = true

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            ForEach(items) { item in
                FeatureRowView(item: item)
            }
        } label: {
            HStack(spacing: Spacing.xs) {
                Image(systemName: icon)
                    .imageScale(.small)
                    .foregroundStyle(.secondary)
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, Spacing.md)
            .frame(height: SideWindowMetrics.compactRowHeight)
        }
        .disclosureGroupStyle(SectionDisclosureStyle())
    }
}

// MARK: - Custom Disclosure Style

private struct SectionDisclosureStyle: DisclosureGroupStyle {
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(reduceMotion ? .linear(duration: 0.1) : .spring(response: 0.35, dampingFraction: 0.85)) {
                    configuration.isExpanded.toggle()
                }
            } label: {
                HStack {
                    configuration.label
                    Spacer()
                    Image(systemName: "chevron.right")
                        .imageScale(.small)
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(configuration.isExpanded ? 90 : 0))
                        .animation(
                            reduceMotion ? .linear(duration: 0.1) : .spring(response: 0.3, dampingFraction: 0.75),
                            value: configuration.isExpanded
                        )
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .background(.background)

            if configuration.isExpanded {
                configuration.content
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

#Preview {
    FeatureSectionView(
        title: "Captures",
        icon: "camera",
        items: [
            FeatureItem(icon: "camera",               label: "Screenshot"),
            FeatureItem(icon: "video",                label: "Record Screen"),
            FeatureItem(icon: "film",                 label: "GIF Recording"),
            FeatureItem(icon: "square.and.arrow.up",  label: "Video Export")
        ]
    )
    .frame(width: SideWindowMetrics.expandedWidth)
}
