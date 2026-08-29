# Technology Stack

**Analysis Date:** 2026-08-29

## Languages

**Primary:**
- Swift 5.0 — All app source in `BoosterSimApp/`, framework in `BoosterSimConnect/`, CLI in `booster-sim-cli/Sources/`

**Secondary:**
- Shell (bash) — Build phase script embedded in `BoosterSimApp.xcodeproj/project.pbxproj` ("Build iOS Framework & Copy" phase) that copies the iOS Simulator framework into the macOS app bundle's Resources

## Runtime

**Environment:**
- macOS 26.2+ (deployment target `MACOSX_DEPLOYMENT_TARGET = 26.2`)
- Xcode 26.3+ (created with `CreatedOnToolsVersion = 26.3`)
- Apple Silicon (ARM64) — CI runs on `macos-26` runners; M3 Pro development machine

**Package Manager:**
- Swift Package Manager (SPM) — Single remote dependency via `XCRemoteSwiftPackageReference` in `BoosterSimApp.xcodeproj/project.pbxproj`
- Xcode build system resolves packages to `SourcePackages/` (CI) or default SPM cache

## Frameworks

**Core (Apple SDK):**
- SwiftUI — All UI views in `BoosterSimApp/Views/`; entry point in `BoosterSimApp/BoosterSimAppApp.swift`
- AppKit — `NSApplicationDelegate` lifecycle in `BoosterSimApp/App/AppDelegate.swift`, `NSWindow`/`NSPanel` in `BoosterSimApp/Windows/`
- Combine — Reactive state and service communication throughout `BoosterSimApp/Services/`
- Foundation — Data models, file I/O, `Process` invocation in `BoosterSimApp/Services/SimCtlService.swift`, `BoosterSimApp/Services/DeepLinkService.swift`, `BoosterSimApp/Services/CertificateStore.swift`

**System Integration:**
- CoreGraphics — `CGWindowListCopyWindowInfo` in `BoosterSimApp/Services/WindowEnumerator.swift`, `CGPreflightScreenCaptureAccess`/`CGRequestScreenCaptureAccess` in `BoosterSimApp/Services/PermissionManager.swift`
- ApplicationServices — `AXUIElement` API in `BoosterSimApp/Services/AXInspectorService.swift`, `BoosterSimApp/Services/CameraService.swift`, `BoosterSimApp/Services/WindowObserver.swift`
- Network framework — `NWListener`/`NWConnection` in `BoosterSimApp/Services/PulseServer.swift`, `BoosterSimApp/Services/PulseClientConnection.swift`
- Security framework — `SecCertificateCreateWithData`/`SecCertificateCopyValues` in `BoosterSimApp/Services/CertificateStore.swift`
- CryptoKit — `SHA256` fingerprinting in `BoosterSimApp/Services/CertificateStore.swift`
- AVFoundation — `AVAssetWriter` for MP4 export in `BoosterSimApp/Services/CaptureService.swift`
- ScreenCaptureKit — `SCStream`/`SCStreamOutput`/`SCShareableContent` for screen recording in `BoosterSimApp/Services/CaptureService.swift`
- ServiceManagement — `SMAppService.mainApp` for launch-at-login in `BoosterSimApp/Models/AppSettings.swift`
- UniformTypeIdentifiers — File type handling in `BoosterSimApp/Services/PermissionManager.swift`, `BoosterSimApp/Services/DesignComparisonService.swift`
- OSLog — Structured logging via `BoosterSimApp/Utilities/AppLogger.swift`

**Third-Party:**
- Pulse 5.1.0+ (kean/Pulse) — Network logging SDK; used as `Pulse` and `PulseProxy` product targets in both macOS app and iOS framework. Consumed via SPM from `https://github.com/kean/Pulse.git`

**Testing:**
- XCTest — Unit tests in `BoosterSimAppTests/`, UI tests in `BoosterSimAppUITests/`

