---
phase: 03-app-actions
plan: 01
subsystem: app-actions
tags: [simctl, swiftui, combine, derived-data, keychain, app-reset]

# Dependency graph
requires:
  - phase: 05-network-manipulation
    provides: CertificateService resetKeychain/reconcileStatus/install — the D-02 delegate path
  - phase: 01-foundation
    provides: SimCtlService seam, AppDelegate/SideWindowView wiring pattern, design tokens
provides:
  - Hardened SimCtlService seam — concurrent pipe drains (>64 KB deadlock fix), optional stdin, machine-wide serialized invocations; publisher signature unchanged
  - DerivedDataAppScanner (caseless enum, injectable root, DiscoveredApp with visible alternatives)
  - AppActionService facade — refreshApps reconcile, resetApp with A6 honest reinstall-degrade, uninstallApp, clearKeychain (D-02 delegate + automatic CA re-reconcile)
  - AppActionOperation state machine + pure simctl argv builders / listapps + launchctl parsers (nonisolated, unit-tested)
  - AppKeychainResetting protocol seam (CertificateService conforms for free)
  - AppPickerBar + AppResetSectionView mounted in ActionsTabView; AppLogger.actions category
  - Wave 0 suites: DerivedDataAppScannerTests + AppActionServiceTests (24 tests)
affects: [03-02 push/deep-links/privacy, 03-03 locale/location/clipboard, 03-04 defaults editor + action search]

actuals:
  tokens: 16880   # chars/4 over the realized diff (67,521 chars)
  tasks: 2        # of 3 — Task 3 is the blocking-human smoke, pending
  commits: 4      # TDD pairs, excluding the docs commit

tech-stack:
  added: []       # Apple frameworks only (REQ-nfr-03)
  patterns:
    - "Concurrent-pipe-drain subprocess executor (read-before-wait + DispatchGroup, resolve after exit AND both EOFs)"
    - "Serialized seam: static serial DispatchQueue — one simctl pipeline machine-wide"
    - "Protocol seam over an existing concrete service for testable delegate-order pinning (AppKeychainResetting)"
    - "Terminal-state observation chain: $operation.dropFirst().first { !$0.isWorking } → next phase"

key-files:
  created:
    - BoosterSimApp/Services/DerivedDataAppScanner.swift
    - BoosterSimApp/Services/AppActionService.swift
    - BoosterSimApp/Models/AppActionModels.swift
    - BoosterSimApp/Views/SideWindow/actions/AppPickerBar.swift
    - BoosterSimApp/Views/SideWindow/actions/AppResetSectionView.swift
    - BoosterSimAppTests/DerivedDataAppScannerTests.swift
    - BoosterSimAppTests/AppActionServiceTests.swift
  modified:
    - BoosterSimApp/Services/SimCtlService.swift
    - BoosterSimApp/Views/SideWindow/tabs/ActionsTabView.swift
    - BoosterSimApp/App/AppDelegate.swift
    - BoosterSimApp/Windows/SideWindowController.swift
    - BoosterSimApp/Views/SideWindow/SideWindowView.swift
    - BoosterSimApp/Utilities/AppLogger.swift

key-decisions:
  - "clearKeychain composes existing public CertificateService verbs (resetKeychain → reconcileStatus → install when a CA exists) — reconcileStatus alone is status-only and would never restore trust (D-02 smoke step 6 would fail)"
  - "AppKeychainResetting protocol + injected keychainEvents publisher — the plan's scripted-double test is impossible against the final concrete CertificateService; convenience init keeps the pinned AppDelegate call site unchanged"
  - "Scanner test fixtures are synthesized at runtime in temp dirs, not committed bundle resources — .app directories inside macOS test-bundle resources break codesign (nested-bundle validation)"
  - "AppActionOperation allows idle→error (unlike CertificateOperation) so typed destructive-UDID refusals are legal state transitions — unit-tested"
  - "Alternatives visibility: dedupe losers ride the winner as alternativePaths, surfaced via picker tooltip + a11y"

patterns-established:
  - "Extend-the-seam recipe for every Phase 3 verb: pure argv builder (nonisolated static) → [weak self] flatMap chain with 30s timeout → begin/finish/fail quartet"
  - "Honest-outcome captions as enum terminals (ResetOutcome) — a failed reinstall is a distinct state, never a success string"

