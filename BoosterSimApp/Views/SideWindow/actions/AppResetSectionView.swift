// AppResetSectionView.swift — App Reset section: reset app data + uninstall behind destructive confirms
import SwiftUI

struct AppResetSectionView: View {

    let udidProvider: () -> String?
    let deviceNameProvider: () -> String

    @EnvironmentObject var appActionService: AppActionService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isExpanded = true
    @State private var showResetConfirm = false
    @State private var showUninstallConfirm = false

    private var activeUDID: String? { udidProvider() }
    private var activeApp: DiscoveredApp? {
        appActionService.candidates.first(where: { $0.bundleID == appActionService.activeBundleID })
    }
    private var appName: String { activeApp?.name ?? "The app" }
    private var isWorking: Bool { appActionService.operation.isWorking }
    private var isDisabled: Bool { isWorking || activeApp == nil || activeUDID == nil }
    private var animation: Animation { reduceMotion ? .linear(duration: 0.1) : .easeInOut(duration: 0.2) }

    var body: some View {
        CollapsibleSection(title: "App Reset", icon: "arrow.uturn.backward", isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                if activeUDID == nil {
                    helperBanner("No active Simulator — destructive app actions need a running device "
                              + "with a concrete UDID.")
                }
                resetButton.padding(.horizontal, Spacing.md)
                uninstallButton.padding(.horizontal, Spacing.md)
                statusRow.padding(.horizontal, Spacing.md)
            }
            .padding(.bottom, Spacing.sm)
            .animation(animation, value: appActionService.operation)
        }
        .confirmationDialog("Reset App Data?", isPresented: $showResetConfirm, titleVisibility: .visible) {
            Button("Cancel", role: .cancel) {}
            Button("Reset \(appName) Data", role: .destructive) {
                if let udid = activeUDID, let app = activeApp {
                    appActionService.resetApp(udid: udid, bundleID: app.bundleID)
                }
            }
        } message: {
            Text("Terminates \(appName) if running, uninstalls it, and erases its container data — "
                + "preferences, defaults, and saved state. "
                + "Reinstalls from your latest DerivedData build when one exists.")
        }
        .confirmationDialog("Uninstall \(appName)?", isPresented: $showUninstallConfirm, titleVisibility: .visible) {
            Button("Cancel", role: .cancel) {}
            Button("Uninstall", role: .destructive) {
                if let udid = activeUDID, let app = activeApp {
                    appActionService.uninstallApp(udid: udid, bundleID: app.bundleID)
                }
            }
        } message: {
            Text("Removes \(appName) and its data container from \(deviceNameProvider()).")
        }
    }

    // MARK: - Actions

    private var resetButton: some View {
        Button { showResetConfirm = true } label: {
            Label("Reset App Data", systemImage: "arrow.uturn.backward")
                .font(.caption.weight(.medium))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.sm)
                .background(Color.accentColor, in: RoundedRectangle(cornerRadius: CornerRadius.small))
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.5 : 1)
    }

    private var uninstallButton: some View {
        Button { showUninstallConfirm = true } label: {
            Label("Uninstall", systemImage: "trash")
                .font(.caption)
                .foregroundStyle(.red)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.5 : 1)
    }

    // MARK: - Status

    private var statusRow: some View {
        HStack(spacing: Spacing.xs) {
            switch appActionService.operation {
            case .refreshing:
                ProgressView().scaleEffect(0.7); Text("Loading apps…")
            case .clearingKeychain:
                ProgressView().scaleEffect(0.7); Text("Clearing keychain…")
            case .resetting:
                ProgressView().scaleEffect(0.7); Text("Resetting app…")
            case .uninstalling:
                ProgressView().scaleEffect(0.7); Text("Uninstalling…")
            case .error(let message):
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange); Text(message)
            case .idle:
                if let caption = appActionService.statusCaption {
                    Image(systemName: "info.circle").foregroundStyle(.secondary); Text(caption)
                }
            }
            Spacer()
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .accessibilityElement(children: .combine)
    }

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
    let simCtl = SimCtlService()
    let service = AppActionService(simCtl: simCtl, certificateService: CertificateService(simCtl: simCtl))
    AppResetSectionView(udidProvider: { "booted" }, deviceNameProvider: { "iPhone 17" })
        .environmentObject(service)
        .frame(width: SideWindowMetrics.expandedWidth)
}
