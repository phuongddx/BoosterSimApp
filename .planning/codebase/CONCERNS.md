# Codebase Concerns

**Analysis Date:** 2026-08-29

## Tech Debt

**Unwired Views — StatusBarSectionView, BuildStatsSectionView, AXTreeView, CameraView:**
- Issue: Four fully-implemented SwiftUI views exist in `BoosterSimApp/Views/SideWindow/` but are not wired into any tab. `SideTab` enum (`BoosterSimApp/Views/SideWindow/SideTab.swift`) defines only four tabs: `.capture`, `.design`, `.actions`, `.network`. `ActionsTabView` (`BoosterSimApp/Views/SideWindow/tabs/ActionsTabView.swift`) only embeds `EnvironmentOverridesView` and `DeepLinkSectionView`. The services for these views (`StatusBarService`, `BuildStatsService`, `AXInspectorService`, `CameraService`) are instantiated in `AppDelegate` and injected as environment objects in `SideWindowView`, but no tab renders them.
- Files: `BoosterSimApp/Views/SideWindow/StatusBarSectionView.swift`, `BoosterSimApp/Views/SideWindow/BuildStatsSectionView.swift`, `BoosterSimApp/Views/SideWindow/AXTreeView.swift`, `BoosterSimApp/Views/SideWindow/CameraView.swift`, `BoosterSimApp/Views/SideWindow/SideTab.swift`, `BoosterSimApp/Views/SideWindow/tabs/ActionsTabView.swift`
- Impact: Users cannot access status bar presets, build stats, VoiceOver navigation, or camera routing. Services run and consume resources (timers, simctl calls) for features nobody can use.
- Fix approach: Add new `SideTab` cases (e.g. `.tools`, `.a11y`) or consolidate these views into the existing `.actions` tab. Remove services from `AppDelegate` initialization if deferring.

**Placeholder Children in AXTreeView:**
- Issue: `AXNodeRowView` in `BoosterSimApp/Views/SideWindow/AXTreeView.swift:122-131` renders the text "Children not yet loaded" when a node is expanded. No mechanism exists to load child nodes — `AXInspectorService` (`BoosterSimApp/Services/AXInspectorService.swift`) fetches only root-level nodes via `loadRoot(for:)`.
- Files: `BoosterSimApp/Views/SideWindow/AXTreeView.swift:122-131`, `BoosterSimApp/Services/AXInspectorService.swift`
- Impact: The VoiceOver Navigator tree is flat — users can see top-level elements but cannot drill into the hierarchy, which is the primary value of an accessibility inspector.
- Fix approach: Add a `loadChildren(for:)` method to `AXInspectorService` that calls `fetchChildren(of:depth:)` (already implemented at line 61) on the underlying AXUIElement, and wire it into `AXNodeRowView`'s expand action.

**Placeholder Timing Metrics in TrafficDetailView:**
- Issue: The Metrics tab in `BoosterSimApp/Views/SideWindow/network/TrafficDetailView.swift:117-127` shows only a total-duration bar (from `PulseNetworkEvent.metrics.taskInterval.duration`) and the static text "Detailed timing requires Pulse integration". No DNS lookup, TLS handshake, TTFB, or download breakdown is displayed.
- Files: `BoosterSimApp/Views/SideWindow/network/TrafficDetailView.swift:117-127`
- Impact: The metrics tab provides minimal value for performance debugging. Users must look at raw timing numbers and manually calculate sub-phases.
- Fix approach: Parse `URLSessionTaskTransactionMetrics` fields (fetch start, connect start, response start) from the Pulse protocol and render per-phase timing bars.

