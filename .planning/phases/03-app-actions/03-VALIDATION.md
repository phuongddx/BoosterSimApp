---
phase: 3
slug: app-actions
# status lifecycle: draft (seeded by plan-phase) → validated (set by validate-phase §6)
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-08-30
---

# Phase 3 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Source: 03-RESEARCH.md `## Validation Architecture` (researcher live-verified on Xcode 26.3/iOS 26.3).

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Swift Testing (`import Testing`, `@Test`, `#expect`) — house standard; UI tests XCTest (untouched) |
| **Config file** | none — Xcode default runner |
| **Quick run command** | `xcodebuild test -project BoosterSimApp.xcodeproj -scheme BoosterSimApp -destination 'platform=macOS' -only-testing:BoosterSimAppTests -skip-testing:BoosterSimAppUITests -parallel-testing-enabled NO` |
| **Full suite command** | same (house phase gate: unit bundle + Debug build; baseline 83 unit cases green at HEAD) |
| **Estimated runtime** | ~60–120 seconds |

---

## Sampling Rate

- **After every task commit:** quick run command (targeted `AppAction*Tests` where scoped)
- **After every plan wave:** full unit bundle + Debug build of the app scheme
- **Before `/gsd-verify-work`:** full suite green + phase-gate manual smoke (below)
- **Max feedback latency:** ~120 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 03-xx reset sequence | — | — | SC1 | — | N/A (pure builders) | unit | `-only-testing:BoosterSimAppTests/AppActionServiceTests` | ❌ W0 | ⬜ pending |
| 03-xx privacy strings | — | — | SC2/D-01 | — | verbatim simctl contract locked | unit | `…/PrivacyPermissionTests` | ❌ W0 | ⬜ pending |
| 03-xx push payload | — | — | SC2 | — | >4096 B / non-object rejected | unit | `…/PushPayloadTests` | ❌ W0 | ⬜ pending |
| 03-xx deep-link parse | — | — | SC2 | — | URL validation; migration keeps behavior | unit | `…/DeepLinkServiceTests` | ❌ W0 | ⬜ pending |
| 03-xx locale args | — | — | SC3 | — | typed defaults writes + relaunch sequence | unit | `…/LocaleCommandTests` | ❌ W0 | ⬜ pending |
| 03-xx scanner | — | — | SC4 | — | fixture DerivedData tree → bundle IDs, mtime order, `-iphonesimulator` filter | unit | `…/DerivedDataAppScannerTests` | ❌ W0 | ⬜ pending |
| 03-xx defaults editor | — | — | SC4 | T-plist-write | typed read of fixture plist; write/delete arg builders | unit | `…/UserDefaultsEditorServiceTests` | ❌ W0 | ⬜ pending |
| 03-xx catalog search | — | — | SC4 | — | keywords/section filtering, empty query, no-match | unit | `…/AppActionCatalogTests` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠ flaky. Task IDs finalize when PLAN.md tasks are numbered.*

---

## Wave 0 Requirements

- [ ] `BoosterSimAppTests/AppActionServiceTests.swift` — command builders + sequencing state
- [ ] `BoosterSimAppTests/PushPayloadTests.swift` — aps encode + 4096 gate + Simulator Target Bundle key
- [ ] `BoosterSimAppTests/PrivacyPermissionTests.swift` — verbatim service strings; notifications-absent contract (D-01)
- [ ] `BoosterSimAppTests/DerivedDataAppScannerTests.swift` — fixture DerivedData tree in test bundle
- [ ] `BoosterSimAppTests/UserDefaultsEditorServiceTests.swift` — fixture plist parsing + typed arg builders
- [ ] `BoosterSimAppTests/AppActionCatalogTests.swift` — search behavior
- [ ] No framework install needed — Swift Testing already configured

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Push banner arrives + taps through | SC2 | live APNs delivery + human eyes | Send payload to booted device with permission granted; banner shows, tap opens app |
| Push permission guided grant | SC2/D-01 | TCC not automatable | Deny → control detects state + shows guidance; grant manually in Settings; send succeeds |
| Keychain wipe + CA reconcile | SC1/D-02 | device-wide destructive path | Confirm dialog names blast radius; after wipe, CA re-reconciles (cert trust works again) |
| Location moves in Maps | SC3 | live CoreLocation | Set coordinates; Maps/Weather reflect; clear restores |
| Clipboard both directions | SC3 | real pasteboards | Mac→Sim and Sim→Mac round-trip via pbsync |
| Locale/appearance/DTC take effect | SC3 | relaunch effects visible | Switch locale → relaunch prompt → app localizes; DTC size change visible |
| Reset app clears state | SC1 | container lifecycle | Install app, write defaults, reset → fresh launch, defaults gone |
| Defaults edits land live | SC4 | real container plist | Edit a key → app reads new value on next launch |

---

## Phase-Gate Manual Smoke (single booted Simulator)

1. Active app detected (DerivedData ∩ installed ∩ running) with explicit picker
2. Reset app → fresh state; keychain wipe (D-02 path) → CA re-reconciles
3. Push send with permission (guided grant per D-01); deep link opens
4. Locale + Dynamic Type + appearance + location + clipboard round-trip
5. Defaults editor: view/edit/add/delete + search across the action catalog
6. `docs/system-architecture.md` § App Actions updated (house docs rule)

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags (house standard includes `-parallel-testing-enabled NO`)
- [ ] Feedback latency < 120s
- [ ] `nyquist_compliant: true` set in frontmatter (by validate-phase)

**Approval:** pending
