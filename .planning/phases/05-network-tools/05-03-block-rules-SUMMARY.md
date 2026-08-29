---
phase: 05-network-tools
plan: 03
subsystem: network
tags: [urlprotocol, block-rules, string-matching, swift-testing, swiftui]

requires:
  - phase: 05-network-tools
    provides: Command channel (BoosterCommand v1 snapshot, CommandServer _booster-cmd._tcp., NetworkConditionService rules CRUD + persistence key "networkBlockRules", verdict precedence guard > airplane > rules > throttle)
provides:
  - Hardened BlockRule matcher on both sides of the schema sync (isEnabled guard, whitespace trim, empty-domain defense on top of plan-01 dot-boundary/case/nil-host semantics)
  - BlockRuleTests — ten-case matcher contract (RED-first)
  - BlockRulesView editor (list/toggle/delete/add, 50-rule cap with caption, PRO-01 scope caption) mounted in the Network tab between NetworkConditionsSectionView and CertificateSectionView
affects: [05-04-phase-gate-closure]

actuals:
  tokens: 3445    # chars/4 over the realized three-commit diff (13,781 chars)
  tasks: 2        # of 2
  commits: 3      # RED test commit + GREEN hardening + editor UI; SUMMARY/docs commits separate

tech-stack:
  added: []        # no packages — REQ-nfr-03 honored (Pulse stays sole exception; Package.resolved byte-identical)
  patterns:
    - "RED-first hardening: failing tests pin the new matcher edges before the implementation lands"
    - "Schema-sync pair discipline: every matches() semantic change mirrored identically into NetworkConditionController's BlockRule copy with cross-reference comments on both sides"

key-files:
  created:
    - BoosterSimApp/Views/SideWindow/network/BlockRulesView.swift
    - BoosterSimAppTests/BlockRuleTests.swift
  modified:
    - BoosterSimApp/Models/BlockRule.swift
    - BoosterSimConnect/NetworkConditionController.swift
    - BoosterSimApp/Views/SideWindow/tabs/NetworkTabView.swift

key-decisions:
  - "isEnabled check lives INSIDE matches() (not only in the evaluate callers) — the plan's disabled-rule behavior bullet names the rule itself, and the callers' `$0.isEnabled &&` short-circuit stays harmlessly redundant"
  - "Field trimming done in matches() (not the service add path) so both the UI and the decode path are safe — exactly the plan's stated pick"
  - "Section default-collapsed unconditionally (@State isExpanded = false) — satisfies the 'default-collapsed when no rules exist' truth with the boring, Pitfall-12-compliant behavior"
  - "pbxproj untouched (synchronized root groups auto-join BlockRulesView.swift) — third consecutive plan confirming the 05-01 finding"

patterns-established:
  - "Rules editor row: FeatureRowView styling (rowHeight + Spacing.md), path prefix as .caption capsule badge, all mutations through the service — never direct UserDefaults"

requirements-completed: []   # REQ-roadmap-phase5-network-tools is phase-level and stays open: criteria 3–5 are now delivered by plans 01–03; phase-gate closure rides plan 04.

coverage:
  - id: D1
    description: "Hardened BlockRule matcher contract: exact host, dot-boundary *.suffix (badexample.com negative), pathPrefix narrowing, disabled rule, case-insensitive host, nil-host, whitespace trim, empty/whitespace/'*.' domain never matching — identical semantics in the framework mirror"
    verification:
      - kind: unit
        ref: "BoosterSimAppTests/BlockRuleTests.swift (10 tests, RED-first)"
        status: pass
    human_judgment: false
  - id: D2
    description: "Block Rules editor operable from the Network tab: own CollapsibleSection, ≤2-interaction mutations (toggle/delete/add), 50-rule cap with explanatory caption, persistence + snapshot push via NetworkConditionService"
    verification:
      - kind: unit
        ref: "BoosterSimAppTests/NetworkConditionServiceTests.swift (8 tests — mutations persist and update snapshots; UI rides this tested surface)"
        status: pass
    human_judgment: true
    rationale: "Visual editor ergonomics (toggle/delete/add row layout in the 260pt panel, collapsed default, cap caption visibility) need human eyes; no UI-test coverage is in scope for this phase and the plan's verification section defers visual confirmation to the plan-04 phase-gate smoke"
  - id: D3
    description: "Adding *.example.com makes dot-boundary subdomain requests fail with NSURLErrorCannotConnectToHost (-1004) on the next snapshot push and appear as an error row in the traffic viewer (existing error mapping)"
    verification: []
    human_judgment: true
    rationale: "Requires a booted iOS Simulator running a DEBUG app embedding BoosterSimConnect plus visual confirmation of the traffic viewer — explicitly deferred to the plan-04 phase-gate manual smoke (research A6) by this plan's verification section; verdict mechanics are unit-proven in ConditionVerdictTests"

