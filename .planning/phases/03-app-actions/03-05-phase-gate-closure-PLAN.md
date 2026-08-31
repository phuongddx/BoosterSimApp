---
phase: 03-app-actions
plan: 05
type: execute
wave: 5
depends_on: ["03-04-defaults-editor-search"]
files_modified:
  - docs/system-architecture.md
  - docs/codebase-summary.md
autonomous: false
requirements:
  - REQ-roadmap-phase3-app-actions
user_setup:
  - service: ios-simulator
    why: "Phase-gate manual smoke needs a booted Simulator with the full checklist state: an app built from DerivedData and installed with persisted state, push permission granted, Apple Maps available, and the local CA generated + installed for the D-02 reconcile re-check"
    dashboard_config:
      - task: "Boot one Simulator; run an iOS app from Xcode onto it once; grant it notification permission in Settings; keep Maps available"
        location: "Xcode → run on the booted Simulator; then Simulator Settings → Notifications → <app> → Allow"
      - task: "Generate + install the BoosterSimApp local CA (Network tab) before starting the smoke"
        location: "BoosterSimApp side panel → Network → Certificates"
estimate:
  tokens: 14000
  raw_tokens: 14000
  tasks: 3
  confidence: low

must_haves:
  truths:
    - "The full BoosterSimAppTests suite is green in one run (all Phase 3 suites — AppActionServiceTests, DerivedDataAppScannerTests, DeepLinkServiceTests, PrivacyPermissionTests, PushPayloadTests, LocaleCommandTests, UserDefaultsEditorServiceTests, AppActionCatalogTests — plus every pre-existing suite)"
    - "Idempotency: Re-invoking an action with identical inputs is safe: repeated typed defaults-write produces identical plist state; repeated reset terminates-if-running then uninstalls-if-installed without erroring; repeated push send delivers N payloads with no corruption."
    - "Concurrency: One action pipeline at a time: SimCtlService serializes invocations (queued, never interleaved); an interrupted action leaves the service in recoverable idle state with no half-written plist (typed writes land atomically or not at all)."
    - "Empty: Empty/null inputs fail fast with typed errors, never crashes: empty bundle ID → typed error; empty search query → full catalog; empty defaults plist → empty list; empty push payload → rejected."
    - "Ordering: Deterministic stable ordering: action catalog sections in fixed order with stable ranking within (equal-keyword matches never shuffle between queries); DerivedDataAppScanner dedupes equal bundle IDs by most-recent mtime deterministically."
    - "Adjacency: Boundary inputs keep results distinct: adjacent catalog sections stay independent; a bundle ID matching multiple DerivedData entries resolves to exactly one candidate (most recent) with the alternatives visible in the picker; scanner treats symlinked/alias DerivedData paths as the same tree."
    - "The phase-gate manual smoke passes on a live Simulator across all six gate groups from 03-VALIDATION.md (detection, reset + keychain w/ reconcile, push w/ guided grant + deep link, locale/appearance/Dynamic Type/location/clipboard, defaults editor + search, docs) — recorded per-group pass/fail"
    - "docs/system-architecture.md documents the App Actions architecture honestly: the service/scanner/editor split, the active-app reconcile (DerivedData ∩ installed ∩ running badge), the seam hardening (concurrent pipe reads, stdin, serialized invocations), the Action Latency table surfaced as UI captions, and BOTH platform limits verbatim-intent (D-01 notification permission managed by iOS; D-02 device-wide-only keychain with CA reconcile)"
    - "Package.resolved is byte-identical to the phase start (REQ-nfr-03: zero new packages this phase — Pulse/PulseProxy remain the sole exception)"
  artifacts:
    - docs/system-architecture.md (updated)
    - docs/codebase-summary.md (updated)
  key_links:
    - "Docs ↔ shipped code: every documented symbol (AppActionService, DerivedDataAppScanner, UserDefaultsEditorService, PushPayload, PrivacyPermission, DefaultsEntry, AppActionCatalog, AppPickerBar, the migrated DeepLinkService) exists in the source tree at documentation time"
    - "Docs ↔ honesty: the D-01/D-02 limitations and the relaunch/terminate captions in the docs match the shipped UI copy"
  prohibitions:
    - requirement_id: REQ-roadmap-phase3-app-actions
      category: values
      status: unverified
      flagged: true
      statement: "MUST NOT add third-party dependencies or change SPM pins this phase — Apple frameworks only; Package.resolved must be byte-identical at phase close (Pulse/PulseProxy remain the sole package exception)"
    - requirement_id: REQ-roadmap-phase3-app-actions
      category: transparency
      status: unverified
      flagged: true
      statement: "MUST NOT document capabilities the platform does not have — the docs restate both scope limits (notification permission not settable via simctl; keychain clear device-wide only, with automatic CA reconcile) exactly as the UI presents them"
  flagged_assumptions:
    - requirement_id: REQ-roadmap-phase3-app-actions
      probe: idempotency
      status: resolved-at-close
      statement: "Confirmed at the gate: smoke re-runs reset, a repeated defaults write, and a repeated push send and observes stable device/list state (criterion-level idempotency, not just unit contracts)"
    - requirement_id: REQ-roadmap-phase3-app-actions
      probe: concurrency
      status: resolved-at-close
      statement: "Confirmed at the gate: the serialization design (plan 01 seam) holds under the smoke's repeated multi-verb chains (locale write→relaunch, reset chain) — no interleaved-output corruption, service returns to idle after every action incl. an interrupted one (step 6 re-check)"
