// MenuBarView.swift — SwiftUI menu content for the MenuBarExtra
import SwiftUI
import Sparkle

struct MenuBarView: View {

    @EnvironmentObject var appDelegate: AppDelegate
    @AppStorage("completedOnboarding") private var completedOnboarding = false

    var body: some View {
        // Show/Hide side window
        Button(appDelegate.sideWindowController.isVisible ? "Hide Side Window" : "Show Side Window") {
            appDelegate.sideWindowController.toggle()
        }
        .keyboardShortcut("b", modifiers: .command)

        Divider()

        // Simulators section
        Text("Simulators")
            .font(.caption)
            .foregroundStyle(.secondary)

        let sims = appDelegate.tracker.simulators
        if sims.isEmpty {
            Text("No Simulators Running")
                .foregroundStyle(.secondary)
                .padding(.leading, Spacing.sm)
        } else {
            ForEach(sims) { sim in
                Label(sim.displayName, systemImage: "iphone")
                    .padding(.leading, Spacing.xs)
            }
        }

        Divider()

        SettingsLink {
            Text("Preferences...")
        }
        .keyboardShortcut(",", modifiers: .command)

        Divider()
        Button("Check for Updates…") {
            appDelegate.updaterController.checkForUpdates(nil)
        }

        Button("About BoosterSim") {
            NSApp.orderFrontStandardAboutPanel(nil)
            NSApp.activate(ignoringOtherApps: true)
        }

        Button("Quit BoosterSim") {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q", modifiers: .command)
    }
}

#Preview {
    MenuBarView()
        .environmentObject(AppDelegate())
}
