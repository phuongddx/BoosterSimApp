---
title: Code Review — Certificate Trust Management Implementation
reviewer: code-reviewer
date: 2026-04-07
files:
  - CertificateModels.swift (95 LOC)
  - CertificateService.swift (181 LOC)
  - CertificateStore.swift (175 LOC)
  - CertificateSectionView.swift (177 LOC)
  - AppDelegate.swift (diff: +2 lines)
  - SideWindowController.swift (diff: +13 lines)
  - SideWindowView.swift (diff: +12 lines)
verdict: DONE_WITH_CONCERNS
---

# Code Review: Certificate Trust Management

## Scope

- 4 new files (628 LOC), 3 modified files (27 LOC diff)
- Build: succeeds cleanly, zero warnings
- Tests: `CertificateServiceTests.swift` — 2 tests covering state machine transitions and metadata extraction
- Prior scout report: `code-reviewer-0407-2150-cert-trust-failure-modes.md` (8 findings at plan stage)

## Overall Assessment

Well-structured implementation. Prior plan-stage findings were largely addressed: atomic staged writes with backup/rollback, `umask(0o077)` for key protection, 30s timeouts on all Process ops, `lastFailedAction` tracking for retry, `udidProvider`/`deviceNameProvider` closures instead of captured values, `"booted"` rejection, `.unknown` state with honest user messaging. Remaining concerns are real but non-blocking for an initial release.

---

## Critical Issues

### C1: `currentProcess` race — mutable shared state on non-isolated class

**File:** `CertificateStore.swift:8`

`CertificateStore` is a plain `final class` (no `@MainActor`, no isolation). It owns `private var currentProcess: Process?` which is read/written inside `runOpenSSL()` running on `workQueue`, but also accessed from `workQueue.async` blocks in `generate()`. Two concurrent `generate()` calls from `CertificateService` (which IS `@MainActor` but dispatches async) could interleave:

1. Call A enters `runOpenSSL()`, sets `currentProcess = processA`
2. Call B enters `runOpenSSL()`, sets `currentProcess = processB` (overwrites A)
3. Call A finishes, sets `currentProcess = nil` — B's reference is lost

In practice, the `CertificateService.begin()` guard prevents this today since `operation.isWorking` blocks re-entry. But `CertificateStore` makes no such guarantee itself — it exposes `generate()` as a public method with no internal serialization beyond the single `workQueue`. If `CertificateStore` is ever called from two `CertificateService` instances or directly, the race manifests.

**Severity:** Critical in principle, mitigated today by `CertificateService` re-entry guard. The `currentProcess` property appears to be unused externally (no cancellation API) — it is dead code that introduces a race.

**Fix:** Either remove `currentProcess` (it is never read outside `runOpenSSL`), or mark the entire class `@MainActor` and dispatch to background explicitly, or add `@unchecked Sendable` with internal lock documentation.

### C2: `reconcileStatus` sets `.unknown` when cert *is* correctly installed — inverted logic

**File:** `CertificateService.swift:127-133`

```swift
guard let udid,
      defaults.string(forKey: StorageKey.installedFingerprint) == metadata.sha256,
      defaults.string(forKey: StorageKey.installedUDID) == udid else {
    status = .generated(...)  // branch: fingerprints DON'T match
    return
}
status = .unknown(..., reason: "Cert trust state uncertain. Reinstall to confirm.")
```

When the persisted fingerprint AND udid both match the current cert on disk, the code sets `.unknown` (uncertain). When they DON'T match, it sets `.generated` (certain). This is logically inverted:

- **Fingerprint + UDID match** = "we previously installed this exact cert into this exact device" = highest confidence state = should be `.installed` (or at least not `.unknown`)
- **No match** = "cert exists on disk but we don't know if it was installed" = uncertain = should be `.unknown`

