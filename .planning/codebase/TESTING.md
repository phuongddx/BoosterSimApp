# Testing Patterns

**Analysis Date:** 2026-08-29

## Test Frameworks

**Unit Tests:**
- Framework: Swift Testing (`import Testing`)
- Location: `BoosterSimAppTests/`
- Assertion macro: `#expect(...)`
- No mocking framework in use
- No test config file — uses Xcode default Swift Testing runner

**UI Tests:**
- Framework: XCTest (`import XCTest`)
- Location: `BoosterSimAppUITests/`
- Assertion: `XCTAssertTrue`, `XCAssertEqual`, etc.
- `XCTApplicationLaunchMetric()` for launch performance

## Run Commands

```bash
# Unit tests (Swift Testing)
xcodebuild test \
  -project BoosterSimApp.xcodeproj \
  -scheme BoosterSimApp \
  -destination 'platform=macOS' \
  -only-testing:BoosterSimAppTests

# UI tests
xcodebuild test \
  -project BoosterSimApp.xcodeproj \
  -scheme BoosterSimApp \
  -destination 'platform=macOS' \
  -only-testing:BoosterSimAppUITests

# UI tests with screenshots (as used in CI)
xcodebuild test \
  -project BoosterSimApp.xcodeproj \
  -scheme BoosterSimApp \
  -destination 'platform=macOS' \
  -only-testing:BoosterSimAppUITests/ScreenshotTests \
  -resultBundlePath UITestResults
```

## Test File Organization

**Location pattern:** Tests live in separate directories mirroring the Xcode target structure:

```
BoosterSimAppTests/
├── BoosterSimAppTests.swift            # Xcode-generated scaffold (empty @Test)
└── CertificateServiceTests.swift      # Real unit tests

BoosterSimAppUITests/
├── BoosterSimAppUITests.swift          # Xcode-generated scaffold (empty test)
├── BoosterSimAppUITestsLaunchTests.swift  # Launch + performance test
└── ScreenshotTests.swift               # Screenshot capture for visual regression
```

**Naming:** `{TargetName}Tests.swift` for unit tests, `{Purpose}Tests.swift` for UI tests. File names are PascalCase.

## Test Structure

**Unit Tests (Swift Testing):**
```swift
import Testing
@testable import BoosterSimApp

struct CertificateServiceTests {

    @Test func certificateOperationAllowsExpectedTransitions() {
        #expect(CertificateOperation.idle.canTransition(to: .generating))
        #expect(CertificateOperation.generating.canTransition(to: .error("failed")))
        #expect(!CertificateOperation.installing.canTransition(to: .generating))
    }

    @Test func certificateStatusExposesMetadataWhenAvailable() {
        let expiry = Date(timeIntervalSince1970: 1_234_567)
        let generated = CertificateStatus.generated(cn: "BoosterSim CA", expiry: expiry, sha256: "abc")
        #expect(generated.certificateMetadata?.commonName == "BoosterSim CA")
    }
}
```

**Patterns:**
- `struct` (value type) for test suites — not `class`
- `@Test` macro on each test function (no `func test...` naming required)
- `#expect(...)` for assertions
- `@testable import BoosterSimApp` for access to internal types
- No `setUp`/`tearDown` — state created inline per test

**UI Tests (XCTest):**
```swift
final class ScreenshotTests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    @MainActor
    func testLaunchScreen() throws {
        app.launch()
        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 5))
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "01-launch"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }
}
```

**Patterns:**
- `final class` conforming to `XCTestCase`
- `@MainActor` on test methods that interact with the app
- `setUpWithError()` for per-test setup; `continueAfterFailure = false`
- Screenshot capture via `XCTAttachment(screenshot:).lifetime = .keepAlways`
- Sequential naming: `01-launch`, `02-side-window-default`, `03-side-window-tab-{n}`

## Mocking

