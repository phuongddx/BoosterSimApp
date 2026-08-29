# External Integrations

**Analysis Date:** 2026-08-29

## APIs & External Services

**iOS Simulator Control (xcrun simctl):**
- All Simulator control is routed through `xcrun simctl` CLI commands
- macOS host service: `BoosterSimApp/Services/SimCtlService.swift` — Combine-based async wrapper spawning `Process` for each command
- CLI tool service: `booster-sim-cli/Sources/boostersim/Services/SimCtlService.swift` — Synchronous `Process` wrapper
- Commands used: `simctl io tap/swipe/type/screenshot`, `simctl ui appearance/increase_contrast/content_size`, `simctl status_bar`, `simctl spawn`, `simctl list devices --json`, `simctl openurl`, `simctl keychain reset`
- Authentication: None (local tool)

**OpenSSL (system):**
- CA certificate generation via `/usr/bin/openssl` CLI
- Implementation: `BoosterSimApp/Services/CertificateStore.swift`
- Command: `openssl req -x509 -newkey rsa:2048 -keyout ... -out ... -days 90 -nodes -subj /CN=BoosterSim CA/O=BoosterSim`
- Authentication: None (local tool)

## Data Storage

**Databases:**
- None. No database dependencies.

**File Storage:**
- **Local filesystem only** — All persistent data stored locally:
  - `~/Library/Application Support/BoosterSimApp/Certificates/` — CA key and certificate (`ca.key`, `ca.pem`) with 0o600 permissions, excluded from backup
  - `UserDefaults` — Deep link history/favorites, design comparison presets, onboarding completion, certificate install status
  - `~/Library/Developer/Xcode/DerivedData/` — Read-only access for Xcode build stats monitoring

**Caching:**
- In-memory only:
  - `SimulatorWindowTracker` — Device info cache (`deviceInfoCache: [String: DeviceInfo]`)
  - `BuildStatsService` — Manifest mtime cache and record cache for 5-second polling

## Authentication & Identity

**Auth Provider:**
- None. The app has no user authentication.

**System Permissions (macOS):**
- Accessibility (AXIsProcessTrusted) — Required for window tracking, AX inspection, camera toggle
  - Requested via `AXIsProcessTrusted()` in `BoosterSimApp/Services/PermissionManager.swift`
- Screen Recording (CGPreflightScreenCaptureAccess / CGRequestScreenCaptureAccess) — Required for screen capture
  - Requested in `BoosterSimApp/Services/PermissionManager.swift`
- DerivedData access — Security-scoped bookmark for `~/Library/Developer/Xcode/DerivedData/`
  - Managed in `BoosterSimApp/Services/PermissionManager.swift`

## Monitoring & Observability

**Error Tracking:**
- None. No third-party error tracking service.

**Logs:**
- `OSLog` via `BoosterSimApp/Utilities/AppLogger.swift`
  - Subsystem: `com.nextlabs.BoosterSimApp`
  - Categories: `WindowTracking`, `Permissions`, `Settings`, `Certificates`
  - Filter in Console.app by subsystem
- `print()` statements used extensively throughout services for debug logging

## CI/CD & Deployment

**Hosting:**
- Not deployed to any hosting platform. This is a local macOS application.

**CI Pipeline:**
- GitHub Actions — `.github/workflows/ci.yml`
  - Runs on `macos-26` runners
  - 3 jobs: `build` (Debug + Release matrix), `ui-tests` (screenshot capture), `build-benchmark` (PR-only build time measurement)
  - SPM package caching via `actions/cache@v4`
  - Build artifacts: `actions/upload-artifact@v4` for xcresult bundles and screenshots
  - Code signing disabled in CI (`CODE_SIGN_IDENTITY=""`)
  - Uses `xcbeautify` for build output formatting

## Environment Configuration

**Required env vars:**
- None. The app requires no environment variables.

**Required system tools:**
- `/usr/bin/xcrun` — Must be present for all Simulator operations
- `/usr/bin/openssl` — Must be present for certificate generation
- Xcode.app — Must be installed at a known path (detected by `BoosterSimApp/Services/XcodeDetector.swift`)

**Secrets location:**
- No secrets management. The app generates its own self-signed CA certificate locally.

## Webhooks & Callbacks

**Incoming:**
- None.

**Outgoing:**
- None.

## Inter-Process Communication

**Pulse TCP Protocol (custom):**
- macOS app hosts a TCP server (`BoosterSimApp/Services/PulseServer.swift`) using Apple's `Network` framework
- Bonjour service type: `_pulse._tcp.` with name "BoosterSimApp"
- iOS companion framework (`BoosterSimConnect/BoosterSimConnect.swift`) broadcasts via Pulse's `RemoteLogger`
- Binary protocol parsed by `BoosterSimApp/Services/PulsePacketDecoder.swift` — implements Pulse's packet codes (clientHello, serverHello, ping, store events for network task lifecycle)
- Connection management in `BoosterSimApp/Services/PulseClientConnection.swift`

**Accessibility API (AXUIElement):**
- Reads Simulator window hierarchy and properties via `AXUIElementCopyAttributeValue`
- Real-time window notifications via `AXObserverCreate` + `AXObserverAddNotification` in `BoosterSimApp/Services/WindowObserver.swift`
- Menu automation (camera toggle) via `AXUIElementPerformAction` in `BoosterSimApp/Services/CameraService.swift`
- Simulator window tracking via `CGWindowListCopyWindowInfo` polling + AXObserver in `BoosterSimApp/Services/SimulatorWindowTracker.swift`

**Xcode Simulator (xcrun simctl):**
- Deep link opening via `simctl openurl <udid> <url>` in `BoosterSimApp/Services/DeepLinkService.swift`
- Environment overrides via `simctl spawn <udid> defaults write/notifyutil` in `BoosterSimApp/Services/EnvironmentOverrideService.swift`
- Certificate install/keychain reset via `simctl addrootcert/simctl keychain reset` in `BoosterSimApp/Services/CertificateService.swift`

---

*Integration audit: 2026-08-29*
