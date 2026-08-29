---
phase: 05-network-tools
plan: 04
type: execute
wave: 3
depends_on: ["05-02-throttle-profiles", "05-03-block-rules"]
files_modified:
  - docs/system-architecture.md
  - docs/codebase-summary.md
autonomous: false
requirements:
  - REQ-fr-16
  - REQ-nfr-03
  - REQ-roadmap-phase5-network-tools
user_setup:
  - service: ios-simulator-debug-app
    why: "Phase-gate manual smoke needs a booted iOS Simulator running a DEBUG app embedding BoosterSimConnect"
    dashboard_config:
      - task: "Boot a Simulator and launch the embedded Connect test app; BoosterSimApp running"
        location: "Xcode → run the embedded-app scheme on a booted Simulator"
estimate:
  tokens: 12000
  raw_tokens: 12000
  tasks: 3
  confidence: low

must_haves:
  truths:
    - "The full BoosterSimAppTests suite is green in one run (all Phase 5 suites plus the pre-existing CertificateServiceTests)"
    - "Manual phase-gate smoke passes on a live Simulator: airplane ON fails an app request which appears as an error row in the viewer while the Mac browses normally; 3G throttle visibly slows a page load; a block rule fails a matching request as an error row; toggling everything off restores normal behavior — and the Certificates section still generates/installs a CA (REQ-fr-16 regression-free)"
    - "docs/system-architecture.md documents the command channel (_booster-cmd._tcp.), the snapshot/verdict enforcement engine, and the URLSession HTTP(S)-only scope limitation with its known gaps (WebSocket, WKWebView, Network.framework, pre-load sessions)"
    - "docs/codebase-summary.md lists the new files and symbols from plans 01-03"
    - "Package.resolved is byte-identical to the phase start (REQ-nfr-03: Pulse/PulseProxy remain the sole dependency exception at 5.2.2)"
  artifacts:
    - docs/system-architecture.md (updated)
    - docs/codebase-summary.md (updated)
  key_links:
    - "Docs ↔ shipped code: every documented symbol (CommandServer, BoosterCommandClient, NetworkConditionController, BoosterNetworkProtocol, NetworkConditionService, BlockRule, NetworkConditionProfile) exists in the source tree at documentation time"
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
      statement: "CLOSES HERE IF SMOKE PASSES: this phase's only certificate interaction is shared Network tab layout; the phase-gate smoke exercises the Certificates section (generate/install) as the regression check. If the smoke fails on certificates, this assumption is invalidated — gap-closure replan required"
    - requirement_id: REQ-nfr-03
      probe: unclassified
      status: resolved-at-close
      statement: "Verified in Task 2: git diff --exit-code BoosterSimApp.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved across the whole phase"
    - requirement_id: REQ-roadmap-phase5-network-tools
      probe: concurrency
      status: resolved-at-close
      statement: "Interrupted/parallel guarantee (plan 01) is confirmed at the gate: the smoke includes the relaunch-reconcile step (Simulator app relaunch re-applies the persisted snapshot) and a mid-condition disconnect/reconnect observation"
---

<objective>
Phase closure: prove all three open success criteria together, keep docs/ the single source of truth, and gate the phase on one manual end-to-end run.

Plans 01-03 delivered the engine (command channel + verdict enforcement), throttle profiles, and block rules with unit coverage. This plan (a) updates the two mandated docs, (b) runs the full suite plus dependency-payload and scope-copy assertions, and (c) executes the phase-gate manual smoke on a live Simulator covering all three tools, the no-Mac-impact guarantee, telemetry non-interference, and a certificate regression check (REQ-fr-16).

Purpose: RESEARCH validation architecture defines the phase gate as "full suite green + one manual e2e run (airplane on → request fails + error row visible + Mac browsing works; throttle 3g → visibly slow load; block rule → failure row) before /gsd-verify-work". AGENTS.md mandates docs/ updates after features land.
Output: updated docs, green full suite, recorded smoke results, closed phase 5.
</objective>

