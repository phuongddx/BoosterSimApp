# Codebase Concerns

**Analysis Date:** 2026-08-29

## Tech Debt

**Debug `print()` statements in production code:**
- Issue: 16 `print()` calls in production source files instead of `os.Logger`. `AppLogger` exists at `BoosterSimApp/Utilities/AppLogger.swift` but only covers 4 categories — no `AppLogger.environmentOverride` or `AppLogger.simCtl`.
- Files: `BoosterSimApp/Services/EnvironmentOverrideService.swift` (15 calls), `BoosterSimApp/Services/SimCtlService.swift` (1 call)
- Impact: Debug output leaks to user's stdout in release builds; inconsistent with the `os.Logger` pattern used elsewhere.
- Fix approach: Add `AppLogger.environmentOverride` and `AppLogger.simCtl` categories; replace all `print()` calls with the appropriate `Logger` calls.

**EnvironmentOverrideService is a 279-line monolith with 12 near-identical setter methods:**
- Issue: Every accessibility toggle (`setReduceMotion`, `setGrayscale`, `setSmartInvert`, etc.) follows the same pattern of `print` → set published property → call `setAccessibility()`. 10 of 12 setters are mechanically identical except for the key string and notification name.
- Files: `BoosterSimApp/Services/EnvironmentOverrideService.swift`
- Impact: Adding a new accessibility toggle requires duplicating ~6 lines. Any bug fix in the pattern must be applied 10 times.
- Fix approach: Extract a single `setAccessibilityToggle(key:notification:enabled:udid:)` method; have the individual setters call it. Remove the `print()` calls at the same time.