**Inconsistent Logging — `print()` vs `AppLogger`:**
- Issue: `SimCtlService` (`BoosterSimApp/Services/SimCtlService.swift:35`) and `EnvironmentOverrideService` (`BoosterSimApp/Services/EnvironmentOverrideService.swift:109,117,126,133,140,146,155,181,190,198,206,229,237,245,253`) use bare `print("[ServiceName] ...")` statements instead of the project's `AppLogger` utility (`BoosterSimApp/Utilities/AppLogger.swift`). `AppLogger` supports log levels, OSLog integration, and privacy redaction per `docs/code-standards.md`.
- Files: `BoosterSimApp/Services/SimCtlService.swift:35`, `BoosterSimApp/Services/EnvironmentOverrideService.swift` (16 occurrences)
- Impact: Log output bypasses OSLog, cannot be filtered in Console.app, and may log sensitive data (UDIDs appear in print statements) without the privacy redaction `AppLogger` provides.
- Fix approach: Replace all `print("[ClassName] ...")` calls with `AppLogger.<category>.<level>("...")` calls. Use `privacy: .private` for UDID parameters.

**Direct Process Spawning in SimulatorWindowTracker:**
- Issue: `refreshDeviceTypeCache()` in `BoosterSimApp/Services/SimulatorWindowTracker.swift:60-84` creates a `Process()` directly to run `xcrun simctl list devices --json`, bypassing `SimCtlService` (`BoosterSimApp/Services/SimCtlService.swift`). The project's code standards (`docs/code-standards.md`) and plan reports explicitly prohibit direct subprocess spawning.
- Files: `BoosterSimApp/Services/SimulatorWindowTracker.swift:60-84`
- Impact: Error handling is weaker (silently returns on failure), no logging, no timeout support. Inconsistent with all other simctl callers.
- Fix approach: Route through `SimCtlService.run()` and handle the JSON parsing from the returned string.

## Known Bugs

**`CameraService` dispatches UI work to global queue:**
- Symptoms: `CameraService` (`BoosterSimApp/Services/CameraService.swift:53-57`) uses `DispatchQueue.global(qos: .userInitiated).async` for `probeSupport()` and `pressItem()`. Inside the global block, it reads AX attributes (which are UI operations on the Simulator process) and calls `AXUIElementPerformAction`. While AX calls are thread-safe, the `Thread.sleep(forTimeInterval: 0.15)` in `pressItem` (line 67) is a fragile timing assumption.
- Files: `BoosterSimApp/Services/CameraService.swift:53-57,67`
- Trigger: Toggle camera routing while Simulator is busy or slow to respond.
- Workaround: None.

**`PulseServer` silently swallows listener state changes and errors:**
- Symptoms: In `BoosterSimApp/Services/PulseServer.swift:45-52`, the `stateUpdateHandler` has empty `break` branches for `.ready`, `.failed`, and all other states. The `catch` block on line 52 is also empty. There is no logging when the server fails to start or when the Bonjour service encounters an error.
- Files: `BoosterSimApp/Services/PulseServer.swift:45-52`
- Trigger: Port conflict, network permission denial, or Bonjour registration failure.
- Workaround: None — the Connect UI shows "searching" indefinitely with no diagnostic output.

## Security Considerations

**Pulse TCP Server has no authentication or encryption:**
- Risk: `PulseServer` (`BoosterSimApp/Services/PulseServer.swift:37`) opens a TCP listener with `params.includePeerToPeer = true` on a Bonjour-advertised port (`_pulse._tcp.`). Any process on the local network (or same machine) can connect and inject fabricated `PulseNetworkEvent` data, which populates the network traffic UI in `ConnectService`.
- Files: `BoosterSimApp/Services/PulseServer.swift:37-40`, `BoosterSimApp/Services/PulseClientConnection.swift`
- Current mitigation: Only runs on localhost (no explicit TLS). Bonjour `_pulse._tcp.` may advertise on the local network segment.
- Recommendations: Restrict `NWParameters` to local-only (remove `includePeerToPeer`), add a handshake token, or validate the connecting app's bundle identity.

