# Phase 01 — SimCtlService Foundation

**Priority:** P1 | **Status:** Complete | **Effort:** 1h

**Context:** [Plan](./plan.md) | [Brainstorm](../reports/brainstorm-0321-2230-phase6-platform-system.md)

## Overview

Create `SimCtlService` — the shared `xcrun simctl` command executor used by phases 2, 3, and 4. All simctl-based features route through this single service. This is the critical foundation that must exist before any feature work begins.

## Key Insights

- `xcrun simctl` commands can block for 1–5s — must run on background queue, never main thread
- Swift 6 strict concurrency: use `DispatchQueue.global` + `DispatchQueue.main` callback pattern (Combine Future), not async/await
- `Process` is `@unchecked Sendable` in Swift 6 — confine creation and use to the background queue closure
- `XcodeDetector.swift` already finds `xcrun` path; reuse that knowledge

## Requirements

- Wraps `xcrun simctl` execution via `Process`
- Returns `AnyPublisher<String, SimCtlError>` — fits existing Combine patterns
- Dispatches process execution to `DispatchQueue.global(qos: .userInitiated)`
- Delivers result on `DispatchQueue.main`
- Typed error enum: `SimCtlError` (commandFailed, xcrunNotFound, timeout)
- `@MainActor final class` (owns published state, consistent with other services)
- Cancellable subscriptions stored in `Set<AnyCancellable>`

## Architecture

```swift
// Services/SimCtlService.swift

enum SimCtlError: Error, LocalizedError {
    case commandFailed(String)   // non-zero exit, includes stderr output
    case xcrunNotFound           // /usr/bin/xcrun missing
    case timeout                 // process exceeded time limit
}

@MainActor final class SimCtlService: ObservableObject {
    // MARK: - Properties
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Public Methods
    /// Runs `xcrun simctl <args>` on background queue; delivers on main.
    func run(_ args: [String]) -> AnyPublisher<String, SimCtlError>

    /// Convenience: runs and ignores output (fire-and-forget with error log).
    func runVoid(_ args: [String]) -> AnyPublisher<Void, SimCtlError>
}
```

**Process execution pattern:**
```swift
func run(_ args: [String]) -> AnyPublisher<String, SimCtlError> {
    Future { promise in
        DispatchQueue.global(qos: .userInitiated).async {
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
            proc.arguments = ["simctl"] + args
            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()
            proc.standardOutput = stdoutPipe
            proc.standardError = stderrPipe
            do {
                try proc.run()
            } catch {
                DispatchQueue.main.async { promise(.failure(.xcrunNotFound)) }
                return
            }
            proc.waitUntilExit()
            let stdout = String(data: stdoutPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            DispatchQueue.main.async {
                proc.terminationStatus == 0
                    ? promise(.success(stdout))
                    : promise(.failure(.commandFailed(stdout)))
            }
        }
    }
    .eraseToAnyPublisher()
}
```

## Related Code Files

| File | Action | Description |
|------|--------|-------------|
| `Services/SimCtlService.swift` | Create | Core simctl wrapper |
| `App/AppDelegate.swift` | Modify | Add `let simCtlService = SimCtlService()` property |

## Implementation Steps

1. Create `Services/SimCtlService.swift`
2. Define `SimCtlError` enum with `LocalizedError` conformance
3. Implement `run(_ args:) -> AnyPublisher<String, SimCtlError>` using pattern above
4. Add `runVoid` convenience method (maps String output to Void)
5. Add `@MainActor` and `ObservableObject` conformance
6. Open `App/AppDelegate.swift`, add `let simCtlService = SimCtlService()` property
7. Build and confirm no Swift 6 concurrency warnings

## Todo

- [x] Create `Services/SimCtlService.swift`
- [x] Define `SimCtlError` enum
- [x] Implement `run(_:)` with background dispatch + main deliver
- [x] Implement `runVoid(_:)` convenience
- [x] Add `simCtlService` to `AppDelegate`
- [x] Build — zero concurrency warnings

## Success Criteria

- `xcrun simctl list` runs without blocking UI
- Result delivered on main thread (verified with `Thread.isMainThread`)
- Build succeeds with zero Swift 6 warnings

## Risk Assessment

| Risk | Mitigation |
|------|-----------|
| Swift 6 `Sendable` violation for `Process` | Confine Process creation + launch entirely within the background closure |
| `xcrun` not found on some machines | Check `/usr/bin/xcrun` existence; emit `.xcrunNotFound` error |

## Next Steps

Phase 02 depends on this service being instantiated in AppDelegate.
