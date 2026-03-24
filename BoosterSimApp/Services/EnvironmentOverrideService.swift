// EnvironmentOverrideService.swift — Appearance and accessibility overrides via xcrun simctl ui
import Foundation
import Combine

// MARK: - Models

enum AppearanceStyle: String {
    case light   = "light"
    case dark    = "dark"
    case unknown = "unknown"
}

// MARK: - Service

@MainActor
final class EnvironmentOverrideService: ObservableObject {

    // MARK: - Published State

    @Published var appearance: AppearanceStyle = .unknown
    @Published var increaseContrast: Bool = false
    @Published var reduceMotion: Bool = false
    @Published var boldText: Bool = false
    @Published var contentSizeIndex: Int = 3  // default = "large" (index 3)
    @Published var tier2Warning: String? = nil

    // MARK: - Constants

    static let contentSizes = [
        "extra-small", "small", "medium", "large", "extra-large",
        "extra-extra-large", "extra-extra-extra-large",
        "accessibility-medium", "accessibility-large",
        "accessibility-extra-large", "accessibility-extra-extra-large",
        "accessibility-extra-extra-extra-large"
    ]

    var currentSizeName: String { Self.contentSizes[contentSizeIndex] }

    // MARK: - Private

    private let simCtl: SimCtlService
    private var cancellables = Set<AnyCancellable>()

    init(simCtl: SimCtlService) { self.simCtl = simCtl }

    // MARK: - Public Methods

    func loadCurrentState(udid: String) {
        simCtl.run(["ui", udid, "appearance"])
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { [weak self] output in
                    let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                    self?.appearance = trimmed == "dark" ? .dark : .light
                }
            )
            .store(in: &cancellables)
    }

    func setAppearance(_ style: AppearanceStyle, udid: String) {
        appearance = style
        simCtl.runVoid(["ui", udid, "appearance", style.rawValue])
            .sink(receiveCompletion: { _ in }, receiveValue: { _ in })
            .store(in: &cancellables)
    }

    func setIncreaseContrast(_ enabled: Bool, udid: String) {
        increaseContrast = enabled
        simCtl.runVoid(["ui", udid, "increase_contrast", enabled ? "enabled" : "disabled"])
            .sink(receiveCompletion: { _ in }, receiveValue: { _ in })
            .store(in: &cancellables)
    }

    func incrementContentSize(udid: String) {
        guard contentSizeIndex < Self.contentSizes.count - 1 else { return }
        contentSizeIndex += 1
        applyContentSize(udid: udid)
    }

    func decrementContentSize(udid: String) {
        guard contentSizeIndex > 0 else { return }
        contentSizeIndex -= 1
        applyContentSize(udid: udid)
    }

    /// Tier 2 — undocumented, shows warning on failure.
    func setReduceMotion(_ enabled: Bool, udid: String) {
        reduceMotion = enabled
        runTier2(["spawn", "booted", "defaults", "write",
                  "com.apple.UIKit", "UIAccessibilityReduceMotionEnabled",
                  "-bool", enabled ? "YES" : "NO"],
                 warningKey: "reduceMotion")
    }

    /// Tier 2 — undocumented, shows warning on failure.
    func setBoldText(_ enabled: Bool, udid: String) {
        boldText = enabled
        runTier2(["spawn", "booted", "defaults", "write",
                  "-g", "AccessibilityBoldText",
                  "-bool", enabled ? "YES" : "NO"],
                 warningKey: "boldText")
    }

    // MARK: - Private

    private func applyContentSize(udid: String) {
        simCtl.runVoid(["ui", udid, "content_size", currentSizeName])
            .sink(receiveCompletion: { _ in }, receiveValue: { _ in })
            .store(in: &cancellables)
    }

    private func runTier2(_ args: [String], warningKey: String) {
        simCtl.runVoid(args)
            .sink(
                receiveCompletion: { [weak self] result in
                    if case .failure = result {
                        self?.tier2Warning = "'\(warningKey)' may require app relaunch or is unsupported"
                    }
                },
                receiveValue: { _ in }
            )
            .store(in: &cancellables)
    }
}
