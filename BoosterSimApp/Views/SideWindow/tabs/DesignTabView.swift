// DesignTabView.swift — Design tab: grid overlay, safe area, ruler, color picker
import SwiftUI

struct DesignTabView: View {

    private let items: [FeatureItem] = [
        FeatureItem(icon: "grid",             label: "Grid Overlay"),
        FeatureItem(icon: "rectangle.dashed", label: "Safe Area Overlay"),
        FeatureItem(icon: "ruler",            label: "Ruler"),
        FeatureItem(icon: "eyedropper",       label: "Color Picker")
    ]

    var body: some View {
        ScrollView {
            FeatureSectionView(title: "Design Tools", icon: "paintbrush", items: items)
        }
    }
}

#Preview {
    DesignTabView()
        .frame(width: SideWindowMetrics.expandedWidth, height: 400)
}
