# External Integrations

**Analysis Date:** 2026-08-31

## APIs & External Services

**None (cloud).** The app makes no outbound HTTP calls to third-party services — every `https://` literal in sources is preview/sample data (e.g. `BoosterSimApp/Views/SideWindow/network/TrafficDetailView.swift:286`). All "integrations" are with **local system tooling** (simctl, Xcode, Simulator.app) and **loopback TCP** to the iOS Simulator.

**Xcode Simulator (primary domain):**
- `xcrun simctl` — invoked as a subprocess for nearly every device action
  - Seam: `BoosterSimApp/Services/SimCtlService.swift` (executes `/usr/bin/xcrun simctl <args>` via `Process`; machine-wide serial queue; concurrent stdout/stderr drain; 64 KB stdin bound; 30 s per-verb Combine timeouts). Consumers take the `SimCtlRunning` protocol for test doubles (see `BoosterSimAppTests/ScriptedSimCtl.swift`).
  - Verbs exercised (with files): `list devices --json` (`BoosterSimApp/Services/SimulatorWindowTracker.swift` — separate direct `Process`), `listapps`, `launch` (incl. `--terminate-running-process`), `terminate`, `install`, `uninstall` (`BoosterSimApp/Services/AppActionService.swift`), `openurl` (`BoosterSimApp/Services/DeepLinkService.swift`), `push <udid> <bundle> -` with stdin payload (`BoosterSimApp/Services/AppActionService.swift:324`), `privacy grant|revoke <service>` and `privacy reset all` (`BoosterSimApp/Models/PrivacyPermission.swift`, `AppActionService`), `status_bar override|clear` (`BoosterSimApp/Services/StatusBarService.swift`), `ui appearance|increase_contrast|content_size` (`BoosterSimApp/Services/EnvironmentOverrideService.swift`), `spawn <udid> defaults read|write|delete` + `spawn <udid> notifyutil -p` (`EnvironmentOverrideService`, `BoosterSimApp/Services/UserDefaultsEditorService.swift`, `AppActionService` locale writes), `keychain add-root-cert` / `keychain reset` (`BoosterSimApp/Services/CertificateService.swift`), `location set <lat>,<lon>` / `location clear` (`AppActionService`), `pbsync host|device` clipboard sync (`AppActionService`), `get_app_container ... data` (`BoosterSimApp/Services/UserDefaultsEditorService.swift:172`).
