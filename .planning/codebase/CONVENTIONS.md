# Coding Conventions

**Analysis Date:** 2026-08-31

Authoritative source: `docs/code-standards.md` (team-authored). Where the doc and build settings diverge, this document reports the actual `BoosterSimApp.xcodeproj/project.pbxproj` values observed.

## Language Mode & Runtime

- **Language mode:** `SWIFT_VERSION = 5.0` with `SWIFT_APPROACHABLE_CONCURRENCY = YES` and `SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY = YES` (all targets, `BoosterSimApp.xcodeproj/project.pbxproj`). Note: `docs/code-standards.md` describes this as "Swift 6 strict concurrency"; the project is on the Swift 6 migration path (approachable concurrency), not the literal Swift 6 language mode.
- **Default actor isolation:** `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` is set on the **app target** (`BoosterSimApp`) — types are `@MainActor` by default there; opt out with `nonisolated` where needed. The test targets use approachable concurrency without default MainActor isolation, so tests that touch services carry explicit `@MainActor`.
- **Deployment target:** `MACOSX_DEPLOYMENT_TARGET = 26.2` (all app-side configurations). `docs/code-standards.md` still says macOS 15 — the pbxproj is ground truth.
- **No async/await in general code** — use Combine `@Published` + publishers. The single sanctioned exception is the ScreenCaptureKit bridge pattern (sync public API → one private `Task {}` → TCC preflight), used only by `BoosterSimApp/Services/CaptureService.swift` and `BoosterSimApp/Services/PixelSamplerService.swift`.
- **No SwiftLint/SwiftFormat** — no `.swiftlint.yml`/`.swiftformat` exists; style is enforced by convention and code review, not tooling.

## Naming Patterns

**Files:**
- `PascalCase.swift`, file name matches its primary type (e.g., `BoosterSimApp/Windows/SideWindowController.swift`).
- File-purpose header comment as line 1: `// FileName.swift — one-line purpose` (e.g., `BoosterSimApp/Models/BlockRule.swift`, `BoosterSimAppTests/RulerMathTests.swift`). Used across ~33 service files; a few older files (`BoosterSimApp/Services/CertificateService.swift`) omit it — new files MUST include it.
- Concern-split extensions use `+` suffix: `BoosterSimApp/Services/DesignOverlayService+Import.swift`, `BoosterSimApp/Services/DesignOverlayService+Presets.swift`, `BoosterSimApp/Windows/DesignOverlayController+InputMode.swift`.

**Types:**
- `PascalCase` for all types; `final class` for services/controllers/observable objects (never bare `class`).
- Caseless `enum`s as namespaces for constants: `AppLogger` (`BoosterSimApp/Utilities/AppLogger.swift`), `Spacing`/`CornerRadius`/`SideWindowMetrics`/`OverlayMetrics` (`BoosterSimApp/Utilities/DesignTokens.swift`), `SimCtlLimits` (`BoosterSimApp/Services/SimCtlService.swift`).
- Test doubles: `*Double` (`ScriptedSimCtlDouble`, `KeychainResetDouble`) or `Noop*` (`NoopCommandBroadcast`).
- Seam protocols end in `-ing`: `SimCtlRunning`, `CommandBroadcasting`, `AppKeychainResetting`, `TouchPreferencesStore`.

**Functions/Variables:**
- `camelCase` everywhere; services are `@MainActor final class` + `ObservableObject`.
- Pure builders/parsers are `static func` on the service, named for what they return/build: `AppActionService.terminateCommand(udid:bundleID:)`, `AppActionService.parseInstalledApps(fromListAppsXML:)` (`BoosterSimApp/Services/AppActionService.swift`).

**Tests:**
- Test types: `struct XTests` (Swift Testing, not classes). Method names are full sentences describing the contract: `runRejectsStdinOverThePipeBoundWithTheTypedException` (`BoosterSimAppTests/SimCtlServiceTests.swift`), `legacyPayloadImportsOnceIntoVersionedKey` (`BoosterSimAppTests/OverlayPersistenceTests.swift`).

## MARK Structure

Every file orders sections exactly like this (from `BoosterSimApp/Services/SimCtlService.swift`):

```swift
// FileName.swift — one-line purpose

// MARK: - Error        (or other top-level groupings: Pipe Drain, Service)
// MARK: - Properties
// MARK: - Lifecycle
// MARK: - Public Methods
// MARK: - Private
// MARK: - Extensions
```

- `// MARK: - Properties` before stored properties; `// MARK: - Public Methods` / `// MARK: - Private` split the API surface.
- Test files use `// MARK: -` to group behaviors: `// MARK: - Airplane Persistence`, `// MARK: - Fixtures` (`BoosterSimAppTests/NetworkConditionServiceTests.swift`, `BoosterSimAppTests/OverlayPersistenceTests.swift`).
- `struct`/`class` declaration follows an `// MARK: - Service`-style banner when preceded by helper types in the same file.
- Violations exist in older files (`CertificateSectionView.swift` has zero MARKs) — match MARK structure in new code.

