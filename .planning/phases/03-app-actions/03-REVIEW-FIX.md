---
phase: 03-app-actions
fixed_at: 2026-08-31T07:25:00Z
review_path: .planning/phases/03-app-actions/03-REVIEW.md
iteration: 1
findings_in_scope: 8
fixed: 8
skipped: 0
status: all_fixed
---

# Phase 03: Code Review Fix Report

**Fixed at:** 2026-08-31T07:25:00Z
**Source review:** .planning/phases/03-app-actions/03-REVIEW.md
**Iteration:** 1
**Mode:** main-tree (workflow.use_worktrees = false)

**Summary:**
- Findings in scope: 8 (CR-01 + WR-01..WR-07)
- Fixed: 8
- Skipped: 0

## Fixed Issues

### CR-01: Reset App Data aborts its chain when the target app is not running

**Files modified:** `BoosterSimApp/Services/AppActionService.swift`, `BoosterSimApp/Services/SimCtlService.swift`, `BoosterSimAppTests/AppActionServiceTests.swift`, `BoosterSimAppTests/ScriptedSimCtl.swift` (new)
**Commit:** 6d52d27
**Applied fix:** terminate-failure catch now emits `Just("")` instead of `Empty`, so the chain continues into the listapps presence check; the facade stores `any SimCtlRunning` so tests drive the real chain. Two regression tests (scripted double): terminate-fail → uninstall leg runs and finishes `.idle`; terminate-fail + app missing → honest `.absent` caption, no uninstall.

### WR-01: City-preset caption claims automatic relaunch when none happens

**Files modified:** `BoosterSimApp/Services/AppActionService.swift`, `BoosterSimApp/Views/SideWindow/actions/LocationSectionView.swift`
**Commit:** 849151a
**Applied fix:** caption and log branch on `bundleID` — "…takes effect on every app's next launch." with no relaunch clause when no app is active; the view's `relaunchCaption` text branches on `activeApp != nil`.

### WR-02: Defaults editor drops reloads while loading / shows stale domain rows

**Files modified:** `BoosterSimApp/Services/UserDefaultsEditorService.swift`, `BoosterSimAppTests/UserDefaultsEditorServiceTests.swift`, `BoosterSimAppTests/ScriptedSimCtl.swift`
**Commit:** a8bc243
**Applied fix:** `loadDomain` during `.loading` records `pendingLoad` (newest target supersedes); `startLoad` clears `entries` and `loadError` up front; stale results/failures are skipped, never published. Two regression tests use gated scripted container loads with real fixture plists (A→B supersede; clear-at-start).

### WR-03: Seam stdin write before drains / unbounded drain wait

**Files modified:** `BoosterSimApp/Services/SimCtlService.swift`, `BoosterSimAppTests/SimCtlServiceTests.swift` (new)
**Commit:** a845f3b
**Applied fix:** `run(_:stdin:)` rejects payloads over the 64 KB pipe bound (`SimCtlLimits.maxStdinBytes`) with typed `SimCtlError.stdinTooLarge` before any subprocess; the stdin write joins the drain group on a concurrent lane after the readers start; `drainGroup.wait()` bounded at 60 s with a lock-guarded exactly-once promise. Also introduced the `SimCtlRunning` protocol (test seam) — consumed by CR-01/WR-02 tests.

### WR-04: Push editor silently strips custom APNs keys

**Files modified:** `BoosterSimApp/Models/PushPayload.swift`, `BoosterSimAppTests/PushPayloadTests.swift`
**Commit:** 02f7938
**Applied fix:** picked reject (safer, honest) over passthrough — `parse` compares key sets before decode and fails with typed `.unsupportedKeys([String])` (sorted offending names); three new tests: unknown aps key, unknown top-level key, full supported set accepted.

### WR-05: readLocaleState and openInSimulator lack the house 30s timeout

**Files modified:** `BoosterSimApp/Services/AppActionService.swift`, `BoosterSimApp/Services/DeepLinkService.swift`
**Commit:** b8cd888
**Applied fix:** the three global-domain reads route through a shared `readLocaleKey` helper with `.timeout(.seconds(30))` + failure caption; `openInSimulator` arms the same timeout so a hung openurl surfaces in `lastResult` instead of starving silently.

### WR-06: clearKeychain's CA-install leg can wedge the machine; unconditional success log

**Files modified:** `BoosterSimApp/Services/AppActionService.swift`, `BoosterSimAppTests/AppActionServiceTests.swift`
**Commit:** 1e5b050
**Applied fix:** both keychainEvents waits arm a 30s timeout (`.setFailureType(SimCtlError.self)` + `.timeout`) → fallback caption through `finish()`, so `.clearingKeychain` can never wedge permanently; the "Keychain clear finished" log moved into the outcome branches. The existing keychain tests became async + main-queue pumps because the timeout operator makes delivery asynchronous.

### WR-07: Test-only chain builders duplicate the production chains

**Files modified:** `BoosterSimApp/Services/AppActionService.swift`, `BoosterSimAppTests/LocaleCommandTests.swift`
**Commit:** 8d4f1b7
**Applied fix:** composed (as directed): new `localeWriteChain(languages:locale:timezone:udid:bundleID:)` is the single source of truth; `localePresetChain` delegates to it and `applyLocale` runs it via a shared `runChain`; `applyLocationPreset` runs `cityPresetChain` directly. `fallbackRelaunchArgs` — no production consumer — was deleted together with its tautological test.

## Skipped Issues

None — all in-scope findings were fixed.

## Verification

- Full unit gate (final): `xcodebuild -project BoosterSimApp.xcodeproj -scheme BoosterSimApp -destination platform=macOS test -only-testing:BoosterSimAppTests -skip-testing:BoosterSimAppUITests` → exit 0, **189 passed / 0 failed** (182 baseline + 8 new regression tests − 1 deleted tautological test). Gates ran in the **main checkout** (no worktree; `workflow.use_worktrees: false`).
- Debug build: `xcodebuild -configuration Debug build` → exit 0, BUILD SUCCEEDED.
- Per-finding: every fix landed behind a green incremental gate run before its commit.
- UI tests untouched; the pre-existing full-suite exit-65 behavior not chased.
- Logic-bearing fixes (CR-01, WR-02, WR-06) flagged for human verification in 03-REVIEW.md's resolution note; CR-01/WR-02 carry regression tests, WR-06's 30s arms are compile+suite covered only.

---

_Fixed: 2026-08-31T07:25:00Z_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_
