# Technology Stack

**Analysis Date:** 2026-08-31

## Languages

**Primary:**
- Swift (language mode `SWIFT_VERSION = 5.0`) — all app code in `BoosterSimApp/`, the embedded framework in `BoosterSimConnect/`, both test bundles, and the CLI in `booster-sim-cli/`. Compiled with Xcode 26.3 "approachable concurrency" settings: `SWIFT_APPROACHABLE_CONCURRENCY = YES`, `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, `SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY = YES` (see `BoosterSimApp.xcodeproj/project.pbxproj`).

**Secondary:**
- Shell (`/bin/sh`) — one build phase ("Build iOS Framework & Copy", id `A1B2C3D4E5F6A7B8C9D0E1F2` in `BoosterSimApp.xcodeproj/project.pbxproj`) that builds `BoosterSimConnect.framework` for `iphonesimulator` and copies it into `BoosterSimApp.app/Contents/Resources`.
- YAML — GitHub Actions workflow `.github/workflows/ci.yml`.

## Runtime

**Environment:**
- macOS 26.2 deployment target (`MACOSX_DEPLOYMENT_TARGET = 26.2` for app, unit-test, and UI-test targets) on Apple Silicon (`arm64`).
- The `BoosterSimConnect` framework target runs on the **iOS simulator platform only** (`SDKROOT = iphoneos`, `SUPPORTED_PLATFORMS = iphonesimulator`, `TARGETED_DEVICE_FAMILY = 1,2`) and is compiled under `#if DEBUG && targetEnvironment(simulator)`.
- App is a menu-bar (agent) app: `INFOPLIST_KEY_LSUIElement = YES` — no Dock icon; entry point `BoosterSimApp/BoosterSimAppApp.swift` (`MenuBarExtra` + `Settings` scenes, `@NSApplicationDelegateAdaptor` in `BoosterSimApp/App/AppDelegate.swift`).

**Package Manager:**
- Swift Package Manager via Xcode (`XCRemoteSwiftPackageReference` in `BoosterSimApp.xcodeproj/project.pbxproj`); pins in `BoosterSimApp.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`.
- The standalone CLI has its own manifest: `booster-sim-cli/Package.swift` (`swift-tools-version: 5.8`, platform `.macOS(.v13)`).
- No CocoaPods / Cartfile.

## Frameworks

**Core (system frameworks imported by app code):**
- SwiftUI — windows/views under `BoosterSimApp/Views/`, `MenuBarExtra` in `BoosterSimApp/BoosterSimAppApp.swift`
- AppKit — `NSPanel`/`NSWindow` controllers under `BoosterSimApp/Windows/`, `NSPasteboard` in `BoosterSimApp/Services/CaptureSaveRouter.swift`
- Combine — the async backbone of every service (`BoosterSimApp/Services/SimCtlService.swift` and all facades)
- Network — `NWListener` servers (`BoosterSimApp/Services/PulseServer.swift`, `BoosterSimApp/Services/CommandServer.swift`) and `NWBrowser`/`NWConnection` client (`BoosterSimConnect/BoosterCommandClient.swift`)
- ScreenCaptureKit — screenshots and recording (`BoosterSimApp/Services/ScreenshotService.swift`, `BoosterSimApp/Services/RecordingService.swift`)
- AVFoundation — `AVAssetExportSession` MP4/MOV export (`BoosterSimApp/Services/CaptureExporter.swift`)
- ImageIO + CoreImage — GIF encoding (`BoosterSimApp/Services/CaptureExporter.swift`)
- CoreGraphics — `CGWindowID`/window frames, screen-capture preflight (`BoosterSimApp/Services/ScreenshotService.swift`, `BoosterSimApp/Services/PermissionManager.swift`)
- ApplicationServices (Accessibility) — `AXUIElement`/`AXObserver` (`BoosterSimApp/Services/AXInspectorService.swift`, `BoosterSimApp/Services/CameraService.swift`, `BoosterSimApp/Services/WindowObserver.swift`)
- OSLog — `AppLogger` (`BoosterSimApp/Utilities/AppLogger.swift`, subsystem `com.nextlabs.BoosterSimApp`)
- Security — `SecCertificate` metadata parsing (`BoosterSimApp/Services/CertificateStore.swift`)
- CryptoKit — SHA-256 certificate fingerprints (`BoosterSimApp/Services/CertificateStore.swift`)
- ServiceManagement — `SMAppService` launch-at-login (`BoosterSimApp/Models/AppSettings.swift`)
- CoreFoundation — `CFPreferences` writes into the Simulator's `com.apple.iphonesimulator` domain (`BoosterSimApp/Services/TouchIndicatorController.swift`)
- Foundation `Process` — `xcrun simctl` and `/usr/bin/openssl` subprocess execution

