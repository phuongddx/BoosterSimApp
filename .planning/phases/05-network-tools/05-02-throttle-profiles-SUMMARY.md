---
phase: 05-network-tools
plan: 02
subsystem: network
tags: [urlprotocol, pacing, throttle-profiles, swift-testing, userdefaults]

requires:
  - phase: 05-network-tools
    provides: Command channel (BoosterCommand v1 snapshot, CommandServer _booster-cmd._tcp., BoosterNetworkProtocol verdict chain, NetworkConditionService, NetworkConditionsSectionView mount point)
provides:
  - NetworkConditionProfile presets (off/edge/threeG/lte/wifi) with display metadata + ThrottleSpec mapping
  - Pure ThrottleSchedule pacing math (Mac) + schema-synced ThrottlePacing mirror (framework)
  - ConditionVerdict .throttle case + ordered enforcement (guard > airplane > rules > throttle > passThrough) on both sides
  - Paced URL-level enforcement in BoosterNetworkProtocol (latency delay → chunked didLoad → finish, cancellable)
  - NetworkConditionService.selectedProfile persisted under user-facing key "networkConditionProfile" and carried in every snapshot
  - Profile picker pills + effective-condition caption in the Network tab
affects: [05-03-block-rules, 05-04-phase-gate-closure]

actuals:
  tokens: 9000    # chars/4 over the realized three-commit diff (35,933 chars)
  tasks: 3        # of 3
  commits: 3      # production commits; SUMMARY/docs commits separate

tech-stack:
  added: []        # no packages — REQ-nfr-03 honored (Pulse stays sole exception, 5.2.2; Package.resolved byte-identical)
  patterns:
    - "Paced URLProtocol delivery: DispatchWorkItem set on a per-request serial queue, cancel() drops pending (T-05-06)"
    - "Schema-synced pacing math pair: ThrottleSchedule (Mac, pure+tested) ⇄ ThrottlePacing.plan (framework mirror)"
    - "Verdict precedence extension: new cases slot into the ordered evaluate chain, never reorder existing ones"

key-files:
  created:
    - BoosterSimApp/Models/NetworkConditionProfile.swift
    - BoosterSimConnect/ThrottlePacing.swift
    - BoosterSimAppTests/NetworkConditionProfileTests.swift
  modified:
    - BoosterSimApp/Models/BoosterCommand.swift
    - BoosterSimApp/Services/NetworkConditionService.swift
    - BoosterSimApp/Views/SideWindow/network/NetworkConditionsSectionView.swift
    - BoosterSimConnect/NetworkConditionController.swift
    - BoosterSimConnect/BoosterNetworkProtocol.swift
    - BoosterSimConnect/BoosterCommandClient.swift
    - BoosterSimAppTests/ConditionVerdictTests.swift
    - BoosterSimAppTests/NetworkConditionServiceTests.swift

key-decisions:
  - "Pacing formula resolved toward the must-have truths: chunkInterval = chunkBytes*8/kbps s (16s per 1500B chunk at 750 kbps; completion = latencyMs + totalBytes*8/kbps). The Task-1 behavior bullet's '16s/10 = 1.6s' tail divided the per-chunk value by chunk count a second time and would have broken truth #1's completion invariant (16.4s ≠ 160.4s) — objective, truth #1, and truth #2 all state the formula consistently, so the bullet tail is a planning arithmetic slip"
  - "Pacing constructor rejection behavior: failable init returning nil for downloadKbps ≤ 0, chunkBytes ≤ 0, totalBytes < 0, latencyMs < 0 (T-05-07); zero latency and empty bodies stay valid (pure-bandwidth pacing, headers-only responses); framework degrades to unpaced delivery on nil plans instead of trapping on wire data"
  - "Enforcement chunkBytes = 1500 (the plan's canonical vector); scheduled items bounded by response body size (T-05-06 accepted)"
  - "pbxproj untouched again: synchronized root groups auto-join new files; zero conflict surface left for plan 05-03's pbxproj edits"

patterns-established:
  - "Throttle delivery schedule: didReceive at firstByteDelay, chunk j at firstByteDelay + j*chunkInterval, finish rides the last chunk's step (empty body finishes at firstByteDelay)"
  - "Profile persistence: raw-value string under a user-facing UserDefaults key, read back via failable rawValue with .off fallback"

requirements-completed: []   # REQ-roadmap-phase5-network-tools is phase-level and stays open: criterion 3 (throttle) is delivered by this plan; criteria 4–5 and phase-gate closure ride plans 01 (done), 03, 04.

