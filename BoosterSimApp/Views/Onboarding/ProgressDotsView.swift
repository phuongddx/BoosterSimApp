// ProgressDotsView.swift — 4-dot step progress indicator
import SwiftUI

struct ProgressDotsView: View {

    let total: Int
    let current: Int

    var body: some View {
        HStack(spacing: Spacing.sm) {
            ForEach(0..<total, id: \.self) { index in
                Circle()
                    .fill(index == current ? Color.accentColor : Color.secondary.opacity(0.3))
                    .frame(width: OnboardingMetrics.dotSize, height: OnboardingMetrics.dotSize)
                    .animation(.easeInOut(duration: 0.2), value: current)
            }
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        ProgressDotsView(total: 4, current: 0)
        ProgressDotsView(total: 4, current: 2)
        ProgressDotsView(total: 4, current: 3)
    }
    .padding()
}
