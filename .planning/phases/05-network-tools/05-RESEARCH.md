# Phase 5: Network Tools - Research

**Researched:** 2026-08-29
**Domain:** Simulator network manipulation (throttle, per-app airplane mode, request blocking) on top of the delivered Connect/Pulse inspection pipeline
**Confidence:** HIGH for the recommended architecture (all load-bearing mechanisms verified against in-repo code and upstream Pulse sources this session); MEDIUM for UX details; LOW only for cosmetic defaults (throttle profile numbers)

## Summary

Phase 5 has three open success criteria: (3) network speed throttle from the side panel, (4) per-app Simulator Airplane Mode with no Mac impact, (5) request blocking by domain/path rules. Criteria 1–2 (traffic viewer, certificates) are already delivered and out of scope.

The decisive finding: **there is no macOS/simctl mechanism for per-app or Simulator-scoped network control.** `xcrun simctl` (Xcode 26.3) has zero network subcommands [VERIFIED: simctl help output run this session — full subcommand list includes addmedia, appinfo, boot, clone, create, delete, diagnose, erase, get_app_container, getenv, icloud_sync, install, install_app_data, io, keychain, launch, list, listapps, location, logverbose, openurl, pair, pair_activate, pbcopy, pbpaste, pbsync, personalization, privacy, push, rename, runtime, shutdown, spawn, status_bar, terminate, ui, uninstall, unpair, upgrade — no network command]. Apple's Network Link Conditioner throttles the whole Mac [CITED: avanderlee.com/debugging/network-link-conditioner-utility — "you'll also experience a slow network for your Mac itself"]. A NetworkExtension content filter (RocketSim's approach) can only allow/drop flows, never shape bandwidth, and requires an Apple-approved managed entitlement plus system-extension approval [CITED: developer.apple.com/videos/play/wwdc2025/234 — "Filter providers cannot modify traffic, but simply provide a filter verdict to the system, either to allow or drop the flow"]. So packet-level throttling is architecturally out of reach for this phase, and RocketSim-grade system-extension filtering is a distribution-phase burden, not a Phase 5 feature.

The recommended architecture closes the gap **inside the target app**: BoosterSimConnect already loads into the Simulator app under test (DEBUG-only `Bundle.load()`), already swizzles URLSession via Pulse, and already holds a reverse-command-capable TCP path to BoosterSimApp. Add (a) a BoosterSim-owned **command channel** (second NWListener advertising a second Bonjour service; NWBrowser client inside BoosterSimConnect — we control both ends, zero dependence on Pulse package internals), and (b) a **`BoosterNetworkProtocol: URLProtocol`** in BoosterSimConnect that enforces three conditions on URLSession HTTP(S) traffic: fail-all (airplane, `URLError(.notConnectedToInternet)`), fail-matching (block rules), pass-through-with-pacing (throttle: latency delay before response delivery + chunked body delivery at profile bitrate). This is per-app by construction, never touches the Mac's stack, needs no entitlements, and Pulse's observer keeps reporting failed/throttled tasks so the effects are visible in the existing traffic viewer. Pulse's own MIT-licensed `MockingURLProtocol` (upstream source read this session) is the copyable precedent for the swizzle + URLProtocol pattern, and its remote protocol already demonstrates regex-matched URL rules (`URLSessionMock`) as prior art for blocking semantics.

