// SimCtlService.swift — Shared xcrun simctl process executor
// Used by StatusBarService, EnvironmentOverrideService, CertificateService, and AppActionService.
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

// MARK: - Pipe Drain

/// Lock-protected accumulator so both pipes can drain concurrently with process exit.
private final class PipeBuffer {
    private let lock = NSLock()
    private var data = Data()

    func append(_ chunk: Data) {
        lock.lock(); data.append(chunk); lock.unlock()
    }

    func contents() -> Data {
        lock.lock(); defer { lock.unlock() }
        return data
    }
}

// MARK: - Service

@MainActor
final class SimCtlService: ObservableObject {

    // MARK: - Properties

    private var cancellables = Set<AnyCancellable>()

    /// Serializes invocations machine-wide: one simctl pipeline at a time (queued, never interleaved).
    private static let invocationQueue = DispatchQueue(
        label: "com.nextlabs.BoosterSimApp.simctl", qos: .userInitiated
    )

    // MARK: - Public Methods

    /// Runs `xcrun simctl <args>`; delivers the result on main.
    /// Both pipes drain concurrently with process exit — outputs past the 64 KB pipe buffer would
    /// otherwise deadlock the child against `waitUntilExit` (listapps is already ~33 KB) — and every
    /// invocation queues on one serial queue. When `stdin` is present it is written to the child's
    /// standard input and closed afterward (serves `push <udid> -`).
    func run(_ args: [String], stdin: Data? = nil) -> AnyPublisher<String, SimCtlError> {
        print("[SimCtl] xcrun simctl \(args.joined(separator: " "))")
        return Future { promise in
            SimCtlService.invocationQueue.async {
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
                var stdinPipe: Pipe?
                if let stdin {
                    let pipe = Pipe()
                    proc.standardInput = pipe
                    stdinPipe = pipe
                }
                do { try proc.run() } catch {
                    DispatchQueue.main.async { promise(.failure(.xcrunNotFound)) }
                    return
                }
                if let stdin, let stdinPipe {
                    try? stdinPipe.fileHandleForWriting.write(contentsOf: stdin)
                    try? stdinPipe.fileHandleForWriting.close()
                }
                Self.drainAndComplete(proc, stdoutPipe: stdoutPipe, stderrPipe: stderrPipe, promise: promise)
            }
        }
        .eraseToAnyPublisher()
    }

    /// Convenience: runs and maps output to Void (fire-and-forget style).
    func runVoid(_ args: [String]) -> AnyPublisher<Void, SimCtlError> {
        run(args).map { _ in () }.eraseToAnyPublisher()
    }

    // MARK: - Private

    /// Reads both pipes concurrently with the child, then resolves the promise only after
    /// exit status AND both EOFs have landed (concurrent-pipe-reads deadlock fix).
    private static func drainAndComplete(
        _ proc: Process, stdoutPipe: Pipe, stderrPipe: Pipe,
        promise: @escaping (Result<String, SimCtlError>) -> Void
    ) {
        let stdoutBuffer = PipeBuffer()
        let stderrBuffer = PipeBuffer()
        let drainGroup = DispatchGroup()
        for (pipe, buffer) in [(stdoutPipe, stdoutBuffer), (stderrPipe, stderrBuffer)] {
            drainGroup.enter()
            DispatchQueue.global(qos: .userInitiated).async {
                buffer.append(pipe.fileHandleForReading.readDataToEndOfFile())
                drainGroup.leave()
            }
        }
        proc.waitUntilExit()
        drainGroup.wait()
        let stdout = String(data: stdoutBuffer.contents(), encoding: .utf8) ?? ""
        let stderr = String(data: stderrBuffer.contents(), encoding: .utf8) ?? ""
        DispatchQueue.main.async {
            if proc.terminationStatus == 0 {
                promise(.success(stdout))
            } else {
                promise(.failure(.commandFailed(stderr.isEmpty ? stdout : stderr)))
            }
        }
    }
}
