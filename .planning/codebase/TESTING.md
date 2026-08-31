# Testing Patterns

**Analysis Date:** 2026-08-31

## Test Framework

**Runner:**
- **Unit tests:** Swift Testing (`import Testing`) — `BoosterSimAppTests/` target. **229 `@Test` functions across 23 files** (largest: `LocaleCommandTests` 20, `CaptureExportConfigTests` 18, `AppActionServiceTests` 18, `UserDefaultsEditorServiceTests` 16, `PushPayloadTests` 15). The 229 suite was built out in Phase 4 of the GSD roadmap.
- **UI tests:** XCTest — `BoosterSimAppUITests/` target, 7 `func test*` across 3 files (`ScreenshotTests` 4, `BoosterSimAppUITests` 2 template, `BoosterSimAppUITestsLaunchTests` 1).
- **Third-party test deps:** None. `BoosterSimApp.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved` contains only Pulse 5.2.2 (production dep of the `BoosterSimConnect` target).

**Assertion Library:**
- Swift Testing `#expect(...)` and `#require(...)`; `Issue.record("...")` for guard-style failures when destructuring pattern matches (see `BoosterSimAppTests/PushPayloadTests.swift`, `SimCtlServiceTests.swift`).
- XCTest `XCTAssertTrue` in UI tests only.

**Run Commands:**
```bash
# All tests (Xcode: Cmd-U on scheme BoosterSimApp)
xcodebuild test -project BoosterSimApp.xcodeproj -scheme BoosterSimApp -destination 'platform=macOS'

# Only UI screenshots (what CI runs — .github/workflows/ci.yml)
xcodebuild test -project BoosterSimApp.xcodeproj -scheme BoosterSimApp \
  -destination 'platform=macOS' -configuration Debug \
  -only-testing:BoosterSimAppUITests/ScreenshotTests
```

**Coverage approach:** No coverage targets enforced; no coverage tooling in CI. CI (`.github/workflows/ci.yml`) builds Debug+Release and runs ONLY `-only-testing:BoosterSimAppUITests/ScreenshotTests` — the Swift Testing unit suite runs locally/via Xcode, not in CI.

## Test File Organization

**Location:**
- Flat directory: `BoosterSimAppTests/` (one file per service/concern, no mirrors of source tree).
- Shared test doubles live in files WITHOUT the `Tests` suffix: `BoosterSimAppTests/ScriptedSimCtl.swift`.

**Naming:**
- `SubjectTests.swift` for `struct SubjectTests` (e.g., `NetworkConditionServiceTests.swift` → `NetworkConditionServiceTests`).
- Shared doubles: descriptive noun (`ScriptedSimCtl.swift` → `ScriptedSimCtlDouble`).

**Structure:**
```
BoosterSimAppTests/
├── ScriptedSimCtl.swift              # shared seam double (SimCtlRunning)
├── <Subject>Tests.swift              # one struct per subject, flat
BoosterSimAppUITests/
├── ScreenshotTests.swift             # numbered screenshot attachments
├── BoosterSimAppUITestsLaunchTests.swift
└── BoosterSimAppUITests.swift        # Xcode template (placeholder)
```

## Test Structure

**Suite Organization** (`BoosterSimAppTests/NetworkConditionServiceTests.swift`):
```swift
// NetworkConditionServiceTests.swift — one-line purpose header
import Foundation
import Testing
@testable import BoosterSimApp

struct NetworkConditionServiceTests {          // struct, not class

    private func makeDefaults() throws -> (defaults: UserDefaults, suiteName: String) {
        let suiteName = "NetworkConditionServiceTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        return (defaults, suiteName)
    }

    // MARK: - Airplane Persistence

    @MainActor
    @Test func airplanePersistsAcrossServiceReInit() throws {
        let (defaults, suiteName) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let first = NetworkConditionService(defaults: defaults, commandServer: NoopCommandBroadcast())
        first.setAirplane(true)
        #expect(first.airplane == true)

        // Re-initialize from the same suite: persisted state must re-apply.
        let second = NetworkConditionService(defaults: defaults, commandServer: NoopCommandBroadcast())
        #expect(second.airplane == true)
    }
}
```

