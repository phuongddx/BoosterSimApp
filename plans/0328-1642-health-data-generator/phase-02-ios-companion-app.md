---
phase: 02
title: iOS Companion App (BoosterHealth)
status: completed
effort: 4h
---

# Phase 02 — iOS Companion App

## Overview

Build the `BoosterHealth` iOS app. No visible UI — app responds to `boosterhealth://` URL, generates HealthKit samples, and exits silently. Four files total.

## Files to Create

```
BoosterHealth/
├── BoosterHealthApp.swift      ← @main, handles onOpenURL
├── URLHandler.swift            ← parses URL → HealthPayload
├── HealthPayload.swift         ← Codable model for URL params
└── HealthDataGenerator.swift   ← HKHealthStore writes
```

---

## HealthPayload.swift

URL format:
```
boosterhealth://generate?preset=active_day&date=2026-03-28
boosterhealth://generate?type=steps&value=10000&date=2026-03-28&days=1
```

```swift
// HealthPayload.swift
import Foundation

enum HealthPreset: String, CaseIterable {
    case activeDay    = "active_day"
    case restDay      = "rest_day"
    case sickDay      = "sick_day"
    case weekHistory  = "week_history"
}

struct HealthPayload {
    // Preset mode
    var preset: HealthPreset?
    // Manual mode
    var type: String?
    var value: Double?
    // Shared
    var date: Date
    var days: Int

    static func parse(from url: URL) -> HealthPayload? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.host == "generate" else { return nil }
        let params = Dictionary(
            uniqueKeysWithValues: (components.queryItems ?? []).compactMap {
                $0.value.map { ($0.name, $0) }
            }
        )
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        let date = params["date"].flatMap { formatter.date(from: $0) } ?? Date()
        let days = params["days"].flatMap { Int($0) } ?? 1

        if let presetStr = params["preset"], let preset = HealthPreset(rawValue: presetStr) {
            return HealthPayload(preset: preset, date: date, days: days)
        }
        if let typeStr = params["type"], let valueStr = params["value"], let value = Double(valueStr) {
            return HealthPayload(type: typeStr, value: value, date: date, days: days)
        }
        return nil
    }

    private init(preset: HealthPreset? = nil, type: String? = nil,
                 value: Double? = nil, date: Date, days: Int) {
        self.preset = preset; self.type = type
        self.value = value; self.date = date; self.days = days
    }
}
```

---

## HealthDataGenerator.swift

