---
phase: 05-network-tools
reviewed: 2026-08-30T00:40:57Z
depth: standard
files_reviewed: 24
files_reviewed_list:
  - BoosterSimApp/App/AppDelegate.swift
  - BoosterSimApp/Models/BlockRule.swift
  - BoosterSimApp/Models/BoosterCommand.swift
  - BoosterSimApp/Models/NetworkConditionProfile.swift
  - BoosterSimApp/Services/CommandServer.swift
  - BoosterSimApp/Services/NetworkConditionService.swift
  - BoosterSimApp/Utilities/AppLogger.swift
  - BoosterSimApp/Views/SideWindow/SideWindowView.swift
  - BoosterSimApp/Views/SideWindow/network/BlockRulesView.swift
  - BoosterSimApp/Views/SideWindow/network/NetworkConditionsSectionView.swift
  - BoosterSimApp/Views/SideWindow/tabs/NetworkTabView.swift
  - BoosterSimApp/Windows/SideWindowController.swift
  - BoosterSimConnect/BoosterCommandClient.swift
  - BoosterSimConnect/BoosterNetworkProtocol.swift
  - BoosterSimConnect/BoosterSimConnect.swift
  - BoosterSimConnect/NetworkConditionController.swift
  - BoosterSimConnect/ThrottlePacing.swift
  - BoosterSimAppTests/BlockRuleTests.swift
  - BoosterSimAppTests/CommandPayloadTests.swift
  - BoosterSimAppTests/ConditionVerdictTests.swift
  - BoosterSimAppTests/NetworkConditionProfileTests.swift
  - BoosterSimAppTests/NetworkConditionServiceTests.swift
  - docs/system-architecture.md
  - docs/codebase-summary.md
findings:
  critical: 1
  warning: 2
  info: 4
  total: 7
status: issues_found
---

# Phase 05: Code Review Report (Network Tools)

**Reviewed:** 2026-08-30T00:40:57Z
**Depth:** standard
**Files Reviewed:** 24
**Status:** issues_found

## Summary

Phase 5 delivers a loopback-bound NWListener command channel (`_booster-cmd._tcp.`), a Mac-side single-writer condition service with persistence, a schema-synced framework enforcement chain (`BoosterCommandClient → NetworkConditionController → BoosterNetworkProtocol`), verdict precedence (guard > airplane > rules > throttle > pass-through), paced throttle delivery, and a block-rules editor. Cross-file verification confirms the core contracts hold: Mac `evaluate` and framework `evaluateCondition` are semantically identical; `ThrottleSchedule` and `ThrottlePacing.plan` compute identical math; the swizzle chain composes with Pulse via renamed-selector calls; the anti-recursion guard is present at all three layers (property check in `canInit`/`evaluate`, canonical-request marking, literal header on inner requests); loopback bind is enforced via `requiredLocalEndpoint`; persistence keys match docs; privacy (PRO-03) is clean — the only logging is port/count/state via `AppLogger.network`, zero query-string or URL construction.

One critical defect was found in the framework client's frame-assembly path: `processBuffer` drops the connection on *any* decode error, including the normal `.incomplete` (partial TCP read) case — the exact condition the length-prefix codec exists to tolerate, and the asymmetry with the Mac-side receive loop (hardened in `ea7b024`) proves the intent. Two warnings cover an unbounded browser-restart hot loop and an un-injectable live listener wired into tests/previews. Four info-level items cover UI-state accuracy, a design-token miss, a cap enforced only at the UI layer, and a mutability asymmetry between schema mirrors.

## Critical Issues

### CR-01: Framework client drops the connection on split (incomplete) frames

**File:** `BoosterSimConnect/BoosterCommandClient.swift:138-147`
**Issue:** `processBuffer` catches every `decodeFrame` error with a single `catch` that cancels the connection. But `decodeFrame` throws `FrameError.incomplete` for the *normal* stream condition where a frame arrives across multiple TCP reads (`buffer.count < prefixLength` or body shorter than the declared length). Any partially-delivered snapshot frame is therefore treated as malformed: the connection is cancelled, the client re-browses, and the server re-pushes — and if segmentation repeats (frames larger than the receive coalescing window, e.g. large rule sets), this becomes a connect/disconnect flapping loop that churns the entire enforcement channel. The codec explicitly supports reassembly (`frameReassemblesAcrossPartialReads`, `CommandPayloadTests.swift:61-76`), and the Mac-side receive loop distinguishes the cases correctly (`CommandServer.swift:157-163`: `payloadTooLarge` → drop, otherwise "incomplete trailing bytes are fine") — the framework mirror of that loop was not hardened the same way in `ea7b024`.
**Fix:** Distinguish the error cases, mirroring the Mac side:

```swift
private func processBuffer() {
    while !receiveBuffer.isEmpty {
        let payload: Data
        do {
            payload = try Self.decodeFrame(from: &receiveBuffer)
        } catch FrameError.payloadTooLarge {
            // Malformed frame: drop the connection; reconcile heals on reconnect.
            connection?.cancel()
            return
        } catch {
            // .incomplete — wait for the next receive to complete the frame.
            return
        }
        apply(payload)
    }
}
```

## Warnings

