# Coding Conventions

**Analysis Date:** 2026-03-25

## Naming Patterns

**Files:**
- PascalCase with `.swift` extension (Swift convention)
- Example: `AppDelegate.swift`, `SimulatorWindowTracker.swift`, `AccentButton.swift`
- Descriptive names that indicate purpose/class name immediately
- No abbreviations in most filenames (full names preferred: `PermissionManager` not `PermMgr`)

**Functions:**
- camelCase, action-based for public methods
- Example: `startTracking()`, `checkAccessibility()`, `attachToSimulator()`
- Private methods use camelCase with leading underscore style avoided; marked `private`
- Example in `WindowObserver`: `registerWindowNotifications()`, `readWindowFrame()`, `handleNotification()`

**Variables:**
- camelCase throughout
- Clear, semantic names: `activeSimulator`, `currentSimulator`, `isVisible`, `isCollapsed`
- Boolean properties prefixed with `is` or use past tense: `isOnScreen`, `isMinimized`, `isAccessibilityGranted`
- Published properties prefix with `@Published`: `@Published var simulators: [SimulatorWindow]`
- Storage properties prefixed with underscore in some cases: `@Published private(set) var simulators`

**Types:**
- PascalCase for all types (classes, structs, enums)
- Example: `SimulatorWindowTracker`, `AppSettings`, `PermissionManager`
- Enum cases use camelCase
- Example in `SimulatorDeviceType`: `case iOS, watchOS, tvOS, visionOS`
- Example in `SideWindowPosition`: `case left, right, bottom, dynamic`

## Code Style

**Formatting:**
- 4-space indentation (Swift standard)
- No linting configuration detected (`.swiftformat`, `.swiftlint` not present)
- Blank line between logical sections within methods
- Method parameters on separate lines when multiple
- Example in `SideWindowController.init()` — 9 parameters across lines

**Concurrency Model (Swift 6 Strict):**
- **@MainActor required on UI/AppKit classes:**
  - `AppDelegate` — `@MainActor final class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject`
  - `SideWindowController` — implicitly main-thread only (manages NSPanel)
  - `SpringAnimator` — `@MainActor final class SpringAnimator` (CADisplayLink requires main thread)
  - `BuildStatsService` — `@MainActor final class BuildStatsService: ObservableObject`
- **Non-MainActor classes for background work:**
  - `SimulatorWindowTracker` — not @MainActor; performs background process (`xcrun simctl list`)
  - `PermissionManager` — not @MainActor; runs checks on main thread but inits without constraint
  - `WindowObserver` — not @MainActor; handles AXObserver callbacks
- **No async/await used** — project uses Combine `@Published` + Timer polling instead
- DispatchQueue.main.async for main-thread hops: See `SimulatorWindowTracker.refreshDeviceTypeCache()` line 56–92
- Weak self capture pattern: `[weak self]` in all closures to prevent retain cycles
- Example: `tracker.$activeSimulator.receive(on: DispatchQueue.main).sink { [weak self] sim in`

**Combine Patterns:**
- Services inherit `ObservableObject` and use `@Published` for state
- Example: `SimulatorWindowTracker: ObservableObject` with `@Published private(set) var simulators`
- Read-only published state uses `private(set)`: `@Published private(set) var simulators: [SimulatorWindow] = []`
- Subscribers use `.sink()` with weak self: Stored in `Set<AnyCancellable>` property
- Example in `AppDelegate.applicationDidFinishLaunching()` lines 53–64 and 67–73
- Timer polling: `Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in ... }`

**AppStorage for Persistence:**
- `@AppStorage` used for persistent user settings in `AppSettings` class
- Example: `@AppStorage("sideWindowPosition") var position: SideWindowPosition = .dynamic`
- Enums backing AppStorage must conform to `RawRepresentable` (typically `.String` case iterable enum)
- Example in `AppSettings`: `enum SideWindowPosition: String, CaseIterable`

## MARK Sections

**Required Structure (observed pattern):**
All files follow this ordering:

1. **// Comment line** — One-line file purpose at top
2. **Imports** — All imports grouped (no blank lines between related imports)
3. **MARK: - [Top-level Model/Constants]** — Enums, typealiases, private structs (if any)
4. **MARK: - [Class/Struct Name]** — Class/struct definition opens
5. **MARK: - Published State** — @Published properties (first in ObservableObject classes)
6. **MARK: - Private** — Private properties and stored state
7. **MARK: - Init** — Initializer(s)
8. **MARK: - Public API** — Public methods (feature-grouped if large class)
9. **MARK: - Public Methods (feature name)** — e.g., "MARK: - Accessibility", "MARK: - Tracker Integration"
10. **MARK: - Private [Feature Name]** — Private helper methods for a feature
11. **MARK: - Lifecycle** or **MARK: - NSApplicationDelegate** — Protocol methods
12. **Extensions** — Separate extension blocks at EOF with `extension ClassName { ... }`

