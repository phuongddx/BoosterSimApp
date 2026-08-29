# Phase 5: Network Tools - Pattern Map

**Mapped:** 2026-08-29
**Files analyzed:** 11
**Analogs found:** 9 / 11

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `BoosterSimApp/Services/CommandServer.swift` | service | event-driven (TCP broadcast) | `BoosterSimApp/Services/PulseServer.swift` | exact |
| `BoosterSimApp/Services/NetworkConditionService.swift` | service | request-response (state machine) | `BoosterSimApp/Services/CertificateService.swift` | exact |
| `BoosterSimApp/Models/NetworkConditionProfile.swift` | model | transform (Codable) | `BoosterSimApp/Services/CertificateModels.swift` | role-match |
| `BoosterSimApp/Models/BlockRule.swift` | model | transform (Codable + pure matcher) | `BoosterSimApp/Services/CertificateModels.swift` | role-match |
| `BoosterSimApp/Views/SideWindow/network/NetworkConditionsSectionView.swift` | component | request-response (UI) | `BoosterSimApp/Views/SideWindow/CertificateSectionView.swift` | exact |
| `BoosterSimApp/Views/SideWindow/network/BlockRulesView.swift` | component | request-response (UI) | `BoosterSimApp/Views/SideWindow/CertificateSectionView.swift` | role-match |
| `BoosterSimApp/Views/SideWindow/tabs/NetworkTabView.swift` | component (modify) | request-response (UI) | self — existing mount point | self |
| `BoosterSimConnect/BoosterCommandClient.swift` | service | event-driven (TCP client) | `BoosterSimApp/Services/PulseClientConnection.swift` | exact |
| `BoosterSimConnect/NetworkConditionController.swift` | service | transform (lock-protected state store) | `BoosterSimConnect/BoosterSimConnect.swift` (singleton pattern) | partial |
| `BoosterSimConnect/BoosterNetworkProtocol.swift` | middleware | request-response (URLProtocol interception) | Pulse `MockingURLProtocol.swift` (upstream MIT) | exact (upstream) |
| `BoosterSimConnect/BoosterSimConnect.swift` | framework (modify) | — | self — existing activation site | self |
| `BoosterSimAppTests/BlockRuleTests.swift` | test | — | `BoosterSimAppTests/CertificateServiceTests.swift` | exact |
| `BoosterSimAppTests/NetworkConditionProfileTests.swift` | test | — | `BoosterSimAppTests/CertificateServiceTests.swift` | exact |
| `BoosterSimAppTests/CommandPayloadTests.swift` | test | — | `BoosterSimAppTests/CertificateServiceTests.swift` | exact |

## Pattern Assignments

### `BoosterSimApp/Services/CommandServer.swift` (service, event-driven)

**Analog:** `BoosterSimApp/Services/PulseServer.swift`

**Class declaration + properties pattern** (lines 1-22):
```swift
import Foundation
import Network
import Combine

@MainActor
final class PulseServer {

    // MARK: - Properties

    private var listener: NWListener?
    private(set) var connections: [UUID: PulseClientConnection] = [:]
    private let eventSubject = PassthroughSubject<PulseDecodedEvent, Never>()
    private var cancellables = Set<AnyCancellable>()

    /// Publishes decoded Pulse events from all connected clients
    var eventPublisher: AnyPublisher<PulseDecodedEvent, Never> {
        eventSubject.eraseToAnyPublisher()
    }
```

**NWListener start pattern** (lines 31-56):
```swift
    func start() {
        guard listener == nil else { return }

        let params = NWParameters.tcp
        params.includePeerToPeer = true

        do {
            let listener = try NWListener(using: params, on: NWEndpoint.Port(rawValue: 0)!)
            listener.service = NWListener.Service(name: "BoosterSimApp", type: "_pulse._tcp.")

            listener.stateUpdateHandler = { (state: NWListener.State) in
                switch state {
                case .ready:
                    break
                case .failed:
                    break
                default:
                    break
                }
            }

            listener.newConnectionHandler = { [weak self] (nwConnection: NWConnection) in
                Task { @MainActor [weak self] in
                    self?.handleNewConnection(nwConnection)
                }
            }

            listener.start(queue: DispatchQueue.main)
            self.listener = listener
        } catch {
            // Failed to create listener — server remains stopped
        }
    }
```

