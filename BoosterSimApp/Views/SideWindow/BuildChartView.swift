// BuildChartView.swift — Canvas bar chart of recent build durations
import SwiftUI

struct BuildChartView: View {

    let records: [BuildRecord]

    var body: some View {
        Canvas { context, size in
            guard !records.isEmpty else { return }
            let maxDuration = records.map(\.duration).max() ?? 1
            let barWidth    = size.width / CGFloat(records.count)

            for (i, record) in records.enumerated() {
                let barHeight = CGFloat(record.duration / maxDuration) * size.height
                let rect = CGRect(
                    x: CGFloat(i) * barWidth,
                    y: size.height - barHeight,
                    width: max(barWidth - 2, 1),
                    height: barHeight
                )
                let color: Color = record.succeeded ? .orange : .red
                context.fill(Path(rect), with: .color(color.opacity(0.85)))
            }
        }
        .frame(height: 56)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
    }
}

#Preview {
    let records: [BuildRecord] = [
        BuildRecord(id: "1", schemeName: "MyApp", startDate: .now, duration: 12.5,  succeeded: true,  errorCount: 0, warningCount: 2),
        BuildRecord(id: "2", schemeName: "MyApp", startDate: .now, duration: 8.3,   succeeded: false, errorCount: 3, warningCount: 0),
        BuildRecord(id: "3", schemeName: "MyApp", startDate: .now, duration: 45.1,  succeeded: true,  errorCount: 0, warningCount: 1),
        BuildRecord(id: "4", schemeName: "MyApp", startDate: .now, duration: 6.7,   succeeded: true,  errorCount: 0, warningCount: 0),
        BuildRecord(id: "5", schemeName: "MyApp", startDate: .now, duration: 120.0, succeeded: false, errorCount: 1, warningCount: 5),
    ]
    BuildChartView(records: records)
        .frame(width: SideWindowMetrics.expandedWidth)
        .padding()
}
