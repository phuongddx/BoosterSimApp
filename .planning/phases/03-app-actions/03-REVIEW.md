---
phase: 03-app-actions
reviewed: 2026-08-31T08:05:00Z
depth: standard
files_reviewed: 34
files_reviewed_list:
  - BoosterSimApp/App/AppDelegate.swift
  - BoosterSimApp/Models/AppAction.swift
  - BoosterSimApp/Models/AppActionModels.swift
  - BoosterSimApp/Models/DefaultsEntry.swift
  - BoosterSimApp/Models/PushPayload.swift
  - BoosterSimApp/Models/PrivacyPermission.swift
  - BoosterSimApp/Services/AppActionService.swift
  - BoosterSimApp/Services/DeepLinkService.swift
  - BoosterSimApp/Services/DerivedDataAppScanner.swift
  - BoosterSimApp/Services/SimCtlService.swift
  - BoosterSimApp/Services/UserDefaultsEditorService.swift
  - BoosterSimApp/Utilities/AppLogger.swift
  - BoosterSimApp/Views/SideWindow/SideWindowView.swift
  - BoosterSimApp/Views/SideWindow/tabs/ActionsTabView.swift
  - BoosterSimApp/Views/SideWindow/actions/ActionSearchBar.swift
  - BoosterSimApp/Views/SideWindow/actions/AppPickerBar.swift
  - BoosterSimApp/Views/SideWindow/actions/AppResetSectionView.swift
  - BoosterSimApp/Views/SideWindow/actions/ClipboardSectionView.swift
  - BoosterSimApp/Views/SideWindow/actions/LocaleSectionView.swift
  - BoosterSimApp/Views/SideWindow/actions/LocationSectionView.swift
  - BoosterSimApp/Views/SideWindow/actions/PushNotificationSectionView.swift
  - BoosterSimApp/Views/SideWindow/actions/PrivacySectionView.swift
  - BoosterSimApp/Views/SideWindow/actions/UserDefaultsEditorView.swift
  - BoosterSimApp/Windows/SideWindowController.swift
  - BoosterSimAppTests/AppActionCatalogTests.swift
  - BoosterSimAppTests/AppActionServiceTests.swift
  - BoosterSimAppTests/DeepLinkServiceTests.swift
  - BoosterSimAppTests/DerivedDataAppScannerTests.swift
  - BoosterSimAppTests/LocaleCommandTests.swift
  - BoosterSimAppTests/PrivacyPermissionTests.swift
  - BoosterSimAppTests/PushPayloadTests.swift
  - BoosterSimAppTests/UserDefaultsEditorServiceTests.swift
  - docs/codebase-summary.md
  - docs/system-architecture.md
findings:
  critical: 1
  warning: 7
  info: 6
  total: 14
status: issues_found
---

# Phase 03: Code Review Report — App Actions

**Reviewed:** 2026-08-31T08:05:00Z
**Depth:** standard (with targeted cross-file traces and live-behavior probes on the flagged paths)
**Files Reviewed:** 34
**Status:** issues_found

## Summary

Phase 3's architecture is sound and the unit suite genuinely pins most contracts: the pipe-drain seam
resolves only after exit AND both EOFs, destructive verbs refuse empty/`booted` UDIDs on every path
(reset/uninstall/keychain/reset-all, all unit-tested), the push gate is boundary-correct (`> 4096`
rejects exactly 4097+, not 4096), the 12 TCC strings are verbatim with no notifications case (D-01),
the defaults editor never touches `defaults export` and validates domain+key before any argv, the
catalog filter is deterministic with a fixed section order, and design-token usage in the 9 new views
matches house precedent (literal caption font sizes mirror TrafficFilterBar/ConnectSetupView). D-02's
blast-radius dialog and automatic CA re-install are correctly ordered behind a destructive confirm.

