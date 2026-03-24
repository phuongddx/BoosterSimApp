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
    func makeBody(configuration: Configuration) -> some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
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
                        .animation(.easeInOut(duration: 0.2), value: configuration.isExpanded)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .background(.background)

            if configuration.isExpanded {
                configuration.content
            }
        }
    }
}
