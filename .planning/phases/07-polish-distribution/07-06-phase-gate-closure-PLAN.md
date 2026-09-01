---
phase: 07-polish-distribution
plan: 06
type: execute
wave: 3
depends_on: ["07-01", "07-02", "07-03", "07-04", "07-05"]
files_modified:
  - README.md
  - docs/system-architecture.md
  - docs/codebase-summary.md
autonomous: false
requirements:
  - REQ-roadmap-phase7-polish-distribution
estimate:
  tokens: 20000
  raw_tokens: 20000
  tasks: 3
  confidence: low

must_haves:
  truths:
    - "Docs tell the as-shipped truth: README.md is rewritten as marketing/front-page polish (the 'Built, not yet surfaced' section is gone — the four views ship in the Actions tab; Sparkle appears in the Dependencies table as the second named exception; a Releases/Download section points at the notarized DMG + appcast; the icon's provenance is stated honestly, placeholder labeled as placeholder), and system-architecture.md / codebase-summary.md match the 13-section Actions tab, the Sparkle wiring, and the real file map"
    - "The full unit bundle passes (exit 0) AND the onboarding UI suite passes, and the dependency pin is proven at the GIT level for the first time: Package.resolved is tracked, `git diff --exit-code` is a real assertion, and the pins are exactly Pulse 5.2.2 + Sparkle 2.9.6"
    - "The two human-credential artifacts are CONFIRMED before the phase closes: a real notarization ticket (Accepted, recorded in 07-01's SUMMARY) and the Sparkle EdDSA keypair (SUPublicEDKey wired + keychain entry) — the narrow blocking human gate; no broad visual smoke (this phase's criteria are build/release/test mechanics, already machine-verified)"
    - "Every flagged assumption from plans 07-01…07-05 is dispositioned pass / known-gap / surfaced-to-user in the gate record before REQ-roadmap-phase7-polish-distribution closes"
  artifacts:
    - README.md
    - docs/system-architecture.md
    - docs/codebase-summary.md
  key_links:
    - "As-shipped source symbols → docs sections (the proven grep truth-gate from Phases 2-4 closures) — the doc-truth link the next reader onboards from"
    - "07-01/07-02 checkpoint records (ticket id, EdDSA public key) → Task 3's confirmation → SUMMARY → requirement close (requirements stay open at halt, close on approval — the Phase 3/4 gate pattern)"
    - "Tracked Package.resolved → git-level pin assertion — the infra gap STATE.md has carried since Phase 2 finally closed"
  prohibitions:
    - requirement_id: REQ-roadmap-phase7-polish-distribution
      category: transparency
      status: unverified
      flagged: true
      verification: judgment
      statement: "MUST NOT close the phase on suite-green alone — the two credential-bound proofs (real notarization ticket, real EdDSA key) are the close condition and the gate record must carry them; any known gap (e.g. release workflow not yet exercised on a real tag push, icon shipped as placeholder) is recorded honestly in the SUMMARY as follow-up state, never smoothed over"
  flagged_assumptions:
    - "release.yml's first real tag-push run has NOT happened by gate time (needs a real tag + GitHub secrets configured from the Task-2 runbook) — the gate records it as a known post-phase step, not a phase failure (criterion 2's acceptance is the shipped update chain + workflow, which are machine-verified)"
---

<objective>
Close Phase 7 the way Phases 2/3/4 closed — docs truth pass, full-bundle + pin gate, human gate — but with a NARROW human scope: this phase's criteria are build/release/test mechanics, not TCC-gated visual behavior, so the blocking gate confirms exactly the two things a machine cannot originate (the real notarization ticket and the Sparkle EdDSA key) plus the flagged-assumption dispositions.

Task 1 is the docs truth pass (README marketing rewrite + architecture/summary refresh, grep-gated). Task 2 is the automated phase gate: full unit bundle + onboarding UI suite + the first-ever REAL git-level dependency-pin assertion (Package.resolved tracked since 07-02) + regression greps (4 tabs, no XCTest). Task 3 is the narrow blocking-human confirmation.

Purpose: REQ-roadmap-phase7-polish-distribution closes on approval; the v1 milestone ends.
Output: truthful docs, green gates, one approved narrow gate record.
</objective>

