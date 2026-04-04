// HealthDataSectionView.swift — Health data generation controls for the side panel
import SwiftUI

struct HealthDataSectionView: View {

    let udid: String
    @EnvironmentObject var healthDataService: HealthDataService

    @State private var isExpanded  = true
    @State private var manualType  = "steps"
    @State private var manualValue = "10000"

    @AppStorage("healthAuthHintDismissed") private var authHintDismissed = false

    private let manualTypes = ["steps", "heartRate", "sleep", "workout"]

    var body: some View {
        CollapsibleSection(title: "Health Data", icon: "heart.text.square", isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: Spacing.sm) {

                presetsGrid

                Divider().padding(.horizontal, Spacing.md)

                manualRow

                // Clear button
                HStack {
                    Button {
                        healthDataService.clearAllData(udid: udid)
                    } label: {
                        Label("Clear Health Data", systemImage: "trash")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                    .disabled(healthDataService.state != .idle)
                    Spacer()
                }
                .padding(.horizontal, Spacing.md)

                if healthDataService.state != .idle {
                    statusRow
                }

                if !authHintDismissed {
                    authHintRow
                }
            }
            .padding(.bottom, Spacing.sm)
        }
    }

    // MARK: - Subviews

    private var presetsGrid: some View {
        LazyVGrid(
            columns: [GridItem(.flexible()), GridItem(.flexible())],
            spacing: Spacing.xs
        ) {
            ForEach(HealthPreset.allCases, id: \.self) { preset in
                presetButton(preset)
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.top, Spacing.sm)
    }

    private func presetButton(_ preset: HealthPreset) -> some View {
        Button {
            authHintDismissed = true
            healthDataService.generatePreset(preset, udid: udid)
        } label: {
            VStack(spacing: Spacing.xxs) {
                Image(systemName: preset.icon).font(.system(size: 16))
                Text(preset.label).font(.caption).multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.sm)
            .background(Color.primary.opacity(0.06),
                        in: RoundedRectangle(cornerRadius: CornerRadius.small))
        }
        .buttonStyle(.plain)
        .disabled(healthDataService.state != .idle)
        .opacity(healthDataService.state != .idle ? 0.5 : 1)
    }

    private var manualRow: some View {
        HStack(spacing: Spacing.xs) {
            Picker("", selection: $manualType) {
                ForEach(manualTypes, id: \.self) { Text($0).tag($0) }
            }
            .labelsHidden()
            .frame(width: 90)

            TextField("Value", text: $manualValue)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: .infinity)

            Button {
                guard let value = Double(manualValue) else { return }
                authHintDismissed = true
                healthDataService.generateManual(type: manualType, value: value, udid: udid)
            } label: {
                Image(systemName: "play.fill").foregroundStyle(.accent)
            }
            .buttonStyle(.plain)
            .disabled(healthDataService.state != .idle || Double(manualValue) == nil)
        }
        .padding(.horizontal, Spacing.md)
    }

    private var statusRow: some View {
        HStack(spacing: Spacing.xs) {
            switch healthDataService.state {
            case .installing:
                ProgressView().scaleEffect(0.7)
                Text("Installing companion…").font(.caption).foregroundStyle(.secondary)
            case .generating:
                ProgressView().scaleEffect(0.7)
                Text("Generating data…").font(.caption).foregroundStyle(.secondary)
            case .done:
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green).font(.caption)
                Text("Done").font(.caption).foregroundStyle(.secondary)
            case .error(let msg):
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange).font(.caption)
                Text(msg).font(.caption).foregroundStyle(.secondary).lineLimit(2)
            case .idle:
                EmptyView()
            }
            Spacer()
        }
        .padding(.horizontal, Spacing.md)
        .animation(.easeInOut(duration: 0.2), value: healthDataService.state)
    }

    private var authHintRow: some View {
        HStack(alignment: .top, spacing: Spacing.xs) {
            Image(systemName: "info.circle").foregroundStyle(.secondary).font(.caption)
            Text("First use: approve Health permissions in the Simulator.")
                .font(.caption2).foregroundStyle(.secondary)
            Spacer()
            Button {
                authHintDismissed = true
            } label: {
                Image(systemName: "xmark").font(.caption2).foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.xs)
        .background(Color.yellow.opacity(0.1),
                    in: RoundedRectangle(cornerRadius: CornerRadius.small))
        .padding(.horizontal, Spacing.md)
    }
}