```swift
// HealthDataGenerator.swift
import HealthKit
import Foundation

@MainActor
final class HealthDataGenerator {

    private let store = HKHealthStore()

    // All types this app writes
    private var writeTypes: Set<HKSampleType> {
        let ids: [HKQuantityTypeIdentifier] = [
            .stepCount, .heartRate, .restingHeartRate,
            .heartRateVariabilitySDNN, .oxygenSaturation,
            .activeEnergyBurned, .distanceWalkingRunning
        ]
        var types = Set(ids.map { HKQuantityType($0) as HKSampleType })
        types.insert(HKObjectType.workoutType())
        types.insert(HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!)
        return types
    }

    // MARK: - Authorization

    func requestAuthorization() async -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else { return false }
        do {
            try await store.requestAuthorization(toShare: writeTypes, read: writeTypes)
            return true
        } catch { return false }
    }

    // MARK: - Clear All

    func clearAll() async {
        for sampleType in writeTypes {
            let predicate = HKQuery.predicateForObjects(from: HKSource.default())
            do {
                let samples = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<[HKSample], Error>) in
                    let query = HKSampleQuery(sampleType: sampleType, predicate: predicate,
                                              limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, results, error in
                        if let error { cont.resume(throwing: error) }
                        else { cont.resume(returning: results ?? []) }
                    }
                    store.execute(query)
                }
                if !samples.isEmpty {
                    try await store.delete(samples)
                }
            } catch { continue }
        }
    }

    // MARK: - Generate

    func generate(payload: HealthPayload) async {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        do {
            try await store.requestAuthorization(toShare: writeTypes, read: writeTypes)
            if let preset = payload.preset {
                try await generatePreset(preset, date: payload.date, days: payload.days)
            } else if let type = payload.type, let value = payload.value {
                try await generateManual(type: type, value: value, date: payload.date, days: payload.days)
            }
        } catch {
            // Silent failure — no UI to show errors
        }
    }

    // MARK: - Preset Generation

    private func generatePreset(_ preset: HealthPreset, date: Date, days: Int) async throws {
        let calendar = Calendar.current
        for dayOffset in 0..<days {
            guard let day = calendar.date(byAdding: .day, value: -dayOffset, to: date) else { continue }
            switch preset {
            case .activeDay:
                try await saveSteps(10_000, date: day)
                try await saveHeartRateSeries(min: 62, max: 145, count: 48, date: day)
                try await saveSleep(bedHour: 23, wakeHour: 7, date: day)
                try await saveWorkout(type: .running, duration: 1800, calories: 320, distance: 5000, date: day)
            case .restDay:
                try await saveSteps(2_500, date: day)
                try await saveHeartRateSeries(min: 58, max: 85, count: 24, date: day)
                try await saveSleep(bedHour: 22, wakeHour: 8, date: day)
            case .sickDay:
                try await saveSteps(800, date: day)
                try await saveHeartRateSeries(min: 72, max: 110, count: 24, date: day)
                try await saveSleep(bedHour: 20, wakeHour: 10, date: day)
            case .weekHistory:
                // Alternating active/rest for variety
                if dayOffset % 3 == 0 {
                    try await generatePreset(.activeDay, date: day, days: 1)
                } else {
                    try await generatePreset(.restDay, date: day, days: 1)
                }
            }
        }
    }

    // MARK: - Manual Generation

    private func generateManual(type: String, value: Double, date: Date, days: Int) async throws {
        let calendar = Calendar.current
        for dayOffset in 0..<days {
            guard let day = calendar.date(byAdding: .day, value: -dayOffset, to: date) else { continue }
            switch type {
            case "steps":       try await saveSteps(value, date: day)
            case "heartRate":   try await saveHeartRateSeries(min: value * 0.8, max: value * 1.2, count: 24, date: day)
            case "sleep":       try await saveSleep(bedHour: 23, wakeHour: Int(value), date: day)
            case "workout":     try await saveWorkout(type: .running, duration: value * 60, calories: value * 8, distance: value * 100, date: day)
            default: break
            }
        }
    }

    // MARK: - Sample Writers

    private func saveSteps(_ count: Double, date: Date) async throws {
        let type = HKQuantityType(.stepCount)
        let qty  = HKQuantity(unit: .count(), doubleValue: count)
        let sample = HKQuantitySample(type: type, quantity: qty,
                                      start: dayStart(date), end: dayEnd(date))
        try await store.save(sample)
    }

    private func saveHeartRateSeries(min: Double, max: Double, count: Int, date: Date) async throws {
        let type = HKQuantityType(.heartRate)
        let unit = HKUnit.count().unitDivided(by: .minute())
        let interval = 86400.0 / Double(count)
        var samples: [HKQuantitySample] = []
        for i in 0..<count {
            let t = dayStart(date).addingTimeInterval(Double(i) * interval)
            let bpm = Double.random(in: min...max)
            samples.append(HKQuantitySample(type: type,
                                            quantity: HKQuantity(unit: unit, doubleValue: bpm),
                                            start: t, end: t.addingTimeInterval(60)))
        }
        try await store.save(samples)
    }

    private func saveSleep(bedHour: Int, wakeHour: Int, date: Date) async throws {
        let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        let cal  = Calendar.current
        let bed  = cal.date(bySettingHour: bedHour, minute: 0, second: 0, of: date)!
        let wake = cal.date(byAdding: .hour, value: wakeHour < bedHour ? (24 - bedHour + wakeHour) : (wakeHour - bedHour), to: bed)!
        let sample = HKCategorySample(type: type,
                                       value: HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
                                       start: bed, end: wake)
        try await store.save(sample)
    }

    private func saveWorkout(type workoutType: HKWorkoutActivityType,
                             duration: Double, calories: Double, distance: Double, date: Date) async throws {
        let start = dayStart(date).addingTimeInterval(7 * 3600)  // 7am
        let end   = start.addingTimeInterval(duration)
        let workout = HKWorkout(activityType: workoutType, start: start, end: end,
                                duration: duration,
                                totalEnergyBurned: HKQuantity(unit: .kilocalorie(), doubleValue: calories),
                                totalDistance: HKQuantity(unit: .meter(), doubleValue: distance),
                                metadata: nil)
        try await store.save(workout)
    }

    // MARK: - Helpers

    private func dayStart(_ date: Date) -> Date {
        Calendar.current.startOfDay(for: date)
    }
    private func dayEnd(_ date: Date) -> Date {
        dayStart(date).addingTimeInterval(86399)
    }
}
```

---

<!-- Updated: Validation Session 1 - Minimal auth UI on first launch + clear handler -->

## BoosterHealthApp.swift

```swift
// BoosterHealthApp.swift
import SwiftUI
import HealthKit

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

// MARK: - Minimal Auth View (shown until permissions granted)

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
```

---

## Success Criteria

- [ ] App builds for `iphonesimulator` only (no device slice errors)
- [ ] URL scheme `boosterhealth://` registered in Info.plist
- [ ] HealthKit entitlement present
- [ ] Launching with `boosterhealth://generate?preset=active_day&date=2026-03-28` in Simulator → Health app shows data
- [ ] First launch shows HealthKit permissions sheet in Simulator
- [ ] Subsequent launches (permissions granted) → data saved silently

## Risks

- `HKHealthStore.requestAuthorization` must be called from a view-presenting context; in a headless app this may require a visible window. If it fails, add a minimal SwiftUI view that shows the auth prompt.
- `store.save(_ samples:)` is async in Swift 6 concurrency — use `try await` (already done above).
