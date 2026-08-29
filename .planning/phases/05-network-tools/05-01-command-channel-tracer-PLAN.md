---
phase: 05-network-tools
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - BoosterSimApp/Models/BoosterCommand.swift
  - BoosterSimApp/Models/BlockRule.swift
  - BoosterSimApp/Services/CommandServer.swift
  - BoosterSimApp/Services/NetworkConditionService.swift
  - BoosterSimApp/Views/SideWindow/network/NetworkConditionsSectionView.swift
  - BoosterSimApp/Views/SideWindow/tabs/NetworkTabView.swift
  - BoosterSimApp/App/AppDelegate.swift
  - BoosterSimApp/Windows/SideWindowController.swift
  - BoosterSimApp/Utilities/AppLogger.swift
  - BoosterSimConnect/BoosterCommandClient.swift
  - BoosterSimConnect/NetworkConditionController.swift
  - BoosterSimConnect/BoosterNetworkProtocol.swift
  - BoosterSimConnect/BoosterSimConnect.swift
  - BoosterSimAppTests/CommandPayloadTests.swift
  - BoosterSimAppTests/ConditionVerdictTests.swift
  - BoosterSimAppTests/NetworkConditionServiceTests.swift
  - BoosterSimApp.xcodeproj/project.pbxproj
autonomous: false
requirements:
  - REQ-roadmap-phase5-network-tools
  - REQ-nfr-03
user_setup:
  - service: ios-simulator-debug-app
    why: "Tracer smoke checkpoint needs a booted iOS Simulator running a DEBUG app that embeds BoosterSimConnect (loads /Applications/Booster.app/Contents/Resources/BoosterSimConnect.framework)"
    dashboard_config:
      - task: "Boot a Simulator and launch any DEBUG app that calls BoosterSimConnect activation (e.g. the usual Connect test app)"
        location: "Xcode → run the embedded-app scheme on a booted Simulator; BoosterSimApp must be running"
estimate:
  tokens: 45000
  raw_tokens: 45000
  tasks: 3
  confidence: low

must_haves:
  truths:
    - "With a connected Simulator app embedding BoosterSimConnect, toggling Airplane Mode ON in the Network tab makes that app's URLSession HTTP(S) requests fail with URLError code NSURLErrorNotConnectedToInternet (-1009) within one snapshot push, while the identical request made from the Mac still succeeds"
    - "Toggling Airplane Mode OFF pushes a new snapshot and subsequent requests in the app succeed again"
    - "The Pulse telemetry stream (_pulse._tcp.) and traffic viewer keep receiving events while Airplane Mode is ON — the tool's own channels are never severed"
    - "Every new command-client connection immediately receives the full condition snapshot (reconcile on connect), so a relaunching Simulator app converges to Mac-side state without user action"
    - "A BoosterCommand JSON frame with an unknown version integer is ignored by the client without partial application; a known-version frame encode/decode round-trips losslessly"
    - "Requests carrying the internal guard marker (X-Booster-Internal) are never intercepted — no recursion, and inner pass-through requests succeed even while Airplane Mode is ON"
    - "Airplane state persists across BoosterSimApp relaunch via AppStorage and is re-pushed on the next client connect"
    - "Concurrent-use guarantee (edge probe, answered): frames are idempotent full-state snapshots with a single writer (Mac-side NetworkConditionService); an interrupted or lost frame leaves the framework at its last complete snapshot and self-heals on the next push or reconnect-reconcile; partial TCP reads never half-apply (length-prefixed buffered reassembly, 10 MB cap, malformed frame drops the connection); multiple parallel embedding apps each receive the complete snapshot independently"
  artifacts:
    - BoosterSimApp/Models/BoosterCommand.swift
    - BoosterSimApp/Models/BlockRule.swift
    - BoosterSimApp/Services/CommandServer.swift
    - BoosterSimApp/Services/NetworkConditionService.swift
    - BoosterSimApp/Views/SideWindow/network/NetworkConditionsSectionView.swift
    - BoosterSimConnect/BoosterCommandClient.swift
    - BoosterSimConnect/NetworkConditionController.swift
    - BoosterSimConnect/BoosterNetworkProtocol.swift
    - BoosterSimAppTests/CommandPayloadTests.swift
    - BoosterSimAppTests/ConditionVerdictTests.swift
    - BoosterSimAppTests/NetworkConditionServiceTests.swift
  key_links:
    - "NetworkConditionsSectionView airplane Toggle → NetworkConditionService.setAirplane(_:) → CommandServer.broadcast(_:) → BoosterCommandClient frame decode → NetworkConditionController.update(_:) → BoosterNetworkProtocol.startLoading() verdict enforcement"
    - "BoosterSimConnect.activate() installs BoosterNetworkProtocol.enableAutomaticRegistration() and starts BoosterCommandClient.shared"
    - "AppDelegate lazy var networkConditionService → SideWindowController.embedSwiftUIContent parameter → .environmentObject(networkConditionService) → NetworkTabView"
  prohibitions:
    - requirement_id: REQ-roadmap-phase5-network-tools
      category: transparency
      status: unresolved
      flag: unverified-no-spec
      statement: "MUST NOT present airplane mode, throttling, or blocking as system-wide or Simulator-wide offline — all UI copy and docs must scope conditions to URLSession HTTP(S) traffic of apps embedding BoosterSimConnect (WebSocket, WKWebView, Network.framework traffic and sessions created before framework load are unaffected; NWPathMonitor still reports satisfied)"
    - requirement_id: REQ-roadmap-phase5-network-tools
      category: safety
      status: unresolved
      flag: unverified-no-spec
      statement: "MUST NOT degrade Mac connectivity nor sever BoosterSimApp's own channels while Airplane Mode is active — the _pulse._tcp. telemetry stream and _booster-cmd._tcp. command channel must stay connected exactly when the app under test is offline"
    - requirement_id: REQ-roadmap-phase5-network-tools
      category: privacy
      status: unresolved
      flag: unverified-no-spec
      statement: "MUST NOT log or transmit full URLs, query strings, or header values — command payloads carry hosts/paths only and AppLogger output for this feature must not contain query strings or tokens"
    - requirement_id: REQ-nfr-03
      category: values
      status: unresolved
      flag: unverified-no-spec
      statement: "MUST NOT add third-party dependencies or change SPM pins this phase — Pulse/PulseProxy remain the sole package exception and Package.resolved must be byte-identical at phase close"
  flagged_assumptions:
    - requirement_id: REQ-fr-16
      probe: unclassified
      status: unresolved
      statement: "Certificate flows are delivered and untouched this phase; the only interaction is the shared Network tab layout. Assumption: CertificateSectionView rendering and certificate code paths stay regression-free — verified only by inspection plus the plan-04 phase-gate smoke (no automated cert-install tests exist)"
    - requirement_id: REQ-nfr-03
      probe: unclassified
      status: unresolved
      statement: "No SPM changes are needed (Pulse pinned at 5.2.2, no new packages). Check at this plan and again at plan 04: git diff --exit-code BoosterSimApp.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved"
    - requirement_id: REQ-roadmap-phase5-network-tools
      probe: concurrency
      status: resolved-by-design-pending-manual-confirm
      statement: "Interrupted/parallel guarantee is answered by truth #8 above (idempotent full-state snapshots, single writer, buffered framing, reconnect reconcile, process-local client state); automated coverage via CommandPayloadTests framing/round-trip, manual confirmation of reconnect-reconcile rides the Task 3 smoke checkpoint"
