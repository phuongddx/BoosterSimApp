// ClipboardSectionView.swift — Manual bidirectional clipboard sync via pbsync (two buttons only)
import SwiftUI

struct ClipboardSectionView: View {

    let udidProvider: () -> String?

    @EnvironmentObject var appActionService: AppActionService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isExpanded = false

    private var activeUDID: String? { udidProvider() }
    private var animation: Animation { reduceMotion ? .linear(duration: 0.1) : .easeInOut(duration: 0.2) }

    // MARK: - Body

    var body: some View {
        CollapsibleSection(title: "Clipboard", icon: "doc.on.doc", isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                if activeUDID == nil {
                    helperBanner("No active Simulator — clipboard sync needs a running device.")
                        .padding(.top, Spacing.sm)
                }
                syncButtonsRow.padding(.horizontal, Spacing.md)
                statusRow.padding(.horizontal, Spacing.md)
                textOnlyCaption.padding(.horizontal, Spacing.md)
                manualOnlyCaption.padding(.horizontal, Spacing.md)
            }
            .padding(.bottom, Spacing.sm)
            .animation(animation, value: appActionService.clipboardCaption)
        }
    }

    // MARK: - Sync Buttons (exactly two — manual triggers only, nothing runs in the background)

    private var syncButtonsRow: some View {
        HStack(spacing: Spacing.xs) {
            syncButton(.macToDevice)
            syncButton(.deviceToMac)
        }
    }

    private func syncButton(_ direction: ClipboardDirection) -> some View {
        Button {
            guard let udid = activeUDID else { return }
            appActionService.syncClipboard(direction: direction, udid: udid)
        } label: {
            Label(direction.label,
                  systemImage: direction == .macToDevice ? "arrow.right.circle" : "arrow.left.circle")
                .font(.caption.weight(.medium))
                .foregroundStyle(Color.primary)
                .frame(maxWidth: .infinity)
                .frame(minHeight: SideWindowMetrics.compactRowHeight)
                .background(Color.secondary.opacity(0.15), in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(activeUDID == nil)
        .opacity(activeUDID == nil ? 0.5 : 1)
        .accessibilityLabel("Sync the clipboard \(direction.label)")
    }

    // MARK: - Status (direction-status caption — carries no content)

    private var statusRow: some View {
        HStack(alignment: .top, spacing: Spacing.xs) {
            if let caption = appActionService.clipboardCaption {
                Image(systemName: "info.circle").foregroundStyle(.secondary)
                Text(caption)
            }
            Spacer()
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Honest Captions (A4 + T-03-08)

    /// Assumption A4: plain-text transfer is what was verified — rich types are not.
    private var textOnlyCaption: some View {
        HStack(alignment: .top, spacing: Spacing.xs) {
            Image(systemName: "textformat")
                .foregroundStyle(.secondary).font(.caption2)
            Text("Plain-text clipboard only — rich pasteboard types are not synced.")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .accessibilityElement(children: .combine)
    }

    /// Prohibition: manual triggers only — there is no background auto-sync, by design.
    private var manualOnlyCaption: some View {
        HStack(alignment: .top, spacing: Spacing.xs) {
            Image(systemName: "hand.tap")
                .foregroundStyle(.secondary).font(.caption2)
            Text("Sync runs only when you click — no background auto-sync, and the "
                + "content never leaves the pasteboards or reaches the logs.")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .accessibilityElement(children: .combine)
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
    ClipboardSectionView(udidProvider: { "booted" })
        .environmentObject(AppActionService(simCtl: SimCtlService(),
                                            certificateService: CertificateService(simCtl: SimCtlService())))
        .frame(width: SideWindowMetrics.expandedWidth)
}
