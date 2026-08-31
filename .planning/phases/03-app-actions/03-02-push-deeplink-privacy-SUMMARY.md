---
phase: 03-app-actions
plan: 02
subsystem: app-actions
tags: [simctl, push, apns, privacy, tcc, deep-link, combine, swiftui]

# Dependency graph
requires:
  - phase: 03-app-actions (plan 01)
    provides: hardened SimCtlService seam (stdin parameter, serial queue), AppActionService facade + extend-the-seam recipe, AppPickerBar, ActionsTabView shell, AppLogger.actions
provides:
  - DeepLinkService migrated onto the SimCtlService seam — the app's last out-of-seam subprocess spawn deleted; async-exemption list shrinks to CaptureService alone
  - PrivacyPermission model — 12 verbatim simctl TCC service strings, grant/revoke/reset-all argv builders, no notifications case (D-01 locked by tests)
  - Privacy verbs on the facade — setPrivacy (per-app scoped), resetAllPrivacy (destructive confirm + booted-UDID refusal), openDeviceSettings (com.apple.Preferences launch)
  - PushPayload model — typed parse gate (empty/invalidJSON/notObject/missingAPS/invalidShape) + pure 4096-byte validate gate on JSONEncoder output, verbatim "Simulator Target Bundle" CodingKey, template presets, encodedByteCount helper
  - AppActionService.sendPush — parse → validate → encode → simctl [push, udid, bundle, -] over the stdin seam; verb+size+outcome logging only
  - PushNotificationSectionView + PrivacySectionView mounted in the Actions tab
  - Wave 0 suites: DeepLinkServiceTests (12) + PrivacyPermissionTests (7) + PushPayloadTests (12)
affects: [03-03 locale/location/clipboard, 03-04 defaults editor + action search, 03-05 docs + phase gate smoke]

actuals:
  tokens: 15205   # chars/4 over the realized diff (60,819 chars) — vs. 42,000 estimate (confidence was low)
  tasks: 2
  commits: 4      # TDD pairs, excluding the docs commit

tech-stack:
  added: []       # Apple frameworks only (REQ-nfr-03)
  patterns:
    - "Typed parse gate before any subprocess: JSONSerialization guards top-level shape so failures map to precise error cases, JSONDecoder decodes the strict struct"
    - "Exact-size boundary fixtures: encoded size grows 1:1 with alert length above the skeleton, so 4095/4096/4097 payloads are constructed deterministically"
    - "D-01 guided-grant control shape: honest caption + Settings launch verb + inline steps + Send-as-probe — never a state-toggling control"
    - "Pure validation/argv statics on the owning service (validationMessage, openURLCommand) so rejection-before-subprocess is unit-provable"

key-files:
  created:
    - BoosterSimApp/Models/PrivacyPermission.swift
    - BoosterSimApp/Models/PushPayload.swift
    - BoosterSimApp/Views/SideWindow/actions/PrivacySectionView.swift
    - BoosterSimApp/Views/SideWindow/actions/PushNotificationSectionView.swift
    - BoosterSimAppTests/DeepLinkServiceTests.swift
    - BoosterSimAppTests/PrivacyPermissionTests.swift
    - BoosterSimAppTests/PushPayloadTests.swift
  modified:
    - BoosterSimApp/Services/DeepLinkService.swift
    - BoosterSimApp/Services/AppActionService.swift
    - BoosterSimApp/Views/SideWindow/tabs/ActionsTabView.swift
    - BoosterSimApp/App/AppDelegate.swift
    - BoosterSimApp/Views/SideWindow/SideWindowView.swift
    - .planning/codebase/CONVENTIONS.md

key-decisions:
  - "DeepLinkService keeps its exact published/parse/history contract but gains init(simCtl:defaults:) — injectable UserDefaults (default .standard) is the minimal seam the plan's own isolated-suite behavior bullet requires; production behavior is identical"
  - "addToHistory is internal, not private — the only public-history write path — so the persistence round-trip is testable without spawning a subprocess"
  - "openInSimulator failure captions now come from SimCtlError.localizedDescription ('simctl failed: <stderr>') instead of 'simctl exited with code N' — the plan's message-from-stderr instruction; success/validation messages are pinned unchanged"
  - "Privacy/push verbs publish dedicated privacyCaption / pushResult / isSendingPush instead of riding the AppActionOperation machine — the 03-01 tests pin that machine's transitions and single-hop verbs have no multi-step sequencing to guard"
  - "setPrivacy takes an optional trailing bundleID (default nil) appended after the pinned 4-token simctlArgs — the per-app TCC scoping the section promises; the model builder itself stays exactly [privacy, udid, grant|revoke, service]"
  - "PushActionResult lives beside PushPayload in Models/ (AppActionModels.swift is not in this plan's file list; ResetOutcome's co-location precedent)"
  - "Byte counter shows UTF-8 bytes of the editor text (PushPayload.encodedByteCount) — the live approximation; the authoritative gate re-encodes canonically on send"

