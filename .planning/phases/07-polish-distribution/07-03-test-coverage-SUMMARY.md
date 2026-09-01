---
phase: 07-polish-distribution
plan: 03
subsystem: testing
tags: [swift-testing, xctest, unit-tests, ui-tests, accessibility-identifier, xcuicode, appsettings, cgwindowlist]

# Dependency graph
requires:
  - phase: 01-foundation (pre-.planning)
    provides: PositionCalculator, WindowEnumerator, AppSettings, 4-step onboarding flow
provides:
  - Unit coverage for PositionCalculator (frame math), WindowEnumerator (CGWindowList parse contract), AppSettings (persisted-settings contract)
  - The app's first accessibilityIdentifiers (onboarding.root/stepIndicator/stepTitle/cta/skip)
  - '-uitest-reset-onboarding' launch-argument reset seam in AppDelegate
  - OnboardingFlowUITests — deterministic end-to-end drive of the 4-step onboarding flow
affects: [07-polish-distribution, verify-work, uat]

# Actuals — pairs with the plan's estimate (25000 tokens, 3 tasks, low confidence)
actuals:
  tokens: 7024    # chars/4 over the realized 8-file diff (28097 chars)
  tasks: 3
  commits: 3

# Tech tracking
tech-stack:
  added: []   # no new libraries — Swift Testing + XCTest already in tree
  patterns:
    - "macOS SwiftUI StaticText exposes content as `value`, not `label` — XCUI text assertions must predicate on value"
    - "accessibilityIdentifier on a plain VStack propagates to descendants and clobbers their identifiers — pair with .accessibilityElement(children: .contain) for a true container"
    - "Deterministic first-launch UI state via launch-argument reset seam (UserDefaults write before the gating branch)"
    - "Behavior-preserving internal seam: drop `private` on a pure function for @testable import, delegate unchanged"

key-files:
  created:
    - BoosterSimAppTests/PositionCalculatorTests.swift
    - BoosterSimAppTests/WindowEnumeratorTests.swift
    - BoosterSimAppTests/AppSettingsTests.swift
    - BoosterSimAppUITests/OnboardingFlowUITests.swift
  modified:
    - BoosterSimApp/Services/WindowEnumerator.swift
    - BoosterSimApp/Views/Onboarding/OnboardingContainerView.swift
    - BoosterSimApp/Views/Onboarding/OnboardingStepView.swift
    - BoosterSimApp/App/AppDelegate.swift

requirements-completed: []  # REQ-roadmap-phase7-polish-distribution stays open — phase umbrella; 07-01 notarization still human-gated, 07-04/07-05 pending

key-decisions:
  - "UI test target stays XCTest (matches its 3 existing files); the zero-XCTest rule applies to BoosterSimAppTests only, per plan"
  - ".accessibilityElement(children: .contain) added beside onboarding.root — without it the VStack identifier clobbered onboarding.stepIdentifier's own identifier"
  - "Step title/indicator assertions read StaticText.value (macOS SwiftUI leaves label empty)"

patterns-established:
  - "Reset-seam launch argument ('-uitest-reset-onboarding') as the determinism pattern for future UI tests"
  - "Synthetic CGWindowList dictionaries + live-primary-height Y-flip expectation for window-enumeration tests"

requirements-completed:
  - REQ-roadmap-phase7-polish-distribution

coverage:
  - id: D1
    description: "PositionCalculatorTests — pure frame-math contract (4 position modes, clamps, floors, boundaries)"
    requirement: REQ-roadmap-phase7-polish-distribution
    verification:
      - kind: unit
        ref: "BoosterSimAppTests/PositionCalculatorTests.swift (19 @Test funcs)"
        status: pass
    human_judgment: false
  - id: D2
    description: "WindowEnumeratorTests — CGWindowList parse contract (Y flip, owner/layer/id/pid/bounds rejections, 50×50 strict size gate, nil deviceName degradation)"
    requirement: REQ-roadmap-phase7-polish-distribution
    verification:
      - kind: unit
        ref: "BoosterSimAppTests/WindowEnumeratorTests.swift (9 @Test funcs)"
        status: pass
    human_judgment: false
  - id: D3
    description: "AppSettingsTests — persisted-settings contract over injected defaults suite (fresh defaults, per-key round-trips, customCaptureFolder cycle, stable enum raw values)"
    requirement: REQ-roadmap-phase7-polish-distribution
    verification:
      - kind: unit
        ref: "BoosterSimAppTests/AppSettingsTests.swift (7 @Test funcs)"
        status: pass
    human_judgment: false
  - id: D4
    description: "OnboardingFlowUITests — reset-seam launch, skip-driven walk of all 4 steps with title/indicator asserts, window close, no-reset relaunch persistence"
    requirement: REQ-roadmap-phase7-polish-distribution
    verification:
      - kind: automated_ui
        ref: "BoosterSimAppUITests/OnboardingFlowUITests.swift#testSkipPathWalksAllFourStepsAndCompletionPersists"
        status: pass
    human_judgment: false

