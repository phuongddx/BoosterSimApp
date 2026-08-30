---
phase: 2
slug: capture-tools
# status lifecycle: draft (seeded by plan-phase) → validated (set by validate-phase §6)
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-08-30
---

# Phase 2 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Source: 02-RESEARCH.md `## Validation Architecture` (researcher-verified).

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Swift Testing (`import Testing`, `@Test`, `#expect`) — house standard |
| **Config file** | none — Xcode default runner |
| **Quick run command** | `xcodebuild test -project BoosterSimApp.xcodeproj -scheme BoosterSimApp -destination 'platform=macOS' -only-testing:BoosterSimAppTests` |
| **Full suite command** | quick + `-skip-testing:BoosterSimAppUITests` (phase-5 gate standard: unfiltered run exits 65 on pristine HEAD from pre-existing UI-test env failure) |
| **Estimated runtime** | ~60–90 seconds |

---

## Sampling Rate

- **After every task commit:** quick run command
- **After every plan wave:** full suite command + Debug build of the app scheme
- **Before `/gsd-verify-work`:** full suite green + phase-gate manual smoke (below)
- **Max feedback latency:** ~90 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 02-01-xx framing | 01 | 1 | P2-1 | T-capture-privacy | N/A (pure math) | unit | `-only-testing:BoosterSimAppTests/CaptureFramingTests` | ❌ W0 | ⬜ pending |
| 02-01-xx bezels | 01 | 1 | P2-1 | — | N/A | unit | same file | ❌ W0 | ⬜ pending |
| 02-xx save destinations | — | — | P2-2 | T-filename-sanitize | Filename builder sanitizes device names | unit | `-only-testing:BoosterSimAppTests/CaptureSettingsTests` | ❌ W0 | ⬜ pending |
| 02-xx recording config | — | — | P2-3 | — | N/A | unit | `-only-testing:BoosterSimAppTests/CaptureExportConfigTests` | ❌ W0 | ⬜ pending |
| 02-xx recording state machine | — | — | P2-3 | — | N/A | unit | same file | ❌ W0 | ⬜ pending |
| 02-xx GIF export timing | — | — | P2-4 | — | N/A | unit | same file | ❌ W0 | ⬜ pending |
| 02-xx touch pref restore | — | — | P2-3 | T-cross-app-pref | Single-key snapshot+restore semantics | unit | CaptureSettingsTests | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky. Task IDs finalize when PLAN.md tasks are numbered.*

---

## Wave 0 Requirements

- [ ] `BoosterSimAppTests/CaptureFramingTests.swift` — ASC preset table (6.9"/6.5"/iPad 13" exact pixel sizes), framing math (scale-to-fit/center/pad), no-stretch invariant, alpha-flatten rule
- [ ] `BoosterSimAppTests/CaptureExportConfigTests.swift` — fps↔CMTime mapping (120 → 1/120), queueDepth ∈ 3…8, codec/container enum mapping, GIF centisecond delay quantization, recording state machine transitions
- [ ] `BoosterSimAppTests/CaptureSettingsTests.swift` — AppSettings capture keys round-trip, filename builder sanitization, ShowSingleTouches set/unset/restore state machine
- [ ] No framework install needed — Swift Testing runs via the existing scheme

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Live screenshot via SCScreenshotManager | P2-1 | needs TCC grant + booted device + WindowServer | Capture from booted Simulator; verify real CGImage, dimensions match preset, no alpha channel |
| Recording produces playable .mov | P2-3 | TCC + real display timing | 30s recording on internal display; AVAsset duration>0, playable, dimensions match; measure delivered fps vs 120 target |
| Touch dots visible in recording | P2-3 | visual | Enable ShowSingleTouches, interact, confirm dots appear in captured frames |
| Thumbnail panel appears/auto-hides | P2-2 | visual + timing | Capture; floating thumbnail shows ~3s then auto-hides |
| Clipboard/Desktop/custom save | P2-2 | real user-session clipboard/desktop | Each destination once; paste into Preview; file exists at chosen path |
| Permission-denied degradation | P2-1..4 | TCC state not simulatable | Deny Screen Recording; setup UX shown, no crash; grant + relaunch recovers |

---

## Phase-Gate Manual Smoke (single booted Simulator)

1. Screenshot → verify dimensions vs selected ASC preset + flattened alpha
2. 30s recording → playable + delivered-fps measurement
3. GIF export → loops, timing correct
4. Each save destination once (Desktop / clipboard / custom path)
5. Thumbnail appears and auto-hides
6. `docs/system-architecture.md` updated (house docs rule)

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 90s
- [ ] `nyquist_compliant: true` set in frontmatter (by validate-phase)

**Approval:** pending