patterns-established:
  - "Honest-cannot-do control: when a platform capability is absent (D-01 notifications), the UI states the limitation, links to where it IS doable, and offers the probe that verifies it — no decoy toggle"
  - "Boundary-exact size tests via skeleton-plus-padding payload construction"

requirements-completed: [REQ-fr-13]   # REQ-fr-13 itself already Complete in REQUIREMENTS.md from Phase 1 (tab shell); REQ-roadmap-phase3-app-actions stays open until the 03-05 phase gate (shared-ID pattern, same as 03-01)

coverage:
  - id: D1
    description: "Deep-link seam migration — parse/validation/argv behavior identical, rejection before any subprocess, history/favorites persistence round-trip (isolated suite, most-recent-first, 50-cap, toggle dedupe)"
    requirement: REQ-roadmap-phase3-app-actions
    verification:
      - kind: unit
        ref: BoosterSimAppTests/DeepLinkServiceTests (12 tests)
        status: pass
    human_judgment: false
  - id: D2
    description: "Privacy contract — 12 verbatim simctl TCC service strings, notifications non-constructible (D-01), grant/revoke/reset-all argv composition"
    requirement: REQ-roadmap-phase3-app-actions
    verification:
      - kind: unit
        ref: BoosterSimAppTests/PrivacyPermissionTests (7 tests)
        status: pass
    human_judgment: false
  - id: D3
    description: "Push payload gate — CodingKeys verbatim 'Simulator Target Bundle', typed parse errors (empty/malformed/non-object/missing-aps/invalid-shape), 4095/4096/4097 exact boundary, templates under the cap"
    requirement: REQ-roadmap-phase3-app-actions
    verification:
      - kind: unit
        ref: BoosterSimAppTests/PushPayloadTests (12 tests)
        status: pass
    human_judgment: false
  - id: D4
    description: "Live push delivery + guided grant + privacy grant/revoke/reset + deep links opening — on a booted Simulator with real TCC and banner behavior"
    requirement: REQ-roadmap-phase3-app-actions
    verification: []
    human_judgment: true
    rationale: "Banner delivery, TCC mutation, and the D-01 manual grant are device-state behaviors; this plan is autonomous by design (unit contracts only) — live proof is plan 03's blocking smoke per the house re-verify-quickly pattern"

# Metrics
duration: 33min
completed: 2026-08-31
status: complete
---

# Phase 3 Plan 02: Push / Deep-Link Migration / Privacy Summary

**Push notifications end-to-end on the stdin seam (typed 4096-byte gate, D-01 guided-grant control that never fakes a toggle), the 12-service privacy section with honest captions, and DeepLinkService migrated onto SimCtlService — deleting the app's last out-of-seam subprocess spawn; 31 new unit tests, full bundle 138/138.**

## Performance

- **Duration:** 33 min (04:02–04:35 UTC)
- **Started:** 2026-08-31T04:02:09Z
- **Completed:** 2026-08-31T04:35:00Z
- **Tasks:** 2 of 2
- **Files modified:** 13 (7 created, 6 modified)

## Accomplishments
- DeepLinkService rides the seam: Combine chain replaces the `Task.detached` + direct `Process` block; parseURL/scheme presets/history/favorites byte-for-byte in behavior (tests pin them); the public open method is synchronous Combine-backed, removing the file's async/await convention exemption
- Push pipeline: `PushPayload.parse` (typed errors) → `validate` (4096-byte gate on JSONEncoder output) → `simCtl.run([push, udid, bundle, "-"], stdin:)` — explicit bundle arg beats the embedded `Simulator Target Bundle` key; logging carries verb + byte size + outcome only
- D-01 shipped honestly: the permission block states notification permission is managed by iOS, links to device Settings (`launch com.apple.Preferences`), spells the guided steps inline, and makes Send the test-push probe (success caption reminds that a banner needs permission) — zero controls claiming to grant/revoke authorization
- Privacy section: one Grant/Revoke row per verbatim TCC service scoped to the picker's active app; Reset All behind a destructive confirmationDialog (booted-UDID refusal server-side); Apple's terminate warning + notifications-not-here captions
- Full unit bundle **138/138** (baseline 107 + 31 new) — zero regressions; Debug build clean

