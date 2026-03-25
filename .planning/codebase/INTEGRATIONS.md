# External Integrations

**Analysis Date:** 2025-03-25

## System APIs & Local Services

**macOS Window System:**
- Quartz Window Services (`CGWindowListCopyWindowInfo`)
  - What it's used for: Polling open windows every 0.5s to detect iOS Simulator instances
  - Client: `BoosterSimApp/Services/WindowEnumerator.swift`
  - Permissions: Screen Recording (macOS Ventura+) for window names
  - Data: Window ID, PID, frame (Y-flip from Quartz to AppKit space), owner name

**macOS Accessibility API:**
- Apple Accessibility (`AXObserver`, `AXUIElement`)
  - What it's used for: Real-time window move/resize events; menu automation for camera routing; UI tree inspection
  - Locations:
    - `BoosterSimApp/Services/WindowObserver.swift` - Per-PID AXObserver for live Simulator window tracking
    - `BoosterSimApp/Services/AXInspectorService.swift` - Accessibility tree walker for UI inspection
    - `BoosterSimApp/Services/CameraService.swift` - Menu item navigation to toggle camera routing
  - Permissions: Accessibility (System Preferences > Security & Privacy > Accessibility)
  - Auth: `AXIsProcessTrusted()` check; prompt via `AXIsProcessTrustedWithOptions()`

**iOS Simulator Control:**
- Xcode toolchain (`xcrun simctl`)
  - What it's used for: List Simulator devices, get device types/UDIDs; toggle environment overrides; read status bar features
  - Client: `BoosterSimApp/Services/SimCtlService.swift` (wrapper with Combine publishers)
  - Used by:
    - `BoosterSimApp/Services/SimulatorWindowTracker.swift` - Device classification (iPhone, iPad, Watch, TV, Vision)
    - `BoosterSimApp/Services/StatusBarService.swift` - Toggle time/battery override
    - `BoosterSimApp/Services/EnvironmentOverrideService.swift` - Set locale, appearance, connectivity
  - Execution: `Process` spawning `/usr/bin/xcrun` with args; output parsed as JSON or plain text
  - Timeout: 2.0s for AX element operations

**Xcode Installation Detection:**
- File system check
  - What it's used for: Detecting active Xcode path; accessing DerivedData for build history
  - Client: `BoosterSimApp/Services/XcodeDetector.swift` (reads `xcode-select -p` output)
  - Permission check: `PermissionManager.checkXcode()`

**Xcode DerivedData:**
- Local file system (plist parsing)
  - What it's used for: Build history with duration, warnings, errors
  - Path: `~/Library/Developer/Xcode/DerivedData/*/Logs/Build/LogStoreManifest.plist`
  - Client: `BoosterSimApp/Services/BuildStatsService.swift`
  - Poll interval: 5.0s
  - Permissions: Security-scoped bookmark storage in UserDefaults (key: `derivedDataBookmark`)

## Data Storage

**Local Storage Only:**
- **UserDefaults** - App settings (side window position, launch-at-login toggle, Xcode path)
  - Keys: `sideWindowPosition`, `showSideWindow`, `launchAtLogin`, `xcodePath`, `derivedDataBookmark`, `completedOnboarding`
  - Location: `BoosterSimApp/Models/AppSettings.swift`
  - Scope: `@AppStorage` backed by UserDefaults (sandboxed app domain)

**No Databases:**
- No SQL, SQLite, Core Data, or Realm
- No remote sync or cloud storage

## Authentication & Identity

**System-Level Only:**
- No user authentication required
- Runs as current macOS user
- Permissions handled via macOS security prompts (Accessibility, Screen Recording)

**Launch at Login:**
- Service: `ServiceManagement.SMAppService`
- Implementation: `BoosterSimApp/Models/AppSettings.swift` lines 38-51
- Registers/unregisters with system launch daemon

## Monitoring & Observability

**Error Tracking:**
- None implemented
- Errors logged to console via `print()` statements

**Logs:**
- Console output only (no persistent logging)
- No error tracking service

## CI/CD & Deployment

**Hosting:**
- Local macOS execution only
- No deployment platform configured

**CI Pipeline:**
- None configured
- Xcode build phases only

## Environment Configuration

**Required Permissions (Runtime):**
- `Accessibility` - For AXObserver and UI automation
- `Screen Recording` - For window name retrieval via CGWindowList
- `DerivedData Access` - For build history (via security-scoped bookmark)
- `Xcode Path` - Manual selection if not auto-detected

**Permission Check Locations:**
- `BoosterSimApp/Services/PermissionManager.swift` - Centralized permission state and prompts
- Onboarding flow: `BoosterSimApp/Views/Onboarding/OnboardingContainerView.swift`

**Secrets/Credentials:**
- None required (no external APIs)
- Development Team ID (EQ8B89SPCX) hardcoded in Xcode project for code signing

## Webhooks & Callbacks

**Incoming:**
- None

**Outgoing:**
- None (all operations are local to macOS)

## System Integration Points

**Simulator Process Detection:**
- Process owner name: `"Simulator"` (hardcoded filter in `WindowEnumerator`)
- UDID/device type mapping: Parsed from `xcrun simctl list devices --json`
- Real-time tracking: `AXObserver` per PID with ref-counting via `Unmanaged.passRetained()`

**Frame Coordinate System:**
- **Quartz space** (CGWindowList output): Y=0 at top, increases downward
- **AppKit space** (NSPanel/NSWindow): Y=0 at bottom, increases upward
- Conversion in `WindowEnumerator.swift`: `appKitY = primaryHeight - quartzY - height`

**Menu Bar Integration:**
- SwiftUI `MenuBarExtra` (macOS 13+)
- No launch agent or helper app required
- LSUIElement=true suppresses Dock icon

---

*Integration audit: 2025-03-25*