<execution_context>
@~/.claude/gsd-core/workflows/execute-plan.md
@~/.claude/gsd-core/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/ROADMAP.md
@.planning/phases/05-network-tools/05-RESEARCH.md
@.planning/phases/05-network-tools/05-01-SUMMARY.md
@.planning/phases/05-network-tools/05-02-SUMMARY.md
@.planning/phases/05-network-tools/05-03-SUMMARY.md

@docs/system-architecture.md
@docs/codebase-summary.md
</context>

<tasks>

<task type="auto">
  <name>Task 1: Update docs/system-architecture.md and docs/codebase-summary.md</name>
  <files>
    docs/system-architecture.md,
    docs/codebase-summary.md
  </files>
  <read_first>
    - docs/system-architecture.md (current structure and section style — extend, do not restructure)
    - docs/codebase-summary.md (current file inventory format)
    - .planning/phases/05-network-tools/05-01-SUMMARY.md, 05-02-SUMMARY.md, 05-03-SUMMARY.md (what actually landed, including any deviations from plans)
    - The landed source files for symbol-name accuracy: BoosterSimApp/Services/{CommandServer,NetworkConditionService}.swift, BoosterSimApp/Models/{BoosterCommand,BlockRule,NetworkConditionProfile}.swift, BoosterSimConnect/{BoosterCommandClient,NetworkConditionController,BoosterNetworkProtocol,ThrottlePacing}.swift
  </read_first>
  <action>
    docs/system-architecture.md: add a "Network Manipulation" subsection (matching the existing Connect/certificates documentation style) covering: the second Bonjour channel (_booster-cmd._tcp., full-state JSON snapshots, reconcile-on-connect); the enforcement chain (BoosterCommandClient → NetworkConditionController → BoosterNetworkProtocol verdicts: fail/airplane, fail/rules, throttle/latency+pacing); the anti-recursion guard (X-Booster-Internal + stripped protocolClasses); the scope limitation stated honestly (URLSession HTTP(S) traffic of DEBUG apps embedding BoosterSimConnect only — WebSocket, WKWebView, Network.framework, and pre-load sessions unaffected; NWPathMonitor still reports satisfied — research Pitfalls 1/3/4); persistence keys; and the upload-throttling approximation (A5). No marketing language — the docs must state what it does NOT cover.

    docs/codebase-summary.md: append the new files (8 source files + 5 test files from plans 01-03) and their primary types in the existing inventory format, and note the modified mount points (NetworkTabView, AppDelegate, SideWindowController, BoosterSimConnect.activate, AppLogger.network).

    Cross-check every symbol name against the landed source before writing (read_first list) — docs must match reality, including any plan deviations recorded in the summaries.
  </action>
  <verify>
    <automated>for f in CommandServer NetworkConditionService BoosterCommandClient NetworkConditionController BoosterNetworkProtocol ThrottlePacing; do grep -l "$f" docs/system-architecture.md docs/codebase-summary.md | wc -l | grep -q '^2$' || echo "MISSING: $f"; done</automated>
  </verify>
  <acceptance_criteria>
    - docs/system-architecture.md contains a Network Manipulation section referencing "_booster-cmd._tcp.", BoosterNetworkProtocol, and the URLSession HTTP(S) scope limitation
    - docs/codebase-summary.md references all six core new types (automated check above prints no MISSING lines)
    - Every documented symbol name exists in the source tree at documentation time (executor cross-check noted in summary)
  </acceptance_criteria>
  <done>docs/ reflects the landed manipulation engine honestly, including limitations.</done>
</task>