## File Size

- Target under 200 LOC per file (`docs/code-standards.md`); split by concern via `+` extension files, sub-view extraction, or moving logic into services.
- SwiftUI `body` over ~40 lines gets extracted into `private var` sub-views or `@ViewBuilder private func`s (see `BoosterSimApp/Views/SideWindow/CertificateSectionView.swift` — `statusRow`, `detailsRow(_:)`, `helperBanner(_:icon:dismissible:)`).

## Code Style

**Formatting:**
- Xcode defaults: 4-space indent, braces on same line. Binary operators spaced (`lock.lock(); defer { lock.unlock() }` seen in `SimCtlService.swift`).
- Space around range/`..` operators in newer code: `0 ..< 50` (`BoosterSimAppTests/ScriptedSimCtl.swift`).

**Concurrency:**
- `@MainActor` explicitly on all services/controllers that own AppKit objects (`SimCtlService`, `SideWindowController`, `AppDelegate`) — redundant on the app target now but kept for clarity.
- All UI work on main; Combine sinks deliver via `.receive(on: main)` or explicit `DispatchQueue.main.async` in promise resolution (`SimCtlService.drainAndComplete`).
- `[weak self]` in every Combine sink and Timer callback.
- `isReleasedWhenClosed = false` on all `NSPanel`s; controller owns panel lifecycle (`BoosterSimApp/Windows/SideWindowPanel.swift`).
- AXObserver refcon: balance `passRetained` with `release()` in `stopObserving()`.

## Import Organization

**Order:**
1. Foundation (or AppKit/SwiftUI as the platform base)
2. Combine / OSLog / framework imports as needed
3. `@testable import BoosterSimApp` (tests only, always last)

Example: `BoosterSimApp/Services/SimCtlService.swift` → `Foundation`, `Combine`. `BoosterSimAppTests/RulerMathTests.swift` → `Foundation`, `CoreGraphics`, `Testing`, `@testable import BoosterSimApp`.

**Path Aliases:** None. Single Xcode project; `BoosterSimConnect/` is an iOS-Simulator framework target in the same project, `booster-sim-cli/` a separate SPM package.

## Error Handling

**Patterns:**
- One typed `Error` enum per service, conforming to `LocalizedError` with a `switch`-based `errorDescription`: `SimCtlError` (`BoosterSimApp/Services/SimCtlService.swift`) with cases `.commandFailed`, `.xcrunNotFound`, `.timeout`, `.stdinTooLarge(Int)`.
- Services expose results as Combine publishers (`AnyPublisher<String, SimCtlError>`); failures delivered via `Fail(error:)`, never thrown synchronously — except guard-style preconditions, which return `Fail` before spawning work (stdin bound check in `SimCtlService.run`).
- `try/catch` for throwing APIs, logged with a `[ClassName]` prefix; **never `try!` or `as!` on user data**; permission failures degrade gracefully (log + continue) — see `BoosterSimApp/Services/PermissionManager.swift`.
- Corrupted persisted payloads decode into tolerant all-optional shapes and degrade to empty state, never trap (`BoosterSimApp/Services/DesignOverlayService.swift`, verified by `BoosterSimAppTests/OverlayPersistenceTests.swift` "garbage under key" tests).

## Logging

**Framework:** `AppLogger` (`BoosterSimApp/Utilities/AppLogger.swift`) — caseless enum exposing per-category `os.Logger` instances under subsystem `com.nextlabs.BoosterSimApp`: `windowTracking`, `permissions`, `settings`, `certificates`, `network`, `capture`, `actions`, `design`.

**Patterns:**
- `AppLogger.<category>.<level>("[TypeName] message")` — levels: `.debug` state changes, `.info` lifecycle, `.warning` recoverable, `.error` crashes.
- Never log UDIDs, file paths, or user tokens.
- A few `print("[SimCtl] …")` traces remain in `BoosterSimApp/Services/SimCtlService.swift` — new code uses `AppLogger`.

## State Management

- **Services:** Combine `@Published` for observable state (`SimulatorWindowTracker`, `SideWindowController`, `NetworkConditionService`).
- **Persistence:** `@AppStorage` for all user-facing settings in views (e.g., `@AppStorage("certFirstUseHintDismissed")` in `BoosterSimApp/Views/SideWindow/CertificateSectionView.swift`); no raw `UserDefaults` in views.
- **View state:** `@State private` for local-only UI state (`isExpanded`, `showResetConfirm`); `@EnvironmentObject` for services; `@ObservedObject` in non-owning views; no `@State` for shared state — lift to services.
- **Schema changes to persisted keys:** version the key, import old payload once behind a flag via a tolerant all-optional decode; importing replaces, never appends (reference: `DesignOverlayService` importing legacy `DesignComparisonPresets`).
- Parent→child context passes as closures, not globals: `CertificateSectionView` takes `udidProvider: () -> String?` and `deviceNameProvider: () -> String`.

