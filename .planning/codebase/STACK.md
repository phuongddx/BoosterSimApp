# Technology Stack

**Analysis Date:** 2025-03-25

## Languages

**Primary:**
- Swift 6 - Entire application with strict concurrency mode enabled
- Objective-C (minimal) - Interface stubs via `AXUIElement` and CoreGraphics C APIs

## Runtime

**Environment:**
- macOS 15 Sequoia (deployment target: 15.0, actual requires macOS 26.2 for Xcode 16.3)
- Target: macOS menu bar companion app

**Package Manager:**
- Xcode built-in (no external package manager)
- No CocoaPods, SPM, or third-party dependencies

## Frameworks

**Core (Apple frameworks only):**
- **SwiftUI** - UI rendering; `@main` App entry point, `MenuBarExtra`, `Settings` scene, views in `BoosterSimApp/Views/`
- **AppKit** - Window management, NSPanel, NSWindow, NSApplication, menu bar integration. `SideWindowPanel` is NSPanel subclass in `BoosterSimApp/Windows/SideWindowPanel.swift`
- **Combine** - Reactive state management via `@Published` and `@EnvironmentObject`. Used throughout services in `BoosterSimApp/Services/`
- **CoreGraphics** - Window enumeration, frame math, display coordinate conversion via `CGWindowListCopyWindowInfo`. Used in `BoosterSimApp/Services/WindowEnumerator.swift`
- **ApplicationServices** - Accessibility API (AX) for Simulator inspection and menu automation. `AXUIElement`, `AXObserver` in `BoosterSimApp/Services/AXInspectorService.swift`, `BoosterSimApp/Services/CameraService.swift`, `BoosterSimApp/Services/WindowObserver.swift`
- **Foundation** - Process execution (`Process`), file I/O, JSON parsing, UserDefaults
- **QuartzCore** - CADisplayLink for spring physics animation in `BoosterSimApp/Utilities/SpringAnimator.swift`
- **ServiceManagement** - Launch-at-login via `SMAppService` in `BoosterSimApp/Models/AppSettings.swift`
- **UniformTypeIdentifiers** - File type checking for macOS permission dialogs

## Key Dependencies

**Critical (system frameworks):**
- **CGWindowList polling** - Detects Simulator windows every 0.5s via `WindowEnumerator`. Location: `BoosterSimApp/Services/WindowEnumerator.swift`
- **AXObserver** - Real-time window move/resize callbacks per Simulator PID. Location: `BoosterSimApp/Services/WindowObserver.swift`
- **xcrun simctl** - External process calls for device list, environment overrides, status bar features. Wrapper: `BoosterSimApp/Services/SimCtlService.swift`
- **Xcode DerivedData** - Build history polling via plist parsing at `~/Library/Developer/Xcode/DerivedData/*/Logs/Build/LogStoreManifest.plist`. Location: `BoosterSimApp/Services/BuildStatsService.swift`

## Configuration

**Environment:**
- Bundle ID: `sim-dev.BoosterSimApp`
- App version: 1.0
- Development Team: EQ8B89SPCX (Xcode auto-signing)
- LSUIElement: true (no Dock icon, menu bar only)
- Code signing: Automatic (Xcode managed)

**Build Settings:**
- Swift version: 5.0 (Xcode 16.3 compatibility)
- Swift concurrency: Strict (Swift 6 mode)
- Swift default actor isolation: `@MainActor`
- Swift upcoming features: `SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY`
- Deployment target: macOS 15.0 (but runtime requires 26.2)
- Asset catalog: `BoosterSimApp/Assets.xcassets`
- String catalog: Generated (Swift native strings)

**Entitlements:**
- App Sandbox: Enabled (`ENABLE_APP_SANDBOX`)
- Hardened Runtime: Enabled (`ENABLE_HARDENED_RUNTIME`)
- User-selected files: Read-only (for DerivedData/Xcode path selection)

## Build & Execution

**Build Command:**
```bash
xcodebuild -project BoosterSimApp.xcodeproj -scheme BoosterSimApp -configuration Debug build
```

**Run:**
```bash
open BoosterSimApp.xcodeproj  # Opens in Xcode, then Cmd+R
```

**Requirements:**
- Xcode 16.3+ (Swift 6 toolchain)
- macOS 15 Sequoia host
- iOS Simulator running (for live behavior)

## Platform Requirements

**Development:**
- Xcode 16.3+ with Swift 6 toolchain
- macOS 15 Sequoia or later

**Runtime:**
- macOS 15.0 deployment target
- iOS Simulator app (appears as window with owner name "Simulator")
- Accessibility permission (required for AXObserver, AXInspector)
- Screen Recording permission (required for window name via CGWindowList)

**No External Services:**
- Zero cloud APIs
- Zero third-party SDKs
- Local-only operation; no network calls

---

*Stack analysis: 2025-03-25*
