# External Integrations

**Analysis Date:** 2026-08-29

## Command-Line Tools

**xcrun simctl:**
- Primary interface to iOS Simulator control
- Service: `BoosterSimApp/Services/SimCtlService.swift` — wraps `Process` calls to `/usr/bin/xcrun simctl`
- Used by:
  - `BoosterSimApp/Services/EnvironmentOverrideService.swift` — `simctl ui <udid> appearance|increase_contrast|content_size`; `simctl spawn <udid> defaults read/write com.apple.Accessibility <key>`; `simctl spawn <udid> notifyutil -p <notification>`
  - `BoosterSimApp/Services/StatusBarService.swift` — `simctl status_bar <udid> override --time/--batteryLevel/--batteryState/--wifiBars/--cellularBars/--dataNetwork/--operatorName`
  - `BoosterSimApp/Services/CertificateService.swift` — `simctl addrootcert <udid> <cert.pem>` for certificate trust; `simctl keychain <udid> reset` for keychain reset
  - `BoosterSimApp/Services/DeepLinkService.swift` — `simctl openurl <udid> <url>` for deep link testing
  - `BoosterSimApp/Services/SimulatorWindowTracker.swift` — `simctl list devices --json` for device type classification and UDID lookup
- Invoked via `Process()` with `executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")`
- Errors: `BoosterSimApp/Services/SimCtlService.swift` defines `SimCtlError` enum (`.commandFailed`, `.xcrunNotFound`, `.timeout`)

**/usr/bin/openssl:**
- Self-signed CA certificate generation
- Service: `BoosterSimApp/Services/CertificateStore.swift` — runs `openssl req -x509 -newkey rsa:2048 -keyout <key> -out <cert> -days 90 -nodes -subj "/CN=BoosterSim CA/O=BoosterSim"`
- Certs stored in `~/Library/Application Support/BoosterSimApp/Certificates/` (excluded from backup, 0o600 permissions)
- Backup/atomic file swap pattern for safe rotation

**notifyutil:**
- Darwin notification posting for instant accessibility setting application
- Invoked inside Simulator via `simctl spawn <udid> notifyutil -p <notification-name>`
- Notifications used: `com.apple.accessibility.reduce-motion`, `com.apple.accessibility.reduce-transparency`, `com.apple.accessibility.grayscale`, `com.apple.accessibility.invert-colors`, `com.apple.accessibility.increase-button-legibility`, `com.apple.accessibility.on-off-switch-labels`, `com.apple.accessibility.differentiate-without-color`, `com.apple.accessibility.prefer-horizontal-text`, `com.apple.accessibility.AccessibilityUIServer`

## Networking — Pulse Protocol

**PulseServer (macOS side):**
- Service: `BoosterSimApp/Services/PulseServer.swift`
- Uses `Network.NWListener` (TCP, peer-to-peer enabled) on a dynamic port
- Bonjour service type: `_pulse._tcp.` with name `"BoosterSimApp"`
- Accepts connections from iOS Simulator apps

**PulseClientConnection (macOS side):**
- Service: `BoosterSimApp/Services/PulseClientConnection.swift`
- Per-client TCP connection handler using `Network.NWConnection`
- Implements Pulse binary protocol: client hello handshake (code 0), ping/pong (code 6), network task created (code 8), network task completed (code 10)
- 10 MB receive buffer safety cap

**PulsePacketDecoder (macOS side):**
- Service: `BoosterSimApp/Services/PulsePacketDecoder.swift`
- Pure static functions for Pulse binary protocol parsing
- Decodes: `PulseClientHello`, `PulseDeviceInfo`, `PulseAppInfo`, `PulseNetworkEvent`, `PulseRequest`, `PulseResponse`

**BoosterSimConnect (iOS side):**
- Framework: `BoosterSimConnect/BoosterSimConnect.swift`
- Built as iOS Simulator framework (`SDKROOT = iphoneos`, `SUPPORTED_PLATFORMS = iphonesimulator`)
- Embedded into macOS app bundle at `Resources/BoosterSimConnect.framework` via build phase script
- Loaded into Simulator apps via `Bundle.load()` / `dlopen` (DEBUG builds only)
- Activates Pulse's `URLSessionProxyDelegate.enableAutomaticRegistration()` to swizzle all `URLSession` traffic
- Configures sensitive header redaction (Authorization, Cookie, API keys, tokens)
- Enables `RemoteLogger` for Bonjour-based discovery and TCP streaming to the macOS app

**ConnectService (orchestration):**
- Service: `BoosterSimApp/Services/ConnectService.swift`
- Manages `PulseServer` lifecycle, decodes events, maintains bounded event list (max 500)

**Pulse (third-party SDK):**
- Package: kean/Pulse ≥ 5.1.0 via SPM
- Products consumed: `Pulse` (network logger) and `PulseProxy` (URLSession swizzling + remote logger)
- Used in both macOS app target and iOS BoosterSimConnect framework target

## macOS System APIs

**Accessibility API (AXUIElement):**
- `BoosterSimApp/Services/AXInspectorService.swift` — Reads accessibility tree from Simulator windows (role, title, description, value, frame, children up to depth 5). Uses raw CFString attribute constants for macOS 26 SDK compatibility.
- `BoosterSimApp/Services/CameraService.swift` — Automates Simulator's Features → Camera menu via AX path traversal (`axFindMenuItem`) and `AXUIElementPerformAction` (kAXPressAction)
- `BoosterSimApp/Services/WindowObserver.swift` — Real-time window move/resize via `AXObserverCreateWithRunLoop` + `AXObserverAddNotification`. Registered for lifecycle notifications (kAXApplicationActivated/Deactivated/Hidden) on the app element and positional notifications (kAXWindowMoved/Resized) on individual window elements.
- Permission: Accessibility (Privacy & Security → Accessibility)

