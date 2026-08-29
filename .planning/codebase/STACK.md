# Technology Stack

**Analysis Date:** 2026-08-29

## Languages

**Primary:**
- Swift 5.0 — All application code (macOS menu-bar app, iOS companion framework, CLI tool)
- ~8,271 lines across 44 Swift files

**No secondary languages.** The project is pure Swift with no Objective-C bridging headers, no `.m`/`.h` files, and no non-Swift source.

## Runtime

**Environment:**
- macOS 26.2+ (deployment target: `MACOSX_DEPLOYMENT_TARGET = 26.2`)
- Apple Silicon (arm64) — runs on M3 Pro; CI uses `macos-26` runners

**Package Manager:**
- Swift Package Manager (SPM) for the CLI tool (`booster-sim-cli/Package.swift`)
- Xcode SPM integration for the main app (resolved in `BoosterSimApp.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`)
- No CocoaPods, no Carthage
- Lockfile: Present (`Package.resolved`)

## Frameworks

**Core (Apple):**
- SwiftUI — All UI views in `BoosterSimApp/Views/`
- AppKit — NSWindow, NSApplication, NSPanel, NSImage, AXUIElement integration
- Combine — Reactive state management across all services (`@Published`, `AnyPublisher`, `sink`)
- Network framework (`Network`) — TCP listener/server in `BoosterSimApp/Services/PulseServer.swift`

**System APIs (Apple):**
- ScreenCaptureKit — Screen recording in `BoosterSimApp/Services/CaptureService.swift`
- ApplicationServices / Accessibility (`AXUIElement`, `AXObserver`) — Window tracking, menu automation, accessibility inspection
- CoreGraphics (`CGWindowListCopyWindowInfo`, `CGPreflightScreenCaptureAccess`) — Window discovery, screen recording permission
- CryptoKit — SHA-256 fingerprinting in `BoosterSimApp/Services/CertificateStore.swift`
- Security framework (`SecCertificate*`) — Certificate parsing and metadata extraction in `BoosterSimApp/Services/CertificateStore.swift`
- AVFoundation — Video export (MP4) in `BoosterSimApp/Services/CaptureService.swift`
- OSLog — Structured logging in `BoosterSimApp/Utilities/AppLogger.swift`
- UniformTypeIdentifiers — File type handling in `BoosterSimApp/Services/DesignComparisonService.swift`

**Testing:**
- Swift Testing (`import Testing`, `@Test func`) — Unit tests in `BoosterSimAppTests/CertificateServiceTests.swift`
- XCTest — UI tests in `BoosterSimAppUITests/ScreenshotTests.swift`

**Build/Dev:**
- Xcode — Primary IDE and build system
- xcodebuild — CI build commands in `.github/workflows/ci.yml`
- xcbeautify — Build output formatting in CI

## Key Dependencies

**Critical:**
- [Pulse](https://github.com/kean/Pulse) 5.2.2 — Network logging SDK. Used in two ways:
  1. **macOS host app:** Custom TCP server (`PulseServer.swift`) receives network events from Simulator via Pulse's binary protocol, parsed by `PulsePacketDecoder.swift`
  2. **iOS companion framework** (`BoosterSimConnect/BoosterSimConnect.swift`): Loaded into Simulator apps via `Bundle.load()` in DEBUG builds; activates `URLSessionProxyDelegate.enableAutomaticRegistration()` for URLSession swizzling and `RemoteLogger` for Bonjour-based broadcasting
  - Products linked: `Pulse`, `PulseProxy`

- [swift-argument-parser](https://github.com/apple/swift-argument-parser) 1.2.0+ — CLI command parsing for `booster-sim-cli`

**Infrastructure:**
- None (no backend, no cloud services)

## Configuration

**Environment:**
- No `.env` files in use
- Configuration is code-level constants and `UserDefaults` for persistence
- Sensitive header/query redaction configured in `BoosterSimConnect/BoosterSimConnect.swift`

**Build:**
- `BoosterSimApp.xcodeproj/project.pbxproj` — Xcode project file (4 targets: app, tests, UI tests, iOS framework)
- `booster-sim-cli/Package.swift` — SPM package for CLI tool (swift-tools-version: 5.8, macOS 13+)
- `BoosterHealth-Entitlements.plist` — HealthKit entitlements (for health data generation feature)
- Code signing: Automatic, Hardened Runtime enabled
- `INFOPLIST_KEY_LSUIElement = YES` — Menu-bar app (no Dock icon)
- Bundle IDs: `sim-dev.BoosterSimApp`, `sim-dev.BoosterSimAppTests`, `sim-dev.BoosterSimAppUITests`, `sim-dev.BoosterSimConnect`

## Platform Requirements

**Development:**
- macOS 26.2+
- Xcode (any recent version with Swift 5.0+ support)
- `/usr/bin/xcrun` — Required for all `simctl` operations
- `/usr/bin/openssl` — Required for certificate generation in `CertificateStore`
- Xcode DerivedData directory at `~/Library/Developer/Xcode/DerivedData/` — For build stats monitoring

**Production:**
- macOS menu-bar app (not distributed via App Store based on code signing setup)
- Runs alongside Xcode's iOS Simulator
- Requires Accessibility permission (for window tracking, AX inspection, camera toggle)
- Requires Screen Recording permission (for screen capture/recording)
- Security-scoped bookmark for DerivedData directory access

---

*Stack analysis: 2026-08-29*
