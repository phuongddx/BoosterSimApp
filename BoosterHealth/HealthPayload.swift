// HealthPayload.swift — URL payload model for boosterhealth:// URL scheme
import Foundation

enum HealthPreset: String, CaseIterable {
    case activeDay   = "active_day"
    case restDay     = "rest_day"
    case sickDay     = "sick_day"
    case weekHistory = "week_history"
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
        let params: [String: String] = Dictionary(
            uniqueKeysWithValues: (components.queryItems ?? []).compactMap { item in
                guard let value = item.value else { return nil }
                return (item.name, value)
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