**Example from AppDelegate.swift:**
```
MARK: - Core Services
MARK: - Feature Services
MARK: - Windows
MARK: - Private
MARK: - NSApplicationDelegate
MARK: - Onboarding Window
```

**Example from SimulatorWindowTracker.swift:**
```
MARK: - Device Info Cache Entry
MARK: - Tracker
MARK: - Published State
MARK: - Private
MARK: - Public API
MARK: - Device Classification
MARK: - Scanning
MARK: - Polling Fallback
MARK: - Workspace Notifications
```

## Import Organization

**Order (observed):**
1. `import AppKit` / `import SwiftUI` (platform frameworks first)
2. `import Combine` (Apple frameworks in alphabetical order)
3. `import CoreGraphics` / `import ApplicationServices` / `import UniformTypeIdentifiers` / etc.
4. `import ServiceManagement` (last if present)

**No aliases or conditional imports observed**

**Path Aliases:**
- Not used in this project (no package manager, no Xcode path mappings configured)
- All imports are standard Apple frameworks

## Error Handling

**Pattern: Guard-let with early return**
- Used throughout for optional unwrapping
- Example in `WindowEnumerator.parseSimulatorWindow()` lines 23–54:
```swift
guard let ownerName = info[kCGWindowOwnerName as String] as? String,
      ownerName == "Simulator" else { return nil }
```

**Pattern: Silent failure (no throws)**
- Most parsing/enumeration methods return optional types instead of throwing
- `WindowEnumerator.parseSimulatorWindow()` returns `SimulatorWindow?` (nil on parse failure)
- `WindowObserver.readWindowFrame()` returns `CGRect?` (nil if AX read fails)
- No custom Error types defined; no try/catch blocks observed

**Pattern: Logged errors (print + continue)**
- Low-level failures logged to console, execution continues
- Example in `WindowObserver.startObserving()` lines 51–52:
```swift
guard result == .success, let obs = observer else {
    print("[WindowObserver] Failed to create AXObserver for PID \(pid): \(result.rawValue)")
    return
}
```
- Example in `AppSettings.setLaunchAtLogin()` line 49:
```swift
} catch {
    print("[AppSettings] Launch at login error: \(error)")
}
```

**Pattern: Assertions for invariants**
- Not heavily used; code relies on early returns and guards instead
- No assertionFailure() or precondition() calls observed in analyzed files

**Safe memory management (AX/C APIs):**
- `Unmanaged.passRetained()` + `.release()` pattern used for AX callbacks
- Example in `WindowObserver` lines 57 and 82:
```swift
selfPtr = Unmanaged.passRetained(self).toOpaque()
...
Unmanaged<WindowObserver>.fromOpaque(ptr).release()
```
- Careful frame conversion between Quartz (Y=top) and AppKit (Y=bottom) coordinates documented
- Example: `WindowEnumerator.parseSimulatorWindow()` line 44 computes `appKitY = primaryHeight - quartzY - height`

## Comments

**When to Comment:**
- Complex coordinate system conversions
  - Example in `WindowEnumerator` line 34: "// kCGWindowBounds is a CFDictionary in Quartz space..."
  - Example in `WindowObserver` line 136: "// Flip Y: Quartz counts from top..."
- Low-level system API usage (AX, CGWindow, etc.)
  - Example in `WindowObserver` line 18: "// Lifecycle notifications — registered on the app element"
- Non-obvious design decisions
  - Example in `SpringAnimator` line 82: "// Spring force: F = -k * displacement - c * velocity"
- Temporal state caching explanations
  - Example in `SimulatorWindowTracker` line 29: "// Device info cache: device name → (type, UDID)"

