// RecordingState.swift — Recording session state machine (idle → recording → finishing → exported)
import Foundation

// MARK: - Recording State

enum RecordingState: Equatable {
    case idle
    case recording
    case finishing
    case exported(URL)
    case error(String)

    var isWorking: Bool {
        switch self {
        case .recording, .finishing: true
        case .idle, .exported, .error: false
        }
    }

    /// Legal transitions only. `stop()` alone never produces `.exported` —
    /// finalization belongs to the recording-output finish callback
    /// (Pitfall 9) — and a stop on idle never enters the machine.
    func canTransition(to next: RecordingState) -> Bool {
        switch self {
        case .idle:
            switch next {
            case .recording: return true
            case .idle, .finishing, .exported, .error: return false
            }
        case .recording:
            switch next {
            case .finishing, .error: return true
            case .recording, .idle, .exported: return false
            }
        case .finishing:
            switch next {
            case .exported, .error: return true
            case .idle, .recording, .finishing: return false
            }
        case .exported:
            switch next {
            case .recording: return true
            case .idle, .finishing, .exported, .error: return false
            }
        case .error:
            switch next {
            case .idle, .recording: return true
            case .finishing, .exported, .error: return false
            }
        }
    }
}
