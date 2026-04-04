# BoosterSimApp Exploration Report - Index

**Exploration Date:** March 28, 2026
**Duration:** Complete codebase scan
**Scope:** 46 Swift files, 3,924 LOC, 11 services, 22 views

## Report Files

### 1. **Explore-0328-1634-codebase-summary.md** (23 KB)
Comprehensive deep-dive covering:
- Complete directory structure with LOC breakdown
- All 11 services with responsibilities and key methods
- Full view hierarchy (22 views across 5 categories)
- Models and data structures
- App lifecycle and initialization chain
- Window/NSPanel management
- Recent commits (10 latest)
- Design system and utilities
- Architecture decisions table
- Unresolved questions and placeholders
- Build info and deployment details

### 2. **file-tree-visual.txt** (8 KB)
Visual reference with ASCII diagrams:
- Directory tree with LOC estimates
- Architecture layer diagram
- Service communication flow
- Recent development timeline
- Known placeholder features
- Key metrics and numbers
- Deployment requirements

## Quick Navigation

### By Task
- **Understanding Services**: See section 2 of summary or service communication map
- **UI/Views Layout**: See section 3 of summary or architecture layer diagram
- **Window Management**: See section 6 of summary (NSPanel details)
- **Recent Changes**: See section 7 of summary (last 10 commits)
- **Key Architecture**: See section 9 of summary (decision table)

### By Component

**Core Services** (SimulatorWindowTracker-led)
- SimulatorWindowTracker (270 LOC)
- WindowObserver (110 LOC)
- WindowEnumerator (100 LOC)
- SimCtlService (80 LOC)

**Feature Services**
- AXInspectorService (180 LOC) — A11y tree walker
- BuildStatsService (140 LOC) — Xcode build monitor
- EnvironmentOverrideService (220 LOC) — Simulator customization
- StatusBarService (120 LOC) — Status bar config
- CameraService (95 LOC) — AX menu automation

**UI Components**
- 14 SideWindow views (1,200+ LOC)
- 3 Onboarding views (225 LOC)
- 3 Preferences views (160 LOC)
- MenuBar view (80 LOC)
- 2 Shared views (75 LOC)

**Window Management**
- SideWindowPanel (37 LOC) — Floating NSPanel
- SideWindowController (250 LOC) — Lifecycle + positioning
- AXHighlightPanel (90 LOC) — A11y overlay
- PositionCalculator (120 LOC) — Positioning math

## Key Highlights

✅ **Complete Feature Set**
- Real-time iOS/watchOS/tvOS/visionOS simulator detection
- Accessibility tree inspection with visual highlighting
- Xcode build monitoring and statistics
- Simulator status bar customization (9 presets + custom)
- Accessibility feature toggles (10 toggles, instant apply)
- Camera routing via AX automation
- Focus-aware panel visibility
- Dynamic window positioning (left/right/bottom)
- 4-step onboarding flow
- Preferences with position picker and launch-at-login

✅ **Architecture Quality**
- Clean service layer (11 independent/coordinated services)
- Reactive Combine-based state management
- Hybrid window detection (CGWindowList + AXObserver)
- Background queue execution for blocking APIs
- Spring physics for smooth animations
- Zero external dependencies (100% Apple frameworks)
- Comprehensive logging (os.Logger with subsystem filtering)
- Proper error handling and type-safe APIs

✅ **Recent Development** (last 5 commits)
- Smart invert detection fix (multi-key plist read)
- Panel focus synchronization
- UDID fallback support (Screen Recording permission optional)
- #Preview macros on all SwiftUI views
- Instant accessibility toggles (no relaunch)

## Metrics at a Glance

| Metric | Value |
|--------|-------|
| Total LOC | 3,924 |
| Total Files | 46 |
| Services | 11 |
| Views | 22 |
| Models | 4 structures + 4 enums |
| Windows | 4 NSPanel classes |
| External Deps | 0 |
| Build System | Xcode 16+ |
| Deployment | macOS 13+ |
| Memory | ~30-50 MB |

## File Paths (Quick Reference)

### Services
```
/Services/SimulatorWindowTracker.swift      — Core orchestrator
/Services/AXInspectorService.swift          — A11y tree walker
/Services/BuildStatsService.swift           — Build monitoring
/Services/EnvironmentOverrideService.swift  — Simulator customization
/Services/StatusBarService.swift            — Status bar config
/Services/CameraService.swift               — AX menu automation
```

### Views (SideWindow)
```
/Views/SideWindow/SideWindowView.swift           — Root
/Views/SideWindow/DeviceHeaderView.swift         — Device picker
/Views/SideWindow/EnvironmentOverridesView.swift — A11y toggles
/Views/SideWindow/StatusBarSectionView.swift    — Status bar UI
/Views/SideWindow/BuildChartView.swift          — Build timeline
/Views/SideWindow/AXTreeView.swift              — A11y inspector
```

### Windows
```
/Windows/SideWindowController.swift  — Lifecycle manager
/Windows/SideWindowPanel.swift       — NSPanel floating
/Windows/PositionCalculator.swift    — Position math
/Windows/AXHighlightPanel.swift      — A11y highlight overlay
```

### Utilities
```
/Utilities/AppLogger.swift        — Centralized logging
/Utilities/DesignTokens.swift     — Design system
/Utilities/SpringAnimator.swift   — Spring physics
```

### App Entry
```
/App/AppDelegate.swift      — NSApplicationDelegate
/BoosterSimAppApp.swift     — @main SwiftUI App
```

## Known Placeholders

4 feature sections with UI-only implementations:
1. **Capture** — Screenshot, Record Screen, GIF, Export
2. **Actions** — Reset App, Clear Keychain, Push Notification, Deep Link
3. **Design** — Grid Overlay, Safe Area, Ruler, Color Picker
4. **Network** — Throttle, Block Requests, Logs, Certificates

Plus: XcodeDetector service (unused)

## Next Steps for Development

**High-Impact Additions:**
1. Screenshot capture via Simulator.app screenshot command
2. Screen recording via simctl video recording
3. Network throttling via simctl io add stress
4. Push notification test via simctl push
5. Deep link testing via simctl openurl

**Refactoring Opportunities:**
1. Extract common binding pattern from EnvironmentOverridesView
2. Consolidate status bar preset definitions
3. Create view factory for feature sections
4. Parameterize simulation state queries (DRY)

**Polish Items:**
1. Persistent custom status bar configs
2. Build notification alerts
3. Xcode path auto-discovery
4. Multi-language localization
5. Accessibility permission auto-prompt

---

**Report Generated:** 2026-03-28
**Codebase Status:** Mature, actively developed
**Recommendation:** Ready for feature implementation in placeholder sections