<execution_context>
@~/.claude/gsd-core/workflows/execute-plan.md
@~/.claude/gsd-core/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/ROADMAP.md
@.planning/STATE.md
@.planning/phases/07-polish-distribution/07-CONTEXT.md
@.planning/phases/07-polish-distribution/07-RESEARCH.md
@.planning/phases/07-polish-distribution/07-PATTERNS.md
@.planning/phases/07-polish-distribution/07-01-signing-notarization-pipeline-SUMMARY.md
@.planning/phases/07-polish-distribution/07-02-sparkle-autoupdate-release-workflow-SUMMARY.md
@.planning/phases/07-polish-distribution/07-03-test-coverage-SUMMARY.md
@.planning/phases/07-polish-distribution/07-04-privacy-manifest-app-icon-SUMMARY.md
@.planning/phases/07-polish-distribution/07-05-phase6-view-wiring-SUMMARY.md
@README.md
@docs/system-architecture.md
@docs/codebase-summary.md
@docs/deployment-guide.md
</context>

<tasks>

<task type="auto">
  <name>Task 1: Docs truth pass — README marketing rewrite + architecture/summary refresh</name>
  <files>
    README.md,
    docs/system-architecture.md,
    docs/codebase-summary.md
  </files>
  <read_first>
    - README.md in full — the "Built, not yet surfaced in the tabbed panel" block (:52-59) this pass deletes, the Dependencies table/prose (:105-113), the feature lists, the architecture-notes counts (:119)
    - the five 07-* SUMMARYs — the as-built truth source (exact section names, key names, counts, which icon path shipped)
    - docs/system-architecture.md §App Actions ("14 searchable actions across 9 sections" — now 18/13) and the section list — where a Platform-integration + Distribution update belongs
    - docs/codebase-summary.md — the file-map/LOC format to refresh
    - .planning/phases/04-design-tools/04-04-phase-gate-closure-PLAN.md Task 1 — the proven truth-gate grep-loop shape
  </read_first>
  <action>
    README.md (marketing polish, drawn from the now-complete architecture docs):
    - Delete the "Built, not yet surfaced" block; fold Status Bar Control, Camera Toggle, Build Stats, and AX Inspector into the App Actions feature list (they ship as searchable Actions-tab sections).
    - Dependencies: add the Sparkle row (2.9.6, linked into BoosterSimApp only, auto-update) and extend the policy sentence to name BOTH exceptions (Pulse/PulseProxy + Sparkle) — mirror of the PROJECT.md edit from 07-02.
    - Add a "Download & Updates" section: notarized DMG from GitHub Releases, Gatekeeper-friendly (stapled), Check for Updates… menu item, appcast URL.
    - State icon provenance exactly as 07-04 shipped it — if placeholder, say "placeholder icon pending real design".
    - Refresh stale counts (file/LOC figures via wc, tab-section count) and keep the existing Permissions/non-sandbox prose (still true).
    docs/system-architecture.md: update §App Actions to the 18-action/13-section reality; add a short §Platform & System Integration note (the four Phase 6 sections wired via the Actions catalog, services already injected by SideWindowController); add a short §Distribution subsection (Developer ID + hardened runtime + notarization + staple + DMG via scripts/build-release.sh, Sparkle auto-update, non-sandbox rationale) cross-linking deployment-guide.md.
    docs/codebase-summary.md: add the phase's new files (ExportOptions.plist, scripts/build-release.sh, scripts/generate-placeholder-icon.swift, PrivacyInfo.xcprivacy, 3 unit suites + 1 UI suite, release.yml, icon PNGs) with real wc -l, and refresh totals.
    Truth-gate: the grep loop — every symbol this pass documents (SPUStandardUpdaterController, StatusBarSectionView, AXTreeView, CameraView, BuildStatsSectionView, PrivacyInfo, build-release, Sparkle) must exist in BOTH the docs that claim it and the source/artifact that ships it.
  </action>
  <verify>
    <automated>! grep -q 'not yet surfaced' README.md && grep -q 'Sparkle' README.md && grep -q 'notarized' README.md && grep -q 'Sparkle' docs/system-architecture.md && grep -q 'build-release' docs/system-architecture.md && for s in StatusBarSectionView BuildStatsSectionView AXTreeView CameraView; do grep -q "$s" BoosterSimApp/Views/SideWindow/tabs/ActionsTabView.swift || exit 1; done && ! grep -q 'across 9 sections' docs/system-architecture.md && echo TRUTH-PASS-OK</automated>
    <fails_when>the orphaned-views block survives in README, Sparkle/notarization/distribution statements are missing from docs, any claimed view is absent from the actual mount table, or the stale 9-section count remains</fails_when>
  </verify>
  <done>README is honest front-page marketing for the finished v1 (four tabs, all features reachable, distribution story, two named dependency exceptions); architecture/summary docs match shipped source.</done>
</task>

