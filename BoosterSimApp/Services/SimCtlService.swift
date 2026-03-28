// SimCtlService.swift — Shared xcrun simctl process executor
// Used by StatusBarService, EnvironmentOverrideService, and SimulatorWindowTracker.
import Foundation
import Combine

// MARK: - Error

enum SimCtlError: Error, LocalizedError {
    case commandFailed(String)
    case xcrunNotFound
    case timeout

    var errorDescription: String? {
        switch self {
        case .commandFailed(let msg): return "simctl failed: \(msg)"
        case .xcrunNotFound:         return "xcrun not found at /usr/bin/xcrun"
        case .timeout:               return "simctl command timed out"
        }
    }
}

// MARK: - Service

@MainActor
final class SimCtlService: ObservableObject {

    // MARK: - Properties

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Public Methods

    /// Runs `xcrun simctl <args>` on background queue; delivers result on main.
    func run(_ args: [String]) -> AnyPublisher<String, SimCtlError> {
        print("[SimCtl] xcrun simctl \(args.joined(separator: " "))")
        return Future { promise in
            DispatchQueue.global(qos: .userInitiated).async {
                guard FileManager.default.fileExists(atPath: "/usr/bin/xcrun") else {
                    DispatchQueue.main.async { promise(.failure(.xcrunNotFound)) }
                    return
                }
                let proc = Process()
                proc.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
                proc.arguments = ["simctl"] + args
                let stdoutPipe = Pipe()
                let stderrPipe = Pipe()
                proc.standardOutput = stdoutPipe
                proc.standardError  = stderrPipe
                do { try proc.run() } catch {
                    DispatchQueue.main.async { promise(.failure(.xcrunNotFound)) }
                    return
                }
                proc.waitUntilExit()
                let stdout = String(
                    data: stdoutPipe.fileHandleForReading.readDataToEndOfFile(),
                    encoding: .utf8
                ) ?? ""
                let stderr = String(
                    data: stderrPipe.fileHandleForReading.readDataToEndOfFile(),
                    encoding: .utf8
                ) ?? ""
                DispatchQueue.main.async {
                    if proc.terminationStatus == 0 {
                        promise(.success(stdout))
                    } else {
                        promise(.failure(.commandFailed(stderr.isEmpty ? stdout : stderr)))
                    }
                }
            }
        }
        .eraseToAnyPublisher()
    }

    /// Convenience: runs and maps output to Void (fire-and-forget style).
    func runVoid(_ args: [String]) -> AnyPublisher<Void, SimCtlError> {
        run(args).map { _ in () }.eraseToAnyPublisher()
    }
}
