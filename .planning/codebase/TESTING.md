# Testing Patterns

**Analysis Date:** 2026-03-25

## Test Framework

**Runner:**
- Swift Testing framework (iOS 18+, macOS 15+)
- Xcode 16.0+ native support (no external test runner required)
- Config: Auto-detected; no explicit config file present

**Assertion Library:**
- Swift Testing `#expect()` macro (replaces XCTest assertions)
- Example from `BoosterSimAppTests.swift` line 13: `#expect(...)`

**Run Commands:**
```bash
# Run all tests (from Xcode project root)
xcodebuild -project BoosterSimApp.xcodeproj -scheme BoosterSimApp -configuration Debug test

# Run tests in Xcode (Cmd+U)
# Opens Test Navigator (Cmd+6) to run/debug specific tests

# Watch mode (via Xcode)
# Not automated; manual re-run via Cmd+U
```

## Test File Organization

**Location:**
- `BoosterSimAppTests/` — Unit tests for main app
- `BoosterSimAppUITests/` — UI tests (present but minimal)
- Tests are **separate from source** (not co-located)
- Target: `BoosterSimAppTests` (created by Xcode template)

**Naming:**
- Test file: `[Module]Tests.swift`
- Example: `BoosterSimAppTests.swift`
- Struct pattern: `struct [Feature]Tests` or `struct BoosterSimAppTests`

**Structure:**
```
BoosterSimAppTests/
├── BoosterSimAppTests.swift        # Main test suite
├── BoosterSimAppUITests/
│   ├── BoosterSimAppUITests.swift  # UI test cases
│   └── BoosterSimAppUITestsLaunchTests.swift  # Launch tests (Xcode template)
```

## Test Structure

**Suite Organization (Swift Testing):**
```swift
import Testing
@testable import BoosterSimApp

struct BoosterSimAppTests {

    @Test func example() async throws {
        // Test implementation
    }
}
```

**Key characteristics:**
- Tests are `@Test` decorated async functions (no `func test*()` naming required)
- Can be `async throws` for async operations and error handling
- No setup/teardown methods observed yet (project is MVP with minimal tests)
- Each test is independent

**Patterns observed:**
- **No setup pattern yet** — project has no configured test fixtures
- **No teardown pattern yet** — no resource cleanup tests
- **Placeholder test structure** — current test is a template placeholder (line 13):
```swift
@Test func example() async throws {
    // Write your test here and use APIs like `#expect(...)` to check expected conditions.
}
```

## Mocking

**Framework:**
- None configured
- No mock library imports observed in test files

**Patterns:**
- Not yet implemented in this project
- Would require dependency injection at service level (which exists: see `SideWindowController.init()` constructor injection)

**What to Mock (future pattern):**
- Services with external dependencies: `PermissionManager`, `WindowEnumerator`, `SimCtlService`
- Network/file I/O: `BuildStatsService` file reads
- System APIs: `CGWindowListCopyWindowInfo`, `AXObserver` callbacks

**What NOT to Mock:**
- Model types (`SimulatorWindow`, `AppSettings`, `BuildRecord`) — use real instances
- UI components (SwiftUI views) — defer to UI testing framework
- Pure utility functions (`PositionCalculator`, `DesignTokens`) — test directly

## Fixtures and Factories

**Test Data:**
- Not yet defined in project
- Would follow `SimulatorWindow` structure if added:
```swift
// Proposed (not yet implemented):
let testSimulator = SimulatorWindow(
    id: 100,
    pid: 1234,
    deviceName: "iPhone 16 Pro",
    frame: CGRect(x: 100, y: 100, width: 393, height: 852),
    isOnScreen: true,
    isMinimized: false,
    deviceType: .iOS,
    udid: "ABCD1234-5678-90EF-GHIJ-KLMNOPQRSTUV"
)
```

**Location:**
- Would belong in `BoosterSimAppTests/` directory
- Proposed file: `TestFixtures.swift` or `MockData.swift`

## Coverage

**Requirements:**
- No coverage targets configured
- No code coverage reporting set up
- MVP phase — focus on happy path testing

**View Coverage (future):**
```bash
# Coverage not yet available
# Future: xcodebuild test with -resultBundlePath and .xccoverage report
```

## Test Types

**Unit Tests:**
- **Scope:** Single service or utility in isolation
- **Approach:** Direct function calls + `#expect()` assertions
- **Example target:** `PositionCalculator.panelFrame()` — pure function returning CGRect
- **Example target:** `WindowEnumerator.enumerateSimulatorWindows()` — with mocked CGWindowList

**Integration Tests:**
- **Scope:** Multi-service interaction (tracker + window controller + animation)
- **Approach:** Combine observables, test state transitions
- **Example target:** SimulatorWindowTracker + SideWindowController positioning
  - Inject tracker into controller
  - Publish simulator change
  - Assert position updates via spring animator
- **Example target:** AppDelegate + all services
  - Test full app lifecycle on launch
  - Assert services start/stop correctly

