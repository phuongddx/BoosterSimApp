# Code Standards

## Language & Runtime

- **Swift 6** with strict concurrency enabled (no `@unchecked Sendable` shortcuts)
- **Minimum deployment:** macOS 15 Sequoia
- **Xcode 16.3+** required
- No async/await — use Combine `@Published` + Timer for async patterns

## File Naming

- **PascalCase.swift** per Swift convention (e.g., `SideWindowController.swift`)
- File name matches the primary type declared inside
- Descriptive names — file purpose must be clear from the name alone

## File Size

- Keep files under 200 LOC
- Split by logical concern when approaching the limit:
  - Extract utilities into separate files
  - Split large views into sub-view components
  - Move business logic out of views into services

## MARK Structure

Every file uses MARK sections in this order:

```swift
// MARK: - Imports (at top, no MARK needed)

// MARK: - Properties
// MARK: - Lifecycle (init, deinit, viewDidLoad, etc.)
// MARK: - Public Methods
// MARK: - Private Methods
// MARK: - Extensions
```

## Concurrency

- `@MainActor` on all classes that touch UI or own AppKit objects
- `AppDelegate` and `SideWindowController` are explicit `@MainActor final class`
- Combine sinks and Timer callbacks must dispatch to `.main` queue
- AXObserver callbacks use `CFRunLoopGetMain()` (fires on main thread)
- `final class` preferred over `class` for services and controllers

## State Management

- **Services:** Combine `@Published` for observable state (`SimulatorWindowTracker`, `SideWindowController`)
- **Persistence:** `@AppStorage` for all user-facing settings (no raw `UserDefaults` in views)
- **View state:** `@ObservedObject` / `@EnvironmentObject` — no `@StateObject` in non-owning views
- **No `@State` for shared state** — lift state to ObservableObject services

## Design Tokens

Never hardcode layout values. Always use the constants from `Utilities/DesignTokens.swift`:

```swift
// Spacing (4pt grid)
Spacing.xxs  // 2pt
Spacing.xs   // 4pt
Spacing.sm   // 8pt
Spacing.md   // 12pt
Spacing.lg   // 16pt
Spacing.xl   // 20pt
Spacing.xxl  // 24pt

// Corner radii
CornerRadius.small    // 4pt
CornerRadius.medium   // 6pt
CornerRadius.large    // 8pt
CornerRadius.panel    // 10pt

// Side window
SideWindowMetrics.expandedWidth   // 260pt
SideWindowMetrics.collapsedWidth  // 28pt
SideWindowMetrics.minHeight       // 400pt
SideWindowMetrics.rowHeight       // 32pt
SideWindowMetrics.titleBarHeight  // 28pt

// Onboarding
OnboardingMetrics.width   // 480pt
OnboardingMetrics.height  // 520pt
```

## Color & Theming

- **Accent:** Amber/orange — `#E8720C` (light), `#F59E0B` (dark)
- Use semantic colors (`.primary`, `.secondary`, `.windowBackgroundColor`) for adaptive appearance
- Never hardcode hex colors — use asset catalog named colors or `Color(.named)` references
- Support both light and dark mode

## Typography & Icons

- **Font:** SF Pro exclusively via `.font(.system(...))` or semantic sizes (`.caption`, `.body`, `.headline`)
- **Icons:** SF Symbols exclusively via `Image(systemName:)` and `Label(_, systemImage:)`
- No custom fonts or third-party icon sets

## View Composition

- Prefer small, focused SwiftUI views over large monolithic view bodies
- Extract sub-views when a `body` exceeds ~40 lines
- Use `private` sub-view types within the same file when the component is not reused
- Shared atoms go in `Views/Shared/` (e.g., `AccentButton`, `StatusBadge`)

## Error Handling

- Use `try/catch` for all throwing APIs; log errors with a `[ClassName]` prefix
- Never use `try!` — handle or propagate gracefully
- Permission failures are non-fatal; log and continue with degraded state

```swift
// Correct
do {
    try SMAppService.mainApp.register()
} catch {
    print("[AppSettings] Launch at login error: \(error)")
}
```

## Logging

- Use `AppLogger` (centralized in `Utilities/AppLogger.swift`) for all service logging; subsystem `com.nextlabs.BoosterSimApp`
- Log levels: `.debug` (state changes), `.info` (lifecycle), `.warning` (recoverable errors), `.error` (crashes)
- Prefix with service name: `AppLogger.windowTracking.debug("[SimulatorWindowTracker] detected new window: \(pid)")`
- Never log sensitive data (UDIDs, file paths, user tokens)

## Memory Management

- Use `[weak self]` in all Combine sinks and Timer callbacks
- AXObserver refcon pointer: balance `passRetained` with `release()` in `stopObserving()`
- NSPanel: `isReleasedWhenClosed = false` — controller owns lifecycle

## Accessibility

- Always set `accessibilityLabel` on icon-only buttons
- Respect `NSWorkspace.shared.accessibilityDisplayShouldReduceMotion` — shorten animation duration to 0.1s when true
- Use semantic `Label(title, systemImage:)` over bare `Image` wherever possible

## Shell Commands (xcrun simctl)

- All `xcrun simctl` commands routed through `SimCtlService`
- Never spawn subprocesses directly — always use `SimCtlService.spawn()` with UDID
- Check for UDID availability before calling simctl (may be nil without Screen Recording permission)
- Parse output as String or JSON; handle non-zero exit codes gracefully

## Tab Navigation Pattern

Side panel uses tab-based navigation via `SideTab` enum:

- `SideTab` enum: `capture`, `design`, `actions`, `network` — each defines icon + label
- `TabBarView` renders icon-only tab buttons with amber underline for selected state
- `SideWindowView` routes tab selection to appropriate content view via `switch selectedTab`
- Tab switch animates with spring (response: 0.25, damping: 0.8); linear 0.1s with Reduce Motion
- Content views are tab-agnostic; views own their state (e.g., `CertificateSectionView` in Actions tab)

## Prohibited Patterns

- No sandboxing bypass hacks
- No `DispatchQueue.global()` for UI work
- No `@unchecked Sendable` without explicit justification
- No hardcoded strings for localized text (prepare for future l10n)
- No `try!` or `as!` force-casts on user data
- No direct subprocess spawning — use `SimCtlService`