**SideWindowController init takes 12 service parameters:**
- Issue: `SideWindowController.init` at `BoosterSimApp/Windows/SideWindowController.swift:23-55` receives every service as a constructor argument and passes them to `embedSwiftUIContent`. Adding any new service requires modifying both `AppDelegate.swift` (where it's constructed) and the controller.
- Files: `BoosterSimApp/Windows/SideWindowController.swift`, `BoosterSimApp/App/AppDelegate.swift`
- Impact: Constructor grows linearly with each new feature service.
- Fix approach: Pass an environment container or use SwiftUI's `@Environment` injection at the hosting view level instead of threading through the controller.

**`loadCurrentState` fires 12 concurrent simctl processes on every call:**
- Issue: `EnvironmentOverrideService.loadCurrentState(udid:)` at `BoosterSimApp/Services/EnvironmentOverrideService.swift:55-105` launches 12 separate `xcrun simctl` processes simultaneously (3 `simctl ui` + 1 `simctl spawn defaults read` for Smart Invert + 8 more `simctl spawn defaults read` for accessibility keys). Each process is a separate `Future` that spawns `Process()`.
- Files: `BoosterSimApp/Services/EnvironmentOverrideService.swift`
- Impact: 12 concurrent process spawns when switching simulators. Unnecessary load; could be consolidated into a single `xcrun simctl` call or batched.
- Fix approach: Use `simctl spawn` with a shell script that reads all keys at once, or consolidate into fewer process invocations.

## Security Considerations

**PulseServer listens on all interfaces with no authentication:**
- Risk: `PulseServer.start()` at `BoosterSimApp/Services/PulseServer.swift:34` creates an `NWListener` with `params.includePeerToPeer = true` on port 0 (all interfaces, Bonjour-advertised as `_pulse._tcp`). Any process on the machine (or network, with peer-to-peer enabled) can connect and send binary Pulse packets.
- Files: `BoosterSimApp/Services/PulseServer.swift`, `BoosterSimApp/Services/PulseClientConnection.swift`
- Current mitigation: 10 MB buffer cap per connection (`PulseClientConnection.swift:24`). Unknown packet codes are silently skipped. No data is written to disk from network input.
- Recommendations: Restrict to localhost (`NWEndpoint.Host.loopback`) unless Bonjour discovery is required. Add a handshake secret or token validation. Consider restricting `includePeerToPeer` to false.

**CA private key stored with 0o600 but generated with RSA 2048 and 90-day expiry:**
- Risk: `CertificateStore.runOpenSSL()` at `BoosterSimApp/Services/CertificateStore.swift:78-92` generates a self-signed CA with `rsa:2048` and `-days 90`. RSA 2048 is acceptable but 90 days is very short — users must re-generate and re-install quarterly.
- Files: `BoosterSimApp/Services/CertificateStore.swift`
- Current mitigation: Key and cert files stored with `0o600` permissions in `~/Library/Application Support/BoosterSimApp/Certificates/` (excluded from backup). Staging uses `0o700` temp directory with deferred cleanup. Backup/restore during install is atomic.
- Recommendations: Consider extending to 365 days or making configurable. The certificate is only used for local simulator MITM — the short expiry creates unnecessary re-install friction.

**Deep link input passed directly to `xcrun simctl openurl` without sanitization:**
- Risk: `DeepLinkService.openInSimulatorAsync(udid:)` at `BoosterSimApp/Services/DeepLinkService.swift:67-94` validates that the URL has a scheme but does not restrict which schemes are allowed. A user could pass `file:///` or other potentially dangerous schemes.
- Files: `BoosterSimApp/Services/DeepLinkService.swift`
- Current mitigation: `simctl openurl` itself is sandboxed to the Simulator environment. The URL string is passed as a single argument to `Process.arguments`.
- Recommendations: Whitelist allowed URL schemes (`http://`, `https://`, and user-defined custom schemes). Reject `file://` and other system schemes.

**OpenSSL process invocation for certificate generation:**
- Risk: `CertificateStore` shells out to `/usr/bin/openssl` at `BoosterSimApp/Services/CertificateStore.swift:78`. If the binary is replaced (unlikely on macOS), arbitrary code executes. The `-subj` flag passes the CN inline, avoiding interactive prompts.
- Files: `BoosterSimApp/Services/CertificateStore.swift`
- Current mitigation: Checks `FileManager.default.fileExists(atPath: "/usr/bin/openssl")` before invocation. Output and error are piped (not passed through shell). Timeout of 30 seconds via `DispatchWorkItem`.
- Recommendations: Consider using `Security` framework's `SecCertificateCreateWithData` with programmatically-constructed ASN.1 to eliminate the subprocess dependency. At minimum, verify the binary's code signature before execution.

## Performance Bottlenecks

**CaptureService accumulates all frames in memory during recording:**
- Problem: `CaptureService` at `BoosterSimApp/Services/CaptureService.swift:46` stores every captured `CMSampleBuffer` in `capturedFrames: [CMSampleBuffer]`. At 15 FPS with Retina resolution (e.g., 2× a 430×932 iPhone frame = 860×1864), each frame's pixel buffer is ~6 MB uncompressed. A 30-second recording at 15 FPS = 450 frames × ~6 MB = ~2.7 GB of pixel buffer memory.
- Files: `BoosterSimApp/Services/CaptureService.swift`
- Cause: `CaptureStreamOutput.onFrame` at line 103 appends each frame to the array. No frame dropping or size limit. Export only happens after recording stops.
- Improvement path: Write frames to a temporary file-backed buffer during recording (e.g., `AVAssetWriter` in real-time instead of post-hoc). Add a maximum recording duration or memory guard. Downscale before storing (the `quality` setting controls FPS but not resolution — config at line 90 always uses `display.width * 2`).

**GIF export creates a new `CIContext()` per frame:**
- Problem: `CaptureService.exportAsGIF()` at `BoosterSimApp/Services/CaptureService.swift:258` creates `CIContext()` inside the frame loop. `CIContext` allocation is expensive (~tens of ms) and should be created once and reused.
- Files: `BoosterSimApp/Services/CaptureService.swift:258`
- Cause: `let context = CIContext()` is inside the `for frame in capturedFrames` loop.
- Improvement path: Create `CIContext()` once before the loop and reuse it for all frames.

**BuildStatsService scans all DerivedData projects every 5 seconds:**
- Problem: `BuildStatsService.scanDerivedData()` at `BoosterSimApp/Services/BuildStatsService.swift:36-63` runs on a 5-second `Timer`, enumerates all directories in `~/Library/Developer/Xcode/DerivedData`, reads `contentModificationDate` for each, and parses `LogStoreManifest.plist` for any changed files. Large DerivedData folders (100+ projects) cause noticeable I/O.
- Files: `BoosterSimApp/Services/BuildStatsService.swift`
- Cause: Polling interval is fixed at 5 seconds. The 20-project prefix limit helps but the `contentsOfDirectory` call still enumerates everything.
- Improvement path: Use `FSEvents` or `DispatchSource.makeFileSystemObjectSource` to watch the DerivedData directory for changes instead of polling. Increase the poll interval to 15-30 seconds as a quick win.

**SimulatorWindowTracker polls CGWindowList every 2 seconds as fallback:**
- Problem: `SimulatorWindowTracker.startPolling()` at `BoosterSimApp/Services/SimulatorWindowTracker.swift:162-165` runs a 2-second `Timer` that calls `CGWindowListCopyWindowInfo` and `scanAndUpdate()` even when no Simulator windows exist.
- Files: `BoosterSimApp/Services/SimulatorWindowTracker.swift`
- Cause: The poll is a fallback for edge cases where AXObserver misses events. It runs unconditionally once `startTracking()` is called.
- Improvement path: Disable the poll timer when no simulator PIDs are detected and re-enable on `didLaunchApplicationNotification`. Increase interval to 5 seconds.

## Fragile Areas

**AX API calls use force casts on `AXValue` types:**
- Files: `BoosterSimApp/Services/AXInspectorService.swift:94`, `BoosterSimApp/Services/WindowObserver.swift:138,140`
- Why fragile: `AXValueGetValue` requires an `UnsafeMutableRawPointer`, forcing the `as! AXValue` cast. If AX returns an unexpected type (e.g., a different AXValue variant), the force cast crashes. The `CFGetTypeID` guard checks that it's an AXValue but not that it's the correct AXValue type variant.
- Safe modification: Add a separate `CFGetTypeID` check for the specific AXValue variant (point vs. rect vs. size) before casting, or use a safe wrapper that returns `nil` on type mismatch.

**Force unwrap on NWEndpoint.Port in PulseServer:**
- Files: `BoosterSimApp/Services/PulseServer.swift:35`
- Why fragile: `NWEndpoint.Port(rawValue: 0)!` — `0` is a valid raw value for port 0 (auto-assign), so this unwrap is safe in practice. However, it violates the project's own code standard ("No `try!` or `as!` force-casts on user data" from `docs/code-standards.md`) and sets a bad precedent.
- Safe modification: Use `NWEndpoint.Port(rawValue: 0)` with `guard let` or the `??` operator with a fallback. Consider a static `anyPort` constant.

**Force unwrap on streamOutput in CaptureService:**
- Files: `BoosterSimApp/Services/CaptureService.swift:103`
- Why fragile: `streamOutput!` is used immediately after assignment on the line above. If `CaptureStreamOutput.init` fails (it can't — it's a simple closure capture), the unwrap would crash. Low risk but unnecessary.
- Safe modification: Use `guard let streamOutput` and return with an error.

**Single-instance check via NSRunningApplication count is racy:**
- Files: `BoosterSimApp/App/AppDelegate.swift:57-61`
- Why fragile: `applicationDidFinishLaunching` checks `runningInstances.count > 1` and calls `NSApp.terminate(nil)`. Between the check and termination, a third instance could launch. The LSUIElement mode (menu-bar app) means the user can't see duplicate instances easily.
- Safe modification: Use a file lock (`flock` on a file in `~/Library/Application Support/BoosterSimApp/`) or `XPC` singleton pattern for reliable mutual exclusion.

**Screen height assumption uses first screen only for Y-flip:**
- Files: `BoosterSimApp/Services/WindowObserver.swift:143`, `BoosterSimApp/Services/AXInspectorService.swift:38`
- Why fragile: Both use `NSScreen.screens.first?.frame.height ?? 0` to convert between Quartz (top-origin) and AppKit (bottom-origin) coordinates. If the Simulator window is on a secondary display with a different height, the Y coordinate will be wrong, causing the side panel to misalign.
- Safe modification: Determine which screen the Simulator window is on (using `NSScreen.screens.contains(where:)` with the window's frame) and use that screen's height for the flip.

**EnvironmentOverrideService silently swallows all simctl errors:**
- Files: `BoosterSimApp/Services/EnvironmentOverrideService.swift` (all `.sink(receiveCompletion: { _ in }, ...)` calls)
- Why fragile: Every setter uses `.sink(receiveCompletion: { _ in }, receiveValue: { _ in })` — errors from `xcrun simctl` are silently discarded. If a command fails (wrong UDID, simulator mid-reboot), the published state is already optimistically updated, leaving the UI and simulator out of sync. This was documented as a root cause in debugging sessions (see `plans/reports/debugger-0327-1725-bold-text-toggle-not-working.md`).
- Safe modification: At minimum, log errors via `AppLogger`. Consider reverting optimistic state updates on failure, or exposing a `lastError: String?` published property.

## Scaling Limits

**ConnectService stores maximum 500 network events in memory:**
- Current capacity: `ConnectService.maxEvents = 500` at `BoosterSimApp/Services/ConnectService.swift:29`. Each `NetworkEvent` holds optional `requestBody` and `responseBody` `Data` blobs.
- Limit: With large request/response bodies (e.g., image uploads, JSON payloads of 100+ KB), 500 events could consume significant memory. The `removeFirst` truncation is O(n) on Array.
- Scaling path: Use a ring buffer (Array with head index) for O(1) truncation. Add a maximum total size cap in addition to the event count cap. Consider streaming body data to disk.

**AXInspectorService loads the entire accessibility tree to depth 5:**
- Current capacity: `AXInspectorService.maxDepth = 5` at `BoosterSimApp/Services/AXInspectorService.swift:32`. Each level fans out to all children. Complex app screens (e.g., settings pages with many table rows) could produce thousands of `AXNode` objects.
- Limit: No limit on total node count — only depth is bounded. A very wide tree at depth 5 could still produce a large result set.
- Scaling path: Add a `maxNodes` cap (e.g., 2000) that stops recursion when reached. Show a "tree truncated" indicator in the UI.

## Dependencies at Risk

**Hardcoded dependency on `/usr/bin/xcrun` and `/usr/bin/openssl`:**
- Risk: Both paths are assumed to exist. `SimCtlService` checks for `/usr/bin/xcrun` before each call, but `CertificateStore` only checks before `generate()`. If Xcode is moved or a future macOS version changes the path, all simctl features break silently.
- Impact: Core features (environment overrides, build stats, deep links, certificates, camera) all depend on `xcrun simctl`.
- Migration plan: Use `XcodeDetector` (already exists at `BoosterSimApp/Services/XcodeDetector.swift`) to resolve the actual Xcode path and derive `xcrun` from it. For OpenSSL, fall back to `Security` framework APIs.

**HealthKit entitlement declared but no HealthKit usage in source:**
- Risk: `BoosterHealth-Entitlements.plist` declares `com.apple.developer.healthkit` and `com.apple.developer.healthkit.access`. No Swift file in `BoosterSimApp/` imports HealthKit or references HK types. This is leftover from a planned feature (see `plans/0328-1642-health-data-generator/`).
- Impact: Unused entitlement may cause App Store review questions or unnecessary permission prompts. May also prevent distribution outside the Mac App Store if not justified.
- Migration plan: Remove the entitlement entries if the HealthKit feature is not shipping in the current release.

## Missing Critical Features

**No timeout on SimCtlService process execution:**
- Problem: `SimCtlService.run()` at `BoosterSimApp/Services/SimCtlService.swift:34-72` spawns `Process()` and calls `waitUntilExit()` with no timeout. If `xcrun simctl` hangs (known to happen with unresponsive simulators), the background thread blocks indefinitely.
- Blocks: Any feature using simctl (environment overrides, certificate install, deep link, build stats, camera).
- Fix approach: Add a `DispatchWorkItem` timeout (like `CertificateStore` already does at line 83-86) or use `process.waitUntilExit(for: timeout)` if available.

**No error propagation from PulseServer state changes:**
- Problem: `PulseServer.start()` at `BoosterSimApp/Services/PulseServer.swift:40-45` has empty `switch` cases for `.ready`, `.failed`, and default — all errors are silently swallowed. The `ConnectService` depends on `connectionState` to show UI status, but server-level failures (port in use, permission denied) are invisible.
- Blocks: Network debugging feature shows no feedback when the server fails to start.
- Fix approach: Add an `onError: ((String) -> Void)?` callback or `@Published var lastError: String?` to `PulseServer`. Call it from the `.failed` state handler.

**CI does not run unit tests:**
- Problem: `.github/workflows/ci.yml` has `build` and `ui-tests` jobs but no job that runs `BoosterSimAppTests`. The `ui-tests` job only runs `ScreenshotTests` — the two unit test files (`BoosterSimAppTests.swift`, `CertificateServiceTests.swift`) are never executed in CI.
- Blocks: Unit test regressions go undetected in pull requests.
- Fix approach: Add a `test` job to `ci.yml` that runs `xcodebuild test -only-testing:BoosterSimAppTests`.

## Test Coverage Gaps

**No tests for PulseServer, PulseClientConnection, or PulsePacketDecoder:**
- What's not tested: The entire Pulse binary protocol (header parsing, zlib decompression, packet dispatch, client handshake). These are complex pure-logic components ideal for unit testing.
- Files: `BoosterSimApp/Services/PulseServer.swift`, `BoosterSimApp/Services/PulseClientConnection.swift`, `BoosterSimApp/Services/PulsePacketDecoder.swift`
- Risk: Binary protocol regressions (endian handling, buffer boundaries, decompression) will only be caught by manual testing against a real Simulator.
- Priority: High — protocol parsing is the most testable and most fragile code.

**No tests for SimCtlService, EnvironmentOverrideService, or ConnectService:**
- What's not tested: simctl process spawning, environment override state management, network event storage and truncation.
- Files: `BoosterSimApp/Services/SimCtlService.swift`, `BoosterSimApp/Services/EnvironmentOverrideService.swift`, `BoosterSimApp/Services/ConnectService.swift`
- Risk: State machine regressions (especially the `cancellables` pattern), event truncation logic, and timeout behavior.
- Priority: Medium — these have external dependencies (simctl, NWConnection) but their state management logic is testable.

**No tests for SimulatorWindowTracker, WindowObserver, or WindowEnumerator:**
- What's not tested: Simulator window detection, device type classification from simctl JSON, AX observer lifecycle, CGWindowList coordinate conversion.
- Files: `BoosterSimApp/Services/SimulatorWindowTracker.swift`, `BoosterSimApp/Services/WindowObserver.swift`, `BoosterSimApp/Services/WindowEnumerator.swift`
- Risk: Multi-monitor Y-flip bugs, observer cleanup on simulator quit, stale PID handling.
- Priority: Medium — core positioning logic but requires mocking AX/CG APIs.

**No tests for CertificateStore file management:**
- What's not tested: Atomic file install (backup → move → cleanup), rollback on failure, PEM-to-DER conversion, metadata extraction.
- Files: `BoosterSimApp/Services/CertificateStore.swift`
- Risk: File corruption during certificate rotation, backup restoration failure, metadata parsing edge cases.
- Priority: Medium — the atomic install pattern is complex and a regression would silently break certificate management.

**Only 2 unit test files for 7,584 lines of Swift:**
- What's not tested: The vast majority of business logic. `BoosterSimAppTests/CertificateServiceTests.swift` tests transition logic (pure enum). `BoosterSimAppTests/BoosterSimAppTests.swift` is a placeholder.
- Files: All files under `BoosterSimApp/Services/`, `BoosterSimApp/Windows/`, `BoosterSimApp/Views/`
- Risk: Any refactor or new feature has no regression safety net.
- Priority: High — the codebase is at a size where untested refactoring is risky.

---

*Concerns audit: 2026-08-29*