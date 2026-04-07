---
title: Hostile Review — Certificate Trust Management Plan
reviewer: code-reviewer (Failure Mode Analyst)
date: 2026-04-07
plan: plans/0407-2141-certificate-trust-management/
verdict: REJECT — multiple Critical race/state-leak holes
---

# Hostile Review: Certificate Trust Management Plan

Scope: plan.md + phase-01 + phase-02 + phase-03. No code yet.

Findings rated by failure-mode severity. 8 findings, all blocking or near-blocking.

---

## Finding 1: `udid` captured at view-construction time leaks across Simulator switches

- **Severity:** Critical
- **Location:** Phase 3, "Step 3: Modify SideWindowView.swift" + Phase 2, "Struct signature"
- **Flaw:** `CertificateSectionView` takes `udid` and `deviceName` as `let` properties at construction. The single `CertificateService` is a singleton owned by `AppDelegate`. The user can switch the active Simulator at any time. There is no binding of operation → originating udid inside the service.
- **Failure scenario:**
  1. User selects iPhone 15 (udid=A), clicks "Install to Simulator". `operation = .installing`, simctl call dispatched against udid A on a background queue.
  2. While the install is in flight (~2s on cold simctl), user switches active Simulator to iPad Air (udid=B). `SideWindowView` re-renders; `activeUDID` changes; SwiftUI reconstructs `CertificateSectionView` with `udid=B`.
  3. The in-flight simctl callback (still bound to udid A) returns success and writes `status = .installed(cn, expiry, deviceName: "iPhone 15")`.
  4. UI now claims iPad Air has the cert installed. It does not. User tests cert pinning against iPad and is baffled.
- **Evidence:** Phase 1 §Architecture: `install(udid:, deviceName:)` is a single method on a singleton; `@Published status` has no per-device dimension. Phase 3 line 104: `udid: activeUDID ?? "booted"` — value-typed snapshot, no observation.
- **Suggested fix:** Either (a) key state by udid: `@Published var statusByUDID: [String: CertStatus]`, or (b) attach the originating udid to every in-flight op and discard the result if it no longer matches the active device, AND clear `operation` on switch. Option (a) is correct; (b) is a band-aid.

---

## Finding 2: `"booted"` fallback can install the cert into the wrong Simulator

