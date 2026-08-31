// PrivacySectionView.swift — 12 TCC privacy services grant/revoke with honest D-01 captions
import SwiftUI

struct PrivacySectionView: View {

    let udidProvider: () -> String?
    let deviceNameProvider: () -> String

    @EnvironmentObject var appActionService: AppActionService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isExpanded = false
    @State private var showResetAllConfirm = false

    private var activeUDID: String? { udidProvider() }
    private var activeApp: DiscoveredApp? {
        appActionService.candidates.first(where: { $0.bundleID == appActionService.activeBundleID })
    }
    private var isDisabled: Bool { activeUDID == nil || activeApp == nil }
    private var animation: Animation { reduceMotion ? .linear(duration: 0.1) : .easeInOut(duration: 0.2) }

    // MARK: - Body

    var body: some View {
        CollapsibleSection(title: "Privacy", icon: "hand.raised", isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                if isDisabled {
                    helperBanner("No active Simulator or app — pick an app above to scope privacy changes.")
                        .padding(.top, Spacing.sm)
                }
                ForEach(PrivacyPermission.allCases, id: \.self) { permission in
                    serviceRow(permission).padding(.horizontal, Spacing.md)
                }
                resetAllButton.padding(.horizontal, Spacing.md)
                statusRow.padding(.horizontal, Spacing.md)
                terminateWarningCaption.padding(.horizontal, Spacing.md)
                notificationsPointerCaption.padding(.horizontal, Spacing.md)
            }
            .padding(.bottom, Spacing.sm)
            .animation(animation, value: appActionService.privacyCaption)
        }
        .confirmationDialog("Reset All Privacy Services?", isPresented: $showResetAllConfirm, titleVisibility: .visible) {
            Button("Cancel", role: .cancel) {}
            Button("Reset All", role: .destructive) {
                if let udid = activeUDID { appActionService.resetAllPrivacy(udid: udid) }
            }
        } message: {
            Text("Resets every TCC privacy service — calendar, contacts, location, photos, "
                + "microphone, and the rest — on \(deviceNameProvider()), for all apps, not just "
                + "\(activeApp?.name ?? "the active app"). Notification permission is not affected; "
                + "it is managed by iOS.")
        }
    }

    // MARK: - Service Rows

    /// One compact row per supported TCC service: label + Grant/Revoke action capsules.
    /// There is deliberately no row (and no control) for notification permission — D-01.
    private func serviceRow(_ permission: PrivacyPermission) -> some View {
        HStack(spacing: Spacing.xs) {
            Text(permission.label)
                .font(.caption)
                .foregroundStyle(.primary)
                .lineLimit(1)
            Spacer()
            actionCapsule(permission, action: .grant)
            actionCapsule(permission, action: .revoke)
        }
        .frame(minHeight: SideWindowMetrics.compactRowHeight)
        .opacity(isDisabled ? 0.5 : 1)
    }

    private func actionCapsule(_ permission: PrivacyPermission, action: PrivacyAction) -> some View {
        Button {
            guard let udid = activeUDID else { return }
            appActionService.setPrivacy(permission, action: action, udid: udid, bundleID: activeApp?.bundleID)
        } label: {
            Text(action.label)
                .font(.caption2)
                .foregroundStyle(action == .grant ? Color.primary : Color.secondary)
                .padding(.horizontal, Spacing.sm)
                .frame(minHeight: SideWindowMetrics.compactRowHeight)
                .background(Color.secondary.opacity(0.15), in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .accessibilityLabel("\(action.label) \(permission.label) for \(activeApp?.name ?? "the active app")")
    }

    // MARK: - Reset All (destructive — the only destructive action, behind its confirm)

    private var resetAllButton: some View {
        Button { showResetAllConfirm = true } label: {
            Label("Reset All Privacy", systemImage: "arrow.counterclockwise.circle")
                .font(.caption)
                .foregroundStyle(.red)
        }
        .buttonStyle(.plain)
        .disabled(activeUDID == nil)
        .opacity(activeUDID == nil ? 0.5 : 1)
    }

    // MARK: - Status

    private var statusRow: some View {
        HStack(spacing: Spacing.xs) {
            if let caption = appActionService.privacyCaption {
                Image(systemName: "info.circle").foregroundStyle(.secondary)
                Text(caption)
            }
            Spacer()
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Honest Captions

    /// Apple help verbatim: some permission changes terminate the running app.
    private var terminateWarningCaption: some View {
        Text("Some permission changes will terminate the application if running.")
            .font(.caption2)
            .foregroundStyle(.secondary)
    }

    /// D-01 pointer: notification permission is NOT among these services and is never settable here.
    private var notificationsPointerCaption: some View {
        Text("Notification permission is not among these services — it is managed by iOS "
            + "(see Push Notifications).")
            .font(.caption2)
            .foregroundStyle(.secondary)
    }

    // MARK: - Helpers

    private func helperBanner(_ text: String, icon: String = "exclamationmark.circle") -> some View {
        HStack(alignment: .top, spacing: Spacing.xs) {
            Image(systemName: icon).foregroundStyle(.secondary).font(.caption)
            Text(text).font(.caption2).foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.xs)
        .background(Color.yellow.opacity(0.1), in: RoundedRectangle(cornerRadius: CornerRadius.small))
        .padding(.horizontal, Spacing.md)
    }
}

// MARK: - Preview

#Preview {
    PrivacySectionView(udidProvider: { nil }, deviceNameProvider: { "iPhone 17" })
        .environmentObject(AppActionService(simCtl: SimCtlService(), certificateService: CertificateService(simCtl: SimCtlService())))
        .frame(width: 260)
}
