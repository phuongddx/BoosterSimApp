# Code Review: Pulse Protocol Network Traffic Inspection

**Reviewer:** code-reviewer  
**Date:** 2026-04-12  
**Scope:** 6 files (4 new, 2 modified), 745 LOC total  

## Scope

- `BoosterSimApp/Services/PulsePacketDecoder.swift` (164 LOC, new)
- `BoosterSimApp/Services/PulseClientConnection.swift` (183 LOC, new)
- `BoosterSimApp/Services/PulseServer.swift` (104 LOC, new)
- `BoosterSimConnect/BoosterSimConnect.swift` (65 LOC, modified)
- `BoosterSimApp/Services/ConnectService.swift` (118 LOC, modified)
- `BoosterSimApp/App/AppDelegate.swift` (111 LOC, modified)

## Overall Assessment

Well-structured implementation. Clean separation between binary parsing (PulsePacketDecoder), per-client state (PulseClientConnection), server orchestration (PulseServer), and UI-facing service (ConnectService). All files under 200 LOC. MARK sections present. Combine patterns are correct. Swift 6 concurrency is mostly sound. One **critical** alignment bug in the header parser will crash at runtime.

---

## Critical Issues

### C1. Misaligned `withUnsafeBytes` load crashes on header parse

**File:** `/Users/ddphuong/Projects/next-labs/sim-dev-tool/BoosterSimApp/BoosterSimApp/Services/PulsePacketDecoder.swift:87`

```swift
let contentSize = data[1...4].withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
```

`data[1...4]` is a 4-byte slice starting at byte offset 1. `load(as: UInt32.self)` requires 4-byte alignment, but the slice pointer is at an odd offset. This triggers a **fatal error** at runtime:

```
Fatal error: load from misaligned raw pointer
```

Confirmed with a standalone Swift reproduction. This means **every incoming packet** crashes the app because `parseHeader` is called on every buffer cycle.

**Fix:** Use manual byte construction instead of `load(as:)`:

```swift
static func parseHeader(_ data: Data) -> (code: UInt8, contentSize: UInt32)? {
    guard data.count >= PulseHeader.size else { return nil }
    let code = data[0]
    var raw = UInt32(0)
    withUnsafeMutableBytes(of: &raw) { dst in
        dst.copyBytes(from: data[1..<5])
    }
    return (code, UInt32(bigEndian: raw))
}
```

**Note:** The manifest parsing at lines 113-115 (`decompressed[0...3]`, `[4...7]`, `[8...11]`) starts at offsets 0, 4, and 8 -- all 4-byte aligned. Those are safe **only if** the decompressed Data has contiguous backing at offset 0 (which `NSData.decompressed` guarantees). However, the same defensive pattern should be applied for robustness.

---

## High Priority

### H1. Silent error swallowing throughout PulsePacketDecoder

**File:** `PulsePacketDecoder.swift` -- every decode method uses `try?` and returns `nil` on failure.

Lines 96, 103, 128: decompression failure, JSON decode failure, and malformed data all return `nil` silently. Callers (`handleHandshake`, `handleNetworkTaskCompleted`) then silently discard the packet. No logging, no metrics, no way to diagnose why traffic isn't appearing.

**Impact:** If Pulse protocol changes between versions, the app silently shows nothing. Developer has zero diagnostic signal.

**Recommendation:** Add an `os_log` / `AppLogger` call at minimum for decode failures, even at debug level:

```swift
static func decompressBody(_ data: Data) -> Data? {
    do {
        return try NSData(data: data).decompressed(using: .zlib) as Data
    } catch {
        AppLogger.connect.error("zlib decompression failed: \(error)")
        return nil
    }
}
```

### H2. NWListener silently ignores bind failures

**File:** `PulseServer.swift:34-59`

```swift
do {
    let listener = try NWListener(using: params, on: NWEndpoint.Port(rawValue: 0)!)
    ...
} catch {
    // Failed to create listener — server remains stopped
}
```

The `catch` block is empty. If `NWListener` creation fails (unlikely but possible with port exhaustion), the app shows `.searching` forever with no indication of failure. The `stateUpdateHandler` for `.failed` is also a no-op.

