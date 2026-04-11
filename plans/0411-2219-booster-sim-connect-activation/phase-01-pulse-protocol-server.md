---
title: "Phase 1: Pulse Protocol Server"
description: "Implement NWListener server that accepts Pulse client connections and decodes binary protocol"
status: pending
priority: P1
effort: 6h
depends_on: []
---

# Phase 1: Pulse Protocol Server

## Context Links

- Research report: `plans/reports/researcher-0411-2224-pulse-remote-logging-api.md`
- Current ConnectService: `BoosterSimApp/Services/ConnectService.swift` (to be rewritten)
- NetworkEvent model: `BoosterSimApp/Views/SideWindow/network/NetworkEventModel.swift`
- NetworkTabView (consumer): `BoosterSimApp/Views/SideWindow/tabs/NetworkTabView.swift`

## Overview

Replace ConnectService's NWBrowser client approach with an NWListener server that:
1. Advertises `_pulse._tcp.` via Bonjour
2. Accepts TCP connections from iOS Simulator apps running Pulse RemoteLogger
3. Implements the Pulse binary protocol (handshake, ping/pong, event decoding)
4. Converts decoded network events to existing `NetworkEvent` model
5. Publishes via Combine `@Published` for UI consumption

**Priority:** P1 — blocks all testing
**Current status:** Not started

## Key Insights

From research report (`researcher-0411-2224-pulse-remote-logging-api.md`):
- Pulse SDK is CLIENT-only (sender). NO server API exists. Must implement custom server.
- Binary protocol is fully documented from open-source client source.
- Protocol is stable across Pulse 3.x-5.x — packet codes unchanged.
- Body compression: zlib deflate. Decompress via `NSData.decompressed(using: .zlib)`.
- Handshake: client sends code 0 (JSON with device/app info), server responds code 1 (JSON with version).
- Keepalive: client pings (code 6) every 2s, server must pong (code 6).
- Primary event: code 10 (`storeEventNetworkTaskCompleted`) — contains full request/response data.
- Manifest format for code 10: 3 x UInt32 (message/request/response sizes) + jsonData + requestBody + responseBody.

## Architecture

```
AppDelegate
  └─ ConnectService (@MainActor, ObservableObject)
       └─ PulseServer (@MainActor)
            ├─ NWListener (Bonjour: _pulse._tcp.)
            ├─ connections: [String: PulseClientConnection]
            └─ eventPublisher: PassthroughSubject<PulseDecodedEvent, Never>

PulseClientConnection (per connected iOS app)
  ├─ NWConnection
  ├─ receive buffer (Data accumulator)
  ├─ handshake state machine
  └─ decode loop → PulsePacketDecoder

PulsePacketDecoder (stateless, pure functions)
  ├─ parseHeader(Data) → (code: UInt8, contentSize: UInt32)?
  ├─ decompressBody(Data) → Data?
  ├─ decodeNetworkTaskCompleted(Data) -> PulseNetworkEvent?
  ├─ decodeClientHello(Data) -> PulseClientHello?
  └─ encodeServerHello() -> Data
  └─ encodePong() -> Data
```

### Data Flow

```
iOS Simulator app makes HTTP request
  → PulseProxy swizzles URLSession
  → RemoteLogger broadcasts via NWConnection to _pulse._tcp.
  → PulseServer NWListener accepts connection
  → PulseClientConnection receive loop reads 5-byte header + body
  → PulsePacketDecoder decompresses + parses JSON
  → ConnectService converts PulseNetworkEvent → NetworkEvent
  → @Published networkEvents array updates
  → NetworkTabView re-renders TrafficList
```

### State Machine (per connection)

```
CONNECTING → WAITING_HELLO → ACTIVE → DISCONNECTED
                              ↕
                           PING/PONG
```

## Requirements

### Functional
- NWListener starts on app launch, stops on termination
- Advertises `_pulse._tcp.` Bonjour service
- Accepts multiple simultaneous client connections
- Completes Pulse handshake (clientHello → serverHello)
- Responds to ping with pong within 1s
- Decodes packet codes 8 (taskCreated), 10 (taskCompleted)
- Converts Pulse network events to `NetworkEvent` model
- Caps event storage at 500 entries (existing behavior)
- Updates `ConnectionState` for UI banner display

### Non-Functional
- All code on `@MainActor` (project rule: no async/await)
- Combine `@Published` pattern for state
- Zero external dependencies (Apple Network framework only)
- Each file under 200 LOC
- Swift 6 strict concurrency (`Sendable` enforced)
- Graceful handling: unknown packet codes (skip), malformed data (log + continue), connection drops (cleanup)

