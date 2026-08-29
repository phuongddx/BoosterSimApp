---
phase: 05-network-tools
plan: 03
type: execute
wave: 2
depends_on: ["05-01-command-channel-tracer"]
files_modified:
  - BoosterSimApp/Models/BlockRule.swift
  - BoosterSimApp/Views/SideWindow/network/BlockRulesView.swift
  - BoosterSimApp/Views/SideWindow/tabs/NetworkTabView.swift
  - BoosterSimAppTests/BlockRuleTests.swift
  - BoosterSimApp.xcodeproj/project.pbxproj
autonomous: true
requirements:
  - REQ-roadmap-phase5-network-tools
estimate:
  tokens: 18000
  raw_tokens: 18000
  tasks: 2
  confidence: low

must_haves:
  truths:
    - "Adding a rule with domain *.example.com makes requests to any dot-boundary subdomain of example.com fail with URLError code NSURLErrorCannotConnectToHost (-1004) on the next snapshot push, and the failure appears as an error row in the traffic viewer through the existing error mapping"
    - "BlockRule.matches verdicts (unit-tested): exact host equality matches; *.suffix matches host on a dot boundary (badexample.com must NOT match *.example.com); pathPrefix narrows via hasPrefix and a rule without pathPrefix matches every path; disabled rule never matches; host comparison is case-insensitive; requests with nil URL.host never match"
    - "Rules persist across BoosterSimApp relaunch (UserDefaults key networkBlockRules) and re-apply on the next client connect via snapshot reconcile"
    - "Disabling or deleting a rule restores matching requests on the next snapshot push — no restart of the app under test required"
    - "The rules editor is reachable within the Network tab as its own CollapsibleSection, default-collapsed when no rules exist, and every mutation is ≤2 interactions (toggle, delete button, add row)"
    - "Rule count is capped at 50 — the add control refuses beyond the cap with an explanatory caption (threat T-05-02 mitigation)"
  artifacts:
    - BoosterSimApp/Views/SideWindow/network/BlockRulesView.swift
    - BoosterSimAppTests/BlockRuleTests.swift
  key_links:
    - "BlockRulesView mutations → NetworkConditionService.addRule/removeRule/setRuleEnabled (plan-01 service surface) → snapshot broadcast → NetworkConditionController → BoosterNetworkProtocol .fail(.cannotConnectToHost)"
    - "BlockRulesView mounted in NetworkTabView between NetworkConditionsSectionView and CertificateSectionView"
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
      statement: "Certificate flows are delivered and untouched this phase; the only interaction is the shared Network tab layout (BlockRulesView mounts in the same VStack as CertificateSectionView). Assumption: certificate code paths stay regression-free — verified at the plan-04 phase-gate smoke"
    - requirement_id: REQ-nfr-03
      probe: unclassified
      status: unresolved
      statement: "No SPM changes are needed (Pulse pinned at 5.2.2, no new packages). Check at plan close: git diff --exit-code BoosterSimApp.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved"
    - requirement_id: REQ-roadmap-phase5-network-tools
      probe: concurrency
      status: resolved-by-design-pending-manual-confirm
      statement: "Interrupted/parallel guarantee (from plan 01): rule mutations flow through the single-writer service as full-state snapshots — a rule deleted mid-broadcast leaves the client at the last COMPLETE snapshot (old or new rules, never a mixture); disabling/deleting takes effect on the next push, no in-flight request state is mutated. No new concurrency surface is introduced by this plan (matcher is pure; UI is @MainActor)"
---

<objective>
Expansion slice 2 of the proven tracer engine: request blocking by domain/path rules (ROADMAP criterion 5).

Ship the rules editor UI (list, add, toggle, delete — mounted in the Network tab) on top of the plan-01 service surface (rules CRUD + persistence + snapshot broadcast already exist), and harden the BlockRule matcher to full edge coverage with tests: dot-boundary suffix matching, case-insensitivity, path prefixing, disabled rules, nil-host safety.

