// AboutTab.swift — About preferences: Xcode path, app version info
import SwiftUI

struct AboutTab: View {

    @ObservedObject var settings: AppSettings
    @State private var xcodePath: String = ""

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }
    private var buildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    }

    var body: some View {
        Form {
            Section("Xcode") {
                LabeledContent("Path") {
                    HStack {
                        Text(xcodePath.isEmpty ? "Not detected" : xcodePath)
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(xcodePath.isEmpty ? .secondary : .primary)
                            .lineLimit(1)
                            .truncationMode(.middle)

                        Spacer()

                        Button("Change...") {
                            selectXcode()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }

                LabeledContent("Status") {
                    HStack(spacing: Spacing.xs) {
                        Circle()
                            .fill(xcodePath.isEmpty ? Color.red : Color.green)
                            .frame(width: 8, height: 8)
                        Text(xcodePath.isEmpty ? "Not found" : "Detected")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("App") {
                LabeledContent("Version", value: "\(appVersion) (\(buildNumber))")
                LabeledContent("Build", value: "BoosterSim MVP")
            }
        }
        .formStyle(.grouped)
        .frame(width: PreferencesMetrics.width, height: PreferencesMetrics.height)
        .onAppear { loadXcodePath() }
    }

    // MARK: - Private

    private func loadXcodePath() {
        xcodePath = XcodeDetector.activeXcodePath() ?? settings.xcodePath
    }

    private func selectXcode() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.message = "Select Xcode Application"
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        if panel.runModal() == .OK, let url = panel.url {
            xcodePath = url.path
            settings.xcodePath = url.path
        }
    }
}
