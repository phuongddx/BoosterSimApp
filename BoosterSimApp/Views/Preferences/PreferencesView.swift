// PreferencesView.swift — Root preferences window with General and About tabs
import SwiftUI

struct PreferencesView: View {

    @ObservedObject var settings: AppSettings

    var body: some View {
        TabView {
            GeneralTab(settings: settings)
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }

            AboutTab(settings: settings)
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(width: PreferencesMetrics.width, height: PreferencesMetrics.height)
    }
}
