# Coding Conventions

**Analysis Date:** 2026-08-29

## Naming Patterns

**Files:**
- PascalCase `.swift` matching primary type: `SideWindowController.swift`, `CaptureService.swift`, `FeatureRowView.swift`
- One primary type per file; companion types (enums, helpers) may coexist
- File header comment: `// FileName.swift — single-line purpose description`

**Types:**
- `final class` for all services and controllers (never open inheritance)
- `struct` for value types: models (`SimulatorWindow`, `BuildRecord`, `AXNode`), enums (`SideTab`, `SimulatorDeviceType`)
- Enums use `camelCase` cases with `rawValue` where needed for persistence/serialization
- `enum` as namespace for constants: `Spacing`, `CornerRadius`, `SideWindowMetrics`, `OnboardingMetrics`, `PreferencesMetrics`

**Functions:**
- `camelCase` for all functions and methods
- Action methods: verb phrases — `startTracking()`, `loadCurrentState(udid:)`, `toggleCollapsed()`
- Boolean properties: `is`/`has` prefix — `isLoading`, `isCollapsed`, `hasChildren`, `isOnScreen`
- Computed properties for derived display values — `formattedDuration`, `displayName`, `currentSizeName`

**Variables:**
- `camelCase` throughout
- `private(set)` on `@Published` state that should not be mutated externally: `@Published private(set) var isVisible = false`
- Combine cancellation sets named `cancellables`
- Timer references: `pollTimer`

**Types:**
- Swift-native types preferred — no third-party DTO libraries
- `LocalizedError` conformance on error enums for user-facing descriptions: `SimCtlError`, `CertificateError`

## Code Style

**Formatting:**
- No external formatter configured (no `.swiftformat`, no SwiftLint)
- Xcode default indentation (4 spaces)
- Single newline between `MARK` sections, no blank lines between consecutive `MARK` blocks

**Linting:**
- No linter configured
- `CLAUDE.md` states: "No tests, linting, or package manager configured"

**Target file size:**
- 200 LOC guideline from `docs/code-standards.md`
- Several files exceed this: `CaptureService.swift` (312 LOC), `TrafficDetailView.swift` (295 LOC), `EnvironmentOverrideService.swift` (279 LOC)

## Import Organization

**Order:**
1. Apple framework imports (`Foundation`, `AppKit`, `SwiftUI`, `Combine`, `CoreGraphics`, `ApplicationServices`, etc.)
2. No third-party imports — project uses zero external dependencies in the main app target

**Observations from codebase:**
- Imports are alphabetical within the Apple framework group
- No unused imports detected in reviewed files
- CLI target (`booster-sim-cli/`) imports `ArgumentParser` (only external dependency)

**Path Aliases:**
- None — no module aliases or custom import paths

## Error Handling

**Patterns:**
- Custom `enum` errors conforming to `LocalizedError` with `errorDescription` computed property
- Example from `BoosterSimApp/Services/SimCtlService.swift`:
  ```swift
  enum SimCtlError: Error, LocalizedError {
      case commandFailed(String)
      case xcrunNotFound
      case timeout
      var errorDescription: String? { ... }
  }
  ```
- `do/catch` for throwing APIs — `try!` and `as!` prohibited per `docs/code-standards.md`
- Permission failures are non-fatal: log and continue with degraded state
- Combine `receiveCompletion` handlers typically discard errors with `{ _ in }` for fire-and-forget simctl calls
- `CertificateService` uses a state machine (`CertificateOperation`) with explicit `canTransition(to:)` guard to prevent invalid operations

## Logging

**Framework:** Dual approach — `os.Logger` for structured logging, `print()` for debug output

**Structured logging:**
- `AppLogger` enum in `BoosterSimApp/Utilities/AppLogger.swift` — centralized `os.Logger` instances per concern
- Subsystem: `com.nextlabs.BoosterSimApp`
- Categories: `WindowTracking`, `Permissions`, `Settings`, `Certificates`
- Usage: `AppLogger.settings.error("Launch at login error: \(error, privacy: .public)")`

**Debug print logging:**
- `print("[ClassName] message")` pattern used throughout services
- Example: `print("[SimCtl] xcrun simctl \(args.joined(separator: " "))")`
- Example: `print("[EnvOverride] setAppearance: \(style.rawValue) (udid: \(udid))")`
- Prefix format: `[ShortClassName]` or `[ServiceName]`

**Patterns:**
- Structured `AppLogger` used for errors and lifecycle events
- `print()` used for command tracing and debug state changes
- Never log sensitive data (UDIDs, file paths, user tokens) per code standards

