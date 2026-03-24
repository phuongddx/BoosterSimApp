// StatusBarService.swift — Status bar configuration via xcrun simctl status_bar
import Foundation
import Combine

// MARK: - Models

enum StatusBarPreset: String, CaseIterable, Identifiable {
    case screenshotReady = "Screenshot"
    case lowBattery      = "Low Battery"
    case noSignal        = "No Signal"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .screenshotReady: return "camera"
        case .lowBattery:      return "battery.25"
        case .noSignal:        return "antenna.radiowaves.left.and.right.slash"
        }
    }

    var config: StatusBarConfig {
        switch self {
        case .screenshotReady:
            return StatusBarConfig(time: "9:41", batteryLevel: 100, batteryState: "charged",
                                   wifiBars: 3, wifiMode: "active",
                                   cellularBars: 4, cellularMode: "active",
                                   dataNetwork: "wifi", operatorName: "")
        case .lowBattery:
            var c = StatusBarConfig(); c.batteryLevel = 9; c.batteryState = "discharging"; return c
        case .noSignal:
            var c = StatusBarConfig()
            c.cellularMode = "searching"; c.cellularBars = 0
            c.wifiMode = "failed"; c.wifiBars = 0
            return c
        }
    }
}

struct StatusBarConfig: Codable, Equatable {
    var time: String        = "9:41"
    var batteryLevel: Int   = 100
    var batteryState: String = "charged"  // charging | charged | discharging
    var wifiBars: Int       = 3
    var wifiMode: String    = "active"    // searching | failed | active
    var cellularBars: Int   = 4
    var cellularMode: String = "active"
    var dataNetwork: String  = "wifi"     // wifi | 5g | lte | 4g | 3g | hide
    var operatorName: String = ""
}

// MARK: - Service

@MainActor
final class StatusBarService: ObservableObject {

    @Published var isApplying = false
    @Published var lastError: String?

    private let simCtl: SimCtlService
    private var cancellables = Set<AnyCancellable>()

    init(simCtl: SimCtlService) { self.simCtl = simCtl }

    // MARK: - Public Methods

    func applyPreset(_ preset: StatusBarPreset, to udid: String) {
        applyCustom(preset.config, to: udid)
    }

    func applyCustom(_ config: StatusBarConfig, to udid: String) {
        isApplying = true
        lastError  = nil
        simCtl.runVoid(["status_bar", udid, "override"] + buildArgs(from: config))
            .sink(
                receiveCompletion: { [weak self] result in
                    self?.isApplying = false
                    if case .failure(let err) = result {
                        self?.lastError = err.localizedDescription
                    }
                },
                receiveValue: { _ in }
            )
            .store(in: &cancellables)
    }

    func clearOverrides(for udid: String) {
        simCtl.runVoid(["status_bar", udid, "clear"])
            .sink(receiveCompletion: { _ in }, receiveValue: { _ in })
            .store(in: &cancellables)
    }

    // MARK: - Private

    private func buildArgs(from config: StatusBarConfig) -> [String] {
        var args: [String] = []
        args += ["--time", config.time]
        args += ["--batteryLevel", "\(config.batteryLevel)"]
        args += ["--batteryState", config.batteryState]
        args += ["--wifiBars", "\(config.wifiBars)"]
        args += ["--wifiMode", config.wifiMode]
        args += ["--cellularBars", "\(config.cellularBars)"]
        args += ["--cellularMode", config.cellularMode]
        args += ["--dataNetwork", config.dataNetwork]
        if !config.operatorName.isEmpty {
            args += ["--operatorName", config.operatorName]
        }
        return args
    }
}
