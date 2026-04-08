// CaptureTabView.swift — Capture tab: screenshot, recording, GIF, export
import SwiftUI

struct CaptureTabView: View {

    private let items: [FeatureItem] = [
        FeatureItem(icon: "camera",              label: "Screenshot"),
        FeatureItem(icon: "video",               label: "Record Screen"),
        FeatureItem(icon: "film",                label: "GIF Recording"),
        FeatureItem(icon: "square.and.arrow.up", label: "Video Export")
    ]

    var body: some View {
        ScrollView {
            FeatureSectionView(title: "Captures", icon: "camera", items: items)
        }
    }
}

#Preview {
    CaptureTabView()
        .frame(width: SideWindowMetrics.expandedWidth, height: 400)
}