### WR-01: Browser-failure restart has no backoff — potential hot restart loop

**File:** `BoosterSimConnect/BoosterCommandClient.swift:66-69` (with `82-87`)
**Issue:** On any `NWBrowser.State.failed`, `restartBrowsing()` immediately creates and starts a fresh browser. If Bonjour is persistently unavailable (mDNS daemon inactive, restricted sandbox), every new browser fails again on its next queue turn, producing an unbounded allocate-fail-restart cycle with no delay — a CPU busy loop for the lifetime of the host app. Transient hiccups self-heal, but nothing bounds the retry rate when the failure is not transient.
**Fix:** Rate-limit restarts — track consecutive failures and re-arm browsing after a backoff delay, e.g. `queue.asyncAfter(deadline: .now() + min(0.25 * pow(2, failures), 8))` (reset `failures` on a successful connect), or cap restarts per time window.

### WR-02: `NetworkConditionService` hard-wires a live `CommandServer` — tests and previews bind real listeners

**File:** `BoosterSimApp/Services/NetworkConditionService.swift:60`
**Issue:** `private let commandServer = CommandServer()` is not injectable, so every `NetworkConditionService()` — including the 8 test instantiations in `NetworkConditionServiceTests` (up to 2 per test) and the `SideWindowView` `#Preview` — starts a real `NWListener` bound to loopback and advertises the `_booster-cmd._tcp.` Bonjour service. Instance name conflicts are only avoided by Network.framework's auto-rename, and this coupling already produced one process-abort class in this phase (listener deallocated while started, fixed in `ea7b024`). The broadcast path also cannot be exercised in isolation (tests assert `snapshot()`, never actual frame delivery).
**Fix:** Inject the dependency and keep the app wiring unchanged: `init(defaults: UserDefaults = .standard, commandServer: CommandServer = CommandServer())`, or accept a broadcast closure `pushSnapshot: @escaping (BoosterCommand) -> Void`. Tests/previews can then pass a no-op stub instead of binding live listeners.

## Info

### IN-01: "Snapshot pushed to connected apps" status overclaims when no client is connected

**File:** `BoosterSimApp/Views/SideWindow/network/NetworkConditionsSectionView.swift:126`
**Issue:** The `.applied` state renders after every mutation, including broadcasts with zero connected Simulator apps (the frame is only cached in `latestSnapshot`, `CommandServer.swift:114-122`). The caption contradicts the phase's own honesty discipline (PRO-01) at a smaller scale: nothing was pushed anywhere.
**Fix:** Reword to "Snapshot ready" / "Snapshot broadcast", or expose a connection count from `CommandServer` and render "Pushed to N app(s)".

### IN-02: Hardcoded 2pt padding instead of the existing design token

**File:** `BoosterSimApp/Views/SideWindow/network/BlockRulesView.swift:67`
**Issue:** `.padding(.vertical, 2)` hardcodes a layout value; `Spacing.xxs = 2` already exists (`Utilities/DesignTokens.swift:8`) and AGENTS.md mandates tokens over hardcoded layout values.
**Fix:** `.padding(.vertical, Spacing.xxs)`.

### IN-03: 50-rule cap is enforced only in the view, not at the single-writer layer

**File:** `BoosterSimApp/Views/SideWindow/network/BlockRulesView.swift:14,24-26` vs `BoosterSimApp/Services/NetworkConditionService.swift:118-124`
**Issue:** The cap defending "bounded O(rules) matching per request" (T-05-02 rationale) lives entirely in `BlockRulesView.canAdd`; `NetworkConditionService.addRule` accepts an unbounded array. Any caller that bypasses the view (tests, future UI, scripted setup) silently defeats the invariant.
**Fix:** Add a shared `static let maxRules = 50` and guard `rules.count < maxRules` inside `NetworkConditionService.addRule`; have the view read the same constant.

### IN-04: Mac `BoosterCommand` fields are `var` while the framework mirror uses `let`

**File:** `BoosterSimApp/Models/BoosterCommand.swift:24-26` vs `BoosterSimConnect/NetworkConditionController.swift:19-22`
**Issue:** `airplane`, `throttle`, and `blockRules` are never mutated after construction (the service builds fresh snapshots), yet the Mac struct declares them `var`; the schema-synced mirror declares the same fields `let`. The mirrors are documented as needing identical semantics — an avoidable asymmetry invites drift, and `let` better expresses the snapshot value semantics.
**Fix:** Change the three Mac-side fields to `let` (no caller mutates them; tests reassign whole values only).

---

_Verified clean during review: loopback-only bind (`CommandServer.swift:43-45`); verdict precedence identical on both sides; anti-recursion guard in `canInit`, `evaluate`/`evaluateCondition`, `canonicalRequest`, and inner-request headers; pacing math parity (`ThrottleSchedule` ⇄ `ThrottlePacing.plan`, invalid-input rejection); persistence keys and re-apply on init; reconcile-on-connect; `deinit` cancellation of listener/connections; stopLoading cancellation of pacing + inner task/session; PRO-03 logging hygiene; docs (`system-architecture.md`, `codebase-summary.md`) consistent with as-shipped code including the pacing kilo-factor fidelity gap._

_Reviewed: 2026-08-30T00:40:57Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
