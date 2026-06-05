// ActionsTabView.swift — Actions tab: environment overrides + deep link testing + quick actions
import SwiftUI

struct ActionsTabView: View {

    let udid: String?
    @State private var isDeepLinkExpanded = true

    @EnvironmentObject var envOverrideService: EnvironmentOverrideService
    @EnvironmentObject var deepLinkService: DeepLinkService

    var body: some View {
        ScrollView {
            EnvironmentOverridesView(udid: udid)

            CollapsibleSection(title: "Deep Link Testing", icon: "link", isExpanded: $isDeepLinkExpanded) {
                DeepLinkSectionView(deepLinkService: deepLinkService, udid: udid)
            }
        }
    }
}
