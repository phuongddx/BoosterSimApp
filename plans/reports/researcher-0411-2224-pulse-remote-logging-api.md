# Research: Pulse Remote Logging API — Receive-Side (macOS)

**Date:** 2026-04-11
**Context:** BoosterSimApp needs to receive network events from iOS Simulator apps running Pulse's `RemoteLogger`
**Sources:** Pulse open-source SDK (github.com/kean/Pulse v5.1.4), PulsePro repo (github.com/kean/PulsePro)

---

## Executive Summary

**There is NO server-side API in the open-source Pulse SDK.** The open-source Pulse contains only the client (sender). The server (receiver) is Pulse Pro, a closed-source commercial macOS app. BoosterSimApp must implement its own Pulse-compatible NWListener server using the fully documented binary protocol reverse-engineered from the client source.

**Recommendation:** Implement a custom `PulseServer` using Apple's Network framework (`NWListener` + `NWConnection`) that speaks the Pulse binary protocol. This is feasible — all packet formats, handshake sequences, and Codable data models are fully documented in the open-source client code.

**Effort estimate:** ~400-500 LOC for a minimal receive-only implementation (no TLS/PSK, no mock support).

---

## 1. Architecture Overview

```
┌─────────────────────────┐          Bonjour: _pulse._tcp          ┌────────────────────────────┐
│   iOS Simulator App     │  ──── NWConnection (TCP) ──────────────>│  BoosterSimApp (macOS)     │
│   (Pulse Client)        │                                        │  (Pulse Server - CUSTOM)   │
│                         │  <──── Packet protocol ────────────────│                            │
│  RemoteLogger.shared     │                                        │  NWListener                │
│    .start()             │                                        │    → accepts connections   │
│                         │                                        │    → decodes packets       │
│  LoggerStore.events     │                                        │    → publishes events      │
│    → send to server     │                                        │      via Combine           │
└─────────────────────────┘                                        └────────────────────────────┘
```

### Source Credibility
- Protocol details: extracted directly from Pulse open-source client source (authoritative)
- Data models: extracted from `NetworkLogger+Entities.swift` (authoritative, Codable structs)
- Server-side behavior: inferred from client expectations (high confidence — handshake is symmetrical)

---

## 2. Binary Packet Protocol (Fully Documented)

### Packet Envelope

```
| code (UInt8, 1 byte) | contentSize (UInt32, 4 bytes) | body (compressed via deflate) |
```

Header = 5 bytes total. Body is always compressed.

### Packet Codes

| Code | UInt8 | Direction | Description |
|------|-------|-----------|-------------|
| `clientHello` | 0 | Client→Server | Handshake init with device/app info |
| `serverHello` | 1 | Server→Client | Handshake response with version |
| `pause` | 2 | Server→Client | Pause streaming |
| `resume` | 3 | Server→Client | Resume streaming |
| `ping` | 6 | Bidirectional | Keepalive (every 2s) |
| `storeEventMessageStored` | 7 | Client→Server | Log message event |
| `storeEventNetworkTaskCreated` | 8 | Client→Server | Network request started |
| `storeEventNetworkTaskProgressUpdated` | 9 | Client→Server | Download/upload progress |
| `storeEventNetworkTaskCompleted` | 10 | Client→Server | **Network response received (PRIMARY INTEREST)** |
| `message` | 13 | Bidirectional | Generic message with path routing |

### Handshake Sequence

1. Client connects → sends `clientHello` (code 0) with JSON payload:
```swift
struct PacketClientHello: Codable {
    let version: Int        // Protocol version (currently 1)
    let deviceId: String    // Unique device identifier
    let deviceInfo: DeviceInfo
    let appInfo: AppInfo
    let session: SessionInfo
}
```

2. Server responds with `serverHello` (code 1) with JSON payload:
```swift
struct ServerHelloResponse: Codable {
    let version: String     // e.g. "1.0.0"
}
```

3. Client starts sending event packets (codes 7-10).
4. Keepalive: client sends ping (code 6) every 2 seconds. Server must respond with pong (code 6).

### Timeout Values (from client source)
- Connection timeout: 5 seconds
- Handshake timeout: 10 seconds
- Message request/response timeout: 20 seconds
- Ping interval: 2 seconds
- Reconnect delay: 1-30 seconds (exponential backoff)

---

## 3. Network Event Data Format (PRIMARY INTEREST)

### Packet Code 10: `storeEventNetworkTaskCompleted`

Binary body format AFTER decompression:
```
| messageSize (UInt32) | requestBodySize (UInt32) | responseBodySize (UInt32) | jsonData | requestBody | responseBody |
```