**Connection management + broadcast** (lines 77-86):
```swift
    private func handleNewConnection(_ nwConnection: NWConnection) {
        let client = PulseClientConnection(connection: nwConnection)

        // Wire event callback → forward to our subject
        client.onEvent = { [weak self] event in
            // ...
        }
        client.onDisconnect = { [weak self] client in
            Task { @MainActor [weak self] in
                self?.removeConnection(client.id)
                // ...
            }
        }
        connections[client.id] = client
        client.start()
    }
```

**Key adaptation:** Same shape; change Bonjour type to `_booster-cmd._tcp.`, replace `PulseClientConnection` with a lightweight `CommandClientConnection`, send JSON snapshots instead of receiving events, broadcast to all connections on every state push.

---

### `BoosterSimApp/Services/NetworkConditionService.swift` (service, state machine)

**Analog:** `BoosterSimApp/Services/CertificateService.swift`

**Class + @Published + init pattern** (lines 7-29):
```swift
@MainActor
final class CertificateService: ObservableObject {

    @Published private(set) var status: CertificateStatus = .notGenerated
    @Published private(set) var operation: CertificateOperation = .idle

    private enum StorageKey { … }

    private let simCtl: SimCtlService
    private let store = CertificateStore()
    private let defaults: UserDefaults

    private var cancellables = Set<AnyCancellable>()
    private var lastFailedAction: RetryAction?

    init(simCtl: SimCtlService, defaults: UserDefaults = .standard) {
        self.simCtl = simCtl
        self.defaults = defaults
        reconcileStatus(udid: nil)
    }
```

**State machine begin/finish/fail/transition** (lines 144-170):
```swift
    private func begin(_ next: CertificateOperation) -> Bool {
        guard !operation.isWorking else { return false }
        transition(to: next)
        return true
    }

    private func finish(with newStatus: CertificateStatus) {
        status = newStatus
        lastFailedAction = nil
        transition(to: .idle)
    }

    private func fail(_ error: CertificateError) {
        let message = store.redactPaths(in: error.errorDescription ?? "Unknown certificate error.")
        AppLogger.certificates.error("\(message, privacy: .public)")
        transition(to: .error(message))
    }

    private func transition(to next: CertificateOperation) {
        if operation != next, !operation.canTransition(to: next) {
            assertionFailure("Illegal certificate transition: \(operation) -> \(next)")
        }
        operation = next
    }
```

**Key adaptation:** Same `begin`/`finish`/`fail`/`transition` quartet. Replace `CertificateStatus`/`CertificateOperation` with network-specific enums (`NetworkConditionState`: idle/applying/applied/error). Add `@AppStorage` for profile + rules persistence (pattern from `AppSettings.swift`). On every allowed transition that changes the snapshot, encode + broadcast via `CommandServer`.

---

### `BoosterSimApp/Models/NetworkConditionProfile.swift` (model, Codable)

**Analog:** `BoosterSimApp/Services/CertificateModels.swift`

**Enum with associated values + computed properties** (lines 1-30):
```swift
enum CertificateStatus: Equatable {
    case notGenerated
    case generated(cn: String, expiry: Date, sha256: String)
    case installed(cn: String, expiry: Date, sha256: String, deviceName: String, udid: String)
    case unknown(cn: String, expiry: Date, sha256: String, reason: String)

    var certificateMetadata: CertificateMetadata? {
        switch self {
        case .notGenerated: nil
        case .generated(let cn, let expiry, let sha256),
             .installed(let cn, let expiry, let sha256, _, _),
             .unknown(let cn, let expiry, let sha256, _):
            CertificateMetadata(commonName: cn, expiry: expiry, sha256: sha256)
        }
    }
}
```

**State machine enum with `canTransition` + `isWorking`** (lines 32-56):
```swift
enum CertificateOperation: Equatable {
    case idle
    case generating
    case installing
    case rotating
    case resetting
    case error(String)

    var isWorking: Bool {
        switch self {
        case .idle, .error: false
        default: true
        }
    }

    func canTransition(to next: CertificateOperation) -> Bool {
        switch self {
        case .idle:
            switch next {
            case .idle, .generating, .installing, .rotating, .resetting: return true
            case .error: return false
            }
        // ... remaining cases
        }
    }
}
```