duration: 11min
completed: 2026-08-29
status: complete
---

# Phase 5 Plan 03: Block Rules Summary

**Request blocking by domain/path rules: hardened string-ops-only matcher (both sides of the schema sync) + BlockRulesView editor (toggle/delete/add, 50-rule cap) mounted in the Network tab; 44/44 unit tests green, both targets build, no SPM changes.**

## Performance

- **Duration:** 11 min (16:49–17:00 UTC)
- **Started:** 2026-08-29T16:49:21Z
- **Completed:** 2026-08-29T17:00:00Z
- **Tasks:** 2 of 2
- **Files modified:** 5 (2 created, 3 modified; pbxproj intentionally untouched — synchronized groups)

## Accomplishments

- `BlockRule.matches` hardened with RED-first ten-case coverage: `isEnabled` guard, whitespace trimming of rule fields (UI + decode paths both safe), empty/whitespace/`*.`-only domains never match (no accidental match-all, T-05-08) — on top of plan-01's dot-boundary suffix, case-insensitive host, and nil-host semantics; string ops only, no regex anywhere (T-05-02)
- Framework-side `BlockRule` mirror in `NetworkConditionController.swift` carries identical semantics with cross-reference comments in both files (schema-sync rule honored)
- `BlockRulesView` — CollapsibleSection ("Block Rules", shield.lefthalf.filled, default collapsed) with FeatureRowView-styled rows (domain + path-prefix capsule badge + enable toggle + delete), an add row (domain + optional path prefix, plus button), 50-rule cap with explanatory caption, and an honest URLSession-HTTP(S)-only scope caption (PRO-01)
- Mounted in `NetworkTabView` directly between `NetworkConditionsSectionView` and `CertificateSectionView`; every mutation flows through `NetworkConditionService.addRule/removeRule/setRuleEnabled` → full-snapshot broadcast (≤2 interactions each)

## Task Commits

1. **Task 1 RED: matcher edge-case contract (tests first)** — `aec8f94` (test)
2. **Task 1 GREEN: matcher hardening + framework mirror** — `99b3aee` (feat)
3. **Task 2: BlockRulesView editor + Network tab mount** — `b7ebad8` (feat)

**Plan metadata:** this docs commit.

## Files Created/Modified

- `BoosterSimAppTests/BlockRuleTests.swift` — ten-case matcher contract (new, RED-first)
- `BoosterSimApp/Models/BlockRule.swift` — hardened matcher: isEnabled guard, trim, empty-domain defense
- `BoosterSimConnect/NetworkConditionController.swift` — schema-synced mirror of the hardened matcher
- `BoosterSimApp/Views/SideWindow/network/BlockRulesView.swift` — rules editor section (new)
- `BoosterSimApp/Views/SideWindow/tabs/NetworkTabView.swift` — BlockRulesView mount point

## Decisions Made