- `messageSize`: size of the JSON-encoded event data
- `requestBodySize`: size of raw request body bytes
- `responseBodySize`: size of raw response body bytes
- `jsonData`: JSON data of `messageSize` bytes → decode as `LoggerStore.Event.NetworkTaskCompleted`
- `requestBody`: raw bytes of `requestBodySize` bytes (can be nil/zero if no body)
- `responseBody`: raw bytes of `responseBodySize` bytes (can be nil/zero if no body)

### Codable Struct: `LoggerStore.Event.NetworkTaskCompleted`

```swift
public struct NetworkTaskCompleted: Codable, Sendable {
    public var taskId: UUID
    public var taskType: NetworkLogger.TaskType        // dataTask, downloadTask, uploadTask, streamTask, webSocketTask
    public var createdAt: Date
    public var originalRequest: NetworkLogger.Request   // URL, method, headers
    public var currentRequest: NetworkLogger.Request?
    public var response: NetworkLogger.Response?        // statusCode, headers
    public var error: NetworkLogger.ResponseError?      // code, domain, description
    public var requestBody: Data?                       // raw request body
    public var responseBody: Data?                      // raw response body
    public var metrics: NetworkLogger.Metrics?          // timing, transfer sizes
    public var label: String?
    public var taskDescription: String?
}
```

### `NetworkLogger.Request` (Codable, Sendable)

```swift
public struct Request: Hashable, Codable, Sendable {
    public var url: URL?
    public var httpMethod: String?                      // "GET", "POST", etc.
    public var headers: [String: String]?               // All HTTP headers
    public var cachePolicy: URLRequest.CachePolicy
    public var timeout: TimeInterval
    public var contentType: ContentType?                // parsed from headers
}
```

### `NetworkLogger.Response` (Codable, Sendable)

```swift
public struct Response: Hashable, Codable, Sendable {
    public var statusCode: Int?                         // 200, 404, etc.
    public var headers: [String: String]?               // All response headers
    public var contentType: ContentType?                // parsed from headers
}
```

### `NetworkLogger.ResponseError` (Codable, Sendable)

```swift
public struct ResponseError: Codable, Sendable {
    public var code: Int
    public var domain: String
    public var debugDescription: String
    public var error: Swift.Error?                      // underlying error (e.g., DecodingError)
}
```

### `NetworkLogger.Metrics` (Codable, Sendable)

```swift
public struct Metrics: Codable, Sendable {
    public var taskInterval: DateInterval               // start/end
    public var redirectCount: Int
    public var transactions: [TransactionMetrics]       // per-redirect metrics
    public var totalTransferSize: TransferSizeInfo      // bytes sent/received
}
```

### `NetworkLogger.ContentType` (Hashable, ExpressibleByStringLiteral)

```swift
public struct ContentType: Hashable, ExpressibleByStringLiteral {
    public var type: String                             // "application/json"
    public var parameters: [String: String]             // {"charset": "UTF-8"}
    public var rawValue: String                         // original string

    public var isJSON: Bool
    public var isImage: Bool
    public var isHTML: Bool
    public var isPDF: Bool
    public var isEncodedForm: Bool
}
```

### `NetworkLogger.TaskType` (Int16, Codable)

```swift
@frozen public enum TaskType: Int16, Codable, Sendable {
    case dataTask
    case downloadTask
    case uploadTask
    case streamTask
    case webSocketTask
}
```

### Other Event Packets

**Packet Code 7: `storeEventMessageStored`**
- Body = JSON-encoded `LoggerStore.Event.MessageStored`
- Fields: `createdAt`, `level` (verbose/debug/info/warning/error), `text`, `file`, `function`, `line`, `label`, `metadata`

**Packet Code 8: `storeEventNetworkTaskCreated`**
- Body = JSON-encoded `LoggerStore.Event.NetworkTaskCreated`
- Fields: `taskId`, `taskType`, `createdAt`, `originalRequest`, `currentRequest`, `label`, `taskDescription`

**Packet Code 9: `storeEventNetworkTaskProgressUpdated`**
- Body = JSON-encoded `LoggerStore.Event.NetworkTaskProgressUpdated`
- Fields: `taskId`, `url`, `completedUnitCount`, `totalUnitCount`

---

## 4. Implementation Plan for BoosterSimApp

### Required Components

| Component | Responsibility | Est. LOC |
|-----------|---------------|----------|
| `PulseServer` | NWListener + Bonjour + connection management | ~120 |
| `PulseConnection` | Per-client NWConnection + packet decode | ~150 |
| `PulsePacketDecoder` | Binary protocol parsing (header, decompress, manifest split) | ~80 |
| `PulseEventPublisher` | Combine subject exposing decoded events | ~30 |
| `ConnectService` update | Wire server to existing network tab UI | ~50 |

### Key Implementation Details

**NWListener setup:**
```swift
let parameters = NWParameters.tcp
parameters.includePeerToPeer = true
let listener = try NWListener(using: parameters, on: .tcp(0)) // any port
listener.service = NWListener.Service(name: "BoosterSimApp", type: "_pulse._tcp")
```

