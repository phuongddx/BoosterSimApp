---
phase: 07-polish-distribution
plan: "06"
subsystem: docs
tags: [phase-gate, docs-truth-pass, readme, dependency-pin, package-resolved, regression-greps, gate-closure, halt]

requires:
  - phase: 07-polish-distribution (plans 01-05)
    provides: the five plan outputs this gate verifies — signing pipeline + notary runbook (07-01), Sparkle + tracked Package.resolved + release workflow (07-02), test coverage (07-03), privacy manifest + placeholder icon (07-04), Phase 6 view wiring (07-05)
provides:
  - Docs truth pass — README.md rewritten as as-shipped v1 front page (orphan block gone, Download & Updates section, both dependency exceptions named, placeholder-icon honesty); system-architecture.md at the 18-action/13-section reality with §Platform & System Integration + §Distribution; codebase-summary.md file map + totals refreshed with real wc -l
  - The phase's automated gate record — unit bundle 266/266, BoosterSimConnect scheme build, THE FIRST REAL git-level dependency-pin assertion (git diff --exit-code on the tracked Package.resolved), structural pin check {pulse 5.2.2, sparkle 2.9.6}, regression greps (SideTab 4, zero XCTest, zero stale team id)
  - The halt record: Task 3's blocking-human gate CANNOT be satisfied yet — both prerequisites are still open human gates from sibling plans (07-01 Task 3 notarization ticket; 07-02 Task 3 Sparkle EdDSA keypair), machine-verified open by this plan's pre-checks
affects: [REQ-roadmap-phase7-polish-distribution (closes only on Task 3 approval), verify-work, v1 milestone close, 07-01/07-02 gate resolution flow]

actuals:
  tokens: 8626    # chars/4 over the realized diff (34,507 diff chars, 3 files, 79 insertions + 40 deletions) — estimate said 20000
  tasks: 2        # Tasks 1-2 complete + committed; Task 3 halted at its blocking-human gate (both upstream credential gates still open)
  commits: 2      # 029a0b5 (docs truth pass) + this metadata commit

tech-stack:
  added: []
  patterns:
    - "Phase-gate truth loop, 4th use: docs claims ⇄ shipping source verified by grep both directions before committing (every documented symbol must exist in the artifact that ships it)"
    - "Real git-level pin gate: Package.resolved tracked → `git diff --exit-code` becomes a true assertion; structural JSON check names the exact expected pin set"

key-files:
  created:
    - .planning/phases/07-polish-distribution/07-06-phase-gate-closure-SUMMARY.md
  modified:
    - README.md
    - docs/system-architecture.md
    - docs/codebase-summary.md

key-decisions:
  - "README's Download & Updates section states the distribution design truthfully WITH its open half named: notarized/stapled DMG from GitHub Releases + Sparkle appcast, plus an explicit 'first public release pending the one-time notarization and signing-key setup' note — claiming a live release would be false while 07-01/07-02 Task 3 gates are open (plan transparency prohibition)"
  - "The onboarding UI suite is recorded as ENVIRONMENT-BLOCKED, not green and not failed: 3 attempts all died at runner init ('Timed out while enabling automation mode', XCTFuture 1000) with 0 tests executed; the suite itself was proven green by 07-03 at 04:35Z (1/1 passed). Recorded in .planning/WINDOWS.md; carried to the human gate"
  - "Halted at Task 3 (07-01/04-04 halt pattern): requirements stay open, plan counter NOT advanced — but this halt is doubly blocked, on 07-01 Task 3 AND 07-02 Task 3, both human-credential steps outside this session's reach"

patterns-established:
  - "Doubly-blocked gate closure: execute every machine-checkable criterion, machine-verify the open human gates' absence (stapler/keychain/notarytool pre-checks), then halt naming each upstream prerequisite explicitly"

requirements-completed: []   # REQ-roadmap-phase7-polish-distribution stays open — Task 3's two credential confirmations are the close condition

