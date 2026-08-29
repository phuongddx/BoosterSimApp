---
phase: 05-network-tools
plan: 02
type: execute
wave: 2
depends_on: ["05-01-command-channel-tracer"]
files_modified:
  - BoosterSimApp/Models/NetworkConditionProfile.swift
  - BoosterSimApp/Models/BoosterCommand.swift
  - BoosterSimApp/Services/NetworkConditionService.swift
  - BoosterSimApp/Views/SideWindow/network/NetworkConditionsSectionView.swift
  - BoosterSimConnect/NetworkConditionController.swift
  - BoosterSimConnect/BoosterNetworkProtocol.swift
  - BoosterSimConnect/ThrottlePacing.swift
  - BoosterSimAppTests/NetworkConditionProfileTests.swift
  - BoosterSimAppTests/ConditionVerdictTests.swift
  - BoosterSimApp.xcodeproj/project.pbxproj
autonomous: true
requirements:
  - REQ-roadmap-phase5-network-tools
estimate:
  tokens: 30000
  raw_tokens: 30000
  tasks: 3
  confidence: low

must_haves:
  truths:
    - "Selecting a throttle profile (e.g. 3G) in the Network tab applies latency + download-bandwidth pacing to the app's URLSession responses: a body of N bytes at downloadKbps completes in approximately latencyMs + N*8/downloadKbps seconds, within one chunk interval of tolerance"
    - "The pacing schedule (latency delay + per-chunk delivery intervals) is a pure deterministic function, unit-tested at chunk granularity — chunkInterval = chunkBytes * 8 / kbps seconds"
    - "Throttle profile selection persists across BoosterSimApp relaunch (UserDefaults key networkConditionProfile) and is re-applied on the next client connect via snapshot reconcile"
    - "Throttled requests remain visible in the traffic viewer as slow rows through the existing Pulse code-10/slow-task events — no new reporting path"
    - "Inner pass-through requests carrying the X-Booster-Internal guard are exempt from throttling — no recursion, no double pacing (Pitfall 2)"
    - "Throttle enforcement never touches Mac traffic or the tool's own NWConnection channels (Pitfall 5)"
    - "Turning throttle off (profile off) removes interception: canInit returns false for ordinary requests again — zero overhead path restored"
  artifacts:
    - BoosterSimApp/Models/NetworkConditionProfile.swift
    - BoosterSimConnect/ThrottlePacing.swift
    - BoosterSimAppTests/NetworkConditionProfileTests.swift
  key_links:
    - "NetworkConditionsSectionView profile pills → NetworkConditionService.selectProfile(_) → snapshot broadcast (throttle: ThrottleSpec) → NetworkConditionController → BoosterNetworkProtocol paced startLoading"
    - "ThrottleSpec (Mac model) ⇄ ThrottlePacing (framework mirror) — schema-synced pair guarded by NetworkConditionProfileTests round-trip"
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
      statement: "No SPM changes are needed (Pulse pinned at 5.2.2, no new packages). Check at plan close: git diff --exit-code BoosterSimApp.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved"
    - requirement_id: REQ-roadmap-phase5-network-tools
      probe: concurrency
      status: resolved-by-design-pending-manual-confirm
      statement: "Interrupted/parallel guarantee (from plan 01): idempotent full-state snapshots, single writer, buffered framing, reconnect reconcile; throttle adds no new concurrency surface — pacing runs on a serial queue per request and stopLoading cancels pending work. Profile switch mid-download applies to the NEXT request (snapshot semantics), never retroactively mutates an in-flight paced response"
---

<objective>
Expansion slice 1 of the proven tracer engine: network speed control (ROADMAP criterion 3).

Add throttle profiles (off / edge / 3g / lte / wifi) selectable in ≤2 clicks from the Network tab, enforced as URL-level pacing inside the app under test: latency delay before first response callback, then body delivery in bounded chunks at chunkInterval = chunkBytes * 8 / kbps on a serial queue, via the plan-01 inner pass-through session. Pure pacing math lives Mac-side (unit-tested) with a schema-synced framework mirror.