**Build/Dev:**
- xcodebuild — Build system (no external build tools)
- swift-argument-parser 1.2.0+ — CLI argument parsing for `booster-sim-cli` (separate SPM package at `booster-sim-cli/Package.swift`)

## Key Dependencies

**Critical:**
- Pulse (`Pulse` + `PulseProxy` products) — Powers the network inspection feature. The macOS app hosts a TCP server (`PulseServer`) that receives Pulse-protocol events from the iOS framework (`BoosterSimConnect`) loaded into Simulator apps. Without Pulse, the Connect/network tab is non-functional.

**Infrastructure:**
- xcrun simctl — External CLI tool (not a package dependency) invoked via `Process` in `BoosterSimApp/Services/SimCtlService.swift`. Powers environment overrides, status bar configuration, certificate trust, deep link opening, and device listing. Expected at `/usr/bin/xcrun`.
- /usr/bin/openssl — External CLI tool invoked via `Process` in `BoosterSimApp/Services/CertificateStore.swift` for self-signed CA certificate generation. Expected at `/usr/bin/openssl`.
- notifyutil — macOS system utility invoked via `simctl spawn` in `BoosterSimApp/Services/EnvironmentOverrideService.swift` for posting Darwin notifications to instantly apply accessibility setting changes inside the Simulator.

## Configuration

**Environment:**
- Xcode project settings via `BoosterSimApp.xcodeproj/project.pbxproj` (no `.xcconfig` files)
- `@AppStorage` (UserDefaults-backed) in `BoosterSimApp/Models/AppSettings.swift` for user preferences (side window position, launch-at-login, Xcode path)
- Additional UserDefaults keys for deep link history/favorites, design comparison presets, and certificate install state
- `ENABLE_APP_SANDBOX = NO` — App runs unsandboxed (required for Accessibility API, AXObserver, CGWindowList, Process invocation)
- `ENABLE_HARDENED_RUNTIME = YES` — Hardened runtime enabled for notarization compatibility
- `INFOPLIST_KEY_LSUIElement = YES` — No Dock icon (menu-bar-only app)

**Build:**
- `BoosterSimApp.xcodeproj/project.pbxproj` — All build configuration lives here
- `SWIFT_APPROACHABLE_CONCURRENCY = YES` — Swift 6 strict concurrency with `MainActor`-first approach
- `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` — All types default to `@MainActor`
- `DEAD_CODE_STRIPPING = YES` — Dead code stripping enabled
- `SWIFT_COMPILATION_MODE = wholemodule` (Release) — Whole-module optimization
- `ENABLE_USER_SCRIPT_SANDBOXING = NO` — Build scripts can access filesystem (needed for framework copy)
- DerivedData LogStoreManifest.plist — Read at runtime from `~/Library/Developer/Xcode/DerivedData/` by `BoosterSimApp/Services/BuildStatsService.swift`

**Concurrency Model:**
- Swift 6 strict concurrency with `MainActor`-as-default-isolation
- `DispatchQueue.global(qos: .userInitiated)` for background Process/AX calls
- `Combine` publishers bridge background work to main-thread `@Published` state
- `nonisolated fileprivate` for AX calls dispatched off main actor

## Platform Requirements

**Development:**
- macOS 26.2+ with Xcode 26.3+
- Accessibility permission (System Settings → Privacy → Accessibility)
- Screen Recording permission (for Simulator window name detection via `kCGWindowName`)
- Xcode installed (detected via `BoosterSimApp/Services/XcodeDetector.swift` at known paths)
- OpenSSL installed at `/usr/bin/openssl` (for certificate features)
- DerivedData access with security-scoped bookmark (for build stats)

**Production:**
- macOS menu-bar app (LSUIElement)
- Distribution: App Store or direct (team ID `EQ8B89SPCX`, auto code signing)
- Target devices: macOS only; companion iOS framework (`BoosterSimConnect`) runs inside iOS Simulator apps
- `booster-sim-cli` is a separate macOS CLI tool built with Swift Package Manager (platform: macOS 13+)

---

*Stack analysis: 2026-08-29*