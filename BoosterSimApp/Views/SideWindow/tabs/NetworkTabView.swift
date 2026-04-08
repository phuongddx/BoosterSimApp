// NetworkTabView.swift — Network tab: certificates + network tools
import SwiftUI

struct NetworkTabView: View {

    let udidProvider: () -> String?
    let deviceNameProvider: () -> String

    @EnvironmentObject var certificateService: CertificateService

    private let networkItems: [FeatureItem] = [
        FeatureItem(icon: "tortoise",              label: "Throttle Network"),
        FeatureItem(icon: "xmark.shield",          label: "Block Requests"),
        FeatureItem(icon: "list.bullet.rectangle", label: "View Logs")
    ]

    var body: some View {
        ScrollView {
            CertificateSectionView(
                udidProvider: udidProvider,
                deviceNameProvider: deviceNameProvider
            )

            FeatureSectionView(title: "Network Tools", icon: "network", items: networkItems)
        }
    }
}
