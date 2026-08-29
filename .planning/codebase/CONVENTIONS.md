# Coding Conventions

**Analysis Date:** 2026-08-29

## Language & Concurrency

- **Swift 6** with strict concurrency enabled; deployment target macOS 15 Sequoia
- **No async/await for service-layer patterns** — use Combine `@Published` + `Timer` per `docs/code-standards.md`. Exception: `CaptureService.swift` and `DeepLinkService.swift` use `async`/`await` because ScreenCaptureKit and `simctl openurl` APIs require it.
- `@MainActor final class` on all classes that touch UI or own AppKit objects (`AppDelegate`, `SideWindowController`, `CertificateService`, `ConnectService`, `CaptureService`, `SpringAnimator`)
- `final class` preferred over `class` for all services and controllers
- No `DispatchQueue.global()` for UI work — background `DispatchQueue.global()` used only for CPU-bound subprocess calls (AX inspection, xcrun simctl, file I/O) in `AXInspectorService.swift:39`, `SimCtlService.swift:37`, `CertificateStore.swift:26`, `CameraService.swift:52`, `SimulatorWindowTracker.swift:66`
- AXObserver callbacks use `CFRunLoopGetMain()` (fires on main thread)

## File Naming

- **PascalCase.swift** — file name matches primary type: `CertificateService.swift`, `SideWindowController.swift`
- Descriptive names: file purpose must be clear from name alone
- Target: files under 200 LOC; split by concern when approaching (see `CaptureService.swift` at 312 LOC as an overage)

## MARK Section Order

Every Swift file uses this MARK section order (from `docs/code-standards.md`):

```swift
// MARK: - Properties
// MARK: - Lifecycle (init, deinit)
// MARK: - Public Methods
// MARK: - Private Methods
// MARK: - Extensions
```

`private enum` types used for file-private helpers sit at top of file before the main class (`RetryAction` in `CertificateService.swift:6`, `DeviceInfo` in `SimulatorWindowTracker.swift:7`).

## Import Organization

- Framework imports first (`Foundation`, `AppKit`, `SwiftUI`, `Combine`, `OSLog`, `AVFoundation`, `Network`)
- No third-party imports (no SPM packages in app target)
- No blank line between imports
- Test files: `import Testing` (unit) or `import XCTest` (UI), then `@testable import BoosterSimApp`

## Class & Type Design

**Services (in `BoosterSimApp/Services/`):**
- All conform to `ObservableObject`; state via `@Published private(set) var` for read-only external access
- Combine `@Published` for observable state; `@AppStorage` for user-facing settings (in `AppSettings`)
- Services receive dependencies via `init` (e.g., `CertificateService(simCtl: SimCtlService)`)
- `AppDelegate` wires all services and passes them into `SideWindowController`

**Views (in `BoosterSimApp/Views/`):**
- `@ObservedObject` for injected services; `@EnvironmentObject` for services injected via SwiftUI environment
- `@State` for local view state only — never for shared state
- `@Binding` for parent-child state flow (e.g., `$selectedTab` in `TabBarView`)
- Services injected via `@EnvironmentObject` in views (see `SideWindowView.swift:22-28`)
- View services: `@EnvironmentObject var connectService: ConnectService` pattern

**Models (in `BoosterSimApp/Models/`):**
- Plain `struct` for data (`SimulatorWindow`, `BuildRecord`, `AXNode`, `AppSettings`)
- `enum` with associated values for state machines (`CertificateStatus`, `CertificateOperation`, `CertificateError`)
- Models with computed properties for derived data (e.g., `CertificateStatus.certificateMetadata`)

**Enums:**
- `CaseIterable` for tab/option enums (`SideTab`, `ExportFormat`, `CaptureQuality`, `DeviceBezel`)
- `RawRepresentable` with `String` raw value when persistence needed (`SideWindowPosition`)
- Methods on enums for state transitions (`CertificateOperation.canTransition(to:)`)

## Error Handling

- `do/catch` for all throwing APIs — never `try!` (prohibited by `docs/code-standards.md`)
- Exception: `as!` force-casts in `WindowObserver.swift:138-140` and `AXInspectorService.swift:95` for AXValue bridging (CoreFoundation interop requires it)
- `LocalizedError` conformance on domain error enums (`CertificateError` in `CertificateModels.swift`)
- Permission failures are non-fatal: log and continue with degraded state
- Error string pattern: `AppLogger.{category}.error("[ClassName] description: \(error)")`

## Logging

- **Centralized via `AppLogger`** (`BoosterSimApp/Utilities/AppLogger.swift`)
- Subsystem: `com.nextlabs.BoosterSimApp`
- Categories: `windowTracking`, `permissions`, `settings`, `certificates`
- Framework: `os.Logger` (OSLog)
- Log levels: `.debug` (state changes), `.info` (lifecycle), `.warning` (recoverable), `.error` (crashes)
- Prefix with service name: `AppLogger.windowTracking.debug("[SimulatorWindowTracker] detected window: \(pid)")`
- Never log sensitive data (UDIDs, file paths, tokens)

## Memory Management

- `[weak self]` in all Combine sinks and Timer callbacks (see `SideWindowController.swift:85-89`, `AppDelegate.swift:68-73`)
- AXObserver refcon: balance `passRetained` with `release()` in `stopObserving()`
- NSPanel: `isReleasedWhenClosed = false` — controller owns lifecycle

