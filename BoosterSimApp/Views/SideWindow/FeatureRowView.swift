// FeatureRowView.swift — 32pt feature row with icon, label, hover state, and "Coming soon" tooltip
import SwiftUI

struct FeatureRowView: View {

    let item: FeatureItem

    @State private var isHovered = false
    @State private var showComingSoon = false
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    var body: some View {
        Button {
            triggerComingSoon()
        } label: {
            HStack(spacing: Spacing.sm) {
                Image(systemName: item.icon)
                    .imageScale(.small)
                    .foregroundStyle(.primary)
                    .frame(width: 16)

                Text(item.label)
                    .font(.body)
                    .foregroundStyle(.primary)

                Spacer()

                if showComingSoon {
                    Text("Coming soon")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(.white)
                        .padding(.horizontal, Spacing.xs)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.8), in: Capsule())
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }
            }
            .padding(.horizontal, Spacing.md)
            .frame(height: SideWindowMetrics.rowHeight)
            .background(isHovered ? Color.accentColor.opacity(0.08) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.1)) {
                isHovered = hovering
            }
        }
    }

    // MARK: - Coming Soon

    private func triggerComingSoon() {
        guard !showComingSoon else { return }
        withAnimation(reduceMotion ? .linear(duration: 0.1) : .spring(response: 0.2, dampingFraction: 0.7)) {
            showComingSoon = true
        }
        // Auto-dismiss after 1.5s
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(reduceMotion ? .linear(duration: 0.1) : .spring(response: 0.3, dampingFraction: 0.8)) {
                showComingSoon = false
            }
        }
    }
}
