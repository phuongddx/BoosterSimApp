// BoosterSimAppApp.swift — @main SwiftUI App entry point
// LSUIElement = true (no Dock icon). AppDelegate owns AppKit services.
import SwiftUI

@main
struct BoosterSimAppApp: App {

    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Menu bar icon — bolt.fill (connected), bolt.slash (disconnected)
        MenuBarExtra("BoosterSim", systemImage: "bolt.fill") {
            MenuBarView()
                .environmentObject(appDelegate)
        }
        .menuBarExtraStyle(.menu)

        // Native Preferences window (Cmd+,) — shares AppDelegate's settings instance
        Settings {
            PreferencesView(settings: appDelegate.settings)
        }
    }
}