requirements-completed: []   # REQ-roadmap-phase3-app-actions + REQ-fr-13 stay open until the Task 3 smoke is approved

coverage:
  - id: D1
    description: "DerivedData scanner contracts — iOS-only filter, mtime ordering, bundle-ID dedupe with visible alternatives, symlink collapse, corrupt-plist skip"
    requirement: REQ-roadmap-phase3-app-actions
    verification:
      - kind: unit
        ref: BoosterSimAppTests/DerivedDataAppScannerTests (8 tests)
        status: pass
    human_judgment: false
  - id: D2
    description: "AppActionService pure contracts — simctl argv builders, listapps/launchctl parsers, candidate reconcile, operation transitions incl. reentrancy rejection and destructive-UDID refusals"
    requirement: REQ-roadmap-phase3-app-actions
    verification:
      - kind: unit
        ref: BoosterSimAppTests/AppActionServiceTests (16 tests)
        status: pass
    human_judgment: false
  - id: D3
    description: "Reset-app end-to-end on a live Simulator — picker lists installed DerivedData apps with running badge; reset yields a fresh app; uninstall removes; repeated reset is idempotent; A6 reinstall-degrade caption is honest"
    verification: []
    human_judgment: true
    rationale: "Live device-state lifecycle (terminate/uninstall/install against a booted Simulator with real persisted state) — impossible to exercise headless"
  - id: D4
    description: "D-02 keychain wipe — blast-radius-naming typed confirmation, device-wide wipe, automatic CA re-reconcile with zero manual steps"
    requirement: REQ-roadmap-phase3-app-actions
    verification:
      - kind: unit
        ref: BoosterSimAppTests/AppActionServiceTests#clearKeychainDelegatesThenReconcilesExactlyOnce + 3 siblings (delegate order pinned on a scripted double)
        status: pass
    human_judgment: true
    rationale: "The unit run pins delegate order on a double; the destructive wipe against the real device keychain and the visual blast-radius gate need the human smoke (steps 5-6)"
  - id: D5
    description: "Seam survival of large outputs (33 KB listapps) + no-Simulator degraded state without crashes"
    verification: []
    human_judgment: true
    rationale: "Requires a booted Simulator producing a real listapps payload and a device shutdown/reboot cycle"

# Metrics
duration: 15min
completed: 2026-08-31
status: halted
---

# Phase 3 Plan 01: Reset-App Tracer Summary

**App Actions spine proven in code — hardened simctl seam (deadlock fix, stdin, serialization), DerivedData scanner, AppActionService facade, app picker + reset section, D-02 keychain clear delegating to CertificateService — halted at the blocking-human live smoke (Task 3).**

## Performance

- **Duration:** 15 min (03:30–03:46 UTC)
- **Started:** 2026-08-31T03:30:50Z
- **Completed:** 2026-08-31T03:46:13Z (automation portion)
- **Tasks:** 2 of 3 (Task 3 = blocking-human checkpoint, pending user)
- **Files modified:** 13 (7 created, 6 modified)

## Accomplishments
- SimCtlService hardened with zero call-site changes: stdout+stderr drain concurrently with process exit (the >64 KB pipe deadlock behind a 33 KB listapps is structurally gone), optional `stdin: Data?` for `push <udid> -`, and a machine-wide serial invocation queue
- DerivedDataAppScanner: injectable-root caseless enum scanning `*/Build/Products/*-iphonesimulator/*.app`, plist parse, symlink-before-dedupe resolution, newest-wins per bundle ID with alternatives retained
- AppActionService facade in the CertificateService shape: refreshApps (scan ∩ listapps ∩ launchctl badge), resetApp (terminate → presence check → uninstall → DerivedData reinstall with honest A6 degrade), uninstallApp, clearKeychain — every destructive verb refuses empty/`booted` UDIDs (unit-tested)
- D-02 keychain clear: single wipe call site inside a blast-radius-naming destructive confirmation; delegates to `CertificateService.resetKeychain` then automatically reconciles AND re-installs the local CA
- Wave 0 suites green: 24 new tests; full unit bundle **107/107** (baseline 83 + 24) — zero regressions; Debug build clean

## Task Commits

Each task was committed atomically (TDD pairs):

