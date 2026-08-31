// SimCtlServiceTests.swift — Seam stdin-bound contract (03-REVIEW WR-03)
import Foundation
import Combine
import Testing
@testable import BoosterSimApp

/// WR-03: the seam rejects stdin payloads over the pipe bound BEFORE any subprocess runs —
/// an oversized synchronous write ahead of the drains would wedge both pipe sides and pin
/// the machine-wide invocation queue. The typed error carries the offending size.
@MainActor
struct SimCtlServiceTests {

    @Test func runRejectsStdinOverThePipeBoundWithTheTypedException() {
        let service = SimCtlService()
        var failure: SimCtlError?
        var values = 0
        let cancellable = service.run(
            ["push", "CONCRETE-UDID", "com.example.app", "-"],
            stdin: Data(count: SimCtlLimits.maxStdinBytes + 1)
        )
        .sink(
            receiveCompletion: { completion in
                if case .failure(let error) = completion { failure = error }
            },
            receiveValue: { _ in values += 1 }
        )
        guard let failure, case .stdinTooLarge(let size) = failure else {
            Issue.record("expected .stdinTooLarge for a payload over the pipe bound")
            _ = cancellable
            return
        }
        #expect(size == SimCtlLimits.maxStdinBytes + 1)
        #expect(failure.errorDescription?.contains("pipe bound") == true)
        _ = cancellable
    }
}
