// SideWindowTitleBar.swift — Custom title bar: app label + collapse button
import SwiftUI

struct SideWindowTitleBar: View {

    let onCollapse: () -> Void

    var body: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: "bolt.fill")
                .foregroundStyle(.accent)
                .imageScale(.small)

            Text("BoosterSim")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.primary)

            Spacer()

            Button(action: onCollapse) {
                Image(systemName: "chevron.left")
                    .imageScale(.small)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Collapse panel")
        }
        .padding(.horizontal, Spacing.md)
        .frame(height: SideWindowMetrics.titleBarHeight)
        .background(.bar)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }
}
