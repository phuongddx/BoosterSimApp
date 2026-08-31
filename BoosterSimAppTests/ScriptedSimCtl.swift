// ScriptedSimCtl.swift — Scripted SimCtlRunning double: canned per-verb outcomes, no subprocesses
import Foundation
import Combine
import Testing
@testable import BoosterSimApp

/// Scripted seam double — the `SimCtlRunning` protocol exists so facade chains can be driven
/// in tests exactly as production runs them, without spawning `xcrun`. Each verb (the first
/// argv token) maps to a canned outcome delivered synchronously.
@MainActor
final class ScriptedSimCtlDouble: SimCtlRunning {

    private(set) var requested: [[String]] = []
    private var outcomes: [String: Result<String, SimCtlError>] = [:]

    /// Cans an immediate outcome for every run whose first arg (the verb) matches.
    func when(_ verb: String, returns outcome: Result<String, SimCtlError>) {
        outcomes[verb] = outcome
    }

    /// The verb (first argv token) of every run, in order.
    var requestedVerbs: [String] { requested.map { $0.first ?? "" } }

    // MARK: - Gated Verbs (hold a run open; complete runs oldest-first)

    private var gatedVerbs: Set<String> = []
    private var activeGates: [String: PassthroughSubject<String, SimCtlError>] = [:]

    /// Holds every run of `verb` open — each run gets its own gate; complete them in order.
    func hold(_ verb: String) {
        gatedVerbs.insert(verb)
    }

    /// Delivers `output` through the verb's most recent gated run and finishes it.
    func complete(_ verb: String, with output: String) {
        guard let subject = activeGates[verb] else {
            Issue.record("no open gate for verb \(verb)")
            return
        }
        activeGates[verb] = nil
        subject.send(output)
        subject.send(completion: .finished)
    }

    func run(_ args: [String], stdin: Data?) -> AnyPublisher<String, SimCtlError> {
        requested.append(args)
        let verb = args.first ?? ""
        if gatedVerbs.contains(verb) {
            let subject = PassthroughSubject<String, SimCtlError>()
            activeGates[verb] = subject
            return subject.eraseToAnyPublisher()
        }
        switch outcomes[verb] {
        case .success(let output):
            return Just(output).setFailureType(to: SimCtlError.self).eraseToAnyPublisher()
        case .failure(let error):
            return Fail(error: error).eraseToAnyPublisher()
        case nil:
            return Empty().setFailureType(to: SimCtlError.self).eraseToAnyPublisher()
        }
    }
}

extension ScriptedSimCtlDouble {

    /// Yields the main actor so `.receive(on: DispatchQueue.main)` deliveries land before
    /// assertions — Combine hops enqueue async main-queue jobs even with synchronous doubles.
    @MainActor
    func pumpMainQueue() async {
        for _ in 0 ..< 50 { await Task.yield() }
    }
}
