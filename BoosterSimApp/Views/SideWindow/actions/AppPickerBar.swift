// AppPickerBar.swift — Horizontal candidate picker for DerivedData apps installed on the Simulator
import SwiftUI

struct AppPickerBar: View {

    @EnvironmentObject private var appActionService: AppActionService

    var body: some View {
        if appActionService.candidates.isEmpty {
            emptyCaption
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.xs) {
                    ForEach(appActionService.candidates) { app in
                        candidatePill(app)
                    }
                }
                .padding(.horizontal, Spacing.md)
            }
            .frame(height: SideWindowMetrics.compactRowHeight)
        }
    }

    // MARK: - Candidates

    private func candidatePill(_ app: DiscoveredApp) -> some View {
        let isSelected = appActionService.activeBundleID == app.bundleID
        let isRunning = appActionService.runningBundleIDs.contains(app.bundleID)
        return Button {
            // Explicit tap-to-select ONLY — no frontmost guessing (RESEARCH Pitfall 11).
            appActionService.activeBundleID = app.bundleID
        } label: {
            HStack(spacing: Spacing.xxs) {
                if isRunning {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 6))
                        .foregroundStyle(.green)
                }
                Text(app.name)
                    .font(.caption2.weight(isSelected ? .semibold : .regular))
                    .lineLimit(1)
            }
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .padding(.horizontal, Spacing.sm)
            .frame(minHeight: SideWindowMetrics.compactRowHeight)
            .background(
                isSelected ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(Color.secondary.opacity(0.15)),
                in: Capsule()
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(app.name), bundle \(app.bundleID)")
        .accessibilityHint(isRunning ? "Currently running" : "Installed on this Simulator")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .help(app.alternativePaths.isEmpty
              ? "Latest DerivedData build of this app"
              : "Latest of \(app.alternativePaths.count + 1) DerivedData builds for this app")
    }

    private var emptyCaption: some View {
        Text("No installed apps found in DerivedData — build and run an app from Xcode first")
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, Spacing.md)
            .frame(maxWidth: .infinity, minHeight: SideWindowMetrics.compactRowHeight, alignment: .leading)
    }
}

// MARK: - Preview

#Preview {
    let simCtl = SimCtlService()
    let service = AppActionService(simCtl: simCtl, certificateService: CertificateService(simCtl: simCtl))
    AppPickerBar()
        .environmentObject(service)
        .frame(width: SideWindowMetrics.expandedWidth)
}