## Task Commits

Each task was committed atomically (TDD pairs):

1. **Task 1 RED:** `f91775f` — test(03-02): deep-link seam migration + privacy service contract tests
2. **Task 1 GREEN:** `d31d6a3` — feat(03-02): deep-link seam migration + 12-service privacy section
3. **Task 2 RED:** `6d00ffa` — test(03-02): push payload encode/validation gate tests
4. **Task 2 GREEN:** `eaead3a` — feat(03-02): push payload model + stdin sender + D-01 guided-grant editor

**Plan metadata:** see docs commit below.

## Files Created/Modified
- `BoosterSimApp/Services/DeepLinkService.swift` — seam migration; injectable defaults; pure validation/argv statics
- `BoosterSimApp/Models/PrivacyPermission.swift` — 12 verbatim TCC services + PrivacyAction + argv builders
- `BoosterSimApp/Models/PushPayload.swift` — payload model, typed errors, parse/validate gates, templates, PushActionResult
- `BoosterSimApp/Services/AppActionService.swift` — setPrivacy / resetAllPrivacy / openDeviceSettings / sendPush + shared single-hop runner
- `BoosterSimApp/Views/SideWindow/actions/PushNotificationSectionView.swift` — editor + pills + counter + result + D-01 block (tokens only)
- `BoosterSimApp/Views/SideWindow/actions/PrivacySectionView.swift` — 12 rows + reset confirm + honest captions
- `BoosterSimApp/Views/SideWindow/tabs/ActionsTabView.swift` — mounts push (deep-link → push → privacy) and privacy sections
- `BoosterSimApp/App/AppDelegate.swift`, `BoosterSimApp/Views/SideWindow/SideWindowView.swift` — deepLinkService init wiring (app + preview)
- `.planning/codebase/CONVENTIONS.md` — async-exemption list shrinks to CaptureService
- `BoosterSimAppTests/{DeepLinkServiceTests,PrivacyPermissionTests,PushPayloadTests}.swift` — 31 Wave 0 tests