**E2E Tests:**
- **Framework:** `BoosterSimAppUITests` (XCTest UI automation)
- **Current state:** Template/placeholder only (`BoosterSimAppUITestsLaunchTests.swift`)
- **Would test:**
  - App launches and menu bar icon appears
  - Side panel shows when Simulator opens
  - Position tracks correctly as Simulator moves
  - Preferences changes persist

## Common Patterns (Expected)

**Async Testing:**
```swift
@Test func testSimulatorTracking() async throws {
    let tracker = SimulatorWindowTracker()
    tracker.startTracking()

    // Wait for async detection
    try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second

    #expect(!tracker.simulators.isEmpty)

    tracker.stopTracking()
}
```

**Error Testing (Optional Handling):**
```swift
@Test func testPermissionCheckWithoutGrant() async throws {
    let manager = PermissionManager()
    manager.checkAccessibility()

    // No throw expected; should return gracefully with false
    #expect(manager.accessibilityGranted == false)
}
```

**Service State Testing:**
```swift
@Test func testAppSettingsStorage() async throws {
    let settings = AppSettings()
    settings.position = .left

    #expect(settings.position == .left)

    // @AppStorage persists; would need UserDefaults reset between tests
}
```

**Combine Observation Testing (Future):**
```swift
@Test func testTrackerPublishes() async throws {
    let tracker = SimulatorWindowTracker()
    var published: [SimulatorWindow]?

    let cancellable = tracker.$simulators.sink { value in
        published = value
    }

    tracker.scanAndUpdate()

    #expect(published != nil)
    cancellable.cancel()
}
```

## Test Organization Guidance (For Future Implementation)

**Directory structure to establish:**
```
BoosterSimAppTests/
├── BoosterSimAppTests.swift              # Main test file (entry point)
├── Fixtures/
│   ├── TestFixtures.swift                # Shared test data (SimulatorWindow, AppSettings)
│   └── MockServices.swift                # Mock services (WindowEnumerator, PermissionManager)
├── Services/
│   ├── SimulatorWindowTrackerTests.swift # SimulatorWindowTracker tests
│   ├── PermissionManagerTests.swift      # PermissionManager tests
│   ├── BuildStatsServiceTests.swift      # BuildStatsService tests
│   └── WindowObserverTests.swift         # WindowObserver integration tests
├── Utilities/
│   ├── PositionCalculatorTests.swift     # PositionCalculator frame math tests
│   └── SpringAnimatorTests.swift         # SpringAnimator physics tests
└── Views/
    └── (UI tests belong in BoosterSimAppUITests/)
```

## Current Test Status

**Present Files:**
- `BoosterSimAppTests/BoosterSimAppTests.swift` — Template with 1 placeholder test
- `BoosterSimAppUITests/BoosterSimAppUITests.swift` — Empty UI test suite
- `BoosterSimAppUITests/BoosterSimAppUITestsLaunchTests.swift` — Xcode auto-generated launch test

**Test Coverage:**
- **0% code coverage** — no meaningful tests yet
- **All features untested** — unit, integration, and E2E coverage gaps

**High-Priority Test Targets (MVP Phase):**
1. **WindowEnumerator.enumerateSimulatorWindows()** — Core detection logic
2. **SimulatorWindowTracker state publishing** — Observable updates when simulator list changes
3. **PositionCalculator.panelFrame()** — Frame math for all positions (left/right/bottom/dynamic)
4. **SideWindowController positioning** — Integration: tracker → position → panel frame update
5. **SpringAnimator physics** — Ensure spring easing smooth and stops at rest
6. **PermissionManager state checks** — Accessibility, Screen Recording, Xcode, DerivedData

**Secondary Targets (Phase 2):**
- AppSettings persistence + Combine updates
- BuildStatsService plist parsing
- WindowObserver AXObserver callback delivery
- Onboarding window lifecycle
- Preferences scene state sync

## Notes for Test Implementation

**No test framework installed yet:**
- Swift Testing is built-in (Xcode 16+)
- No external packages (Combine, AppKit are system frameworks)

**Key considerations for future tests:**
- **Main thread enforcement:** Services marked @MainActor require test code on main thread
  - Use `@MainActor` on test functions that create @MainActor services
  - Or dispatch to main: `DispatchQueue.main.async { ... }`
- **UserDefaults isolation:** Tests using AppSettings (@AppStorage) need to reset UserDefaults between tests
  - Consider adding test helper: `UserDefaults.standard.removePersistentDomain(forName:)`
- **Timer/polling cleanup:** Services with `Timer` properties (tracker, services) must call `stopMonitoring()` in cleanup
  - Example: `tracker.stopTracking()` in test teardown (via deinit if needed)
- **Weak self capture testing:** Verify reference cycles don't prevent deallocation
  - Use `weak` references in test assertions to ensure cleanup
- **Display link testing:** `SpringAnimator` uses `CADisplayLink` — may need mocking for deterministic tests
- **System permissions:** Tests cannot check actual system grants (Accessibility, Screen Recording)
  - Assume false by default; mock permission checks for tests

---

*Testing analysis: 2026-03-25*
