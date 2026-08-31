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

    func run(_ args: [String], stdin: Data?) -> AnyPublisher<String, SimCtlError> {
        requested.append(args)
        switch outcomes[args.first ?? ""] {
        case .success(let output):
            return Just(output).setFailureType(to: SimCtlError.self).eraseToAnyPublisher()
        case .failure(let error):
            return Fail(error: error).eraseToAnyPublisher()
        case nil:
            return Empty().setFailureType(to: SimCtlError.self).eraseToAnyPublisher()
        }
    }
}
