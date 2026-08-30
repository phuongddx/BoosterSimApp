// CaptureFilename.swift — Sanitized capture filename construction (pure utility)
import Foundation

// MARK: - Filename Builder

enum CaptureFilename {

    // MARK: - Public API

    /// Sanitized timestamp-unique filename:
    /// "BoosterSim-" + device + "-" + preset + "-" + stamp + ".png".
    /// Allowlist is alphanumeric + hyphen; every other character collapses to a
    /// single hyphen (threat T-02-05 — device strings must never reach the path raw).
    /// - Parameters:
    ///   - device: Simulator-provided device name (untrusted string)
    ///   - preset: Selected ASC frame preset (its raw value rides the name)
    ///   - date: Capture timestamp — a second capture never touches the first
    static func captureFilename(device: String?, preset: ASCFramePreset, date: Date) -> String {
        let stamp = stampFormatter.string(from: date)
        return "BoosterSim-\(sanitized(device))-\(preset.rawValue)-\(stamp).png"
    }

    // MARK: - Private

    private static let stampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    private static func sanitized(_ device: String?) -> String {
        var result = ""
        var lastWasSeparator = false
        for character in (device ?? "Simulator").lowercased() {
            let isAllowed = (character.isLetter || character.isNumber) && character.isASCII
            if isAllowed {
                result.append(character)
                lastWasSeparator = false
            } else if !lastWasSeparator {
                result.append("-")
                lastWasSeparator = true
            }
        }
        let trimmed = result.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return trimmed.isEmpty ? "simulator" : trimmed
    }
}
