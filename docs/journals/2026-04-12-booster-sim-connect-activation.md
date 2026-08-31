# BoosterSimConnect: From Broken NWBrowser to Working Pulse Protocol Server

**Date**: 2026-04-12 00:31
**Severity**: High
**Component**: Network traffic inspection pipeline (PulseServer, PulsePacketDecoder, PulseClientConnection, ConnectService, BoosterSimConnect iOS framework, full Network tab UI)
**Status**: Resolved -- build clean, protocol decoding functional, end-to-end pending real iOS app testing

## What Happened

The original NWBrowser client-mode architecture (from commit b144e1e) was fundamentally flawed -- it tried to discover Pulse servers broadcasting on the local network, but the iOS Simulator apps we want to monitor are *not* Pulse servers; they are Pulse *clients* that need somewhere to send events. We tore out the entire discovery approach and replaced it with NWListener server-mode: BoosterSimApp hosts a TCP server advertising `_pulse._tcp.` via Bonjour, and iOS Simulator apps running BoosterSimConnect connect to it.

35 files changed, 4139 lines inserted, zero external dependencies added. The Pulse binary protocol was reverse-engineered and decoded from scratch: 5-byte header (`[code: UInt8][contentSize: UInt32 BE]`) + zlib-compressed body with a 3-entry manifest for network task completed events.

> **Correction 2026-08-31:** "zero external dependencies added" was accurate on 2026-04-12 — this change decoded the Pulse wire format from scratch without depending on the package. It is no longer true of the project: Pulse 5.2.2 (`Pulse`, `PulseProxy`) was adopted on 2026-06-04 (`2d28bda`) and is declared on BOTH the app target (`project.pbxproj:199-202`) and `BoosterSimConnect` (`:271-274`). The original sentence above is left unedited as the historical record.

## The Brutal Truth

The NWBrowser client-mode architecture was architecturally backwards from day one. We spent an entire session building 11 files on the assumption that Pulse iOS apps broadcast themselves and we discover them. They do not. They connect *to* a server. That mistake cascaded into a full rewrite of the transport layer. The previous journal entry (0411-1218) even flagged `parsePulseEvent` as a nil-returning stub -- now it is a real protocol decoder with manifest parsing, zlib decompression, and Codable struct mapping. But the fact remains: we built the first version without verifying who connects to whom.

The cross-platform build situation was its own circle of hell. Xcode refused to nest xcodebuild invocations for the same project. `Contents/Frameworks/` rejected the iOS-style shallow framework bundle. We burned multiple iterations on build phase scripting before landing on the two-step approach (pre-build the iOS framework, then Run Script copies it to `Contents/Resources/`). Each failure required reading build logs line by line because Xcode's error messages for bundle validation are spectacularly unhelpful.

## Technical Details

**Server architecture (replaces client-mode NWBrowser):**
- `PulseServer.swift` (104 LOC) -- NWListener on port 0 (OS assigns), advertises `_pulse._tcp.` via Bonjour, accepts multiple concurrent clients
- `PulseClientConnection.swift` (183 LOC) -- per-client handler with state machine: `connecting -> waitingHello -> active -> disconnected`, 10 MB buffer safety cap
- `PulsePacketDecoder.swift` (174 LOC) -- pure static decoder for Pulse binary protocol

**Protocol format reverse-engineered:**
- Header: `[code: UInt8][contentSize: UInt32 BE]` = 5 bytes
- Body: zlib-compressed
- Code 10 (networkTaskCompleted) body structure: `[3x UInt32 BE manifest][JSON event data][request body][response body]`
- Manifest entries: messageSize, requestBodySize, responseBodySize
- Code 0 (clientHello): JSON with device info + app info, zlib-compressed
- Code 6 (ping/pong): keepalive, empty body

**Critical crash fix in `PulsePacketDecoder.readUInt32BE`:**
Original code used `withUnsafeBytes { $0.load(as: UInt32.self) }` which crashes on misaligned Data slices. Replaced with safe `copyBytes` pattern:
```swift
var raw = UInt32(0)
withUnsafeMutableBytes(of: &raw) { $0.copyBytes(from: data[offset..<offset + 4]) }
return UInt32(bigEndian: raw)
```

**Cross-platform framework embedding:**
- BoosterSimConnect builds as iOS Simulator-only framework
- Run Script build phase copies to `Contents/Resources/` (not `Contents/Frameworks/` -- macOS bundle validation rejects non-platform-matching frameworks in Frameworks/)
- Graceful fallback: if pre-built framework missing, build continues without it