---

<objective>
Tracer slice: prove the Phase 5 manipulation architecture end-to-end with ONE story — Airplane Mode.

Wire a single vertical path through every layer this phase touches: Network tab toggle (Mac) → NetworkConditionService (@MainActor state machine) → CommandServer (new NWListener + Bonjour "_booster-cmd._tcp.") → BoosterCommandClient (NWBrowser + length-prefixed JSON frames, iOS framework) → NetworkConditionController (NSLock snapshot store) → BoosterNetworkProtocol (URLProtocol verdict enforcement on URLSession traffic in the app under test).

This tracer ships the ENGINE, not just airplane: the complete BoosterCommand payload schema (airplane + ThrottleSpec + BlockRule, version-gated), the generic fail-verdict enforcement, the service's full condition-state hub (airplane flag, rules array CRUD, persistence keys), and both new section-view mount points. Plans 02 (throttle) and 03 (block rules UI) expand on this proven slice without architectural change.

Purpose: Per RESEARCH.md there is no OS-level per-app network boundary without entitlements; the only entitlement-free interception point is the app's own process, where BoosterSimConnect already lives. This slice proves the second Bonjour channel (assumption A3), the swizzle+URLProtocol chain, telemetry non-interference (Pitfall 5), and anti-recursion (Pitfall 2) before any expansion work builds on them.
Output: 11 new source files, 4 modified files, 3 Swift Testing files, one green end-to-end smoke on a live Simulator.
</objective>

<execution_context>
@~/.claude/gsd-core/workflows/execute-plan.md
@~/.claude/gsd-core/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/ROADMAP.md
@.planning/STATE.md
@.planning/phases/05-network-tools/05-RESEARCH.md
@.planning/phases/05-network-tools/05-PATTERNS.md

Source-of-truth analogs (read before writing each file — PATTERNS.md carries near-verbatim excerpts):
@BoosterSimApp/Services/PulseServer.swift
@BoosterSimApp/Services/PulseClientConnection.swift
@BoosterSimApp/Services/CertificateService.swift
@BoosterSimApp/Services/CertificateModels.swift
@BoosterSimApp/Views/SideWindow/CertificateSectionView.swift
@BoosterSimApp/Views/SideWindow/tabs/NetworkTabView.swift
@BoosterSimApp/Models/AppSettings.swift
@BoosterSimApp/Utilities/DesignTokens.swift
@BoosterSimConnect/BoosterSimConnect.swift
@BoosterSimAppTests/CertificateServiceTests.swift
</context>