**Key adaptation:** Define `NetworkConditionProfile` as `Codable` struct with preset cases (off/3g/edge/lte/wifi/custom) and `ThrottleSpec` values. Define `NetworkConditionState` enum mirroring `CertificateOperation` shape (idle/applying/applied/error). Same `canTransition` + `isWorking` pattern.

---

### `BoosterSimApp/Models/BlockRule.swift` (model, Codable + pure matcher)

**Analog:** `BoosterSimApp/Services/CertificateModels.swift` (struct/enum declaration style) + RESEARCH.md `BlockRule` design

This file combines a `Codable, Identifiable` struct with a pure `matches(request:) -> Bool` method. No exact analog for the matcher — closest structural match is the `CertificateMetadata` struct. Use the RESEARCH.md design directly:

```swift
// From RESEARCH.md — Recommended command snapshot payload
struct BlockRule: Codable, Identifiable {
    let id: UUID
    var domain: String                // exact or "*.example.com" suffix
    var pathPrefix: String?           // "/api/v1/ads"
    var isEnabled: Bool = true
}
```

**Key adaptation:** Add `func matches(_ request: URLRequest) -> Bool` as a pure function (exact host, `*.suffix` host match, path prefix). No regex — string ops only (security requirement from RESEARCH.md).

---

### `BoosterSimApp/Views/SideWindow/network/NetworkConditionsSectionView.swift` (component, UI)

**Analog:** `BoosterSimApp/Views/SideWindow/CertificateSectionView.swift`

**View declaration + environment + state** (lines 1-18):
```swift
import SwiftUI

struct CertificateSectionView: View {
    let udidProvider: () -> String?
    let deviceNameProvider: () -> String

    @EnvironmentObject var certService: CertificateService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isExpanded = true
    @State private var showResetConfirm = false
    @AppStorage("certFirstUseHintDismissed") private var hintDismissed = false
```

**Body with CollapsibleSection** (lines 19-37):
```swift
    var body: some View {
        CollapsibleSection(title: "Certificates", icon: "lock.shield", isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                statusRow.padding(.horizontal, Spacing.md).padding(.top, Spacing.sm)
                if let metadata { detailsRow(metadata) }
                if activeUDID == nil { helperBanner(…) }
                primaryButton.padding(.horizontal, Spacing.md)
                if metadata != nil { secondaryActions.padding(.horizontal, Spacing.md) }
                if !hintDismissed, case .notGenerated = certService.status {
                    helperBanner(…, dismissible: true)
                }
            }
            .padding(.bottom, Spacing.sm)
            .animation(animation, value: certService.status)
            .animation(animation, value: certService.operation)
        }
        .confirmationDialog(…)
    }
```

**Status row with operation-driven caption** (lines 38-51):
```swift
    private var statusRow: some View {
        HStack(spacing: Spacing.xs) {
            switch certService.operation {
            case .generating:
                ProgressView().scaleEffect(0.7); Text("Generating CA…")
            case .installing:
                ProgressView().scaleEffect(0.7); Text("Installing into Simulator…")
            case .error(let message):
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange); Text(message)
            case .idle:
                idleStatus
            }
            Spacer()
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .accessibilityElement(children: .combine)
    }
```

**Key adaptation:** Same `CollapsibleSection` wrapper (title: "Network Conditions", icon: "network"). Profile picker as pill-style `HStack` of `Button`s (not a `Picker` — 260pt width constraint). Airplane toggle as `Toggle`. Status caption driven by `NetworkConditionService` operation state. Use `Spacing`/`SideWindowMetrics` tokens exclusively.

---

### `BoosterSimApp/Views/SideWindow/network/BlockRulesView.swift` (component, UI)

**Analog:** `BoosterSimApp/Views/SideWindow/CertificateSectionView.swift` (CollapsibleSection wrapper) + `BoosterSimApp/Views/SideWindow/FeatureRowView.swift` (row styling)