- **`isEnabled` checked inside `matches()`** — the plan's behavior bullet ("rule with isEnabled false never matches even on exact host") names the rule; the two evaluate callers keep their `$0.isEnabled &&` short-circuit (redundant, harmless, no behavior change).
- **Trimming in `matches()`** — the plan's stated pick; both the UI add path and the UserDefaults decode path become safe without duplicating logic.
- **Default-collapsed unconditionally** — satisfies "default-collapsed when no rules exist" with the simplest Pitfall-12-compliant behavior; expansion state is not persisted.
- **pbxproj untouched** — `PBXFileSystemSynchronizedRootGroup` auto-membership proven by the build; third consecutive plan confirming the 05-01 finding.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] GitNexus MCP tools unavailable; manual impact analysis substituted**
- **Found during:** Task 1 (read_first gate — "run gitnexus_impact on BlockRule")
- **Issue:** The plan and AGENTS.md mandate GitNexus impact analysis before editing; the tools are not available in this runtime (noted in the dispatch assignment).
- **Fix:** Manual blast-radius analysis via repo-wide search: `BlockRule.matches` has exactly two upstream callers — `evaluate(request:snapshot:)` (BoosterSimApp/Models/BoosterCommand.swift:120) and `evaluateCondition(request:snapshot:)` (BoosterSimConnect/NetworkConditionController.swift:84), both invoking it as `$0.isEnabled && $0.matches(request)`. Hardening inside `matches` cannot change caller outcomes; risk assessed LOW. No other references.
- **Files modified:** none (analysis only)
- **Verification:** full unit bundle green after the edit (44/44, exit 0) — the only two callers and all their tests unchanged in behavior
- **Committed in:** n/a (process substitution)

**2. [Rule 3 - Blocking] Plan's per-suite test verify hits the documented pre-existing host flake**
- **Found during:** Task 1 verification
- **Issue:** `-only-testing:BoosterSimAppTests/BlockRuleTests` intermittently exits 65 with "Early unexpected exit … test runner exited with code 0 before establishing connection" — the flake reproduced on pristine HEAD in 05-01 (deviation 3) and logged in STATE.md; all 10 per-case results were green in the failing run.
- **Fix:** Verification standard from 05-02 reused: full unit bundle via `-only-testing:BoosterSimAppTests -skip-testing:BoosterSimAppUITests` → `** TEST SUCCEEDED **`, exit 0, 44/44 cases (10 BlockRuleTests + 8 NetworkConditionServiceTests + 26 others).
- **Files modified:** none
- **Verification:** two clean exit-0 bundle runs captured in session logs
- **Committed in:** n/a (verification method)

---

**Total deviations:** 2 (both Rule 3 process/workaround handling; zero code deviations)
**Impact on plan:** No scope creep; plan executed as written otherwise. Package.resolved byte-identical (`git diff --exit-code` clean).

## Issues Encountered

- `gsd-tools query roadmap.update-plan-progress 5 05-03-block-rules complete` returned `"updated": true` but left the bullet unchecked on the first call (it keys off SUMMARY files on disk, which did not exist yet at call time); re-running after SUMMARY.md landed flipped the bullet and the 3/4 counter correctly — no hand-edit needed.

## User Setup Required

None beyond the plan-01 setup (booted Simulator running a DEBUG app embedding BoosterSimConnect; BoosterSimApp running). The visible blocked-request error row confirmation rides the plan-04 phase-gate smoke.

## Next Phase Readiness

- Criterion 5 (request blocking by domain/path rules) delivered end-to-end on the plan-01 engine; only plan 04 (docs, full-suite + pin assertions, phase-gate manual smoke) remains for phase closure.
- The plan-04 smoke gains a block-rule step: add `*.example.com` (or similar) in the new Block Rules section, trigger a matching request in the app under test, confirm the -1004 error row in the traffic viewer, then disable/delete and confirm recovery on the next request (must-have truths 1 and 4).
- Matcher is shared-contract-stable: any future semantic change must mirror into `BoosterSimConnect/NetworkConditionController.swift` (cross-reference comments mark both copies).

## Self-Check: PASSED

- All key-files exist on disk (`[ -f ]` verified): BlockRuleTests.swift, BlockRule.swift, NetworkConditionController.swift, BlockRulesView.swift, NetworkTabView.swift
- All 3 production commits present in git log (aec8f94, 99b3aee, b7ebad8)
- Task 1 acceptance: 10 behavior bullets as separate @Test funcs ✓; no regex in either matcher file (grep clean) ✓; badexample.com negative passes ✓; framework mirror carries identical semantics + cross-reference comment ✓; test command exit 0 (full-bundle form) ✓
- Package.resolved byte-identical after all tasks ✓

---
*Phase: 05-network-tools — Plan: 03 (block rules)*
*Completed: 2026-08-29*
