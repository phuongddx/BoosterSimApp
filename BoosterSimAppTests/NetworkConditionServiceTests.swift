import Foundation
import Testing
@testable import BoosterSimApp

struct NetworkConditionServiceTests {

    private func makeDefaults() throws -> (defaults: UserDefaults, suiteName: String) {
        let suiteName = "NetworkConditionServiceTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        return (defaults, suiteName)
    }

    // MARK: - State Machine Transitions

    @Test func networkConditionStateAllowsExpectedTransitions() {
        #expect(NetworkConditionState.idle.canTransition(to: .applying))
        #expect(NetworkConditionState.applying.canTransition(to: .applied))
        #expect(NetworkConditionState.applying.canTransition(to: .error("failed")))
        #expect(NetworkConditionState.error("failed").canTransition(to: .applying))
        #expect(NetworkConditionState.applied.canTransition(to: .applying))
    }

    @Test func networkConditionStateRejectsReentrantApplying() {
        #expect(!NetworkConditionState.applying.canTransition(to: .applying))
        #expect(!NetworkConditionState.idle.canTransition(to: .applied))
        #expect(!NetworkConditionState.idle.canTransition(to: .error("x")))
        #expect(NetworkConditionState.applying.isWorking)
        #expect(!NetworkConditionState.applied.isWorking)
        #expect(!NetworkConditionState.error("x").isWorking)
    }

    // MARK: - Airplane Persistence

    @MainActor
    @Test func airplanePersistsAcrossServiceReInit() throws {
        let (defaults, suiteName) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let first = NetworkConditionService(defaults: defaults)
        #expect(first.state == .idle)
        first.setAirplane(true)
        #expect(first.airplane == true)
        #expect(first.state == .applied)

        // Re-initialize from the same suite: persisted state must re-apply.
        let second = NetworkConditionService(defaults: defaults)
        #expect(second.airplane == true)
        #expect(second.snapshot().airplane == true)
    }

    @MainActor
    @Test func setAirplaneOffPersistsToo() throws {
        let (defaults, suiteName) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let first = NetworkConditionService(defaults: defaults)
        first.setAirplane(true)
        first.setAirplane(false)

        let second = NetworkConditionService(defaults: defaults)
        #expect(second.airplane == false)
    }

    // MARK: - Rules Persistence

    @MainActor
    @Test func ruleMutationsPersistAndUpdateSnapshot() throws {
        let (defaults, suiteName) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let service = NetworkConditionService(defaults: defaults)

        let rule = BlockRule(id: UUID(), domain: "*.example.com", pathPrefix: "/api", isEnabled: true)
        service.addRule(rule)

        let persisted = try #require(defaults.data(forKey: "networkBlockRules"))
        let decoded = try JSONDecoder().decode([BlockRule].self, from: persisted)
        #expect(decoded == [rule])
        #expect(service.snapshot().blockRules == [rule])

        service.removeRule(id: rule.id)
        #expect(service.snapshot().blockRules.isEmpty)
        let afterRemove = try #require(defaults.data(forKey: "networkBlockRules"))
        #expect(try JSONDecoder().decode([BlockRule].self, from: afterRemove).isEmpty)

        let disabled = BlockRule(id: UUID(), domain: "ads.example.net", pathPrefix: nil, isEnabled: true)
        service.addRule(disabled)
        service.setRuleEnabled(id: disabled.id, enabled: false)
        let snapshot = service.snapshot()
        #expect(snapshot.blockRules.count == 1)
        #expect(snapshot.blockRules.first?.isEnabled == false)
    }

    // MARK: - Total Snapshot Building

    @MainActor
    @Test func snapshotCombinesAirplaneAndRulesAtomically() throws {
        let (defaults, suiteName) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let service = NetworkConditionService(defaults: defaults)

        let rule = BlockRule(id: UUID(), domain: "api.example.com", pathPrefix: "/v1", isEnabled: true)
        service.setAirplane(true)
        service.addRule(rule)

        let snapshot = service.snapshot()
        // Single-writer guarantee: both conditions travel in one frame.
        #expect(snapshot.airplane == true)
        #expect(snapshot.blockRules == [rule])
        #expect(snapshot.version == BoosterCommand.version)
        #expect(snapshot.throttle == nil)
    }
}