The current code means every app relaunch with a previously-installed cert shows "Cert trust state uncertain" to the user, even when the install was successful and nothing changed. This is the OPPOSITE of what the prior scout report recommended (Finding 4: be honest about uncertainty). The uncertainty exists in ALL cases (you can't verify sim keychain state), so showing `.unknown` when fingerprints match is misleading — it's actually the BEST-case scenario.

**Impact:** UX confusion. User sees "uncertain" after a successful install + relaunch, and "generated" (no warning) when the cert was never installed. The user messaging is backwards.

**Fix:** When fingerprints + UDID match, return `.installed` with a note that trust state is best-effort. When they don't match, return `.unknown` with the uncertain messaging. Or, if `.installed` is reserved for verified state only, at minimum swap the messaging so the "uncertain" warning appears when there is NO install record, not when there IS one.

---

## High Priority

### H1: `retry()` with `lastFailedAction == nil` and `udid == ""` silently calls `reconcileStatus`

**File:** `CertificateService.swift:102-117`, `CertificateSectionView.swift:167`

When `operation == .error` and the user clicks "Retry", the view calls:
```swift
certService.retry(udid: activeUDID ?? "", deviceName: deviceNameProvider())
```

If `activeUDID` is nil (no simulator selected), this passes `udid: ""`. In `retry()`, when `lastFailedAction == nil` (no prior failure recorded — can happen if app relaunched with stale `.error` state), it calls `reconcileStatus(udid: nil)` which is fine. But when `lastFailedAction == .install` and `activeUDID == nil`, it calls `install(udid: "", deviceName: ...)` which hits the `guard !udid.isEmpty` check and calls `fail(.noUDIDSelected)`. The error replaces the current error — the user sees "No active Simulator selected" but the retry action is consumed. On next retry, `lastFailedAction` is now nil (cleared by `fail()` path? No — `fail()` does NOT clear `lastFailedAction`).

Wait — actually `fail()` at line 147-151 does NOT clear `lastFailedAction`. It only clears on `finish()` (line 143). So the retry cycle is: user clicks retry with no sim -> fail(.noUDIDSelected) -> lastFailedAction still set -> user can retry again. This works, but the UX is confusing: the error message changes from the original error to "No active Simulator selected".

**Severity:** High — degraded UX in edge case, but no data corruption.

**Fix:** Guard in `primaryAction()` — when retry is triggered and `activeUDID == nil` and `lastFailedAction` requires a UDID, show inline message or disable retry button.

### H2: `rotate()` — two nested async operations share a single `cancellables` set

**File:** `CertificateService.swift:62-85`

`rotate()` calls `runSimCtl` (keychain reset) which stores its AnyCancellable in `self.cancellables`. On success, it calls `store.generate` then another `runSimCtl` (add-root-cert). Each `runSimCtl` call stores into the same `cancellables` set. If the user triggers a second operation after the first `runSimCtl` succeeds but before the second completes, the `begin(.rotating)` guard catches it. However, deallocation of the outer cancellable does not cancel the in-flight Process — only the Combine subscription is dropped.

Additionally, the inner `runSimCtl` at line 76 captures `retryAction: .rotate` — if this inner call fails, `lastFailedAction` is set to `.rotate`, and `retry()` will re-enter `rotate()` from the top, which resets keychain + regenerates + reinstalls. This is correct behavior but expensive.

**Severity:** High — no resource leak or corruption, but the nested async chain is complex and fragile for future changes.

**Fix:** Consider breaking `rotate()` into discrete steps tracked by a state enum (e.g., `RotationStep.resetting, .generating, .installing`) to flatten the nesting.

### H3: `SimCtlService.run()` has its own Process with no timeout

**File:** `SimCtlService.swift:34-72`

The `CertificateService.runSimCtl` adds a 30s Combine timeout on the publisher, but `SimCtlService.run()` itself calls `proc.waitUntilExit()` on a background thread with no Process-level timeout. If `xcrun simctl` hangs, the Combine timeout fires and delivers `.timeout` error — but the underlying `Process` is never terminated. It becomes a zombie, holding any file descriptors or locks.

**Severity:** High — zombie processes accumulate if simctl hangs.

**Fix:** `SimCtlService` should implement its own timeout+terminate pattern (like `CertificateStore.runOpenSSL` does). Or `CertificateService` should use a different mechanism to cancel the underlying Process on timeout.

---

## Medium Priority

### M1: `umask` is process-global — mutates across all threads during `runOpenSSL`

**File:** `CertificateStore.swift:80-81`

```swift
let oldMask = umask(0o077)
defer { umask(oldMask) }
```

`umask()` is a per-process, thread-unsafe syscall. If another thread creates a file between these two lines, it gets the restrictive mask. This is a known pattern on macOS and the window is tiny (between `Process.run()` and the first write), but it is technically a data race.

**Fix:** The staged directory approach (writing to a 0700 temp dir) already provides the same protection. The `umask` call is defense-in-depth — acceptable, but document the thread-safety caveat.

### M2: `redactPaths` only redacts `certsDirectoryURL.path` and `NSHomeDirectory()`

**File:** `CertificateStore.swift:60-65`

If `TMPDIR` or other temp paths appear in error messages from openssl or simctl, they leak the user's home directory path. The `/tmp` symlink on macOS resolves to `/private/var/folders/XX/...` which includes a per-user random component — lower risk, but still a path leak.

**Fix:** Also redact `/private/var/folders` or any path containing the username.

### M3: `CertificateMetadata` and `CertificateStatus` are not `Sendable`

**File:** `CertificateModels.swift`

Under Swift 6 strict concurrency, these types cross isolation boundaries (created on background queue in `CertificateStore`, consumed on `@MainActor` in `CertificateService`). The build succeeds because they are value types (struct/enum) which are implicitly `Sendable` in Swift 6. No action needed, but worth confirming the project's concurrency mode.

### M4: `CertificateSectionView` — `.disabled` state doesn't prevent programmatic action calls

**File:** `CertificateSectionView.swift:113`

The `primaryButton` uses `.disabled(isWorking || ...)` but the `primaryAction()` function has no guard. If `certService.generateCA()` is called programmatically (e.g., from a keyboard shortcut), it bypasses the UI disabled state. The service-level `begin(.generating)` guard catches this, so no double-invocation, but it's defense-in-depth to add the guard in `primaryAction()`.

### M5: Tests are minimal — 2 tests for 628 LOC

**File:** `CertificateServiceTests.swift`

Only `CertificateOperation.canTransition` and `CertificateStatus.certificateMetadata` are tested. No tests for:
- `CertificateService.generateCA/install/rotate/resetKeychain` flows
- `CertificateStore` file operations, permissions, atomic writes
- `reconcileStatus` state transitions
- `retry()` logic
- Error path handling

**Severity:** Medium — acceptable for MVP, but the state machine and file I/O paths are complex enough to warrant integration tests.

---

## Low Priority

### L1: `CertificateOperation.canTransition` allows `.idle -> .idle`

**File:** `CertificateModels.swift:48`

The transition `.idle -> .idle` is valid. `finish()` calls `transition(to: .idle)` from a working state, which is correct. But if `begin()` or another path accidentally transitions `.idle -> .idle`, no assertion fires. Minor — not a bug, just a loose guard.

### L2: Magic string "BoosterSim CA" in openssl subj and in `readMetadata` fallback

**File:** `CertificateStore.swift:76,109`

The CN "/CN=BoosterSim CA" is hardcoded in the openssl command and also as the fallback in `SecCertificateCopySubjectSummary`. If the openssl subject format changes, the fallback masks the discrepancy.

### L3: View uses `@EnvironmentObject` without `@MainActor` isolation annotation

**File:** `CertificateSectionView.swift`

SwiftUI views are implicitly `@MainActor`, so this is fine. Noted for completeness.

---

## Prior Scout Report Status

| Finding | Status |
|---------|--------|
| F1: udid captured at construction | FIXED — closures used |
| F2: "booted" fallback | FIXED — explicit rejection |
| F3: Partial-write corruption | FIXED — staged writes + backup/rollback |
| F4: `.installed` unverifiable post-launch | ADDRESSED — `.unknown` state with honest message (but logic inverted — see C2) |
| F5: No Process timeout | FIXED — 30s timeout with `DispatchWorkItem` |
| F6: No `lastFailedAction` tracking | FIXED — `RetryAction` enum |
| F7: `.error` blocks retry | FIXED — `retry()` transitions to `.idle` first |
| F8: Concurrent generate spam | MITIGATED — `begin()` guard, but `CertificateStore` itself has no serialization |

---

## Positive Observations

1. **Security hygiene is strong:** `umask(0o077)`, 0600 perms on key+cert, backup exclusion on certs dir, path redaction in all error messages, 30s Process timeout with `terminate()`.
2. **Atomic file writes:** Staged directory with UUID, then move into place with backup/rollback on failure. Correctly handles crash mid-write.
3. **State machine design:** `canTransition` guards with `assertionFailure` catch illegal states in debug. Clean separation of `status` (persistent) and `operation` (transient).
4. **Closure-based providers:** `udidProvider` and `deviceNameProvider` avoid stale-capture bugs when switching simulators.
5. **Reconcile on sim switch:** `SideWindowController` subscribes to `activeSimulator` changes and calls `reconcileStatus`, keeping cert state consistent with device context.
6. **Consistent with existing patterns:** Follows project conventions — `@MainActor`, Combine publishers, `@EnvironmentObject` injection, `CollapsibleSection`, `DesignTokens`.

---

## Recommended Actions

1. **C2 (inverted reconcile logic):** Fix before merge. Swap `.unknown` and `.generated` branches in `reconcileStatus` or adjust the `.unknown` messaging to reflect that this is actually the best-known state.
2. **C1 (currentProcess race):** Remove `currentProcess` property — it is dead code (no cancellation API reads it). Eliminates the race entirely.
3. **H3 (zombie simctl processes):** Add Process-level timeout to `SimCtlService.run()` or track the Process for termination on Combine timeout.
4. **M5 (test coverage):** Add integration tests for at minimum: generate+install happy path, rotate flow, reconcile after relaunch, retry after error.

---

## Metrics

- Type Coverage: Full (all types used, Swift 6 strict concurrency)
- Test Coverage: ~3% of new code (2 tests for 628 LOC)
- Build: Clean, zero warnings
- Linting: N/A (no linter configured)
- LOC per file: All under 200 LOC target

---

## Unresolved Questions

1. What should `.unknown` actually mean? Currently it fires when fingerprints+UDID match (highest confidence). The naming suggests uncertainty but the condition suggests confidence. Recommend clarifying the semantic intent.
2. Is `CertificateStore` intended to be a singleton per `CertificateService`? If so, document the 1:1 lifetime contract.
3. Should `SimCtlService` be extended with Process-level timeouts, or should the caller (`CertificateService`) handle Process lifecycle?
4. What happens if the user clicks "Reinstall" while a cert IS actually installed and trusted? `simctl keychain add-root-cert` is idempotent in practice, but is this guaranteed by Apple?

---

**Status:** DONE_WITH_CONCERNS
**Summary:** Well-implemented feature with strong security hygiene. Two issues need attention: inverted `.unknown`/`.generated` logic in `reconcileStatus` (C2 — user sees wrong messaging), and dead `currentProcess` property introducing a theoretical race (C1 — remove it). The prior scout report's 8 findings are all addressed or mitigated.