**Fix:** Log the error and optionally transition `ConnectService.connectionState` to a failure state.

### H3. `DispatchQueue.main` receive operator is redundant but correct

**File:** `ConnectService.swift:33`

```swift
.receive(on: DispatchQueue.main)
```

`ConnectService` is `@MainActor`, and `PulseServer.eventSubject` is fed from `@MainActor` code (the `client.onEvent` callback hops to main via `Task { @MainActor }`). The `.receive(on: DispatchQueue.main)` is redundant but harmless. Not a bug, just worth noting for clarity.

---

## Medium Priority

### M1. `PulseClientConnection` callbacks are not `@Sendable`

**File:** `PulseClientConnection.swift:34-36`

```swift
var onEvent: ((PulseDecodedEvent) -> Void)?
var onDisconnect: ((PulseClientConnection) -> Void)?
var onStateChange: ((ClientState) -> Void)?
```

These closures are set from `PulseServer.handleNewConnection` (main actor) and invoked from `receiveLoop` which hops to main via `Task { @MainActor }`. Under Swift 6 strict concurrency, these should be `@Sendable` to satisfy the `Task` closure capture. Currently builds because the callbacks are stored as non-Sendable optionals and captured implicitly. This may produce warnings or errors with stricter concurrency auditing.

**Fix:** Mark as `@Sendable`:
```swift
var onEvent: (@Sendable (PulseDecodedEvent) -> Void)?
```

### M2. `connectService.stopServer()` drops `cancellables` but `startServer()` re-creates the server

**File:** `ConnectService.swift:44-48`

```swift
func stopServer() {
    pulseServer?.stop()
    pulseServer = nil
    cancellables.removeAll()
    ...
}
```

This is correct for a stop-then-restart cycle. But if `stopServer()` is called while events are still in-flight on the Combine pipeline, the `cancellables.removeAll()` cancels the subscription immediately -- events in the Combine operator chain are dropped. This is acceptable behavior for a stop operation, but worth documenting.

### M3. `PulseServer.stop()` iterates dictionary while disconnecting

**File:** `PulseServer.swift:62-69`

```swift
func stop() {
    for (_, connection) in connections {
        connection.disconnect()
    }
    connections.removeAll()
    ...
}
```

`disconnect()` calls `onDisconnect?(self)` which calls `removeConnection(_:)` -- mutating `connections` during iteration. However, the `removeConnection` is called after the `for` loop completes because `onDisconnect` is set to call `self?.removeConnection(...)` which captures `[weak self]` and the `Task { @MainActor }` hop means the mutation is deferred to the next runloop tick. So the iteration completes before any mutation. **Safe but fragile.**

**Recommendation:** Set `client.onDisconnect = nil` before disconnecting to avoid the indirect mutation path:

```swift
func stop() {
    let conns = connections.values
    connections.removeAll()
    for connection in conns {
        connection.onDisconnect = nil  // prevent callback to removeConnection
        connection.disconnect()
    }
    ...
}
```

### M4. `encodeServerHello` silently returns empty `Data()` on encoding failure

**File:** `PulsePacketDecoder.swift:140`

```swift
guard let json = try? JSONEncoder().encode(payload) else { return Data() }
```