1. **Task 1 (tracer) RED:** `ebffaf7` — test(03-01): Wave 0 scanner + app action service tests
2. **Task 1 (tracer) GREEN:** `7fd9de8` — feat(03-01): reset-app tracer (seam + scanner + service + views + wiring)
3. **Task 2 RED:** `7242874` — test(03-01): D-02 keychain clear + reconcile delegate-order tests
4. **Task 2 GREEN:** `daefdc3` — feat(03-01): D-02 destructive keychain clear with automatic CA re-reconcile

**Tracer feedback gate:** re-ran the tracer `<verify>` post-commit (targeted suites 19/19 + Debug build) — passed; continued to expansion per end-of-phase mode.

**Task 3:** `checkpoint:human-verify gate="blocking-human"` — STOPPED; awaiting the live Simulator smoke (never auto-run: D-02 wipes a real device keychain).

**Plan metadata:** see docs commit below.

## Files Created/Modified
- `BoosterSimApp/Services/SimCtlService.swift` — concurrent drains + stdin + serialized invocations (signature-compatible)
- `BoosterSimApp/Services/DerivedDataAppScanner.swift` — pure FS scanner + DiscoveredApp
- `BoosterSimApp/Services/AppActionService.swift` — state-machine facade (252 LOC)
- `BoosterSimApp/Models/AppActionModels.swift` — AppActionOperation, ResetOutcome, argv builders, parsers, AppKeychainResetting
- `BoosterSimApp/Views/SideWindow/actions/AppPickerBar.swift` — candidate pills, running badge, explicit selection
- `BoosterSimApp/Views/SideWindow/actions/AppResetSectionView.swift` — reset/uninstall/keychain sections with destructive confirms
- `BoosterSimApp/Views/SideWindow/tabs/ActionsTabView.swift` — VStack shell + picker pinned top + refresh triggers
- `BoosterSimApp/App/AppDelegate.swift`, `BoosterSimApp/Windows/SideWindowController.swift`, `BoosterSimApp/Views/SideWindow/SideWindowView.swift` — construction + environment injection
- `BoosterSimApp/Utilities/AppLogger.swift` — actions category
- `BoosterSimAppTests/DerivedDataAppScannerTests.swift`, `BoosterSimAppTests/AppActionServiceTests.swift` — Wave 0

## Decisions Made
- See key-decisions in frontmatter; all were forced by live constraints (reconcileStatus being status-only, codesign vs nested .app resources, final-CertificateService testability) and stay inside the plan's architecture.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] GitNexus MCP unavailable — impact analysis substituted**
- **Found during:** Task 1 read_first
- **Issue:** The plan's `gitnexus_impact` pre-edit step could not run (no GitNexus MCP in this runtime)
- **Fix:** grep-based blast radius over `simCtl.run|SimCtlService()`: direct callers = EnvironmentOverrideService (~20 call sites incl. the ~11-parallel defaults burst), CertificateService (runSimCtl), StatusBarService; DeepLinkService/NetworkConditionService use no seam. Risk: compile-none (optional-param signature), runtime-medium (serialization queues the defaults burst — flagged assumption accepts this). All five consumers compile + their suites green (107/107)
- **Files modified:** none (analysis only)
- **Verification:** full unit bundle + Debug build
- **Committed in:** n/a

**2. [Rule 3 - Blocking] Wiring needed SideWindowController + SideWindowView body edits (files absent from plan list)**
- **Found during:** Task 1 implementation
- **Issue:** The `.environmentObject` chain lives in `SideWindowController.embedSwiftUIContent`, not SideWindowView's body; passing appActionService "into sideWindowController" requires its init + embed signature change
- **Fix:** Added `appActionService` parameter through init/embed/environment chain; SideWindowView passes `deviceName` to ActionsTabView (dialogs name the device; the CA re-install persisted record wants it)
- **Files modified:** SideWindowController.swift, SideWindowView.swift, ActionsTabView.swift
- **Verification:** Debug build + previews compile
- **Committed in:** 7fd9de8

