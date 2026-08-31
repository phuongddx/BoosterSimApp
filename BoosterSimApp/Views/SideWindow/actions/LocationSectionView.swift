// LocationSectionView.swift — Location simulation: validated coords, tz-syncing city presets, paired Stop
import SwiftUI

struct LocationSectionView: View {

    let udidProvider: () -> String?

    @EnvironmentObject var appActionService: AppActionService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isExpanded = false
    @State private var latText = ""
    @State private var lonText = ""

    private var activeUDID: String? { udidProvider() }
    private var activeApp: DiscoveredApp? {
        appActionService.candidates.first(where: { $0.bundleID == appActionService.activeBundleID })
    }
    private var animation: Animation { reduceMotion ? .linear(duration: 0.1) : .easeInOut(duration: 0.2) }

    private var hasCoordinateText: Bool {
        !latText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !lonText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    /// Inline typed validation BEFORE any verb — the same pure function the service gates on.
    private var validation: Result<[String], CoordinateError> {
        AppActionService.locationSetCommand(udid: "", lat: latText, lon: lonText)
    }
    private var isValid: Bool {
        if case .success = validation { return true }
        return false
    }

    // MARK: - Body

    var body: some View {
        CollapsibleSection(title: "Location", icon: "location", isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                if activeUDID == nil {
                    helperBanner("No active Simulator — location simulation needs a running device.")
                        .padding(.top, Spacing.sm)
                }
                if appActionService.hasSimulatedLocation {
                    activeSimulationBanner.padding(.horizontal, Spacing.md)
                }
                coordinateRows.padding(.horizontal, Spacing.md)
                if hasCoordinateText, case .failure(let error) = validation {
                    inlineError(error.message).padding(.horizontal, Spacing.md)
                }
                setClearRow.padding(.horizontal, Spacing.md)
                presetPillsRow.padding(.horizontal, Spacing.md)
                relaunchCaption.padding(.horizontal, Spacing.md)
                scopeCaption.padding(.horizontal, Spacing.md)
                statusRow.padding(.horizontal, Spacing.md)
            }
            .padding(.bottom, Spacing.sm)
            .animation(animation, value: appActionService.hasSimulatedLocation)
            .animation(animation, value: appActionService.locationCaption)
        }
    }

    // MARK: - Active Simulation (Pitfall 10 — the Stop is always visible while active)

    private var activeSimulationBanner: some View {
        HStack(alignment: .top, spacing: Spacing.xs) {
            Image(systemName: "location.fill")
                .foregroundStyle(.orange).font(.caption)
            Text("Simulation active — Clear stops it and restores the real/none location.")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(Spacing.xs)
        .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: CornerRadius.small))
        .accessibilityElement(children: .combine)
    }

    // MARK: - Manual Coordinates

    private var coordinateRows: some View {
        HStack(spacing: Spacing.xs) {
            TextField("Latitude (e.g. 35.6762)", text: $latText)
            TextField("Longitude (e.g. 139.6503)", text: $lonText)
        }
        .font(.caption)
        .textFieldStyle(.roundedBorder)
        .frame(minHeight: SideWindowMetrics.compactRowHeight)
    }

    private var setClearRow: some View {
        HStack(spacing: Spacing.xs) {
            Button {
                guard let udid = activeUDID else { return }
                appActionService.setLocation(lat: latText, lon: lonText, udid: udid)
            } label: {
                Label("Set", systemImage: "mappin")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.xs)
                    .background(Color.accentColor, in: RoundedRectangle(cornerRadius: CornerRadius.small))
            }
            .buttonStyle(.plain)
            .disabled(activeUDID == nil || !isValid)
            .opacity(activeUDID == nil || !isValid ? 0.5 : 1)

            clearButton
        }
    }

    /// The paired Stop: always rendered, prominent (filled red) while a simulation is
    /// active, quiet otherwise — state-driven via hasSimulatedLocation, never guesswork.
    private var clearButton: some View {
        let isActive = appActionService.hasSimulatedLocation
        return Button {
            guard let udid = activeUDID else { return }
            appActionService.clearLocation(udid: udid)
        } label: {
            Label("Clear", systemImage: "location.slash")
                .font(.caption.weight(isActive ? .semibold : .medium))
                .foregroundStyle(isActive ? Color.white : Color.red)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.xs)
                .background(isActive ? Color.red.opacity(0.85) : Color.red.opacity(0.12),
                            in: RoundedRectangle(cornerRadius: CornerRadius.small))
        }
        .buttonStyle(.plain)
        .disabled(activeUDID == nil)
        .opacity(activeUDID == nil ? 0.5 : 1)
        .accessibilityLabel(isActive ? "Stop the active location simulation" : "Clear location simulation")
    }

    // MARK: - City Presets (location + timezone in one action)

    private var presetPillsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.xs) {
                ForEach(CityPreset.allCases) { preset in
                    presetPill(preset)
                }
            }
        }
    }

    /// One tap sets coordinates AND writes the matching timezone, relaunching the app
    /// for the timezone half (GPS + timezone sync in one action).
    private func presetPill(_ preset: CityPreset) -> some View {
        Button {
            guard let udid = activeUDID else { return }
            appActionService.applyLocationPreset(preset: preset, udid: udid, bundleID: activeApp?.bundleID)
        } label: {
            Text(preset.name)
                .font(.caption2.weight(.medium))
                .foregroundStyle(Color.primary)
                .padding(.horizontal, Spacing.sm)
                .frame(minHeight: SideWindowMetrics.compactRowHeight)
                .background(Color.secondary.opacity(0.15), in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(activeUDID == nil)
        .opacity(activeUDID == nil ? 0.5 : 1)
        .accessibilityLabel("Set location and timezone to \(preset.name)")
    }

    // MARK: - Honest Captions

    /// The timezone half of a city preset is a relaunch-domain write (Pitfall 6) — but the
    /// relaunch only happens when an app is active; with none selected, the write takes
    /// effect on every app's next launch (03-REVIEW WR-01).
    private var relaunchCaption: some View {
        HStack(alignment: .top, spacing: Spacing.xs) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .foregroundStyle(.secondary).font(.caption2)
            Text(activeApp != nil
                ? "City presets also switch the timezone — that half takes effect on next "
                    + "app launch; the app is relaunched automatically."
                : "City presets also switch the timezone — that half takes effect on every "
                    + "app's next launch.")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .accessibilityElement(children: .combine)
    }

    /// Honest scope: the simulation is device-wide for CoreLocation consumers.
    private var scopeCaption: some View {
        HStack(alignment: .top, spacing: Spacing.xs) {
            Image(systemName: "globe.desk")
                .foregroundStyle(.secondary).font(.caption2)
            Text("Device-wide simulation — applies immediately to apps reading CoreLocation "
                + "(Maps, Weather). Clear restores the real/none location.")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Status

    private var statusRow: some View {
        HStack(alignment: .top, spacing: Spacing.xs) {
            if let caption = appActionService.locationCaption {
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
    LocationSectionView(udidProvider: { "booted" })
        .environmentObject(AppActionService(simCtl: SimCtlService(),
                                            certificateService: CertificateService(simCtl: SimCtlService())))
        .frame(width: SideWindowMetrics.expandedWidth)
}