**`as!` Force Casts on AXValue types:**
- Risk: `WindowObserver.swift:138-140` and `AXInspectorService.swift:95` use `val as! AXValue` after checking `CFGetTypeID`. While the type check makes the cast safe in practice, the project's code standards (`docs/code-standards.md:162`) explicitly prohibit `as!` on user data. If the AX API returns an unexpected type that happens to share a type ID, this would crash.
- Files: `BoosterSimApp/Services/WindowObserver.swift:138-140`, `BoosterSimApp/Services/AXInspectorService.swift:95`
- Current mitigation: Preceding `CFGetTypeID` guard makes this practically safe.
- Recommendations: Use `guard let axVal = val as? AXValue` or extract the value in a helper that returns `Optional`.

**`NWEndpoint.Port` Force Unwrap:**
- Risk: `PulseServer.swift:36` force-unwraps `NWEndpoint.Port(rawValue: 0)!`. Port 0 is always valid (requests any available port), so this cannot fail, but it violates the code standard.
- Files: `BoosterSimApp/Services/PulseServer.swift:36`
- Current mitigation: Port 0 is guaranteed valid by the system.
- Recommendations: Use `NWEndpoint.Port(rawValue: 0)!` only if necessary, or restructure to avoid the unwrap.

**UDIDs Logged via `print()` in EnvironmentOverrideService:**
- Risk: `BoosterSimApp/Services/EnvironmentOverrideService.swift` passes UDID strings directly into `print()` calls (lines 109, 117, 126, 133, 140, 146, etc.). The code standards require using `AppLogger` with `privacy: .private` for UDIDs.
- Files: `BoosterSimApp/Services/EnvironmentOverrideService.swift` (16 print statements)
- Current mitigation: None.
- Recommendations: Migrate to `AppLogger` with privacy markers.

## Performance Bottlenecks

**`CaptureService` Accumulates All Frames in Memory:**
- Problem: `capturedFrames: [CMSampleBuffer]` (`BoosterSimApp/Services/CaptureService.swift:68`) appends every frame during recording into an array held in memory. A 30-second recording at 30fps = 900 `CMSampleBuffer` objects, each potentially holding uncompressed or compressed pixel data.
- Files: `BoosterSimApp/Services/CaptureService.swift:68,98,223,256`
- Cause: No streaming write-to-disk during capture; all frames buffered until `exportCapture()` is called.
- Improvement path: Write frames to a temporary file incrementally via `AVAssetWriter`, or limit the in-memory buffer and spill to disk.

**`BuildStatsService` Scans Entire DerivedData Every 5 Seconds:**
- Problem: `scanDerivedData()` (`BoosterSimApp/Services/BuildStatsService.swift:31-63`) enumerates all directories in `~/Library/Developer/Xcode/DerivedData`, checks each for a `LogStoreManifest.plist`, and parses up to 20 manifests every 5 seconds. The `mtimeCache` optimization skips re-parsing unchanged files but still performs `contentsOfDirectory` + 20 `fileExists` calls each cycle.
- Files: `BoosterSimApp/Services/BuildStatsService.swift:22-63`
- Cause: No `FSEvents`-based or `DispatchSource` file-watching; relies on polling.
- Improvement path: Use `DispatchSource.makeFileSystemObjectSource` to watch the DerivedData directory for changes, or increase the poll interval when no Simulator is active.

**`EnvironmentOverrideService.loadCurrentState` Fires 12 Concurrent simctl Processes:**
- Problem: `loadCurrentState(udid:)` (`BoosterSimApp/Services/EnvironmentOverrideService.swift:85-105`) creates 12 separate `simCtl.run()` Combine pipelines simultaneously (1 for appearance, 1 for smart invert, 10 for accessibility keys). Each spawns a background `Process` running `xcrun simctl`.
- Files: `BoosterSimApp/Services/EnvironmentOverrideService.swift:85-105`
- Cause: Individual `simctl spawn` calls for each defaults key.
- Improvement path: Batch all accessibility reads into a single `simctl spawn` that runs a shell script, or use `simctl spawn udid defaults read com.apple.Accessibility` once and parse all keys.

## Fragile Areas

