// CollapsedStripView.swift — 28pt collapsed state: accent top stripe + expand chevron
import SwiftUI

struct CollapsedStripView: View {

    let onExpand: () -> Void

    var body: some View {
        Button(action: onExpand) {
            VStack(spacing: 0) {
                // 2pt accent orange top stripe
                Rectangle()
                    .fill(Color.accentColor)
                    .frame(height: 2)

                Spacer()

                Image(systemName: "chevron.right")
                    .imageScale(.medium)
                    .foregroundStyle(.secondary)

                Spacer()
            }
            .frame(width: SideWindowMetrics.collapsedWidth)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Show BoosterSim")
    }
}

#Preview {
    CollapsedStripView(onExpand: {})
        .frame(width: SideWindowMetrics.collapsedWidth, height: 200)
}
