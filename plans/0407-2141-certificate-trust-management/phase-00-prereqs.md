# Phase 0 — Prerequisites & Assumption Verification

**Effort:** 0.5h
**Status:** completed
**Depends on:** —
**Blocks:** Phase 1

## Overview

Verify all load-bearing assumptions before writing any code. Red-team review found the plan was built on several unverified claims. This phase resolves them explicitly.

The non-manual assumptions are verified and recorded below. The iOS Simulator trust behavior without Settings toggle remains a manual smoke test and is deferred to Phase 3.

## Assumptions to Verify

### 1. `SimCtlService.run` uses argv-array (not shell)

**Why:** Determines whether command injection via udid/path is possible.
**Action:** Read `BoosterSimApp/Services/SimCtlService.swift`. Confirm `Process` is invoked with `executableURL = /usr/bin/xcrun` + `arguments: [...]` (argv-array). If it uses `/bin/sh -c` anywhere → escalate and redesign.

### 2. `SimulatorWindow` name property

**Why:** Phase 2 UI needs a `deviceName` string.
**Action:**
```bash
grep -n "displayName\|deviceName\|name\|title" BoosterSimApp/Models/SimulatorWindow.swift
```
Record actual property name. If none exists → add one as part of this phase (not deferred to Phase 3).

### 3. `xcrun simctl keychain booted` behavior

**Why:** Plan originally used `"booted"` as fallback. Red team flagged this as broken.
**Action:** Manual test (requires Simulator running):
```bash
# With exactly 1 booted sim:
xcrun simctl keychain booted add-root-cert /tmp/dummy.pem
# Expected: success or file-not-found

# With 2+ booted sims (boot a second):
xcrun simctl keychain booted add-root-cert /tmp/dummy.pem
# Expected: "Multiple devices matched the request." error
```
**Decision:** Regardless of outcome, **do NOT use `"booted"` as fallback**. Always require explicit UDID.

### 4. iOS Simulator trust semantics

**Why:** Critical finding #1 — does `simctl keychain add-root-cert` actually create trusted certs, or does Settings → Certificate Trust still need to be toggled?
**Action:** Manual verification procedure (to be repeated in Phase 3 smoke test):
1. Generate dummy CA: `openssl req -x509 -newkey rsa:2048 -keyout /tmp/t.key -out /tmp/t.pem -days 1 -nodes -subj "/CN=Test"`
2. Install into booted sim: `xcrun simctl keychain <udid> add-root-cert /tmp/t.pem`
3. Sign a leaf cert with this CA and serve HTTPS on a test hostname
4. In Simulator Safari, navigate to the test hostname
5. Check: does it load without warnings, or does it require Settings → Cert Trust toggle?

**If the toggle is required:** Plan must add UI hint directing user to Settings → General → About → Certificate Trust Settings.
**If the toggle is NOT required:** Proceed as originally planned (add UI hint still recommended, as a safety net).

> **Note:** Apple's behavior has historically been that `simctl keychain add-root-cert` DOES trust certs without requiring the manual Settings toggle (unlike manually-installed profiles on real devices). But this is a critical assumption — verify before shipping.

### 5. `simctl keychain` subcommand inventory

**Why:** Red team asked if there's a narrow "remove cert" that avoids the nuclear `reset`.
**Action:**
```bash
xcrun simctl keychain --help
xcrun simctl keychain booted --help
```
Record all subcommands. Expected: `add-cert`, `add-root-cert`, `reset` only. If a `remove-cert` or `list` exists → update Phase 1 to use narrower operations.

### 6. `/usr/bin/openssl` availability

**Why:** Plan depends on openssl CLI.
**Action:**
```bash
/usr/bin/openssl version
# Expected: "LibreSSL X.Y.Z" or similar
file /usr/bin/openssl
# Expected: Mach-O executable
```
Confirm path exists on target macOS 15+.

## Deliverable

A short markdown report at `plans/0407-2141-certificate-trust-management/phase-00-verification-results.md` documenting:

```markdown
# Phase 0 Verification Results

## SimCtlService.run
- Execution model: argv-array | /bin/sh -c
- Evidence: line X of SimCtlService.swift

## SimulatorWindow name property
- Actual property: displayName | name | (missing → added)

## simctl keychain booted with 2+ sims
- Result: success | error "Multiple devices matched"
- Decision: require explicit UDID (locked in)

## iOS Simulator trust without Settings toggle
- Verified cert is trusted: yes | no | pending Phase 3
- If no: UI hint required pointing to Settings

## simctl keychain subcommands available
- add-cert: yes
- add-root-cert: yes
- reset: yes
- remove-cert: yes | no
- list: yes | no

## /usr/bin/openssl
- Version: LibreSSL X.Y.Z
- Present on macOS 15: yes
```

## Todo

- [x] Read `SimCtlService.swift` — confirm argv-array invocation
- [x] Grep `SimulatorWindow.swift` for name property
- [x] Boot 2 simulators, test `simctl keychain booted`
- [x] Verify openssl path + version
- [x] List `simctl keychain` subcommands
- [ ] (Optional but recommended) Manually test trust semantics with dummy CA — deferred to Phase 3 smoke test
- [x] Write `phase-00-verification-results.md`

## Success Criteria

- [x] Non-manual assumptions resolved (documented yes/no + evidence)
- [ ] Simulator trust-toggle smoke test deferred to Phase 3
- [x] Any surprise outcomes logged for Phase 1 adjustment
- [x] Results file committed under plan directory

## Risks

| Risk | Mitigation |
|------|-----------|
| `SimCtlService` uses shell | STOP. Redesign. Add input validation everywhere. |
| `SimulatorWindow` has no name | Add `var displayName: String` now, update tracker to populate |
| Trust toggle required in Settings | Document prominently; add UI "Open Trust Settings" button or hint |
| `simctl keychain` has no narrow remove | Accept nuclear reset; strengthen warning dialog copy |