**Row styling reference** from `FeatureRowView.swift` (lines 22-35):
```swift
            HStack(spacing: Spacing.sm) {
                Image(systemName: item.icon)
                    .imageScale(.small)
                    .foregroundStyle(.primary)
                    .frame(width: 16)

                Text(item.label)
                    .font(.body)
                    .foregroundStyle(.primary)

                Spacer()
                // … trailing content
            }
            .padding(.horizontal, Spacing.md)
            .frame(height: SideWindowMetrics.rowHeight)
            .background(isHovered ? Color.accentColor.opacity(0.08) : Color.clear)
            .contentShape(Rectangle())
```

**Key adaptation:** Wrap in `CollapsibleSection(title: "Block Rules", icon: "shield.lefthalf.filled")`. Each rule row: domain text + optional path badge + `Toggle` for enable/disable + delete button. "Add rule" button at bottom. Use `SideWindowMetrics.rowHeight` for row height, `Spacing` for padding.

---

### `BoosterSimApp/Views/SideWindow/tabs/NetworkTabView.swift` (component, modify)

**Analog:** self — existing mount point

**Current body structure** (lines 24-55):
```swift
    var body: some View {
        VStack(spacing: 0) {
            ConnectStatusBanner(…)
            if showSetup || … {
                ConnectSetupView()
            } else {
                TrafficFilterBar(…)
                TrafficList(…)
            }
            Divider()
            // >>> NEW: insert NetworkConditionsSectionView and BlockRulesView here <<<
            CertificateSectionView(…)
        }
        .sheet(item: $selectedEvent) { … }
    }
```

**Key adaptation:** Insert the two new section views between `Divider()` and `CertificateSectionView`. Add `@EnvironmentObject var networkConditionService: NetworkConditionService` and pass it down.

---

### `BoosterSimConnect/BoosterCommandClient.swift` (service, event-driven TCP client)

**Analog:** `BoosterSimApp/Services/PulseClientConnection.swift`

**Init + connection lifecycle** (lines 35-55):
```swift
@MainActor
final class PulseClientConnection {

    let id: UUID
    let connection: NWConnection
    private(set) var state: ClientState = .connecting
    private(set) var deviceName: String?
    private(set) var appName: String?

    var onEvent: ((PulseDecodedEvent) -> Void)?
    var onDisconnect: ((PulseClientConnection) -> Void)?
    var onStateChange: ((ClientState) -> Void)?

    private var receiveBuffer = Data()
    private static let maxBufferSize = 10 * 1024 * 1024 // 10 MB safety cap

    init(connection: NWConnection) {
        self.id = UUID()
        self.connection = connection
    }

    func start() {
        updateState(.waitingHello)
        connection.stateUpdateHandler = { [weak self] state in
            Task { @MainActor [weak self] in
                guard let self else { return }
                switch state {
                case .ready: self.receiveLoop()
                case .failed, .cancelled: self.disconnect()
                default: break
                }
            }
        }
        connection.start(queue: .main)
    }
```

**Buffered receive loop + length-prefixed framing** (lines 68-104):
```swift
    private func receiveLoop() {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] content, _, _, error in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let error { self.disconnect(); return }
                if let content {
                    self.receiveBuffer.append(content)
                    if self.receiveBuffer.count > Self.maxBufferSize { self.disconnect(); return }
                    self.processBuffer()
                }
                if self.state != .disconnected { self.receiveLoop() }
            }
        }
    }

    private func processBuffer() {
        while receiveBuffer.count >= PulseHeader.size {
            guard let header = PulsePacketDecoder.parseHeader(receiveBuffer) else { return }
            let totalLength = PulseHeader.size + Int(header.contentSize)
            guard receiveBuffer.count >= totalLength else { return }
            let bodyData = Data(receiveBuffer[bodyStart..<bodyEnd])
            receiveBuffer.removeFirst(totalLength)
            dispatchPacket(code: header.code, body: bodyData)
        }
    }
```

**Send pattern** (lines 155-162):
```swift
    func send(_ data: Data) {
        connection.send(content: data, completion: .contentProcessed { [weak self] error in
            Task { @MainActor [weak self] in
                if error != nil { self?.disconnect() }
            }
        })
    }
```

**Key adaptation:** This is the framework-side client (NWBrowser → NWConnection). Mirror the receive loop + buffer framing. Replace Pulse's binary packet protocol with simpler length-prefixed JSON frames (4-byte big-endian length + JSON body). On received snapshot → update `NetworkConditionController`. **NOT `@MainActor`** — use `NSLock`-protected state (framework target, URLProtocol callbacks on session queue).