## Decisions Made
- See key-decisions in frontmatter. All stay inside the planned architecture; the only contract-visible change is the planned one (deep-link failure captions now carry simctl's stderr via SimCtlError).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] GitNexus MCP unavailable — impact analysis substituted**
- **Found during:** Task 1 read_first
- **Issue:** The plan's `gitnexus_impact` pre-edit step could not run (no GitNexus MCP in this runtime)
- **Fix:** grep blast radius over DeepLinkService references: construction sites = AppDelegate:25 + SideWindowView:95 (#Preview); pass-through = SideWindowController (init/embed, no construction); consumers = ActionsTabView (@EnvironmentObject) + DeepLinkSectionView (@ObservedObject, `openInSimulator(udid:)` signature unchanged). d=1 = the two construction sites; both updated
- **Files modified:** none (analysis only)
- **Verification:** full unit bundle + Debug build
- **Committed in:** n/a

**2. [Rule 3 - Blocking] SideWindowView preview is a second d=1 caller the plan did not name**
- **Found during:** Task 1 implementation (compile)
- **Issue:** `#Preview` in SideWindowView.swift:95 constructs `DeepLinkService()`; the plan listed only AppDelegate for the init-signature change
- **Fix:** `DeepLinkService(simCtl: simCtl)` in the preview block — same one-line shape as the AppDelegate edit
- **Files modified:** BoosterSimApp/Views/SideWindow/SideWindowView.swift (unlisted file, required for compilation)
- **Verification:** Debug build + preview compiles
- **Committed in:** d31d6a3

**3. [Rule 3 - Blocking] Injectable UserDefaults + internal addToHistory (testability seam)**
- **Found during:** Task 1 test authoring
- **Issue:** The plan's behavior bullet requires history/favorites round-trip "through an isolated UserDefaults suite (never the shared standard suite)" — impossible against hardcoded `.standard` with a private writer
- **Fix:** `init(simCtl: SimCtlService, defaults: UserDefaults = .standard)` (production callers unchanged in behavior) and `addToHistory` promoted internal with a doc comment; persistence logic untouched
- **Files modified:** BoosterSimApp/Services/DeepLinkService.swift
- **Verification:** isolated-suite round-trip tests green
- **Committed in:** d31d6a3

**4. [Rule 1 - Bug] Invalid-URL test premise wrong on modern Foundation**
- **Found during:** Task 1 GREEN run (1 failing test)
- **Issue:** `URL(string: "not a url with spaces")` returns non-nil (spaces percent-encoded by the modern default parser) — the test asserted nil; the implementation (unchanged house parseURL) was correct
- **Fix:** replaced the example with `URL(string: "ht%tp://bad-percent")` (genuinely nil, verified in a scratch probe); also repaired two edit-boundary accidents caught by this same run (an eaten `activeBundleID` declaration and a test function lost to an over-wide CUT)
- **Files modified:** BoosterSimAppTests/DeepLinkServiceTests.swift, BoosterSimApp/Services/AppActionService.swift
- **Verification:** 19/19 Task 1 tests green
- **Committed in:** d31d6a3

**5. [Process] Plan's literal verify flag silently runs 0 tests on this Xcode**
- **Found during:** Task 1 verification
- **Issue:** `-parallel-testing-enabled NO` on plain `test` produced "Executed 0 tests" (with `test-without-building` too) or runner-handshake flakes ("Early unexpected exit" — the documented pre-existing 65-flake family); plain unflagged `test` flaked at session level while every reporting test passed
- **Fix:** ran all gates with `-maximum-parallel-testing-workers 1` — single worker without the broken no-parallel code path: 19/19, 12/12, 138/138, TEST SUCCEEDED, exit 0 each time
- **Files modified:** none
- **Verification:** /tmp/03-02-task1-final.log, /tmp/03-02-task2-green3.log, /tmp/03-02-full.log
- **Committed in:** n/a

**6. [Observation - deferred] Seam diagnostic print echoes argv, including full openurl URLs**
- **Found during:** prohibition self-check (T-03-06 adjacent)
- **Issue:** SimCtlService's pre-existing `print("[SimCtl] xcrun simctl …")` echoes argv; with deep links on the seam that now includes full URLs with query strings, brushing the "never log full URLs" prohibition. SimCtlService is outside this plan's file list (and the print predates Phase 1)
- **Fix:** none here — all NEW logging (AppActionService verbs) is verb+size+outcome only; flagged for the plan 05 phase-gate review to decide redaction at the seam
- **Files modified:** none
- **Committed in:** n/a

---

**Total deviations:** 6 (2 blocking wiring/testability auto-fixes, 1 test-premise bug, 1 process substitution, 1 unlisted-caller compile fix, 1 deferred observation)
**Impact on plan:** All within the planned architecture; no scope creep. Deviations 2-3 were load-bearing for the plan's own acceptance criteria.

## Issues Encountered
- Intermittent test-runner handshake flake ("Early unexpected exit", pre-existing per STATE.md) surfaced in 3 of 6 test invocations; every test that reported in those runs passed, and single-worker runs completed cleanly — treated as infra, not product signal
- Two edit-tool boundary accidents (Deviation 4) were caught immediately by the next compile/test cycle

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Plans 03-04 ride the seam additively; locale/location/clipboard/defaults need only new argv builders + sections (the runVerb helper and section anatomy are established)
- **Blocker:** none — live push/privacy/deep-link behavior is proven at plan 03's blocking smoke (D4 above), per the plan's own design
- CONVENTIONS.md now documents CaptureService as the sole async exemption — the codebase contains zero direct subprocess spawns outside the seam

## Self-Check: PASSED
- All 7 created files exist on disk; all 6 modified files changed as listed (git show --stat per commit)
- Commits f91775f, d31d6a3, 6d00ffa, eaead3a present on main; no deletions in any
- Full unit bundle 138/138 exit 0 (107 baseline + 31 new, zero regressions); Debug build exit 0; every Task 1/2 acceptance criterion grep-verified

---
*Phase: 03-app-actions — Plan: 02 (push / deep-link migration / privacy)*
*Status: complete — live smoke pending at plan 03 per design*
