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
                statusRow
                    .padding(.horizontal, Spacing.md)
                scopeCaption
                    .padding(.horizontal, Spacing.md)
            }
            .padding(.bottom, Spacing.sm)
            .animation(animation, value: networkConditionService.state)
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