coverage:
  - id: D1
    description: "Throttle presets (exact specs for EDGE/3G/LTE/Wi-Fi, nil for off) + pure deterministic pacing math at chunk granularity with invalid-input rejection and Codable round-trip"
    verification:
      - kind: unit
        ref: "BoosterSimAppTests/NetworkConditionProfileTests.swift (6 tests)"
        status: pass
    human_judgment: false
  - id: D2
    description: ".throttle verdict with ordered precedence (guard > airplane > rules > throttle) on the Mac evaluate and the framework mirror"
    verification:
      - kind: unit
        ref: "BoosterSimAppTests/ConditionVerdictTests.swift (4 new throttle tests, 9 total)"
        status: pass
    human_judgment: false
  - id: D3
    description: "Profile selection persists under networkConditionProfile and rides every full-state snapshot (off → nil throttle, reconcile on client connect)"
    verification:
      - kind: unit
        ref: "BoosterSimAppTests/NetworkConditionServiceTests.swift (2 new profile tests, 8 total)"
        status: pass
    human_judgment: false
  - id: D4
    description: "Visible slow-loading behavior in a live Simulator app under a selected profile (paced rows in the traffic viewer, one-tap pick, persistence across relaunch)"
    verification: []
    human_judgment: true
    rationale: "Requires a booted iOS Simulator running a DEBUG app embedding BoosterSimConnect plus visual timing judgment of paced delivery — explicitly deferred to the plan-04 phase-gate manual smoke (3G profile step) by this plan's verification section"

duration: 15min
completed: 2026-08-29
status: complete
---

# Phase 5 Plan 02: Throttle Profiles Summary

**Network speed control end-to-end: Network tab profile pills (Off/EDGE/3G/LTE/Wi-Fi) → persisted NetworkConditionProfile → snapshot throttle spec → .throttle verdict → latency + paced-chunk delivery inside the app under test; 34 unit tests green, both targets build, no SPM changes.**

## Performance

- **Duration:** 15 min (16:33–16:48 UTC)
- **Started:** 2026-08-29T16:33:57Z
- **Completed:** 2026-08-29T16:48:00Z
- **Tasks:** 3 of 3
- **Files modified:** 11 (3 created, 8 modified; pbxproj intentionally untouched — synchronized groups)

## Accomplishments

- `NetworkConditionProfile` presets with exact specs (EDGE 800ms/200 Kbps, 3G 400ms/750, LTE 100ms/10000, Wi-Fi 20ms/25000), display names + picker captions, and pure `ThrottleSchedule` pacing math (`chunkInterval = chunkBytes * 8 / kbps` s, completion `latencyMs + totalBytes * 8 / kbps`)
- `.throttle(ThrottleSpec)` verdict on Mac + framework mirror with the ordered precedence contract (guard > airplane > rules > throttle > pass-through), enforced in `BoosterNetworkProtocol` via `ThrottlePacing`: latency delay before the first `didReceive`, body in 1500-byte slices at `chunkInterval` spacing, cancellable from `stopLoading`, malformed specs degrade to unpaced
- One-tap profile picker in the Network tab (five pills, amber selected accent, VoiceOver captions, disabled under airplane) + effective-condition status caption; selection persists under `networkConditionProfile` and re-applies via snapshot reconcile

## Task Commits

1. **Task 1: NetworkConditionProfile presets + pure pacing math (tests first)** — `726289c` (feat)
2. **Task 2: .throttle verdict + paced enforcement in BoosterNetworkProtocol** — `3a1bb34` (feat, includes the Rule-3 framework-build fix)
3. **Task 3: Profile selection state + picker pills** — `08e9fcf` (feat)

**Plan metadata:** this docs commit.

## Files Created/Modified

- `BoosterSimApp/Models/NetworkConditionProfile.swift` — profile enum + ThrottleSchedule pure pacing math (new)
- `BoosterSimConnect/ThrottlePacing.swift` — framework pacing helper: serial queue, mirrored schedule math, schedule/cancel (new)
- `BoosterSimApp/Models/BoosterCommand.swift` — ConditionVerdict + evaluate gain `.throttle`
- `BoosterSimConnect/NetworkConditionController.swift` — schema-synced verdict mirror
- `BoosterSimConnect/BoosterNetworkProtocol.swift` — canInit admits throttle; paced forwardThrottled; stopLoading cancels pacing
- `BoosterSimConnect/BoosterCommandClient.swift` — restored frame constants (pre-existing build break, see deviation 2)
- `BoosterSimApp/Services/NetworkConditionService.swift` — selectedProfile + selectProfile(_:) + snapshot throttle wiring
- `BoosterSimApp/Views/SideWindow/network/NetworkConditionsSectionView.swift` — pill row + effective-condition caption
- `BoosterSimAppTests/{NetworkConditionProfileTests,ConditionVerdictTests,NetworkConditionServiceTests}.swift` — 12 new test cases total

## Decisions Made