**CoreGraphics Window APIs:**
- `BoosterSimApp/Services/WindowEnumerator.swift` — `CGWindowListCopyWindowInfo` to enumerate all on-screen Simulator windows. Filters by owner name "Simulator", layer 0, and minimum size (50×50). Converts Quartz coordinates (top-origin) to AppKit coordinates (bottom-origin).
- `CGPreflightScreenCaptureAccess()` / `CGRequestScreenCaptureAccess()` in `BoosterSimApp/Services/PermissionManager.swift`

**ScreenCaptureKit:**
- `BoosterSimApp/Services/CaptureService.swift` — `SCShareableContent` for display discovery, `SCStreamConfiguration` + `SCStream` for recording Simulator windows. `SCStreamOutput` receives `CMSampleBuffer` frames. Exports to MP4 via `AVAssetWriter` or GIF via `ImageIO`.

**Security Framework:**
- `BoosterSimApp/Services/CertificateStore.swift` — `SecCertificateCreateWithData`, `SecCertificateCopySubjectSummary`, `SecCertificateCopyValues` for certificate metadata extraction (common name, expiry, SHA256 fingerprint)

**ServiceManagement:**
- `BoosterSimApp/Models/AppSettings.swift` — `SMAppService.mainApp.register()`/`unregister()` for launch-at-login toggle

## Data Storage

**UserDefaults:**
- `BoosterSimApp/Models/AppSettings.swift` — `@AppStorage` keys: `sideWindowPosition`, `showSideWindow`, `launchAtLogin`, `xcodePath`
- `BoosterSimApp/Services/DeepLinkService.swift` — Keys: `DeepLinkHistory`, `DeepLinkFavorites` (JSON-encoded arrays)
- `BoosterSimApp/Services/DesignComparisonService.swift` — Key: `DesignComparisonPresets` (JSON-encoded array)
- `BoosterSimApp/Services/CertificateService.swift` — Persisted install status (device name, UDID) to detect reinstall/rotation need

**Filesystem:**
- Certificate storage: `~/Library/Application Support/BoosterSimApp/Certificates/ca.pem` and `ca.key` (0o600 permissions, excluded from backup)
- DerivedData scanning: `~/Library/Developer/Xcode/DerivedData/*/Logs/Build/LogStoreManifest.plist` — read-only polling by `BoosterSimApp/Services/BuildStatsService.swift` (5-second interval, mtime-based cache, limited to 20 most-recently-modified projects, 30 build records)

**No databases, no cloud storage, no caching layers.**

## Authentication & Identity

**No authentication provider.** The app is a local developer tool with no user accounts.

**macOS Permissions Required:**
- Accessibility — Required for AX tree inspection, window observation, camera menu automation
- Screen Recording — Required for `kCGWindowName` (device name in Simulator window title) and ScreenCaptureKit recording
- DerivedData access — Security-scoped bookmark for reading Xcode build logs (user grants folder access via NSOpenPanel)

## Monitoring & Observability

**Error Tracking:**
- None. No third-party error reporting (Sentry, Crashlytics, etc.)

**Logging:**
- `BoosterSimApp/Utilities/AppLogger.swift` — Centralized `os.Logger` instances under subsystem `com.nextlabs.BoosterSimApp`
  - `AppLogger.windowTracking` — window detection/tracking events
  - `AppLogger.permissions` — permission check/request events
  - `AppLogger.settings` — settings and SMAppService events
  - `AppLogger.certificates` — certificate generation/install/rotation events
- Additional `print()` statements scattered in services for debug-level output (e.g., `[SimCtl]`, `[EnvOverride]`)

## CI/CD & Deployment

**Hosting:**
- Not deployed to any hosting platform. Local macOS application.

**CI Pipeline:**
- GitHub Actions — `BoosterSimApp/.github/workflows/ci.yml`
- Runner: `macos-26`
- Jobs:
  1. `build` — Builds Debug and Release configurations (code signing disabled) with SPM dependency caching
  2. `ui-tests` — Runs `BoosterSimAppUITests/ScreenshotTests`, extracts and uploads PNG screenshots as artifacts (14-day retention)
  3. `build-benchmark` — PR-only job that measures build duration and posts to `$GITHUB_STEP_SUMMARY`
- Uses `xcbeautify` for build output formatting
- Concurrency group `ci-${{ github.ref }}` with cancel-in-progress

## Environment Configuration

**Required system tools:**
- `/usr/bin/xcrun` — Simulator control
- `/usr/bin/openssl` — Certificate generation

**Required macOS permissions (user-granted):**
- Accessibility (Privacy & Security)
- Screen Recording (Privacy & Security)

**User-configurable paths:**
- Xcode path (defaults to auto-detection via `BoosterSimApp/Services/XcodeDetector.swift` checking `/Applications/Xcode.app`, `/Applications/Xcode-beta.app`, etc.)
- DerivedData path (defaults to `~/Library/Developer/Xcode/DerivedData`; user can select manually via NSOpenPanel)

**No `.env` files.** No API keys, tokens, or cloud credentials.

## Webhooks & Callbacks

**Incoming:**
- None. The app has no HTTP server or webhook receiver.

**Outgoing:**
- None. The app does not make any outbound HTTP calls.

**Bonjour Service Advertisement:**
- `PulseServer` in `BoosterSimApp/Services/PulseServer.swift` registers Bonjour service `_pulse._tcp.` named `"BoosterSimApp"` for local network discovery by the iOS `BoosterSimConnect` framework's `RemoteLogger`

**Darwin Notifications (outgoing to Simulator):**
- Posted via `simctl spawn <udid> notifyutil -p <name>` for instant accessibility toggle application

---

*Integration audit: 2026-08-29*