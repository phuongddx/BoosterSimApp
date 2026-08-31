// PushNotificationSectionView.swift — JSON push payload editor + D-01 guided permission control
import SwiftUI

struct PushNotificationSectionView: View {

    let udidProvider: () -> String?
    let deviceNameProvider: () -> String

    @EnvironmentObject var appActionService: AppActionService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isExpanded = true
    @State private var payloadText = ""

    private var activeUDID: String? { udidProvider() }
    private var activeApp: DiscoveredApp? {
        appActionService.candidates.first(where: { $0.bundleID == appActionService.activeBundleID })
    }
    private var byteCount: Int { PushPayload.encodedByteCount(of: payloadText) }
    private var isOverCap: Bool { byteCount > PushPayload.maxEncodedBytes }
    /// Within 10% of the cap (integer math — no rounding literals).
    private var isNearCap: Bool { byteCount * 10 >= PushPayload.maxEncodedBytes * 9 }
    private var counterColor: Color { isOverCap ? .red : (isNearCap ? .orange : .secondary) }
    private var isEditorEmpty: Bool {
        payloadText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    /// Inline gate: the typed parse/validate result, so errors show BEFORE any send.
    private var validationError: PushPayloadError? {
        guard !isEditorEmpty else { return nil }
        switch PushPayload.parse(payloadText) {
        case .failure(let error): return error
        case .success(let payload): return payload.validate()
        }
    }
    private var canSend: Bool {
        activeUDID != nil && activeApp != nil && !isEditorEmpty
            && validationError == nil && !appActionService.isSendingPush
    }
    private var animation: Animation { reduceMotion ? .linear(duration: 0.1) : .easeInOut(duration: 0.2) }

    // MARK: - Body

    var body: some View {
        CollapsibleSection(title: "Push Notifications", icon: "bell.badge", isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                if activeUDID == nil || activeApp == nil {
                    helperBanner("No active Simulator or app — pick an app above to target pushes.")
                        .padding(.top, Spacing.sm)
                }
                TextEditor(text: $payloadText)
                    .font(.system(.caption, design: .monospaced))
                    .frame(height: Spacing.xxl * 4)   // ~5 JSON lines on the 4pt grid
                    .padding(.horizontal, Spacing.md)
                templatePillsRow
                    .padding(.horizontal, Spacing.md)
                byteCounterCaption
                    .padding(.horizontal, Spacing.md)
                if let error = validationError {
                    inlineError(error)
                        .padding(.horizontal, Spacing.md)
                }
                sendButton
                    .padding(.horizontal, Spacing.md)
                resultBlock
                    .padding(.horizontal, Spacing.md)
                permissionBlock
                    .padding(.horizontal, Spacing.md)
            }
            .padding(.bottom, Spacing.sm)
            .animation(animation, value: appActionService.pushResult)
            .animation(animation, value: appActionService.isSendingPush)
        }
    }

    // MARK: - Template Pills

    private var templatePillsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.xs) {
                templatePill("Alert", payload: PushPayload.templateAlert())
                templatePill("Alert + Sound", payload: PushPayload.templateAlertSound())
                templatePill("Badge + Alert", payload: PushPayload.templateBadgeAlert())
            }
        }
    }

    private func templatePill(_ title: String, payload: PushPayload) -> some View {
        Button {
            if let data = try? JSONEncoder().encode(payload),
               let text = String(data: data, encoding: .utf8) {
                payloadText = text
            }
        } label: {
            Text(title)
                .font(.caption2.weight(.medium))
                .foregroundStyle(Color.primary)
                .padding(.horizontal, Spacing.sm)
                .frame(minHeight: SideWindowMetrics.compactRowHeight)
                .background(Color.secondary.opacity(0.15), in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Insert \(title) payload template")
    }

    // MARK: - Byte Counter

    private var byteCounterCaption: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: isOverCap ? "exclamationmark.triangle.fill" : "textformat.123")
                .foregroundStyle(counterColor)
            Text("\(byteCount) / \(PushPayload.maxEncodedBytes) bytes")
                .font(.caption2)
                .foregroundStyle(counterColor)
            Spacer()
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Inline Validation

    private func inlineError(_ error: PushPayloadError) -> some View {
        HStack(alignment: .top, spacing: Spacing.xs) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .font(.caption)
            Text(error.message)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(Spacing.xs)
        .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: CornerRadius.medium))
    }

    // MARK: - Send (also the D-01 verify probe)

    private var sendButton: some View {
        Button {
            guard let udid = activeUDID else { return }
            appActionService.sendPush(udid: udid, bundleID: activeApp?.bundleID, payloadText: payloadText)
        } label: {
            Group {
                if appActionService.isSendingPush {
                    HStack(spacing: Spacing.xs) {
                        ProgressView().scaleEffect(0.7)
                        Text("Sending…")
                    }
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white)
                } else {
                    Label("Send Push", systemImage: "paperplane.fill")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.sm)
            .background(Color.accentColor, in: RoundedRectangle(cornerRadius: CornerRadius.small))
        }
        .buttonStyle(.plain)
        .disabled(!canSend)
        .opacity(!canSend && !appActionService.isSendingPush ? 0.5 : 1)
    }

    // MARK: - Result

    @ViewBuilder
    private var resultBlock: some View {
        if let result = appActionService.pushResult {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: result.isSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(result.isSuccess ? .green : .orange)
                    Text(result.caption)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                if result.isSuccess {
                    // D-01: Send IS the probe — remind what a silent banner means.
                    Text("A banner appears only when the app has notification permission.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(Spacing.sm)
            .background(
                result.isSuccess ? Color.green.opacity(0.1) : Color.orange.opacity(0.1),
                in: RoundedRectangle(cornerRadius: CornerRadius.medium)
            )
        }
    }

    // MARK: - Permission (D-01 — locked: guided manual grant, never a fake toggle)

    /// simctl cannot grant or revoke notification authorization (no privacy service exists).
    /// This control guides the manual grant honestly: caption, Settings link, inline steps,
    /// and the Send button as the test-push probe. No control here toggles permission state.
    private var permissionBlock: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Label("Notification permission is managed by iOS — it cannot be set from here.",
                  systemImage: "lock.shield")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("Grant it manually on the Simulator: Settings → Notifications → "
                + "\(activeApp?.name ?? "the app") → Allow. Then use Send as the test probe — "
                + "a delivered banner is the proof.")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Button {
                if let udid = activeUDID {
                    appActionService.openDeviceSettings(udid: udid)
                }
            } label: {
                Label("Open Settings", systemImage: "gearshape")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .foregroundColor(.accentColor)
            .disabled(activeUDID == nil)
            .opacity(activeUDID == nil ? 0.5 : 1)
            .accessibilityLabel("Open the Simulator Settings app")
        }
        .padding(Spacing.xs)
        .background(Color.blue.opacity(0.05), in: RoundedRectangle(cornerRadius: CornerRadius.medium))
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

// MARK: - Result Extension

private extension PushActionResult {
    var isSuccess: Bool {
        if case .sent = self { return true }
        return false
    }

    var caption: String {
        switch self {
        case .sent(let line): return line
        case .failed(let message): return message
        }
    }
}

// MARK: - Preview

#Preview {
    PushNotificationSectionView(udidProvider: { nil }, deviceNameProvider: { "iPhone 17" })
        .environmentObject(AppActionService(simCtl: SimCtlService(), certificateService: CertificateService(simCtl: SimCtlService())))
        .frame(width: 260)
}
