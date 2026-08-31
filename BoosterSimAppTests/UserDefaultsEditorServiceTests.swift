// UserDefaultsEditorServiceTests.swift — Wave 0: typed plist parse + validated spawn-defaults argv contracts
import Foundation
import Testing
@testable import BoosterSimApp

struct UserDefaultsEditorServiceTests {

    // MARK: - Fixtures (synthesized at runtime in temp dirs — nested bundle-resource
    // directories break macOS test-bundle codesign, 03-01 precedent)

    private func makeFixturePlist(_ entries: [String: Any]) throws -> (path: String, cleanup: URL) {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("UserDefaultsEditorServiceTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let path = dir.appendingPathComponent("fixture.plist").path
        try #require(NSDictionary(dictionary: entries).write(toFile: path, atomically: true))
        return (path, dir)
    }

    // MARK: - Fixture Plist → Typed Entries

    @Test func fixturePlistParsesToTypedEntries() throws {
        let blob = Data([0x68, 0x65, 0x6c, 0x6c, 0x6f])
        let (path, cleanup) = try makeFixturePlist([
            "apiHost": "api.example.com",
            "retryLimit": 3,
            "hasSeenIntro": true,
            "recentSearches": ["swift", "simctl"],
            "rawBlob": blob,
        ])
        defer { try? FileManager.default.removeItem(at: cleanup) }

        let entries = UserDefaultsEditorService.parseEntries(fromPlistAt: path)

        #expect(entries.map(\.key) == ["apiHost", "hasSeenIntro", "rawBlob", "recentSearches", "retryLimit"])
        #expect(entries.first(where: { $0.key == "apiHost" })?.value == .string("api.example.com"))
        #expect(entries.first(where: { $0.key == "retryLimit" })?.value == .int(3))
        #expect(entries.first(where: { $0.key == "hasSeenIntro" })?.value == .bool(true))
        #expect(entries.first(where: { $0.key == "recentSearches" })?.value == .array(["swift", "simctl"]))
        #expect(entries.first(where: { $0.key == "recentSearches" })?.typeLabel == "array")
        #expect(entries.first(where: { $0.key == "rawBlob" })?.value == .json(blob))
    }

    @Test func intZeroAndOneAreNotMisreadAsBooleans() throws {
        // NSNumber bridging trap: plain `as? Bool` turns integer 0/1 into false/true.
        // The parser must discriminate CFBoolean so integers keep their type.
        let (path, cleanup) = try makeFixturePlist(["launchCount": 1, "failureCount": 0, "flagOn": true])
        defer { try? FileManager.default.removeItem(at: cleanup) }

        let entries = UserDefaultsEditorService.parseEntries(fromPlistAt: path)

        #expect(entries.first(where: { $0.key == "launchCount" })?.value == .int(1))
        #expect(entries.first(where: { $0.key == "failureCount" })?.value == .int(0))
        #expect(entries.first(where: { $0.key == "flagOn" })?.value == .bool(true))
    }

    @Test func missingPlistYieldsEmptyListNotError() {
        let missing = FileManager.default.temporaryDirectory
            .appendingPathComponent("no-such-domain-\(UUID().uuidString).plist").path

        #expect(UserDefaultsEditorService.parseEntries(fromPlistAt: missing) == [])
    }

    @Test func parsingIsDeterministicAndSortedByKey() throws {
        let (path, cleanup) = try makeFixturePlist(["zeta": "1", "alpha": "2", "mid": "3"])
        defer { try? FileManager.default.removeItem(at: cleanup) }

        let first = UserDefaultsEditorService.parseEntries(fromPlistAt: path)
        let second = UserDefaultsEditorService.parseEntries(fromPlistAt: path)

        #expect(first.map(\.key) == ["alpha", "mid", "zeta"])
        #expect(first == second)
    }

    // MARK: - Write Args (exact argv per kind — RESEARCH Verified Surface)

    @Test func writeArgsBuildExactStringForm() {
        let entry = DefaultsEntry(key: "apiHost", value: .string("api.example.com"))

        let args = UserDefaultsEditorService.writeArgs(entry: entry, udid: "UDID-1", domain: "com.example.app")

        #expect(args == .success(["spawn", "UDID-1", "defaults", "write",
                                  "com.example.app", "apiHost", "-string", "api.example.com"]))
    }

    @Test func writeArgsBuildExactIntForm() {
        let entry = DefaultsEntry(key: "retryLimit", value: .int(42))

        let args = UserDefaultsEditorService.writeArgs(entry: entry, udid: "UDID-1", domain: "com.example.app")

        #expect(args == .success(["spawn", "UDID-1", "defaults", "write",
                                  "com.example.app", "retryLimit", "-int", "42"]))
    }

    @Test func writeArgsBuildExactBoolForms() {
        let yes = DefaultsEntry(key: "hasSeenIntro", value: .bool(true))
        let no = DefaultsEntry(key: "hasSeenIntro", value: .bool(false))

        let yesArgs = UserDefaultsEditorService.writeArgs(entry: yes, udid: "UDID-1", domain: "com.example.app")
        let noArgs = UserDefaultsEditorService.writeArgs(entry: no, udid: "UDID-1", domain: "com.example.app")

        #expect(yesArgs == .success(["spawn", "UDID-1", "defaults", "write",
                                     "com.example.app", "hasSeenIntro", "-bool", "YES"]))
        #expect(noArgs == .success(["spawn", "UDID-1", "defaults", "write",
                                    "com.example.app", "hasSeenIntro", "-bool", "NO"]))
    }

    @Test func writeArgsBuildExactArraySpread() {
        let entry = DefaultsEntry(key: "recentSearches", value: .array(["swift", "simctl"]))

        let args = UserDefaultsEditorService.writeArgs(entry: entry, udid: "UDID-1", domain: "com.example.app")

        #expect(args == .success(["spawn", "UDID-1", "defaults", "write",
                                  "com.example.app", "recentSearches", "-array", "swift", "simctl"]))
    }

    @Test func writeArgsCarryJSONCapsuleAsDataHex() {
        // `defaults help write`: -data <hex_digits> — round-trip verified against the tool.
        let entry = DefaultsEntry(key: "rawBlob", value: .json(Data([0x68, 0x65, 0x6c, 0x6c, 0x6f])))

        let args = UserDefaultsEditorService.writeArgs(entry: entry, udid: "UDID-1", domain: "com.example.app")

        #expect(args == .success(["spawn", "UDID-1", "defaults", "write",
                                  "com.example.app", "rawBlob", "-data", "68656c6c6f"]))
    }

    @Test func deleteArgsAreExact() {
        let args = UserDefaultsEditorService.deleteArgs(key: "apiHost", udid: "UDID-1", domain: "com.example.app")

        #expect(args == .success(["spawn", "UDID-1", "defaults", "delete", "com.example.app", "apiHost"]))
    }

    // MARK: - Name Allowlist (T-03-11 — typed error, NO argv on violation)

    @Test func invalidNamesReturnTypedErrorAndNoArgs() {
        for badKey in ["", "has space", "key$symbol", "bad|pipe", "café", "new\nline"] {
            let entry = DefaultsEntry(key: badKey, value: .string("v"))
            let result = UserDefaultsEditorService.writeArgs(entry: entry, udid: "UDID-1", domain: "com.example.app")
            #expect(result == .failure(.invalidKey))
        }

        #expect(UserDefaultsEditorService.deleteArgs(key: "ok", udid: "UDID-1", domain: "not a domain")
                == .failure(.invalidDomain))
        #expect(UserDefaultsEditorService.deleteArgs(key: "ok", udid: "", domain: "com.example.app")
                == .failure(.noDevice))
    }

    @Test func allowlistAcceptsDomainStyleNames() {
        for good in ["com.example.app", "my_key", "Key-1", "a", "ShowSingleTouches", ".GlobalPreferences"] {
            #expect(UserDefaultsEditorService.isValidName(good))
        }
    }

    // MARK: - Container Path Composition (pure function over the container string)

    @Test func containerPathComposesExactly() {
        let container = "/Users/dev/Library/Developer/CoreSimulator/Devices/5DD/Containers/Data/Application/ABC"

        #expect(UserDefaultsEditorService.preferencesPlistPath(containerPath: container, bundleID: "com.example.app")
                == container + "/Library/Preferences/com.example.app.plist")
        #expect(UserDefaultsEditorService.containerArgs(udid: "UDID-1", bundle: "com.example.app")
                == ["get_app_container", "UDID-1", "com.example.app", "data"])
    }

    // MARK: - Value Round-Trip (Equatable, no loss through the typed wrapper)

    @Test func arrayAndJSONValuesRoundTripThroughTheTypedWrapper() throws {
        let blob = Data([0x01, 0x02, 0xff])
        let (path, cleanup) = try makeFixturePlist([
            "recentSearches": ["swift", "simctl", "defaults"],
            "blob": blob,
        ])
        defer { try? FileManager.default.removeItem(at: cleanup) }

        let entries = UserDefaultsEditorService.parseEntries(fromPlistAt: path)

        #expect(entries.first(where: { $0.key == "recentSearches" })?.value == .array(["swift", "simctl", "defaults"]))
        #expect(entries.first(where: { $0.key == "blob" })?.value == .json(blob))
    }

    // MARK: - Load Supersede (03-REVIEW WR-02 — never drop a newer target, never show a stale domain)

    /// Synthesizes a data-container root whose Library/Preferences/<bundle>.plist carries
    /// `entries` — the exact layout preferencesPlistPath composes from the container verb.
    private func makeContainer(bundle: String, entries: [String: Any]) throws -> String {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("defaults-editor-\(UUID().uuidString)", isDirectory: true)
        let prefs = root.appendingPathComponent("Library/Preferences", isDirectory: true)
        try FileManager.default.createDirectory(at: prefs, withIntermediateDirectories: true)
        try (entries as NSDictionary).write(to: prefs.appendingPathComponent("\(bundle).plist"))
        return root.path
    }

    /// Switching apps A→B while A's container verb is in flight must load B — the newest
    /// request supersedes the in-flight one and A's keys never render under B's domain.
    @MainActor
    @Test func loadDuringLoadingSupersedesTheInFlightLoadWithTheNewestTarget() async throws {
        let containerA = try makeContainer(bundle: "com.a", entries: ["OldKey": "old"])
        let containerB = try makeContainer(bundle: "com.b", entries: ["NewKey": "new"])
        let simCtl = ScriptedSimCtlDouble()
        simCtl.hold("get_app_container")
        let service = UserDefaultsEditorService(simCtl: simCtl)

        service.loadDomain(udid: "UDID", bundle: "com.a")
        service.loadDomain(udid: "UDID", bundle: "com.b")      // while .loading — supersede, not drop
        #expect(service.operation == .loading)

        simCtl.complete("get_app_container", with: containerA) // stale A lands — must be skipped
        await simCtl.pumpMainQueue()
        #expect(simCtl.requestedVerbs == ["get_app_container", "get_app_container"])  // B re-ran
        #expect(service.entries.isEmpty)                       // A's rows never render under B's header
        #expect(service.operation == .loading)

        simCtl.complete("get_app_container", with: containerB) // newest target's result publishes
        await simCtl.pumpMainQueue()
        #expect(service.entries.map(\.key) == ["NewKey"])
        #expect(service.operation == .idle)
        #expect(service.loadError == nil)
    }

    /// A load clears `entries` at start, so the outgoing app's rows are never displayed
    /// during the round trip.
    @MainActor
    @Test func loadClearsThePreviousDomainRowsAtStart() async throws {
        let containerA = try makeContainer(bundle: "com.a", entries: ["OldKey": "old"])
        let containerB = try makeContainer(bundle: "com.b", entries: ["NewKey": "new"])
        let simCtl = ScriptedSimCtlDouble()
        simCtl.hold("get_app_container")
        let service = UserDefaultsEditorService(simCtl: simCtl)

        service.loadDomain(udid: "UDID", bundle: "com.a")
        simCtl.complete("get_app_container", with: containerA)
        await simCtl.pumpMainQueue()
        #expect(service.entries.map(\.key) == ["OldKey"])      // A loaded normally first

        service.loadDomain(udid: "UDID", bundle: "com.b")
        #expect(service.entries.isEmpty)                       // cleared BEFORE B's result lands
        #expect(service.operation == .loading)

        simCtl.complete("get_app_container", with: containerB)
        await simCtl.pumpMainQueue()
        #expect(service.entries.map(\.key) == ["NewKey"])
        #expect(service.operation == .idle)
    }
}
