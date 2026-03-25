# Codebase Structure

**Analysis Date:** 2026-03-25

## Directory Layout

```
BoosterSimApp/
├── BoosterSimApp/                    # Main source code
│   ├── BoosterSimAppApp.swift        # @main SwiftUI App entry point
│   ├── App/
│   │   └── AppDelegate.swift         # NSApplicationDelegate; owns all services
│   ├── Models/                       # Domain data structures
│   │   ├── SimulatorWindow.swift     # Detected window + device type
│   │   ├── AppSettings.swift         # @AppStorage-backed user settings
│   │   ├── AXNode.swift              # Accessibility tree node
│   │   └── BuildRecord.swift         # Build analytics event
│   ├── Services/                     # Business logic; owned by AppDelegate
│   │   ├── SimulatorWindowTracker.swift    # Core: Simulator detection (CGWindowList + AXObserver)
│   │   ├── WindowEnumerator.swift         # Low-level: CGWindowListCopyWindowInfo scan
│   │   ├── WindowObserver.swift           # Low-level: AXObserver per PID
│   │   ├── PermissionManager.swift        # System permissions (Accessibility, Screen Recording, Xcode)
│   │   ├── SimCtlService.swift            # Thin wrapper around xcrun simctl
│   │   ├── XcodeDetector.swift            # Xcode installation detection
│   │   ├── StatusBarService.swift         # Simulator status bar info
│   │   ├── EnvironmentOverrideService.swift  # Environment variable management
│   │   ├── BuildStatsService.swift        # Build analytics monitoring
│   │   ├── AXInspectorService.swift       # Accessibility tree inspection
│   │   └── CameraService.swift            # Camera availability detection
│   ├── Windows/                      # AppKit window management
│   │   ├── SideWindowPanel.swift     # NSPanel subclass (floating behavior)
│   │   ├── SideWindowController.swift # Manages panel lifecycle + position sync
│   │   ├── PositionCalculator.swift  # Pure frame math for positioning
│   │   └── AXHighlightPanel.swift    # Overlay panel for UI inspection
│   ├── Views/                        # SwiftUI presentation layer
│   │   ├── MenuBar/
│   │   │   └── MenuBarView.swift     # Menu bar icon + quick menu
│   │   ├── SideWindow/               # Main side panel views
│   │   │   ├── SideWindowView.swift  # Root view (embeds all sections)
│   │   │   ├── SideWindowTitleBar.swift
│   │   │   ├── DeviceHeaderView.swift
│   │   │   ├── StatusBarSectionView.swift
│   │   │   ├── BuildStatsSectionView.swift
│   │   │   ├── BuildChartView.swift
│   │   │   ├── EnvironmentOverridesView.swift
│   │   │   ├── AXTreeView.swift
│   │   │   ├── CameraView.swift
│   │   │   ├── FeatureSectionView.swift
│   │   │   ├── FeatureRowView.swift
│   │   │   ├── CollapsedStripView.swift
│   │   │   └── SideWindowFooter.swift
│   │   ├── Preferences/              # Settings window views
│   │   │   ├── PreferencesView.swift # Root (tabs)
│   │   │   ├── GeneralTab.swift
│   │   │   └── AboutTab.swift
│   │   ├── Onboarding/               # First-launch flow
│   │   │   ├── OnboardingContainerView.swift
│   │   │   ├── OnboardingStepView.swift
│   │   │   └── ProgressDotsView.swift
│   │   └── Shared/                   # Reusable components
│   │       ├── AccentButton.swift
│   │       └── StatusBadge.swift
│   ├── Utilities/                    # Constants + pure algorithms
│   │   ├── DesignTokens.swift        # Spacing, corner radii, metrics (all 4pt grid-aligned)
│   │   └── SpringAnimator.swift      # Spring physics engine for smooth transitions
│   └── Assets.xcassets/              # App icon, accent color
├── BoosterSimAppTests/               # Unit tests (placeholder)
├── BoosterSimAppUITests/             # UI tests (placeholder)
├── BoosterSimApp.xcodeproj/          # Xcode project
├── Info.plist                        # App configuration (LSUIElement = true)
└── README.md                         # Project overview

Plans & Documentation:
├── plans/                            # Implementation plans
│   ├── 0317-2302-boostersimapp-mvp/  # Active plan
│   └── reports/                      # Plan execution reports
├── docs/                             # Official documentation
│   ├── project-overview-pdr.md
│   ├── system-architecture.md
│   ├── codebase-summary.md
│   ├── code-standards.md
│   ├── design-guidelines.md
│   ├── project-roadmap.md
│   └── deployment-guide.md
└── .planning/codebase/               # GSD codebase analysis
    ├── ARCHITECTURE.md
    └── STRUCTURE.md
```

## Directory Purposes