**Primary recommendation:** Build all three tools as one mechanism — `NetworkConditionService` + `CommandServer` (macOS app) pushing full-state JSON snapshots over a second Bonjour channel to `BoosterCommandClient` + `NetworkConditionController` + `BoosterNetworkProtocol` (BoosterSimConnect framework) — surfaced in the Network tab as a single "Network Conditions" section (profile picker + airplane toggle) and a "Block Rules" list.

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| REQ-fr-16 | CA generation, install, rotate, reset against Simulator keychain; trust persists | Delivered (criteria 1–2). No new work; only interacts with Phase 5 via shared Network tab layout. |
| REQ-nfr-03 | Apple frameworks only, exception: Pulse/PulseProxy via BoosterSimConnect | Recommended architecture uses only Foundation/Network/SwiftUI/Combine on both targets; no new third-party packages. URLProtocol/swizzle pattern reuses Apple APIs (precedent: Pulse's MIT-licensed code). |
| REQ-roadmap-phase5-network-tools | Network inspection and manipulation — inspection delivered; network speed control/throttle, Simulator Airplane Mode (per-app, no Mac impact), request blocking (domain/path rules) pending | This research: rejected alternatives (simctl, dummynet/NLC, NetworkExtension) with evidence; recommended in-app interception architecture; pitfalls; validation plan for the three open criteria. |
</phase_requirements>

## Project Constraints (from CLAUDE.md)

Extracted actionable directives from the repo root `CLAUDE.md` + `AGENTS.md` + `docs/code-standards.md` (the constraint "no CLAUDE.md exists" was stale — the file exists at repo root):

- **No async/await** — Combine `@Published`, `Future`, `Timer` only (existing `SimCtlService.run` is the Future-on-background-queue precedent).
- **Swift 6 strict concurrency** at compile time, both targets; no `@unchecked Sendable` without justification.
- **Non-sandboxed by requirement** (ENABLE_APP_SANDBOX = NO) — NetworkExtension approval friction noted below is unrelated to sandboxing.
- **Design tokens mandatory** (`Utilities/DesignTokens.swift`: `Spacing`, `CornerRadius`, `SideWindowMetrics`); SF Pro + SF Symbols only; amber accent.
- **All subprocess spawning through SimCtlService** — though Phase 5 adds no simctl usage.
- **Files < 200 LOC, split by concern**, PascalCase matching primary type, `// MARK:` order Properties/Lifecycle/Public/Private.
- **Swift Testing for unit tests** (`import Testing`, `@Test`, `#expect`) under `BoosterSimAppTests/`; behavior-named tests; UI tests under `BoosterSimAppUITests/` (XCTest).
- **Conventional Commits** (`feat(network): ...`).
- **GitNexus:** executor MUST run impact analysis before editing existing symbols (`ConnectService`, `PulseServer`, `NetworkTabView`, `AppDelegate`, `AppSettings` are all touched by this phase).
- **`docs/` is the single source of truth** — update `system-architecture.md` / `codebase-summary.md` after the feature lands.
- **RocketSim reference** (`../RocketSimApp/dev-docs/`, read-only) — consulted; its public docs are the UX/mechanism reference (see Sources).

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Throttle profile state, rule editing, persistence | macOS app (BoosterSimApp service + views) | — | UI/persist belongs to the tool app; single source of truth for desired conditions |
| Condition enforcement (block/airplane/throttle) | Simulator app process (BoosterSimConnect URLProtocol) | — | Per-app scoping impossible at OS level (see Summary); in-process URLProtocol is the only entitlement-free per-app interception point |
| Command delivery (Mac → Simulator app) | macOS app (CommandServer, NWListener + Bonjour) | Simulator app (BoosterCommandClient, NWBrowser) | Reverse channel; both endpoints are ours; Pulse's RemoteLogger owns its connection and cannot host custom client-side handlers |
| Telemetry of blocked/throttled requests (viewer visibility) | Pulse observer (existing) | BoosterSimApp ConnectService | Unchanged: URLSessionSwizzler logs failed tasks; code-10 events flow to traffic viewer today |
| Traffic viewer / certs UI (delivered) | macOS app views | — | Out of scope; new sections mount into the same Network tab |

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Foundation (URLProtocol, URLSession) | macOS 15 SDK (Xcode 26.3) | In-app interception + pacing | Apple-only policy (REQ-nfr-03); Pulse's own MockingURLProtocol proves the pattern in this exact context |
| Network (NWListener, NWConnection, NWBrowser) | macOS 15 SDK | Command channel + Bonjour | Already the project's transport (PulseServer/RemoteLogger both Network.framework); simulator apps reach the Mac host stack, proven by delivered pipeline |
| Combine | macOS 15 SDK | Service → view publishing | Project convention: no async/await |
| SwiftUI/AppKit | macOS 15 SDK | Panel UI | Existing shell |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Pulse / PulseProxy (SPM, existing) | pinned (see Pitfall 13) | Observation only — do NOT extend | Keep Pulse strictly as the reporter; no new coupling to its internals |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| In-app URLProtocol enforcement | NEFilterDataProvider content filter (RocketSim's way) | Packet-level truth + works without app embedding, BUT needs Apple-approved managed entitlement (`com.apple.developer.networking.networkextension`, `content-filter-provider[-systemextension]`), system-extension install entitlement, matching provisioning profiles, macOS user approval in Login Items & Extensions [CITED: developer.apple.com/help/account/reference/provisioning-with-managed-capabilities; rocketsim.app docs]. And a filter **cannot throttle** — verdicts are allow/drop only [CITED: WWDC25 session 234]. Reject for Phase 5; revisit only if "block ALL simulator traffic incl. non-URLSession" becomes a requirement. |
| In-app URLProtocol enforcement | dummynet (dnctl/pfctl) shaping on the simulator bridge | Affects the whole Mac or whole interfaces; PF cannot match per-process [CITED: blog.leiy.me/post/bw-throttling-on-mac]; violates criterion 4 "no impact on Mac connectivity". `dnctl` exists on this machine (/usr/sbin/dnctl) but scoping is fatal, not the tool's availability. |
| In-app URLProtocol enforcement | Pulse-native mocks (wire `updateMocks`/`getMockedResponse`) | Blocking/airplane could ride Pulse's MockingURLProtocol today (protocol verified this session — see Code Examples), but it depends on package-internal wire encoding, needs a per-request server round trip, and **cannot throttle** (no delay field in `URLSessionMockedResponse`). Two enforcement mechanisms instead of one. Keep as documented fallback, not the plan. |
| Second Bonjour command channel | Custom packet codes on the existing Pulse connection | Client-side `RemoteLogger` safely ignores unknown codes (`default: break // Do nothing` [VERIFIED: github.com/kean/Pulse main Sources/Pulse/RemoteLogger/RemoteLogger.swift, `connection(_:didReceiveEvent:)`]) — but nothing would *apply* them; we cannot inject handlers into Pulse's receive loop. A fork of RemoteLogger is worse than a parallel 80-LOC client. |

**Installation:** none — no new packages. REQ-nfr-03 remains satisfied.

**Version verification:** No registry lookups needed (Apple-SDK only). Toolchain verified on this machine: Xcode 26.3 (Build 17C529), macOS 26.6.2 [VERIFIED: `xcodebuild -version` / `sw_vers` this session].

## Package Legitimacy Audit

**Not applicable — this phase installs no external packages.** Pulse/PulseProxy are already vendored via SPM under the existing REQ-nfr-03 exception. No SPM changes are recommended (do not bump Pulse while extending BoosterSimConnect — see Pitfall 13).

## Architecture Patterns

### System Architecture Diagram

```
                 ┌─────────────────────────── macOS (BoosterSimApp) ───────────────────────────┐
                 │                                                                             │
  User toggles ─▶│ NetworkConditionService (@MainActor)                                        │
  profile/rules  │  • NetworkConditionProfile (off / 3g / edge / … / airplane)                  │
  in Network tab │  • [BlockRule] (domain + path matchers)                                      │
                 │  • state machine idle→applying→applied/error; reconcile on client connect    │
                 │        │ full-state JSON snapshot (idempotent)                               │
                 │        ▼                                                                    │
                 │  CommandServer (NEW: NWListener, Bonjour "_booster-cmd._tcp.", port 0)       │
                 │        │ broadcast to all connected clients                                  │
                 └────────┼────────────────────────────────────────────────────────────────────┘
                          │ TCP, length-prefixed JSON  (Mac loopback — Simulator shares host stack)
   ┌──────────────────────▼──────────── iOS Simulator app process (DEBUG) ──────────────────────┐
   │ BoosterCommandClient (NEW: NWBrowser → NWConnection)  ──▶ NetworkConditionController        │
   │                                                        (lock-protected snapshot, Sendable)  │
   │                                                                    │ reads snapshot        │
   │ URLSession ──▶ [swizzled init prepends] ──▶ BoosterNetworkProtocol (NEW: URLProtocol)       │
   │                          │                                                 │                   │
   │                          ├─ airplane ON ─────▶ fail URLError(.notConnectedToInternet) ──┐  │
   │                          ├─ rule match ───────▶ fail URLError(block error code) ───────┤  │
   │                          └─ throttle ON ─▶ inner URLSession (header-guarded,            │  │
   │                                              protocolClasses stripped) → latency delay   │  │
   │                                              → paced body chunks at profile bitrate       │  │
   │                                                                                         ▼  │
   │ PulseProxy/URLSessionProxyDelegate observer (unchanged) logs failed/slow tasks ── code 10 ──┘
   └──────────────────────────────────────┬─────────────────────────────────────────────────────┘
                                          │ existing "_pulse._tcp." event stream (unchanged)
                     ┌────────────────────▼──────────────┐
                     │ ConnectService → traffic viewer   │
                     │ (blocked/throttled requests show  │
                     │  as error/slow rows — delivered)  │
                     └───────────────────────────────────┘

  Mac's own connectivity: never traversed. NWConnection-based channels (Pulse telemetry,
  BoosterCommandClient) are NOT URLSession traffic → airplane mode never severs control/telemetry.
```

### Recommended Project Structure
```
BoosterSimApp/
├── Services/
│   ├── CommandServer.swift            # NWListener + Bonjour "_booster-cmd._tcp.", JSON frames, broadcast
│   └── NetworkConditionService.swift  # @MainActor ObservableObject; state machine; push + reconcile
├── Models/
│   ├── NetworkConditionProfile.swift  # presets (off/3g/edge/lte/wifi/custom…) + Codable command payload
│   └── BlockRule.swift                # Codable rule + pure matcher (testable)
└── Views/SideWindow/network/
    ├── NetworkConditionsSectionView.swift   # profile picker pills + airplane toggle + status caption
    └── BlockRulesView.swift                 # rule list editor (add/remove/toggle rows)
BoosterSimConnect/
├── BoosterSimConnect.swift            # existing activation + NEW: session hook installation
├── BoosterCommandClient.swift         # NWBrowser("_booster-cmd._tcp.") → NWConnection → JSON frames
├── NetworkConditionController.swift   # lock-based snapshot store (Sendable, not @MainActor)
└── BoosterNetworkProtocol.swift       # URLProtocol: airplane / block / throttle(pass-through+pacing)
BoosterSimAppTests/
├── BlockRuleTests.swift               # Wave 0
├── NetworkConditionProfileTests.swift # Wave 0
└── CommandPayloadTests.swift          # Wave 0 (Codable round-trip)
```

### Pattern 1: Reverse command channel with full-state snapshots
**What:** Second NWListener on the Mac (mirroring the in-repo PulseServer structure) + NWBrowser client in the framework; every state change and every client connect sends the *complete* desired condition set as one JSON snapshot.
**When to use:** Always for Mac→Simulator-app control.
**Why snapshots, not deltas:** A relaunching Simulator app starts with empty state; a missed frame self-heals on the next push; reconnect triggers reconcile (same philosophy as the in-repo certificate trust reconciliation on Simulator change — SideWindowController re-checks trust on `activeSimulator` changes [CITED: .planning/intel/context.md "SideWindowController" entry]).
**In-repo precedent (verbatim):** PulseServer already does server-mode + Bonjour + OS-assigned port — [VERIFIED: BoosterSimApp/Services/PulseServer.swift:31-36]:
```swift
let params = NWParameters.tcp
params.includePeerToPeer = true
...
let listener = try NWListener(using: params, on: NWEndpoint.Port(rawValue: 0)!)
listener.service = NWListener.Service(name: "BoosterSimApp", type: "_pulse._tcp.")
```
The command server is the same shape with `type: "_booster-cmd._tcp."`.

### Pattern 2: URLProtocol injection via URLSession init swizzle (Pulse's MIT pattern)
**What:** Swizzle `URLSession.init(configuration:delegate:delegateQueue:)` once, prepend `BoosterNetworkProtocol` to `protocolClasses`, call the original imp.
**When to use:** At BoosterSimConnect activation (same moment Pulse's hooks install today).
**Precedent (verbatim, MIT © 2020-2026 Alexander Grebenyuk)** — [VERIFIED: github.com/kean/Pulse main Sources/Pulse/NetworkDebugger/MockingURLProtocol.swift]:
```swift
@MainActor
public static func enableAutomaticRegistration() {
    if let lhs = class_getClassMethod(URLSession.self, #selector(URLSession.init(configuration:delegate:delegateQueue:))),
       let rhs = class_getClassMethod(URLSession.self, #selector(URLSession.pulse_init2(configuration:delegate:delegateQueue:))) {
        method_exchangeImplementations(lhs, rhs)
    }
}

private extension URLSession {
    @objc class func pulse_init2(configuration: URLSessionConfiguration, delegate: URLSessionDelegate?, delegateQueue: OperationQueue?) -> URLSession {
        guard isConfiguringSessionSafe(delegate: delegate) else {
            return self.pulse_init2(configuration: configuration, delegate: delegate, delegateQueue: delegateQueue)
        }
        configuration.protocolClasses = [MockingURLProtocol.self] + (configuration.protocolClasses ?? [])
        return self.pulse_init2(configuration: configuration, delegate: delegate, delegateQueue: delegateQueue)
    }
}
```
Copy this shape (renamed selectors, `BoosterNetworkProtocol.self`), including the safety guard idea (`isConfiguringSessionSafe` skips GTMSessionFetcher delegates upstream).

### Pattern 3: Condition decision as a pure function
**What:** `NetworkConditionController.evaluation(for: URLRequest) -> .passThrough | .fail(URLError) | .throttle(profile)` computed from a lock-copied snapshot — pure, synchronous, unit-testable.
**When to use:** `canInit(with:)` returns true only for non-`.passThrough`; `startLoading()` re-evaluates and enforces. Keeps the URLProtocol thin and the logic in tests (Nyquist — see Validation Architecture).

### Pattern 4: Throttle enforcement = latency sleep + paced chunk delivery
**What:** Pass through via an inner ephemeral URLSession whose requests carry a guard header; on response, wait `latencyMs` before `client?.urlProtocol(didReceive:)`, then deliver the body in N-byte chunks at `interval = chunkBytes * 8 / kbps` via a serial queue; `stopLoading` cancels inner task + pending items.
**Precedent:** Mocker's `mock.delay = DispatchTimeInterval.seconds(5)` [CITED: github.com/WeTransfer/Mocker]; OHHTTPStubs `requestTime`/`responseTime`; delivery uses the standard `URLProtocolClient` callbacks `urlProtocol(_:didReceive:)`, `urlProtocol(_:didLoad:)`, `urlProtocolDidFinishLoading` [CITED: developer.apple.com/documentation/foundation/urlprotocolclient].

### Pattern 5: State machine service mirroring CertificateService
**What:** `NetworkConditionService` publishes `idle / applying / applied / error(reason)`; every UI action goes through allowed-transition checks. In-repo precedent of exactly this test style — [VERIFIED: BoosterSimAppTests/CertificateServiceTests.swift:7-13]:
```swift
@Test func certificateOperationAllowsExpectedTransitions() {
    #expect(CertificateOperation.idle.canTransition(to: .generating))
    ...
    #expect(!CertificateOperation.resetting.canTransition(to: .rotating))
}
```

### Anti-Patterns to Avoid
- **Driving Pulse's mock machinery from the Mac side** (wire `updateMocks`/`getMockedResponse`): works today (mechanism verified below) but couples BoosterSimApp to package-internal JSON encoding of `RemoteLogger.Path` and adds a per-request server round trip; also covers only 2 of 3 tools. One mechanism beats two.
- **Throttling by failing/retrying or dropping requests** (fake "100% loss" via random fails inside URLProtocol): breaks retry/backoff semantics in unpredictable ways; if loss simulation is wanted, do it as a profile flag that fails requests *deterministically per-rule*, not randomly inside pass-through.
- **`@MainActor` on the URLProtocol or controller**: URLProtocol callbacks arrive on the session's internal queue, not main. Use lock/`Mutex`-protected state (Pulse's `NetworkDebugger` uses `NSLock` [VERIFIED: github.com/kean/Pulse main Sources/Pulse/NetworkDebugger/NetworkDebugger.swift — `final class NetworkDebugger: @unchecked Sendable { ... private let lock = NSLock() }]`).
- **Delta command protocol**: send full snapshots (Pattern 1).
- **New hardcoded layout values**: DesignTokens only (`Spacing`, `CornerRadius`, `SideWindowMetrics`) — code-standards mandate.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Mac↔Simulator transport + discovery | Custom sockets/mDNS | Network.framework NWListener/NWConnection/NWBrowser + Bonjour | Project already ships this exact stack; simulator↔Mac loopback proven by the delivered pipeline |
| Session interception | Delegate-chain wrapping or `__NSCFURLSessionTask` method swizzling | protocolClasses injection at init (Pattern 2) | Delegate wrapping only sees delegate-based sessions; task swizzling touches private classes (Pulse's own swizzler notes fragility) |
| Block matching engine | Regex compiler / full glob engine | Exact-host, host-suffix (`*.domain`), path-prefix string ops on `URL.host`/`URL.path` | User input never becomes a regex → no ReDoS surface (see Security); Pulse's regex `URLSessionMock` is prior art, not a requirement |
| Traffic-viewer visibility of blocked requests | Extra event injection into ConnectService | Do nothing — Pulse observer already reports failed tasks as code-10 events; `ConnectService.convertToNetworkEvent` already maps errors to `errorStr` [VERIFIED: BoosterSimApp/Services/ConnectService.swift:84-89 — `if let err = pulseEvent.error { errorStr = "\(err.domain): \(err.debugDescription) (code \(err.code))" }`] | Zero pipeline changes for visibility |
| Bandwidth shaping at packet level | dummynet/pfctl helper, NetworkExtension | URL-level pacing (Pattern 4) | OS-level tools affect the whole Mac or need Apple entitlements; rejected with evidence (Alternatives table) |

**Key insight:** The only per-app network boundary Apple gives you without entitlements is the app's own process. BoosterSimConnect already lives there — Phase 5 is an extension of the delivered architecture, not a new subsystem.

## Runtime State Inventory

> Phase 5 adds features but also introduces *new* runtime state that outlives UI sessions; inventory of what must persist/reconcile:

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data (app) | New: throttle profile selection, airplane toggle state, block rules list — persist via `@AppStorage` (existing AppSettings pattern [VERIFIED: BoosterSimApp/Models/AppSettings.swift:34-37 — `@AppStorage("sideWindowPosition") var position: SideWindowPosition = .dynamic` …]) | Code edit: new keys (e.g. `networkConditionProfile`, `networkBlockRules`); rules array needs `RawRepresentable`-style JSON wrapper |
| Stored data (Simulator app) | Framework-side condition snapshot — ephemeral, resets on app relaunch | Reconcile: CommandServer pushes full snapshot on every client connect |
| Live service config | None external — no simctl/launchd/agents state introduced | None |
| OS-registered state | None — no NetworkExtension, no system extension, no privileged helper (explicitly rejected) | None — verified by choice of architecture |
| Secrets/env vars | None | None |
| Build artifacts | BoosterSimConnect.framework copy in `Contents/Resources/` (existing Run Script, two-step pre-build) — new framework source files ride the existing copy phase | None new; verify copy phase still runs (Pitfall 13) |

## Common Pitfalls

### Pitfall 1: Swizzle timing — sessions created before BoosterSimConnect loads
**What goes wrong:** `URLSession.shared` or sessions built in static/`init` code before the framework's `Bundle.load()` never get `BoosterNetworkProtocol` injected; airplane/block silently miss that traffic.
**Why it happens:** The swizzle only affects sessions constructed after it installs.
**How to avoid:** Document that the loader runs at app entry point (existing ConnectSetupView snippet does this [VERIFIED: BoosterSimApp/Views/SideWindow/network/ConnectSetupView.swift:8-12 — `Bundle(path: "/Applications/Booster.app/Contents/Resources/BoosterSimConnect.framework")?.load()`]). Surface a UI caption ("applies to requests made after launch").
**Warning signs:** Some requests still succeed in airplane mode.

### Pitfall 2: Recursion in the pass-through protocol
**What goes wrong:** `BoosterNetworkProtocol.startLoading()` creates its own URLSession; that inner session also goes through the swizzled init (both our protocol *and* Pulse's `MockingURLProtocol` get prepended) → infinite interception or double-mocking.
**Why it happens:** Swizzled init mutates *every* configuration it sees.
**How to avoid:** Guard header on inner requests (`X-Booster-Internal: 1`); `canInit` returns false when present. Precedent: Pulse's own `requestMockedHeaderName` — `static let requestMockedHeaderName = "X-PulseRequestMocked"` + `canonicalRequest` adds it [VERIFIED: MockingURLProtocol.swift]. Also set the inner config's `protocolClasses = []` *and* accept MockingURLProtocol may still be prepended — the header guard is the real defense.
**Warning signs:** Hangs or stack overflow on first throttled request.

### Pitfall 3: NWPathMonitor-based offline UI won't react
**What goes wrong:** The app under test shows "online" (path monitor reports satisfied) while every request fails; devs conclude airplane mode "doesn't work".
**Why it happens:** In-process URLProtocol failures never change the system network path; `NWPathMonitor` reads system state.
**How to avoid:** Document honestly (RocketSim FAQ answers the identical complaint [CITED: rocketsim.app/llms-full.txt — "RocketSim only blocks connections coming from your configured bundle identifier. We're also optimized for URLSession-based applications."]); test flows driven by request failure (`.notConnectedToInternet`) which is the error code real airplane mode produces. Optional stretch: BoosterSimConnect posts an `NSNotification` (`BoosterSimAirplaneModeChanged`) the app may observe — one line, no framework fight.
**Warning signs:** Bug reports "reachability still says online".

### Pitfall 4: Coverage gaps — WebSocket, WKWebView, Network.framework, background transfers
**What goes wrong:** Blocked/throttled expectations don't apply to `URLSessionWebSocketTask` (URLProtocol interception unsupported — "Connection not set before response is received" [CITED: developer.apple.com/forums/thread/729943]), WKWebView (networking out-of-process, "does not 'see' your NSURLProtocol subclass" — Apple DTS [CITED: developer.apple.com/forums/thread/64240]), NWConnection, or background sessions reliably.
**How to avoid:** State scope in the UI copy ("URLSession HTTP(S) traffic"); same limitation class RocketSim ships with.
**Warning signs:** Websocket-driven apps unaffected.

### Pitfall 5: Airplane mode must not sever the tool's own channels
**What goes wrong:** Naive "block everything" also kills telemetry → viewer goes dark exactly when testing offline.
**Why it happens:** Only if interception were delegate/network-level.
**How to avoid:** Already safe by construction: Pulse's RemoteLogger and the new BoosterCommandClient use `NWConnection` (Network.framework), not URLSession [VERIFIED: RemoteLogger-Connection.swift — `package init(_ connection: NWConnection, …)`], which bypasses URLProtocol entirely. Add a regression note in tests/docs.
**Warning signs:** Traffic viewer disconnects when airplane toggles.

### Pitfall 6: Swift 6 strict concurrency in the framework target
**What goes wrong:** `@MainActor` controller deadlocks/asserts from URLProtocol queue; or `nonisolated` violations fail the build (project enforces strict concurrency).
**How to avoid:** Controller = `final class` + `NSLock` (Pulse's NetworkDebugger precedent); NWBrowser/NWConnection callbacks hop to main via `DispatchQueue.main.async` (or `MainActor.assumeIsolated` as Pulse does [VERIFIED: RemoteLogger-Connection.swift — `MainActor.assumeIsolated { self?.delegate?.connection(...) }`]). Mac-side service stays `@MainActor` per code standards.
**Warning signs:** Build errors on framework target; runtime isolation crashes.

### Pitfall 7: Outer-request timeouts during throttle latency
**What goes wrong:** The app's `timeoutIntervalForRequest` fires while the protocol sleeps in the latency phase → `URLError(.timedOut)` before any bytes — actually *realistic* (real 3G does this), but surprising.
**How to avoid:** Intended behavior — document. Do not extend app timeouts silently.
**Warning signs:** All requests time out under high-latency profiles with tight client timeouts.

### Pitfall 8: Upload/body-stream fidelity
**What goes wrong:** `request.httpBody` is nil for stream uploads inside URLProtocol; forwarding `httpBodyStream` requires manual stream reads.
**How to avoid:** v1 scope: throttle download bandwidth + latency; treat upload throttling as approximated by the latency phase. Document as approximation (this is HTTP-level emulation, not packet shaping — see State of the Art).

### Pitfall 9: Multiple connected Simulator apps
**What goes wrong:** Two apps embedding BoosterSimConnect both receive broadcasts; conditions are global to all *embedding* apps while the criterion is "per-app".
**How to avoid:** This matches the criterion's intent ("per-app" = the app under test, vs. the Mac) and RocketSim's default (targets recent builds unless bundle IDs given [CITED: rocketsim.app/llms-full.txt]). If scoping is later wanted, add a bundle-ID allowlist to the snapshot payload — the protocol already carries app info via `PulseAppInfo.bundleId` [VERIFIED: BoosterSimApp/Services/PulsePacketDecoder.swift:38-43 — `struct PulseAppInfo: Codable { let bundleId: String? … }`].
**Warning signs:** Two simulators both throttled when user expected one.

### Pitfall 10: Error-code choice for block rules
**What goes wrong:** Failing blocked requests with `.cancelled` triggers SDK retry logic; failing with an HTTP 5xx hides them from error-driven UI.
**How to avoid:** Default: `URLError(.notConnectedToInternet)` for airplane, `URLError(.cannotConnectToHost)` for rules (surfaced as error rows in the viewer via existing error mapping). Exact raw codes must be verified at implementation time [ASSUMED — do not hardcode until checked against URLError.Code docs].
**Warning signs:** Infinite retries against blocked hosts.

### Pitfall 11: Command frame decoding on partial TCP reads
**What goes wrong:** Treating each NWConnection receive as one message corrupts the stream under load.
**How to avoid:** Length-prefixed frames + buffered reassembly — the in-repo receive loop is the precedent: `PulseClientConnection` buffers with `receiveBuffer` and a 10 MB cap [VERIFIED: BoosterSimApp/Services/PulseClientConnection.swift:38-39 — `private var receiveBuffer = Data()` / `private static let maxBufferSize = 10 * 1024 * 1024 // 10 MB safety cap`]. Mirror it on both ends of the command channel (avoid the Data-slice alignment trap already fixed once — use `copyBytes`, per .planning/intel/context.md connect-transport-rewrite).

### Pitfall 12: UI surface creep in the Network tab
**What goes wrong:** Network tab becomes a scroll graveyard; panel is 260pt wide [VERIFIED: REQUIREMENTS.md REQ-fr-07 "expanded state is a 260pt panel"].
**How to avoid:** Two `CollapsibleSection`s ("Network Conditions", "Block Rules") using the existing atom [in-repo: Views/Shared/CollapsibleSection.swift]; ≤2-click rule from the core value statement (profile pill + toggle). Default collapsed when no conditions active.

### Pitfall 13: Pulse version drift
**What goes wrong:** Upgrading Pulse changes `URLSessionProxyDelegate.enableAutomaticRegistration` behavior (already soft-deprecated upstream in favor of `NetworkLogger.enableProxy()` [VERIFIED: URLSessionProxyDelegate+AutomaticRegistration.swift — `@available(*, deprecated, message: "Experimental.URLSessionProxy is replaced with NetworkLogger.enableProxy() from the PulseProxy target")`]) or the remote wire format.
**How to avoid:** Pin Pulse in `Package.resolved` this phase; schedule the API migration (enableProxy) as its own follow-up; keep our command channel fully independent so Pulse churn can't break manipulation.

## Code Examples

### Verified: Pulse's wire protocol already models block rules (prior art, not the plan)
[VERIFIED: github.com/kean/Pulse main Sources/Pulse/RemoteLogger/RemoteLogger-Protocol.swift] — verbatim:
```swift
package enum PacketCode: UInt8, Equatable {
    // Handshake
    case clientHello = 0 // PacketClientHello
    case serverHello = 1 // ServerHelloResponse
    // Controls
    case pause = 2
    case resume = 3
    ...
    case message = 13
}
...
package enum Path: Codable {
    case updateMocks
    case getMockedResponse(mockID: UUID)
}
...
package struct URLSessionMock: Hashable, Codable {
    package let mockID: UUID
    package var pattern: String
    package var method: String?
    package var skip: Int?
    package var count: Int?
    ...
    package func isMatch(_ url: String) -> Bool {
        guard let regex = try? Regex(pattern, [.caseInsensitive]) else {
            return false
        }
        return regex.isMatch(url)
    }
}
```
And the client applies server-pushed mocks — [VERIFIED: github.com/kean/Pulse main Sources/Pulse/RemoteLogger/RemoteLogger.swift]:
```swift
switch message.path {
case .updateMocks:
    let mocks = try JSONDecoder().decode([URLSessionMock].self, from: message.data)
    NetworkDebugger.shared.update(mocks)
case .getMockedResponse, .openMessageDetails, .openTaskDetails:
    break // Server specific (should never happen)
default:
    break // Do nothing
}
```
Note `NetworkDebugger` is package-internal (`final class NetworkDebugger`, no `public`) [VERIFIED: NetworkDebugger.swift] — mocks cannot be driven via public API, only via the wire. This is exactly the coupling the recommended design avoids.

### Recommended: command snapshot payload (both targets — keep schemas in sync, test the round-trip)
```swift
// Source: design for this phase (no upstream source; structure follows in-repo Codable models
// like PulseClientHello [VERIFIED: PulsePacketDecoder.swift:25-29])
struct BoosterCommand: Codable {
    let version: Int                  // bump on schema change; client ignores unknown versions
    let airplane: Bool
    let throttle: ThrottleSpec?       // nil = off
    let blockRules: [BlockRule]
}

struct ThrottleSpec: Codable {
    let latencyMs: Int
    let downloadKbps: Int
    let uploadKbps: Int?              // approximated (Pitfall 8)
}

struct BlockRule: Codable, Identifiable {
    let id: UUID
    var domain: String                // exact or "*.example.com" suffix
    var pathPrefix: String?           // "/api/v1/ads"
    var isEnabled: Bool = true
}
```

### Recommended: enforcement decision (pure, testable)
```swift
// Source: design for this phase; evaluation mirrors Pulse's canInit gating shape
// [VERIFIED: MockingURLProtocol.swift — canInit checks connection + shouldMock]
enum ConditionVerdict {
    case passThrough
    case fail(URLError.Code)
    case throttle(ThrottleSpec)
}

func evaluate(request: URLRequest, snapshot: BoosterCommand) -> ConditionVerdict {
    guard !isInternalGuarded(request) else { return .passThrough }   // Pitfall 2
    if snapshot.airplane { return .fail(.notConnectedToInternet) }
    if let rule = snapshot.blockRules.first(where: { $0.isEnabled && $0.matches(request) }) {
        return .fail(.cannotConnectToHost)                            // Pitfall 10
    }
    if let throttle = snapshot.throttle { return .throttle(throttle) }
    return .passThrough
}
```

### Verified: what the Network tab looks like today (mount point)
[VERIFIED: BoosterSimApp/Views/SideWindow/tabs/NetworkTabView.swift:24-62] — body composes `ConnectStatusBanner` → (`ConnectSetupView` | `TrafficFilterBar` + `TrafficList`) → `Divider()` → `CertificateSectionView`, plus `.sheet(item: $selectedEvent) { TrafficDetailView(event:) }`. New sections slot between `Divider()` and `CertificateSectionView`.

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Network Link Conditioner / dummynet for slow-network testing | Per-app NetworkExtension filters (RocketSim) or in-app URLProtocol pacing | RocketSim networking tools shipped ~2024 (v13+); NLC unchanged (whole-Mac) | RocketSim proves users accept "URLSession-only" per-app semantics; their profiles (`airplane, 100-loss, 3g, edge, lte, wifi, dsl, very-bad` [CITED: rocketsim.app/llms-full.txt]) are the naming baseline |
| Proxy-based inspection (Charles/Proxyman) | Embedded observers (Pulse/BoosterSimConnect) | PulseProxy era | Blocking in proxies is global & MITM-based; in-app blocking is per-app and TLS-clean |
| Delegate-based session hooking (`URLSessionProxyDelegate`, soft-deprecated upstream in Pulse 5.0) | Task-level swizzler `NetworkLogger.enableProxy()` | Pulse 5.0 | BoosterSimConnect currently calls the deprecated API — schedule migration, don't mix into Phase 5 |

**Deprecated/outdated:**
- `URLSessionProxyDelegate.enableAutomaticRegistration(logger:)` — soft-deprecated upstream [VERIFIED: URLSessionProxyDelegate+AutomaticRegistration.swift deprecation attribute quoted above]; still functional, currently used by BoosterSimConnect.
- dummynet/NLC for *Simulator* work — industry consensus is they throttle the dev machine too [CITED: avanderlee.com; rocketsim.app FAQ "How does this feature differ from the Network Link Conditioner?"].

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `URLError.Code.notConnectedToInternet` / `.cannotConnectToHost` raw values appropriate for fail-verdicts (exact numeric codes not verified this session) | Patterns/Pitfall 10 | Low — verify once at implementation; semantics (code choice) is the real decision |
| A2 | Throttle profile numbers (e.g., 3G ≈ 750 Kbps down / 400 ms latency) — recommended defaults, not compliance targets | Standard Stack | Low — planner/user picks numbers; RocketSim profile *names* are cited, values are ours |
| A3 | Simulator apps can reach a second Bonjour service on Mac loopback exactly like the existing `_pulse._tcp.` channel | Architecture | Low — same mechanism as delivered pipeline (NWListener service + client browse); smoke-test first task anyway |
| A4 | `@AppStorage`-persisted Codable arrays via RawRepresentable wrapper is acceptable under code standards ("no raw UserDefaults in views" respected) | Runtime State | Low — established SwiftUI pattern |
| A5 | Upload bandwidth throttling approximated by latency phase only (no paced body-stream forwarding in v1) | Pitfall 8 | Medium — upload-heavy apps see less faithful shaping; documented approximation |
| A6 | Blocked/throttled requests continue to appear in the traffic viewer purely via existing code-10 error/slow-task events (no extra reporting path needed) | Diagram / Don't Hand-Roll | Medium — if Pulse's observer misses URLProtocol-failed tasks in some session configs, blocked requests would be invisible; verify during first smoke test |
| A7 | macOS 15 min-target compatibility of all APIs used (URLProtocol, NWListener service, NWBrowser) — dev machine runs macOS 26/Xcode 26.3 | Environment | Low — all APIs predate macOS 15 |

## Open Questions

1. **Block-rule failure semantics — URLError vs HTTP status?**
   - What we know: airplane must be `.notConnectedToInternet` to read as offline; rules could also serve HTTP 403/526 for server-driven UI branches.
   - What's unclear: which default the target apps' retry logic tolerates better.
   - Recommendation: ship URLError default (Pitfall 10), add per-rule "respond with status" only if requested.
2. **Should conditions auto-reset when the last client disconnects or BoosterSimApp quits?**
   - What we know: framework state dies with the app process; persisted Mac-side profile re-applies on next connect (Pattern 1).
   - What's unclear: whether users expect "off" after restarting the tool app.
   - Recommendation: persist + re-apply (matches certificate trust persistence behavior, REQ-fr-16 precedent), with a visible "active" caption in the panel.
3. **Scope of "per-app" with multiple connected apps** (Pitfall 9) — recommend global-to-embedding-apps for v1, bundle-ID allowlist as stretch. Planner should encode the decision in the task list either way.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Xcode + macOS SDK | Build both targets | ✓ | Xcode 26.3 (17C529) | — |
| macOS runtime | Run app | ✓ | 26.6.2 (target min 15) | — |
| iOS Simulator runtime | End-to-end smoke (embedded framework) | ✓ | via Xcode 26.3 | unit tests cover logic; live test manual |
| `/usr/sbin/dnctl`, `/sbin/pfctl`, `/usr/sbin/networksetup` | *Rejected* approaches only | ✓ present | — | not used |
| Bonjour/mDNS on loopback | Command channel | ✓ (delivered `_pulse._tcp.` pipeline proves it) | — | — |

**Missing dependencies with no fallback:** none.
**Missing dependencies with fallback:** none — all required tooling verified present this session.

## Validation Architecture

> `.planning/config.json` does not exist → `workflow.nyquist_validation` treated as enabled.

### Test Framework
| Property | Value |
|----------|-------|
| Framework | Swift Testing (`import Testing`, `@Test`, `#expect`) — in-repo convention (AGENTS.md; CertificateServiceTests precedent) |
| Config file | none — tests live in `BoosterSimAppTests/`, discovered by the Xcode target |
| Quick run command | `xcodebuild -project BoosterSimApp.xcodeproj -scheme BoosterSimApp -destination 'platform=macOS' test -only-testing:BoosterSimAppTests/BlockRuleTests` |
| Full suite command | `xcodebuild -project BoosterSimApp.xcodeproj -scheme BoosterSimApp -destination 'platform=macOS' test -only-testing:BoosterSimAppTests` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| SC3 (throttle) | Pacing math: chunk schedule from data size + kbps + latency is deterministic | unit | `… -only-testing:BoosterSimAppTests/NetworkConditionProfileTests` | ❌ Wave 0 |
| SC3 (throttle) | Service state machine allows/legal transitions (idle→applying→applied→off; error recovery) | unit | `… -only-testing:BoosterSimAppTests/NetworkConditionServiceTests` | ❌ Wave 0 |
| SC3/4/5 (all) | `BoosterCommand` Codable round-trip + unknown-version tolerance | unit | `… -only-testing:BoosterSimAppTests/CommandPayloadTests` | ❌ Wave 0 |
| SC4 (airplane) | `evaluate(request:)` verdicts: airplane→fail(notConnectedToInternet); guard-header requests always pass | unit (pure decision fn, no network) | `… -only-testing:BoosterSimAppTests/ConditionVerdictTests` | ❌ Wave 0 |
| SC5 (blocking) | `BlockRule.matches`: exact host, `*.suffix` host, path prefix, case-insensitive host, non-match, disabled rule, port/URL edge cases | unit | `… -only-testing:BoosterSimAppTests/BlockRuleTests` | ❌ Wave 0 |
| SC3/4/5 (e2e) | Real Simulator app embedding BoosterSimConnect: airplane fails requests, viewer shows error rows, Mac connectivity untouched (browse from Mac during airplane) | manual-only | — (needs Simulator + target app; consistent with NET-04 being a deferred v2 item) | n/a — justify in plan |

Note: framework-side classes (`BoosterNetworkProtocol`, controller) are not importable by `BoosterSimAppTests` (separate targets). Keep decision logic in `NetworkConditionService`/`BlockRule` on the Mac side where possible; framework-side logic is smoke-tested manually. Commands flow Mac→framework, so Mac-side payload tests cover the contract surface both ends must satisfy.

### Sampling Rate
- **Per task commit:** quick run command (single new test file)
- **Per wave merge:** full suite command
- **Phase gate:** full suite green + one manual e2e run (airplane on → request fails + error row visible + Mac browsing works; throttle 3g → visibly slow load; block rule → 403-style failure row) before `/gsd-verify-work`

### Wave 0 Gaps
- [ ] `BoosterSimAppTests/BlockRuleTests.swift` — covers SC5 matcher behavior
- [ ] `BoosterSimAppTests/NetworkConditionProfileTests.swift` — covers SC3 pacing math + preset integrity
- [ ] `BoosterSimAppTests/NetworkConditionServiceTests.swift` — covers state machine
- [ ] `BoosterSimAppTests/CommandPayloadTests.swift` — covers SC3/4/5 wire contract
- [ ] `BoosterSimAppTests/ConditionVerdictTests.swift` — covers SC4 airplane/guard-header verdicts (decision fn must be exposed from the service layer, not the URLProtocol)

## Security Domain

> `security_enforcement` not disabled → included. Non-sandboxed dev tool; threat model is the developer's own machine/LAN.

### Applicable ASVS Categories
| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | Dev tool on trusted machine; no auth (RocketSim ships none either; optional passcode is a v2 idea) |
| V3 Session Management | no | — |
| V4 Access Control | marginal | CommandServer accepts any connecting client on the LAN while Bonjour-visible. Mitigate: bind to loopback (`NWParameters.requiredLocalEndpoint` on 127.0.0.1) — Simulator reaches Mac loopback; or accept and document (PulseServer today binds all interfaces [VERIFIED: PulseServer.swift — `NWListener(using: params, on: NWEndpoint.Port(rawValue: 0)!)` with default params]) |
| V5 Input Validation | yes | Block-rule fields are plain strings matched with exact/suffix/prefix ops — never compiled to regex (ReDoS impossible by construction; don't hand-roll a regex engine) |
| V6 Cryptography | no | No secrets in payloads; command channel plaintext JSON on loopback (document; TLS if LAN exposure kept) |
| V14/V16 Config & Logging | yes | Never log full URLs/tokens: command payloads contain hosts/paths only; follow CurlExporter redaction ethos [in-repo: CurlExporter redacts sensitive headers]; AppLogger rules forbid sensitive data |

### Known Threat Patterns for this stack
| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| LAN peer connects to CommandServer and injects conditions | Tampering | Loopback bind (preferred) or document LAN-trust assumption; ignore malformed frames (length-prefix + version check) |
| Malicious/typo rule string causing pathological matching | DoS | No regex compilation; bounded string ops; cap rule count in UI |
| Sensitive URLs in logs | Information disclosure | Log domains only, never query strings; existing AppLogger conventions |

## Sources

### Primary (HIGH confidence — read this session)
- In-repo source: `BoosterSimApp/Services/{ConnectService,PulseServer,PulseClientConnection,PulsePacketDecoder,SimCtlService}.swift`, `BoosterSimApp/App/AppDelegate.swift`, `BoosterSimApp/Models/AppSettings.swift`, `BoosterSimApp/Views/SideWindow/tabs/NetworkTabView.swift`, `BoosterSimApp/Views/SideWindow/network/{TrafficFilterBar,ConnectSetupView}.swift`, `BoosterSimAppTests/CertificateServiceTests.swift`, `BoosterSimConnect/BoosterSimConnect.swift`, `CLAUDE.md`, `AGENTS.md`
- Upstream Pulse sources (github.com/kean/Pulse, branch main, MIT): `Sources/Pulse/RemoteLogger/{RemoteLogger.swift,RemoteLogger-Connection.swift,RemoteLogger-Protocol.swift}`, `Sources/Pulse/NetworkDebugger/{NetworkDebugger.swift,MockingURLProtocol.swift}`, `Sources/Pulse/URLSessionProxy/URLSessionProxyDelegate+AutomaticRegistration.swift`, `Sources/PulseProxy/URLSessionSwizzler.swift`
- RocketSim official docs (rocketsim.app/llms-full.txt, fetched 2026-08-29): "Slow Network & Airplane Mode on the iOS Simulator", CLI networking section, FAQ
- Machine probes this session: `simctl help` (Xcode 26.3), `xcodebuild -version`, `sw_vers`, `command -v dnctl pfctl networksetup`

### Secondary (MEDIUM confidence)
- Context7 `/websites/kean-docs_github_io_pulse` — RemoteLogger API surface, URLSessionProxyDelegate docs, MockingURLProtocol enableAutomaticRegistration
- developer.apple.com — WWDC25/234 (filter verdicts), forums thread 64240 (WKWebView out-of-process), forums thread 729943 (WebSocketTask + URLProtocol), URLProtocolClient reference, managed-capability provisioning docs
- avanderlee.com — Network Link Conditioner whole-Mac behavior

### Tertiary (LOW confidence)
- Web-search-only claims: dummynet operational status nuances on recent macOS (moot — rejected on scoping grounds, not availability); Mocker/OHHTTPStubs delay APIs (precedent only, not used as dependencies)

## Metadata

**Confidence breakdown:**
- Recommended architecture: HIGH — every load-bearing mechanism (reverse-channel feasibility, swizzle pattern, URLProtocol enforcement, telemetry non-interference, per-app isolation) verified against in-repo code or upstream primary sources this session
- Rejected alternatives: HIGH — simctl absence machine-verified; NE/`filter` limits Apple-cited; NLC whole-Mac behavior multi-source
- UX details: MEDIUM — grounded in existing atoms and RocketSim precedent, but panel layout is a design judgment
- Throttle fidelity: MEDIUM — HTTP-level pacing is an approximation of packet-level shaping (documented, A5)

**Research date:** 2026-08-29
**Valid until:** 2026-09-28 (stable domain; revisit if Pulse releases a breaking version or Apple ships simulator network controls in a new Xcode)