## Related Code Files

### Create
| File | Responsibility | Est. LOC |
|------|---------------|----------|
| `BoosterSimApp/Services/PulseServer.swift` | NWListener, Bonjour, connection acceptance, lifecycle | ~120 |
| `BoosterSimApp/Services/PulseClientConnection.swift` | Per-client state machine, receive loop, handshake, ping/pong | ~150 |
| `BoosterSimApp/Services/PulsePacketDecoder.swift` | Binary protocol parsing, decompression, JSON decode, encode helpers | ~100 |

### Modify
| File | Change |
|------|--------|
| `BoosterSimApp/Services/ConnectService.swift` | Replace NWBrowser with PulseServer; wire event publishing |

### Read-only (reference)
| File | Why |
|------|-----|
| `BoosterSimApp/Views/SideWindow/network/NetworkEventModel.swift` | Target model for event conversion |
| `BoosterSimApp/Views/SideWindow/network/ConnectStatusBanner.swift` | ConnectionState consumer |
| `BoosterSimApp/App/AppDelegate.swift` | Calls startDiscovering/stopDiscovering |
| `BoosterSimApp/Views/SideWindow/tabs/NetworkTabView.swift` | Consumes connectService.networkEvents |

## Implementation Steps

### Step 1: PulsePacketDecoder (no dependencies, pure functions)

1. Create `BoosterSimApp/Services/PulsePacketDecoder.swift`
2. Define packet code enum:
   ```swift
   enum PulsePacketCode: UInt8 {
       case clientHello = 0
       case serverHello = 1
       case ping = 6
       case storeEventMessageStored = 7
       case storeEventNetworkTaskCreated = 8
       case storeEventNetworkTaskProgressUpdated = 9
       case storeEventNetworkTaskCompleted = 10
   }
   ```
3. Implement `parseHeader(_ data: Data) -> (code: UInt8, contentSize: UInt32)?` — reads first 5 bytes
4. Implement `decompressBody(_ data: Data) -> Data?` — uses `NSData.decompressed(using: .zlib)`
5. Implement `decodeClientHello(_ data: Data) -> PulseClientHello?` — JSON decode
6. Implement `decodeNetworkTaskCompleted(_ data: Data) -> (json: Data, requestBody: Data?, responseBody: Data?)?` — manifest split (3 x UInt32 + slices)
7. Implement `decodeNetworkTaskCreated(_ data: Data) -> Data?` — simple JSON (no manifest)
8. Implement `encodeServerHello() -> Data` — compress JSON `{"version":"1.0.0"}` with header code 1
9. Implement `encodePong() -> Data` — header code 6, empty body
10. Define Codable structs: `PulseClientHello`, `PulseNetworkTaskCompleted`, `PulseRequest`, `PulseResponse`, `PulseResponseError`

### Step 2: PulseClientConnection (depends on PulsePacketDecoder)

1. Create `BoosterSimApp/Services/PulseClientConnection.swift`
2. Define connection state enum: `connecting`, `waitingHello`, `active`, `disconnected`
3. Store properties: `NWConnection`, `receiveBuffer: Data`, `state`, `deviceName: String?`, `appName: String?`
4. Implement `start()` — begin receive loop on main queue
5. Implement `receiveLoop()` — read into buffer, call processBuffer()
6. Implement `processBuffer()` — extract complete packets from buffer:
   - If buffer < 5 bytes → wait for more
   - Parse header → if buffer < 5 + contentSize → wait for more
   - Extract full packet → dispatch by code → trim buffer → repeat
7. Implement `handleHandshake(_ data: Data)` — decode clientHello, store device/app info, send serverHello
8. Implement `handlePing()` — send pong
9. Implement `handleNetworkTaskCompleted(_ data: Data)` — decode, extract bodies, publish via callback
10. Implement `handleNetworkTaskCreated(_ data: Data)` — decode, publish (for "pending" state in UI)
11. Implement `send(_ data: Data)` — write to NWConnection
12. Implement `disconnect()` — cancel NWConnection, clear buffer
13. Callback closures: `onEvent: (PulseDecodedEvent) -> Void`, `onDisconnect: (PulseClientConnection) -> Void`, `onStateChange: (ConnectionState) -> Void`

### Step 3: PulseServer (depends on PulseClientConnection)

