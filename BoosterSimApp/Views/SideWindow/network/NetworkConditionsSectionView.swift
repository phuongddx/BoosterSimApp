// NetworkConditionsSectionView.swift — Network tab section: airplane toggle + condition status
import SwiftUI

struct NetworkConditionsSectionView: View {

    @EnvironmentObject var networkConditionService: NetworkConditionService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isExpanded = false

    private var animation: Animation {
        reduceMotion ? .linear(duration: 0.1) : .easeInOut(duration: 0.2)
    }

    // MARK: - Body

    var body: some View {
        CollapsibleSection(title: "Network Conditions", icon: "network", isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                airplaneRow
                    .padding(.horizontal, Spacing.md)
                    .padding(.top, Spacing.sm)
                profilePillsRow
                    .padding(.horizontal, Spacing.md)
                effectiveConditionCaption
                    .padding(.horizontal, Spacing.md)
                statusRow
                    .padding(.horizontal, Spacing.md)
                scopeCaption
                    .padding(.horizontal, Spacing.md)
            }
            .padding(.bottom, Spacing.sm)
            .animation(animation, value: networkConditionService.state)
            .animation(animation, value: networkConditionService.selectedProfile)
        }
    }

    // MARK: - Airplane Toggle

    private var airplaneRow: some View {
        Toggle(isOn: airplaneBinding) {
            Label("Airplane Mode", systemImage: "airplane")
                .font(.caption)
        }
        .toggleStyle(.switch)
        .frame(minHeight: SideWindowMetrics.compactRowHeight)
        .accessibilityLabel("Airplane Mode")
    }

    private var airplaneBinding: Binding<Bool> {
        Binding(
            get: { networkConditionService.airplane },
            set: { networkConditionService.setAirplane($0) }
        )
    }

    // MARK: - Throttle Profile Pills

    /// One tap selects and applies (≤2-click rule). Airplane ON outranks
    /// throttle (verdict order) — the row disables while airplane is active.
    private var profilePillsRow: some View {
        HStack(spacing: Spacing.xs) {
            ForEach(NetworkConditionProfile.allCases) { profile in
                profilePill(profile)
            }
        }
        .disabled(networkConditionService.airplane)
        .opacity(networkConditionService.airplane ? 0.5 : 1)
    }

    private func profilePill(_ profile: NetworkConditionProfile) -> some View {
        let isSelected = networkConditionService.selectedProfile == profile
        return Button {
            networkConditionService.selectProfile(profile)
        } label: {
            Text(profile.displayName)
                .font(.caption2.weight(isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? Color.white : Color.primary)
                .padding(.horizontal, Spacing.sm)
                .frame(minHeight: SideWindowMetrics.compactRowHeight)
                .background(
                    isSelected ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(Color.secondary.opacity(0.15)),
                    in: Capsule()
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(pillAccessibilityLabel(profile))
    }

    /// VoiceOver caption, e.g. "3G, 400 milliseconds latency, 750 kilobits per second".
    private func pillAccessibilityLabel(_ profile: NetworkConditionProfile) -> String {
        guard let spec = profile.throttleSpec else { return "Off, no throttling" }
        return "\(profile.displayName), \(spec.latencyMs) milliseconds latency, \(spec.downloadKbps) kilobits per second"
    }

    // MARK: - Effective Condition

    /// Current effective condition: airplane outranks throttle (verdict order).
    private var effectiveConditionCaption: some View {
        Text(effectiveConditionText)
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    private var effectiveConditionText: String {
        if networkConditionService.airplane {
            return "Airplane Mode on"
        }
        if networkConditionService.selectedProfile.throttleSpec != nil {
            return "Throttling: \(networkConditionService.selectedProfile.caption)"
        }
        return "No conditions applied"
    }

    // MARK: - Status

    private var statusRow: some View {
        HStack(spacing: Spacing.xs) {
            switch networkConditionService.state {
            case .applying:
                ProgressView().scaleEffect(0.7); Text("Applying…")
            case .error(let message):
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange); Text(message)
            case .idle:
                Image(systemName: "circle").foregroundStyle(.secondary); Text("No conditions pushed")
            case .applied:
                Image(systemName: "checkmark.seal.fill").foregroundStyle(.green); Text("Snapshot pushed to connected apps")
            }
            Spacer()
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Scope Disclosure

    /// Honest scope disclosure (prohibition PRO-01): never present conditions
    /// as system-wide or Simulator-wide offline.
    private var scopeCaption: some View {
        Text("Affects URLSession HTTP(S) traffic in apps embedding BoosterSimConnect")
            .font(.caption)
            .foregroundStyle(.secondary)
    }
}
