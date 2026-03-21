// SideWindowFooter.swift — Fixed footer with Preferences link
import SwiftUI

struct SideWindowFooter: View {

    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(spacing: 0) {
            Divider()

            Button {
                openSettings()
            } label: {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "gearshape")
                        .imageScale(.small)
                        .foregroundStyle(.secondary)
                    Text("Preferences")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal, Spacing.md)
                .frame(height: SideWindowMetrics.compactRowHeight)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }
}
