// ExportState.swift — Export lifecycle state machine + error (CaptureExporter's Models family)
import Foundation

// MARK: - Export State

/// Published export lifecycle: idle → running → completed/failed/cancelled.
enum ExportState: Equatable {
    case idle
    case running(progress: Double)
    case completed(URL)
    case failed(String)
    case cancelled

    var isWorking: Bool {
        switch self {
        case .running: true
        case .idle, .completed, .failed, .cancelled: false
        }
    }
}

// MARK: - Export Error

enum ExportError: Error {
    case cancelled
    case failed(String)

    /// UI-facing message — never carries a file path (redaction rule).
    var userMessage: String {
        switch self {
        case .cancelled: return "Export cancelled — the recording is kept"
        case .failed(let message): return message
        }
    }
}
