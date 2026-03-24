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
