---
phase: 03
title: macOS HealthDataService
status: completed
effort: 2h
---

# Phase 03 — macOS HealthDataService

## Overview

New macOS service that installs `BoosterHealth.app` onto the Simulator and triggers generation via URL scheme. Wraps `SimCtlService`. Follows the same `@MainActor ObservableObject` pattern as existing services.

## File to Create

`BoosterSimApp/Services/HealthDataService.swift`

---

## Implementation

```swift
// HealthDataService.swift — Install + trigger BoosterHealth companion for HealthKit data generation
import Foundation
import Combine

// MARK: - Models

enum HealthPreset: String, CaseIterable {
    case activeDay   = "active_day"
    case restDay     = "rest_day"
    case sickDay     = "sick_day"
    case weekHistory = "week_history"

    var label: String {
        switch self {
        case .activeDay:   return "Active Day"
        case .restDay:     return "Rest Day"
        case .sickDay:     return "Sick Day"
        case .weekHistory: return "7-Day History"
        }
    }

    var icon: String {
        switch self {
        case .activeDay:   return "figure.run"
        case .restDay:     return "bed.double"
        case .sickDay:     return "cross.case"
        case .weekHistory: return "calendar.badge.clock"
        }
    }
}

enum HealthDataState: Equatable {
    case idle
    case installing
    case generating
    case done
    case error(String)
}

// MARK: - Service

@MainActor
final class HealthDataService: ObservableObject {

    @Published private(set) var state: HealthDataState = .idle

    private let simCtl: SimCtlService
    private var cancellables = Set<AnyCancellable>()

    /// Path to bundled BoosterHealth.app inside this app's Resources
    private var companionPath: String? {
        Bundle.main.path(forResource: "BoosterHealth", ofType: "app")
    }

    init(simCtl: SimCtlService) {
        self.simCtl = simCtl
    }

    // MARK: - Public

    func generatePreset(_ preset: HealthPreset, udid: String) {
        let dateStr = ISO8601DateFormatter().string(from: Date()).prefix(10).description
        let days    = preset == .weekHistory ? 7 : 1
        let urlStr  = "boosterhealth://generate?preset=\(preset.rawValue)&date=\(dateStr)&days=\(days)"
        trigger(udid: udid, urlStr: urlStr)
    }

    func generateManual(type: String, value: Double, udid: String) {
        let dateStr = ISO8601DateFormatter().string(from: Date()).prefix(10).description
        let urlStr  = "boosterhealth://generate?type=\(type)&value=\(value)&date=\(dateStr)&days=1"
        trigger(udid: udid, urlStr: urlStr)
    }

    // <!-- Updated: Validation Session 1 - Add clearAllData -->
    func clearAllData(udid: String) {
        let urlStr = "boosterhealth://clear"
        trigger(udid: udid, urlStr: urlStr)
    }

    func resetState() {
        state = .idle
    }

    // MARK: - Private

    private func trigger(udid: String, urlStr: String) {
        guard let companionPath else {
            state = .error("BoosterHealth.app not found in bundle")
            return
        }
        state = .installing

        simCtl.run(["install", udid, companionPath])
            .flatMap { [weak self] _ -> AnyPublisher<String, SimCtlError> in
                guard let self else {
                    return Fail(error: SimCtlError.commandFailed("deallocated")).eraseToAnyPublisher()
                }
                self.state = .generating
                return self.simCtl.run(["openurl", udid, urlStr])
            }
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let err) = completion {
                        self?.state = .error(err.localizedDescription)
                    }
                },
                receiveValue: { [weak self] _ in
                    self?.state = .done
                    // Auto-reset after 3s so button becomes available again
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        if self?.state == .done { self?.state = .idle }
                    }
                }
            )
            .store(in: &cancellables)
    }
}
```

## Notes

- `simctl install` is idempotent — safe to call every time (re-installs if companion updated)
- `simctl openurl` triggers the companion; HealthKit write happens async inside Simulator
- No feedback from companion back to macOS → `done` state is set immediately after `openurl` succeeds (not after HealthKit write completes)
- `companionPath` uses `Bundle.main.path(forResource:ofType:)` — works because of the Copy Files build phase in Phase 01

## Success Criteria

- [ ] `HealthDataService` compiles with no Swift 6 concurrency warnings
- [ ] `state` transitions: `idle → installing → generating → done` on success
- [ ] `state` transitions to `.error(msg)` when simctl fails (e.g., no booted Simulator)
- [ ] `companionPath` resolves correctly in both Debug and Release builds
