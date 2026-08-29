---
phase: 05-network-tools
plan: 01
subsystem: network
tags: [bonjour, nwlistener, urlprotocol, swizzle, json-framing, swift-testing]

requires:
  - phase: 04-connect-traffic-viewer (pre-.planning delivery)
    provides: Connect/Pulse inspection pipeline (traffic viewer, _pulse._tcp. channel, BoosterSimConnect loader)
provides:
  - BoosterCommand full-state snapshot schema (version 1) + CommandFrame length-prefix codec — the wire contract for all Phase 5 tools
  - CommandServer (Mac, "_booster-cmd._tcp.", loopback-bound, reconcile-on-connect)
  - BoosterCommandClient + NetworkConditionController + BoosterNetworkProtocol (framework side enforcement chain)
  - NetworkConditionService state machine + persistence keys ("networkConditionAirplane", "networkBlockRules")
  - NetworkConditionsSectionView mount point in the Network tab
affects: [05-02-throttle-profiles, 05-03-block-rules, 05-04-phase-gate-closure]

actuals:
  tokens: 14646   # chars/4 over the realized two-commit diff (58,586 chars)
  tasks: 2        # of 3; Task 3 is the blocking-human Simulator smoke (pending)
  commits: 2      # production commits; SUMMARY commit separate

tech-stack:
  added: []        # no packages — REQ-nfr-03 honored (Pulse stays sole exception, 5.2.2)
  patterns:
    - "Second Bonjour channel pattern: mirror PulseServer shape, different service type"
    - "Framework-side schema mirrors behind #if DEBUG && targetEnvironment(simulator) (compile empty in macOS app target)"
    - "URLSession init method-exchange chaining with Pulse (renamed selector calls exchanged IMP)"
    - "Length-prefixed framing via re-based [UInt8] copy (Data-slice index trap avoidance)"
    - "NWListener/NWConnection must be cancelled in deinit or Network.framework traps"

key-files:
  created:
    - BoosterSimApp/Models/BoosterCommand.swift
    - BoosterSimApp/Models/BlockRule.swift
    - BoosterSimApp/Services/CommandServer.swift
    - BoosterSimApp/Services/NetworkConditionService.swift
    - BoosterSimApp/Views/SideWindow/network/NetworkConditionsSectionView.swift
    - BoosterSimConnect/BoosterCommandClient.swift
    - BoosterSimConnect/NetworkConditionController.swift
    - BoosterSimConnect/BoosterNetworkProtocol.swift
    - BoosterSimAppTests/CommandPayloadTests.swift
    - BoosterSimAppTests/ConditionVerdictTests.swift
    - BoosterSimAppTests/NetworkConditionServiceTests.swift
  modified:
    - BoosterSimApp/Views/SideWindow/tabs/NetworkTabView.swift
    - BoosterSimApp/App/AppDelegate.swift
    - BoosterSimApp/Windows/SideWindowController.swift
    - BoosterSimApp/Utilities/AppLogger.swift
    - BoosterSimApp/Views/SideWindow/SideWindowView.swift
    - BoosterSimConnect/BoosterSimConnect.swift

key-decisions:
  - "No project.pbxproj edit needed: targets use PBXFileSystemSynchronizedRootGroup (auto membership) — plan's pbxproj step satisfied by the build itself"
  - "Framework files wrapped in #if DEBUG && targetEnvironment(simulator) so the macOS app target (which also compiles the BoosterSimConnect folder) gets zero symbols — prevents duplicate BoosterCommand declarations"
  - "CommandServer bound to loopback 127.0.0.1 (T-05-01) with includePeerToPeer kept to mirror PulseServer; fallback documented if smoke fails discovery"
  - "Framework mirror function named evaluateCondition (not evaluate) to avoid member/module shadowing; semantics byte-for-byte identical to Mac-side evaluate"
  - "URLProtocol.setProperty requires NSMutableURLRequest — guard marker set via mutableCopy round-trip (markedInternal helper)"

