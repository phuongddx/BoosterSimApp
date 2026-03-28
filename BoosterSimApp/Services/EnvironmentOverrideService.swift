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
    @Published var smartInvert: Bool = false
    @Published var buttonShapes: Bool = false
    @Published var preferHorizontalText: Bool = false
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
        // Smart Invert requires reading both keys
        simCtl.run(["spawn", udid, "defaults", "read", "com.apple.Accessibility",
                    "AXSSystemUIProcessAppSmartInvertEnabledPreference"])
            .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] output in
                self?.smartInvert = output.trimmingCharacters(in: .whitespacesAndNewlines) == "1"
            })
            .store(in: &cancellables)

        let a11yKeys: [(String, WritableKeyPath<EnvironmentOverrideService, Bool>)] = [
            ("ReduceMotionEnabled",               \.reduceMotion),
            ("BoldTextEnabled",                    \.boldText),
            ("EnhancedBackgroundContrastEnabled", \.reduceTransparency),
            ("GrayscaleDisplay",                  \.grayscale),
            ("IncreaseButtonLegibilityEnabled",   \.buttonShapes),
            ("OnOffSwitchLabels",                 \.onOffLabels),
            ("DifferentiateWithoutColor",         \.differentiateWithoutColor),
            ("PreferHorizontalTextEnabled",       \.preferHorizontalText),
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
        print("[EnvOverride] setAppearance: \(style.rawValue) (udid: \(udid))")
        appearance = style
        simCtl.runVoid(["ui", udid, "appearance", style.rawValue])
            .sink(receiveCompletion: { _ in }, receiveValue: { _ in })
            .store(in: &cancellables)
    }

    func setIncreaseContrast(_ enabled: Bool, udid: String) {
        print("[EnvOverride] setIncreaseContrast: \(enabled) (udid: \(udid))")
        increaseContrast = enabled
        simCtl.runVoid(["ui", udid, "increase_contrast", enabled ? "enabled" : "disabled"])
            .sink(receiveCompletion: { _ in }, receiveValue: { _ in })
            .store(in: &cancellables)
    }

    func incrementContentSize(udid: String) {
        guard contentSizeIndex < Self.contentSizes.count - 1 else { return }
        print("[EnvOverride] incrementContentSize: \(contentSizeIndex + 1) (udid: \(udid))")
        contentSizeIndex += 1
        applyContentSize(udid: udid)
    }

    func decrementContentSize(udid: String) {
        guard contentSizeIndex > 0 else { return }
        print("[EnvOverride] decrementContentSize: \(contentSizeIndex - 1) (udid: \(udid))")
        contentSizeIndex -= 1
        applyContentSize(udid: udid)
    }

    func setContentSizeIndex(_ index: Int, udid: String) {
        guard index >= 0 && index < Self.contentSizes.count else { return }
        print("[EnvOverride] setContentSizeIndex: \(index) (\(Self.contentSizes[index])) (udid: \(udid))")
        contentSizeIndex = index
        applyContentSize(udid: udid)
    }

    func setReduceMotion(_ enabled: Bool, udid: String) {
        print("[EnvOverride] setReduceMotion: \(enabled) (udid: \(udid))")
        reduceMotion = enabled
        setAccessibility(key: "ReduceMotionEnabled",
                         notification: "com.apple.accessibility.reduce-motion",
                         enabled: enabled, udid: udid)
    }

    /// Bold Text requires 3 plist keys across 2 domains + a different notification than other toggles.
    func setBoldText(_ enabled: Bool, udid: String) {
        print("[EnvOverride] setBoldText: \(enabled) (udid: \(udid))")
        boldText = enabled
        let value = enabled ? "YES" : "NO"

        simCtl.runVoid(["spawn", udid, "defaults", "write",
                        "com.apple.Accessibility", "BoldTextEnabled", "-bool", value])
            .flatMap { [weak self] _ -> AnyPublisher<Void, SimCtlError> in
                guard let self else { return Empty().eraseToAnyPublisher() }
                return self.simCtl.runVoid(["spawn", udid, "defaults", "write",
                                           "com.apple.Accessibility",
                                           "EnhancedTextLegibilityEnabled", "-bool", value])
            }
            .flatMap { [weak self] _ -> AnyPublisher<Void, SimCtlError> in
                guard let self else { return Empty().eraseToAnyPublisher() }
                return self.simCtl.runVoid(["spawn", udid, "defaults", "write",
                                           ".GlobalPreferences",
                                           "UIAccessibilityBoldTextEnabled", "-bool", value])
            }
            .flatMap { [weak self] _ -> AnyPublisher<Void, SimCtlError> in
                guard let self else { return Empty().eraseToAnyPublisher() }
                return self.simCtl.runVoid(["spawn", udid, "notifyutil", "-p",
                                           "com.apple.accessibility.AccessibilityUIServer"])
            }
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let e) = completion {
                        print("[EnvOverride] setBoldText error: \(e)")
                    }
                },
                receiveValue: { _ in }
            )
            .store(in: &cancellables)
    }

    func setReduceTransparency(_ enabled: Bool, udid: String) {
        print("[EnvOverride] setReduceTransparency: \(enabled) (udid: \(udid))")
        reduceTransparency = enabled
        setAccessibility(key: "EnhancedBackgroundContrastEnabled",
                         notification: "com.apple.accessibility.reduce-transparency",
                         enabled: enabled, udid: udid)
    }

    func setGrayscale(_ enabled: Bool, udid: String) {
        print("[EnvOverride] setGrayscale: \(enabled) (udid: \(udid))")
        grayscale = enabled
        setAccessibility(key: "GrayscaleDisplay",
                         notification: "com.apple.accessibility.grayscale",
                         enabled: enabled, udid: udid)
    }

    func setSmartInvert(_ enabled: Bool, udid: String) {
        print("[EnvOverride] setSmartInvert: \(enabled) (udid: \(udid))")
        smartInvert = enabled
        // Smart Invert requires both InvertColorsEnabled + AXSSystemUIProcessAppSmartInvertEnabledPreference
        simCtl.runVoid(["spawn", udid, "defaults", "write",
                        "com.apple.Accessibility", "InvertColorsEnabled",
                        "-bool", enabled ? "YES" : "NO"])
            .flatMap { [weak self] _ -> AnyPublisher<Void, SimCtlError> in
                guard let self else { return Empty().eraseToAnyPublisher() }
                return self.simCtl.runVoid(["spawn", udid, "defaults", "write",
                                           "com.apple.Accessibility",
                                           "AXSSystemUIProcessAppSmartInvertEnabledPreference",
                                           "-bool", enabled ? "YES" : "NO"])
            }
            .flatMap { [weak self] _ -> AnyPublisher<Void, SimCtlError> in
                guard let self else { return Empty().eraseToAnyPublisher() }
                return self.simCtl.runVoid(["spawn", udid, "notifyutil", "-p",
                                           "com.apple.accessibility.invert-colors"])
            }
            .sink(receiveCompletion: { _ in }, receiveValue: { _ in })
            .store(in: &cancellables)
    }

    func setButtonShapes(_ enabled: Bool, udid: String) {
        print("[EnvOverride] setButtonShapes: \(enabled) (udid: \(udid))")
        buttonShapes = enabled
        setAccessibility(key: "IncreaseButtonLegibilityEnabled",
                         notification: "com.apple.accessibility.increase-button-legibility",
                         enabled: enabled, udid: udid)
    }

    func setOnOffLabels(_ enabled: Bool, udid: String) {
        print("[EnvOverride] setOnOffLabels: \(enabled) (udid: \(udid))")
        onOffLabels = enabled
        setAccessibility(key: "OnOffSwitchLabels",
                         notification: "com.apple.accessibility.on-off-switch-labels",
                         enabled: enabled, udid: udid)
    }

    func setDifferentiateWithoutColor(_ enabled: Bool, udid: String) {
        print("[EnvOverride] setDifferentiateWithoutColor: \(enabled) (udid: \(udid))")
        differentiateWithoutColor = enabled
        setAccessibility(key: "DifferentiateWithoutColor",
                         notification: "com.apple.accessibility.differentiate-without-color",
                         enabled: enabled, udid: udid)
    }

    func setPreferHorizontalText(_ enabled: Bool, udid: String) {
        print("[EnvOverride] setPreferHorizontalText: \(enabled) (udid: \(udid))")
        preferHorizontalText = enabled
        setAccessibility(key: "PreferHorizontalTextEnabled",
                         notification: "com.apple.accessibility.prefer-horizontal-text",
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
