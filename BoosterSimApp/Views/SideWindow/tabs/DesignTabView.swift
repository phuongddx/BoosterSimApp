// DesignTabView.swift — Design tab: comparison tools, grid, ruler, color picker
import SwiftUI

struct DesignTabView: View {

    @EnvironmentObject var designComparisonService: DesignComparisonService
    @State private var isDesignExpanded = true

    var body: some View {
        ScrollView {
            CollapsibleSection(title: "Design Comparison", icon: "paintbrush", isExpanded: $isDesignExpanded) {
                DesignComparisonView(service: designComparisonService)
            }
        }
    }
}
