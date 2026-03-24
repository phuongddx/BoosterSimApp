// StatusBarSectionView.swift — Status bar configuration UI (presets + custom expander)
import SwiftUI

struct StatusBarSectionView: View {

    @EnvironmentObject var service: StatusBarService
    let udid: String?

    @State private var showCustom = false
    @State private var customConfig = StatusBarConfig()

    private var isDisabled: Bool { udid == nil }

    var body: some View {
        VStack(spacing: 0) {
            sectionHeader
            if isDisabled {
                noSimulatorRow
            } else {
                presetButtons
                if showCustom { customControls }
            }
        }
    }

    // MARK: - Sub-views

    private var sectionHeader: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: "clock")
                .imageScale(.small)
                .foregroundStyle(.secondary)
            Text("Status Bar")
                .font(.subheadline).fontWeight(.medium)
                .foregroundStyle(.secondary)
            Spacer()
            if service.isApplying {
                ProgressView().scaleEffect(0.6)
            }
        }
        .padding(.horizontal, Spacing.md)
        .frame(height: SideWindowMetrics.compactRowHeight)
    }

    private var presetButtons: some View {
        VStack(spacing: Spacing.xs) {
            HStack(spacing: Spacing.xs) {
                ForEach(StatusBarPreset.allCases) { preset in
                    Button {
                        if let udid { service.applyPreset(preset, to: udid) }
                    } label: {
                        VStack(spacing: 2) {
                            Image(systemName: preset.icon).font(.system(size: 11))
                            Text(preset.rawValue).font(.caption2).lineLimit(1)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(isDisabled)
                }
            }
            .padding(.horizontal, Spacing.md)

            HStack(spacing: Spacing.xs) {
                Button("Clear") {
                    if let udid { service.clearOverrides(for: udid) }
                }
                .buttonStyle(.bordered)
                .disabled(isDisabled)

                Button(showCustom ? "Hide Custom" : "Custom") {
                    showCustom.toggle()
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.bottom, Spacing.sm)
        }
    }

    private var customControls: some View {
        VStack(spacing: Spacing.sm) {
            HStack {
                Text("Time").font(.caption).foregroundStyle(.secondary)
                Spacer()
                TextField("9:41", text: $customConfig.time)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 72)
            }
            HStack {
                Text("Battery \(customConfig.batteryLevel)%")
                    .font(.caption).foregroundStyle(.secondary)
                Slider(value: Binding(
                    get: { Double(customConfig.batteryLevel) },
                    set: { customConfig.batteryLevel = Int($0) }
                ), in: 0...100, step: 1)
            }
            if let err = service.lastError {
                Text(err).font(.caption2).foregroundStyle(.red).lineLimit(2)
            }
            Button("Apply") {
                if let udid { service.applyCustom(customConfig, to: udid) }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isDisabled)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.bottom, Spacing.sm)
    }

    private var noSimulatorRow: some View {
        Text("No simulator detected")
            .font(.caption).foregroundStyle(.secondary)
            .padding(.horizontal, Spacing.md)
            .frame(height: SideWindowMetrics.rowHeight, alignment: .leading)
    }
}
