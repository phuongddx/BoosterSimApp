// DeviceHeaderView.swift — Shows active simulator device name, type icon, and connection status
import SwiftUI

struct DeviceHeaderView: View {

    @ObservedObject var tracker: SimulatorWindowTracker

    // If multiple simulators are running, allow picking one
    @Binding var selectedIndex: Int

    private var simulator: SimulatorWindow? {
        guard !tracker.simulators.isEmpty,
              selectedIndex < tracker.simulators.count else { return tracker.activeSimulator }
        return tracker.simulators[selectedIndex]
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: simulator?.deviceType.sfSymbol ?? "iphone")
                    .font(.system(size: 20))
                    .foregroundStyle(.secondary)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(simulator?.displayName ?? "No Simulator")
                        .font(.headline).fontWeight(.semibold)
                        .lineLimit(1)

                    HStack(spacing: Spacing.xs) {
                        Circle()
                            .fill(simulator != nil ? Color.green : Color.red)
                            .frame(width: 6, height: 6)
                        Text(simulator != nil ? "Connected" : "Disconnected")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }

                Spacer()
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)

            // Multi-simulator picker (shown when >1 simulator is detected)
            if tracker.simulators.count > 1 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Spacing.xs) {
                        ForEach(Array(tracker.simulators.enumerated()), id: \.offset) { idx, sim in
                            Button {
                                selectedIndex = idx
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: sim.deviceType.sfSymbol)
                                        .imageScale(.small)
                                    Text(sim.displayName)
                                        .font(.caption2).lineLimit(1)
                                }
                                .padding(.horizontal, Spacing.xs)
                                .padding(.vertical, 3)
                                .background(
                                    selectedIndex == idx
                                        ? Color.accentColor.opacity(0.15)
                                        : Color.clear,
                                    in: Capsule()
                                )
                                .overlay(
                                    Capsule().stroke(
                                        selectedIndex == idx ? Color.accentColor : Color.clear,
                                        lineWidth: 1
                                    )
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, Spacing.md)
                    .padding(.bottom, Spacing.xs)
                }
            }
        }
        .background(.background)
        .overlay(alignment: .bottom) { Divider() }
    }
}

#Preview {
    @Previewable @State var index = 0
    DeviceHeaderView(tracker: SimulatorWindowTracker(), selectedIndex: $index)
        .frame(width: SideWindowMetrics.expandedWidth)
}
