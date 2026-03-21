// DeviceHeaderView.swift — Shows active simulator device name and connection status
import SwiftUI

struct DeviceHeaderView: View {

    let simulator: SimulatorWindow?

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "iphone")
                .font(.system(size: 20))
                .foregroundStyle(.secondary)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(simulator?.displayName ?? "No Simulator")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .lineLimit(1)

                HStack(spacing: Spacing.xs) {
                    Circle()
                        .fill(simulator != nil ? Color.green : Color.red)
                        .frame(width: 6, height: 6)

                    Text(simulator != nil ? "Connected" : "Disconnected")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(.background)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }
}