- Simulator.app UI automation (Accessibility API, see below): camera menu toggling via menu-item paths `Features → Camera → Front/Back Camera → Mac Built-In Camera` (`BoosterSimApp/Services/CameraService.swift`).
- Simulator.app preferences written in-process via `CFPreferences` in domain `com.apple.iphonesimulator` (key `ShowSingleTouches`) with snapshot/restore — `BoosterSimApp/Services/TouchIndicatorController.swift:85-88`.
- Xcode / DerivedData filesystem probing: `BoosterSimApp/Services/XcodeDetector.swift` (candidate paths `/Applications/Xcode.app` etc.) and `BoosterSimApp/Services/DerivedDataAppScanner.swift` (scans `~/Library/Developer/Xcode/DerivedData/<tree>/Build/Products/*-iphonesimulator/*.app`, reads each `.app`'s `Info.plist`).
- `/usr/bin/openssl` — local CA generation (`req -x509 -newkey rsa:2048 -days 90 -subj /CN=BoosterSim CA/O=BoosterSim`) in `BoosterSimApp/Services/CertificateStore.swift`; installed into a simulator via `simctl keychain add-root-cert`.

**macOS TCC Permissions (host):**
- Accessibility: `AXIsProcessTrusted()` + settings deep link + 1 s polling — `BoosterSimApp/Services/PermissionManager.swift`
- Screen Recording: `CGPreflightScreenCaptureAccess()` / `CGRequestScreenCaptureAccess()` + polling — same file
- DerivedData access: security-scoped bookmark selection — `PermissionManager.checkDerivedData()`/`selectDerivedData()`

## The Connect Pipeline (iOS app ↔ Mac, loopback TCP + Bonjour)

The flagship integration: an iOS app running inside Simulator streams its `URLSession` traffic to this Mac app and receives network-condition commands.

1. **Injection** — the developer's iOS app (DEBUG + simulator builds only) loads the framework: `Bundle(path: "/Applications/BoosterSim.app/Contents/Resources/BoosterSimConnect.framework")?.load()` (snippet shown in `BoosterSimApp/Views/SideWindow/network/ConnectSetupView.swift`). The framework is built by the app target's shell build phase (`A1B2C3D4E5F6A7B8C9D0E1F2` in `BoosterSimApp.xcodeproj/project.pbxproj`).
2. **Activation** — `BoosterSimConnect/BoosterSimConnect.swift` enables `PulseProxy` `URLSession` swizzling (`URLSessionProxyDelegate.enableAutomaticRegistration()`), registers a custom `URLProtocol` (`BoosterNetworkProtocol.enableAutomaticRegistration()`), starts `BoosterCommandClient.shared.start()`, and enables Pulse `RemoteLogger` broadcasting. Sensitive headers (`Authorization`, `Cookie`, tokens) and query items (`password`, `token`, `secret`, `api_key`, `access_token`) are redacted at the `NetworkLogger` configuration.
3. **Traffic up** (`_pulse._tcp.` Bonjour service) — `BoosterSimApp/Services/PulseServer.swift` (`NWListener`, `includePeerToPeer = true`) accepts connections; `BoosterSimApp/Services/PulseClientConnection.swift` frames them; `BoosterSimApp/Services/PulsePacketDecoder.swift` implements Pulse's binary wire protocol: 5-byte header `[code: UInt8][contentSize: UInt32 BE]`, zlib-decompressed (via `NSData.decompressed(using: .zlib)`) JSON bodies, packet codes 0–10 (clientHello/serverHello/ping/storeEvent*), and a 3×UInt32-BE manifest splitting JSON message + request body + response body for `networkTaskCompleted`.
4. **Commands down** (`_booster-cmd._tcp.` Bonjour service) — `BoosterSimApp/Services/CommandServer.swift` broadcasts length-prefixed JSON `BoosterCommand` snapshots (airplane mode, block rules, throttle specs; 10 MB frame cap; reconcile-push on client connect). `NetworkConditionService` is the state hub (`BoosterSimApp/Services/NetworkConditionService.swift`), behind the `CommandBroadcasting` seam (tests inject `NoopCommandBroadcast`).
5. **Client side** — `BoosterSimConnect/BoosterCommandClient.swift` browses via `NWBrowser`, reassembles frames (`BoosterSimConnect/CommandFrameAssembler.swift`), applies snapshots through `BoosterSimConnect/NetworkConditionController.swift`; `BoosterSimConnect/BoosterNetworkProtocol.swift` enforces verdicts on requests (guard marker `X-Booster-Internal`, airplane → `-1009`, block rule → `-1004`, throttle pacing in `BoosterSimConnect/ThrottlePacing.swift`).
6. **Display** — decoded events become `NetworkEvent` rows in `BoosterSimApp/Services/ConnectService.swift` (ring buffer of 500).

**Shared-contract rule:** the framework cannot import the Mac target, so `BoosterCommand`/`BlockRule`/`ConditionVerdict` are mirrored by hand in `BoosterSimConnect/NetworkConditionController.swift` and guarded by `BoosterSimAppTests/CommandPayloadTests.swift`.

## Data Storage

**Databases:**
- None. No SQLite, Core Data, or CloudKit.

**File Storage:**
- Local filesystem only: captures staged and exported in place (`BoosterSimApp/Services/CaptureSaveRouter.swift` routes to Desktop / clipboard / custom folder / ask-me via `NSSavePanel`); CA files under `~/Library/Application Support/BoosterSimApp/Certificates/` (0700 dir, 0600 files, excluded from backup).

**Caching:**
- In-memory only: device info cache in `BoosterSimApp/Services/SimulatorWindowTracker.swift`, event ring buffers in `ConnectService`. `UserDefaults` (@AppStorage) persists settings and deep-link history/favorites (`BoosterSimApp/Services/DeepLinkService.swift`).

## Authentication & Identity

**Auth Provider:**
- None. No sign-in, no OAuth, no account system. The only security-adjacent identity is the codesigning team `EQ8B89SPCX` (automatic signing, `BoosterSimApp.xcodeproj/project.pbxproj`).

## Monitoring & Observability

**Error Tracking:**
- None (no Crashlytics/Sentry/etc.)

**Logs:**
- Apple unified logging (OSLog) via `BoosterSimApp/Utilities/AppLogger.swift` — subsystem `com.nextlabs.BoosterSimApp`, categories: `WindowTracking`, `Permissions`, `Settings`, `Certificates`, `Network`, `Capture`, `Actions`, `Design`. Message privacy: dynamic strings interpolated with `privacy: .public` only when safe. A legacy `print("[SimCtl] ...")` trace remains in `BoosterSimApp/Services/SimCtlService.swift:106`.

## CI/CD & Deployment

**Hosting:**
- Local macOS app; CI on GitHub Actions `macos-26` runners (`.github/workflows/ci.yml`).

**CI Pipeline:**
- Jobs: `build` (Debug+Release matrix, codesigning disabled), `ui-tests` (runs `BoosterSimAppUITests/ScreenshotTests`, exports screenshots via `xcrun xcresulttool`, uploads artifacts), `build-benchmark` (PR-only timing summary). SPM caching keyed on `Package.resolved`. `xcbeautify` for log formatting.

## Environment Configuration

**Required env vars:**
- None. Everything is derived from the local system (xcrun path, Xcode path, DerivedData root, Simulator pid).

**Secrets location:**
- No secrets in the repo. The only secret-like material is the locally generated CA private key at `~/Library/Application Support/BoosterSimApp/Certificates/ca.key` (never committed; paths are redacted from user-facing errors by `CertificateStore.redactPaths`).

## Webhooks & Callbacks

**Incoming:**
- None (no HTTP server). The TCP listeners (`PulseServer`, `CommandServer`) are loopback/Bonjour peers, not HTTP endpoints.

**Outgoing:**
- None.

## macOS System Integration Points (reference)

| Concern | API | File |
|---|---|---|
| Window discovery | `CGWindowList` polling + `NSWorkspace` notifications | `BoosterSimApp/Services/SimulatorWindowTracker.swift` |
| Window lifecycle events | `AXObserver` (`kAXWindowMovedNotification`, created/destroyed/miniaturized) | `BoosterSimApp/Services/WindowObserver.swift` |
| AX tree inspection | `AXUIElementCopyAttributeValue` walker (depth 5, 2 s messaging timeout) | `BoosterSimApp/Services/AXInspectorService.swift` |
| AX highlight overlay | `AXHighlightPanel` | `BoosterSimApp/Windows/AXHighlightPanel.swift` |
| Window screenshots | ScreenCaptureKit window filter (desktop-independent, avoids recursive self-capture) | `BoosterSimApp/Services/ScreenshotService.swift` |
| Screen recording | `SCStream` + `SCRecordingOutput` straight to disk | `BoosterSimApp/Services/RecordingService.swift` |
| Export | `AVAssetExportSession` (MP4/MOV passthrough), ImageIO GIF | `BoosterSimApp/Services/CaptureExporter.swift` |
| Launch at login | `SMAppService` | `BoosterSimApp/Models/AppSettings.swift` |
| Clipboard | `NSPasteboard` (capture destination) | `BoosterSimApp/Services/CaptureSaveRouter.swift` |

---

*Integration audit: 2026-08-31*
