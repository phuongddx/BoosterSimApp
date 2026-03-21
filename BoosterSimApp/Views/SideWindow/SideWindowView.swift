// SideWindowView.swift — Root SwiftUI view hosted in SideWindowPanel
import SwiftUI

struct SideWindowView: View {

    @ObservedObject var tracker: SimulatorWindowTracker
    @ObservedObject var controller: SideWindowController

    // MARK: - Feature data (MVP: all "Coming soon")

    private let captureItems: [FeatureItem] = [
        FeatureItem(icon: "camera", label: "Screenshot"),
        FeatureItem(icon: "video", label: "Record Screen"),
        FeatureItem(icon: "film", label: "GIF Recording"),
        FeatureItem(icon: "square.and.arrow.up", label: "Video Export")
    ]

    private let actionItems: [FeatureItem] = [
        FeatureItem(icon: "arrow.counterclockwise", label: "Reset App"),
        FeatureItem(icon: "key", label: "Clear Keychain"),
        FeatureItem(icon: "bell", label: "Push Notification"),
        FeatureItem(icon: "link", label: "Deep Link")
    ]

    private let designItems: [FeatureItem] = [
        FeatureItem(icon: "grid", label: "Grid Overlay"),
        FeatureItem(icon: "rectangle.dashed", label: "Safe Area Overlay"),
        FeatureItem(icon: "ruler", label: "Ruler"),
        FeatureItem(icon: "eyedropper", label: "Color Picker")
    ]

    private let networkItems: [FeatureItem] = [
        FeatureItem(icon: "tortoise", label: "Throttle Network"),
        FeatureItem(icon: "xmark.shield", label: "Block Requests"),
        FeatureItem(icon: "list.bullet.rectangle", label: "View Logs"),
        FeatureItem(icon: "lock.shield", label: "Certificates")
    ]

    // MARK: - Body

    var body: some View {
        if controller.isCollapsed {
            CollapsedStripView(onExpand: { controller.toggleCollapsed() })
        } else {
            VStack(spacing: 0) {
                SideWindowTitleBar(onCollapse: { controller.toggleCollapsed() })

                DeviceHeaderView(simulator: tracker.activeSimulator)

                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 0) {
                        FeatureSectionView(title: "Captures", icon: "camera", items: captureItems)
                        FeatureSectionView(title: "App Actions", icon: "bolt", items: actionItems)
                        FeatureSectionView(title: "Design Tools", icon: "ruler", items: designItems)
                        FeatureSectionView(title: "Network", icon: "network", items: networkItems)
                    }
                }

                SideWindowFooter()
            }
            .frame(width: SideWindowMetrics.expandedWidth)
        }
    }
}