coverage:
  - id: D1
    description: "Docs truth pass: README marketing rewrite (orphan block deleted, four views folded into App Actions, Sparkle dependency row + both named exceptions, Download & Updates, placeholder-icon provenance, refreshed counts) + system-architecture 18/13 + Platform/Distribution sections + codebase-summary refresh"
    requirement: REQ-roadmap-phase7-polish-distribution
    verification:
      - kind: other
        ref: "plan verify loop run verbatim: TRUTH-PASS-OK (! grep 'not yet surfaced' README && Sparkle+notarized in README && Sparkle+build-release in system-architecture && 4 view mounts in ActionsTabView.swift && no '9 sections'/'14 searchable' anywhere)"
        status: pass
      - kind: other
        ref: "both-directions symbol check: SPUStandardUpdaterController/StatusBarSectionView/BuildStatsSectionView/AXTreeView/CameraView/PrivacyInfo/build-release/Sparkle each present in the claiming docs AND the shipping source/artifact"
        status: pass
    human_judgment: false
  - id: D2
    description: "Automated phase gate: unit bundle + both schemes + FIRST REAL git-level pin assertion + structural pins + regression greps"
    requirement: REQ-roadmap-phase7-polish-distribution
    verification:
      - kind: unit
        ref: "xcodebuild test -only-testing:BoosterSimAppTests (chain, proven command): ** TEST SUCCEEDED **; xcresult Test-BoosterSimApp-2026.09.01_12-26-45: Passed, 266/266"
        status: pass
      - kind: other
        ref: "BoosterSimConnect scheme build (generic/platform=iOS Simulator): ** BUILD SUCCEEDED ** exit 0; BoosterSimApp scheme built green by the test invocation"
        status: pass
      - kind: other
        ref: "git diff --exit-code Package.resolved → exit 0 (first REAL git-level assertion — file tracked since 07-02; the Phases 2-5 vacuous-check gap closed) + python3 pins assert == {'pulse':'5.2.2','sparkle':'2.9.6'}"
        status: pass
      - kind: other
        ref: "regression greps: SideTab 'case [a-z]' count == 4; zero 'import XCTest' under BoosterSimAppTests; zero EQ8B89SPCX in pbxproj AND repo-wide (source tree)"
        status: pass
      - kind: automated_ui
        ref: "OnboardingFlowUITests — ENVIRONMENT-BLOCKED at gate time: 3 attempts, all 'test runner failed to initialize (Timed out while enabling automation mode)', 0 tests executed; suite proven green by 07-03 (04:35Z, 1/1). Recorded in WINDOWS.md, carried to human gate"
        status: unknown
    human_judgment: true
    rationale: "The UI-suite leg could not execute on this machine at gate time (XCTest automation-mode infrastructure, not a test defect); a human at the console re-runs it — and the unit/pin/grep legs, while machine-green, close a phase whose acceptance is judgment-gated per the plan's transparency prohibition."
  - id: D3
    description: "Narrow human gate: confirm the real notarization ticket (07-01 Task 3) and the Sparkle EdDSA keypair (07-02 Task 3), disposition all 07-01…07-05 flagged assumptions, approve phase close"
    requirement: REQ-roadmap-phase7-polish-distribution
    verification: []
    human_judgment: true
    rationale: "Machine pre-checks verified BOTH gates still OPEN: stapler validate → 'does not have a ticket stapled' (exit 65); SUPublicEDKey empty in SparkleInfo.plist and in the last local build's Info.plist; security find-generic-password -s https://sparkle-project.org → not found; notarytool history → 'No Keychain password item found for profile: booster-notary'. The ticket and the keypair are human-owned credentials a machine cannot originate (T-07-17); both sibling plans 07-01 and 07-02 are themselves halted at these gates."
duration: 17min to halt
completed: 2026-09-01
status: halted
---

# Phase 7 Plan 06: Phase Gate Closure Summary

**Docs truth pass landed (README as-shipped front page + 18/13 architecture reality + refreshed file map) and every machine-checkable gate criterion is green — including the first REAL git-level dependency-pin assertion — but Task 3's human gate is doubly blocked: 07-01's notarization ticket and 07-02's Sparkle EdDSA key are both still pending human action, machine-verified open**