Purpose: Blocking rides the SAME enforcement mechanism as airplane mode (.fail verdict with a distinct URLError code — Pitfall 10: .cannotConnectToHost rather than .cancelled, so SDK retry logic and error-driven UI see a connection failure), keeping one mechanism for all three tools per the research primary recommendation.
Output: BlockRulesView, hardened matcher, BlockRuleTests.
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
@BoosterSimApp/Views/SideWindow/FeatureRowView.swift
@BoosterSimApp/Views/SideWindow/CertificateSectionView.swift
@BoosterSimApp/Views/Shared/CollapsibleSection.swift
@BoosterSimApp/Utilities/DesignTokens.swift
@BoosterSimAppTests/CertificateServiceTests.swift
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: BlockRule matcher hardening with full test coverage (tests first)</name>
  <files>
    BoosterSimApp/Models/BlockRule.swift,
    BoosterSimAppTests/BlockRuleTests.swift,
    BoosterSimApp.xcodeproj/project.pbxproj
  </files>
  <read_first>
    - .planning/phases/05-network-tools/05-RESEARCH.md Don't Hand-Roll table (block matching engine row: string ops only, no regex — ReDoS impossible by construction), Pitfall 10 (error-code choice), Security Domain V5 row
    - BoosterSimApp/Models/BlockRule.swift as landed in plan 01
    - BoosterSimAppTests/CertificateServiceTests.swift (test style)
    - AGENTS.md GitNexus section — run gitnexus_impact (upstream) on BlockRule before editing
  </read_first>
  <behavior>
    - BlockRuleTests: URLRequest to https://api.example.com/v1/feed matches rule domain "api.example.com" (exact host)
    - BlockRuleTests: https://cdn.example.com/img.png matches rule domain "*.example.com" (dot-boundary suffix)
    - BlockRuleTests: https://badexample.com does NOT match rule domain "*.example.com" (suffix must align on a dot boundary — the negative case that separates hasSuffix(".example.com") from naive hasSuffix("example.com"))
    - BlockRuleTests: rule domain "example.com" with pathPrefix "/api" matches https://example.com/api/v1 and does NOT match https://example.com/docs
    - BlockRuleTests: same rule without pathPrefix matches both /api/v1 and /docs (prefix only narrows)
    - BlockRuleTests: rule with isEnabled false never matches even on exact host
    - BlockRuleTests: host case-insensitivity — rule "API.Example.COM" matches host "api.example.com"
    - BlockRuleTests: URLRequest with nil URL.host never matches any rule
    - BlockRuleTests: whitespace-trimmed input — rule domain " api.example.com " (as typed into a text field) matches exact host (matcher or add-path trims)
    - BlockRuleTests: empty-string domain rule never matches (defensive: no accidental match-all)
  </behavior>
  <action>
    Write BlockRuleTests.swift first (red against the plan-01 matcher), then harden BlockRule.matches to green: lowercase host AND rule domain before comparison; for "*."-prefixed rules require host.hasSuffix("." + base) OR host == base where base is the domain after the "*." prefix stripped (an apex match is convenient and explicit); trim whitespace from rule fields before use (do it in matches or in the service add-path — pick matches so both UI and decode paths are safe); treat empty domain as never-matching. Keep ONLY string operations — hasSuffix, hasPrefix, lowercased, trimming, equality. Mirror the exact same semantics into the framework-side BlockRule copy inside BoosterSimConnect/NetworkConditionController.swift (schema-sync rule: the two implementations must stay semantically identical — add a comment cross-referencing BlockRuleTests as the contract). Add BlockRuleTests.swift to the BoosterSimAppTests target in project.pbxproj.
  </action>
  <verify>
    <automated>xcodebuild -project BoosterSimApp.xcodeproj -scheme BoosterSimApp -destination 'platform=macOS' test -only-testing:BoosterSimAppTests/BlockRuleTests</automated>
  </verify>
  <acceptance_criteria>
    - BoosterSimAppTests/BlockRuleTests.swift imports Testing and covers all ten behavior bullets as separate @Test funcs or #expect groups
    - BlockRule.swift matches implementation references only string APIs (hasSuffix/hasPrefix/lowercased/trimming/==) — the file contains no NSRegularExpression or Regex literal
    - The badexample.com dot-boundary negative case passes (guards against naive hasSuffix)
    - The framework-side BlockRule mirror in NetworkConditionController.swift carries the same comparison semantics with a cross-reference comment
    - The xcodebuild test command exits 0
  </acceptance_criteria>
  <done>Matcher is edge-hardened, string-ops-only, and green under ten targeted tests on both sides of the schema sync.</done>
</task>

