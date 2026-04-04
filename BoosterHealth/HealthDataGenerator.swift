// HealthDataGenerator.swift — HKHealthStore sample writer for test data generation
import HealthKit
import Foundation

@MainActor
final class HealthDataGenerator {

    private let store = HKHealthStore()

    // All HK types this app writes
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
                    self.store.execute(query)
                }
                if !samples.isEmpty {
                    try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
                        self.store.delete(samples as [HKObject]) { _, error in
                            if let error { cont.resume(throwing: error) }
                            else { cont.resume() }
                        }
                    }
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
                try await saveWorkout(duration: 1800, calories: 320, distance: 5000, date: day)
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
            case "steps":     try await saveSteps(value, date: day)
            case "heartRate": try await saveHeartRateSeries(min: value * 0.8, max: value * 1.2, count: 24, date: day)
            case "sleep":     try await saveSleep(bedHour: 23, wakeHour: Int(value), date: day)
            case "workout":   try await saveWorkout(duration: value * 60, calories: value * 8, distance: value * 100, date: day)
            default: break
            }
        }
    }

    // MARK: - Sample Writers

    private func saveSteps(_ count: Double, date: Date) async throws {
        let type   = HKQuantityType(.stepCount)
        let qty    = HKQuantity(unit: .count(), doubleValue: count)
        let sample = HKQuantitySample(type: type, quantity: qty,
                                      start: dayStart(date), end: dayEnd(date))
        try await store.save(sample)
    }

    private func saveHeartRateSeries(min: Double, max: Double, count: Int, date: Date) async throws {
        let type     = HKQuantityType(.heartRate)
        let unit     = HKUnit.count().unitDivided(by: .minute())
        let interval = 86400.0 / Double(count)
        var samples: [HKQuantitySample] = []
        for i in 0..<count {
            let t   = dayStart(date).addingTimeInterval(Double(i) * interval)
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
        let hoursOfSleep = wakeHour < bedHour ? (24 - bedHour + wakeHour) : (wakeHour - bedHour)
        let wake = cal.date(byAdding: .hour, value: hoursOfSleep, to: bed)!
        let sample = HKCategorySample(type: type,
                                       value: HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
                                       start: bed, end: wake)
        try await store.save(sample)
    }

    private func saveWorkout(duration: Double, calories: Double, distance: Double, date: Date) async throws {
        let start = dayStart(date).addingTimeInterval(7 * 3600)  // 7am
        let end   = start.addingTimeInterval(duration)

        let config = HKWorkoutConfiguration()
        config.activityType = .running

        let builder = HKWorkoutBuilder(healthStore: store, configuration: config, device: nil)
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            builder.beginCollection(withStart: start) { _, error in
                if let error { cont.resume(throwing: error) }
                else { cont.resume() }
            }
        }
        let energySample = HKQuantitySample(
            type: HKQuantityType(.activeEnergyBurned),
            quantity: HKQuantity(unit: .kilocalorie(), doubleValue: calories),
            start: start, end: end)
        let distSample = HKQuantitySample(
            type: HKQuantityType(.distanceWalkingRunning),
            quantity: HKQuantity(unit: .meter(), doubleValue: distance),
            start: start, end: end)
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            builder.add([energySample, distSample]) { _, error in
                if let error { cont.resume(throwing: error) }
                else { cont.resume() }
            }
        }
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            builder.endCollection(withEnd: end) { _, error in
                if let error { cont.resume(throwing: error) }
                else { cont.resume() }
            }
        }
        _ = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<HKWorkout?, Error>) in
            builder.finishWorkout { workout, error in
                if let error { cont.resume(throwing: error) }
                else { cont.resume(returning: workout) }
            }
        }
    }

    // MARK: - Helpers

    private func dayStart(_ date: Date) -> Date { Calendar.current.startOfDay(for: date) }
    private func dayEnd(_ date: Date) -> Date { dayStart(date).addingTimeInterval(86399) }
}
