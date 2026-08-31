// LocaleSectionView.swift — Locale & region switching: presets + manual rows, relaunch-captioned writes
import SwiftUI

struct LocaleSectionView: View {

    let udidProvider: () -> String?

    @EnvironmentObject var appActionService: AppActionService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isExpanded = true
    @State private var manualLanguage = ""
    @State private var manualLocale = ""
    @State private var manualTimezone = ""

    private var activeUDID: String? { udidProvider() }
    private var activeApp: DiscoveredApp? {
        appActionService.candidates.first(where: { $0.bundleID == appActionService.activeBundleID })
    }
    private var isDisabled: Bool { activeUDID == nil || activeApp == nil }
    private var animation: Animation { reduceMotion ? .linear(duration: 0.1) : .easeInOut(duration: 0.2) }

    private var trimmedLanguage: String { manualLanguage.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var trimmedLocale: String { manualLocale.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var trimmedTimezone: String { manualTimezone.trimmingCharacters(in: .whitespacesAndNewlines) }

    /// Language and locale go together; the timezone may travel alone.
    private var manualPairError: String? {
        if trimmedLanguage.isEmpty != trimmedLocale.isEmpty {
            return "Language and locale go together — fill both (timezone may travel alone)."
        }
        return nil
    }
    private var canApplyManual: Bool {
        !isDisabled && manualPairError == nil
            && (!trimmedLanguage.isEmpty || !trimmedLocale.isEmpty || !trimmedTimezone.isEmpty)
    }

    // MARK: - Body

    var body: some View {
        CollapsibleSection(title: "Locale & Region", icon: "globe", isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                if isDisabled {
                    helperBanner("No active Simulator or app — pick an app above to apply locale changes.")
                        .padding(.top, Spacing.sm)
                }
                currentStateRow.padding(.horizontal, Spacing.md)
                presetBlock.padding(.horizontal, Spacing.md)
                manualRows.padding(.horizontal, Spacing.md)
                if let pairError = manualPairError,
                   !trimmedLanguage.isEmpty || !trimmedLocale.isEmpty {
                    inlineError(pairError).padding(.horizontal, Spacing.md)
                }
                applyBlock.padding(.horizontal, Spacing.md)
                deviceScopeCaption.padding(.horizontal, Spacing.md)
                statusRow.padding(.horizontal, Spacing.md)
            }
            .padding(.bottom, Spacing.sm)
            .animation(animation, value: appActionService.localeCaption)
        }
        .onAppear {
            if let udid = activeUDID { appActionService.readLocaleState(udid: udid) }
        }
        .onChange(of: activeUDID) { _, newUDID in
            if let newUDID { appActionService.readLocaleState(udid: newUDID) }
        }
    }

    // MARK: - Current State

    private var currentStateRow: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: "globe").foregroundStyle(.secondary).font(.caption)
            Text(currentStateText)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .accessibilityElement(children: .combine)
    }

    private var currentStateText: String {
        var parts: [String] = []
        if !appActionService.currentLanguages.isEmpty {
            parts.append(appActionService.currentLanguages.joined(separator: ", "))
        }
        if let locale = appActionService.currentLocaleID { parts.append(locale) }
        if let timezone = appActionService.currentTimezone { parts.append(timezone) }
        return parts.isEmpty ? "Current device locale not read yet."
                             : "Current: " + parts.joined(separator: " · ")
    }

    // MARK: - Preset Pills (each carries the relaunch caption — adjacency contract)

    private var presetBlock: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.xs) {
                    ForEach(LocalePreset.allCases) { preset in
                        presetPill(preset)
                    }
                }
            }
            relaunchCaption
        }
    }

    /// One tap writes languages + locale + timezone and relaunches the app (≤2-click rule).
    private func presetPill(_ preset: LocalePreset) -> some View {
        Button {
            guard let udid = activeUDID else { return }
            appActionService.applyLocale(languages: preset.languages,
                                          locale: preset.locale,
                                          timezone: preset.timezone,
                                          udid: udid,
                                          bundleID: activeApp?.bundleID)
        } label: {
            Text(preset.name)
                .font(.caption2.weight(.medium))
                .foregroundStyle(Color.primary)
                .padding(.horizontal, Spacing.sm)
                .frame(minHeight: SideWindowMetrics.compactRowHeight)
                .background(Color.secondary.opacity(0.15), in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.5 : 1)
        .accessibilityLabel("Apply \(preset.name) locale and relaunch the app")
    }

    // MARK: - Manual Rows

    private var manualRows: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(spacing: Spacing.xs) {
                manualField("Language (e.g. ja-JP)", text: $manualLanguage)
                manualField("Locale (e.g. ja_JP)", text: $manualLocale)
            }
            manualField("Timezone (e.g. Asia/Tokyo) — may travel alone", text: $manualTimezone)
        }
    }

    private func manualField(_ placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text)
            .font(.caption)
            .textFieldStyle(.roundedBorder)
            .frame(minHeight: SideWindowMetrics.compactRowHeight)
    }

    // MARK: - Apply (manual values; carries the relaunch caption — adjacency contract)

    private var applyBlock: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Button {
                guard let udid = activeUDID else { return }
                if !trimmedLanguage.isEmpty {
                    appActionService.applyLocale(languages: [trimmedLanguage],
                                                  locale: trimmedLocale,
                                                  timezone: trimmedTimezone.isEmpty ? nil : trimmedTimezone,
                                                  udid: udid,
                                                  bundleID: activeApp?.bundleID)
                } else if !trimmedTimezone.isEmpty {
                    appActionService.setTimezone(tz: trimmedTimezone,
                                                 udid: udid,
                                                 bundleID: activeApp?.bundleID)
                }
            } label: {
                Label("Apply", systemImage: "checkmark.circle")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.sm)
                    .background(Color.accentColor, in: RoundedRectangle(cornerRadius: CornerRadius.small))
            }
            .buttonStyle(.plain)
            .disabled(!canApplyManual)
            .opacity(!canApplyManual ? 0.5 : 1)
            relaunchCaption
        }
    }

    // MARK: - Honest Captions (Pitfall 6 prohibition + T-03-09 scope disclosure)

    /// Prohibition: never present these writes as instant — the write chain always relaunches.
    private var relaunchCaption: some View {
        HStack(alignment: .top, spacing: Spacing.xs) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .foregroundStyle(.secondary).font(.caption2)
            Text("Takes effect on next app launch — the app is relaunched automatically.")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .accessibilityElement(children: .combine)
    }

    /// Device-wide scope (A5): global-domain writes affect every app launched afterward.
    private var deviceScopeCaption: some View {
        HStack(alignment: .top, spacing: Spacing.xs) {
            Image(systemName: "globe.desk")
                .foregroundStyle(.secondary).font(.caption2)
            Text("Device-wide: changes the Simulator's global locale — every app picks it up "
                + "on its next launch; other running apps are unaffected until then.")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Status

    private var statusRow: some View {
        HStack(alignment: .top, spacing: Spacing.xs) {
            if let caption = appActionService.localeCaption {
                Image(systemName: "info.circle").foregroundStyle(.secondary)
                Text(caption)
            }
            Spacer()
        }
        .font(.caption)
        .foregroundStyle(.secondary)
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

    private func inlineError(_ message: String) -> some View {
        HStack(alignment: .top, spacing: Spacing.xs) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .font(.caption)
            Text(message)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(Spacing.xs)
        .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: CornerRadius.medium))
    }
}

// MARK: - Preview

#Preview {
    LocaleSectionView(udidProvider: { "booted" })
        .environmentObject(AppActionService(simCtl: SimCtlService(),
                                            certificateService: CertificateService(simCtl: SimCtlService())))
        .frame(width: SideWindowMetrics.expandedWidth)
}