## Design Tokens

Never hardcode layout values. Use constants from `BoosterSimApp/Utilities/DesignTokens.swift`:

- **Spacing:** `Spacing.xxs` (2pt) through `Spacing.xxl` (24pt) on 4pt grid
- **Corner radii:** `CornerRadius.small` (4pt) through `CornerRadius.panel` (10pt)
- **Window dimensions:** `SideWindowMetrics.expandedWidth` (260pt), `SideWindowMetrics.headerHeight` (36pt), etc.
- **Onboarding:** `OnboardingMetrics.width` (480pt), `OnboardingMetrics.height` (520pt)

**Known deviation:** A few views use raw numeric values (`.padding(8)`, `.padding(12)`, `.cornerRadius(6)`) in `CaptureTabView.swift:96,109,114`, `DeepLinkSectionView.swift:49,83,131`, `DesignComparisonView.swift:222`. These should use `Spacing.sm`, `Spacing.md`, `CornerRadius.medium` respectively.

## Color & Theming

- Accent: amber/orange — `Color.accentColor` (asset catalog named `AccentColor`)
- Use semantic SwiftUI colors: `.primary`, `.secondary`, `.windowBackgroundColor`, `.separator`
- Never hardcode hex colors — zero instances found in Views
- Support light and dark mode via semantic colors

## Typography & Icons

- **SF Pro exclusively** via `.font(.system(...))` or semantic sizes (`.caption`, `.caption2`, `.body`, `.subheadline`, `.headline`)
- **SF Symbols exclusively** via `Image(systemName:)` and `Label(_, systemImage:)`
- Filled variants for active/selected states, outlined for inactive
- No custom fonts or third-party icon sets

## View Composition

- Small, focused SwiftUI views — extract when `body` exceeds ~40 lines
- `private` sub-view functions within same file for non-reused components (e.g., `TabBarView.tabButton(_:)`, `TabBarView.collapseButton`)
- Shared atoms in `BoosterSimApp/Views/Shared/`: `AccentButton.swift`, `StatusBadge.swift`, `CollapsibleSection.swift`
- `#Preview` macro at bottom of view files for Xcode canvas previews
- `@ViewBuilder` for conditional content switching (`SideWindowView.tabContent`)
- `.buttonStyle(.plain)` on all custom-styled buttons
- `.contentShape(Rectangle())` to expand tap targets on HStack rows

## Accessibility

- `.accessibilityLabel` on all icon-only buttons (e.g., `TabBarView.collapseButton`, `TabBarView.tabButton`)
- `.accessibilityAddTraits(.isSelected)` for selected tab state
- `.help()` tooltip on tab buttons and controls
- `@Environment(\.accessibilityReduceMotion)` checked in `TabBarView.swift:24`, `SideWindowView.swift:33`, `FeatureRowView.swift:15`
- Reduce Motion: shorten animation to 0.1s linear (vs spring/0.2-0.3s normally)
- `Label(title, systemImage:)` preferred over bare `Image` where applicable

## Shell Commands

- All `xcrun simctl` calls routed through `SimCtlService` (`BoosterSimApp/Services/SimCtlService.swift`)
- Never spawn subprocesses directly — always use `SimCtlService.spawn()`
- UDID may be nil without Screen Recording permission — check before calling
- Parse output as String or JSON; handle non-zero exit codes gracefully

## State Management

- **Services:** Combine `@Published` for observable state
- **Persistence:** `@AppStorage` for all user-facing settings (`BoosterSimApp/Models/AppSettings.swift`)
- **Views:** `@ObservedObject` / `@EnvironmentObject` — no `@StateObject` in non-owning views
- **No `@State` for shared state** — lift to ObservableObject services
- Combine pipelines: `.receive(on: DispatchQueue.main)` + `.sink { [weak self] ... }.store(in: &cancellables)`

## Comments

- Single-line comment at top of file: `// FileName.swift — Purpose description`
- MARK comments for section organization (see MARK order above)
- No JSDoc/TSDoc equivalents — Swift documentation comments (`///`) used sparingly (only on public computed properties like `CertificateStatus.certificateMetadata`)
- Inline `// swiftlint:disable:this force_cast` when force-cast is unavoidable (`AXInspectorService.swift:95`)

## File Header Comment

Every file starts with a single-line purpose comment:
```swift
// SideWindowController.swift — Manages SideWindowPanel lifecycle, position sync, and collapse state
// PulseServer.swift — NWListener TCP server for Pulse protocol connections
```

## Formatting

- 4-space indentation (Xcode default)
- No external formatter or linter configured (no `.swiftlint.yml`, no `.swiftformat`, no `.editorconfig`)
- Code style enforced via Xcode defaults and `docs/code-standards.md` conventions
- Trailing closures preferred for single-closure APIs

## Prohibited Patterns (from docs/code-standards.md)

- No sandboxing bypass hacks
- No `DispatchQueue.global()` for UI work
- No `@unchecked Sendable` without explicit justification
- No hardcoded strings for localized text (prepare for future l10n)
- No `try!` or `as!` force-casts on user data (AXValue bridging is the sole exception)
- No direct subprocess spawning — use `SimCtlService`
- No raw `UserDefaults` in views — use `@AppStorage` via `AppSettings`

---

*Convention analysis: 2026-08-29*