**STATUS: HALTED at `checkpoint:human-verify gate="blocking-human"` — Task 3 awaits TWO upstream human gates resolving first: 07-01 Task 3 (real notarization ticket — `xcrun notarytool store-credentials booster-notary` + submit + staple) and 07-02 Task 3 (Sparkle EdDSA keypair — `generate_keys` + paste `SUPublicEDKey` into SparkleInfo.plist). Requirements stay open until the gate resolves (the 07-01/07-02/04-04 halt pattern).**

## Performance

- **Duration:** 17 min to halt (started 2026-09-01T05:19:56Z, halted 2026-09-01T05:37:04Z)
- **Tasks:** 2 of 3 complete (Task 1 ✅ committed, Task 2 ✅ gate recorded, Task 3 halted at its blocking-human gate — not attempted, per plan AND per machine-verified open prerequisites)
- **Files modified:** 3 (README.md, docs/system-architecture.md, docs/codebase-summary.md)

## Task 1 — Docs truth pass (commit `029a0b5`)

**README.md** — the "Built, not yet surfaced in the tabbed panel" block is DELETED; Status Bar Control, Build Stats, AX Inspector, and Camera Toggle fold into the App Actions feature list ("18 actions across 13 sections" searchable); a **Download & Updates** section states the distribution story (notarized stapled DMG on GitHub Releases, Check for Updates… via Sparkle, appcast URL, `scripts/build-release.sh`) with an HONEST open-half note — "first public release is pending the one-time notarization and signing-key setup" (claiming a live release would be false while the credential gates are open); the Dependencies table gains the **Sparkle 2.9.6 row (app target only — auto-update)** and the policy sentence names **both** exceptions (Pulse/PulseProxy + Sparkle); icon provenance stated exactly as 07-04 shipped it (scripted placeholder, amber `#E8720C` + white bolt, all 10 sizes, pending real design); counts refreshed via wc (128 Swift files ~16,129 LOC app, 6/772 Connect, 32 test files ~4,296 LOC); `SPUStandardUpdaterController` node added to the service tree. Permissions/non-sandbox prose untouched (still true).

**docs/system-architecture.md** — §App Actions corrected at all three stale sites to **18 actions / 13 sections** (the "9 sections"/"14 searchable" strings are gone repo-wide in this doc); MenuBarView description gains Check for Updates…; NEW **§Platform & System Integration** (the four Phase 6 views wired as Actions-catalog sections — statusBar after environment, camera/axTree/buildStats before reset; pid vs udid threading; probeSupport lifecycle; SideTab stays 4 cases) and NEW **§Distribution** (Developer ID + hardened runtime + notarize + staple + DMG via `scripts/build-release.sh`; Sparkle chain `SPUStandardUpdaterController` → menu item → `SUFeedURL`/`SUPublicEDKey` via SparkleInfo.plist; non-sandbox rationale; cross-link to deployment-guide.md); Sparkle exception row added to Key Design Decisions.

**docs/codebase-summary.md** — Project Stats updated (178 Swift files ~21,790 LOC; dependencies line names BOTH exceptions; test targets line updated); phase 7 files added with real wc -l (`scripts/build-release.sh` 170, `scripts/generate-placeholder-icon.swift` 182, `PrivacyInfo.xcprivacy` 32, `release.yml` 133, `ExportOptions.plist` 12, `SparkleInfo.plist` 18, AppIcon 10-PNG set, `PositionCalculatorTests` 244 / `WindowEnumeratorTests` 90 / `AppSettingsTests` 118 / `OnboardingFlowUITests` 82); stale LOCs refreshed (AppDelegate 152, AppAction 140, ActionsTabView 131 "13-section", AppActionService 957, CameraView 108, MenuBarView 63, onboarding views, AppActionCatalogTests 139, tracker/controller largest-files rows); 4 new Actions-tab section rows (Complete (Phase 7)); "Standalone views" block replaced by the wired statement; 4 rows added to Key Files by Role.