**When NOT to Comment:**
- Straightforward property declarations
- Self-explanatory method names (e.g., `startTracking()` doesn't need comment)
- Loop logic (for-in, map, filter)

**Header comments (file-level):**
- Single-line purpose comment at top of every file
- Example: `// BoosterSimAppApp.swift — @main SwiftUI App entry point`
- Example: `// AppDelegate.swift — NSApplicationDelegate hosting all AppKit services`
- Additional one-liner for key design note if needed
- Example: `// WindowObserver.swift — Wraps AXObserver to get real-time window move/resize events`

**No JSDoc/TSDoc observed** — Swift comments are minimal, focused on "why" not "what"

## Function Design

**Size Guidelines:**
- Observed functions under 30 lines (most under 20)
- Example: `SideWindowController.updatePosition()` is 26 lines (calculation-heavy)
- Example: `PermissionManager.checkAccessibility()` is 1 line
- Larger methods (50+ lines) split using MARK sections for logical blocks
- Example: `SimulatorWindowTracker.refreshDeviceTypeCache()` is 38 lines but clearly separated: setup → process → cache update → main thread sync

**Parameter Guidelines:**
- Max 5 parameters before wrapping to multiple lines
- Example: `SideWindowController.init()` has 7 parameters, each on own line (lines 32–40)
- Callback/closure parameters placed last
- Example: `WindowObserver.startObserving(callback: @escaping (String, AXUIElement) -> Void)`

**Return Values:**
- Optionals used for "may not exist" results: `SimulatorWindow?`, `CGRect?`
- Published properties for state: `@Published var activeSimulator: SimulatorWindow?`
- Void implied for actions: `func toggleCollapsed()`
- Array returns with empty default: `enumerateSimulatorWindows() -> [SimulatorWindow]` returns `[]` on failure

## Module Design

**Exports:**
- All public types are top-level in their files (no nested structs in separate files)
- Internal/private types nested only when single-use
- Example: `DeviceInfo` struct nested in `SimulatorWindowTracker` file (private)
- Example: `PanelSide` enum nested in `SideWindowController` (private, computation helper)

**Barrel Files:**
- Not used; no `__init__.swift` or re-export pattern observed
- Each service/view imported directly: `import BoosterSimApp` then `SimulatorWindowTracker()`

**Service Injection:**
- Constructor injection for dependencies
- Example: `SideWindowController.init(settings:, tracker:, statusBarService:, ...)`
- Services stored as properties, not singletons
- Example: `AppDelegate` creates all services and passes them down

**EnvironmentObject pattern for SwiftUI:**
- Services injected via `.environmentObject()` in view hierarchy
- Example in `SideWindowController.embedSwiftUIContent()` lines 163–167:
```swift
.environmentObject(statusBarService)
.environmentObject(envOverrideService)
```
- Views read via `@EnvironmentObject var serviceName: ServiceType`

## DesignTokens Usage (Critical)

**All layout values come from `Utilities/DesignTokens.swift`:**
- **Never hardcode** spacing, corner radius, or dimensions
- Use enum static properties only

**Spacing (4pt grid):**
```swift
Spacing.xxs    // 2
Spacing.xs     // 4
Spacing.sm     // 8
Spacing.md     // 12
Spacing.lg     // 16
Spacing.xl     // 20
Spacing.xxl    // 24
```

**Corner Radius:**
```swift
CornerRadius.small      // 4
CornerRadius.medium     // 6
CornerRadius.large      // 8
CornerRadius.panel      // 10
CornerRadius.onboarding // 12
```

**Dimensions:**
```swift
SideWindowMetrics.expandedWidth  // 260
SideWindowMetrics.collapsedWidth // 28
SideWindowMetrics.minHeight      // 400
SideWindowMetrics.rowHeight      // 32

OnboardingMetrics.width  // 480
OnboardingMetrics.height // 520

PreferencesMetrics.width  // 500
PreferencesMetrics.height // 380
```

**Color:**
- Accent color: `Color.accentColor` (maps to asset `AccentColor`, defined as #E8720C light / #F59E0B dark)
- Never hardcode hex colors
- Text colors use semantic names: `.foregroundStyle(.primary)`, `.foregroundStyle(.secondary)`, `.foregroundStyle(.tertiary)`
- Example in `AccentButton.swift` line 14: `.foregroundStyle(.white)` (only for white text on colored bg)
- Example in `SideWindowView.swift` line 156: `.foregroundStyle(.secondary)` (for secondary text)

**Typography:**
- SF Pro + SF Symbols exclusively
- Font sizes via `.font()` modifier: `.font(.body)`, `.font(.subheadline)`, `.font(.caption)`
- FontWeights via `.fontWeight()`: `.fontWeight(.medium)`, `.fontWeight(.semibold)`
- Example in `AccentButton.swift` lines 12–13:
```swift
.font(.body)
.fontWeight(.medium)
```

---

*Convention analysis: 2026-03-25*