**`SideWindowController` Constructor with 12 Service Parameters:**
- Files: `BoosterSimApp/Windows/SideWindowController.swift:46-61`, `BoosterSimApp/App/AppDelegate.swift:34-44`
- Why fragile: Adding a new service requires updating the `SideWindowController.init()` parameter list, the `embedSwiftUIContent()` call, the `AppDelegate` lazy property, and the `SideWindowView` preview. The `#Preview` block in `SideWindowView.swift:86-119` is already 33 lines of pure boilerplate.
- Safe modification: When adding a service, update all four locations in a single commit. Consider a service container/registry to decouple.
- Test coverage: No unit tests for `SideWindowController`; changes only verified through UI tests or manual testing.

**AX Observer `selfPtr` Manual Memory Management:**
- Files: `BoosterSimApp/Services/WindowObserver.swift:17,101-114`
- Why fragile: Uses `Unmanaged.passRetained(self)` to create a raw pointer for the C-style `AXObserver` callback, and must pair it with `Unmanaged.fromOpaque(selfPtr).release()` in `stopObserving()`. If `stopObserving()` is never called (e.g., exception during setup), the retain is leaked. The `deinit` guard helps, but the pattern is error-prone.
- Safe modification: Always call `stopObserving()` before re-observing. Verify `deinit` is called when `SimulatorWindowTracker` releases observers.
- Test coverage: No tests for observer lifecycle.

**CertificateService State Machine with `assertionFailure` on Invalid Transitions:**
- Files: `BoosterSimApp/Services/CertificateService.swift:167-168`
- Why fragile: The `transition(to:)` method calls `assertionFailure("Illegal certificate transition: ...")` in debug builds but silently proceeds with the invalid transition in release builds. An invalid transition could leave the service in an inconsistent state (e.g., trying to install while already installing).
- Safe modification: Guard against invalid transitions in release builds by returning `false` or throwing.
- Test coverage: `CertificateServiceTests` (`BoosterSimAppTests/CertificateServiceTests.swift`) tests valid transitions but not the assertionFailure path (assertions are stripped in test builds by default).

**Quartz-to-AppKit Y-Coordinate Flip in Multiple Locations:**
- Files: `BoosterSimApp/Services/WindowObserver.swift:142-143`, `BoosterSimApp/Services/WindowEnumerator.swift:35-37`, `BoosterSimApp/Utilities/PositionCalculator.swift` (assumed)
- Why fragile: The same Y-coordinate flip logic ("screenHeight - quartzY - height") is duplicated in `WindowObserver`, `WindowEnumerator`, and likely `PositionCalculator`. If any copy is wrong or the screen height source differs, the panel positions incorrectly.
- Safe modification: Extract to a single `CGPoint.appKitY(screenHeight:)` extension in a shared utility.
- Test coverage: No tests for coordinate conversion.

## Scaling Limits

**DerivedData Directory Enumeration:**
- Current capacity: `BuildStatsService` limits to 20 most-recently-modified project manifests and 30 recent build records.
- Limit: Developers with hundreds of Xcode projects will see builds from unknown projects. The `contentsOfDirectory` call on a large DerivedData can be slow.
- Scaling path: Filter by recently-accessed projects (check `.xcodeproj` last-open date) or let the user select which projects to monitor.

**Network Event Buffer:**
- Current capacity: `ConnectService` caps at `maxEvents = 500` (`BoosterSimApp/Services/ConnectService.swift:29`). Older events are silently dropped.
- Limit: During active debugging with many network requests, useful early events may be lost.
- Scaling path: Add pagination or a persistent event store (SQLite) for the session.

**Pulse Client Buffer:**
- Current capacity: `PulseClientConnection` enforces a 10 MB buffer cap (`BoosterSimApp/Services/PulseClientConnection.swift:36`) and disconnects clients that exceed it.
- Limit: A single large request/response pair (e.g., image upload) could exceed this.
- Scaling path: Stream large bodies to disk instead of buffering in memory.

## Dependencies at Risk