<task type="auto">
  <name>Task 2: BlockRulesView editor + Network tab mount</name>
  <files>
    BoosterSimApp/Views/SideWindow/network/BlockRulesView.swift,
    BoosterSimApp/Views/SideWindow/tabs/NetworkTabView.swift,
    BoosterSimApp.xcodeproj/project.pbxproj
  </files>
  <read_first>
    - .planning/phases/05-network-tools/05-PATTERNS.md BlockRulesView pattern (FeatureRowView row styling, SideWindowMetrics.rowHeight) and Pitfall 12 (UI surface creep — CollapsibleSection, default collapsed)
    - BoosterSimApp/Views/SideWindow/FeatureRowView.swift (row styling reference)
    - BoosterSimApp/Views/Shared/CollapsibleSection.swift (atom API)
    - BoosterSimApp/Services/NetworkConditionService.swift as landed in plan 01 (rules CRUD surface: addRule/removeRule/setRuleEnabled, published rules)
    - BoosterSimApp/Views/SideWindow/tabs/NetworkTabView.swift as landed in plan 01 (mount point after NetworkConditionsSectionView)
    - BoosterSimApp/Utilities/DesignTokens.swift
    - AGENTS.md GitNexus section — run gitnexus_impact (upstream) on NetworkTabView before editing
  </read_first>
  <action>
    Create BoosterSimApp/Views/SideWindow/network/BlockRulesView.swift: struct BlockRulesView: View wrapped in CollapsibleSection(title: "Block Rules", icon: "shield.lefthalf.filled"), binding @EnvironmentObject var networkConditionService. Rows follow FeatureRowView styling: domain text (.body, .primary), optional pathPrefix shown as a secondary .caption badge, a Toggle bound to rule.isEnabled calling setRuleEnabled, and a trash button (Image systemName "trash", accessibilityLabel "Delete rule domain-name") calling removeRule; row height SideWindowMetrics.rowHeight, padding Spacing.md horizontal. Below the list: an add row — TextField prompt "domain or *.domain.com" plus optional path prefix TextField prompt "/api/path" and an add Button (plus icon) calling addRule, disabled when the domain field is empty or the 50-rule cap is reached; when capped show a .caption explanation "Rule limit reached (50)". Header caption shows enabled-rule count like "3 of 5 enabled". Section default-collapsed when rules array is empty (isExpanded initial value false when service.rules.isEmpty). Scope caption in .caption secondary: "Blocked requests fail with a connection error in the traffic viewer" (honest failure semantics, no overclaiming — PRO-01). All layout via DesignTokens; accessibilityLabels on all icon-only controls. Empty state: when no rules exist and expanded, a single secondary caption "No block rules".

    Modify BoosterSimApp/Views/SideWindow/tabs/NetworkTabView.swift: insert BlockRulesView() directly after NetworkConditionsSectionView() (before CertificateSectionView). Add BlockRulesView.swift to the BoosterSimApp target in project.pbxproj.
  </action>
  <verify>
    <automated>xcodebuild -project BoosterSimApp.xcodeproj -scheme BoosterSimApp -destination 'platform=macOS' build && xcodebuild -project BoosterSimApp.xcodeproj -scheme BoosterSimApp -destination 'platform=macOS' test -only-testing:BoosterSimAppTests/BlockRuleTests -only-testing:BoosterSimAppTests/NetworkConditionServiceTests</automated>
  </verify>
  <acceptance_criteria>
    - BoosterSimApp/Views/SideWindow/network/BlockRulesView.swift declares struct BlockRulesView: View and wraps its content in CollapsibleSection with title "Block Rules"
    - The view references networkConditionService.addRule, removeRule, and setRuleEnabled (all mutations go through the service, none direct to UserDefaults)
    - The add control is disabled on empty domain input and at 50 rules, with a visible caption at the cap
    - Row styling uses SideWindowMetrics.rowHeight and Spacing tokens only; every icon-only control has accessibilityLabel
    - NetworkTabView.swift body references BlockRulesView after NetworkConditionsSectionView and before CertificateSectionView
    - Build and both test suites exit 0
  </acceptance_criteria>
  <done>Criterion 5 (block requests by domain/path rules) is user-operable from the Network tab with full matcher coverage.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| User input → rule strings | Free-text domain/path fields enter the matcher that gates every request in the app under test |
| Mac app → Simulator app process | Rules ride the version-gated BoosterCommand snapshot over _booster-cmd._tcp. (plan-01 channel, unchanged) |

## STRIDE Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation Plan |
|-----------|----------|-----------|----------|-------------|-----------------|
| T-05-02 | DoS | Block-rule matcher on user strings | low | mitigate (design) | No regex compilation ever — bounded O(rules) string comparisons (Task 1 acceptance enforces string-ops-only); rule count capped at 50 in the UI (Task 2); malformed frames already dropped by plan-01 framing |
| T-05-08 | Tampering | Accidental match-all rule breaks the app under test | medium | mitigate | Empty domain never matches (Task 1); add control requires non-empty domain (Task 2); disabling a rule is one click and takes effect on next push; rules are per-embedding-app only (never touches Mac or other apps) |
| T-05-SC | Tampering | Package installs | high | mitigate | No installs this plan; Package.resolved must remain unchanged — checked in plan 04 |
</threat_model>

<verification>
- Automated: BlockRuleTests (ten matcher cases), NetworkConditionServiceTests still green (rules persistence covered in plan 01), macOS app build green.
- Wave-2 serialization note: plan 02 (05-02-throttle-profiles) also modifies BoosterSimApp.xcodeproj/project.pbxproj in this wave — different target/sections, so overlap is merge-conflict-level only; pbxproj edits within Wave 2 must serialize (executor wave guard); no other files_modified overlap with plan 02.
- Manual confirmation (blocked request produces an error row in the viewer — research A6) rides the plan-04 phase-gate smoke.
</verification>

<success_criteria>
- The 6 must_haves truths hold; rules CRUD is ≤2 interactions and persists.
- Matcher edge cases green; no regex anywhere in the matcher; framework mirror semantically identical.
- No SPM changes; builds green.
</success_criteria>

## Artifacts this phase produces

Created by THIS plan (new symbols):
- BlockRulesView — BoosterSimApp/Views/SideWindow/network/BlockRulesView.swift
- Tests: BlockRuleTests (new, ten-case matcher contract)

Extended symbols: BlockRule.matches (hardened: dot-boundary suffix, case-insensitive host, trim, empty-domain safety), NetworkTabView (+ BlockRulesView mount).

No new persisted keys (rules already persist under "networkBlockRules" from plan 01).

<output>
Create `.planning/phases/05-network-tools/05-03-SUMMARY.md` when done
</output>