**UI layer (7 new view files):**
- `TrafficList.swift`, `TrafficRowView.swift`, `TrafficDetailView.swift` (295 LOC) -- full request/response inspection with 4 tabs
- `TrafficFilterBar.swift` -- method/status/URL filtering
- `ConnectSetupView.swift` -- disconnected state with integration instructions
- `ConnectStatusBanner.swift` -- live connection state indicator
- `CurlExporter.swift` -- cURL command generation with sensitive header redaction

**ConnectService.swift (118 LOC)** -- replaces old NWBrowser version. Now wraps PulseServer, converts PulseDecodedEvent to NetworkEvent model, manages 500-event ring buffer.

## What We Tried

1. **NWBrowser client mode** (original approach) -- architecturally backwards. iOS Simulator apps do not broadcast; they connect to a server. Abandoned.

2. **Nested xcodebuild for iOS framework** -- Xcode refuses to run xcodebuild for the same project from within a build phase. Tried multiple approaches: direct invocation, xcrun wrapper, separate scheme. All failed with "unable to run xcodebuild within xcodebuild" or similar.

3. **Contents/Frameworks/ for iOS framework** -- macOS validates that frameworks in `Contents/Frameworks/` match the host's platform. iOS Simulator framework = hard rejection at launch. Moved to `Contents/Resources/` which bypasses validation entirely.

4. **`withUnsafeBytes { $0.load(as:) }` for header parsing** -- crashes on misaligned memory when Data is sliced (common when reading from the middle of a buffer). The `load(as:)` method requires proper alignment. `copyBytes` is alignment-safe.

5. **Code 8 (taskCreated) event handling** -- started implementing, decided to skip for MVP. TaskCreated fires when a request starts but contains no response data. Only Code 10 (taskCompleted) gives us the full request/response/error/metrics picture. TaskCreated support deferred.

## Root Cause Analysis

The original NWBrowser mistake was a failure to verify the transport contract before building the pipeline. The previous journal entry (0411-1218) documented this exact lesson: "Verify the transport contract before building the pipeline." We wrote the lesson and then had to learn it again by actually doing the verification -- reading Pulse's source code and discovering that `RemoteLogger` connects *to* a server, not the other way around. The lesson was known intellectually but not acted on.

The cross-platform build issues stem from a fundamental tension: Xcode expects frameworks in `Contents/Frameworks/` to match the host platform, but we need an iOS Simulator framework embedded in a macOS app. There is no clean Apple-sanctioned way to do this. `Contents/Resources/` is the pragmatic escape hatch, and the Run Script fallback ensures builds do not break when the iOS framework is not yet built.

The alignment crash in protocol parsing is a classic Swift footgun. `Data` slices share backing storage with the original, so a slice starting at byte offset 3 does not guarantee 4-byte alignment for a `UInt32` read. The `load(as:)` method on `UnsafeRawBufferPointer` requires alignment. `copyBytes` performs a memcpy which has no alignment requirement.

## Lessons Learned

1. **Read the source before architecting the transport.** We spent one full session building NWBrowser discovery on wrong assumptions about Pulse's directionality. Reading Pulse's `RemoteLogger.swift` for 10 minutes would have shown that it initiates outbound connections to a server endpoint. Do the 10-minute source read *before* the multi-hour implementation.

2. **Apple's bundle validation is platform-strict.** `Contents/Frameworks/` is validated; `Contents/Resources/` is not. When embedding a foreign-platform framework, Resources is the only option. This is not documented anywhere prominent -- it is tribal knowledge learned from build failures.

3. **`copyBytes` over `load(as:)` for Data parsing.** Always. The alignment trap is invisible until you slice a buffer at an odd offset and crash at runtime. There is no compiler warning for this.

4. **Two-step build workflow for cross-platform targets.** Xcode cannot nest xcodebuild for the same project. Pre-build the secondary target separately, then copy via Run Script phase. The Run Script must have a graceful fallback (do not fail the build if the artifact is missing).

5. **MVP scope discipline on protocol codes.** Code 10 (taskCompleted) gives complete request/response/error data. Code 8 (taskCreated) only gives the URL and method -- no response, no error, no timing. Shipping Code 10 only for MVP was the right call. Pending events add complexity without proportional value.

## Next Steps

- [ ] End-to-end test with a real iOS Simulator app embedding BoosterSimConnect framework
- [ ] Verify Bonjour advertisement is discoverable from Simulator (network namespace may differ)
- [ ] Test large response body handling (10 MB buffer cap behavior under load)
- [ ] Add Code 8 (taskCreated) support for in-progress request tracking
- [ ] Replace placeholder timing data in TrafficDetailView metrics tab with real `PulseMetrics` data
- [ ] Investigate whether `NWParameters.includePeerToPeer = true` is needed or harmful for Simulator-to-host communication