## Comments

**When to Comment:**
- File header: single-line purpose description on line 1 — `// SideWindowController.swift — Manages SideWindowPanel lifecycle, position sync, and collapse state`
- `MARK` sections used consistently for code organization
- Inline comments for non-obvious decisions: `// NOTE: envOverrideService.loadCurrentState is called from EnvironmentOverridesView (onAppear + onChange) — no need to duplicate here.`
- Workarounds documented: `// Uses raw AX attribute string constants for macOS 26 SDK compatibility.`

**JSDoc/TSDoc:**
- Not applicable (Swift)
- `///` doc comments used sparingly on public API: `/// Runs xcrun simctl <args> on background queue; delivers result on main.`
- `///` used on computed properties with return semantics: `/// Number of currently connected clients`

## Function Design

**Size:**
- Functions kept focused — most under 30 lines
- Longer functions are sequential Combine chains (e.g., `setBoldText` in `EnvironmentOverrideService.swift` uses `flatMap` chains)

**Parameters:**
- `udid: String` is the most common parameter — passed to nearly all simctl-facing service methods
- Callback closures used for event handling: `onHeightChanged: (() -> Void)?`, `onFrameUpdate: ((CGRect) -> Void)?`
- Label-based navigation uses `@Binding var selectedTab: SideTab`

**Return Values:**
- Combine publishers: `AnyPublisher<String, SimCtlError>` from `SimCtlService.run()`
- `Void` convenience: `AnyPublisher<Void, SimCtlError>` from `SimCtlService.runVoid()`
- Fire-and-forget: methods that `sink` into `&cancellables` and return nothing
- `@Published private(set)` for read-only external state

## Module Design

**Exports:**
- No explicit export lists — standard Swift module visibility
- `@MainActor` isolation on all service classes restricts cross-actor access
- `nonisolated fileprivate static` used for background-queue-callable helpers (see `AXInspectorService`)

**Barrel Files:**
- None — no index files or re-export modules
- Each file is imported individually through the Xcode target membership

## MARK Section Convention

Every file follows this `MARK` structure (from `docs/code-standards.md`):

```swift
// MARK: - Properties
// MARK: - Lifecycle (init, deinit)
// MARK: - Public Methods
// MARK: - Private Methods
// MARK: - Extensions
```

Additional observed sections:
- `// MARK: - Published State` — at top of class, grouping all `@Published` properties
- `// MARK: - Constants` — static constants within a class
- `// MARK: - Types` — nested enums/structs (e.g., `CaptureService.ExportFormat`)
- `// MARK: - Helpers` — private utility methods

## Concurrency Patterns

- **No async/await** — project explicitly prohibits it per `docs/code-standards.md`
- `@MainActor` on all service/controller classes that touch UI or own AppKit objects
- Combine `@Published` + `Timer` for all asynchronous patterns
- `DispatchQueue.global(qos: .userInitiated)` for CPU-bound work (simctl process spawning, plist parsing)
- Results dispatched back to main via `DispatchQueue.main.async` or Combine's `.receive(on: DispatchQueue.main)`
- `[weak self]` in all Combine sinks and timer callbacks
- `final class` enforced — no inheritance-based concurrency boundaries

## View Patterns

- SwiftUI views are `struct` conforming to `View`
- State ownership: `@EnvironmentObject` for shared services, `@ObservedObject` for passed-in dependencies, `@State` for local view state only
- `@ViewBuilder` used for computed properties returning conditional view content (`tabContent` in `SideWindowView`)
- `Group` used for conditional top-level view switching with transitions
- `withAnimation` wraps all state mutations that drive visual changes
- Reduce Motion respected everywhere: ternary `reduceMotion ? .linear(duration: 0.1) : .spring(response: ..., dampingFraction: ...)`
- `#Preview` macro for SwiftUI previews — constructs full dependency graph inline
- `.buttonStyle(.plain)` on interactive containers using `.contentShape(Rectangle())`
- `Spacer()` for flexible layout, `Frame` with `DesignTokens` constants for fixed dimensions

## Dependency Injection

- **Constructor injection:** Services receive dependencies via `init` parameters
- **AppDelegate** is the composition root — creates all services and wires them into `SideWindowController`
- **EnvironmentObject injection:** Services passed down through SwiftUI environment via `.environmentObject()`
- **No DI framework** — manual wiring in `AppDelegate.init` and `SideWindowController.embedSwiftUIContent()`

---

*Convention analysis: 2026-08-29*