Purpose: There is no packet-level per-app shaping without entitlements or whole-Mac tools (research rejected dummynet/NLC/NetworkExtension with evidence); HTTP-level pacing through BoosterNetworkProtocol is the entitlement-free approximation — its fidelity limits are documented assumptions (A5: upload approximated by latency; Pitfall 7: outer timeouts under high latency are intended realism).
Output: NetworkConditionProfile model + presets, .throttle verdict + paced enforcement, profile picker UI, pacing unit tests.
</objective>

<execution_context>
@~/.claude/gsd-core/workflows/execute-plan.md
@~/.claude/gsd-core/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/ROADMAP.md
@.planning/phases/05-network-tools/05-RESEARCH.md
@.planning/phases/05-network-tools/05-PATTERNS.md
@.planning/phases/05-network-tools/05-01-SUMMARY.md

Analog sources:
@BoosterSimApp/Views/SideWindow/CertificateSectionView.swift
@BoosterSimApp/Utilities/DesignTokens.swift
@BoosterSimAppTests/CertificateServiceTests.swift
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: NetworkConditionProfile presets + pure pacing math (tests first)</name>
  <files>
    BoosterSimApp/Models/NetworkConditionProfile.swift,
    BoosterSimAppTests/NetworkConditionProfileTests.swift,
    BoosterSimApp.xcodeproj/project.pbxproj
  </files>
  <read_first>
    - .planning/phases/05-network-tools/05-RESEARCH.md Pattern 4 (latency sleep + paced chunk delivery), Standard Stack throttle-profile row, Assumption A2 (profile numbers are ours, RocketSim names are the baseline)
    - .planning/phases/05-network-tools/05-PATTERNS.md CertificateModels pattern (enum with associated values + Codable shape)
    - BoosterSimApp/Models/BoosterCommand.swift (as landed in plan 01 — ThrottleSpec lives here)
    - BoosterSimAppTests/CertificateServiceTests.swift (test style)
  </read_first>
  <behavior>
    - NetworkConditionProfileTests: all five presets exist with exact specs — off (nil throttle), edge (latencyMs 800, downloadKbps 200), threeG (latencyMs 400, downloadKbps 750), lte (latencyMs 100, downloadKbps 10000), wifi (latencyMs 20, downloadKbps 25000)
    - NetworkConditionProfileTests: pacing schedule for ThrottleSpec(latencyMs: 400, downloadKbps: 750) over 15000 bytes with chunkBytes 1500 → 10 chunks, first byte at 0.4s, per-chunk interval 16s/10 = 1.6s, last chunk at 0.4 + 10*1.6 s — exact arithmetic on TimeInterval, deterministic
    - NetworkConditionProfileTests: chunk interval scales inversely with kbps — doubling kbps halves the interval; zero/negative kbps or latency inputs are rejected (pacing constructor returns nil or traps a precondition per code-standards error handling — assert the chosen behavior)
    - NetworkConditionProfileTests: NetworkConditionProfile Codable round-trip — selected profile + custom ThrottleSpec survive encode/decode equal
    - NetworkConditionProfileTests: preset display metadata — each profile exposes a short name and a caption string like "3G · 400ms · 750 Kbps" for the picker
  </behavior>
  <action>
    Write NetworkConditionProfileTests.swift first (red). Then create BoosterSimApp/Models/NetworkConditionProfile.swift: enum NetworkConditionProfile: String, Codable, CaseIterable, Identifiable with cases off, edge, threeG, lte, wifi — display names "Off", "EDGE", "3G", "LTE", "Wi-Fi" (RocketSim naming baseline per research) — each case mapping to an optional ThrottleSpec with the exact values in the behavior block (document in a doc comment that values are chosen approximations, research A2, not compliance targets). Add the pure pacing type (name it ThrottleSchedule or extend ThrottleSpec) computing from (latencyMs, downloadKbps, chunkBytes, totalBytes): firstByteDelay: TimeInterval, chunkCount: Int, chunkInterval: TimeInterval, lastChunkAt: TimeInterval. Default chunkBytes constant 1500 (typical MTU-sized delivery unit). All math pure TimeInterval arithmetic — no clocks, no queues, fully unit-testable (research Pattern 3 discipline). Keep the file under 200 LOC. Add the file to the BoosterSimApp target in project.pbxproj.
  </action>
  <verify>
    <automated>xcodebuild -project BoosterSimApp.xcodeproj -scheme BoosterSimApp -destination 'platform=macOS' test -only-testing:BoosterSimAppTests/NetworkConditionProfileTests</automated>
  </verify>
  <acceptance_criteria>
    - BoosterSimApp/Models/NetworkConditionProfile.swift declares enum NetworkConditionProfile: String, Codable, CaseIterable with exactly the five cases off, edge, threeG, lte, wifi
    - Preset spec values match the behavior block exactly (edge 800/200, threeG 400/750, lte 100/10000, wifi 20/25000)
    - The pacing math is a pure function of its inputs with no Date, clock, queue, or sleep references in the model file
    - NetworkConditionProfileTests.swift imports Testing, uses @Test + #expect, and covers all five behavior bullets
    - The xcodebuild test command exits 0
  </acceptance_criteria>
  <done>Presets and deterministic pacing math exist Mac-side, green under Swift Testing.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: .throttle verdict + paced enforcement in BoosterNetworkProtocol</name>
  <files>
    BoosterSimApp/Models/BoosterCommand.swift,
    BoosterSimConnect/NetworkConditionController.swift,
    BoosterSimConnect/BoosterNetworkProtocol.swift,
    BoosterSimConnect/ThrottlePacing.swift,
    BoosterSimAppTests/ConditionVerdictTests.swift,
    BoosterSimApp.xcodeproj/project.pbxproj
  </files>
  <read_first>
    - .planning/phases/05-network-tools/05-RESEARCH.md Pattern 4 (throttle enforcement), Pitfall 2 (recursion — guard header + stripped protocolClasses), Pitfall 6 (no @MainActor in URLProtocol paths), Pitfall 7 (outer timeouts are intended realism), Pitfall 8 (upload approximated by latency)
    - BoosterSimConnect/BoosterNetworkProtocol.swift and BoosterSimConnect/NetworkConditionController.swift as landed in plan 01
    - BoosterSimApp/Models/BoosterCommand.swift as landed in plan 01 (Mac-side evaluate to extend first)
    - BoosterSimAppTests/ConditionVerdictTests.swift as landed in plan 01
    - AGENTS.md GitNexus section — run gitnexus_impact (upstream) on BoosterNetworkProtocol and NetworkConditionController before editing
  </read_first>
  <behavior>
    - ConditionVerdictTests (extend): evaluate with airplane=false, no matching rules, throttle=ThrottleSpec(400, 750, nil) returns .throttle with the spec attached
    - ConditionVerdictTests (extend): precedence — airplane=true still returns .fail(.notConnectedToInternet) even when throttle is set; an enabled matching rule still fails before throttle applies (order: airplane > rules > throttle)
    - ConditionVerdictTests (extend): guard-marked requests still return .passThrough even with throttle set
  </behavior>
  <action>
    Extend the Mac-side decision layer FIRST (red tests, then green): add case throttle(ThrottleSpec) to ConditionVerdict in BoosterCommand.swift and the ordered branch in evaluate after the rules check (airplane > rules > throttle > passThrough).

    Then mirror schema-synced into the framework: extend the framework copies in NetworkConditionController.swift (verdict case + evaluate branch identical in semantics).

    Create BoosterSimConnect/ThrottlePacing.swift (new): final class ThrottlePacing — framework-side enforcement helper holding the serial DispatchQueue, computing chunk delivery times from the Mac-side math mirrored verbatim (chunkInterval = chunkBytes * 8 / kbps), with a method to schedule delivery of response + data chunks and a cancel() that drops all pending work. No @MainActor (Pitfall 6); state guarded per-instance on its own serial queue.

    Extend BoosterSimConnect/BoosterNetworkProtocol.swift: canInit(with:) additionally returns true when the verdict is .throttle; startLoading() handles .throttle(ThrottleSpec) by (1) forwarding via the plan-01 inner ephemeral URLSession (request with X-Booster-Internal header, configuration.protocolClasses = []), (2) on receiving the response: wait latencyMs (ThrottlePacing schedule) before client?.urlProtocol(didReceive cacheStoragePolicy:), (3) then deliver the body data in chunkBytes slices at chunkInterval spacing via urlProtocol(_:didLoad:), finishing with urlProtocolDidFinishLoading, (4) stopLoading() cancels the inner task AND ThrottlePacing pending items. Use the standard URLProtocolClient callbacks exactly (research Pattern 4 citations: Mocker delay precedent + URLProtocolClient reference). Document upload pacing as approximated by the latency phase only (A5) in a doc comment. Add both new/changed framework files to the BoosterSimConnect target in project.pbxproj.
  </action>
  <verify>
    <automated>xcodebuild -project BoosterSimApp.xcodeproj -scheme BoosterSimApp -destination 'platform=macOS' test -only-testing:BoosterSimAppTests/ConditionVerdictTests && xcodebuild -project BoosterSimApp.xcodeproj -scheme BoosterSimApp -destination 'platform=macOS' build</automated>
  </verify>
  <acceptance_criteria>
    - BoosterCommand.swift ConditionVerdict has a throttle(ThrottleSpec) case and evaluate enforces the order airplane > rules > throttle > passThrough
    - NetworkConditionController.swift framework mirror carries the same case and order (schema-synced)
    - BoosterSimConnect/ThrottlePacing.swift exists, contains no @MainActor attribute, and owns a serial DispatchQueue for scheduled delivery
    - BoosterNetworkProtocol.swift startLoading references the latency delay before the first didReceive callback and chunked didLoad delivery, and stopLoading cancels both the inner task and pending paced items
    - The inner forwarding request sets X-Booster-Internal and its configuration has an empty protocolClasses array (Pitfall 2 defense present in source)
    - ConditionVerdictTests covers throttle verdict, both precedence cases, and the guard-exemption case; xcodebuild commands exit 0
  </acceptance_criteria>
  <reversibility rating="reversible">Pacing behavior is additive to the verdict enum and protocol; reverting removes a case — no persisted or published contract changes.</reversibility>
  <done>.throttle is enforced end-to-end: profile snapshot → verdict → latency + paced chunks inside the app under test, with anti-recursion intact and cancellable in-flight.</done>