- **Pacing arithmetic resolved to the must-have truths** (see key-decisions): `chunkInterval = chunkBytes * 8 / kbps` seconds; the Task-1 behavior bullet's "1.6s" tail was an internal inconsistency, not the contract.
- **Failable constructor over precondition** for invalid pacing input — wire data is never trusted, callers degrade gracefully (T-05-07).
- **Finish rides the last chunk's dispatch step** rather than a separate equal-deadline item — same-deadline FIFO ordering on the serial queue would hold, but composing the steps removes the ordering assumption entirely.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Plan-internal inconsistency] Pacing test-vector arithmetic (behavior bullet vs must-have truths)**
- **Found during:** Task 1 (test authoring)
- **Issue:** The Task-1 behavior bullet's tail "per-chunk interval 16s/10 = 1.6s, last chunk at 0.4 + 10*1.6s" contradicts the plan's own contract stated three times (objective, truth #1, truth #2): `chunkInterval = chunkBytes * 8 / kbps` = 16s for 1500B @ 750 kbps, completion = `latencyMs + N*8/downloadKbps` = 160.4s. The bullet divides the already-per-chunk value (16) by chunk count (10) a second time; its 16.4s total would violate truth #1's completion invariant.
- **Fix:** Implemented and tested the truth-stated formula: interval 16s, last chunk at 0.4 + 10·16 = 160.4s; the test also asserts the truth-#1 identity (`lastChunkAt == latency + totalBytes*8/kbps`).
- **Files modified:** BoosterSimAppTests/NetworkConditionProfileTests.swift, BoosterSimApp/Models/NetworkConditionProfile.swift
- **Verification:** threeGPacingScheduleOver15000Bytes passes with exact TimeInterval arithmetic
- **Committed in:** 726289c

**2. [Rule 3 - Blocking] Framework target did not compile at HEAD (pre-existing)**
- **Found during:** Task 2 (BoosterSimConnect scheme build)
- **Issue:** 05-01's hardening commit `ea7b024` rewrote `BoosterCommandClient.decodeFrame` to the re-based `[UInt8]` form but deleted the private `prefixLength` / `maxPayloadSize` / `FrameError` declarations the function still uses — `xcodebuild -scheme BoosterSimConnect` fails at pristine HEAD. The macOS app scheme never caught it because the BoosterSimConnect folder compiles empty there (`targetEnvironment(simulator)` guard).
- **Fix:** Restored the three private declarations exactly as they stood in `7a8da29` (verified via git archaeology; no other file references them).
- **Files modified:** BoosterSimConnect/BoosterCommandClient.swift
- **Verification:** BoosterSimConnect scheme builds (`BUILD SUCCEEDED`, generic/platform=iOS Simulator)
- **Committed in:** 3a1bb34

---

**Total deviations:** 2 auto-fixed (1 Rule-1 plan-inconsistency resolution, 1 Rule-3 blocking pre-existing build fix)
**Impact on plan:** Both fixes were required for the plan's own contract (truth #1) and verification gate ("both targets build"). No scope creep; Package.resolved byte-identical.

## Issues Encountered

- The documented post-test "Early unexpected exit" flake (05-01 deviation 3, pre-existing on pristine HEAD) also fires under `-only-testing:BoosterSimAppTests/...Suite` invocations — the UI-test runner still relaunches the host app after the unit bundle. Verification standard used: full unit bundle via `-only-testing:BoosterSimAppTests -skip-testing:BoosterSimAppUITests`, which produced a clean `** TEST SUCCEEDED **` (exit 0) twice this session; every per-case result green in all runs (0 failures anywhere).

## User Setup Required

None beyond the plan-01 setup (booted Simulator running a DEBUG app embedding BoosterSimConnect; BoosterSimApp running). The visible slow-loading confirmation rides the plan-04 phase-gate smoke (3G profile step).

## Next Phase Readiness

- Engine extension complete: `.throttle` is enforced end-to-end; plan 03 (block rules UI) is additive and has zero file overlap with this plan (no pbxproj edits made here at all).
- **Fidelity note for plan-04 smoke:** the plan-contract formula treats the profile numbers as the plan specifies (`N*8/downloadKbps` seconds — no ÷1000 kilo factor), so a 3G-paced 15 KB body takes ~160 s, far slower than physical 3G. Values are declared approximations (research A2); if the smoke wants real-world timing, rescaling is a one-line constant in `ThrottleSchedule` + `ThrottlePacing.plan` and a test-vector update — flagged, not changed, because the plan text pins the formula.
- Slow-row visibility in the traffic viewer needs no new path: Pulse's observer already reports long-running tasks (code 10 / slow-task events) on the outer URLSession task.

## Self-Check: PASSED

- All 3 key-files exist on disk (`[ -f ]` verified)
- All 3 production commits present in git log (726289c, 3a1bb34, 08e9fcf)
- Unit bundle: 34/34 cases green across two clean exit-0 runs (12 new this plan: 6 profile + 4 verdict + 2 service)
- BoosterSimConnect scheme: BUILD SUCCEEDED; BoosterSimApp scheme: BUILD SUCCEEDED
- Package.resolved byte-identical after all tasks (`git diff --exit-code` clean)
- No pbxproj changes (wave-2 serialization guard honored for plan 03)

---
*Phase: 05-network-tools — Plan: 02 (throttle profiles)*
*Completed: 2026-08-29*