- **Severity:** Critical
- **Location:** Phase 3, "Step 3" line 104 — `udid: activeUDID ?? "booted"`
- **Flaw:** `simctl keychain booted add-root-cert` resolves to whichever Simulator the OS considers "booted" — which may be a Simulator the user is NOT looking at. With multiple Simulators booted (the app's whole premise — it tracks multiple), `booted` is non-deterministic and resolves to the first booted device simctl finds.
- **Failure scenario:** User has iPhone 15 + iPad Air both booted. App's tracker hasn't yet attached an `activeUDID` (race on launch). User clicks "Install". simctl installs the cert into iPad Air (first in list). UI shows "installed on Simulator". User believes iPhone 15 is configured. Cert pinning tests against iPhone 15 fail mysteriously.
- **Evidence:** Phase 3 line 104, plus Phase 1 §Functional #3 explicitly says "into booted Simulator" without binding to an identity.
- **Suggested fix:** Disable the Install button entirely when `activeUDID == nil`. Never pass `"booted"` to a destructive simctl call. Show "No active simulator" empty state.

---

## Finding 3: Partial-write corruption — `ca.key` written, openssl crashes before `ca.pem`

- **Severity:** High
- **Location:** Phase 1, "openssl Command" + step 7 `generateCA()`
- **Flaw:** openssl writes `-keyout` and `-out` to two distinct files. If openssl crashes, is killed (SIGTERM on app quit), or is OOM-killed between writing the key and writing the cert, the disk is left with `ca.key` and no `ca.pem`. On next launch, `checkStatusOnInit` checks `caCertURL.exists` only — sees missing pem, returns `.notGenerated`. User clicks Generate again. `openssl req -x509 -keyout ca.key` overwrites the existing key — silently. Any cert that was actually installed in a Simulator from the prior key is now orphaned: the trust store still trusts the old key's cert, but the on-disk key no longer matches anything. User can never `Reset Keychain` to clean it up unless they remember to.
- **Failure scenario:** User generates CA, installs into Simulator. App quits during a second generate (rare but possible). Stale `ca.key` remains. User reopens, regenerates. Old cert remains trusted in the Simulator with no corresponding on-disk artifact — undetectable from the app.
- **Evidence:** Phase 1 step 6 only checks `caCertURL` existence; never validates pair integrity. No atomic write strategy. No tempdir → rename.
- **Suggested fix:** Write to `ca.key.tmp` + `ca.pem.tmp`, verify both exist + parse, then atomic rename both into place. On startup, if `ca.key` exists without `ca.pem` (or vice versa), delete the orphan and reset.

---

## Finding 4: `.installed` state cannot be verified post-relaunch — silently lies to user

- **Severity:** High
- **Location:** Phase 1 step 6, explicit note: *"installed state cannot be detected without querying Simulator → starts as `.generated` after relaunch even if actually installed (user reinstalls if needed)"*
- **Flaw:** The plan acknowledges this but does not handle the consequences. Reinstalling an already-trusted root cert via `simctl keychain add-root-cert` is technically idempotent on the Simulator side, BUT:
  1. The user has no way to know whether the cert is currently trusted in the Simulator. The UI lies in either direction.
  2. If the Simulator was erased between sessions (`xcrun simctl erase`), the cert is GONE but the user sees `.generated` and assumes safe-to-skip-install.
  3. If the cert was installed to a different Simulator last session, the new active Simulator has nothing — UI gives no signal.
- **Failure scenario:** Day 1: install cert into iPhone 15. Quit app. Day 2: launch app, iPhone 15 still booted. UI shows `.generated` (never `.installed`). User runs MITM proxy test, fails because state is wrong about which Simulator has the cert. Or worse: Day 2 user has erased iPhone 15 in Xcode; cert is gone; UI still shows `.generated`; user tests fail; debugging takes an hour.
- **Evidence:** Phase 1 step 6 + Success Criteria checkbox "Cert persists across app relaunches (re-read on startup)" — re-reads the file but not the trust state.
- **Suggested fix:** On launch (or on Simulator switch), shell `xcrun simctl keychain <udid> list-root-certs` (or equivalent) and grep for the CA's CN/fingerprint to determine real installed state. If unsupported, force `.generated` UI with a "trust state unknown — reinstall to be sure" hint, NOT a silent claim.

---

## Finding 5: openssl `Process` has no timeout — hang freezes the operation forever

- **Severity:** High
- **Location:** Phase 1 step 7 + step 8 (simctl invocations)
- **Flaw:** Plan says "Background queue: run openssl via Process". No timeout, no cancellation, no watchdog. If openssl hangs (entropy starvation on a fresh VM, weird FS state, unkillable child), `operation = .generating` is sticky forever. Every button is disabled. The only recovery is force-quit the app. Same for simctl — `xcrun` invocations are known to hang on stale CoreSimulator state.
- **Failure scenario:** User clicks Generate. openssl hangs (rare but real on macOS — happened to me with /dev/random in CI). Spinner spins forever. User waits 5 minutes, closes app, loses other in-progress side panel state.
- **Evidence:** No timeout/`waitUntilExit` strategy mentioned. No cancellation handle exposed. Phase 1 §Risks does not list this. `retry(udid:)` cannot escape because `operation != .idle` guard (Phase 1 §Risks row 4) blocks re-entry.
- **Suggested fix:** Wrap Process in a 30s timeout (`DispatchWorkItem` + `process.terminate()`). On timeout, set `operation = .error("timed out")`. Expose a Cancel button when `operation` is non-idle.

---

## Finding 6: `retry(udid:)` has no recorded last-failed-operation — guesses wrong

- **Severity:** High
- **Location:** Phase 1 §Architecture line 47 + step 10
- **Flaw:** `retry(udid:, deviceName:)` says "Look at current state + last failed operation" but the data model has no `lastFailedOperation` field. `CertOperation` has `.error(String)` but does not encode WHICH op failed. Step 10 says "Re-invoke appropriate method" with no algorithm.
- **Failure scenario:** User generates CA successfully (`status = .generated`). Clicks Install. simctl fails (`operation = .error("simctl failed")`). User clicks Retry. The retry handler looks at `status = .generated` and guesses "user wants to install" — correct in this case. Now repeat with: `status = .installed`, user clicks Reset Keychain, fails, `operation = .error`. User clicks Retry. Retry sees `.installed`, guesses "install again". Wrong — user wanted reset. Cert is now reinstalled instead of reset; user does not notice; subsequent test runs against stale state.
- **Evidence:** Phase 1 step 10 is two lines with no algorithm. Data model has no failed-op tag. Phase 2's primary button "Retry" has no payload distinguishing what to retry.
- **Suggested fix:** Add `private var lastFailedOp: CertOperation?` set on every error transition. `retry()` reads it, clears it, re-invokes. Or fold the failed op INTO the error case: `case error(failedOp: CertOperation, message: String)`.

---

## Finding 7: Re-entrancy guard `operation != .idle` blocks legitimate retry paths AND deadlocks on `.error`

- **Severity:** High
- **Location:** Phase 1 §Risks row 4: *"Race condition on rapid button clicks | `operation != .idle` guard at entry of each method"*
- **Flaw:** The proposed guard is `operation != .idle`. But `.error(...)` is also `!= .idle`. So when the user is in the error state and clicks Retry, the guard rejects the call. The plan never specifies that `.error` resets to `.idle` before retry. Worse, after a successful op the state is `.done` which is also `!= .idle` — a second click on a normal button would be silently dropped after a prior success until something resets `operation` back to `.idle`. Phase 2's UI mapping table has no row for `.done` — undefined behavior.
- **Failure scenario:** User clicks Generate. Success. `operation = .done`. User clicks Install. Guard rejects — `operation != .idle`. Button appears live but does nothing. User clicks again. Nothing. User force-quits app.
- **Evidence:** State machine in Phase 1 has `.idle | .generating | .installing | .resetting | .done | .error`. No transitions defined. No `.done → .idle` reset point. Phase 2 §State→UI Mapping table omits `.done` entirely.
- **Suggested fix:** Either collapse `.done` into `.idle` (success returns to `.idle` immediately) or define explicit transitions. Guard should be `case .generating, .installing, .resetting`, not `!= .idle`. Reset to `.idle` on entry to retry path.

---

## Finding 8: Concurrent generate/install spam not actually prevented at the UI layer; `@AppStorage` race on first-use hint

- **Severity:** Medium
- **Location:** Phase 2, step 8 ("Disabled + 0.5 opacity when isWorking") + Phase 1 §Risks row 4
- **Flaw:** SwiftUI `.disabled(isWorking)` is best-effort and the disabled state lags one render cycle behind a `@Published` change posted from a background callback. A user pressing Enter or double-clicking can fire the action twice before SwiftUI re-renders. The plan relies entirely on the service-layer guard (Finding 7), which is itself broken. Two simultaneous `generateCA()` calls = two openssl processes writing to the same `ca.key` path concurrently — corrupt PEM, undefined results. Additionally, `@AppStorage("certFirstUseHintDismissed")` is shared across the entire app process; if the plan is later extended with multiple certificate sections (e.g., per-device), they will fight over the same key with no namespacing.
- **Failure scenario:** User double-clicks Generate. Two openssl processes spawn. Both write `ca.key` interleaved. Resulting key is invalid PEM. `parseCert` fails. UI flips to `.error("invalid cert format")`. User retries; openssl overwrites cleanly; user never knew anything happened — until a stale half-written file is discovered weeks later in a backup.
- **Evidence:** No serialization queue mentioned. No file lock. No PID tracking. Phase 1 §Implementation Steps step 7 just says "Background queue".
- **Suggested fix:** Use a serial `DispatchQueue` inside `CertificateService` for ALL Process invocations. Set `operation` SYNCHRONOUSLY on the main thread before dispatching the background work — `@Published` updates from `@MainActor` are synchronous and the disabled state will be honored on the very next render.

---

## Cross-Cutting Concerns (not numbered findings, but flag them)

- **No teardown of `cancellables`.** Phase 1 declares `private var cancellables = Set<AnyCancellable>()` but the service is owned by `AppDelegate` for the process lifetime. Fine in practice — but the plan never says so. If a future refactor recreates the service (e.g., per-window), in-flight Combine sinks will deliver to a deallocated instance unless cancelled. Document the lifetime contract.
- **`ca.key` permission set "after creation" (Phase 1 §Security).** There is a window between openssl writing the key and the app chmod'ing it where the file is world-readable. Use `umask 0077` before spawning openssl, or write the key into a directory chmod'd 0700 first.
- **No migration / version field on the cert format.** If the CA generation parameters change in v2 (e.g., switch to ECC), there is no way to detect "old format" and force regen.
- **Deep link from `simctl` failure → user-actionable message is missing.** Phase 1 step 8 says "On failure: operation = .error(msg)" with `msg` being the raw simctl stderr. Simctl errors are notoriously cryptic. Plan should map known failures to friendly text.

---

## Unresolved Questions

1. Does `simctl keychain <udid> list-root-certs` exist on macOS 15? If not, how do we ever know real install state?
2. What does `simctl keychain` do against a SHUTDOWN device? Error, or silent boot? Plan never says.
3. If user erases the Simulator from Xcode mid-operation, does simctl return an error or hang?
4. Is `CertificateService` recreated on any code path, or is it strictly singleton-for-life? Phase 1 implies the latter; please make it explicit.
5. Should the cert be tied to the user's keychain (Touch ID) for the private key, even though it's "user-space, simulator-only"? Threat model is not articulated.
6. What is the rollback story if Phase 3 wiring breaks the existing side panel? No "revert" steps listed.

---

**Status: DONE**
Verdict: 8 findings (3 Critical, 4 High, 1 Medium). State machine, multi-device identity, and partial-write paths must be redesigned before implementation starts.