<task type="auto">
  <name>Task 2: Full suite green + dependency-pin + scope-copy assertions</name>
  <files>none</files>
  <read_first>
    - .planning/phases/05-network-tools/05-RESEARCH.md Validation Architecture (full-suite command, phase gate definition)
  </read_first>
  <action>
    Run the full unit suite in one invocation (all Phase 5 suites plus pre-existing tests). Assert the dependency pin is untouched across the phase: git diff --exit-code BoosterSimApp.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved (REQ-nfr-03 closure — flagged assumption FA-02). Verify prohibition compliance mechanically where cheap: NetworkConditionsSectionView.swift and BlockRulesView.swift contain the scope caption strings naming URLSession (PRO-01); the new services log through AppLogger.network with no query-string construction (spot-check the landed logging lines — PRO-03). Run gitnexus_detect_changes (AGENTS.md pre-commit self-check) and confirm the changed-symbol set matches the phase scope (plans 01-03 files plus the two docs). Record all outputs in the summary. Any red test or unexpected symbol drift HALTS the phase gate.
  </action>
  <verify>
    <automated>xcodebuild -project BoosterSimApp.xcodeproj -scheme BoosterSimApp -destination 'platform=macOS' test -only-testing:BoosterSimAppTests && git diff --exit-code BoosterSimApp.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved && grep -c "URLSession" BoosterSimApp/Views/SideWindow/network/NetworkConditionsSectionView.swift</automated>
  </verify>
  <acceptance_criteria>
    - Full BoosterSimAppTests run exits 0 (CommandPayloadTests, ConditionVerdictTests, NetworkConditionServiceTests, NetworkConditionProfileTests, BlockRuleTests, CertificateServiceTests all green)
    - git diff on Package.resolved across the phase is empty (exit 0)
    - NetworkConditionsSectionView.swift contains at least one URLSession scope-caption reference (grep count ≥ 1)
    - gitnexus_detect_changes output recorded in the summary with no out-of-scope symbols
  </acceptance_criteria>
  <done>All automated phase-gate checks green; REQ-nfr-03 dependency assertion closed.</done>
</task>

