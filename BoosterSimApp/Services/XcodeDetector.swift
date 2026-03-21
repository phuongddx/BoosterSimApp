// XcodeDetector.swift — Detects Xcode installation path via filesystem checks
// Uses file path detection (sandboxed alternative to running xcode-select process).
import Foundation

enum XcodeDetector {

    // Common installation paths, most likely first
    private static let candidatePaths: [String] = [
        "/Applications/Xcode.app",
        "/Applications/Xcode-beta.app",
        "/Applications/Xcode-Release.app",
        "\(NSHomeDirectory())/Applications/Xcode.app"
    ]

    // MARK: - Public API

    /// Returns the path to the active Xcode .app bundle, or nil if not found.
    static func activeXcodePath() -> String? {
        for path in candidatePaths {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }
        return nil
    }

    /// Returns all Xcode installations found at known paths.
    static func allXcodeInstallations() -> [String] {
        candidatePaths.filter {
            FileManager.default.fileExists(atPath: $0)
        }
    }

    /// Extracts the Developer directory from an Xcode .app path.
    /// e.g. /Applications/Xcode.app → /Applications/Xcode.app/Contents/Developer
    static func developerDirectory(for xcodePath: String) -> String {
        "\(xcodePath)/Contents/Developer"
    }
}