**Patterns:**
- `struct` suites; `@Test func` methods with full-sentence contract names.
- `@MainActor` on the whole struct (`OverlayPersistenceTests`) or per-test when the service under test is MainActor-isolated (app target defaults to MainActor isolation; test targets do NOT, so explicit annotation is required).
- `// MARK: -` sections group behaviors within a suite (`// MARK: - State Machine Transitions`, `// MARK: - Fixtures`).
- **Isolated persistence:** every test needing defaults uses the `makeDefaults()` helper — a UUID-suffixed `UserDefaults(suiteName:)` plus `defer { defaults.removePersistentDomain(forName: suiteName) }` teardown.
- **Re-init persistence testing:** instantiate service from suite → mutate → construct a SECOND instance from the same suite → assert state re-applied (canonical in `NetworkConditionServiceTests`, `CaptureSettingsTests`, `OverlayPersistenceTests`).

## Mocking

**Framework:** Hand-rolled protocol seam doubles — no mocking library.

**Seam protocols live in PRODUCTION code** so facades take doubles in tests:
- `SimCtlRunning` — `BoosterSimApp/Services/SimCtlService.swift` (conformed by `SimCtlService`)
- `CommandBroadcasting` — `BoosterSimApp/Services/CommandServer.swift`
- `AppKeychainResetting` — `BoosterSimApp/Models/AppActionModels.swift`
- `TouchPreferencesStore` — `BoosterSimApp/Services/TouchIndicatorController.swift`

**Doubles:**
- `ScriptedSimCtlDouble` (`BoosterSimAppTests/ScriptedSimCtl.swift`) — shared scripted double: `when(verb, returns:)` cans outcomes per first-argv-token; `hold(verb)` + `complete(verb, with:)` gate in-flight runs oldest-first for race tests; `requested`/`requestedVerbs` record invocations.
- `NoopCommandBroadcast` — a no-op `CommandBroadcasting` implemented in PRODUCTION code (`CommandServer.swift`) and injected by tests; the codebase pattern for "test needs a silent collaborator."
- Small per-file doubles are `private final class` inside the test file (`KeychainResetDouble` in `AppActionServiceTests.swift`) with plain recorded `calls: [String]` arrays.

```typescript
// Scripted-double usage (AppActionServiceTests.swift)
let simCtl = ScriptedSimCtlDouble()
simCtl.when("terminate", returns: .success(""))
service.resetApp(udid: "CONCRETE-UDID", bundleID: "com.example.app")
await pumpMainQueue()   // chain lands via .receive(on: main) even with a synchronous double
#expect(simCtl.requestedVerbs == ["terminate", "listapps", "uninstall"])
```

**Async determinism — `pumpMainQueue()`:** Combine `.receive(on: main)` hops enqueue async main-queue jobs even with synchronous doubles, so tests call `await pumpMainQueue()` (a `for _ in 0 ..< 50 { await Task.yield() }` loop, defined on `ScriptedSimCtlDouble` and inlined in `AppActionServiceTests`) between act and assert. For gated sequencing tests, drive events and pump between each: `events.send(.resetting)` → `await pumpMainQueue()` → `#expect(...)` (see the clear-keychain reconcile tests in `AppActionServiceTests.swift`, stale-container race tests in `UserDefaultsEditorServiceTests.swift`).

**What to Mock:**
- Process boundaries (`xcrun simctl`), network broadcast sinks, keychain reset delegates, defaults stores.
- Never mock the unit under test's pure logic — builders/parsers are `static func` and tested directly with no doubles.

**What NOT to Mock:**
- `UserDefaults` — use real isolated per-test suites (pattern above).
- Codable round-trips and state machines — always exercised for real.

## Fixtures and Factories