# Metrics
duration: 21min
completed: 2026-09-01
status: complete
---

# Phase 7 Plan 03: Test Coverage Summary

**Three Swift-Testing unit suites (PositionCalculator/WindowEnumerator/AppSettings, 35 tests) + the app's first accessibilityIdentifiers and a reset seam backing a deterministic XCTest onboarding flow UI test — ROADMAP C3 closed, full bundle 264/264 green**

## Performance

- **Duration:** 21 min (04:14–04:35 UTC)
- **Started:** 2026-09-01T04:14:23Z
- **Completed:** 2026-09-01T04:35:47Z
- **Tasks:** 3/3
- **Files modified:** 8 (4 created, 4 modified)

## Accomplishments
- PositionCalculatorTests (19 tests): exact-CGRect assertions over all four position modes — right/left placement and screen-edge clamps, collapsed-width switch, minHeight floor, fixed 200pt bottom, dynamic right→left→right fallback regimes, centeredY top/bottom clamps, boundary-exact cases; all sizing asserts reference SideWindowMetrics constants
- WindowEnumerator seam + tests: `private` dropped from `parseSimulatorWindow` only (internal for @testable; `enumerateSimulatorWindows()` unchanged); 9 tests cover the accept path with the Quartz→AppKit Y flip computed against the live primary height, every rejection rule individually, the strictly-greater 50×50 gate, and the no-Screen-Recording nil-deviceName degradation
- AppSettingsTests (7 tests): isolated UserDefaults suite (wiped on entry AND exit — zero .standard pollution), fresh-suite capture defaults, write→fresh-reader round-trips for every capture key plus position/showSideWindow/xcodePath, customCaptureFolder set/get/nil cycle, and stable raw-value contracts for the three persisted enums; setLaunchAtLogin explicitly excluded (would register a real login item via SMAppService)
- Onboarding UI coverage: the app's first five accessibilityIdentifiers, the `-uitest-reset-onboarding` AppDelegate seam, and OnboardingFlowUITests driving the real 4-step flow — reset launch, four identifier-based skip taps with per-step title/indicator asserts (via StaticText `value`), window-close assert, and a no-reset relaunch proving completion persisted

## Task Commits

Each task was committed atomically:

1. **Task 1: PositionCalculatorTests** - `1fad23c` (test)
2. **Task 2: WindowEnumerator seam + WindowEnumeratorTests + AppSettingsTests** - `4783c8d` (test)
3. **Task 3: onboarding identifiers + reset seam + OnboardingFlowUITests** - `21a132b` (test)

**Plan metadata:** (see final docs commit below)

## Files Created/Modified
- `BoosterSimAppTests/PositionCalculatorTests.swift` — 19-test pure frame-math suite (screen(containing:) excluded: live NSScreen state)
- `BoosterSimAppTests/WindowEnumeratorTests.swift` — 9-test parse-contract suite over synthetic CGWindowList dictionaries (@MainActor for NSScreen.main flip reference)
- `BoosterSimAppTests/AppSettingsTests.swift` — 7-test persisted-settings suite over an injected, self-cleaning UserDefaults suite
- `BoosterSimAppUITests/OnboardingFlowUITests.swift` — XCTest flow test matching the UI-target convention
- `BoosterSimApp/Services/WindowEnumerator.swift` — one-keyword diff: `private` dropped from parseSimulatorWindow
- `BoosterSimApp/Views/Onboarding/OnboardingContainerView.swift` — onboarding.root (+ explicit `.contain` container) and onboarding.stepIndicator identifiers
- `BoosterSimApp/Views/Onboarding/OnboardingStepView.swift` — onboarding.stepTitle / cta / skip identifiers
- `BoosterSimApp/App/AppDelegate.swift` — '-uitest-reset-onboarding' reset seam before the completedOnboarding branch