One BLOCKER was found and empirically confirmed: **Reset App Data silently does nothing for a
non-running app** — the reset chain is aborted by a misused Combine idiom on its most common input.
Six further Warnings cover caption dishonesty, a stale/dropped-loads bug in the defaults editor,
latent seam deadlock paths, silent push-payload mutation, missing timeouts, an unbounded wait in
clearKeychain's second leg, and tautological test-only chain builders. The known pre-existing seam
argv-echo gap (URLs + defaults values) is still present and remains tracked — flagged, not
re-litigated.

Scope note: the assignment text mentioned "AppSettings additions", but the phase diff
(`git diff 18da229..HEAD --name-only`) contains no `AppSettings.swift` change; the authoritative
scope list was followed. Verification performed during this review: `xcrun simctl terminate` against
the booted iPhone 17 with a non-running app exits code 3 ("found nothing to terminate") — the input
that triggers CR-01.

## Critical Issues

### CR-01: Reset App Data aborts its chain when the target app is not running — reset silently does nothing, then reports a bogus timeout

**File:** `BoosterSimApp/Services/AppActionService.swift:93` (in `resetApp`, line 88)

**Issue:** The reset chain opens with terminate and swallows its failure as
`.catch { _ in Empty<String, SimCtlError>().eraseToAnyPublisher() }` — commented "not-running
terminate fails; harmless". That is incorrect on both counts. `simctl terminate <udid> <bundle>`
exits nonzero for a non-running app (empirically verified this session: exit 3, "found nothing to
terminate"), and Combine's `catch` replaces the failed upstream with `Empty`, which **completes
without emitting a value**. The downstream `flatMap` therefore never runs: no listapps presence
check, no uninstall, no reinstall — the reset does not happen at all. The dead chain sits in
`.resetting` (all buttons disabled by the reentrancy guard) until the 30s `.timeout` fires, and the
user gets "Reset failed before completion: simctl command timed out" — a false error for a normal
"reset a closed app" operation. `Empty` drops the flow; the author's intent was to *skip* terminate
and continue. The idiom used in the sibling optional hops (`Just("").setFailureType(...)` at lines
402/414/525) is the correct one — this one line uses the wrong operator.

**Fix:**
```swift
simCtl.run(Self.terminateCommand(udid: udid, bundleID: bundleID))
    // Terminate of a not-running app fails (exit 3) — emit a dummy value so the chain
    // continues to the listapps presence check, which owns the absent/apparent decision.
    .catch { _ in Just("").setFailureType(to: SimCtlError.self).eraseToAnyPublisher() }
```
Add a regression test: resetApp against a scripted double whose terminate run fails must still reach
the uninstall/presence leg (assert `uninstallCommand` argv is built / outcome is `.reset`/`.absent`).

## Warnings

### WR-01: City-preset caption claims "app relaunched automatically" when no relaunch happens

**File:** `BoosterSimApp/Services/AppActionService.swift:534-535`; same claim in
`BoosterSimApp/Views/SideWindow/actions/LocationSectionView.swift:170-172`

**Issue:** `applyLocationPreset` appends the relaunch hop only `if let bundleID` (line ~527), and
`LocationSectionView.presetPill` is disabled only when `activeUDID == nil` — an active app is NOT
required. With no app selected, the service caption still reads "timezone takes effect on the next
app launch (app relaunched automatically)" and the section's static `relaunchCaption` reads "the app
is relaunched automatically" — both false. The sibling `applyLocale` branches its caption on
`bundleID == nil` (line 399) precisely for this; the location preset path didn't inherit that
discipline, violating the phase's own caption-honesty contract.

**Fix:** Branch the caption on `bundleID == nil` → "…timezone takes effect on every app's next
launch." (no relaunch clause), and gate the view's `relaunchCaption` text on `activeApp != nil`.

### WR-02: Defaults editor drops reload requests while loading and shows the previous app's keys under the new domain header

**File:** `BoosterSimApp/Services/UserDefaultsEditorService.swift:70` (`guard operation != .loading
else { return }`) and lines 74-95 (entries cleared only on failure)

**Issue:** Two defects compound. (1) `loadDomain` rejects a request whenever a load is already in
flight instead of honoring the newest target. `UserDefaultsEditorView` reloads on
`onChange(of: activeUDID)` and `onChange(of: activeBundleID)`; switching apps A→B while the
get_app_container round trip for A is in flight silently discards the load for B — the editor then
shows **A's defaults keys** under B's domain label until the user manually hits reload (and the
same drop recurs during the write-completion auto-reload). (2) `entries` is never cleared at load
start, so even the non-dropped path displays the outgoing app's rows for the duration of the load.
In a tool whose design deliberately keeps values low-exposure, briefly rendering one app's defaults
under another app's header is a correctness trap, not just a flicker.

**Fix:** Clear (or snapshot-key by `(udid, bundle)`) `entries` when a load starts, and make a
request during `.loading` supersede the in-flight one (store the latest requested pair and re-run on
completion) rather than dropping it.

### WR-03: Seam writes stdin on the serial queue before drains start — latent machine-wide deadlock; unbounded drain wait

**File:** `BoosterSimApp/Services/SimCtlService.swift:85-87` (stdin write) and `:119`
(`drainGroup.wait()`)

**Issue:** `run(args, stdin:)` writes the child's stdin synchronously on `invocationQueue` BEFORE
`drainAndComplete` starts the readers. If `stdin` exceeds the 64 KB pipe buffer while the child is
blocked writing stdout (its pipe also full, no reader attached yet), both sides block forever —
and since the queue is machine-wide and serial, every simctl verb in the app (status bar, env
overrides, certificates, actions) wedges with it. Today the only stdin caller is `sendPush`, gated
to ≤4096 bytes in the UI — but `run(_:stdin:)` is public API and nothing at the seam enforces the
cap; the hazard is one future caller away. Related: `drainGroup.wait()` is unbounded — a simctl
child whose grandchild inherits the stdout/stderr FDs delays EOF past child exit and stalls the
same queue — and `readDataToEndOfFile` buffers output without a cap (listapps is ~33 KB today;
unbounded in principle).

**Fix:** Move the stdin write onto a concurrent task alongside the pipe drains (write after the
readers are draining, or chunk it), and optionally bound the drain with a watchdog. Cheap hardening
now beats a machine-wide hang later.

### WR-04: Push editor silently strips custom APNs keys — delivered payload differs from the editor text

**File:** `BoosterSimApp/Models/PushPayload.swift:86-100` (`parse` strict decode); sender at
`BoosterSimApp/Services/AppActionService.swift:253-257` (re-encodes the struct)

**Issue:** `parse` decodes the strict 4-field struct (aps.alert/badge/sound + "Simulator Target
Bundle"), and `sendPush` sends the canonical re-encode — so a perfectly valid APNs payload the user
pastes, e.g. `{"aps":{"alert":"x","mutable-content":1},"custom":{"id":5}}`, parses fine, passes the
4096 gate, reports "sent" — and arrives at the app with `mutable-content` and `custom` silently
removed. For a push-testing tool this is a correctness trap: notification-extension and
payload-dependent code paths get tested against a different payload than the one in the editor,
with no error, caption, or doc disclosure (injection is NOT a risk here — exec argv + stdin, no
shell — but silent payload mutation is).

**Fix:** Either reject with a typed error when the JSON carries keys outside the supported set
(compare parsed key sets before decode), or support passthrough (extra aps keys + top-level custom
payload dictionary). Minimum viable: disclose the field set in the section caption.

### WR-05: `readLocaleState` and deep-link `openInSimulator` lack the house 30s timeout — hung reads starve silently

**File:** `BoosterSimApp/Services/AppActionService.swift:327-347` (three un-timeouted
`readKeyArgs` runs); `BoosterSimApp/Services/DeepLinkService.swift:58-75`

**Issue:** Every other verb chains `.timeout(.seconds(30), customError: { .timeout })`; these four
chains have none. On a degraded/hung simulator, locale fields stay blank with no error caption
(failure completions are swallowed by `receiveCompletion: { _ in }`), and a failed openurl shows
nothing at all (no completion handling on the failure path is present, only via `lastResult` — which
never arrives). Because the seam serializes invocations machine-wide, an un-timeouted hung read
gives the user no signal and no recovery path beyond quitting.

**Fix:** Route both through the same timeout + failure-caption discipline as `runVerb` (a shared
helper on `DeepLinkService` mirrors the established anatomy).

### WR-06: clearKeychain's CA-install leg can wedge the operation machine forever; unconditional success log

**File:** `BoosterSimApp/Services/AppActionService.swift:173-215`

**Issue:** The inner leg waits on
`keychainEvents.dropFirst().first { !$0.isWorking }` after calling
`certificateService.install(...)`. That future never completes if `install` doesn't transition
CertificateService's machine (e.g. its own begin-refusal path changes) — and there is no timeout on
either leg. The AppActionService machine would then sit in `.clearingKeychain` permanently,
rejecting every subsequent verb (reentrancy guard) until app restart. The first leg has the same
shape guarded only by a pre-check `!certificateService.operation.isWorking`, which admits `.error`
states whose re-entry semantics live in another type. Separately, line 209 logs "Keychain clear
finished — CA reconcile completed" unconditionally in `receiveValue` — including for the "wipe
failed" and "install failed" captions — contradicting the verb+outcome-only honesty rule.

**Fix:** Arm a timeout on the keychainEvents chain (fallback caption + `finish`), and move the log
line into the branches so it reflects the actual outcome.

### WR-07: Test-only chain builders duplicate the production chains — tautological coverage

**File:** `BoosterSimApp/Services/AppActionService.swift:729` (`fallbackRelaunchArgs`), `:735`
(`localePresetChain`), `:890` (`cityPresetChain`)

**Issue:** All three builders are referenced only from `LocaleCommandTests`; the production chains
in `applyLocale` / `applyLocationPreset` re-inline the same argv step by step. The tests pin the
builders to themselves — if the inline chain drifts from the builder (an edit to `applyLocale`
that skips the timezone hop, say), every "chain" test still passes. The idempotency and
write-then-relaunch guarantees are asserted against code that never executes in the app.

**Fix:** Have the production verbs compose their argv from the builders (single source of truth),
or delete the builders and test the composition through the real service methods.

## Info

### IN-01: Known seam argv echo still present (tracked — flag only)

**File:** `BoosterSimApp/Services/SimCtlService.swift:61`

**Issue:** `print("[SimCtl] xcrun simctl …")` still echoes full argv — now including openurl URLs
and defaults write VALUES — brushing the never-log-URLs/values prohibitions. Already documented
(`docs/system-architecture.md:541`, deferred-items.md #2, 03-02/03-04 deviations); not re-litigated.
Still present at review time; recommend redacting at the print site in the next change that touches
this file.

### IN-02: File-size budget exceeded (pre-flagged)

**File:** `BoosterSimApp/Services/AppActionService.swift` (906 LOC);
`BoosterSimApp/Views/SideWindow/actions/UserDefaultsEditorView.swift` (505 LOC)

**Issue:** House target is <200 LOC. Both were self-flagged in the phase summaries for the review
gate; recorded here so the gate decision is explicit. `AppActionModels.swift`/`UserDefaultsEditorService.swift`
show the split is achievable where facade state permits.

### IN-03: Catalog keyword "camera" surfaces a section with no camera row

**File:** `BoosterSimApp/Models/AppAction.swift:79`

**Issue:** The privacy entry's keywords include `"camera"`, so searching "camera" surfaces the
Privacy section — which deliberately has no camera row (simctl has no camera TCC service). Honest
dead end for the user.

**Fix:** Drop the keyword, or keep it and note in the section that camera is not simctl-settable.

### IN-04: "json" add-kind writes raw text bytes as `-data`, not a JSON value

**File:** `BoosterSimApp/Views/SideWindow/actions/UserDefaultsEditorView.swift:377` (placeholder
"raw JSON text") and `:411-412` (`Data(raw.utf8)`)

**Issue:** Adding a key of kind "json" stores the raw UTF-8 bytes of the text as an opaque data
blob (`-data <hex>`) — not a JSON-decoded plist value. The read side's `.json` capsule means
"binary-plist capsule", so the kind label overpromises on the write side. Consistent with the
documented capsule design, but the placeholder invites wrong expectations.

**Fix:** Relabel the kind "data" on the add picker, or decode the text as JSON into a plist object
before writing.

### IN-05: Coordinate argv uses raw input text; plist read path skips the name allowlist

**File:** `BoosterSimApp/Services/AppActionService.swift:846-860` (`coordinatePair`);
`BoosterSimApp/Services/UserDefaultsEditorService.swift:171-174` (`preferencesPlistPath`)

**Issue:** (a) The validated coordinate string is the trimmed input verbatim, not the parsed value:
`3.7e1` / `0x1p5` pass the numeric gate and reach simctl, which may reject the spelling (failure is
captured, but the gate's promise is "valid coordinates build the verb"). Emit
`String(latValue)`/`String(lonValue)`. (b) `preferencesPlistPath` interpolates the scanned
`CFBundleIdentifier` into a path without the `[A-Za-z0-9._-]` allowlist the write path applies —
path traversal is practically unreachable (the ID must also pass device install), but the
asymmetry is free to close. (c) `parseEntries` loads the whole plist via
`NSDictionary(contentsOfFile:)` — memory is bounded by what the debugged app wrote to its own
container (local trust boundary), acceptable for a dev tool; noted for completeness.

### IN-06: `fail()` logs simctl stderr with `privacy: .public`

**File:** `BoosterSimApp/Services/AppActionService.swift:600`

**Issue:** Failure captions embed `error.localizedDescription` (i.e. "simctl failed: <stderr>") and
`fail` logs them public. simctl stderr can echo argv fragments (paths, device state). Not the IN-01
seam echo, but the same redaction sweep should cover stderr passthrough when that lands.

---

## Verified Sound (no action)

- **Destructive guards:** empty/`booted` refusal present on reset/uninstall/clearKeychain/resetAllPrivacy,
  unit-pinned; `SideWindowView.activeUDID` can legitimately be `"booted"` and is refused server-side.
- **Seam core:** concurrent drains + exit-AND-both-EOF resolution kill the >64 KB deadlock; PipeBuffer
  lock discipline correct; promise fires exactly once per path; serialization is queue-based, never interleaved.
- **4096 gate:** exact boundary (`> maxEncodedBytes`), 4095/4096/4097 pinned by deterministic fixtures.
- **D-01/D-02:** no notifications case constructible; guided-grant control never fakes a toggle; CA
  reconcile order (reset → reconcile → install-if-CA) pinned by scripted-double tests and matches the D-02 contract.
- **Privacy argv:** 12 verbatim TCC strings; per-app bundle arg appended only by the facade; reset-all destructive-gated.
- **Defaults editor:** `defaults export` absent (grep-verified); allowlist rejects before argv (typed path unit-tested);
  CFBoolean-before-Int discrimination pinned; values never in logs/captions.
- **Scanner:** symlink resolution precedes dedupe; macOS/universal dirs excluded; corrupt/missing-plist skips;
  newest-wins with visible alternatives; fixtures runtime-synthesized.
- **Catalog/search:** fixed order, empty query = all sections through one table, no shuffle; clear-on-collapse present.
- **Strict concurrency:** project builds in Swift 5 language mode with approachable concurrency
  (`SWIFT_VERSION = 5.0`); the seam's cross-thread work is manually synchronized (NSLock + queue
  discipline), so it is correct today — worth re-validating when the project flips to Swift 6 mode.
- **Docs:** § App Actions matches the landed source on every point cross-checked during this review.

---

_Reviewed: 2026-08-31T08:05:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