**No mocking framework** is configured or imported. Current tests test pure model logic (`CertificateOperation` state transitions, `CertificateStatus` metadata) that requires no mocks.

**What to mock (when needed):**
- `SimCtlService` — for services that call xcrun subprocesses
- `SimulatorWindowTracker` — for view tests that depend on simulator state
- `CertificateStore` — for `CertificateService` tests

**Approach:** Use protocol-based dependency injection. Create a protocol (e.g., `SimCtlProviding`) and inject a mock conformer. The existing `init` dependency injection pattern in services (e.g., `CertificateService(simCtl:)`) supports this directly.

**What NOT to mock:**
- Model types (`CertificateStatus`, `CertificateOperation`, `NetworkEvent`) — test directly
- Pure utility types (`DesignTokens`, `AppLogger`)

## Fixtures and Factories

**Test data:** Created inline within test functions:
```swift
let expiry = Date(timeIntervalSince1970: 1_234_567)
let generated = CertificateStatus.generated(cn: "BoosterSim CA", expiry: expiry, sha256: "abc")
```

**Location:** No shared fixture files or factory directories exist. All test data is inline.

## Coverage

**Requirements:** No enforced coverage target.

**Current state:** Only model-layer logic is tested (`CertificateOperation` transitions, `CertificateStatus` metadata). Services, views, and controllers have zero test coverage.

## Test Types

**Unit Tests:**
- Framework: Swift Testing
- Scope: Model logic, enums, state transitions
- One test file with 2 test functions: `BoosterSimAppTests/CertificateServiceTests.swift`

**UI Tests:**
- Framework: XCTest
- Scope: Screenshot capture for visual regression, launch verification
- Primary file: `BoosterSimAppUITests/ScreenshotTests.swift` (4 test methods)
- Secondary: `BoosterSimAppUITests/BoosterSimAppUITestsLaunchTests.swift` (1 launch + 1 performance test)
- `BoosterSimAppUITests/BoosterSimAppUITests.swift`: Xcode-generated scaffold, empty tests

**E2E Tests:** Not used.

## CI Configuration

**File:** `.github/workflows/ci.yml`

**Jobs:**
1. **build** — Builds Debug + Release configurations on `macos-26`; code signing disabled; SPM dependency caching
2. **ui-tests** — Runs `ScreenshotTests` only; extracts PNG screenshots from xcresult; uploads xcresult bundle and screenshots as artifacts (14-day retention)
3. **build-benchmark** (PR only) — Measures build time in seconds; posts to `$GITHUB_STEP_SUMMARY`

**Notable CI gaps:**
- Unit tests (`BoosterSimAppTests`) are **not run in CI** — only UI tests and builds execute
- No coverage reporting
- Build benchmark runs on PRs only, not on push to main

**UI test output:**
- xcresult bundle uploaded as `ui-test-results` artifact
- Screenshots extracted and uploaded as `ui-screenshots` artifact
- Uses `xcbeautify` for build output formatting (piped with `|| true` so UI test failures don't fail the job)

**Concurrency:** `cancel-in-progress: true` on same ref

## Common Patterns

**State machine testing:**
```swift
@Test func certificateOperationAllowsExpectedTransitions() {
    #expect(CertificateOperation.idle.canTransition(to: .generating))
    #expect(!CertificateOperation.installing.canTransition(to: .generating))
}
```

**Metadata extraction testing:**
```swift
@Test func certificateStatusExposesMetadataWhenAvailable() {
    let status = CertificateStatus.generated(cn: "BoosterSim CA", expiry: expiry, sha256: "abc")
    #expect(status.certificateMetadata?.commonName == "BoosterSim CA")
    #expect(CertificateStatus.notGenerated.certificateMetadata == nil)
}
```

**Async testing:** Swift Testing supports `async throws` on `@Test` functions natively. XCTest UI tests use `@MainActor` annotation.

---

*Testing analysis: 2026-08-29*