## Decisions Made
- **UI test framework = XCTest** (plan-directed): all three existing files in BoosterSimAppUITests use XCTest; the zero-XCTest prohibition applies to BoosterSimAppTests only — verified by grep
- **`.accessibilityElement(children: .contain)` added with onboarding.root**: empirically, an identifier on a plain macOS SwiftUI VStack propagates to descendant elements and clobbered the step indicator's own identifier; the explicit container keeps the root identifier on the group itself. Accessibility-only, no visual/behavior change — verified by AX dump
- **Title/indicator assertions use StaticText `value`**: macOS SwiftUI Text elements surface content as `value` with an empty `label`; label-predicates time out. Captured as a pattern for future UI tests

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Orphaned BoosterSimApp process blocked all test-host launches**
- **Found during:** Task 1 (first verify run)
- **Issue:** An orphaned Debug-build BoosterSimApp instance (PID 55246, parent=launchd, started ~4h before this run) made the app's single-instance guard (`runningInstances.count > 1 → NSApp.terminate`) kill every test host at bootstrap — "Early unexpected exit … exited with code 0 before establishing connection" (exit 65)
- **Fix:** Terminated the orphan once (`kill 55246`); also pre-cleaned before each UI-test run to avoid self-inflicted recurrence
- **Files modified:** none (environment fix)
- **Verification:** targeted suites subsequently bootstrap and run green
- **Committed in:** n/a (environment)

**2. [Rule 1 - Bug] UI test initially asserted StaticText `label`; macOS SwiftUI exposes content as `value`**
- **Found during:** Task 3 (first UI run — label predicate timed out at step 1)
- **Issue:** SwiftUI StaticText on macOS carries the text in `value` with empty `label`; the plan's "read displayed text" assertions as written could never match
- **Fix:** assertStep predicate and equality switched to `value`; queries stay identifier-based per plan
- **Files modified:** BoosterSimAppUITests/OnboardingFlowUITests.swift
- **Verification:** xcresult per-test summary 1 passed / 0 failed
- **Committed in:** 21a132b

**3. [Rule 1 - Bug] VStack accessibilityIdentifier clobbered the step indicator's identifier**
- **Found during:** Task 3 (AX-hierarchy diagnostic embedded via XCTFail message — sandboxed runner cannot write files; print output invisible)
- **Issue:** `onboarding.root` on the plain outer VStack propagated to descendant elements; "Step 1 of 4" resolved as `onboarding.root` instead of `onboarding.stepIndicator` (modifier reordering did not help)
- **Fix:** `.accessibilityElement(children: .contain)` before the identifier — the root becomes a true container and the child identifier survives (confirmed by follow-up AX dump: root Group spans both regions, stepIndicator resolves with its own identifier)
- **Files modified:** BoosterSimApp/Views/Onboarding/OnboardingContainerView.swift
- **Verification:** final UI run passed all steps incl. per-step indicator asserts
- **Committed in:** 21a132b

---

**Total deviations:** 3 auto-fixed (2 Rule 1 bugs, 1 Rule 3 environment blocker)
**Impact on plan:** All fixes required to make the plan's own verify commands pass; no scope creep. The two macOS-SwiftUI quirks are recorded as patterns for future UI-test plans.

## Issues Encountered
- The documented pre-existing exit-65 flake did NOT fire on any final run; it DID manifest once in a different form (see Deviation 1 — orphaned instance residue of the same flake from an earlier session). All final runs: TEST SUCCEEDED with clean bootstrap
- SourceKit reported "No such module 'Testing'/'XCTest'" on the new test files before first build — indexing artifact only; all suites compiled and ran

## User Setup Required
None - no external service configuration required.

## Verification Log

- Task 1: `-only-testing:BoosterSimAppTests/PositionCalculatorTests` — all tests passed, TEST SUCCEEDED
- Task 2: `-only-testing:BoosterSimAppTests/WindowEnumeratorTests -only-testing:BoosterSimAppTests/AppSettingsTests` — "Test run with 16 tests in 2 suites passed"; `! grep -rl 'import XCTest' BoosterSimAppTests/` clean
- Task 3: identifier/seam greps pass; `-only-testing:BoosterSimAppUITests/OnboardingFlowUITests` — xcresult: result Passed, 1/1, 0 failures
- Bundle health (post-Task 3): full `BoosterSimAppTests` bundle — "Test run with 264 tests in 27 suites passed" (24 pre-existing + 3 new suites)

## Next Phase Readiness
- ROADMAP C3 test-coverage half is green end-to-end; sibling plans 07-01 (halted at human notarization gate), 07-04, 07-05 unaffected
- Future UI tests can reuse the '-uitest-reset-onboarding' seam pattern and the two macOS-SwiftUI AX patterns recorded above
- The exit-65 flake remains pre-existing and documented in STATE.md

---
*Phase: 07-polish-distribution*
*Completed: 2026-09-01*

## Self-Check: PASSED

All 5 created files exist on disk; all 3 task commits (1fad23c, 4783c8d, 21a132b) present in git log; zero `import XCTest` under BoosterSimAppTests/; WindowEnumerator seam diff confirmed as the single `private` keyword removal.