<tasks>

<task type="tracer" tdd="true">
  <name>Task 1: Airplane Mode end-to-end — payload, command channel, enforcement, Network tab toggle</name>
  <files>
    BoosterSimApp/Models/BoosterCommand.swift,
    BoosterSimApp/Models/BlockRule.swift,
    BoosterSimApp/Services/CommandServer.swift,
    BoosterSimApp/Services/NetworkConditionService.swift,
    BoosterSimApp/Views/SideWindow/network/NetworkConditionsSectionView.swift,
    BoosterSimApp/Views/SideWindow/tabs/NetworkTabView.swift,
    BoosterSimApp/App/AppDelegate.swift,
    BoosterSimApp/Windows/SideWindowController.swift,
    BoosterSimApp/Utilities/AppLogger.swift,
    BoosterSimConnect/BoosterCommandClient.swift,
    BoosterSimConnect/NetworkConditionController.swift,
    BoosterSimConnect/BoosterNetworkProtocol.swift,
    BoosterSimConnect/BoosterSimConnect.swift,
    BoosterSimAppTests/CommandPayloadTests.swift,
    BoosterSimAppTests/ConditionVerdictTests.swift,
    BoosterSimApp.xcodeproj/project.pbxproj
  </files>
  <read_first>
    - .planning/phases/05-network-tools/05-RESEARCH.md (Patterns 1-5, Pitfalls 1-6/10/11, Code Examples: command snapshot payload + enforcement decision)
    - .planning/phases/05-network-tools/05-PATTERNS.md (every file has an assigned analog with excerpts)
    - BoosterSimApp/Services/PulseServer.swift (exact NWListener + Bonjour shape to mirror)
    - BoosterSimApp/Services/PulseClientConnection.swift (receiveBuffer + maxBufferSize + processBuffer framing to mirror on the client)
    - BoosterSimApp/Services/CertificateService.swift and BoosterSimApp/Services/CertificateModels.swift (begin/finish/fail/transition quartet + enum shapes)
    - BoosterSimApp/Views/SideWindow/tabs/NetworkTabView.swift (mount point between Divider() and CertificateSectionView)
    - BoosterSimApp/Views/SideWindow/CertificateSectionView.swift (CollapsibleSection usage + status row pattern)
    - BoosterSimApp/App/AppDelegate.swift (lazy var service ownership, lines 22-23)
    - BoosterSimApp/Windows/SideWindowController.swift (embedSwiftUIContent signature + .environmentObject chain, lines 194-232)
    - BoosterSimConnect/BoosterSimConnect.swift (activate() — the hook installation site)
    - BoosterSimApp/Models/AppSettings.swift (@AppStorage key naming precedent)
    - AGENTS.md GitNexus section — run gitnexus_impact (upstream) on NetworkTabView, AppDelegate, SideWindowController.embedSwiftUIContent, and BoosterSimConnect.activate before editing them; report blast radius before proceeding
  </read_first>
  <behavior>
    - CommandPayloadTests: BoosterCommand with airplane=true, throttle=ThrottleSpec(latencyMs:400, downloadKbps:750, uploadKbps:nil), blockRules=[BlockRule(id: UUID(), domain:"*.example.com", pathPrefix:"/api", isEnabled:true)] encodes to JSON and decodes back equal (all fields)
    - CommandPayloadTests: a decoded frame whose version field is greater than the current constant (1) is rejected/ignored by the client decode path without mutating prior state
    - CommandPayloadTests: 4-byte big-endian length prefix round-trips for empty body, 1-byte body, and a body split across two simulated partial reads (buffered reassembly)
    - ConditionVerdictTests: evaluate with airplane=true returns .fail(.notConnectedToInternet) regardless of rules/throttle
    - ConditionVerdictTests: evaluate with a request carrying the internal guard property returns .passThrough even when airplane=true
    - ConditionVerdictTests: evaluate with airplane=false, an enabled matching rule, returns .fail(.cannotConnectToHost); disabled rule returns .passThrough
    - ConditionVerdictTests: evaluate with airplane=false, no matching rules, throttle=nil returns .passThrough
  </behavior>
  <action>
    NOTE: this task spans every layer BY DESIGN (tracer); keep each file minimal for the slice and under 200 LOC per docs/code-standards.md. Write CommandPayloadTests.swift and ConditionVerdictTests.swift FIRST (Swift Testing, red), then implement green.

    BoosterSimApp/Models/BoosterCommand.swift (new): Codable structs BoosterCommand (version: Int constant 1, airplane: Bool, throttle: ThrottleSpec?, blockRules: [BlockRule]) and ThrottleSpec (latencyMs: Int, downloadKbps: Int, uploadKbps: Int? — upload approximated by latency in v1 per research A5/Pitfall 8, keep the field for schema stability). Also the pure decision layer: enum ConditionVerdict with cases passThrough, fail(URLError.Code); free function evaluate(request:snapshot:) -> ConditionVerdict implementing EXACTLY this order (research Code Examples): guard-marker check first, then airplane → fail(URLError.Code.notConnectedToInternet), then first enabled matching rule → fail(URLError.Code.cannotConnectToHost) (Pitfall 10: verify both raw codes against URLError.Code docs during implementation — research A1 flags this as unverified), then passThrough. No throttle branch yet (ConditionVerdict gains .throttle in plan 02 — additive). Keep evaluate pure/synchronous (Pattern 3).

    BoosterSimApp/Models/BlockRule.swift (new): struct BlockRule: Codable, Identifiable with id: UUID, domain: String, pathPrefix: String?, isEnabled: Bool = true; plus pure func matches(_ request: URLRequest) -> Bool using ONLY string operations on URL.host and URL.path — exact-host equality, "*."-prefixed domain matches host on a dot boundary via hasSuffix, optional pathPrefix via hasPrefix, case-insensitive host comparison, nil-host requests never match. Absolutely no regex compilation (research Don't-Hand-Roll + threat T-05-02).

    BoosterSimApp/Services/CommandServer.swift (new): @MainActor final class CommandServer mirroring PulseServer.swift exactly (PATTERNS Pattern assignment 1): NWParameters.tcp with includePeerToPeer = true, NWListener on port 0, listener.service = NWListener.Service(name: "BoosterSimApp", type: "_booster-cmd._tcp."). SECURITY (threat T-05-01 mitigation): prefer binding to loopback by setting params.requiredLocalEndpoint = NWEndpoint.hostPort(host: "127.0.0.1", port: 0) — Simulator apps reach the Mac host loopback (research V4 row). If the Task 3 smoke shows the client cannot discover/connect under the loopback bind, fall back to default-interface bind and record the LAN-trust assumption in the summary + threat disposition change. Broadcast API: func broadcast(_ command: BoosterCommand) — encode with JSONEncoder, frame as 4-byte big-endian UInt32 length prefix + JSON body, send to every connected client. On new connection: immediately send the latest snapshot (reconcile-on-connect, Pattern 1). Per-connection receive side ignores client frames except to detect malformed input: any frame violating the length-prefix contract or exceeding the 10 MB cap drops that connection (never the app). Use AppLogger.network for state changes (hosts/paths only — never full URLs, prohibition PRO-03).

    BoosterSimApp/Services/NetworkConditionService.swift (new): @MainActor final class NetworkConditionService: ObservableObject mirroring CertificateService's begin/finish/fail/transition quartet with assertionFailure on illegal transitions (PATTERNS Pattern 5). Published state: NetworkConditionState enum (idle/applying/applied/error(String)) with canTransition + isWorking exactly in the CertificateOperation shape. Owns a private CommandServer, started in init, and exposes: var airplane: Bool (backed by @AppStorage key "networkConditionAirplane" — NOTE: @AppStorage inside an ObservableObject is not the right tool; follow the AppSettings.swift pattern instead: read/write UserDefaults via a RawRepresentable-style helper and republish through @Published, keeping views free of raw UserDefaults per code standards), rules: [BlockRule] with addRule(_:)/removeRule(id:)/setRuleEnabled(id:enabled:) mutating UserDefaults key "networkBlockRules" as JSON, and a func setAirplane(_:) that builds the full BoosterCommand snapshot (profile-less for now: throttle nil, current airplane, current rules), marks applying → broadcast → applied. On CommandServer client-connect callback, re-broadcast the current snapshot. Reconcile on init from persisted defaults (research Open Question 2 decision: persist + re-apply, matching REQ-fr-16 certificate precedent).

    BoosterSimApp/Utilities/AppLogger.swift (modify): add one line matching existing style — static let network = Logger(subsystem: subsystem, category: "Network") (alphabetically after certificates; observe the aligned-column formatting of neighbors).

    BoosterSimConnect/NetworkConditionController.swift (new): framework-side snapshot store, NOT @MainActor (Pitfall 6): final class NetworkConditionController with private let lock = NSLock (Pulse NetworkDebugger precedent), static let shared, a private optional BoosterCommand snapshot, func update(_ command: BoosterCommand) that validates version == known constant else ignores, and func evaluate(request: URLRequest) -> ConditionVerdict — a schema-synced mirror of the Mac-side pure evaluate (research Validation note: keep decision logic unit-tested on the Mac side; the framework mirror stays byte-for-byte in semantics). The framework needs its own Codable definitions of BoosterCommand/ThrottleSpec/BlockRule + ConditionVerdict in this file (framework cannot import the Mac app target; schemas must stay in sync — CommandPayloadTests is the contract guard).

    BoosterSimConnect/BoosterNetworkProtocol.swift (new): public final class BoosterNetworkProtocol: URLProtocol copying Pulse's MockingURLProtocol MIT pattern (research Pattern 2, verified upstream): static func enableAutomaticRegistration() exchanging URLSession.init(configuration:delegate:delegateQueue:) with a renamed booster_init2 class method that prepends BoosterNetworkProtocol.self to configuration.protocolClasses and calls the exchanged selector (the chain composes with Pulse's existing exchange — our body calls the renamed selector, so both prepends apply; traffic must still be captured after this lands, verified in Task 3 smoke). Include a safety guard analog of isConfiguringSessionSafe that skips known-problematic delegate configurations. canInit(with:) returns false when the request carries the internal guard marker (URLProtocol.property(forKey: "X-Booster-Internal", in:)) and otherwise consults NetworkConditionController.shared.evaluate — returning true ONLY for non-passThrough verdicts (zero overhead when conditions are off). canonicalRequest(for:) sets the guard property (Pulse pattern). startLoading() re-evaluates (snapshot may have changed since canInit): .fail(code) → client?.urlProtocol(self, didFailWithError: URLError(code)); .passThrough (race case) → forward via an inner ephemeral URLSession whose request carries literal header "X-Booster-Internal: 1" and whose configuration has protocolClasses = [] (Pitfall 2 double defense), relaying response/data/finish/error to client. stopLoading() cancels the inner task. All callbacks run on session queues — no main-thread assumptions, no @MainActor (Pitfall 6).

    BoosterSimConnect/BoosterSimConnect.swift (modify): in activate(), after the existing URLSessionProxyDelegate.enableAutomaticRegistration() call, add BoosterNetworkProtocol.enableAutomaticRegistration() and BoosterCommandClient.shared.start(), inside the existing #if canImport(PulseProxy)/DEBUG gating that already guards this path. Do NOT touch the deprecated Pulse migration (Pitfall 13 — separate follow-up).

    BoosterSimApp/Views/SideWindow/network/NetworkConditionsSectionView.swift (new): struct NetworkConditionsSectionView: View wrapped in CollapsibleSection(title: "Network Conditions", icon: "network"), binding @EnvironmentObject var networkConditionService. Content: an airplane Toggle (Label "Airplane Mode", systemImage "airplane"), a status caption row driven by NetworkConditionState in the CertificateSectionView statusRow pattern (ProgressView while applying, error row with exclamationmark.triangle.fill, idle caption otherwise), and a scope caption in .font(.caption).foregroundStyle(.secondary) reading "Affects URLSession HTTP(S) traffic in apps embedding BoosterSimConnect" (prohibition PRO-01 — no overclaiming). All layout via Spacing.* / SideWindowMetrics.* tokens only; accessibilityLabel on every icon-only control; default collapsed.

    BoosterSimApp/Views/SideWindow/tabs/NetworkTabView.swift (modify): insert NetworkConditionsSectionView() between the existing Divider() and CertificateSectionView (research-verified mount point). Add @EnvironmentObject var networkConditionService: NetworkConditionService.

    BoosterSimApp/App/AppDelegate.swift (modify): add lazy var networkConditionService = NetworkConditionService() next to the existing lazy service vars (line ~22-23 style).

    BoosterSimApp/Windows/SideWindowController.swift (modify): add networkConditionService: NetworkConditionService parameter to embedSwiftUIContent, thread it from its caller, and add .environmentObject(networkConditionService) to the chain (after .environmentObject(certificateService), line ~224).

    BoosterSimApp.xcodeproj/project.pbxproj (modify): add all 5 new BoosterSimApp files to the BoosterSimApp target and the 3 new BoosterSimConnect files to the BoosterSimConnect target (framework target must build for iOS Simulator; the existing "Build iOS Framework & Copy" script phase picks them up — verify it still runs).

    Do NOT add any SPM dependency or touch Package.resolved (prohibition PRO-04; REQ-nfr-03 — Pulse stays sole exception at 5.2.2).
  </action>
  <verify>
    <automated>xcodebuild -project BoosterSimApp.xcodeproj -scheme BoosterSimApp -destination 'platform=macOS' test -only-testing:BoosterSimAppTests/CommandPayloadTests -only-testing:BoosterSimAppTests/ConditionVerdictTests && xcodebuild -project BoosterSimApp.xcodeproj -scheme BoosterSimApp -destination 'platform=macOS' build && git diff --exit-code BoosterSimApp.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved</automated>
  </verify>
  <acceptance_criteria>
    - BoosterSimApp/Models/BoosterCommand.swift declares struct BoosterCommand: Codable with stored properties version, airplane, throttle, blockRules and a constant equal to Int 1
    - BoosterSimApp/Models/BlockRule.swift contains a matches(_ request: URLRequest) -> Bool implementation referencing only hasSuffix, hasPrefix, lowercased, and equality comparisons on URL host/path values — no NSRegularExpression and no Regex literal anywhere in the file
    - BoosterSimApp/Services/CommandServer.swift declares @MainActor final class CommandServer and references NWListener.Service with type string "_booster-cmd._tcp." and a broadcast method taking BoosterCommand
    - BoosterSimApp/Services/NetworkConditionService.swift declares @MainActor final class NetworkConditionService: ObservableObject with a NetworkConditionState enum exposing canTransition(to:) and isWorking
    - BoosterSimConnect/NetworkConditionController.swift declares final class NetworkConditionController holding NSLock and exposes update(_:) and evaluate(request:) — the file contains no @MainActor attribute
    - BoosterSimConnect/BoosterNetworkProtocol.swift declares a URLProtocol subclass whose canInit(with:) returns false for requests carrying the "X-Booster-Internal" marker, and whose enableAutomaticRegistration uses method_exchangeImplementations on the URLSession init(configuration:delegate:delegateQueue:) selector
    - BoosterSimConnect/BoosterSimConnect.swift activate() references BoosterNetworkProtocol.enableAutomaticRegistration and BoosterCommandClient.shared.start
    - NetworkTabView.swift body references NetworkConditionsSectionView between its Divider and CertificateSectionView
    - SideWindowController.swift contains .environmentObject(networkConditionService) and AppDelegate.swift contains lazy var networkConditionService
    - NetworkConditionsSectionView.swift references the CollapsibleSection atom and Spacing/SideWindowMetrics tokens, and its caption string names URLSession traffic explicitly (scope disclosure present)
    - xcodebuild test command exits 0 with CommandPayloadTests and ConditionVerdictTests green
    - git diff on Package.resolved is empty after the task
  </acceptance_criteria>
  <reversibility rating="costly">The URLSession init swizzle ships inside the DEBUG framework loaded by the target app; removing it later requires redeploying BoosterSimConnect to every embedded test app — flag only, no checkpoint needed (DEBUG-only, no published external contract).</reversibility>
  <done>One green vertical path: Network tab airplane toggle pushes a version-gated full-state snapshot over a second Bonjour channel into the app under test, where BoosterNetworkProtocol fails URLSession requests; payload/verdict unit tests green; both targets build; smoke on a live Simulator confirmed by Task 3.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: State-machine, persistence, and framing-robustness hardening</name>
  <files>
    BoosterSimApp/Services/NetworkConditionService.swift,
    BoosterSimApp/Services/CommandServer.swift,
    BoosterSimConnect/BoosterCommandClient.swift,
    BoosterSimAppTests/NetworkConditionServiceTests.swift
  </files>
  <read_first>
    - BoosterSimAppTests/CertificateServiceTests.swift (transition-test style to replicate)
    - BoosterSimApp/Services/CertificateService.swift (begin/finish/fail/transition semantics)
    - The Task 1 versions of NetworkConditionService.swift, CommandServer.swift, BoosterCommandClient.swift
  </read_first>
  <behavior>
    - NetworkConditionServiceTests: NetworkConditionState allows idle→applying, applying→applied, applying→error, error→applying; rejects applied→applying while another operation is in flight (isWorking guard) — mirror CertificateServiceTests.certificateOperationAllowsExpectedTransitions
    - NetworkConditionServiceTests: airplane persistence — after setAirplane(true) and re-initializing the service with the same UserDefaults suite, airplane reads true and the built snapshot carries airplane=true (persist + re-apply, research Open Question 2 decision)
    - NetworkConditionServiceTests: rule mutations update the persisted JSON under key "networkBlockRules" and the next built snapshot contains them
    - NetworkConditionServiceTests: snapshot building is total — airplane + rules together produce one BoosterCommand with both applied (single-writer guarantee, no torn snapshots)
    - CommandPayloadTests (extend): two snapshots concatenated in one buffer decode as two frames; a frame declaring a length beyond the 10 MB cap is rejected by the framing decoder (extract the framing decode into a testable Mac-side type shared by CommandServer tests — the pure framing logic lives on the Mac side where it is unit-testable)
  </behavior>
  <action>
    Write NetworkConditionServiceTests.swift first (red), then harden to green. Extract the length-prefix framing (encode frame from Data, decode frames from a mutable buffer with cap enforcement) into a small testable type on the Mac side (e.g. CommandFrame in BoosterCommand.swift or CommandServer.swift) and reuse it in CommandServer rather than duplicating byte logic — the framework client keeps its own mirrored copy (schema-sync rule). Verify NetworkConditionService applies the persist+re-apply semantics from init (reconcile pushes on first client connect), that illegal transitions hit assertionFailure in Debug (CertificateService.transition precedent), and that BoosterCommandClient reconnection restarts browsing after a dropped connection. Log through AppLogger.network with hosts/paths only (PRO-03).
  </action>
  <verify>
    <automated>xcodebuild -project BoosterSimApp.xcodeproj -scheme BoosterSimApp -destination 'platform=macOS' test -only-testing:BoosterSimAppTests/NetworkConditionServiceTests -only-testing:BoosterSimAppTests/CommandPayloadTests</automated>
  </verify>
  <acceptance_criteria>
    - BoosterSimAppTests/NetworkConditionServiceTests.swift exists, imports Testing, uses @Test funcs with #expect, and covers allowed transitions, rejected transitions, airplane persistence re-init, rules persistence, and combined snapshot building
    - The framing encoder/decoder is a named type referenced by CommandServer.swift (no duplicated byte manipulation inline in the broadcast path)
    - CommandPayloadTests includes a two-frames-one-buffer case and an over-cap rejection case
    - The xcodebuild test command exits 0
  </acceptance_criteria>
  <reversibility rating="reversible">Persistence key names ("networkConditionAirplane", "networkBlockRules") become user-visible defaults keys — renaming later strands stored state, so choose final names now; flagged costly only in that sense.</reversibility>
  <done>State machine, persistence, and framing behaviors are unit-tested and green; reconnect-reconcile logic implemented and manually confirmed in Task 3.</done>