**Packet decoding (per connection receive loop):**
1. Accumulate bytes into buffer
2. Read first 5 bytes → `PacketHeader(code, contentSize)`
3. Read `contentSize` bytes → compressed body
4. Decompress body using `NSData.decompress(using: .zlib)` or `Compression.decompress`
5. For code 10: split into manifest (12 bytes) + jsonData + requestBody + responseBody
6. Decode JSON using `JSONDecoder` → `LoggerStore.Event.NetworkTaskCompleted`
7. Publish via Combine `PassthroughSubject`

**Compression:** Body uses deflate (zlib). Can decompress with:
- `NSData.decompressed(using: .zlib)` — available on macOS 10.15+
- Or `import Compression` with `COMPRESSION_ZLIB` — more portable

**TLS/PSK (OPTIONAL for MVP):**
Client supports optional passcode-based TLS using cipher suite `TLS_PSK_WITH_AES_128_GCM_SHA256`. For local simulator communication, skip TLS — connections are local only. Add later if needed for remote device support.

### Connection to Existing Code

The existing `ConnectService` (in `Services/ConnectService.swift`) already has a `@Published var networkEvents: [NetworkEvent]` pattern. The Pulse server would:
1. Start `NWListener` on app launch
2. Accept connections from any Pulse-enabled iOS app in the simulator
3. Decode incoming `NetworkTaskCompleted` events
4. Convert to `NetworkEvent` models (or use Pulse's native types directly)
5. Publish via `ConnectService` → `NetworkTabView` displays them

---

## 5. Trade-off Matrix

| Dimension | Custom NWListener Server | Buy Pulse Pro (reference) | Proxy via Pulse Pro API |
|-----------|--------------------------|---------------------------|-------------------------|
| **Complexity** | Medium (~400 LOC) | N/A (closed-source) | Low but fragile |
| **Maintenance** | Must track protocol changes | Vendor handles | Vendor + integration |
| **Data access** | Full control, all fields | Full control | Limited by API |
| **Dependencies** | Zero (Apple Network framework) | Commercial license | Pulse Pro + API |
| **Reliability** | Protocol is stable (v5.x) | Production-tested | Two points of failure |
| **Cost** | Engineering time only | $49-99/device/year | License + eng time |
| **Latency** | Direct TCP, minimal | Direct TCP | Extra hop |

### Adoption Risk

- **Protocol stability:** HIGH confidence. Protocol has been stable across Pulse 3.x-5.x. Packet codes unchanged.
- **Breaking changes:** MEDIUM risk. If Pulse adds new packet codes, server ignores unknown codes gracefully (unknown UInt8 → skip).
- **Alternative paths:** If protocol breaks, can fall back to reading Pulse's SQLite store files directly (simulator filesystem access).

---

## 6. Source Reference Map

| Source | What it provides | Reliability |
|--------|-----------------|-------------|
| `Sources/Pulse/RemoteLogger/RemoteLogger.swift` (748 lines) | Client logic, connection lifecycle, event forwarding | Authoritative |
| `Sources/Pulse/RemoteLogger/RemoteLogger-Protocol.swift` (~10KB) | Packet codes, handshake structs, binary manifest format | Authoritative |
| `Sources/Pulse/RemoteLogger/RemoteLogger-Connection.swift` (~11.5KB) | NWConnection wrapper, packet encode/decode, compression | Authoritative |
| `Sources/Pulse/LoggerStore/LoggerStore+Event.swift` (~7.3KB) | Event enum, NetworkTaskCompleted/NetworkTaskCreated structs | Authoritative |
| `Sources/Pulse/NetworkLogger/NetworkLogger+Entities.swift` (~550 lines) | Request/Response/ResponseError/Metrics/ContentType types | Authoritative |
| `Sources/Pulse/LoggerStore/LoggerStore+Entities.swift` | Core Data entities (reference for field completeness) | Authoritative |
| PulsePro repo (github.com/kean/PulsePro) | NO source code, commercial product placeholder | N/A |

---

## 7. Unresolved Questions

1. **Multiple simultaneous clients:** Should the server accept connections from multiple iOS Simulator apps simultaneously, or lock to one? The client sends `deviceId` in handshake — could use for identification.
2. **Store persistence:** Should decoded events be persisted to a local LoggerStore/CoreData, or held in memory only? Memory-only is simpler but loses history on app restart.
3. **Bonjour name collision:** If Pulse Pro is also running on the same Mac, both will advertise `_pulse._tcp`. iOS clients may connect to either. Need to handle this (unique Bonjour name? Different service type?).
4. **Body size limits:** Large response bodies (images, videos) could consume significant memory. Need streaming or size-capped handling.
5. **Protocol version negotiation:** Client sends `version: 1` in hello. Should we version-check or accept all versions?
