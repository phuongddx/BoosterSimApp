// ActionsTabView.swift — Actions tab: env overrides + deep link testing + app picker + app reset
import SwiftUI

struct ActionsTabView: View {

    let udid: String?
    let deviceName: String
    @State private var isDeepLinkExpanded = true
    @State private var isAppResetExpanded = true

    @EnvironmentObject var envOverrideService: EnvironmentOverrideService
    @EnvironmentObject var deepLinkService: DeepLinkService
    @EnvironmentObject var appActionService: AppActionService

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.xxs) {
                AppPickerBar()

                EnvironmentOverridesView(udid: udid)

                CollapsibleSection(title: "Deep Link Testing", icon: "link", isExpanded: $isDeepLinkExpanded) {
                    DeepLinkSectionView(deepLinkService: deepLinkService, udid: udid)
                }
                PrivacySectionView(udidProvider: { udid }, deviceNameProvider: { deviceName })

                AppResetSectionView(udidProvider: { udid }, deviceNameProvider: { deviceName })
            }
        }
        .onAppear { appActionService.refreshApps(udid: udid) }
        .onChange(of: udid) { _, newUDID in
            appActionService.refreshApps(udid: newUDID)
        }
    }
}
