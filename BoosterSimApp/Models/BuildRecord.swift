// BuildRecord.swift — Value type representing a single Xcode build from LogStoreManifest.plist
import Foundation

struct BuildRecord: Identifiable, Sendable {
    let id: String           // plist log UUID key
    let schemeName: String
    let startDate: Date
    let duration: TimeInterval   // seconds
    let succeeded: Bool
    let errorCount: Int
    let warningCount: Int

    // MARK: - Computed

    var formattedDuration: String {
        if duration < 60 {
            return String(format: "%.1fs", duration)
        }
        let mins = Int(duration / 60)
        let secs = Int(duration.truncatingRemainder(dividingBy: 60))
        return "\(mins)m \(secs)s"
    }

    var formattedDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: startDate, relativeTo: Date())
    }
}