1. Create `BoosterSimApp/Services/PulseServer.swift`
2. Store properties: `NWListener`, `connections: [UUID: PulseClientConnection]`, `PassthroughSubject<PulseDecodedEvent, Never>`
3. Implement `start()`:
   - Create `NWParameters.tcp` with `includePeerToPeer = true`
   - Create `NWListener(using: parameters, on: .tcp(0))` — ephemeral port
   - Set `listener.service = NWListener.Service(name: "BoosterSimApp", type: "_pulse._tcp.")`
   - Set `stateUpdateHandler` — log state, handle errors
   - Set `newConnectionHandler` — create PulseClientConnection, wire callbacks, start
   - Call `listener.start(queue: .main)`
4. Implement `stop()` — cancel all connections, cancel listener
5. Implement `handleNewConnection(_ nwConnection: NWConnection)` — create wrapper, store, start
6. Implement `removeConnection(_ connection: PulseClientConnection)` — cleanup from dict
7. Expose `var eventPublisher: AnyPublisher<PulseDecodedEvent, Never>`

### Step 4: Rewrite ConnectService (depends on PulseServer)

1. Replace `NWBrowser` property with `PulseServer`
2. Remove `browser`, `connection`, `isConnected` properties
3. Replace `startDiscovering()` with `startServer()`:
   - Create PulseServer, start it
   - Subscribe to `eventPublisher`
   - Set `connectionState = .searching` initially
   - On first connection: `connectionState = .connected(deviceName)`
   - On all disconnects: `connectionState = .searching` if no connections remain
4. Replace `stopDiscovering()` with `stopServer()`
5. Add `convertToNetworkEvent(_ pulseEvent: PulseDecodedEvent) -> NetworkEvent`:
   - Map PulseRequest fields → method, url, headers
   - Map PulseResponse fields → statusCode, responseHeaders
   - Map requestBody/responseBody data
   - Compute duration from metrics.taskInterval
   - Map error fields
6. Keep `clearEvents()`, `appendEvent()` (existing logic)
7. Keep `maxEvents = 500` cap (existing)
8. Update `AppDelegate` calls: `startDiscovering` → `startServer`, `stopDiscovering` → `stopServer` (method rename only, same call sites)

### Step 5: Wire into AppDelegate

1. Rename method calls in AppDelegate if needed (startDiscovering → startServer, stopDiscovering → stopServer)
2. Verify `connectService` is passed to `SideWindowView` → `NetworkTabView` (already wired)
3. Verify `ConnectStatusBanner` receives correct `connectionState` updates

## Todo List

- [ ] Create `PulsePacketDecoder.swift` with protocol parsing + Codable structs
- [ ] Create `PulseClientConnection.swift` with receive loop + state machine
- [ ] Create `PulseServer.swift` with NWListener + Bonjour + connection management
- [ ] Rewrite `ConnectService.swift` to use PulseServer instead of NWBrowser
- [ ] Update `AppDelegate.swift` method call names if changed
- [ ] Build project — verify zero compile errors
- [ ] Manual test: launch app, verify NWListener starts (check Console.app for Bonjour logs)

## Success Criteria

1. App builds with zero errors under Swift 6 strict concurrency
2. NWListener starts on app launch, advertises `_pulse._tcp.`
3. `dns-sd` command in terminal discovers "BoosterSimApp._pulse._tcp."
4. Connection state shows "Searching..." in UI when no clients connected
5. All files under 200 LOC
6. No NWBrowser/NWConnection client code remains in ConnectService

## Risk Assessment

| Risk | Mitigation |
|------|-----------|
| Zlib decompression fails on certain payloads | Wrap in try/catch, log error, skip packet — don't crash connection |
| NWListener port conflict | Use ephemeral port (0) — OS assigns available port |
| Client sends unexpected packet code | Default case in switch: log code, skip contentSize bytes, continue |
| Buffer accumulation memory leak | Cap receive buffer at 10MB; force-disconnect if exceeded |
| MainActor + Network queue contention | NWConnection callback on `.main` queue (already project convention) |

## Security Considerations

- Local-only TCP (simulator ↔ macOS same machine) — no network exposure
- No TLS for MVP (local communication, same host)
- No authentication — any local process could connect; acceptable for dev tool
- Sensitive headers redacted in cURL export (existing CurlExporter behavior)

## Next Steps

- Phase 2 (Cross-Platform Framework) can run in parallel
- Phase 3 (Testing) requires Phase 1 + Phase 2 complete
