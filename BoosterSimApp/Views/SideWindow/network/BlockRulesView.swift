// BlockRulesView.swift — Network tab section: domain/path block-rule editor
import SwiftUI

struct BlockRulesView: View {

    @EnvironmentObject var networkConditionService: NetworkConditionService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var isExpanded = false
    @State private var newDomain = ""
    @State private var newPathPrefix = ""

    /// Rule-count cap — bounded O(rules) matching per request (threat T-05-02).
    private static let maxRules = 50

    private var animation: Animation {
        reduceMotion ? .linear(duration: 0.1) : .easeInOut(duration: 0.2)
    }

    private var atCap: Bool {
        networkConditionService.rules.count >= Self.maxRules
    }

    private var canAdd: Bool {
        !atCap && !newDomain.trimmingCharacters(in: .whitespaces).isEmpty
    }

    // MARK: - Body

    var body: some View {
        CollapsibleSection(title: "Block Rules", icon: "shield.lefthalf.filled", isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                if networkConditionService.rules.isEmpty {
                    emptyCaption
                } else {
                    ForEach(networkConditionService.rules) { rule in
                        ruleRow(rule)
                    }
                }
                addRow
                if atCap {
                    capCaption
                }
            }
            .padding(.top, Spacing.xs)
            .padding(.bottom, Spacing.sm)
            .animation(animation, value: networkConditionService.rules)
        }
    }

    // MARK: - Rule Rows

    private func ruleRow(_ rule: BlockRule) -> some View {
        HStack(spacing: Spacing.sm) {
            Text(rule.domain)
                .font(.body)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .truncationMode(.middle)

            if let prefix = rule.pathPrefix, !prefix.isEmpty {
                Text(prefix)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .padding(.horizontal, Spacing.xs)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.12), in: Capsule())
            }

            Spacer()

            Toggle("", isOn: enabledBinding(rule))
                .toggleStyle(.switch)
                .labelsHidden()
                .accessibilityLabel("Block requests to \(rule.domain)")

            Button {
                networkConditionService.removeRule(id: rule.id)
            } label: {
                Image(systemName: "trash")
                    .imageScale(.small)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Delete rule \(rule.domain)")
        }
        .padding(.horizontal, Spacing.md)
        .frame(height: SideWindowMetrics.rowHeight)
    }

    private func enabledBinding(_ rule: BlockRule) -> Binding<Bool> {
        Binding(
            get: { rule.isEnabled },
            set: { networkConditionService.setRuleEnabled(id: rule.id, enabled: $0) }
        )
    }

    // MARK: - Add Rule

    private var addRow: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            TextField("domain or *.domain.com", text: $newDomain)
                .textFieldStyle(.roundedBorder)
                .onSubmit(addRule)

            HStack(spacing: Spacing.xs) {
                TextField("/api/path", text: $newPathPrefix)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(addRule)

                Button(action: addRule) {
                    Image(systemName: "plus")
                        .imageScale(.small)
                        .foregroundStyle(canAdd ? Color.accentColor : Color.secondary)
                }
                .buttonStyle(.plain)
                .disabled(!canAdd)
                .accessibilityLabel("Add block rule")
            }
        }
        .padding(.horizontal, Spacing.md)
    }

    private func addRule() {
        let domain = newDomain.trimmingCharacters(in: .whitespaces)
        guard !domain.isEmpty, !atCap else { return }
        let prefix = newPathPrefix.trimmingCharacters(in: .whitespaces)
        networkConditionService.addRule(
            BlockRule(id: UUID(), domain: domain, pathPrefix: prefix.isEmpty ? nil : prefix)
        )
        newDomain = ""
        newPathPrefix = ""
    }

    // MARK: - Captions

    /// Honest scope disclosure (PRO-01): blocking applies only to URLSession
    /// HTTP(S) traffic of apps embedding BoosterSimConnect.
    private var emptyCaption: some View {
        Text("No rules yet. Matching hosts fail with a connection error in apps embedding BoosterSimConnect — URLSession HTTP(S) only.")
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, Spacing.md)
    }

    private var capCaption: some View {
        Text("Rule limit reached (\(Self.maxRules)). Delete a rule to add another.")
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, Spacing.md)
    }
}
