import SwiftUI

struct CertificateSectionView: View {
    let udidProvider: () -> String?
    let deviceNameProvider: () -> String

    @EnvironmentObject var certService: CertificateService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isExpanded = true
    @State private var showResetConfirm = false
    @AppStorage("certFirstUseHintDismissed") private var hintDismissed = false

    private var activeUDID: String? { udidProvider() }
    private var isWorking: Bool { certService.operation.isWorking }
    private var metadata: CertificateMetadata? { certService.status.certificateMetadata }
    private var animation: Animation { reduceMotion ? .linear(duration: 0.1) : .easeInOut(duration: 0.2) }

    var body: some View {
        CollapsibleSection(title: "Certificates", icon: "lock.shield", isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                statusRow.padding(.horizontal, Spacing.md).padding(.top, Spacing.sm)
                if let metadata { detailsRow(metadata) }
                if activeUDID == nil { helperBanner("No active Simulator with a concrete UDID. Generate works without one; install, rotate, and reset do not.") }
                primaryButton.padding(.horizontal, Spacing.md)
                if metadata != nil { secondaryActions.padding(.horizontal, Spacing.md) }
                if !hintDismissed, case .notGenerated = certService.status {
                    helperBanner("Generate a CA and install it in the Simulator to test HTTPS traffic. Keep ca.key private. Anyone with it can intercept HTTPS for any site.", icon: "info.circle", dismissible: true)
                }
            }
            .padding(.bottom, Spacing.sm)
            .animation(animation, value: certService.status)
            .animation(animation, value: certService.operation)
        }
        .confirmationDialog("Reset Simulator Keychain?", isPresented: $showResetConfirm, titleVisibility: .visible) {
            Button("Cancel", role: .cancel) {}
            Button("Reset Everything", role: .destructive) { if let udid = activeUDID { certService.resetKeychain(udid: udid) } }
        } message: {
            Text("This wipes all keychain data in \(deviceNameProvider()), including certificates installed by other tools, app passwords, and tokens. There is no undo.")
        }
    }

    private var statusRow: some View {
        HStack(spacing: Spacing.xs) {
            switch certService.operation {
            case .generating:
                ProgressView().scaleEffect(0.7); Text("Generating CA…")
            case .installing:
                ProgressView().scaleEffect(0.7); Text("Installing into Simulator…")
            case .rotating:
                ProgressView().scaleEffect(0.7); Text("Rotating CA…")
            case .resetting:
                ProgressView().scaleEffect(0.7); Text("Resetting keychain…")
            case .error(let message):
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange); Text(message)
            case .idle:
                idleStatus
            }
            Spacer()
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var idleStatus: some View {
        switch certService.status {
        case .notGenerated:
            Image(systemName: "circle").foregroundStyle(.secondary); Text("No CA certificate")
        case .generated:
            Image(systemName: "exclamationmark.circle.fill").foregroundStyle(.yellow); Text("Generated — not installed")
        case .installed(_, _, _, let deviceName, _):
            Image(systemName: "checkmark.seal.fill").foregroundStyle(.green); Text("Installed in \(deviceName)")
        case .unknown(_, _, _, let reason):
            Image(systemName: "questionmark.circle.fill").foregroundStyle(.orange); Text(reason)
        }
    }

    private func detailsRow(_ metadata: CertificateMetadata) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(metadata.commonName).font(.caption).foregroundStyle(.primary)
            Text("Expires \(metadata.expiry.formatted(date: .abbreviated, time: .omitted))").font(.caption2).foregroundStyle(.tertiary)
        }
        .padding(.horizontal, Spacing.md)
    }

    private func helperBanner(_ text: String, icon: String = "exclamationmark.circle", dismissible: Bool = false) -> some View {
        HStack(alignment: .top, spacing: Spacing.xs) {
            Image(systemName: icon).foregroundStyle(.secondary).font(.caption)
            Text(text).font(.caption2).foregroundStyle(.secondary)
            Spacer()
            if dismissible {
                Button { hintDismissed = true } label: { Image(systemName: "xmark").font(.caption2).foregroundStyle(.tertiary) }
                    .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.xs)
        .background(Color.yellow.opacity(0.1), in: RoundedRectangle(cornerRadius: CornerRadius.small))
        .padding(.horizontal, Spacing.md)
    }

    private var primaryButton: some View {
        Button(action: primaryAction) {
            Label(primaryTitle, systemImage: primarySymbol)
                .font(.caption.weight(.medium))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.sm)
                .background(Color.accentColor, in: RoundedRectangle(cornerRadius: CornerRadius.small))
        }
        .buttonStyle(.plain)
        .disabled(isWorking || (needsUDID && activeUDID == nil))
        .opacity(isWorking || (needsUDID && activeUDID == nil) ? 0.5 : 1)
    }

    private var secondaryActions: some View {
        HStack {
            Button {
                if let udid = activeUDID { certService.rotate(udid: udid, deviceName: deviceNameProvider()) }
            } label: {
                Label("Rotate CA", systemImage: "arrow.triangle.2.circlepath").font(.caption).foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .disabled(isWorking || activeUDID == nil)

            Spacer()

            Button { showResetConfirm = true } label: {
                Label("Reset Keychain", systemImage: "trash").font(.caption).foregroundStyle(.red)
            }
            .buttonStyle(.plain)
            .disabled(isWorking || activeUDID == nil)
        }
    }

    private var primaryTitle: String {
        if case .error = certService.operation { return "Retry" }
        switch certService.status {
        case .notGenerated: return "Generate CA"
        case .generated: return "Install to Simulator"
        case .installed: return "Reinstall"
        case .unknown: return "Reinstall to Verify"
        }
    }

    private var primarySymbol: String {
        if case .error = certService.operation { return "arrow.clockwise" }
        switch certService.status {
        case .notGenerated: return "plus"
        case .generated, .installed: return "arrow.down.circle"
        case .unknown: return "checkmark.arrow.trianglehead.counterclockwise"
        }
    }

    private var needsUDID: Bool {
        if case .error = certService.operation, case .notGenerated = certService.status { return false }
        switch certService.status {
        case .notGenerated: return false
        case .generated, .installed, .unknown: return true
        }
    }

    private func primaryAction() {
        hintDismissed = true
        if case .error = certService.operation {
            certService.retry(udid: activeUDID ?? "", deviceName: deviceNameProvider())
            return
        }
        switch certService.status {
        case .notGenerated:
            certService.generateCA()
        case .generated, .installed, .unknown:
            if let udid = activeUDID { certService.install(udid: udid, deviceName: deviceNameProvider()) }
        }
    }
}
