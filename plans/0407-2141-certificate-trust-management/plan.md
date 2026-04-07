---
title: Certificate Trust Management (Network Tools #10)
description: Install custom CA certificates into iOS Simulator via simctl keychain + openssl CA generation. Side panel section with 6 visual states.
status: complete
priority: P2
effort: 5h
branch: main
tags: [feature, network-tools, certificates, side-panel]
created: 2026-04-07
red_teamed: 2026-04-07
blockedBy: []
blocks: []
github_issue: phuongddx/BoosterSimApp#10
---

# Certificate Trust Management

## Overview

First sub-feature of Phase 5 (Network Tools). Adds a "Certificates" section to the BoosterSimApp side panel for generating and installing a self-signed root CA into the iOS Simulator trust store. Foundation for future HTTPS content inspection (paired with MITM proxy in #6).

**Parent issue:** phuongddx/BoosterSimApp#10

Implementation is in place. Remaining work is environment-bound verification: host-side `xcodebuild` still fails in this setup, and the Simulator Safari trust smoke test is still pending/manual.

## Why First

- Simplest sub-feature in Phase 5 (~5h effort post red-team)
- **No Apple Developer account required** (unlike #7 Throttle)
- Zero external dependencies — uses existing `SimCtlService` + Apple Security.framework
- Uses existing architecture patterns
- Immediate utility: install custom enterprise CAs, debug trust issues, prepare foundation for future MITM proxy

## Threat Model (post red-team)

**Asset:** Self-signed root CA private key (`ca.key`)
**Impact if leaked:** Attacker can mint valid certs for **any public hostname**, trusted by any system that imported this CA (Simulator, backups, colleagues). Not "simulator-only" — once the key leaks, the Simulator scope is irrelevant.

**Mitigations:**
- `umask 0o077` set on Process before openssl runs → `ca.key` born `0600`
- `chmod 0700` on `Certificates/` directory
- `com.apple.metadata:com_apple_backup_excludeItem` xattr on certs dir (Time Machine / iCloud exclusion)
- 90-day CA validity (not 2 years) — forces periodic rotation
- Key never logged; error messages redact absolute paths
- UI first-use hint explicitly warns: "Anyone with this file can intercept HTTPS for any site."
- **Future:** migrate to Keychain Services (`SecItemAdd` with `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`) — tracked as follow-up

## Critical Reality Checks (from red-team)

1. **Cert pinning defeats this feature** — apps using pinning will reject our CA. Only works for non-pinned HTTPS.
2. **Multi-booted Simulators** — `"booted"` fallback fails with 0 or 2+ booted devices; must require explicit active UDID.
3. **Post-install trust verification** — smoke test must confirm cert is actually honored (not just keychain-loaded).
4. **Trust state cannot be verified on relaunch** — must persist fingerprint + UDID in `@AppStorage` and check against current cert.
5. **`simctl keychain reset` nukes all keychain data** — including third-party tool certs (Proxyman, Charles). UI dialog must state this explicitly.

## Context

### Research Artifacts (pre-done)
- Research: `../reports/researcher-0406-2308-network-inspection-manipulation.md`
- API verification: `../reports/xcdocs-0407-1734-network-tools-api-verification.md`
- UI design spec: `../reports/ui-0407-2126-certificate-section-design.md`
- UI mockup: `../reports/assets/certificate-section-ui-mockup.html`

### Key Technical Decisions (revised after red-team)

| Decision | Choice | Rationale |
|----------|--------|-----------|
| CA generation | `openssl` CLI via `Process` with `umask 0o077` + atomic rename | Key born `0600`, no race window |
| Cert parsing | **`SecCertificateCreateWithData` + `SecCertificateCopyValues`** (Apple Security.framework) | Stable Apple API, replaces fragile openssl text parsing |
| Cert install | `xcrun simctl keychain add-root-cert` via existing `SimCtlService` | No root, Apple-sanctioned |
| CA storage | `~/Library/Application Support/BoosterSimApp/Certificates/` with `0700` dir + `.nobackup` xattr | Excluded from backups/Time Machine |
| CA validity | **90 days** (not 2 years) | Reduces compromise window; forces rotation |
| State persistence | Fingerprint (SHA-256) + UDID via `@AppStorage` | Reconcile `.installed` across relaunches |
| Operation serialization | Dedicated serial `DispatchQueue` + state machine transitions + 30s timeout | Prevents race conditions, hangs, lost operations |
| Concurrent install guard | Operation guard + `.allowsHitTesting(false)` + `@MainActor` transitions | Fully atomic |
| UDID source | **Closure provided by view** (not captured value) — resolved at action time | Avoids stale UDID across sim switches |
| UI pattern | `CollapsibleSection` wrapper | Matches `HealthDataSectionView` |

## Phases

| # | Phase | Status | Effort | Link |
|---|-------|--------|--------|------|
| 0 | Pre-reqs — verify assumptions | completed | 0.5h | [phase-00-prereqs.md](./phase-00-prereqs.md) |
| 1 | Service + state machine + Security.framework | completed | 3h | [phase-01](./phase-01-service-and-models.md) |
| 2 | UI section view | completed | 1h | [phase-02-ui-section-view.md](./phase-02-ui-section-view.md) |
| 3 | Integration & wiring + verification smoke test | completed (build+tests pass; manual smoke A-G pending user) | 0.5h | [phase-03-integration.md](./phase-03-integration.md) |

## New Files

```
BoosterSimApp/Services/CertificateService.swift    (~180 LOC, < 200 limit)
BoosterSimApp/Views/SideWindow/CertificateSectionView.swift  (~180 LOC)
```

## Modified Files

```
BoosterSimApp/App/AppDelegate.swift                (add certService property)
BoosterSimApp/Windows/SideWindowController.swift   (init param + environment injection)
BoosterSimApp/Views/SideWindow/SideWindowView.swift (add section between EnvOverrides and HealthData)
```

## Dependencies

- Sequential: Phase 1 → Phase 2 → Phase 3
- Phase 2 references service types from Phase 1
- Phase 3 wires the view into existing AppKit/SwiftUI layer

## Success Criteria

- [x] User can click "Generate CA" -> self-signed root CA created in `~/Library/Application Support/BoosterSimApp/Certificates/`
- [x] User can click "Install to Simulator" -> cert installed in booted device's keychain via `simctl`
- [x] User can click "Reset Keychain" (with confirmation) -> all certs in Simulator cleared
- [x] Section shows correct state after each operation (notGenerated / generated / installed / error)
- [x] Cert persists across app relaunches (re-read on startup)
- [x] Expiry date displayed correctly
- [x] Build succeeds with no warnings, all files under 200 LOC
- [x] Follows existing section pattern (`HealthDataSectionView` parity)

## Out of Scope (Defer)

- HTTPS content inspection via MITM (requires full proxy + per-host cert gen)
- **Certificate pinning bypass** — pinned apps reject our CA by design; requires runtime hooks / Frida / disabled pinning in debug builds
- **Selective cert removal** — `simctl keychain` has no "remove this cert" subcommand; only full reset available
- Keychain Services migration (store `ca.key` in macOS Keychain instead of disk)
- Copy PEM to clipboard
- Cert expiry warning (<30 days)
- Multiple CA management
- Per-device install selection (only installs to currently-selected Simulator)

## Risks (revised)

| Risk | Mitigation |
|------|-----------|
| `openssl` output format changes on future macOS | Use Security.framework for parsing; openssl only for key generation |
| `"booted"` UDID fallback fails with 0 or 2+ sims | Disable Install button when `activeUDID == nil`; refuse to use "booted" as default |
| Simulator erase wipes installed cert | Fingerprint check on relaunch detects mismatch; UI shows `.unknown` state |
| Regenerate orphans the previous CA still trusted in Simulator | "Regenerate" renamed to "Rotate" — forces `resetKeychain` → delete → generate → reinstall atomically |
| User runs Reset Keychain and wipes Proxyman/Charles certs | Confirmation dialog explicitly warns about third-party tools; default button is Cancel |
| Process hangs (openssl or simctl) | 30s timeout; `operation = .error("Operation timed out")` on expiry |
| Rapid tapping spawns parallel processes | Serial dispatch queue in service + state machine transitions (only legal transitions allowed) |
| Error messages leak absolute paths into logs | Redaction helper strips paths to `<certs-dir>` before logging |

## Red Team Review

### Session — 2026-04-07
**Findings:** 15 total (15 accepted, 0 rejected)
**Severity breakdown:** 7 Critical, 7 High, 1 Medium
**Reviewers:** Security Adversary, Failure Mode Analyst, Assumption Destroyer

| # | Finding | Severity | Applied To |
|---|---------|----------|------------|
| 1 | iOS trust toggle may be required post-install (verify) | Critical | Phase 0 + Phase 3 smoke test |
| 2 | `"booted"` fallback broken with 0/2+ sims | Critical | Phase 1 + Phase 3 |
| 3 | Partial-write corruption of CA files | Critical | Phase 1 (atomic rename) |
| 4 | Regenerate leaves old CA trusted | Critical | Phase 1 (rename → "Rotate" flow) |
| 5 | `ca.key` chmod-after-write race window | Critical | Phase 1 (`umask 0o077`) |
| 6 | `udid` captured at view-construction leaks across sim switches | Critical | Phase 2 (closure-based) |
| 7 | Threat model misrepresents leaked-CA impact | Critical | plan.md threat model section |
| 8 | Cert pinning falsely listed as use case | High | Out of scope section |
| 9 | `.installed` state lies across app relaunches | High | Phase 1 (fingerprint in `@AppStorage`) |
| 10 | Race condition guard insufficient | High | Phase 1 (serial queue + state machine) |
| 11 | No Process timeouts | High | Phase 1 (30s) |
| 12 | Reset Keychain nukes third-party certs | High | Phase 2 (dialog copy) |
| 13 | openssl text parsing fragile | High | Phase 1 (Security.framework) |
| 14 | `retry()` has no recorded last-op | High | Phase 1 (`lastFailedOperation` tracking) |
| 15 | 1.5h Phase 1 unrealistic | Medium | Plan totals updated to 5h |
