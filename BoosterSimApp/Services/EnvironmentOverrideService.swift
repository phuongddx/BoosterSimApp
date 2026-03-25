// EnvironmentOverrideService.swift — Appearance and accessibility overrides via xcrun simctl
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
    @Published var contentSizeIndex: Int = 3  // default = "large" (index 3)

    // Accessibility toggles — com.apple.Accessibility domain
    @Published var reduceMotion: Bool = false
    @Published var boldText: Bool = false
    @Published var reduceTransparency: Bool = false
    @Published var grayscale: Bool = false
    @Published var invertColors: Bool = false
    @Published var buttonShapes: Bool = false
    @Published var onOffLabels: Bool = false
    @Published var differentiateWithoutColor: Bool = false

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
        // Tier 1 — official simctl ui commands
        simCtl.run(["ui", udid, "appearance"])
            .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] output in
                let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                self?.appearance = trimmed == "dark" ? .dark : .light
            })
            .store(in: &cancellables)

        simCtl.run(["ui", udid, "increase_contrast"])
            .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] output in
                self?.increaseContrast = output.trimmingCharacters(in: .whitespacesAndNewlines) == "enabled"
            })
            .store(in: &cancellables)

        simCtl.run(["ui", udid, "content_size"])
            .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] output in
                let name = output.trimmingCharacters(in: .whitespacesAndNewlines)
                if let idx = Self.contentSizes.firstIndex(of: name) {
                    self?.contentSizeIndex = idx
                }
            })
            .store(in: &cancellables)

        // Tier 2 — com.apple.Accessibility plist (instant via notifyutil)
        let a11yKeys: [(String, WritableKeyPath<EnvironmentOverrideService, Bool>)] = [
            ("ReduceMotionEnabled",               \.reduceMotion),
            ("EnhancedTextLegibilityEnabled",     \.boldText),
            ("EnhancedBackgroundContrastEnabled", \.reduceTransparency),
            ("GrayscaleDisplay",                  \.grayscale),
            ("InvertColorsEnabled",               \.invertColors),
            ("IncreaseButtonLegibilityEnabled",   \.buttonShapes),
            ("OnOffSwitchLabels",                 \.onOffLabels),
            ("DifferentiateWithoutColor",         \.differentiateWithoutColor),
        ]
        for (key, path) in a11yKeys {
            simCtl.run(["spawn", udid, "defaults", "read", "com.apple.Accessibility", key])
                .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] output in
                    self?[keyPath: path] = output.trimmingCharacters(in: .whitespacesAndNewlines) == "1"
                })
                .store(in: &cancellables)
        }
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

    func setReduceMotion(_ enabled: Bool, udid: String) {
        reduceMotion = enabled
        setAccessibility(key: "ReduceMotionEnabled",
                         notification: "com.apple.accessibility.reduce-motion",
                         enabled: enabled, udid: udid)
    }

    func setBoldText(_ enabled: Bool, udid: String) {
        boldText = enabled
        setAccessibility(key: "EnhancedTextLegibilityEnabled",
                         notification: "com.apple.accessibility.enhanced-text-legibility",
                         enabled: enabled, udid: udid)
    }

    func setReduceTransparency(_ enabled: Bool, udid: String) {
        reduceTransparency = enabled
        setAccessibility(key: "EnhancedBackgroundContrastEnabled",
                         notification: "com.apple.accessibility.reduce-transparency",
                         enabled: enabled, udid: udid)
    }

    func setGrayscale(_ enabled: Bool, udid: String) {
        grayscale = enabled
        setAccessibility(key: "GrayscaleDisplay",
                         notification: "com.apple.accessibility.grayscale",
                         enabled: enabled, udid: udid)
    }

    func setInvertColors(_ enabled: Bool, udid: String) {
        invertColors = enabled
        setAccessibility(key: "InvertColorsEnabled",
                         notification: "com.apple.accessibility.invert-colors",
                         enabled: enabled, udid: udid)
    }

    func setButtonShapes(_ enabled: Bool, udid: String) {
        buttonShapes = enabled
        setAccessibility(key: "IncreaseButtonLegibilityEnabled",
                         notification: "com.apple.accessibility.increase-button-legibility",
                         enabled: enabled, udid: udid)
    }

    func setOnOffLabels(_ enabled: Bool, udid: String) {
        onOffLabels = enabled
        setAccessibility(key: "OnOffSwitchLabels",
                         notification: "com.apple.accessibility.on-off-switch-labels",
                         enabled: enabled, udid: udid)
    }

    func setDifferentiateWithoutColor(_ enabled: Bool, udid: String) {
        differentiateWithoutColor = enabled
        setAccessibility(key: "DifferentiateWithoutColor",
                         notification: "com.apple.accessibility.differentiate-without-color",
                         enabled: enabled, udid: udid)
    }

    // MARK: - Private

    private func applyContentSize(udid: String) {
        simCtl.runVoid(["ui", udid, "content_size", currentSizeName])
            .sink(receiveCompletion: { _ in }, receiveValue: { _ in })
            .store(in: &cancellables)
    }

    /// Writes a boolean to com.apple.Accessibility then posts the Darwin notification for instant apply.
    private func setAccessibility(key: String, notification: String, enabled: Bool, udid: String) {
        simCtl.runVoid(["spawn", udid, "defaults", "write",
                        "com.apple.Accessibility", key, "-bool", enabled ? "YES" : "NO"])
            .flatMap { [weak self] _ -> AnyPublisher<Void, SimCtlError> in
                guard let self else { return Empty().eraseToAnyPublisher() }
                return self.simCtl.runVoid(["spawn", udid, "notifyutil", "-p", notification])
            }
            .sink(receiveCompletion: { _ in }, receiveValue: { _ in })
            .store(in: &cancellables)
    }
}