---

### `BoosterSimConnect/NetworkConditionController.swift` (service, lock-protected state store)

**Analog:** `BoosterSimConnect/BoosterSimConnect.swift` (singleton pattern) + `CertificateService` (state publishing shape, adapted for non-MainActor)

**Singleton pattern** from `BoosterSimConnect.swift` (lines 14-16):
```swift
@MainActor @objc public final class BoosterSimConnect: NSObject {
    @objc public static let shared = BoosterSimConnect()
```

**Key adaptation:** This is the framework-side state holder. NOT `@MainActor` — use `NSLock` (Pulse's `NetworkDebugger` precedent from upstream). Holds the current `BoosterCommand` snapshot. Exposes `func evaluate(request: URLRequest) -> ConditionVerdict` as a pure synchronous function for `BoosterNetworkProtocol` to call.

---

### `BoosterSimConnect/BoosterNetworkProtocol.swift` (middleware, URLProtocol interception)

**Analog:** Pulse upstream `MockingURLProtocol.swift` (MIT licensed, verified this session)

**URLProtocol subclass + canInit + startLoading shape** from RESEARCH.md verified upstream source:
```swift
// From Pulse upstream (MIT © 2020-2026 Alexander Grebenyuk)
// MockingURLProtocol.swift — pattern to copy

// canInit gating:
public override class func canInit(with request: URLRequest) -> Bool {
    guard URLProtocol.property(forKey: requestMockedHeaderName, in: request) == nil else { return false }
    return shouldMock(request: request)
}

// Guard header injection (anti-recursion):
public override class func canonicalRequest(for request: URLRequest) -> URLRequest {
    var request = request
    URLProtocol.setProperty(true, forKey: requestMockedHeaderName, in: &request)
    return request
}

// Swizzle registration (from Pulse's AutomaticRegistration):
@MainActor
public static func enableAutomaticRegistration() {
    if let lhs = class_getClassMethod(URLSession.self, #selector(URLSession.init(configuration:delegate:delegateQueue:))),
       let rhs = class_getClassMethod(URLSession.self, #selector(URLSession.pulse_init2(configuration:delegate:delegateQueue:))) {
        method_exchangeImplementations(lhs, rhs)
    }
}
```

**Key adaptation:** Same `canInit`/`canonicalRequest` guard-header pattern (use `X-Booster-Internal` instead of `X-PulseRequestMocked`). Same swizzle shape (renamed selectors, prepend `BoosterNetworkProtocol.self`). `startLoading()` calls `NetworkConditionController.shared.evaluate(request:)` and enforces the verdict (fail for airplane/block, pass-through with pacing for throttle).

---

### `BoosterSimConnect/BoosterSimConnect.swift` (framework, modify)

**Analog:** self — existing activation site

**Current activation** (lines 1-42):
```swift
    private func activate() {
        guard !didActivate else { return }
        didActivate = true

        #if canImport(PulseProxy)
        configureNetworkLogger()
        URLSessionProxyDelegate.enableAutomaticRegistration()
        RemoteLogger.shared.initialize(store: .shared)
        RemoteLogger.shared.enable()
        #endif
    }
```

**Key adaptation:** Add `BoosterNetworkProtocol.enableAutomaticRegistration()` after the existing swizzle. Add `BoosterCommandClient.shared.start()` to begin browsing for the command Bonjour service. Both gated by `#if canImport(PulseProxy)` or separate `DEBUG` guard.

---

### Test files (test)

**Analog:** `BoosterSimAppTests/CertificateServiceTests.swift`

**Test structure + framework** (lines 1-13):
```swift
import Foundation
import Testing
@testable import BoosterSimApp

struct CertificateServiceTests {

    @Test func certificateOperationAllowsExpectedTransitions() {
        #expect(CertificateOperation.idle.canTransition(to: .generating))
        #expect(CertificateOperation.generating.canTransition(to: .error("failed")))
        #expect(CertificateOperation.error("failed").canTransition(to: .installing))
        #expect(!CertificateOperation.installing.canTransition(to: .generating))
        #expect(!CertificateOperation.resetting.canTransition(to: .rotating))
    }

    @Test func certificateStatusExposesMetadataWhenAvailable() {
        let expiry = Date(timeIntervalSince1970: 1_234_567)
        // … #expect assertions on enum associated values
    }
}
```

**Key adaptation for all 3 test files:** Same `import Testing` + `@Test func` + `#expect` pattern. File-per-concern: `BlockRuleTests` (matcher logic), `NetworkConditionProfileTests` (preset values, pacing math, Codable round-trip), `CommandPayloadTests` (BoosterCommand encode/decode, version tolerance).

---

## Shared Patterns

### Authentication / Service Ownership
**Source:** `BoosterSimApp/App/AppDelegate.swift` — all services created and owned there, injected as `@EnvironmentObject`.
**Apply to:** `CommandServer` and `NetworkConditionService` — instantiate in `AppDelegate`, add to SwiftUI environment.

### Error Handling
**Source:** `BoosterSimApp/Services/CertificateService.swift` (lines 144-170)
**Apply to:** `NetworkConditionService` — same `begin`/`fail`/`finish`/`transition` quartet with `assertionFailure` on illegal transitions and `AppLogger` for error messages.

### Persistence
**Source:** `BoosterSimApp/Models/AppSettings.swift`
**Apply to:** `NetworkConditionService` — `@AppStorage("networkConditionProfile")` for selected profile, `@AppStorage("networkBlockRules")` with `RawRepresentable` JSON wrapper for rules array.

### Design Tokens
**Source:** `BoosterSimApp/Utilities/DesignTokens.swift`
**Apply to:** All view files — `Spacing.*`, `SideWindowMetrics.*`, `CornerRadius.*`. Never hardcode layout values.

### Collapsible Section Atom
**Source:** `BoosterSimApp/Views/Shared/CollapsibleSection.swift`
**Apply to:** Both new section views (NetworkConditionsSectionView, BlockRulesView).

### Combine Publishing (no async/await)
**Source:** `BoosterSimApp/Services/ConnectService.swift` (lines 1-30) — `@Published` + `PassthroughSubject` + `sink`
**Apply to:** `NetworkConditionService` — `@Published private(set) var state: NetworkConditionState`. Command channel notifications via Combine or direct method calls on `CommandServer`.

### Buffered TCP Framing
**Source:** `BoosterSimApp/Services/PulseClientConnection.swift` (lines 68-104) — `receiveBuffer` + `maxBufferSize` + `processBuffer` loop
**Apply to:** Both `CommandServer` (per-client send buffering) and `BoosterCommandClient` (receive buffering). Use same 4-byte-length-prefix + buffer reassembly pattern. Use `copyBytes` for Data slicing (per .planning/intel/context.md connect-transport-rewrite note).

### Concurrency in Framework Target
**Source:** Upstream Pulse `NetworkDebugger` — `final class NetworkDebugger: @unchecked Sendable { ... private let lock = NSLock() }`
**Apply to:** `NetworkConditionController` — `NSLock`-protected snapshot, NOT `@MainActor`. URLProtocol callbacks arrive on session queue, not main.

## No Analog Found

Files with no close match in the codebase (planner should use RESEARCH.md patterns instead):

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| `BoosterSimConnect/BoosterNetworkProtocol.swift` | middleware | request-response | No URLProtocol subclass exists in-repo; exact upstream analog in Pulse's `MockingURLProtocol.swift` (MIT) documented in RESEARCH.md |
| `BoosterSimConnect/NetworkConditionController.swift` | service | transform | No lock-protected state store exists in-repo; pattern from upstream Pulse `NetworkDebugger` (NSLock + @unchecked Sendable) |

## Metadata

**Analog search scope:** `BoosterSimApp/Services/`, `BoosterSimApp/Views/`, `BoosterSimApp/Models/`, `BoosterSimAppTests/`, `BoosterSimConnect/`, upstream Pulse sources
**Files scanned:** 14 (PulseServer, PulseClientConnection, ConnectService, CertificateService, CertificateModels, CertificateSectionView, CollapsibleSection, FeatureRowView, NetworkTabView, AppSettings, DesignTokens, CertificateServiceTests, BoosterSimConnect, AGENTS.md)
**Pattern extraction date:** 2026-08-29