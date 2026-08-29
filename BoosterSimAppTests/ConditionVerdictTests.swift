import Foundation
import Testing
@testable import BoosterSimApp

struct ConditionVerdictTests {

    private func makeRequest(_ urlString: String) -> URLRequest {
        URLRequest(url: URL(string: urlString)!)
    }

    // MARK: - Airplane

    @Test func airplaneFailsEveryRequestRegardlessOfRules() {
        let snapshot = BoosterCommand(
            airplane: true,
            blockRules: [BlockRule(id: UUID(), domain: "ads.example.net", pathPrefix: nil, isEnabled: true)]
        )

        let verdict = evaluate(
            request: makeRequest("https://api.example.com/v1/users"),
            snapshot: snapshot
        )

        #expect(verdict == .fail(.notConnectedToInternet))
    }

    @Test func internalGuardedRequestPassesThroughEvenUnderAirplane() {
        let mutable = NSMutableURLRequest(url: URL(string: "https://api.example.com/v1/users")!)
        URLProtocol.setProperty(true, forKey: BoosterInternalGuard.markerKey, in: mutable)
        let guarded = mutable.copy() as! URLRequest

        let snapshot = BoosterCommand(airplane: true)

        #expect(evaluate(request: guarded, snapshot: snapshot) == .passThrough)
    }

    // MARK: - Block Rules

    @Test func enabledMatchingRuleFailsWithCannotConnectToHost() {
        let snapshot = BoosterCommand(
            airplane: false,
            blockRules: [BlockRule(id: UUID(), domain: "api.example.com", pathPrefix: "/api", isEnabled: true)]
        )

        let verdict = evaluate(
            request: makeRequest("https://api.example.com/api/v2/feed"),
            snapshot: snapshot
        )

        #expect(verdict == .fail(.cannotConnectToHost))
    }

    @Test func disabledRulePassesThrough() {
        let snapshot = BoosterCommand(
            airplane: false,
            blockRules: [BlockRule(id: UUID(), domain: "api.example.com", pathPrefix: nil, isEnabled: false)]
        )

        #expect(evaluate(request: makeRequest("https://api.example.com/anything"), snapshot: snapshot) == .passThrough)
    }

    // MARK: - Clean State

    @Test func noConditionsPassThrough() {
        let snapshot = BoosterCommand(airplane: false, throttle: nil, blockRules: [])

        #expect(evaluate(request: makeRequest("https://api.example.com/"), snapshot: snapshot) == .passThrough)
    }
}