patterns-established:
  - "Command channel framing: CommandFrame.encode/decodeOne on Mac, schema-synced mirror in BoosterCommandClient"
  - "State machine quartet (begin/finish/fail/transition) reused from CertificateService for NetworkConditionService"
  - "Persistence: UserDefaults-backed @Published (networkConditionAirplane / networkBlockRules) read in init, written on every mutation"

requirements-completed: []   # REQ-roadmap-phase5-network-tools (phase-level) and REQ-nfr-03 remain open: smoke + plans 02–04 outstanding. REQ-nfr-03 was honored by this plan (Package.resolved byte-identical) but is verified phase-wide at plan 04.

coverage:
  - id: D1
    description: "BoosterCommand/ThrottleSpec/BlockRule wire contract: lossless Codable round-trip, unknown-version ignore, length-prefix framing (empty/1-byte/split/two-concat/over-cap)"
    verification:
      - kind: unit
        ref: "BoosterSimAppTests/CommandPayloadTests.swift (8 tests)"
        status: pass
    human_judgment: false
  - id: D2
    description: "Condition verdict decision function: airplane → -1009, matching enabled rule → -1004, guard-marked pass-through, clean pass-through"
    verification:
      - kind: unit
        ref: "BoosterSimAppTests/ConditionVerdictTests.swift (5 tests)"
        status: pass
    human_judgment: false
  - id: D3
    description: "NetworkConditionService state machine + persist/re-apply + total single-writer snapshots"
    verification:
      - kind: unit
        ref: "BoosterSimAppTests/NetworkConditionServiceTests.swift (6 tests)"
        status: pass
    human_judgment: false
  - id: D4
    description: "End-to-end airplane proof on a live Simulator: app URLSession request fails (-1009), traffic viewer stays connected, Mac browsing unaffected, OFF recovers, relaunch reconciles"
    verification: []
    human_judgment: true
    rationale: "Requires a booted iOS Simulator running a DEBUG app embedding BoosterSimConnect plus visual confirmation of the traffic viewer — not automatable in this harness (research marks e2e Connect verification manual-only)"

duration: 37min
completed: 2026-08-29
status: halted   # designed stop: Task 3 blocking-human Simulator smoke pending; flip to complete after approval
---

# Phase 5 Plan 01: Command Channel Tracer Summary

**Airplane Mode end-to-end slice: Network tab toggle → NetworkConditionService → CommandServer ("_booster-cmd._tcp.", loopback) → BoosterCommandClient → NetworkConditionController → BoosterNetworkProtocol failing URLSession requests; all 19 unit tests green, both targets build — halted at the blocking-human Simulator smoke.**

## Performance

- **Duration:** 37 min (15:37–16:14 UTC)
- **Started:** 2026-08-29T15:37:39Z
- **Completed:** 2026-08-29T16:14:36Z (Tasks 1–2)
- **Tasks:** 2 of 3 (Task 3 = human smoke, pending)
- **Files modified:** 17 (11 created, 6 modified; pbxproj intentionally untouched — synchronized groups)

## Accomplishments

