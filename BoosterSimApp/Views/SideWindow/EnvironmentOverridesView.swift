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

            Divider().padding(.horizontal, Spacing.md)

            // Reduce Motion
            overrideRow(label: "Reduce Motion", icon: "waveform.path") {
                service.setReduceMotion(!service.reduceMotion, udid: udid ?? "booted")
            } indicator: {
                if service.reduceMotion {
                    Image(systemName: "checkmark").imageScale(.small).foregroundStyle(.secondary)
                }
            }

            // Bold Text
            overrideRow(label: "Bold Text", icon: "bold") {
                service.setBoldText(!service.boldText, udid: udid ?? "booted")
            } indicator: {
                if service.boldText {
                    Image(systemName: "checkmark").imageScale(.small).foregroundStyle(.secondary)
                }
            }

            // Reduce Transparency
            overrideRow(label: "Reduce Transparency", icon: "rectangle.on.rectangle") {
                service.setReduceTransparency(!service.reduceTransparency, udid: udid ?? "booted")
            } indicator: {
                if service.reduceTransparency {
                    Image(systemName: "checkmark").imageScale(.small).foregroundStyle(.secondary)
                }
            }

            Divider().padding(.horizontal, Spacing.md)

            // Button Shapes
            overrideRow(label: "Button Shapes", icon: "rectangle.and.hand.point.up.left") {
                service.setButtonShapes(!service.buttonShapes, udid: udid ?? "booted")
            } indicator: {
                if service.buttonShapes {
                    Image(systemName: "checkmark").imageScale(.small).foregroundStyle(.secondary)
                }
            }

            // On/Off Labels
            overrideRow(label: "On/Off Labels", icon: "switch.2") {
                service.setOnOffLabels(!service.onOffLabels, udid: udid ?? "booted")
            } indicator: {
                if service.onOffLabels {
                    Image(systemName: "checkmark").imageScale(.small).foregroundStyle(.secondary)
                }
            }

            // Grayscale
            overrideRow(label: "Grayscale", icon: "circle.lefthalf.strikethrough") {
                service.setGrayscale(!service.grayscale, udid: udid ?? "booted")
            } indicator: {
                if service.grayscale {
                    Image(systemName: "checkmark").imageScale(.small).foregroundStyle(.secondary)
                }
            }

            // Invert Colors
            overrideRow(label: "Invert Colors", icon: "circle.inset.filled") {
                service.setInvertColors(!service.invertColors, udid: udid ?? "booted")
            } indicator: {
                if service.invertColors {
                    Image(systemName: "checkmark").imageScale(.small).foregroundStyle(.secondary)
                }
            }

            // Differentiate without Color
            overrideRow(label: "Differentiate w/o Color", icon: "circle.hexagongrid") {
                service.setDifferentiateWithoutColor(!service.differentiateWithoutColor, udid: udid ?? "booted")
            } indicator: {
                if service.differentiateWithoutColor {
                    Image(systemName: "checkmark").imageScale(.small).foregroundStyle(.secondary)
                }
            }
        }
        .onAppear {
            if let udid { service.loadCurrentState(udid: udid) }
        }
        .onChange(of: udid) { _, newUdid in
            if let newUdid { service.loadCurrentState(udid: newUdid) }
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
