// DesignTabView.swift — Design tab: comparison tools, grid, ruler, color picker
import SwiftUI

struct DesignTabView: View {

    @EnvironmentObject var designComparisonService: DesignComparisonService

    var body: some View {
        ScrollView {
            CollapsibleSection(title: "Design Comparison", icon: "paintbrush") {
                DesignComparisonView(service: designComparisonService)
            }
        }
    }
}
