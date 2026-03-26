// EnvironmentOverridesView.swift — Appearance and accessibility override controls
import SwiftUI

struct EnvironmentOverridesView: View {

    @EnvironmentObject var service: EnvironmentOverrideService
    let udid: String?

    private var isDisabled: Bool { udid == nil }
    private var effectiveUDID: String { udid ?? "booted" }

    var body: some View {
        if isDisabled {
            noSimulatorRow
        } else {
            controls
        }
    }

    // MARK: - Controls

    private var controls: some View {
        VStack(spacing: 0) {
            // ACCESSIBILITY group
            subsectionHeader("Accessibility")

            toggleRow("Increase Contrast",      icon: "circle.lefthalf.filled",
                isOn: binding(\.increaseContrast,   { service.setIncreaseContrast($0, udid: effectiveUDID) }))
            toggleRow("Reduce Transparency",     icon: "rectangle.on.rectangle",
                isOn: binding(\.reduceTransparency, { service.setReduceTransparency($0, udid: effectiveUDID) }))
            toggleRow("Bold Text",               icon: "bold",
                isOn: binding(\.boldText,           { service.setBoldText($0, udid: effectiveUDID) }))
            toggleRow("Reduce Motion",           icon: "waveform.path",
                isOn: binding(\.reduceMotion,       { service.setReduceMotion($0, udid: effectiveUDID) }))
            toggleRow("On/Off Labels",           icon: "switch.2",
                isOn: binding(\.onOffLabels,        { service.setOnOffLabels($0, udid: effectiveUDID) }))
            toggleRow("Button Shapes",           icon: "rectangle.and.hand.point.up.left",
                isOn: binding(\.buttonShapes,       { service.setButtonShapes($0, udid: effectiveUDID) }))
            toggleRow("Grayscale",               icon: "circle.lefthalf.strikethrough",
                isOn: binding(\.grayscale,          { service.setGrayscale($0, udid: effectiveUDID) }))
            toggleRow("Invert Colors",           icon: "circle.inset.filled",
                isOn: binding(\.invertColors,       { service.setInvertColors($0, udid: effectiveUDID) }))
            toggleRow("Differentiate w/o Color", icon: "circle.hexagongrid",
                isOn: binding(\.differentiateWithoutColor, { service.setDifferentiateWithoutColor($0, udid: effectiveUDID) }))

            Divider().padding(.horizontal, Spacing.md)

            // APPEARANCE group
            subsectionHeader("Appearance")

            toggleRow("Dark Mode", icon: "moon",
                isOn: Binding(
                    get: { service.appearance == .dark },
                    set: { service.setAppearance($0 ? .dark : .light, udid: effectiveUDID) }))

            Divider().padding(.horizontal, Spacing.md)

            // DYNAMIC TYPE group
            subsectionHeader("Dynamic Type")

            dynamicTypeSlider
        }
        .onAppear {
            if let udid { service.loadCurrentState(udid: udid) }
        }
        .onChange(of: udid) { _, newUdid in
            if let newUdid { service.loadCurrentState(udid: newUdid) }
        }
    }

    // MARK: - Row Helpers

    private func subsectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.subheadline).fontWeight(.medium)
            .foregroundStyle(.secondary)
            .padding(.horizontal, Spacing.md)
            .padding(.top, Spacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Icon + label on left, native macOS switch toggle on right
    private func toggleRow(_ label: String, icon: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: icon).imageScale(.small).frame(width: 16)
            Text(label).font(.body)
            Spacer()
            Toggle("", isOn: isOn)
                .toggleStyle(.switch)
                .labelsHidden()
        }
        .padding(.horizontal, Spacing.md)
        .frame(height: SideWindowMetrics.rowHeight)
        .disabled(isDisabled)
    }

    /// Creates a Binding<Bool> from a service keyPath + setter closure
    private func binding(_ keyPath: KeyPath<EnvironmentOverrideService, Bool>,
                         _ setter: @escaping (Bool) -> Void) -> Binding<Bool> {
        Binding(get: { service[keyPath: keyPath] }, set: setter)
    }

    private var dynamicTypeSlider: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(spacing: Spacing.sm) {
                Text("A").font(.caption).foregroundStyle(.secondary)
                Slider(
                    value: Binding(
                        get: { Double(service.contentSizeIndex) },
                        set: { service.setContentSizeIndex(Int($0.rounded()), udid: effectiveUDID) }
                    ),
                    in: 0...Double(EnvironmentOverrideService.contentSizes.count - 1),
                    step: 1
                )
                .disabled(isDisabled)
                Text("A").font(.title3).foregroundStyle(.secondary)
            }
            Text(service.currentSizeName)
                .font(.caption2).foregroundStyle(.secondary)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.xs)
    }

    private var noSimulatorRow: some View {
        Text("No simulator detected")
            .font(.caption).foregroundStyle(.secondary)
            .padding(.horizontal, Spacing.md)
            .frame(height: SideWindowMetrics.rowHeight, alignment: .leading)
    }
}

#Preview("With simulator") {
    EnvironmentOverridesView(udid: "booted")
        .environmentObject(EnvironmentOverrideService(simCtl: SimCtlService()))
        .frame(width: SideWindowMetrics.expandedWidth)
}

#Preview("No simulator") {
    EnvironmentOverridesView(udid: nil)
        .environmentObject(EnvironmentOverrideService(simCtl: SimCtlService()))
        .frame(width: SideWindowMetrics.expandedWidth)
}
