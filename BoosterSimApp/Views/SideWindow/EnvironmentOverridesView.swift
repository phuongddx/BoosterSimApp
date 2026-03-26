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
            groupHeader("Accessibility")

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

            // APPEARANCE group
            groupHeader("Appearance")

            toggleRow("Dark Mode", icon: "moon",
                isOn: Binding(
                    get: { service.appearance == .dark },
                    set: { service.setAppearance($0 ? .dark : .light, udid: effectiveUDID) }))

            dynamicTypeRow
        }
        .onAppear {
            if let udid { service.loadCurrentState(udid: udid) }
        }
        .onChange(of: udid) { _, newUdid in
            if let newUdid { service.loadCurrentState(udid: newUdid) }
        }
    }

    // MARK: - Row Helpers

    /// Caps-style muted group label matching RocketSim section header pattern
    private func groupHeader(_ title: String) -> some View {
        HStack {
            Text(title.uppercased())
                .font(.caption2).fontWeight(.semibold)
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .padding(.horizontal, Spacing.md)
        .frame(height: SideWindowMetrics.compactRowHeight)
        .padding(.top, Spacing.xs)
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

    private var dynamicTypeRow: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "textformat.size").imageScale(.small).frame(width: 16)
            Text("Dynamic Type").font(.body)
            Spacer()
            HStack(spacing: Spacing.xs) {
                Button { service.decrementContentSize(udid: effectiveUDID) }
                    label: { Image(systemName: "minus").imageScale(.small) }
                    .buttonStyle(.plain)
                    .disabled(service.contentSizeIndex == 0)

                Text(shortSizeName(service.currentSizeName))
                    .font(.caption2).foregroundStyle(.secondary).frame(minWidth: 28)

                Button { service.incrementContentSize(udid: effectiveUDID) }
                    label: { Image(systemName: "plus").imageScale(.small) }
                    .buttonStyle(.plain)
                    .disabled(service.contentSizeIndex == EnvironmentOverrideService.contentSizes.count - 1)
            }
        }
        .padding(.horizontal, Spacing.md)
        .frame(height: SideWindowMetrics.rowHeight)
        .disabled(isDisabled)
    }

    private var noSimulatorRow: some View {
        Text("No simulator detected")
            .font(.caption).foregroundStyle(.secondary)
            .padding(.horizontal, Spacing.md)
            .frame(height: SideWindowMetrics.rowHeight, alignment: .leading)
    }

    private func shortSizeName(_ name: String) -> String {
        name.replacingOccurrences(of: "accessibility-", with: "a11y-")
            .replacingOccurrences(of: "extra-extra-extra-large", with: "3XL")
            .replacingOccurrences(of: "extra-extra-large", with: "2XL")
            .replacingOccurrences(of: "extra-large", with: "XL")
            .replacingOccurrences(of: "extra-small", with: "XS")
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