---

<objective>
Phase closure: prove all four success criteria together, keep docs/ the single source of truth, and gate the phase on one manual end-to-end run.

Plans 01-04 delivered the seam-hardened action engine (reset/keychain, push/deep links/privacy, locale/location/clipboard, defaults editor/search) with 8 Wave 0 test files. This plan (a) updates the two mandated docs with an honest App Actions section including the D-01/D-02 platform limits, (b) runs the full suite plus the dependency-pin and prohibition-compliance assertions, and (c) executes the phase-gate manual smoke on a live Simulator covering all six gate groups from 03-VALIDATION.md.

Purpose: 03-VALIDATION.md defines the phase gate as "full suite green + phase-gate manual smoke before /gsd-verify-work"; AGENTS.md mandates docs/ updates after features land; the house gate standard (STATE.md Phase 2/5 pattern) is unit bundle + Debug build + unchanged dependency pin.
Output: updated docs, green full suite, recorded six-group smoke, closed phase 3.
</objective>

<execution_context>
@~/.claude/gsd-core/workflows/execute-plan.md
@~/.claude/gsd-core/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/ROADMAP.md
@.planning/phases/03-app-actions/03-RESEARCH.md
@.planning/phases/03-app-actions/03-VALIDATION.md
@.planning/phases/03-app-actions/03-01-SUMMARY.md
@.planning/phases/03-app-actions/03-02-SUMMARY.md
@.planning/phases/03-app-actions/03-03-SUMMARY.md
@.planning/phases/03-app-actions/03-04-SUMMARY.md

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
    - .planning/phases/03-app-actions/03-01-SUMMARY.md through 03-04-SUMMARY.md (what actually landed, incl. deviations from plans — the 02-02/05-04 truth-pass discipline)
    - The landed source files for symbol-name accuracy: BoosterSimApp/Services/{AppActionService,DerivedDataAppScanner,UserDefaultsEditorService}.swift, BoosterSimApp/Models/{PushPayload,PrivacyPermission,DefaultsEntry,AppAction}.swift, BoosterSimApp/Views/SideWindow/actions/* (7 views), the modified SimCtlService/DeepLinkService/ActionsTabView
    - .planning/phases/03-app-actions/03-RESEARCH.md — Action Latency & Effect Table (the caption source of truth) and the two scope-honest gaps behind D-01/D-02
  </read_first>
  <action>
    docs/system-architecture.md: add an "App Actions" section (matching the existing Capture/Network documentation style) covering: the service split (AppActionService facade + DerivedDataAppScanner + UserDefaultsEditorService over the extended SimCtlService seam — concurrent pipe reads, stdin support, serialized invocations, and WHY each exists: the 33 KB listapps deadlock, the push stdin payload, the one-pipeline-at-a-time guarantee); the active-app reconcile model (DerivedData scan ∩ listapps installed ∩ launchctl running badge, explicit picker, no frontmost verb exists); the per-action effect-latency table from RESEARCH rendered as the UI caption contract (instant / relaunch-required / device-wide); the UserDefaults editor data path (container plist file read, typed spawn writes, cfprefsd coherence); and BOTH platform limits stated exactly as the UI does (notification permission is managed by iOS and not settable from simctl — D-01 guided grant; keychain clear is device-wide and wipes the local CA, automatically re-reconciled via CertificateService — D-02). Correct any stale line the phase invalidated (e.g. the DeepLinkService async exemption) in the same truth pass.

    docs/codebase-summary.md: append the Phase 3 files (15 source files + 8 test files) with their primary types in the existing inventory format, and note the modified mount points (SimCtlService, DeepLinkService, ActionsTabView, AppDelegate, SideWindowView, AppLogger, .planning/codebase/CONVENTIONS.md exemption-list shrink).

    Cross-check every symbol name against the landed source before writing — docs must match reality, including plan deviations recorded in the summaries.
  </action>
  <verify>
    <automated>for f in AppActionService DerivedDataAppScanner UserDefaultsEditorService PushPayload PrivacyPermission DefaultsEntry AppActionCatalog AppPickerBar; do grep -l "$f" docs/system-architecture.md docs/codebase-summary.md | wc -l | grep -q '^2$' || echo "MISSING: $f"; done</automated>
  </verify>
  <acceptance_criteria>
    - docs/system-architecture.md contains an App Actions section naming the seam hardening (concurrent reads, stdin, serialization), the active-app reconcile, the effect-latency caption contract, and both D-01/D-02 limitations in UI-matching wording
    - docs/codebase-summary.md references all eight core new types (automated check above prints no MISSING lines)
    - Every documented symbol name exists in the source tree at documentation time (executor cross-check noted in the summary)
    - No stale DeepLinkService-exemption or pre-phase-3 statement survives that the phase invalidated
  </acceptance_criteria>
  <done>docs/ reflects the landed App Actions architecture honestly, including both platform limits.</done>
</task>

<task type="auto">
  <name>Task 2: Full suite green + dependency-pin + prohibition-compliance assertions</name>
  <files>none</files>
  <read_first>
    - .planning/phases/03-app-actions/03-VALIDATION.md — Test Infrastructure (full-suite command, house standard -parallel-testing-enabled NO) and Validation Sign-Off checklist
    - .planning/phases/03-app-actions/03-RESEARCH.md — Package Legitimacy Audit (n/a — zero installs) and Security Domain (the caption/log prohibitions being asserted)
  </read_first>
  <action>
    Run the full unit bundle in one invocation (all Phase 3 suites + pre-existing; house -parallel-testing-enabled NO per STATE.md infra note) and the BoosterSimApp Debug build. Assert the dependency pin is untouched across the phase: git diff --exit-code on the swiftpm Package.resolved (REQ-nfr-03). Verify prohibition compliance mechanically where cheap: PushNotificationSectionView contains the iOS-managed-permission caption and no permission-granting control; LocaleSectionView contains the takes-effect-on-relaunch caption; AppResetSectionView's keychain dialog message names every-app scope + the CA consequence; AppLogger output sites for defaults/push carry no value/payload interpolation (spot-check the landed logging lines). Run gitnexus_detect_changes (AGENTS.md pre-commit self-check) and confirm the changed-symbol set matches the phase scope (plans 01-04 files plus the two docs). Record all outputs in the summary.
  </action>
  <verify>
    <automated>xcodebuild -project BoosterSimApp.xcodeproj -scheme BoosterSimApp -destination 'platform=macOS' test -only-testing:BoosterSimAppTests -skip-testing:BoosterSimAppUITests -parallel-testing-enabled NO && git diff --exit-code BoosterSimApp.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved && grep -c "managed by iOS" BoosterSimApp/Views/SideWindow/actions/PushNotificationSectionView.swift && grep -c "relaunch" BoosterSimApp/Views/SideWindow/actions/LocaleSectionView.swift</automated>
  </verify>
  <acceptance_criteria>
    - Full BoosterSimAppTests run exits 0 (all 8 Phase 3 suites + pre-existing suites green)
    - git diff on Package.resolved across the phase is empty (exit 0)
    - The D-01 caption grep returns >= 1 and the relaunch-caption grep returns >= 1 (prohibition spot-checks)
    - gitnexus_detect_changes output recorded in the summary with no out-of-scope symbols
  </acceptance_criteria>
  <done>All automated phase-gate checks green; REQ-nfr-03 dependency assertion closed with an empty diff.</done>
</task>

<task type="checkpoint:human-verify" gate="blocking-human">
  <name>Task 3: Phase-gate manual smoke — all six gate groups on one booted Simulator</name>
  <files>none</files>
  <read_first>
    - .planning/phases/03-app-actions/03-VALIDATION.md — Phase-Gate Manual Smoke section (the six steps, verbatim source of the groups below) and Manual-Only Verifications table
    - .planning/phases/03-app-actions/03-RESEARCH.md — Action Latency & Effect table (expected timing per action) and Pitfalls 4, 6, 10 (reconcile, relaunch, stop pairing — the failure modes to watch)
    - Smoke results from plan 01 Task 3 and plan 03 Task 3 (already-verified paths — re-verify quickly, do not skip)
  </read_first>
  <action>
    Blocking human checkpoint on a live Simulator (user_setup prerequisites). The human runs and records pass/fail per group, following 03-VALIDATION.md's gate list: (1) DETECTION — picker shows DerivedData ∩ installed with running badge + explicit selection; (2) RESET — fresh state after reset; D-02 keychain wipe behind the blast-radius dialog with CA re-reconcile; (3) PUSH + DEEP LINK — send with permission (guided grant path re-checked), deep link opens; (4) ENVIRONMENT — locale + Dynamic Type + appearance + location + clipboard round-trip; (5) DEFAULTS + SEARCH — view/edit/add/delete plus quick search across the catalog; (6) DOCS — system-architecture § App Actions matches shipped behavior. Each group also notes the idempotency/concurrency re-check where cheap (re-run reset, re-send push, re-apply locale — stable state, service returns to idle).
  </action>
  <verify>
    <human-check>All six gate groups observed and recorded pass/fail in the summary; specifically the D-01 guided grant, the D-02 blast-radius dialog + automatic CA reconcile, the defaults edit landing in the live app, and the search filtering the full tab deterministically.</human-check>
  </verify>
  <acceptance_criteria>
    - Summary contains per-group pass/fail records for all six gate groups
    - All four ROADMAP criteria are each proven live: reset + keychain (criterion 1), push permission/send + deep links (criterion 2), locale/appearance/Dynamic Type/location/clipboard (criterion 3), defaults editor + search + DerivedData bundle-ID detection (criterion 4)
    - The five probe truths are observed where manually checkable: repeated reset/push/defaults-write stability, service-idle recovery, empty-input typed errors, stable catalog ordering, single-candidate resolution with visible alternatives
    - Docs group confirms the architecture section matches shipped behavior incl. both platform limits
  </acceptance_criteria>
  <what-built>The complete Phase 3 App Actions surface on the proven seam: reset + D-02 keychain with CA reconcile (plan 01), push + D-01 guided grant + privacy + seam-migrated deep links (plan 02), locale/location/clipboard with honest latency captions (plan 03), defaults editor + deterministic quick search (plan 04) — plus updated docs/system-architecture.md and docs/codebase-summary.md, a green full BoosterSimAppTests suite, and an unchanged Package.resolved.</what-built>
  <how-to-verify>
    With BoosterSimApp running and the prepared booted Simulator (app installed w/ state + push permission, CA installed, Maps available):
    1. DETECTION — the Actions tab picker lists the DerivedData-built installed app with a running badge; selection is explicit; run a quick search query and clear it — full tab returns in fixed order
    2. RESET — write state in the app, Reset App Data → fresh on relaunch; Clear Keychain → red blast-radius dialog → wipe → CA re-reconciles automatically (Certificates section healthy); run Reset twice — second run errors nothing
    3. PUSH + DEEP LINK — with permission granted send the alert template → banner + tap-through; re-check the D-01 control (caption + Open Settings); open a preset deep link
    4. ENVIRONMENT — apply a locale preset → relaunch + localization; toggle Dark Mode + Dynamic Type (instant, existing section); set a city preset → Maps moves + timezone changes; Clear location; clipboard round-trip both directions
    5. DEFAULTS — open the Defaults section: keys listed typed; edit one value → app reads the new value on next launch; add a bool key; delete it; re-edit the same key twice → identical plist state
    6. DOCS — read § App Actions in docs/system-architecture.md against the running app — services, captions, and both platform limits match
  </how-to-verify>
  <resume-signal>Reply "approved" to close phase 3 (proceed to /gsd-verify-work), or describe the failing group → gap-closure replan (do not patch past the gate).</resume-signal>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| Whole-phase review boundary | This plan re-verifies every boundary shipped in plans 01-04 (subprocess seam, device-state mutation, pasteboard transfer, preference reads/writes, DerivedData enumeration) at the gate rather than introducing new ones |
| Docs describing the attack surface | The new architecture section documents mutation and data-access surfaces |

## STRIDE Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation Plan |
|-----------|----------|-----------|----------|-------------|-----------------|
| T-03-16 | Information Disclosure | Docs describing data-access surfaces (scanner reach, defaults values) | low | mitigate | Docs document the design (local-only scanning, key-name-only logging) without credential, path, or machine-specific detail beyond existing doc conventions |
| T-03-SC | Tampering | Package installs (phase-close audit) | high | mitigate | git diff --exit-code on Package.resolved across the entire phase (Task 2) — any SPM drift blocks the gate and forces replan; zero installs was every plan's T-03-SC posture |
</threat_model>

<verification>
- Task 1: docs symbol cross-check (automated grep over both docs for the eight core types).
- Task 2: full-suite xcodebuild run + Package.resolved diff + caption greps + gitnexus_detect_changes.
- Task 3: blocking manual smoke (six groups) on a live Simulator — the phase gate.
</verification>

<success_criteria>
- All 9 must_haves truths hold; all four ROADMAP success criteria are each proven live in the smoke.
- The five probe truths (idempotency, concurrency, empty, ordering, adjacency) verified at gate level — unit contracts plus observed live behavior.
- Docs updated to match landed reality including both platform limits; dependency pin byte-identical.
</success_criteria>

## Artifacts this phase produces

Created by THIS plan (new symbols): none (closure plan — docs content only, no new code symbols).

Modified: docs/system-architecture.md (+ App Actions section), docs/codebase-summary.md (+ plans 01-04 file/type inventory).

Verification artifacts recorded in the summary: full-suite output, Package.resolved diff result, gitnexus_detect_changes scope, six-group smoke record.

<output>
Create `.planning/phases/03-app-actions/03-05-SUMMARY.md` when done
</output>
