# Code Review: BoosterSim Connect Feature

## Scope

- **Files (9 new + modified):** ConnectService.swift, BoosterSimConnect.swift, AppDelegate.swift, SideWindowController.swift, SideWindowView.swift, NetworkTabView.swift, CurlExporter.swift, NetworkEventModel.swift, TrafficDetailView.swift
- **Supporting files (6 new):** ConnectStatusBanner.swift, TrafficList.swift, TrafficFilterBar.swift, ConnectSetupView.swift, TrafficRowView.swift
- **LOC:** ~872 (new/changed) + ~350 (supporting) = ~1,222 total
- **Focus:** Recent changes (Connect feature end-to-end)
- **Scout findings:** 5 edge cases found (see below)

## Overall Assessment

Solid implementation. Follows established service patterns well -- `@MainActor final class: ObservableObject`, `@Published` state, injected via `AppDelegate` -> `SideWindowController` -> `@EnvironmentObject`. Architecture is consistent with the rest of the codebase. Found 2 major issues, 4 minor. No critical/blocking bugs.

---

## Major Issues

### M1. `networkEvents` should use `private(set)` -- encapsulation violation

**File:** `ConnectService.swift:12`

```swift
@Published var networkEvents: [NetworkEvent] = []
```

Every other `@Published` mutable collection in this codebase uses `private(set)` (see `SimulatorWindowTracker.simulators`). External callers can currently mutate the array directly, bypassing the 500-event cap and any future invariant checks. The `clearEvents()` method is the intended public API for external mutation.

**Fix:**
```swift
@Published private(set) var networkEvents: [NetworkEvent] = []
```

### M2. `TrafficFilterBar` clear button is a no-op

**File:** `TrafficFilterBar.swift:46-55`

The trash button appears when events exist but does nothing -- the action closure is empty:

```swift
Button {
    // Clear handled by parent via binding
} label: {
    Image(systemName: "trash")
```

The comment says "handled by parent via binding" but there is no callback, binding, or notification to the parent. The parent (`NetworkTabView`) passes `onRequestClear` to `TrafficList`, not to `TrafficFilterBar`. Users will tap the trash icon and nothing happens.

**Fix:** Add a callback parameter to `TrafficFilterBar` and wire it to `connectService.clearEvents()`:

```swift
// In TrafficFilterBar
var onClear: (() -> Void)?

// In the Button action:
onClear?()

// In NetworkTabView, pass it:
TrafficFilterBar(filter: $filter, eventCount: filteredEvents.count, onClear: { connectService.clearEvents() })
```

---

## Minor Issues

### m1. `TrafficFilter.matches` -- `statusCode: nil` passes all status filters except `success`

**File:** `NetworkEventModel.swift:50-62`

When `statusCode` is `nil` (request still in-flight), `StatusRange.success` (2xx) returns `false` because `contains(200...299)` excludes `nil`. This means filtering by "2xx" hides in-flight requests. May be intentional but could surprise users -- they'd see requests vanish from "2xx" filter while loading, then reappear once the response arrives.

**Impact:** UX surprise, not a bug. Document the behavior or treat `nil` as "pass all filters" if in-flight visibility is desired.

### m2. Operator precedence in `NetworkTabView` condition -- misleading but correct

**File:** `NetworkTabView.swift:32`

```swift
if showSetup || connectService.connectionState == .disconnected && connectService.networkEvents.isEmpty {
```

`&&` binds tighter than `||`, so this evaluates as:
`showSetup || (state == .disconnected && events.isEmpty)`

The result is correct (show setup when user taps Setup OR when disconnected with no events). But the mixed operators without parentheses make intent ambiguous. Adding parens would improve readability:

```swift
if showSetup || (connectService.connectionState == .disconnected && connectService.networkEvents.isEmpty) {
```

### m3. `TrafficDetailView` exceeds 200 LOC guideline (300 lines)

**File:** `TrafficDetailView.swift`

At 300 lines it exceeds the project's 200-LOC guideline. The view contains 4 tab implementations (summary, headers, body, metrics) plus helpers. Consider extracting the `DetailTab` enum and individual tab views into separate files.

### m4. `CurlExporter` -- unescaped URLs with single quotes may break shell execution

**File:** `CurlExporter.swift:17`

```swift
parts.append("'\(event.url)'")
```

If the URL contains a single quote, the generated cURL command breaks. While rare in practice, the body escaping already handles this pattern (line 36) but the URL does not. For consistency:

```swift
let escapedUrl = event.url.replacingOccurrences(of: "'", with: "'\\''")
parts.append("'\(escapedUrl)'")
```