</task>

<task type="checkpoint:human-verify" gate="blocking-human">
  <name>Task 3: Smoke the tracer on a live Simulator — airplane fails app requests, viewer stays live, Mac unaffected</name>
  <files>none</files>
  <read_first>
    - .planning/phases/05-network-tools/05-RESEARCH.md Validation Architecture (manual-only e2e row) and Pitfall 3 (reachability caveat) and Pitfall 5 (telemetry non-interference)
  </read_first>
  <action>
    Blocking human checkpoint — the tracer's end-to-end proof requires a live Simulator (research: manual-only, consistent with NET-04 deferral). Prerequisites (user_setup): BoosterSimApp running; a booted iOS Simulator with a DEBUG app embedding BoosterSimConnect that makes URLSession requests on demand (e.g. its usual Connect test app). Steps for the human: (1) confirm the app's traffic appears in the traffic viewer (Connect pipeline healthy after the second swizzle installed — chained-exchange check); (2) toggle Airplane Mode ON in the Network tab; (3) trigger a request in the app → it must fail with NSURLErrorNotConnectedToInternet and appear as an error row in the viewer (research A6 confirmation); (4) confirm the traffic viewer/connection banner stays connected while airplane is ON (Pitfall 5, prohibition PRO-02); (5) browse any website from the Mac — must load normally (criterion 4, no Mac impact); (6) toggle OFF → next request in the app succeeds; (7) relaunch the Simulator app → snapshot reconciles (airplane re-applies if still ON) within a second of reconnect. The executor records observed results per step in the plan summary; any failure here HALTS expansion plans 02/03 (architecture assumption A3 invalidated — escalate to replan, do not work around).
  </action>
  <verify>
    <human-check>All seven smoke steps observed and recorded pass/fail in the summary; specifically the app request fails under airplane while the Mac browser loads a page and the viewer keeps streaming.</human-check>
  </verify>
  <acceptance_criteria>
    - Summary contains a per-step pass/fail record for the 7 smoke steps
    - Under airplane ON: app URLSession request fails AND viewer stays connected AND Mac browsing works (the three-way proof of criterion 4 + PRO-02)
    - Recovery and reconnect-reconcile steps confirmed
  </acceptance_criteria>
  <what-built>The Phase 5 manipulation engine wired end-to-end: Network tab Airplane Mode toggle → NetworkConditionService full-state snapshot → CommandServer Bonjour broadcast ("_booster-cmd._tcp.") → BoosterCommandClient → NetworkConditionController → BoosterNetworkProtocol failing the app's URLSession requests with NSURLErrorNotConnectedToInternet. CommandPayloadTests, ConditionVerdictTests, and NetworkConditionServiceTests green; BoosterSimApp macOS build green (framework target + copy phase included).</what-built>
  <how-to-verify>
    With BoosterSimApp running and a booted Simulator DEBUG app embedding BoosterSimConnect that can trigger a URLSession request on demand:
    1. Confirm the app's traffic appears in the traffic viewer (Connect pipeline healthy after the second swizzle)
    2. Toggle Airplane Mode ON in the Network tab
    3. Trigger a request in the app → it must fail with NSURLErrorNotConnectedToInternet and appear as an error row in the viewer
    4. Confirm the traffic viewer / connection banner stays connected while airplane is ON
    5. Open any website in a Mac browser → it must load normally (no Mac impact)
    6. Toggle Airplane Mode OFF → the next request in the app succeeds
    7. With airplane ON, relaunch the Simulator app → the condition re-applies within ~1 second of reconnect (reconcile)
  </how-to-verify>
  <resume-signal>Reply "approved" to unblock wave 2 (plans 02/03), or describe the failing step — a failure here invalidates architecture assumption A3 and halts expansion for replan.</resume-signal>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| Mac app → Simulator app process | BoosterCommand JSON frames cross from BoosterSimApp (trusted, developer-owned) into the DEBUG app under test over the _booster-cmd._tcp. channel |
