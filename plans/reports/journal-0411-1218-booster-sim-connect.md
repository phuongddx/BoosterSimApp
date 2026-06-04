# BoosterSim Connect: Service + iOS Framework + UI Rewrite

**Date**: 2026-04-11 12:18
**Severity**: High
**Component**: Network monitoring pipeline (ConnectService, BoosterSimConnect, NetworkTabView)
**Status**: Build clean; end-to-end blocked on manual Xcode setup

## What Happened

Implemented the three-layer BoosterSim Connect feature: macOS Bonjour discovery service, iOS Simulator-side traffic capture framework, and a full rewrite of the Network tab UI. Build compiles with zero errors and zero warnings on Swift 6 strict concurrency. The catch: it is all wire and no signal until Pulse SPM gets added to the Xcode project manually.

## The Brutal Truth

We built 11 files of production code for a pipeline whose data source does not exist yet. `ConnectService.parsePulseEvent(_:)` at line 152 returns `nil` unconditionally because Pulse's binary protocol is proprietary and decoding it requires the `LoggerStore` type from the Pulse SPM package we have not added. The iOS framework (`BoosterSimConnect.swift`) compiles conditionally with `#if canImport(PulseProxy)` -- meaning every activation call is a no-op until someone opens Xcode and adds the package. Feels like plumbing a house with no water main connected.

The UI rewrite was satisfying to get right, but the metrics tab in `TrafficDetailView` uses fake proportional breakdowns (line 139: `duration * 0.1` for DNS, TCP, TLS). Those placeholder values will mislead anyone testing without real data.

## Technical Details

**Files created (8 in network/ dir):**
- `ConnectService.swift` (178 LOC) -- NWBrowser Bonjour discovery, NWConnection TCP transport, 500-event ring buffer
- `NetworkEventModel.swift` (209 LOC) -- `NetworkEvent`, `ConnectionState`, `HTTPMethod`, `TrafficFilter`, `StatusRange`
- `ConnectStatusBanner.swift` -- connection state indicator
- `TrafficFilterBar.swift` -- method/status/URL filter controls
- `TrafficList.swift` -- scrollable event list
- `TrafficRowView.swift` -- single row in traffic list
- `ConnectSetupView.swift` -- disconnected state instructions
- `TrafficDetailView.swift` (301 LOC) -- full request/response detail with 4 tabs (summary, headers, body, metrics)
- `CurlExporter.swift` (50 LOC) -- cURL export with sensitive header redaction

**Files created (1 in BoosterSimConnect/):**
- `BoosterSimConnect.swift` (75 LOC) -- iOS framework entry point

**Swift 6 concurrency fixes required:**
- NWBrowser `stateUpdateHandler` and `browseResultsChangedHandler` are Sendable closures that cannot directly touch `@MainActor` state. Fixed by wrapping every state mutation in `Task { @MainActor [weak self] in ... }` (ConnectService.swift lines 38, 53, 86-97).
- NWConnection `stateUpdateHandler` same pattern (line 86).
- `ConnectionState` needed explicit `Equatable` conformance for `.sheet(item:)` binding (NetworkEventModel.swift line 191).
- `CurlExporter` needed explicit `import AppKit` for `NSPasteboard` (line 2).
- `TrafficDetailView` had a `error` variable name colliding with Swift's error macro -- renamed the local usage.

**Key design decisions:**
1. NWBrowser for Bonjour discovery over manual DNS-SD -- Network framework is Apple-native, no C interop, works with `NWParameters.tcp`.
2. `Task { @MainActor }` bridge pattern over `DispatchQueue.main.async` -- required for Swift 6 strict concurrency, avoids Sendable violations.
3. 500-event cap with ring buffer (`removeFirst` when exceeding max) -- prevents unbounded memory growth during long sessions.
4. `parsePulseEvent` returns nil -- intentional stub. Real implementation requires `LoggerStore` from Pulse SPM.

## What We Tried

- First pass on NWBrowser callbacks tried direct `self.connectionState` mutation inside the handler. Swift 6 compiler rejected it: `@MainActor`-isolated property accessed from `Sendable` closure. Solution: `Task { @MainActor }` wrappers on every callback.
- `ConnectionState` originally had no `Equatable`. SwiftUI's `.sheet(item:)` requires `Identifiable` (which we had via UUID on `NetworkEvent`), but the filter binding needed `Equatable` for change detection. Added explicit conformance.
- `TrafficDetailView.metricsTab` timing bars originally attempted to use real `URLSessionTaskMetrics` -- no such data available from the Pulse protocol (yet). Fell back to proportional estimates.

## Root Cause Analysis

The core tension: we built the full receiver pipeline before confirming the transmitter works. The `parsePulseEvent` stub is the symptom -- Pulse's `RemoteLogger` broadcasts events in a proprietary binary format that requires `LoggerStore` (from Pulse SPM) to decode. We made a reasonable bet that the Network framework transport layer (NWBrowser + NWConnection) would be correct and that the parsing layer could be filled in later. The risk is that Pulse's Bonjour service type (`_pulse._tcp.`) or data format may not match our assumptions, and we will not know until manual Xcode setup happens.

## Lessons Learned

1. **Verify the transport contract before building the pipeline.** We assumed `_pulse._tcp.` Bonjour type and UInt32 length-prefixed binary frames. A 30-minute spike with Pulse's example app would have confirmed or denied this. We skipped it because "we can fix it later" -- classic mistake.
2. **Placeholder data in UI is a liability.** The fake timing breakdowns in `TrafficDetailView.metricsTab` (lines 139-143) will confuse QA and future developers. Should have shown "No timing data" unconditionally until real metrics flow.
3. **Conditional compilation hides bugs.** `#if canImport(PulseProxy)` in BoosterSimConnect.swift means the entire activation path compiles to nothing without Pulse. This is correct for distribution but dangerous for development -- we cannot verify any iOS-side logic until SPM is wired.
4. **Swift 6 Sendable is non-negotiable for Network framework.** Every NWBrowser/NWConnection callback is a `Sendable` closure. Budget time for `Task { @MainActor }` wrappers from the start.

## Next Steps

- [ ] Add Pulse SPM dependency to Xcode project (requires `github.com/kean/Pulse`, manual via Xcode File > Add Package)
- [ ] Create BoosterSimConnect framework target (iOS, Simulator only)
- [ ] Verify `_pulse._tcp.` Bonjour type matches Pulse's actual service type
- [ ] Implement `parsePulseEvent` using Pulse's `LoggerStore` API
- [ ] Replace fake timing data in TrafficDetailView.metricsTab with real metrics or "No data" message
- [ ] End-to-end test: run sample iOS app with BoosterSimConnect embedded, verify events appear in side panel