**Test Data:**
- Inline fixture builders as private funcs/properties: `makeApp(_:age:)` building `DiscoveredApp`, embedded `listAppsXML` plist strings, `launchctlExcerpt` output samples (`BoosterSimAppTests/AppActionServiceTests.swift`).
- Legacy-payload fixtures declared as private `Codable` structs + `plantLegacyPreset(...)` writers (`BoosterSimAppTests/OverlayPersistenceTests.swift`).
- Synthetic `NSImage` factories with explicit pixel dimensions (`makeImage(pixelsWide:pixelsHigh:)` in `OverlayPersistenceTests.swift`).
- Deterministic dates: `Date(timeIntervalSince1970: 1_700_000_000)` for filename tests (`CaptureSettingsTests.swift`).

**Location:**
- Fixtures are declared inside the test file that uses them — no shared fixture directory.

## Coverage

**Requirements:** None enforced.

**View Coverage:** Not wired up (no `xcconfig`, no CI flags). Enable ad hoc via Xcode test-report coverage tab.

## Test Types

**Unit Tests:**
- Swift Testing; four families:
  1. **Pure logic** — static argv builders, output parsers, math, payload parsing with no I/O (`AppActionServiceTests` argv equality, `RulerMathTests` geometry, `PushPayloadTests` parse contracts, `GridGeometryTests`).
  2. **Persistence round-trips** — real `UserDefaults` suites + re-init (see above).
  3. **State machines** — `canTransition(to:)` accept/reject matrices (`NetworkConditionServiceTests`, `CertificateServiceTests`, `ConditionVerdictTests`).
  4. **Seam/async chains** — scripted doubles + `pumpMainQueue()` ordering assertions (`SimCtlServiceTests`, `UserDefaultsEditorServiceTests`, `AppActionServiceTests`).

**Integration Tests:**
- None as a separate tier; seam tests with real `SimCtlService` (subprocess preflight stubs only, e.g., stdin-bound rejection test) are the closest.

**E2E Tests:**
- XCTest UI tests: `ScreenshotTests.swift` launches `XCUIApplication`, asserts `window.waitForExistence(timeout: 5)`, attaches numbered screenshots via `XCTAttachment` with `.keepAlways` lifetime (`"01-launch"`, `"03-side-window-tab-\(index)"`, `"05-full-screen"` — full-desktop via `XCUIScreen.main.screenshot()`). CI exports these PNGs from the xcresult bundle and uploads them as artifacts.

## Common Patterns

**Async Testing:**
```swift
@Test func staleResultIsSkipped() async throws {
    simCtl.hold("get_app_container")
    service.loadDomain(udid: "UDID", bundle: "com.a")
    simCtl.complete("get_app_container", with: containerA)
    await simCtl.pumpMainQueue()      // let main-queue Combine hops land
    #expect(simCtl.requestedVerbs == ["get_app_container", "get_app_container"])
}
```
No `confirmation`/task-group concurrency tests exist — ordering is verified by gated `hold`/`complete` + `pumpMainQueue`.

**Error Testing:**
```swift
// Guard-destructure with Issue.record; assert typed error + boundary (SimCtlServiceTests.swift)
var failure: SimCtlError?
let cancellable = service.run(["push", "UDID", "com.x", "-"],
                              stdin: Data(count: SimCtlLimits.maxStdinBytes + 1))
    .sink(receiveCompletion: { if case .failure(let e) = completion { failure = e } },
          receiveValue: { _ in values += 1 })
guard let failure, case .stdinTooLarge(let size) = failure else {
    Issue.record("expected .stdinTooLarge for a payload over the pipe bound"); _ = cancellable; return
}
#expect(size == SimCtlLimits.maxStdinBytes + 1)
```
Boundary +1/+1-byte-over patterns recur (`PushPayloadTests` 4097-byte cap; `SimCtlServiceTests` pipe bound); corrupted-payload tests assert degrade-never-trap (`OverlayPersistenceTests` "garbage under key" tests).

**Parameterization:**
- Swift Testing parameterized `@Test(arguments:)` is NOT used; case matrices are `for` loops inside a single `@Test` over inline arrays (`BoosterSimAppTests/LocaleCommandTests.swift:38`).

---

*Testing analysis: 2026-08-31*