| LAN → CommandServer | Any process on the machine/LAN that can see the Bonjour service could attempt to connect while the listener is bound |
| App-under-test traffic → BoosterNetworkProtocol | Every URLSession request in the embedded app passes the verdict function before reaching the network |

## STRIDE Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation Plan |
|-----------|----------|-----------|----------|-------------|-----------------|
| T-05-01 | Tampering | CommandServer (LAN exposure) | medium | mitigate | Bind listener to loopback via NWParameters.requiredLocalEndpoint 127.0.0.1 (Simulator reaches host loopback); drop connections sending malformed/oversized frames (length-prefix + version gate + 10 MB cap); documented fallback to LAN-trust note if loopback bind breaks Bonjour discovery in smoke |
| T-05-02 | DoS | BlockRule matcher on user strings | low | mitigate | No regex compilation ever — exact/suffix/prefix string ops only; rule count cap enforced in plan 03 UI (max 50); matcher is O(rules) bounded string comparisons |
| T-05-03 | Information Disclosure | Command payloads + logs | medium | mitigate | Payloads carry hosts/paths only (no query strings, no headers); AppLogger.network logs follow AppLogger sensitive-data rules; traffic viewer redaction (CurlExporter) untouched |
| T-05-04 | Tampering | URLSession init swizzle inside target app | medium | mitigate | Copy Pulse's isConfiguringSessionSafe-style guard skipping unsafe delegate configs; DEBUG-only framework; chained exchange verified in Task 3 smoke (traffic capture still works) |
| T-05-05 | DoS | Airplane mode severing tool telemetry | low | mitigate | By construction: Pulse RemoteLogger and BoosterCommandClient use NWConnection (Network.framework), which bypasses URLProtocol entirely; regression-checked in Task 3 step 4 |
| T-05-SC | Tampering | Package installs | high | mitigate | No package installs this phase; enforcement = git diff --exit-code on Package.resolved in Task 1 verify and again at plan 04 (any SPM change is a stop-and-replan) |
</threat_model>

