// TabBarView.swift — Icon-only tab bar with amber underline + collapse button
import SwiftUI

struct TabBarView: View {

    @Binding var selectedTab: SideTab
    let onCollapse: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 0) {
            ForEach(SideTab.allCases, id: \.self) { tab in
                tabButton(tab)
            }
            Spacer()
            collapseButton
        }
        .padding(.horizontal, Spacing.xs)
        .frame(height: SideWindowMetrics.headerHeight)
        .background(.bar, in: RoundedRectangle(cornerRadius: CornerRadius.large))
        .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
    }

    // MARK: - Tab Button

    private func tabButton(_ tab: SideTab) -> some View {
        Button {
            withAnimation(reduceMotion ? .linear(duration: 0.1) : .spring(response: 0.25, dampingFraction: 0.8)) {
                selectedTab = tab
            }
        } label: {
            VStack(spacing: 2) {
                Image(systemName: tab.icon)
                    .imageScale(.small)
                    .foregroundStyle(selectedTab == tab ? .accent : .secondary)
                    .frame(height: SideWindowMetrics.headerHeight - 4)

                // Amber underline indicator
                RoundedRectangle(cornerRadius: 1)
                    .fill(selectedTab == tab ? NSColor.controlAccentColor : NSColor.clear)
                    .frame(height: 2)
            }
            .padding(.horizontal, Spacing.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(tab.label)
        .accessibilityLabel(tab.label)
        .accessibilityAddTraits(selectedTab == tab ? .isSelected : [])
    }

    // MARK: - Collapse Button

    private var collapseButton: some View {
        Button(action: onCollapse) {
            Image(systemName: "chevron.left")
                .imageScale(.small)
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .help("Collapse panel")
        .accessibilityLabel("Collapse panel")
    }
}

#Preview {
    @Previewable @State var tab: SideTab = .capture
    TabBarView(selectedTab: $tab, onCollapse: {})
        .frame(width: SideWindowMetrics.expandedWidth)
}