**Testing:**
- Swift Testing (`import Testing`, `@Test`, `#expect`) — unit tests in `BoosterSimAppTests/` (e.g. `BoosterSimAppTests/SimCtlServiceTests.swift`)
- XCTest + `XCUIApplication` — UI tests in `BoosterSimAppUITests/` (`BoosterSimAppUITests/BoosterSimAppUITests.swift`, `BoosterSimAppUITests/ScreenshotTests.swift`)

**Build/Dev:**
- Xcode 26.3 (project created `CreatedOnToolsVersion = 26.3`; `LastUpgradeCheck = 2640`), `.xcodeproj` with `PBXFileSystemSynchronizedRootGroup` targets (folder-synced, no per-file pbx entries)
- GitHub Actions CI on `macos-26` runners (`.github/workflows/ci.yml`) with `xcbeautify` and `xcrun xcresulttool`

## Key Dependencies

**Critical:**
- `Pulse` 5.2.2 (pinned revision `a4e5bc2b0439552d4ff5fc9667c389be6ef5bd52`, up-to-next-major from 5.1.0, `https://github.com/kean/Pulse.git`) — products **Pulse** and **PulseProxy**, linked by BOTH the `BoosterSimApp` app target and the `BoosterSimConnect` framework target. `PulseProxy` provides the `URLSession` swizzling (`URLSessionProxyDelegate`) activated in `BoosterSimConnect/BoosterSimConnect.swift`.

**Infrastructure:**
- `swift-argument-parser` ≥ 1.2.0 (CLI only, `booster-sim-cli/Package.swift`) — argument parsing for the `boostersim` executable (`booster-sim-cli/Sources/boostersim/boostersim.swift`).
- System tools invoked as subprocesses: `/usr/bin/xcrun` (simctl), `/usr/bin/openssl` (CA generation). Both are existence-checked before use (`BoosterSimApp/Services/SimCtlService.swift`, `BoosterSimApp/Services/CertificateStore.swift`).

## Targets

| Target | Product | Platform | Purpose |
|---|---|---|---|
| `BoosterSimApp` | `BoosterSimApp.app` | macOS | Main menu-bar app |
| `BoosterSimConnect` | `BoosterSimConnect.framework` | iOS simulator | Framework loaded into a host iOS app inside Simulator to capture `URLSession` traffic and enforce network conditions |
| `BoosterSimAppTests` | unit-test bundle (hosted in app) | macOS | Swift Testing unit tests |
| `BoosterSimAppUITests` | UI-test bundle | macOS | XCTest UI + screenshot tests |
| `boostersim` (separate package `booster-sim-cli/`) | `boostersim` executable | macOS | CLI for AI agents: `tap`, `swipe`, `type`, `screenshot`, `press`, `list-elements`, `list-devices`, `doctor` |

## Configuration

**Environment:**
- No `.env` files, no required environment variables, no secrets in repo (a `BoosterHealth-Entitlements.plist` with HealthKit keys exists at the repo root but is **not referenced** by any target — no `CODE_SIGN_ENTITLEMENTS` setting in `BoosterSimApp.xcodeproj/project.pbxproj`).
- Info.plist is generated (`GENERATE_INFOPLIST_FILE = YES`) from `INFOPLIST_KEY_*` build settings: display name `BoosterSim`, `LSUIElement`, copyright, bundle id `sim-dev.BoosterSimApp`, version 1.0 (1).
- User settings persist via `@AppStorage`/`UserDefaults` in `BoosterSimApp/Models/AppSettings.swift` (side-window position, capture destination/format/GIF size+fps, launch-at-login, xcode path).
- Generated CA material lives on disk under `~/Library/Application Support/BoosterSimApp/Certificates/` (`ca.pem`/`ca.key`, 0600 perms) — `BoosterSimApp/Services/CertificateStore.swift`.

**Build:**
- Configurations: Debug / Release (project + all four targets).
- Signing: `CODE_SIGN_STYLE = Automatic`, Development Team `EQ8B89SPCX`; CI overrides with `CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO` (`.github/workflows/ci.yml`).
- `ENABLE_APP_SANDBOX = NO`, `ENABLE_HARDENED_RUNTIME = YES`, `ENABLE_USER_SCRIPT_SANDBOXING = NO` on the app target (the framework-copy build phase needs unsandboxed scripts).
- CI cache key hashes `BoosterSimApp.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`.

## Platform Requirements

**Development:**
- macOS 26.2+ host with Xcode 26.3 (iOS simulator SDK required for the `BoosterSimConnect` framework build phase), Apple team `EQ8B89SPCX` for automatic signing; Accessibility + Screen Recording TCC permissions granted for full functionality.
- For the Connect feature: a host iOS app running in Simulator that loads `BoosterSimConnect.framework` from `/Applications/BoosterSim.app/Contents/Resources/` (snippet surfaced in `BoosterSimApp/Views/SideWindow/network/ConnectSetupView.swift`).

**Production:**
- macOS app distributed as `BoosterSim.app` (bundle id `sim-dev.BoosterSimApp`); no App Store-specific capabilities configured (sandbox off, no entitlements file wired).

---

*Stack analysis: 2026-08-31*
