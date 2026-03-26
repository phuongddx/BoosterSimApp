// GeneralTab.swift — General preferences: position picker, show toggle, launch at login
import SwiftUI

struct GeneralTab: View {

    @ObservedObject var settings: AppSettings

    var body: some View {
        Form {
            Section("Side Window") {
                Picker("Position", selection: $settings.position) {
                    ForEach(SideWindowPosition.allCases, id: \.self) { pos in
                        Label(pos.label, systemImage: pos.icon).tag(pos)
                    }
                }
                .pickerStyle(.menu)

                Toggle("Show side window when Simulator is open", isOn: $settings.showSideWindow)
            }

            Section("Startup") {
                Toggle("Launch at login", isOn: Binding(
                    get: { settings.launchAtLogin },
                    set: { settings.setLaunchAtLogin($0) }
                ))
            }
        }
        .formStyle(.grouped)
        .frame(width: PreferencesMetrics.width, height: PreferencesMetrics.height)
    }
}

#Preview {
    GeneralTab(settings: AppSettings())
}
