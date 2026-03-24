// EnvironmentOverridesView.swift — Appearance and accessibility override controls
import SwiftUI

struct EnvironmentOverridesView: View {

    @EnvironmentObject var service: EnvironmentOverrideService
    let udid: String?

    private var isDisabled: Bool { udid == nil }

    var body: some View {
        VStack(spacing: 0) {
            sectionHeader
            if isDisabled {
                noSimulatorRow
            } else {
                controls
            }
        }
    }

    // MARK: - Sub-views

    private var sectionHeader: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: "dial.medium")
                .imageScale(.small)
                .foregroundStyle(.secondary)
            Text("Environment")
                .font(.subheadline).fontWeight(.medium)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, Spacing.md)
        .frame(height: SideWindowMetrics.compactRowHeight)
    }

    private var controls: some View {
        VStack(spacing: 0) {
            // Dark mode toggle
            overrideRow(label: "Dark Mode", icon: "moon") {
                let next: AppearanceStyle = service.appearance == .dark ? .light : .dark
                service.setAppearance(next, udid: udid ?? "booted")
            } indicator: {
                Image(systemName: service.appearance == .dark ? "checkmark" : "")
                    .imageScale(.small).foregroundStyle(.secondary)
            }

            // Increase Contrast
            overrideRow(label: "Increase Contrast", icon: "circle.lefthalf.filled") {
                service.setIncreaseContrast(!service.increaseContrast, udid: udid ?? "booted")
            } indicator: {
                if service.increaseContrast {
                    Image(systemName: "checkmark").imageScale(.small).foregroundStyle(.secondary)
                }
            }

            // Dynamic Type stepper
            HStack(spacing: Spacing.sm) {
                Image(systemName: "textformat.size")
                    .imageScale(.small).frame(width: 16)
                Text("Dynamic Type").font(.body)
                Spacer()
                HStack(spacing: Spacing.xs) {
                    Button {
                        service.decrementContentSize(udid: udid ?? "booted")
                    } label: { Image(systemName: "minus").imageScale(.small) }
                    .buttonStyle(.plain)
                    .disabled(service.contentSizeIndex == 0)

                    Text(shortSizeName(service.currentSizeName))
                        .font(.caption2).foregroundStyle(.secondary).frame(minWidth: 28)

                    Button {
                        service.incrementContentSize(udid: udid ?? "booted")
                    } label: { Image(systemName: "plus").imageScale(.small) }
                    .buttonStyle(.plain)
                    .disabled(service.contentSizeIndex == EnvironmentOverrideService.contentSizes.count - 1)
                }
            }
            .padding(.horizontal, Spacing.md)
            .frame(height: SideWindowMetrics.rowHeight)

            // Reduce Motion (Tier 2)
            tier2Row(label: "Reduce Motion", icon: "waveform.path",
                     isOn: service.reduceMotion) {
                service.setReduceMotion(!service.reduceMotion, udid: udid ?? "booted")
            }

            // Bold Text (Tier 2)
            tier2Row(label: "Bold Text", icon: "bold",
                     isOn: service.boldText) {
                service.setBoldText(!service.boldText, udid: udid ?? "booted")
            }

            if let warning = service.tier2Warning {
                Text(warning)
                    .font(.caption2).foregroundStyle(.orange)
                    .padding(.horizontal, Spacing.md)
                    .padding(.bottom, Spacing.xs)
            }
        }
    }

    // MARK: - Row Helpers

    private func overrideRow<I: View>(
        label: String, icon: String,
        action: @escaping () -> Void,
        @ViewBuilder indicator: () -> I
    ) -> some View {
        Button(action: action) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: icon).imageScale(.small).frame(width: 16)
                Text(label).font(.body)
                Spacer()
                indicator()
            }
            .padding(.horizontal, Spacing.md)
            .frame(height: SideWindowMetrics.rowHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
    }

    private func tier2Row(label: String, icon: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: icon).imageScale(.small).frame(width: 16)
                Text(label).font(.body)
                Spacer()
                if isOn { Image(systemName: "checkmark").imageScale(.small).foregroundStyle(.secondary) }
                Image(systemName: "exclamationmark.triangle")
                    .imageScale(.small).foregroundStyle(.orange)
                    .help("May require app relaunch")
            }
            .padding(.horizontal, Spacing.md)
            .frame(height: SideWindowMetrics.rowHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
    }

    private var noSimulatorRow: some View {
        Text("No simulator detected")
            .font(.caption).foregroundStyle(.secondary)
            .padding(.horizontal, Spacing.md)
            .frame(height: SideWindowMetrics.rowHeight, alignment: .leading)
    }

    // Abbreviate long size names for the stepper display
    private func shortSizeName(_ name: String) -> String {
        name.replacingOccurrences(of: "accessibility-", with: "a11y-")
            .replacingOccurrences(of: "extra-extra-extra-large", with: "3XL")
            .replacingOccurrences(of: "extra-extra-large", with: "2XL")
            .replacingOccurrences(of: "extra-large", with: "XL")
            .replacingOccurrences(of: "extra-small", with: "XS")
    }
}
