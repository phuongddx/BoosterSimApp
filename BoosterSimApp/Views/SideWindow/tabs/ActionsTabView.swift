// ActionsTabView.swift — Actions tab: environment overrides + quick actions
import SwiftUI

struct ActionsTabView: View {

    let udid: String?

    @EnvironmentObject var envOverrideService: EnvironmentOverrideService

    private let actionItems: [FeatureItem] = [
        FeatureItem(icon: "arrow.counterclockwise", label: "Reset App"),
        FeatureItem(icon: "key",                    label: "Clear Keychain"),
        FeatureItem(icon: "bell",                   label: "Push Notification"),
        FeatureItem(icon: "link",                   label: "Deep Link")
    ]

    var body: some View {
        ScrollView {
            EnvironmentOverridesView(udid: udid)

            FeatureSectionView(title: "Quick Actions", icon: "bolt", items: actionItems)
        }
    }
}
