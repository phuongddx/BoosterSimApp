// BoosterHealthApp.swift — Minimal companion app: receives boosterhealth:// URLs and writes HealthKit data
import SwiftUI
import HealthKit
import Combine

@main
struct BoosterHealthApp: App {

    @StateObject private var viewModel = CompanionViewModel()

    var body: some Scene {
        WindowGroup {
            CompanionView(viewModel: viewModel)
                .onOpenURL { url in
                    viewModel.handleURL(url)
                }
        }
    }
}

// MARK: - ViewModel

@MainActor
final class CompanionViewModel: ObservableObject {
    @Published var authGranted = false
    @Published var status: String = ""

    private let generator = HealthDataGenerator()

    func requestAuth() async {
        authGranted = await generator.requestAuthorization()
    }

    func handleURL(_ url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return }

        if components.host == "clear" {
            Task {
                status = "Clearing…"
                await generator.clearAll()
                status = "Cleared"
            }
        } else if let payload = HealthPayload.parse(from: url) {
            Task {
                status = "Generating…"
                await generator.generate(payload: payload)
                status = "Done"
            }
        }
    }
}

// MARK: - Minimal Auth View (shown until Health permissions are granted)

struct CompanionView: View {
    @ObservedObject var viewModel: CompanionViewModel

    var body: some View {
        VStack(spacing: 16) {
            if viewModel.authGranted {
                Image(systemName: "checkmark.circle.fill")
                    .font(.largeTitle).foregroundStyle(.green)
                Text(viewModel.status.isEmpty ? "Ready" : viewModel.status)
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                Image(systemName: "heart.text.square")
                    .font(.largeTitle).foregroundStyle(.pink)
                Text("BoosterHealth needs access to write Health data.")
                    .font(.caption).multilineTextAlignment(.center)
                Button("Grant Health Access") {
                    Task { await viewModel.requestAuth() }
                }
                .buttonStyle(.borderedProminent)
                .tint(.pink)
            }
        }
        .padding()
        .frame(width: 260, height: 200)
        .task { await viewModel.requestAuth() }
    }
}