<task type="auto">
  <name>Task 2: Automated phase gate — full bundles + first real git-level pin + regression greps</name>
  <files>none</files>
  <read_first>
    - .planning/STATE.md Phase 5 05-04 decision — the proven unit-bundle command and the exit-65 pre-existing flake note
    - BoosterSimApp.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved — must show exactly two pins after 07-02
  </read_first>
  <action>
    Run and record: (1) the full unit bundle with the proven command; (2) the onboarding UI suite (OnboardingFlowUITests — flake allowance per 07-03's flagged assumption: judge the per-test summary, one re-run allowed, record occurrences); (3) the dependency pin — Package.resolved is TRACKED now, so run `git diff --exit-code` on it (a REAL assertion for the first time — the vacuous-check infra gap from Phases 2-5 closes here) plus a structural check that pins == Pulse 5.2.2 + Sparkle 2.9.6; (4) regression greps — SideTab exactly 4 cases, zero `import XCTest` under BoosterSimAppTests, zero EQ8B89SPCX anywhere; (5) both schemes build (BoosterSimApp + BoosterSimConnect, the Phase 5 lesson). Record every output hash/exit code in the gate record. Any red is investigate-not-commit.
  </action>
  <verify>
    <automated>xcodebuild -project BoosterSimApp.xcodeproj -scheme BoosterSimApp -destination 'platform=macOS' test -only-testing:BoosterSimAppTests -skip-testing:BoosterSimAppUITests -parallel-testing-enabled NO 2>&1 | tail -3 && git diff --exit-code BoosterSimApp.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved && python3 -c "import json;p=json.load(open('BoosterSimApp.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved'));m={x['identity']:x['state'].get('version') for x in p['pins']};assert m=={'pulse':'5.2.2','sparkle':'2.9.6'},m" && grep -c 'case ' BoosterSimApp/Views/SideWindow/SideTab.swift | grep -qx 4 && ! grep -rq 'import XCTest' BoosterSimAppTests --include='*.swift' && ! grep -rq 'EQ8B89SPCX' BoosterSimApp.xcodeproj/project.pbxproj && echo GATE-GREEN</automated>
    <fails_when>the unit bundle fails, the pin file drifted (git diff non-empty), pins ≠ Pulse 5.2.2 + Sparkle 2.9.6, SideTab ≠ 4 cases, any XCTest import, or the stale team id resurfaces</fails_when>
  </verify>
  <done>Every machine-checkable criterion of the phase is green and recorded: unit bundle, UI suite, real git-level pin, locked-requirement greps, both schemes.</done>
</task>

<task type="checkpoint:human-verify" gate="blocking-human">
  <name>Task 3: Narrow phase gate — confirm the notarization ticket + EdDSA key, disposition assumptions, approve close</name>
  <files>none</files>
  <read_first>
    - 07-01 SUMMARY (ticket id, stapler/spctl outputs) and 07-02 SUMMARY (SUPublicEDKey, keychain confirmation, CI-secrets state)
    - flagged_assumptions blocks of 07-01…07-05 — the items this gate dispositions
    - .planning/phases/04-design-tools/04-04-phase-gate-closure-PLAN.md Task 2 — the disposition-completeness discipline (every flag answered pass / known-gap / surfaced-to-user)
  </read_first>
  <action>
    Machine-check what can be machine-checked first, then ask the user to confirm the two credential-bound artifacts:
    - `xcrun stapler validate build/export/BoosterSimApp.app` (re-validate the stapled artifact if the export still exists; otherwise rely on the 07-01 SUMMARY record);
    - SUPublicEDKey non-empty in the built app's Info.plist (re-run 07-02 Task 3's dump);
    - `security find-generic-password -s "https://sparkle-project.org"` (tolerant of Sparkle's naming; the user's confirmation covers ambiguity).
    Then present the narrow gate to the user: (a) confirm the notarization ticket recorded in 07-01 is real and theirs (Accepted status, their team); (b) confirm the Sparkle EdDSA keypair exists on this machine and SUPublicEDKey matches generate_keys' output; (c) review the flagged-assumption disposition table — including the two known-gap candidates this phase honestly carries (release.yml not yet exercised on a real tag push; icon placeholder status if Path B shipped) — and either accept them as recorded follow-ups or name what must be fixed inside the phase. NO six-group visual smoke: every visual surface here was already covered by Phase 6's shipped views and this phase's mechanical wiring greps.
  </action>
  <verify>
    <automated>PUB=$(/usr/libexec/PlistBuddy -c 'Print :SUPublicEDKey' "$(ls -d build/*/Build/Products/*/BoosterSimApp.app 2>/dev/null | tail -1)/Contents/Info.plist" 2>/dev/null) && test ${#PUB} -gt 20 && echo "SUPublicEDKey present (${#PUB} chars)" || echo "WARN: no local build with SUPublicEDKey — rely on 07-02 SUMMARY record"</automated>
    <fails_when>the user reports the ticket or key is absent/fabricated — either blocks closure and reopens the corresponding plan</fails_when>
    <human-check>The two credential artifacts are real: (1) a notarization ticket with Accepted status for BoosterSimApp under team K2TYLYAWMK (ticket id visible in 07-01's record or notarytool history), and (2) the Sparkle EdDSA keypair on this machine with its public key wired as SUPublicEDKey — plus acceptance of the flagged-assumption dispositions.</human-check>
  </verify>
  <acceptance_criteria>
    - Gate record carries: ticket id + Accepted status, SUPublicEDKey length/confirmation, per-flag dispositions for 07-01…07-05, the two known-gap follow-ups explicitly accepted
    - Task 2's GATE-GREEN output attached
    - Requirements stayed open at halt; REQ-roadmap-phase7-polish-distribution closes only on the user's approval (Phase 3/4 gate pattern)
  </acceptance_criteria>
  <what-built>Everything Phase 7 shipped, machine-verified in Tasks 1-2 (truthful docs, green bundles, real git-level pin, regression greps) — this gate adds the two human-originated proofs: the notarization ticket and the EdDSA keypair, plus the flagged-assumption dispositions that close the phase honestly.</what-built>
  <how-to-verify>
    1. Machine pre-checks: `xcrun stapler validate build/export/BoosterSimApp.app` (or the 07-01 SUMMARY record), SUPublicEDKey dump from the built Info.plist, `security find-generic-password -s "https://sparkle-project.org"`
    2. Human confirms: the notarytool ticket in the 07-01 record is real, Accepted, and theirs (team K2TYLYAWMK)
    3. Human confirms: the Sparkle EdDSA keypair exists on this machine and SUPublicEDKey matches generate_keys' output
    4. Review the flagged-assumption disposition table together — accept the recorded known gaps (release.yml first-run pending; icon placeholder if Path B) or name what must be fixed in-phase
    5. Reply approved / name the failure
  </how-to-verify>
  <resume-signal>Reply "approved" to close Phase 7 (REQ-roadmap-phase7-polish-distribution closes on approval), or name the failing artifact/assumption — a missing ticket or key reopens 07-01/07-02 work inside this phase.</resume-signal>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| Docs ↔ source | The truth-gate grep loop: every documented symbol must exist in shipped source |
| Credential artifacts ↔ phase claim | The ticket and EdDSA key are the only claims in this phase a machine cannot originate — the human confirmation is their proof |
| Tracked pin file ↔ dependency graph | First real git-level assertion that the shipped dependency set is exactly Pulse + Sparkle |

## STRIDE Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation Plan |
|-----------|----------|-----------|----------|-------------|-----------------|
| T-07-17 | Repudiation | Phase closed on suite-green | high | mitigate | Narrow blocking-human gate confirms ticket + key + dispositions; requirements open at halt, close on approval; known gaps recorded, never smoothed |
| T-07-18 | Tampering | Dependency drift at gate time | medium | mitigate | Tracked Package.resolved + git diff --exit-code (now non-vacuous) + structural pin assert {pulse 5.2.2, sparkle 2.9.6} |
| T-07-19 | Repudiation (docs) | README overclaims | medium | mitigate | Truth-gate greps both directions; icon placeholder honesty; provenance statement must match 07-04's SUMMARY |
</threat_model>

<verification>
- Task 1: truth-gate grep loop green (orphan block gone, Sparkle/notarization present, mounts real, counts updated)
- Task 2: GATE-GREEN — unit bundle + UI suite + real pin assertion + regression greps + both schemes
- Task 3: narrow human confirmation recorded (ticket + key + dispositions)
- Phase close: on approval only
</verification>

<success_criteria>
- All five ROADMAP criteria TRUE and evidenced: signed/notarized/DMG + non-sandbox documented (C1), Sparkle update chain end-to-end (C2), named test coverage green (C3), privacy manifest + icon + README polish (C4), four Phase 6 views reachable (C5)
- Docs truthful, pin proven at git level for the first time, two credential artifacts human-confirmed
- REQ-roadmap-phase7-polish-distribution ready to close — v1 milestone complete
</success_criteria>

<output>
Create `.planning/phases/07-polish-distribution/07-06-phase-gate-closure-SUMMARY.md` when done
</output>