<verification>
- Task 1/2 automated: Swift Testing suites (CommandPayloadTests, ConditionVerdictTests, NetworkConditionServiceTests) green via the plan's xcodebuild commands; macOS app build green (which also runs the "Build iOS Framework & Copy" phase proving the framework target still compiles and copies).
- Task 3: blocking human smoke on a live Simulator (7 steps) — the only honest end-to-end check of criterion 4 (needs Simulator + embedded app; research marks e2e Connect verification as manual).
- Package.resolved byte-identical (REQ-nfr-03).
</verification>

<success_criteria>
- The 8 must_haves truths hold; specifically the three-way airplane proof (app fails / viewer live / Mac unaffected) is observed on a live Simulator.
- All three test files green; both Xcode targets build; no SPM changes.
- Architecture proven well enough that plans 02 (throttle) and 03 (block rules UI) are additive, not architectural.
</success_criteria>

## Artifacts this phase produces

Created by THIS plan (new symbols):
- BoosterCommand, ThrottleSpec, ConditionVerdict, evaluate(request:snapshot:), CommandFrame (framing codec) — BoosterSimApp/Models/BoosterCommand.swift
- BlockRule (+ matches(_:) pure matcher) — BoosterSimApp/Models/BlockRule.swift
- CommandServer — BoosterSimApp/Services/CommandServer.swift
- NetworkConditionService, NetworkConditionState — BoosterSimApp/Services/NetworkConditionService.swift
- NetworkConditionsSectionView — BoosterSimApp/Views/SideWindow/network/NetworkConditionsSectionView.swift
- BoosterCommandClient — BoosterSimConnect/BoosterCommandClient.swift
- NetworkConditionController (+ framework-side mirrors of BoosterCommand/ThrottleSpec/BlockRule/ConditionVerdict/evaluate) — BoosterSimConnect/NetworkConditionController.swift
- BoosterNetworkProtocol (+ enableAutomaticRegistration, booster_init2 exchange) — BoosterSimConnect/BoosterNetworkProtocol.swift
- AppLogger.network category — BoosterSimApp/Utilities/AppLogger.swift
- New UserDefaults keys: "networkConditionAirplane", "networkBlockRules"
- New Bonjour service: "_booster-cmd._tcp." (name "BoosterSimApp")
- Tests: CommandPayloadTests, ConditionVerdictTests, NetworkConditionServiceTests

Modified: NetworkTabView (section mount), AppDelegate (lazy service), SideWindowController (environment injection), BoosterSimConnect.activate() (hook install), project.pbxproj (target membership), AppLogger.

Later plans add: NetworkConditionProfile + presets + pacing (02), BlockRulesView + matcher hardening (03), docs updates (04).

<output>
Create `.planning/phases/05-network-tools/05-01-SUMMARY.md` when done
</output>