---

## Edge Cases Found by Scout

1. **Multiple Simulator apps on same network** -- `browseResultsChangedHandler` connects to `results.first` only. If multiple Simulator apps are running, the service ignores all but the first Bonjour result. This is likely acceptable for MVP but worth noting for multi-sim support.

2. **Connection race: browser callback fires during `connect(to:)`** -- `browseResultsChangedHandler` checks `!self.isConnected` before calling `connect(to:)`, but `isConnected` is set to `true` only in the `stateUpdateHandler` for `.ready`. Between the `connect()` call and `.ready`, `isConnected` is still `false`, so duplicate `browseResultsChanged` callbacks could create multiple connections. The `self.connection = conn` assignment overwrites the previous connection without canceling it, leaking the NWConnection.

   **Fix:** Set a guard flag immediately in `connect(to:)`:
   ```swift
   private func connect(to browseResult: NWBrowser.Result) {
       guard !isConnected, connection == nil else { return }
       // ... existing code
   }
   ```

3. **`handleDisconnection` sets state to `.searching` -- no backoff or retry limit** -- If the Simulator app crashes repeatedly, the browser immediately rediscovers it and the cycle repeats forever. Not a bug, but worth noting for production hardening.

4. **`parsePulseEvent` returns `nil` always** -- Placeholder is clearly documented. The entire data reception pipeline (`receiveData` -> `processPayload` -> `parsePulseEvent`) is wired correctly but will silently drop all events. This is expected for the current integration phase but means the network tab will always show empty until Pulse integration is complete.

5. **`BoosterSimConnect.configureNetworkLogger` creates a new `NetworkLogger()` that is immediately discarded** -- The logger instance is local to the function, so the sensitive header/query configuration has no effect. It needs to be stored or applied to a shared singleton.

   **File:** `BoosterSimConnect.swift:51`
   ```swift
   let logger = NetworkLogger()  // local only, discarded after configureNetworkLogger() returns
   logger.sensitiveHeaders = [...]
   ```

---

## Positive Observations

- `ConnectService` follows the established `@MainActor final class: ObservableObject` pattern exactly
- `NWBrowser`/`NWConnection` callbacks correctly dispatch to `@MainActor` via `Task { @MainActor in }` -- thread-safe
- Sensitive header redaction in both `CurlExporter` and `BoosterSimConnect` cover the same set of headers -- consistent
- `NetworkEvent` model is well-structured: `Sendable`, `Identifiable`, computed properties for display
- `ConnectionState` enum is clean with associated value for device name
- Event cap (500) prevents unbounded memory growth
- `BoosterSimConnect` correctly gated behind `#if DEBUG && targetEnvironment(simulator)` -- no risk of shipping in production
- All new files use `DesignTokens` (`Spacing`, `CornerRadius`, `SideWindowMetrics`) -- no hardcoded values
- Weak `self` captures in all closures -- no retain cycles
- `SideWindowController` init parameter list updated consistently with all new services

---

## Recommended Actions

1. **[Major]** Add `private(set)` to `networkEvents` in `ConnectService` (1-line fix)
2. **[Major]** Fix the no-op clear button in `TrafficFilterBar` -- add callback and wire to parent
3. **[Edge Case]** Add guard in `connect(to:)` to prevent duplicate connections during browser callback storms
4. **[Edge Case]** Store or apply `NetworkLogger` configuration to a shared instance in `BoosterSimConnect`
5. **[Minor]** Add parentheses in `NetworkTabView` line 32 for readability
6. **[Minor]** Extract `TrafficDetailView` tabs into separate files to meet 200-LOC guideline

---

## Metrics

| Metric | Value |
|--------|-------|
| Type Coverage | Full (`Sendable`, `@MainActor`, strict concurrency) |
| Test Coverage | 0% (project has no test infrastructure yet) |
| Linting Issues | 0 (build passes, zero errors/warnings) |
| LOC (new/changed) | ~1,222 |
| Files over 200 LOC | 1 (TrafficDetailView at 300) |

---

## Unresolved Questions

1. **Pulse integration timeline** -- `parsePulseEvent` is a placeholder. When will the actual binary protocol parser be implemented? The entire Connect feature is non-functional without it.
2. **Multi-sim support** -- Is connecting to only the first discovered Simulator app acceptable for MVP, or should the user be able to choose?
3. **`NetworkLogger` configuration in BoosterSimConnect** -- Is the intention to configure the shared `NetworkLogger.shared` or a per-session instance? The current code configures a throwaway instance.