**ScreenCaptureKit (SCStream):**
- Risk: `CaptureService` (`BoosterSimApp/Services/CaptureService.swift`) uses `SCStream` and `SCStreamOutput` for screen recording. These APIs are available from macOS 12.3+ but have changed behavior across macOS versions (especially 14/15). The `CaptureStreamOutput` delegate method signature and `SCStreamConfiguration` properties may need updates.
- Impact: Screen capture could break on new macOS versions.
- Migration plan: Pin minimum deployment target and test each macOS major version. The entitlement `BoosterHealth-Entitlements.plist` references Screen Recording.

**`xcrun simctl` CLI Interface:**
- Risk: Most features depend on `xcrun simctl` commands (`SimCtlService`, `EnvironmentOverrideService`, `SimulatorWindowTracker`, `CertificateService`). Apple can change flags, output format, or behavior in Xcode betas.
- Impact: Any simctl change breaks environment overrides, status bar control, certificate management, and device detection.
- Migration plan: Pin to tested Xcode versions. The `SimCtlService` abstraction layer makes it easier to adapt, but output parsing (e.g., JSON format in `SimulatorWindowTracker`) is fragile.

## Missing Critical Features

**No Error Recovery for Pulse Server Failures:**
- Problem: If the Pulse TCP server fails (port in use, Bonjour error), it stays in `.disconnected` state with no retry or user-visible error. The Connect UI shows "searching" indefinitely.
- Blocks: Users cannot diagnose why network traffic capture isn't working.

**No Certificate Expiry Monitoring:**
- Problem: `CertificateService` checks certificate status on launch and when the active simulator changes, but does not monitor for approaching expiry. The certificate metadata includes an `expiry` date that is never used for proactive alerts.
- Blocks: Users discover certificate expiration only when HTTPS interception fails.

**No Settings Persistence for Connect Service:**
- Problem: `ConnectService` state (connection status, event list) is purely in-memory. Closing and reopening the app loses all captured traffic history.
- Blocks: Users cannot review traffic from a previous session.

## Test Coverage Gaps

**No Unit Tests for Service Layer:**
- What's not tested: `SimCtlService`, `ConnectService`, `PulseServer`, `PulseClientConnection`, `PulsePacketDecoder`, `CaptureService`, `BuildStatsService`, `WindowObserver`, `WindowEnumerator`, `SimulatorWindowTracker`, `EnvironmentOverrideService`, `CameraService`, `StatusBarService`, `DesignComparisonService`, `DeepLinkService`.
- Files: All files under `BoosterSimApp/Services/`
- Risk: Core business logic (Pulse protocol parsing, simctl argument building, coordinate conversion, certificate state machine) has zero automated test coverage.
- Priority: High — `PulsePacketDecoder` and `PulseClientConnection` handle binary protocol parsing where regressions are likely.

**No Unit Tests for Models:**
- What's not tested: `NetworkEvent`, `TrafficFilter`, `BuildRecord`, `SimulatorWindow`, `AXNode`, `AppSettings`, `StatusBarConfig`.
- Files: All files under `BoosterSimApp/Models/`, `BoosterSimApp/Views/SideWindow/network/NetworkEventModel.swift`
- Risk: Filtering logic, computed properties, and model transformations are untested.
- Priority: Medium — model logic is typically simpler but `TrafficFilter.matches()` has boolean logic worth testing.

**UI Tests Are Screenshot-Only:**
- What's not tested: `BoosterSimAppUITests/` contains only `ScreenshotTests.swift` (visual regression screenshots) and a basic launch test. No functional UI tests exercise tab navigation, button presses, environment override toggling, or certificate installation flow.
- Files: `BoosterSimAppUITests/ScreenshotTests.swift`, `BoosterSimAppUITests/BoosterSimAppUITests.swift`
- Risk: No automated verification that UI controls are wired and functional.
- Priority: Medium — manual testing is the only verification method.

---

*Concerns audit: 2026-08-29*