**3. [Rule 2 - Missing Critical] clearKeychain also re-installs the CA, not just reconcileStatus**
- **Found during:** Task 2 implementation
- **Issue:** `reconcileStatus` is status-only (reads persisted records; runs no simctl verb) — the plan's literal wording would leave trust broken and fail smoke step 6
- **Fix:** Terminal-of-reset → reconcileStatus → `install(udid:deviceName:)` when a CA exists; honest captions per branch. Still pure delegation — zero keychain argv in AppActionService
- **Files modified:** AppActionService.swift, AppActionModels.swift (protocol adds status/install)
- **Verification:** clearKeychainReinstallsTheCAWhenOneExists + 3 sibling tests
- **Committed in:** daefdc3

**4. [Rule 1 - Bug] refreshApps parsed the launchctl output as listapps XML**
- **Found during:** Task 2 self-review (before any live run)
- **Issue:** installedBundleIDs was assigned from the second hop's output — every parse returned an empty set; the picker would never list anything
- **Fix:** Parse listapps XML inside the first flatMap; parse launchctl in receiveValue
- **Files modified:** AppActionService.swift
- **Verification:** parse-contract unit tests pin both parsers
- **Committed in:** daefdc3

**5. [Rule 3 - Blocking] Test fixtures synthesized at runtime, not committed bundle resources**
- **Found during:** Task 1 test authoring
- **Issue:** A `.app` directory inside macOS test-bundle resources is a nested bundle — codesign rejects it; synchronized-group resource handling of directory trees is also unreliable
- **Fix:** Fixture DerivedData tree built in a unique temp dir per test (same scenarios: two bundles, duplicate-ID loser, macOS/universal dirs, corrupt plist, missing CFBundleName, symlink alias); scanner injectivity is the actual contract
- **Files modified:** DerivedDataAppScannerTests.swift
- **Verification:** 8/8 scanner tests green
- **Committed in:** ebffaf7 / 7fd9de8

**6. [Design] AppActionService.swift at 252 LOC (house target <200)**
- Task 1's acceptance criterion (≤200) held at its commit (196 lines). Task 2's keychain cluster grew the file; a cross-file split would force de-privatizing the facade's state (extensions can't touch private members). House precedent: CaptureService 312. Noted for the code review gate.

**7. [Process] Windows ledger not appended**
- `.planning/WINDOWS.md` is user-dirty and was marked untouched by the orchestrator; the pending smoke is instead tracked here (status: halted) + STATE blocker + ROADMAP 03-01 unchecked.

---

**Total deviations:** 7 auto-fixed/documentated (1 bug, 2 missing-critical/blocking, 3 blocking-process, 1 design note)
**Impact on plan:** All within the planned architecture; no scope creep. Deviations 2-3 were load-bearing for the plan's own success criteria.

## Issues Encountered
- Several edit-tool boundary repairs during implementation produced duplicated/dropped lines (AppDelegate deepLinkService, scanner guards, SideWindowView preview, SimCtlService properties, view activeUDID, the dropped `.first{}` operator) — every one was caught by the next compile and fixed; the `.first{}` drop was additionally caught by the failing delegate-order tests before commit. Final state verified green.

## User Setup Required

**Task 3 smoke needs (from the plan's user_setup):**
1. One booted iOS Simulator with a non-Apple app built from Xcode into DerivedData, installed, carrying visible persisted state (log in / set a preference)
2. BoosterSimApp local CA generated + installed (Network tab → Certificates) to prove the D-02 reconcile
3. BoosterSimApp running with the side panel on the Simulator

## Next Phase Readiness
- Plans 02-04 ride the proven seam additively (push needs the already-shipped stdin parameter; privacy/locale/location/clipboard/defaults need only new argv builders + sections)
- **Blocker:** Task 3 blocking-human smoke pending — approve via the 7-step checklist (picker accuracy, reset freshness, idempotent repeat, A6 degrade honesty, D-02 blast-radius dialog + automatic CA re-trust, degraded no-simulator state) before wave 2 dispatches
- On approval: re-summarize as complete + roadmap 03-01 checked; on failure of the reinstall leg (A6), keep the degrade path and file the note

## Self-Check: PASSED
- All 7 created files exist on disk; all 6 modified files changed as listed (git show --stat per commit)
- Commits ebffaf7, 7fd9de8, 7242874, daefdc3 present on main
- Full unit bundle 107/107 exit 0; Debug build exit 0; every Task 1/2 acceptance criterion grep-verified

---
*Phase: 03-app-actions — Plan: 01 (reset-app tracer)*
*Status: halted at blocking-human smoke — 2026-08-31*
