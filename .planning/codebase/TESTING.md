# Testing Patterns

**Analysis Date:** 2026-08-29

## Test Framework

**Runner:**
- Swift Testing (new framework) for unit tests — `import Testing`, `@Test` macro, `#expect(...)`
- XCTest for UI tests — `import XCTest`, `XCTestCase` subclass

**Config:**
- No test configuration files — uses Xcode default test schemes
- Unit test target: `BoosterSimAppTests`
- UI test target: `BoosterSimAppUITests`

**Run Commands:**
```bash
# Build + test (from terminal)
xcodebuild test \
  -project BoosterSimApp.xcodeproj \
  -scheme BoosterSimApp \
  -destination 'platform=macOS' \
  -only-testing:BoosterSimAppTests

# UI tests (as run in CI)
xcodebuild test \
  -project BoosterSimApp.xcodeproj \
  -scheme BoosterSimApp \
  -destination 'platform=macOS' \
  -only-testing:BoosterSimAppUITests/ScreenshotTests
```

## Test File Organization

**Location:**
- Unit tests: `BoosterSimAppTests/` (Xcode target, sibling to `BoosterSimApp/`)
- UI tests: `BoosterSimAppUITests/` (separate Xcode target)
- CLI tests: none — `booster-sim-cli/` has no test target

**Naming:**
- `[TypeName]Tests.swift` for unit tests: `CertificateServiceTests.swift`
- `[Feature]Tests.swift` for UI tests: `ScreenshotTests.swift`
- Xcode-generated boilerplate: `BoosterSimAppTests.swift`, `BoosterSimAppUITests.swift`, `BoosterSimAppUITestsLaunchTests.swift`

**Structure:**
```
BoosterSimAppTests/
├── BoosterSimAppTests.swift            # Xcode boilerplate (empty @Test)
└── CertificateServiceTests.swift      # Only meaningful unit test

BoosterSimAppUITests/
├── BoosterSimAppUITests.swift         # Xcode boilerplate (empty test)
├── BoosterSimAppUITestsLaunchTests.swift  # Xcode boilerplate (launch screenshot)
└── ScreenshotTests.swift              # CI visual regression screenshots
```

## Test Structure

**Unit test pattern (Swift Testing):**
```swift
import Testing
@testable import BoosterSimApp

struct CertificateServiceTests {
    @Test func certificateOperationAllowsExpectedTransitions() {
        #expect(CertificateOperation.idle.canTransition(to: .generating))
        #expect(!CertificateOperation.installing.canTransition(to: .generating))
    }
}
```

**UI test pattern (XCTest):**
```swift
import XCTest

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
- **Setup:** `setUpWithError()` for XCTest; no setup needed for Swift Testing structs
- **Teardown:** Not used — no `tearDownWithError()` implementations with cleanup logic
- **Assertions:** `#expect(...)` in Swift Testing; `XCTAssertTrue`/`XCTAssertEqual` in XCTest

## Mocking

**Framework:** None — no mocking library is used or configured

**Patterns:**
- No mocks, stubs, or fakes exist in the codebase
- `SimCtlService` is concrete and spawns real `xcrun simctl` processes — not mockable without protocol extraction
- `CertificateServiceTests` tests only pure model logic (enum transitions, computed properties) that requires no mocking

**What to Mock (when adding tests):**
- `SimCtlService` — extract a protocol to mock simctl process spawning
- `SimulatorWindowTracker` — inject mock window enumeration for view tests
- `CertificateStore` — already initialized with default `UserDefaults = .standard` but accepts injection: `init(simCtl:, defaults:)`

**What NOT to Mock:**
- Pure value types (`SimulatorWindow`, `BuildRecord`, `AXNode`, `CertificateMetadata`) — test directly
- Enum transition logic (`CertificateOperation.canTransition(to:)`) — already tested without mocks
- Design token enums (`Spacing`, `CornerRadius`) — constant values, no behavior to mock

## Fixtures and Factories

**Test Data:**
- No shared test fixtures or factory methods exist
- Test data is constructed inline within each test:
  ```swift
  let expiry = Date(timeIntervalSince1970: 1_234_567)
  let generated = CertificateStatus.generated(cn: "BoosterSim CA", expiry: expiry, sha256: "abc")
  ```

**Location:**
- No fixture files or test resource directories

## Coverage

**Requirements:** None enforced

**View Coverage:**
- No coverage tool configured
- CI does not measure or report coverage
- `CLAUDE.md` explicitly states: "No tests, linting, or package manager configured"

## Test Types

**Unit Tests:**
- Framework: Swift Testing (`@Test`, `#expect`)
- Scope: Pure model logic only — enum state transitions and computed properties
- 2 test functions in `CertificateServiceTests.swift` covering `CertificateOperation` transitions and `CertificateStatus` metadata extraction
- All 15+ services, all views, and all utilities have zero unit test coverage

**Integration Tests:**
- Not used — no integration test target exists

**E2E Tests:**
- Framework: XCTest UI testing (`XCUIApplication`, `XCTAttachment`)
- Purpose: CI visual regression screenshots, not behavioral verification
- `ScreenshotTests.swift` captures 5 screenshots: launch, default tab, each of 4 tabs, window resize, full screen
- Tests use `Thread.sleep(forTimeInterval: 0.5)` for tab transitions (fragile)
- Tests use `waitForExistence(timeout: 5)` for window appearance
- Screenshot results uploaded as CI artifacts with 14-day retention
- Tests pass regardless of content (`|| true` on xcodebuild in CI) — screenshot capture is the goal, not assertions

## Common Patterns

**Async Testing:**
- No async test patterns — project prohibits async/await
- Swift Testing `@Test` functions are synchronous
- XCTest UI tests use `@MainActor` annotation

**Error Testing:**
- No error-path tests exist
- `SimCtlError` and `CertificateError` enums are untested
- Error state transitions in `CertificateOperation` are only partially covered (one `.error` case tested)

## CI Integration

**Pipeline:** `.github/workflows/ci.yml`

**Test execution in CI:**
- Build job: Debug + Release matrix, no tests run
- UI test job: runs `ScreenshotTests` only, with `|| true` (non-blocking)
- Build benchmark job: measures build time on PRs, no tests
- UI test screenshots extracted via `xcrun xcresulttool export` and uploaded as artifacts

**What CI does NOT test:**
- Unit tests are not run in CI
- No test failure blocks the merge

---

*Testing analysis: 2026-08-29*