## Design Tokens

Never hardcode layout values — always use `BoosterSimApp/Utilities/DesignTokens.swift`:

```swift
Spacing.xxs /*2*/  Spacing.xs /*4*/  Spacing.sm /*8*/  Spacing.md /*12*/
Spacing.lg /*16*/  Spacing.xl /*20*/  Spacing.xxl /*24*/

CornerRadius.small /*4*/  CornerRadius.medium /*6*/  CornerRadius.large /*8*/
CornerRadius.panel /*10*/  CornerRadius.onboarding /*12*/

SideWindowMetrics.expandedWidth /*260*/  .collapsedWidth /*28*/  .rowHeight /*32*/
OnboardingMetrics.width /*480*/  .height /*520*/  .steps /*4*/
PreferencesMetrics.width /*500*/  OverlayMetrics.loupeDiameter /*96*/
```

Usage style (from `CertificateSectionView.swift`): `VStack(alignment: .leading, spacing: Spacing.sm)`, `.background(..., in: RoundedRectangle(cornerRadius: CornerRadius.small))`.

## View Conventions

- `struct X: View` with `private var` computed sub-views; `@ViewBuilder` for switch-based branches.
- `.buttonStyle(.plain)` for custom-styled buttons; `Label(_, systemImage:)` with SF Symbols only; semantic foreground styles (`.primary`/`.secondary`/`.tertiary`) — no hardcoded hex colors.
- Amber accent via `Color.accentColor`; light/dark adaptive.
- Reduce Motion: `@Environment(\.accessibilityReduceMotion)` → linear 0.1s animation, else spring/easeInOut 0.2s (pattern in `CertificateSectionView.animation` computed var).
- `accessibilityElement(children: .combine)` on composite status rows; `accessibilityLabel` required on icon-only buttons.
- Shared atoms in `BoosterSimApp/Views/Shared/` (`CollapsibleSection`, `StatusBadge`, `AccentButton`); per-tab sections in `BoosterSimApp/Views/SideWindow/<Tab>/`.
- Tab navigation via `SideTab` enum + `switch selectedTab` routing in `BoosterSimApp/Views/SideWindow/SideWindowView.swift`; content views are tab-agnostic.

## Shell Commands (xcrun simctl)

- ALL `xcrun simctl` invocations go through `SimCtlService` (`BoosterSimApp/Services/SimCtlService.swift`) — `run(args)` / `runVoid(args)`; no direct `Process` spawning anywhere else.
- Parse `simctl` output with pure static parsers (`AppActionService.parseInstalledApps`, `parseRunningApps`) so they are unit-testable without subprocesses.

## Comments

**When to Comment:**
- `///` doc comments on seam protocols and non-obvious invariants, citing review findings: `/// (03-REVIEW WR-03: bound enforced at the seam)` in `SimCtlService.swift`.
- One-line `// FileName.swift — purpose` headers state the file's single responsibility (e.g., `// RulerMathTests.swift — Y-flip/scale window-point→image-pixel mapping and distance math (no windows)`).
- Inline `//` explains WHY (deadlock fixes, gate ordering), never restates code.

## Function Design

**Size:** Small; view helpers return `some View` from computed properties.

**Parameters:** Closure providers for context injection (`udidProvider: () -> String?`); defaults for optional args (`run(_ args:, stdin: Data? = nil)`), with protocol-extension overloads so defaults survive existential witnesses (`extension SimCtlRunning { func run(_ args: [String]) }`).

**Return Values:** Combine `AnyPublisher<T, ServiceError>` for I/O; plain values/tuples for pure functions; state machines modeled as enums with `canTransition(to:)` (`NetworkConditionState`, `CertificateOperation`).

## Module Design

**Exports:** One primary type per file; helpers (`Once`, `PipeBuffer` in `SimCtlService.swift`) are `private final class` in the same file.

**Barrel Files:** None — imports are direct by file.

## Prohibited Patterns

From `docs/code-standards.md`, verified enforced:

- No direct subprocess spawning — always `SimCtlService`.
- No `DispatchQueue.global()` for UI work (background lanes only for pipe drains in `SimCtlService`).
- No `@unchecked Sendable`; no `try!`/`as!` on user data; no hardcoded layout values (use `DesignTokens`); no hardcoded hex colors; no custom fonts/icons (SF Pro + SF Symbols only); no sensitive data in logs.

---

*Convention analysis: 2026-08-31*