**BoosterSimApp/BoosterSimApp/**
- Purpose: Main source code root
- Contains: All Swift source files organized by layer (Models, Services, Views, Windows, Utilities, App)
- Key files: BoosterSimAppApp.swift (entry), AppDelegate.swift (service owner)

**BoosterSimApp/Models/**
- Purpose: Domain data structures (immutable models + enums)
- Contains: SimulatorWindow, SimulatorDeviceType, AppSettings, AXNode, BuildRecord
- Key files: `SimulatorWindow.swift` (core data model), `AppSettings.swift` (@AppStorage-backed settings)

**BoosterSimApp/Services/**
- Purpose: Business logic and system integration; all owned by AppDelegate
- Contains: 11 service classes with @Published properties and pure methods
- Key files:
  - `SimulatorWindowTracker.swift` — primary service; publishes simulators + activeSimulator
  - `WindowEnumerator.swift` — low-level CGWindowList scanning
  - `WindowObserver.swift` — low-level AXObserver callbacks

**BoosterSimApp/Windows/**
- Purpose: AppKit window management and positioning
- Contains: Panel definition (SideWindowPanel), lifecycle controller (SideWindowController), positioning math (PositionCalculator), overlay (AXHighlightPanel)
- Key files:
  - `SideWindowController.swift` — embeds SwiftUI content, manages show/hide/position
  - `PositionCalculator.swift` — pure frame math (no side effects)

**BoosterSimApp/Views/MenuBar/**
- Purpose: Menu bar icon + quick menu
- Contains: MenuBarView.swift (status display, toggle side window)

**BoosterSimApp/Views/SideWindow/**
- Purpose: Main side panel sections and subcomponents
- Contains: 13 view files
- Key files:
  - `SideWindowView.swift` — root view; renders all sections
  - `DeviceHeaderView.swift` — simulator info + picker
  - `StatusBarSectionView.swift`, `BuildStatsSectionView.swift`, `EnvironmentOverridesView.swift`, `AXTreeView.swift`, `CameraView.swift` — feature sections

**BoosterSimApp/Views/Preferences/**
- Purpose: Settings window (native Cmd+, Settings scene)
- Contains: PreferencesView (tabbed root), GeneralTab (position, launch-at-login), AboutTab (version info)

**BoosterSimApp/Views/Onboarding/**
- Purpose: First-launch permission + feature tour
- Contains: OnboardingContainerView (flow orchestrator), OnboardingStepView (individual step), ProgressDotsView (pagination)

**BoosterSimApp/Views/Shared/**
- Purpose: Reusable UI components
- Contains: AccentButton (amber accent), StatusBadge (permission/feature status display)

**BoosterSimApp/Utilities/**
- Purpose: Constants and pure algorithms
- Contains: DesignTokens (all spacing/metrics), SpringAnimator (spring physics)

## Key File Locations

**Entry Points:**
- `BoosterSimApp/BoosterSimAppApp.swift` — @main SwiftUI App; defines MenuBarExtra + Settings scenes
- `BoosterSimApp/App/AppDelegate.swift` — service owner; wires up all dependencies; responds to app lifecycle

**Configuration:**
- `Info.plist` — LSUIElement = true (menu bar app), CFBundleVersion, CFBundleShortVersionString
- `BoosterSimApp/BoosterSimApp.xcodeproj/project.pbxproj` — Xcode project settings (build phases, frameworks, etc.)

**Core Logic:**
- `BoosterSimApp/Services/SimulatorWindowTracker.swift` — simulator detection + state publishing
- `BoosterSimApp/Windows/SideWindowController.swift` — window lifecycle + position sync
- `BoosterSimApp/Views/SideWindow/SideWindowView.swift` — main UI layout

**Testing:**
- `BoosterSimAppTests/` — placeholder (no tests yet)
- `BoosterSimAppUITests/` — placeholder (no tests yet)

## Naming Conventions

**Files:**
- **Swift source:** PascalCase.swift (Swift convention)
  - Examples: `BoosterSimAppApp.swift`, `SimulatorWindowTracker.swift`, `MenuBarView.swift`, `PositionCalculator.swift`
  - Structure: Single public type per file (rare exceptions: enums + related types in same file)

**Directories:**
- **Functional organization:** PascalCase, descriptive names
  - Examples: `Models/`, `Services/`, `Views/`, `Windows/`, `Utilities/`, `Assets.xcassets/`
  - Subdirectories under Views: feature-grouped (MenuBar, SideWindow, Preferences, Onboarding, Shared)

**Symbols (classes, structs, enums, protocols):**
- **Classes/Structs/Enums:** PascalCase
  - Examples: `SimulatorWindowTracker`, `SideWindowView`, `PositionCalculator`, `SideWindowMetrics`
- **Functions/Properties:** camelCase
  - Examples: `startTracking()`, `attachToSimulator(_:)`, `panelFrame(...)`, `activeSimulator`, `isCollapsed`
- **Constants (static/enum cases):** camelCase
  - Examples: `Spacing.md`, `CornerRadius.panel`, `SideWindowMetrics.expandedWidth`
- **Type abbreviations:** Lowercase (standard Swift)
  - Examples: `pid` (process ID), `udid` (unique device ID), `ax` (accessibility)

## Where to Add New Code

**New Feature:**
- **Primary code:** `BoosterSimApp/Services/{FeatureName}Service.swift` (new service class with @Published state)
- **Tests:** `BoosterSimAppTests/{FeatureName}ServiceTests.swift` (when test suite is configured)
- **Views:** `BoosterSimApp/Views/SideWindow/{FeatureName}View.swift` (if feature has UI section)
- **Integration:** Wire service in AppDelegate.swift (lazy var), inject into SideWindowView as @EnvironmentObject

**New Component/Module:**
- **Implementation:** Place in functional subdirectory
  - Reusable UI component → `BoosterSimApp/Views/Shared/{ComponentName}.swift`
  - Feature section view → `BoosterSimApp/Views/SideWindow/{SectionName}View.swift`
  - Service class → `BoosterSimApp/Services/{ServiceName}.swift`
  - Window manager → `BoosterSimApp/Windows/{WindowName}Controller.swift`
- **Keep file size under 200 LOC:** If exceeding, modularize (extract subviews, extract pure functions to Utilities)

**Utilities & Constants:**
- **Pure functions / algorithms:** `BoosterSimApp/Utilities/[FunctionName].swift` (static enum pattern)
  - Example: `PositionCalculator` enum with static methods
- **Design constants:** Add to `BoosterSimApp/Utilities/DesignTokens.swift` (extend existing enums)
  - Example: Add `FeatureSectionMetrics` enum for new section dimensions

## Special Directories

**Assets.xcassets/**
- Purpose: Xcode asset catalog (app icon, accent color)
- Generated: No (checked in)
- Committed: Yes
- Contains: `AppIcon.appiconset/`, `AccentColor.colorset/`

**BoosterSimApp.xcodeproj/**
- Purpose: Xcode project metadata
- Generated: No (checked in)
- Committed: Yes
- Avoid editing directly; use Xcode UI for target/build phase changes

**plans/ & docs/**
- Purpose: Implementation plans and official documentation (living documents)
- Generated: No (manually maintained)
- Committed: Yes
- Update after significant changes (phases, architecture, design decisions)

**.planning/codebase/**
- Purpose: GSD agent analysis (ARCHITECTURE.md, STRUCTURE.md, CONVENTIONS.md, TESTING.md, CONCERNS.md)
- Generated: Yes (by agents)
- Committed: No (gitignore)
- Consumed by: `/gsd:plan-phase` and `/gsd:execute-phase` commands

## Import Organization

**Order by layer (top → bottom, dependencies flow downward):**

1. Apple frameworks (Foundation, AppKit, SwiftUI, Combine, etc.)
2. ApplicationServices (CoreGraphics, etc.) — low-level system
3. ServiceManagement (if using)
4. No external dependencies

**Example from AppDelegate.swift:**
```swift
import AppKit
import SwiftUI
import Combine
```

**Example from SideWindowController.swift:**
```swift
import AppKit
import SwiftUI
import Combine
```

**Example from SimulatorWindowTracker.swift:**
```swift
import AppKit
import Combine
```

## File Size Management

**Current policy:** Keep individual files under 200 LOC (strict)

**Largest files (as of 2026-03-25):**
- `SideWindowView.swift` — ~250 LOC (candidate for modularization if grows further)
- `SimulatorWindowTracker.swift` — ~180 LOC (under limit)
- `AppDelegate.swift` — ~108 LOC (healthy)

**When to split:**
- View file > 200 LOC → extract subviews into separate files in same directory
  - Example: If SideWindowView grows, extract DeviceHeaderView, FeatureSectionView, etc. (already done)
- Service file > 200 LOC → extract helper types/extensions into separate files or break into logical services
  - Example: If StatusBarService + EnvironmentOverrideService grow, consider separate files (already separated)
- Utilities file > 200 LOC → add new utility enum to separate file
  - Example: If DesignTokens exceeds limit, create separate `ColorTokens.swift`, `TypographyTokens.swift`

## Key Dependencies

**Internal (within BoosterSimApp/):**
- AppDelegate imports all Services + Models
- Services import Models only (no service→service dependencies)
- Views import Models + Services (via @EnvironmentObject)
- Windows import Services + Models + Utilities
- Utilities depend on Foundation only (pure, no business logic)

**External (Apple frameworks only):**
- `AppKit` — NSPanel, NSWindow, NSApplication, NSScreen, NSWorkspace
- `SwiftUI` — @main, Views, @State, @EnvironmentObject, @AppStorage
- `Combine` — @Published, sink, AnyCancellable
- `CoreGraphics` — CGRect, CGWindowList, Quartz coordinate space
- `ApplicationServices` — AXUIElement, AXObserver (accessibility)
- `Foundation` — Process, URL, Timer, DispatchQueue
- `ServiceManagement` — SMAppService (launch at login)
- `UniformTypeIdentifiers` — UTType (if needed for file handling)

---

*Structure analysis: 2026-03-25*