- Full command channel: Mac-side `CommandServer` (NWListener, Bonjour `_booster-cmd._tcp.`, loopback-bound, reconcile-on-connect, malformed-frame connection drop) and framework-side `BoosterCommandClient` (NWBrowser → NWConnection, buffered length-prefixed JSON, reconnect restarts browsing)
- Enforcement chain in BoosterSimConnect: `NetworkConditionController` (NSLock snapshot store, version gate) + `BoosterNetworkProtocol` (URLSession init method-exchange chained with Pulse's, guard-marker anti-recursion, zero-overhead canInit when conditions off)
- Network tab `NetworkConditionsSectionView` with airplane toggle, state-machine status row, and honest URLSession-scope disclosure caption
- 19 Swift Testing cases across 3 suites, all passing (3 consecutive clean runs after the crash fix below)

## Task Commits

1. **Task 1: Airplane Mode end-to-end tracer** — `7a8da29` (feat)
2. **Task 2: State-machine, persistence, framing-robustness hardening** — `ea7b024` (test)
3. **Task 3: Live-Simulator smoke** — *pending human verification (blocking-human checkpoint)*

**Plan metadata:** (this commit)

## Files Created/Modified

- `BoosterSimApp/Models/BoosterCommand.swift` — payload schema, CommandFrame codec, pure `evaluate` decision function
- `BoosterSimApp/Models/BlockRule.swift` — string-ops-only rule matcher (no regex)
- `BoosterSimApp/Services/CommandServer.swift` — NWListener broadcast server, loopback bind
- `BoosterSimApp/Services/NetworkConditionService.swift` — @MainActor state machine + persistence + single-writer snapshots
- `BoosterSimApp/Views/SideWindow/network/NetworkConditionsSectionView.swift` — airplane toggle UI section
- `BoosterSimConnect/BoosterCommandClient.swift` — NWBrowser client with mirrored framing
- `BoosterSimConnect/NetworkConditionController.swift` — lock-protected snapshot store + schema mirrors
- `BoosterSimConnect/BoosterNetworkProtocol.swift` — URLProtocol enforcement + swizzle registration
- `NetworkTabView.swift` / `AppDelegate.swift` / `SideWindowController.swift` / `SideWindowView.swift` / `AppLogger.swift` / `BoosterSimConnect.swift` — wiring, environment injection, activation hooks

## Decisions Made

- **pbxproj not modified** — the project uses PBXFileSystemSynchronizedRootGroup; new files gain target membership automatically (verified by both target builds). The plan's pbxproj step is satisfied by the build itself.
- **Framework sources wrapped in `#if DEBUG && targetEnvironment(simulator)`** — the BoosterSimConnect folder is compiled by BOTH targets; the guard prevents duplicate `BoosterCommand` symbols in the macOS app module and mirrors the existing `BoosterSimConnect.swift` pattern.
- **`evaluateCondition` name on the framework mirror** — a free `evaluate` inside the controller collides with its own method (and `BoosterSimConnect` class name shadows the module qualifier); semantics stay identical to the Mac side.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Data-slice index trap in frame decoding (SIGTRAP crash)**
- **Found during:** Task 2 (two-frames-one-buffer test)
- **Issue:** `Data.removeFirst` can leave a non-zero `startIndex`; `subdata(in: 4..<N)` with raw offsets then traps (EXC_BREAKPOINT in `Data.subdata`). Crash report confirmed at `BoosterCommand.swift:87`. This is the exact trap PATTERNS.md/Pitfall 11 warned about from the connect-transport rewrite.
- **Fix:** Decode over a re-based `[UInt8]` copy before any offset math; remainder rebuilt as `Data(bytes[total...])`. Applied to both Mac `CommandFrame.decodeOne` and the framework mirror `BoosterCommandClient.decodeFrame` (schema-sync).
- **Files modified:** BoosterSimApp/Models/BoosterCommand.swift, BoosterSimConnect/BoosterCommandClient.swift
- **Verification:** 3 consecutive full-suite runs: 19/19 cases pass, 0 crashes (previously: intermittent suite wipeouts + crash reports)
- **Committed in:** ea7b024 (Task 2 commit)

**2. [Rule 1 - Bug] NWListener deallocated while started aborts the process**
- **Found during:** Task 2 (services dropped by unit tests)
- **Issue:** Test-created `NetworkConditionService`s release their `CommandServer` at test end; an `NWListener` deallocated without `cancel()` traps in Network.framework.
- **Fix:** `CommandServer.deinit` cancels listener and all connections.
- **Files modified:** BoosterSimApp/Services/CommandServer.swift
- **Verification:** Crash-at-dealloc no longer observed across 3 runs
- **Committed in:** ea7b024

**3. [Rule 3 - Blocking] Pre-existing test-host early-exit flake blocks exit-code-0 verification**
- **Found during:** Task 1 verification
- **Issue:** `xcodebuild … test` exits 65 with "Early unexpected exit … test runner exited with code 0 before establishing connection" for 3–5 post-test app launches. **Reproduced identically on pristine HEAD** (zero 05-01 changes, pre-existing `CertificateServiceTests` only) — environmental, out of plan scope. A separate real blocker (the script phase's *nested* fallback `xcodebuild` hitting a "Multiple commands produce" graph error) was resolved within scope by pre-building the BoosterSimConnect scheme so the copy phase takes its intended fast path.
- **Fix/Handling:** Suite-level green is demonstrated via per-case results (19/19 pass, 0 failures). Pre-existing flake logged to `deferred-items.md` for follow-up outside feature plans.
- **Files modified:** .planning/phases/05-network-tools/deferred-items.md
- **Verification:** Baseline-vs-change comparison runs captured in session output
- **Committed in:** docs commit (with SUMMARY)

---

**Total deviations:** 3 auto-fixed (2 Rule 1 bugs, 1 Rule 3 blocking-environment handling)
**Impact on plan:** Both Rule 1 fixes were correctness requirements (crash in the framing codec the whole phase depends on). No scope creep; no SPM changes (Package.resolved byte-identical, verified twice).

## Issues Encountered

- The plan's `xcodebuild test … exits 0` acceptance literal is not achievable on this machine even on pristine HEAD (see deviation 3). All 19 cases pass; 3 consecutive clean runs recorded.
- SideWindowView's `#Preview` also constructs `SideWindowController` — migrated as a caller (clean cutover) though the plan didn't name the file.

## Task 3 — Simulator Smoke (PENDING HUMAN VERIFICATION)

Prerequisites: BoosterSimApp running; a booted iOS Simulator with a DEBUG app embedding BoosterSimConnect that can trigger a URLSession request on demand.

| # | Step | Result |
|---|------|--------|
| 1 | App traffic appears in the traffic viewer (chained swizzle healthy) | ⏳ pending |
| 2 | Toggle Airplane Mode ON in the Network tab | ⏳ pending |
| 3 | Trigger a request in the app → fails with NSURLErrorNotConnectedToInternet, error row in viewer | ⏳ pending |
| 4 | Traffic viewer / connection banner stays connected while airplane is ON | ⏳ pending |
| 5 | Mac browser loads any website normally (no Mac impact) | ⏳ pending |
| 6 | Toggle Airplane Mode OFF → next app request succeeds | ⏳ pending |
| 7 | With airplane ON, relaunch the Simulator app → condition re-applies within ~1 s (reconcile) | ⏳ pending |

**Resume signal:** reply "approved" to unblock wave 2 (plans 02/03), or describe the failing step — a failure invalidates architecture assumption A3 and halts expansion for replan.

## User Setup Required

See plan frontmatter `user_setup`: a booted Simulator running a DEBUG app embedding BoosterSimConnect (loads `/Applications/Booster.app/Contents/Resources/BoosterSimConnect.framework`); BoosterSimApp must be running.

## Next Phase Readiness

- Engine complete and unit-proven; plans 02 (throttle) and 03 (block rules UI) are additive by design (`.throttle` verdict case, BlockRulesView).
- **Blocker:** Task 3 smoke must pass before wave 2 dispatch (plan resume-signal). ROADMAP plan-progress flip deliberately deferred until the smoke is approved (this SUMMARY records `status: halted`).
- Loopback-bind fallback: if smoke step 1/2 fails discovery/connect, plan 05-01 specifies falling back to default-interface bind + LAN-trust note (threat T-05-01 disposition change).

## Self-Check: PASSED

- All 11 key-files exist on disk (`[ -f ]` verified)
- Both commits present in git log (7a8da29, ea7b024)
- Task 1 acceptance greps: 12/12 PASS (mechanical checks in session log)
- Task 2 acceptance: framing type referenced by CommandServer ✓, two-frames + over-cap tests present ✓, tests green ✓
- Package.resolved byte-identical after both tasks ✓

---
*Phase: 05-network-tools — Plan: 01 (command channel tracer)*
*Completed (Tasks 1–2): 2026-08-29 — Task 3 awaiting human smoke*