If encoding fails (it won't for this simple payload, but defensively), an empty packet is sent. The client would receive a 5-byte header with code=1 and contentSize=0, which is a valid but meaningless packet. Low risk since the payload is static.

### M5. `BoosterSimConnect` init calls `activate()` which may run before Pulse is loaded

**File:** `BoosterSimConnect/BoosterSimConnect.swift:29`

`init()` immediately calls `activate()`. The `#if canImport(PulseProxy)` guard is correct, but `URLSessionProxyDelegate.enableAutomaticRegistration()` is called unconditionally within the guard. If PulseProxy is available but not fully initialized at load time (e.g., loaded via `dlopen`), swizzling may not take effect on existing `URLSession` instances. This is a known Pulse limitation, not a bug in this code.

---

## Low Priority

### L1. `NWEndpoint.Port(rawValue: 0)!` force unwrap

**File:** `PulseServer.swift:35`

`Port(rawValue: 0)` is always valid (0 means OS assigns a port), so the force unwrap is safe. But for style consistency, could use `guard let` with a log.

### L2. `includePeerToPeer = true` may not be needed

**File:** `PulseServer.swift:31`

`includePeerToPeer` enables peer-to-peer networking (Wi-Fi Direct / AWDL). For local Simulator communication over TCP loopback, this is unnecessary and may cause unwanted network interface scanning. Consider removing if only local connections are expected.

### L3. `PulseDecodedEvent` not `Sendable`

**File:** `PulseClientConnection.swift:7-10`

The enum carries `Data?` values. `Data` is `Sendable`, so the enum could be marked `Sendable` for consistency.

### L4. `AppState` connection state never returns to `.searching` after disconnect

If a client connects then disconnects, `connectionState` stays `.connected("Simulator")`. The `stopServer()` path resets to `.disconnected`, but a natural disconnect during an active session leaves stale state. Consider listening for `onDisconnect` to transition back to `.searching` or `.disconnected`.

---

## Positive Observations

- Clean layer separation: decoder (pure static), connection (per-client state), server (orchestration), service (UI bridge)
- Buffer safety cap at 10MB prevents OOM from misbehaving clients
- `weak self` captures throughout prevent retain cycles
- `@MainActor` isolation is consistent across all service classes
- `isReleasedWhenClosed` pattern respected; NWConnection lifecycle managed correctly
- `receiveLoop` properly chains recursive receives and checks disconnected state before re-calling
- The `processBuffer` while-loop correctly handles multiple packets in one receive chunk
- Sensitive header/query redaction in `BoosterSimConnect` is well-configured
- All files under 200 LOC target

---

## Edge Cases Found by Scout

1. **Malformed packet with `contentSize = 0`**: Handled correctly -- `totalLength = 5`, body is empty, dispatches with empty `Data`. Fine.
2. **Multiple packets in single receive**: `processBuffer` while-loop handles this correctly.
3. **Partial header (less than 5 bytes received)**: `parseHeader` returns `nil`, loop exits, waits for more data. Correct.
4. **Partial body (header says 1000 bytes, only 500 received)**: `guard receiveBuffer.count >= totalLength` catches this. Correct.
5. **Decompression bomb**: `decompressBody` produces Data in memory without size limit. A malicious client could send a small compressed payload that decompresses to gigabytes. The 10MB receive buffer cap limits the compressed size, but zlib can expand ~1000x. Max theoretical decompressed size from 10MB compressed is ~10GB. Consider capping decompressed output size.
6. **Client sends packets after disconnect state**: `receiveLoop` checks `state != .disconnected` before re-calling, but the current in-flight receive callback could fire after `disconnect()` sets state. The guard `guard let self` and state check prevent double-processing.

---

## Recommended Actions

1. **(Blocking) Fix C1:** Replace `withUnsafeBytes { $0.load(as:) }` with aligned byte-copy pattern in `parseHeader`. Apply same defensive pattern to manifest parsing.
2. **(High) H1:** Add logging to all decode failure paths in PulsePacketDecoder.
3. **(High) H2:** Log NWListener creation/state failures.
4. **(Medium) M3:** Pre-clear connections dict in `PulseServer.stop()` before calling disconnect to avoid fragile deferred-mutation pattern.
5. **(Medium) M5/L4:** Consider listening for client disconnect to update connection state.

---

## Metrics

| Metric | Value |
|--------|-------|
| Files Reviewed | 6 |
| Total LOC | 745 |
| Critical Issues | 1 |
| High Priority | 3 |
| Medium Priority | 5 |
| Low Priority | 4 |
| File Size Compliance | All under 200 LOC |
| MARK Sections | Present in all files |
| Swift 6 Concurrency | Mostly sound (M1 minor) |

## Unresolved Questions

- Is the decompression bomb scenario (10MB compressed -> multi-GB decompressed) a realistic concern given this is a local-only developer tool?
- Should `connectionState` automatically transition back to `.searching` when a client disconnects, or only on explicit `stopServer()`?
- Is `includePeerToPeer = true` intentional for future device-to-device features?