</task>

<task type="auto">
  <name>Task 3: Profile selection state + picker pills in NetworkConditionsSectionView</name>
  <files>
    BoosterSimApp/Services/NetworkConditionService.swift,
    BoosterSimApp/Views/SideWindow/network/NetworkConditionsSectionView.swift
  </files>
  <read_first>
    - .planning/phases/05-network-tools/05-PATTERNS.md NetworkConditionsSectionView pattern (pill HStack guidance, 260pt width constraint — Picker rejected) and Pitfall 12 (UI surface creep)
    - BoosterSimApp/Services/NetworkConditionService.swift as landed in plan 01
    - BoosterSimApp/Views/SideWindow/network/NetworkConditionsSectionView.swift as landed in plan 01
    - BoosterSimApp/Views/SideWindow/CertificateSectionView.swift (status row + helper banner patterns)
    - BoosterSimApp/Utilities/DesignTokens.swift (Spacing/SideWindowMetrics)
    - AGENTS.md GitNexus section — run gitnexus_impact (upstream) on NetworkConditionService before editing
  </read_first>
  <action>
    NetworkConditionService: add published selectedProfile: NetworkConditionProfile persisted under UserDefaults key "networkConditionProfile" (same persistence pattern as plan 01's airplane flag) and func selectProfile(_:) that updates persistence, builds the snapshot with throttle = selectedProfile.throttleSpec, and broadcasts through the existing applying→applied path. Profile off maps to throttle nil in the snapshot.

    NetworkConditionsSectionView: below the airplane toggle add a pill row — one small Button per NetworkConditionProfile.allCases styled as segmented pills in an HStack (260pt panel width: compact capsule styling, selected pill uses the amber accent; accessibilityLabel on each pill carrying the profile caption like "3G, 400 milliseconds latency, 750 kilobits per second"). Add an active-condition status caption showing the current effective condition, e.g. "Throttling: 3G · 400ms · 750 Kbps" or "Airplane Mode on" or "No conditions applied", driven by the service state. Keep ≤2-click interaction (single tap selects and applies). Spacing/SideWindowMetrics tokens only; no hardcoded layout values. Airplane ON should visually disable the profile pills (airplane supersedes throttle per verdict precedence) — use .disabled and reduced opacity, never a hidden control.
  </action>
  <verify>
    <automated>xcodebuild -project BoosterSimApp.xcodeproj -scheme BoosterSimApp -destination 'platform=macOS' build && xcodebuild -project BoosterSimApp.xcodeproj -scheme BoosterSimApp -destination 'platform=macOS' test -only-testing:BoosterSimAppTests/NetworkConditionServiceTests -only-testing:BoosterSimAppTests/NetworkConditionProfileTests</automated>
  </verify>
  <acceptance_criteria>
    - NetworkConditionService.swift exposes selectedProfile and selectProfile(_:), persists under the exact key "networkConditionProfile", and the built snapshot carries throttle = selectedProfile.throttleSpec (nil for off)
    - NetworkConditionsSectionView.swift renders one selectable pill per case of NetworkConditionProfile.allCases (five pills) with accessibilityLabel on each
    - Selecting a pill is a single tap (no confirmation step) and the status caption reflects the effective condition
    - The airplane toggle disables the pill row when ON (source shows .disabled bound to airplane state)
    - Layout references only Spacing.* / SideWindowMetrics.* tokens
    - Build and both test suites exit 0
  </acceptance_criteria>
  <reversibility rating="costly">UserDefaults key "networkConditionProfile" becomes a persisted user-facing key — renaming later strands stored selection; choose final name now.</reversibility>
  <done>Criterion 3 (throttle from the side panel) is user-operable: pick a profile in one tap, the app under test is paced, state persists and reconciles.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| Mac app → Simulator app process | ThrottleSpec rides the version-gated BoosterCommand snapshot over _booster-cmd._tcp. (plan-01 channel, unchanged) |
| App-under-test traffic → BoosterNetworkProtocol | Throttled requests are held and paced on a framework-owned serial queue before delivery to the app |

## STRIDE Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation Plan |
|-----------|----------|-----------|----------|-------------|-----------------|
| T-05-06 | DoS | ThrottlePacing unbounded queues | medium | mitigate | Chunk scheduling bounded by response body size; every scheduled item cancellable from stopLoading; inner session request timeouts remain the app's own (Pitfall 7 documented realism); serial queue per in-flight request, released on completion |
| T-05-07 | Tampering | Throttle spec on the wire | low | mitigate | Spec values are Ints inside the version-gated snapshot; malformed/oversized frames already dropped by plan-01 framing (cap + version gate); negative/zero kbps rejected by the pacing constructor (Task 1 behavior) |
| T-05-SC | Tampering | Package installs | high | mitigate | No installs this plan; Package.resolved must remain unchanged — checked in plan 04 |
</threat_model>

<verification>
- Automated: NetworkConditionProfileTests (pacing math + presets + Codable), extended ConditionVerdictTests (throttle + precedence), NetworkConditionServiceTests still green; macOS app build green (framework target + copy phase included).
- Manual confirmation of visible slow-loading behavior rides the plan-04 phase-gate smoke (3G profile step).
</verification>

<success_criteria>
- The 7 must_haves truths hold; profile selection is ≤2 clicks and persists.
- Pacing math deterministic and green; anti-recursion defenses present in source.
- No SPM changes; both targets build.
</success_criteria>

## Artifacts this phase produces

Created by THIS plan (new symbols):
- NetworkConditionProfile (enum, presets off/edge/threeG/lte/wifi + display metadata + throttleSpec mapping) — BoosterSimApp/Models/NetworkConditionProfile.swift
- ThrottleSchedule / pacing math (pure, Mac-side) — BoosterSimApp/Models/NetworkConditionProfile.swift
- ThrottlePacing (framework enforcement helper, serial queue) — BoosterSimConnect/ThrottlePacing.swift
- Tests: NetworkConditionProfileTests (new)

Extended symbols: ConditionVerdict (+ .throttle case), evaluate(request:snapshot:) (+ throttle branch), NetworkConditionController (framework mirror), BoosterNetworkProtocol (canInit/startLoading/stopLoading throttle paths), NetworkConditionService (+ selectedProfile, selectProfile(_:)), NetworkConditionsSectionView (+ profile pills, effective-condition caption), ConditionVerdictTests (+3 cases).

New UserDefaults key: "networkConditionProfile".

<output>
Create `.planning/phases/05-network-tools/05-02-SUMMARY.md` when done
</output>