<task type="checkpoint:human-verify" gate="blocking-human">
  <name>Task 3: Phase-gate manual smoke — all three tools, no Mac impact, certs regression check</name>
  <files>none</files>
  <read_first>
    - .planning/phases/05-network-tools/05-RESEARCH.md Validation Architecture phase-gate row, Pitfalls 3 (reachability reads online — expected), 5 (telemetry stays up), 7 (timeouts under throttle are realistic)
    - Smoke results from plan 01 Task 3 (already-verified airplane path — re-verify quickly, do not skip)
  </read_first>
  <action>
    Blocking human checkpoint on a live Simulator (user_setup prerequisites). The human runs and records pass/fail per step: (1) AIRPLANE — toggle ON, trigger an app request → fails NSURLErrorNotConnectedToInternet, error row visible in the traffic viewer (research A6 confirmation), viewer stays connected, Mac browser loads a page; toggle OFF → request succeeds. (2) THROTTLE — select 3G, load a content-heavy request in the app → visibly slow (multi-second), then a slow row in the viewer; select Off → speed restored. (3) BLOCK — add rule *.example.com (or a domain the test app actually calls), trigger a matching request → fails NSURLErrorCannotConnectToHost with an error row; delete the rule → request succeeds on next try. (4) RECONCILE — with a condition active, relaunch the Simulator app → condition re-applies within ~1s of reconnect. (5) CERTS REGRESSION (REQ-fr-16) — in the same Network tab, run the Certificates flow (generate/install against the Simulator keychain) → succeeds exactly as before Phase 5. (6) CLEAN STATE — set everything off, confirm normal app behavior. The executor records each step's observed result in the summary; any failure = gap-closure replan (do not patch past the gate). This checkpoint also closes the flagged assumptions FA-01 (certs regression-free), FA-03 (reconnect reconcile observed), and partially PRO-01/PRO-02 (observed behaviors, human-verified).
  </action>
  <verify>
    <human-check>All six smoke groups observed and recorded pass/fail in the summary; specifically the three-way airplane proof (app fails / viewer live / Mac unaffected), visible 3G slowdown, block-rule error row, relaunch reconcile, and a working certificate install.</human-check>
  </verify>
  <acceptance_criteria>
    - Summary contains per-group pass/fail records for all six groups
    - Airplane three-way proof passes (criterion 4 + PRO-02)
    - Throttle visible-slowdown passes (criterion 3) and block-rule error row passes (criterion 5)
    - Certificate generate/install passes in the same session (REQ-fr-16 regression check, FA-01 closes)
    - Reconnect reconcile observed (FA-03 closes)
  </acceptance_criteria>
  <what-built>All three Phase 5 manipulation tools on the proven command-channel engine: Airplane Mode (plan 01), throttle profiles off/EDGE/3G/LTE/Wi-Fi with latency+bandwidth pacing (plan 02), and domain/path block rules with editor UI (plan 03) — plus updated docs/system-architecture.md and docs/codebase-summary.md, and a green full BoosterSimAppTests suite with an unchanged Package.resolved.</what-built>
  <how-to-verify>
    With BoosterSimApp running and a booted Simulator DEBUG app embedding BoosterSimConnect:
    1. AIRPLANE — toggle ON, trigger an app request → fails NSURLErrorNotConnectedToInternet with an error row in the traffic viewer, viewer stays connected, Mac browser loads a page; toggle OFF → request succeeds
    2. THROTTLE — select 3G, load a content-heavy request → visibly slow, slow row in the viewer; select Off → speed restored
    3. BLOCK — add rule *.example.com (or a domain the test app calls), trigger a matching request → fails NSURLErrorCannotConnectToHost with an error row; delete the rule → request succeeds on next try
    4. RECONCILE — with a condition active, relaunch the Simulator app → condition re-applies within ~1 second of reconnect
    5. CERTS — in the same Network tab, run the Certificates flow (generate/install against the Simulator keychain) → succeeds as before Phase 5
    6. CLEAN STATE — set everything off, confirm normal app behavior
  </how-to-verify>
  <resume-signal>Reply "approved" to close phase 5 (proceed to /gsd-verify-work), or describe the failing group → gap-closure replan (do not patch past the gate).</resume-signal>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| Whole-phase review boundary | This plan re-verifies every boundary shipped in plans 01-03 (LAN→CommandServer, Mac→Simulator frames, app traffic→verdict) at the gate rather than introducing new ones |

## STRIDE Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation Plan |
|-----------|----------|-----------|----------|-------------|-----------------|
| T-05-09 | Information Disclosure | Docs describing the attack surface | low | mitigate | Docs document the loopback-bind design and its LAN fallback condition only — no credential, path, or machine-specific detail beyond existing doc conventions |
| T-05-SC | Tampering | Package installs (phase-close audit) | high | mitigate | git diff --exit-code on Package.resolved across the entire phase (Task 2) — any SPM drift blocks the gate and forces replan |
</threat_model>

<verification>
- Task 1: docs symbol cross-check (automated grep over both docs for the six core types).
- Task 2: full-suite xcodebuild run + Package.resolved diff + scope-caption grep + gitnexus_detect_changes.
- Task 3: blocking manual smoke (six groups) on a live Simulator.
</verification>

<success_criteria>
- All 5 must_haves truths hold; the three open ROADMAP criteria (3, 4, 5) are each proven in the smoke.
- REQ-fr-16 regression check passes; REQ-nfr-03 dependency assertion closed with an empty diff.
- Docs updated to match landed reality including limitations.
</success_criteria>

## Artifacts this phase produces

Created by THIS plan (new symbols): none (closure plan — docs content only, no new code symbols).

Modified: docs/system-architecture.md (+ Network Manipulation section), docs/codebase-summary.md (+ plans 01-03 file/type inventory).

Verification artifacts recorded in the summary: full-suite output, Package.resolved diff result, gitnexus_detect_changes scope, six-group smoke record.

<output>
Create `.planning/phases/05-network-tools/05-04-SUMMARY.md` when done
</output>
