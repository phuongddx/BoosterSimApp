// CollapsibleSection.swift — Reusable collapsible section header + content wrapper for the side panel
import SwiftUI

struct CollapsibleSection<Content: View>: View {
    let title: String
    let icon: String
    @Binding var isExpanded: Bool
    @ViewBuilder let content: () -> Content

    @Environment(\.accessibilityReduceMotion) var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(reduceMotion ? .linear(duration: 0.1) : .spring(response: 0.35, dampingFraction: 0.85)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: icon).imageScale(.small).foregroundStyle(.secondary)
                        Text(title).font(.subheadline).fontWeight(.medium).foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, Spacing.md)
                    .frame(height: SideWindowMetrics.compactRowHeight)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .imageScale(.small).foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .animation(
                            reduceMotion ? .linear(duration: 0.1) : .spring(response: 0.3, dampingFraction: 0.75),
                            value: isExpanded
                        )
                        .padding(.trailing, Spacing.md)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .background(.background)

            if isExpanded {
                content()
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}