**Verify (plan loop, verbatim): `TRUTH-PASS-OK`** — plus the both-directions symbol check: SPUStandardUpdaterController, StatusBarSectionView, BuildStatsSectionView, AXTreeView, CameraView, PrivacyInfo, build-release, Sparkle each exist in the claiming docs AND in the shipping source/artifact (AppDelegate, ActionsTabView mount table, SparkleInfo.plist, scripts/build-release.sh, PrivacyInfo.xcprivacy).

## Task 2 — Automated phase gate (files: none; record below)

| # | Check | Result |
|---|---|---|
| 1 | Unit bundle (proven command, chain step 1) | **TEST SUCCEEDED**, exit 0 — xcresult `Test-BoosterSimApp-2026.09.01_12-26-45`: **Passed, 266/266** |
| 2 | Onboarding UI suite (`OnboardingFlowUITests`) | **ENVIRONMENT-BLOCKED** — 3 attempts (chain run + the plan's one allowed re-run + one Rule-3 retry), all exit 65 with `test runner failed to initialize for UI testing (Underlying Error: Timed out while enabling automation mode)` — **0 tests executed every time**; xcresults `…_12-26-59` and `/tmp/onboarding-ui{,2}.xcresult` all show the runner-init failure, no test-level failure. Suite proven green by 07-03 at 04:35Z (1/1 passed). Recorded in `.planning/WINDOWS.md`; needs a console-side re-run at the human gate |
| 3 | BoosterSimConnect scheme build (`generic/platform=iOS Simulator`) | **BUILD SUCCEEDED**, exit 0 |
| 4 | BoosterSimApp scheme | built green by the test invocation (chain step 1) |
| 5 | **First REAL git-level pin** — `git diff --exit-code Package.resolved` | **exit 0** — the assertion is non-vacuous for the first time (file tracked since 07-02); the Phase 2–5 infra gap (STATE.md `[infra]` blocker) closes here |
| 6 | Structural pin check | `{'pulse': '5.2.2', 'sparkle': '2.9.6'}` — exactly 2 pins ✓ |
| 7 | SideTab regression | `grep -c 'case [a-z]' SideTab.swift` == **4** ✓ (REQ-fr-13 unregressed) |
| 8 | Zero-XCTest rule | no `import XCTest` under BoosterSimAppTests/ ✓ |
| 9 | Stale team id | zero `EQ8B89SPCX` in pbxproj ✓ and repo-wide (source tree, excluding .planning/build) ✓ |

**Gate verdict: every check green EXCEPT the UI-suite leg, which is environment-blocked (not failed)** — the chain therefore never printed `GATE-GREEN`; per the plan's investigate-not-commit rule the UI failure was investigated to root cause (below), not papered over.

## Task 3 — HALTED: doubly-blocked human gate

Task 3 is `checkpoint:human-verify gate="blocking-human"` and was **not** attempted — its two confirmation subjects do not exist yet. Machine pre-checks (run read-only, this session):

| Pre-check | Output | Meaning |
|---|---|---|
| `xcrun stapler validate build/export/BoosterSimApp.app` | "does not have a ticket stapled to it" (exit 65) | **07-01 Task 3 open** — no notarization ticket exists |
| `PlistBuddy Print :SUPublicEDKey` (SparkleInfo.plist + last local build's Info.plist) | empty string | **07-02 Task 3 open** — EdDSA public key not wired |
| `security find-generic-password -s "https://sparkle-project.org"` | item could not be found | generate_keys not run on this machine |
| `xcrun notarytool history --keychain-profile booster-notary` | "No Keychain password item found for profile: booster-notary" | store-credentials not run |
| `SUFeedURL` (built Info.plist) | `https://github.com/phuongddx/BoosterSimApp/releases/latest/download/appcast.xml` | 07-02 Task 2 wiring intact |

**Blocked by (explicit prerequisites, in order):**
1. **07-01 Task 3 — real notarization ticket** (sibling plan halted at this exact gate): app-specific password → `xcrun notarytool store-credentials booster-notary --apple-id <Apple ID> --team-id K2TYLYAWMK --password <pw>` → `scripts/build-release.sh` → Accepted ticket. Runbook: docs/deployment-guide.md § "One-time credential setup".
2. **07-02 Task 3 — Sparkle EdDSA keypair** (sibling plan halted at this exact gate): run Sparkle's `generate_keys`, paste the printed public key into `SparkleInfo.plist`'s `SUPublicEDKey` (the INFOPLIST_FILE mechanism — NOT an INFOPLIST_KEY setting, 07-02 deviation 1). Runbook: docs/deployment-guide.md § "CI release secrets".

After both resolve: re-run this plan's Task 2 UI-suite leg console-side, run Task 3's confirmation (ticket id + Accepted status; SUPublicEDKey non-empty + keychain entry), disposition the flagged assumptions below with the user, and close on approval.

## Flagged-assumption disposition table (prepared for the human gate)

| Plan | Flag | Disposition |
|---|---|---|
| 07-01 A1 | export with automatic signing + developer-id method, no entitlements | **pass** (RESOLVED live: EXPORT SUCCEEDED, Developer-ID re-sign verified) |
| 07-01 A2 | K2TYLYAWMK private key accessible non-interactively | **pass** (RESOLVED live: unattended archive + export) |
| 07-01 Task 3 | real notarization ticket | **OPEN — human gate #1** (machine-verified: no staple, no notary profile) |
| 07-02 A1 | INFOPLIST_KEY_* prefixes flow into generated plist | **pass with deviation** (DISPROVEN live; SU keys live in SparkleInfo.plist via INFOPLIST_FILE merge — SUFeedURL proven in the built plist) |
| 07-02 A2 / 07-06 flag | release.yml not yet exercised on a real tag push | **known-gap, post-phase step** (needs the six GitHub secrets from the runbook + a real `v*` tag; the workflow itself is machine-verified: valid YAML, correct job graph, secrets-only credentials) |
| 07-02 Task 3 | Sparkle EdDSA keypair | **OPEN — human gate #2** (machine-verified: SUPublicEDKey empty, no keychain entry) |
| 07-03 flag | documented post-test exit-65 UI-test env flake | **known-gap, surfaced** — recurred at gate time in a stronger form (runner-init automation-mode timeout, 0 tests executed × 3 attempts; suite green at 04:35Z); WINDOWS.md entry #9 |
| 07-04 | icon as placeholder (Path B); privacy manifest accuracy | **known-gap accepted** (placeholder labeled as placeholder in README — never claimed as finished art) / **pass** (CA92.1 + FileTimestamp codes verified against live docs) |
| 07-05 D4 | visual reachability of the four sections on a live Simulator | **surfaced-to-user at the gate** (mechanical wiring grep+unit-proven; 07-06 Task 3 deliberately carries no six-group visual smoke — the user confirms reachability as part of approval) |

## Task Commits

1. **Task 1: docs truth pass** — `029a0b5` (docs: README + system-architecture + codebase-summary; TRUTH-PASS-OK)
2. **Task 2: no commit** — gate record only (plan `files: none`; this SUMMARY is the record)
3. **Task 3: no commit** — halted at the blocking-human gate (no files)

**Plan metadata:** this commit (docs: phase-gate closure halted at doubly-blocked human gate).

## Files Created/Modified

- `README.md` — as-shipped front page (see Task 1)
- `docs/system-architecture.md` — 18/13 reality + §Platform & System Integration + §Distribution
- `docs/codebase-summary.md` — phase 7 file map + refreshed totals
- `.planning/WINDOWS.md` — unrun-verify entry appended (UI suite environment-block)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] UI suite runner-init failure — investigated to root cause, not retried past the attempt limit**
- **Found during:** Task 2 (chain step 2)
- **Issue:** `OnboardingFlowUITests` failed with exit 65; the plan's one allowed re-run (plus one Rule-3 retry = 3 attempts total) all failed identically BEFORE any test ran: `The test runner failed to initialize for UI testing (Underlying Error: Timed out while enabling automation mode)` (XCTFuture Code 1000)
- **Fix (investigation, no code change):** unified-log diagnosis — `testmanagerd` requested automation mode (12:31:05) and timed out 60 s later; `ibtoold` logged "Automation Mode has been disabled, existing connections will be invalidated"; the machine-level state file `/var/db/com.apple.dt.automationmode/automation-enabled` is absent. This is macOS XCTest automation infrastructure, not a defect in the app or the test (0 tests executed; suite green at 04:35Z). Attempt limit (3) reached → recorded as environment-blocked in the gate record + WINDOWS.md, carried to the human gate for a console-side re-run
- **Files modified:** none (verification environment)
- **Verification:** xcresult bundles for all 3 attempts show runner-init failure with `passed: 0, failed: 1 (runner)`, no test-level failures
- **Committed in:** n/a (record in this SUMMARY)

**2. [Rule 1 - Truth] Task 1 edits initially dropped README's true BoosterSimConnect release-surface sentence; CameraView tree indent off by one level in codebase-summary**
- **Found during:** Task 1 diff review (pre-commit)
- **Issue:** the Dependencies rewrite dropped "`BoosterSimConnect` is a DEBUG, simulator-only framework … no cross-process surface" (still true); one tree line had the wrong nesting depth; one tree edit briefly clobbered the BlockRule entry
- **Fix:** all three restored/corrected before the Task 1 commit; full diff reviewed line-by-line
- **Files modified:** README.md, docs/codebase-summary.md
- **Verification:** `git show 029a0b5` diff reviewed; TRUTH-PASS-OK re-run after fixes
- **Committed in:** 029a0b5

---

**Total deviations:** 2 auto-fixed (1 Rule-3 environment investigation, 1 Rule-1 truth fix caught in review)
**Impact on plan:** No scope creep; the UI-suite gap is recorded honestly per the plan's own transparency prohibition rather than claimed green.

## Issues Encountered

- UI-test automation-mode timeout (deviation 1) — the only red in the gate; everything else green on first run
- No keychain prompts, no permission errors, no package drift during the whole gate (the git-level pin diff stayed clean across all build/test invocations)

## Known Stubs

None introduced by this plan. Pre-existing, honestly-tracked: `SUPublicEDKey` empty (07-02 Task 3 gate — WINDOWS.md #8), AppIcon placeholder (07-04 — WINDOWS.md #7), UI suite unrun-verify (WINDOWS.md #9, this plan).

## User Setup Required

**Two human-credential steps, both outside this session (they are the halt's prerequisites):**
1. Notarization: app-specific password at appleid.apple.com → `xcrun notarytool store-credentials booster-notary --apple-id <Apple ID> --team-id K2TYLYAWMK --password <app-specific password>` (interactive) → `scripts/build-release.sh` — full steps in docs/deployment-guide.md § "One-time credential setup"
2. Sparkle EdDSA: run Sparkle's `generate_keys` (SPM checkout already on this machine) → paste the printed public key into `SparkleInfo.plist`'s `SUPublicEDKey` — full steps in docs/deployment-guide.md § "CI release secrets"

## Next Phase Readiness


- Phase 7 is machine-green everywhere it can be: docs truthful (TRUTH-PASS-OK), 266/266 units, both schemes, real git-level pin {pulse 5.2.2, sparkle 2.9.6}, zero regressions
- REQ-roadmap-phase7-polish-distribution closes ONLY when 07-01 Task 3 + 07-02 Task 3 resolve and the user approves this plan's Task 3 gate — then the v1 milestone ends
- Post-phase known gaps (accepted follow-ups, never smoothed): release.yml's first real tag-push run (needs the six GitHub secrets); real icon art replacing the placeholder; optional throttle-rescale and other v2 candidates per STATE.md

---
*Phase: 07-polish-distribution*
*Halted at doubly-blocked human gate (07-01 ticket + 07-02 EdDSA key): 2026-09-01*

## Self-Check: PASSED

README.md, docs/system-architecture.md, docs/codebase-summary.md modified and committed (029a0b5 present on main); this SUMMARY exists on disk; Task 1 verify re-run after all fixes: TRUTH-PASS-OK; Task 2 record re-verified from xcresults (266/266 Passed) and the pin/grep checks re-run individually green; Task 3 machine pre-checks confirm both upstream gates open. Task 3 intentionally not executed — halted at its blocking-human gate.
