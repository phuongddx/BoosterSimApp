// BuildStatsSectionView.swift — Xcode build history with bar chart and build list
import SwiftUI

struct BuildStatsSectionView: View {

    @EnvironmentObject var service: BuildStatsService

    private var avgDuration: Double {
        guard !service.recentBuilds.isEmpty else { return 0 }
        return service.recentBuilds.map(\.duration).reduce(0, +) / Double(service.recentBuilds.count)
    }

    private var avgFormatted: String {
        avgDuration < 60
            ? String(format: "%.1fs", avgDuration)
            : String(format: "%.0fm %.0fs", avgDuration / 60, avgDuration.truncatingRemainder(dividingBy: 60))
    }

    var body: some View {
        VStack(spacing: 0) {
            sectionHeader
            if service.recentBuilds.isEmpty {
                emptyRow
            } else {
                chartRow
                buildList
            }
        }
    }

    // MARK: - Sub-views

    private var sectionHeader: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: "hammer")
                .imageScale(.small).foregroundStyle(.secondary)
            Text("Build Stats")
                .font(.subheadline).fontWeight(.medium).foregroundStyle(.secondary)
            Spacer()
            if !service.recentBuilds.isEmpty {
                Text("\(service.recentBuilds.count) builds · avg \(avgFormatted)")
                    .font(.caption2).foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, Spacing.md)
        .frame(height: SideWindowMetrics.compactRowHeight)
    }

    private var chartRow: some View {
        BuildChartView(records: Array(service.recentBuilds.prefix(20)))
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.xs)
    }

    private var buildList: some View {
        ForEach(service.recentBuilds.prefix(10)) { record in
            HStack(spacing: Spacing.sm) {
                Image(systemName: record.succeeded ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .imageScale(.small)
                    .foregroundStyle(record.succeeded ? .green : .red)
                    .frame(width: 16)

                Text(record.schemeName)
                    .font(.body).lineLimit(1)

                Spacer()

                VStack(alignment: .trailing, spacing: 1) {
                    Text(record.formattedDuration)
                        .font(.caption).fontWeight(.medium).foregroundStyle(.primary)
                    Text(record.formattedDate)
                        .font(.caption2).foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, Spacing.md)
            .frame(height: SideWindowMetrics.rowHeight)
        }
    }

    private var emptyRow: some View {
        Text("No builds found in DerivedData")
            .font(.caption).foregroundStyle(.secondary)
            .padding(.horizontal, Spacing.md)
            .frame(height: SideWindowMetrics.rowHeight, alignment: .leading)
    }
}
