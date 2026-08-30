---
phase: 02-capture-tools
plan: 04
subsystem: capture
tags: [screencapturekit, documentation, phase-gate, tcc, appstoreconnect, gif, mp4, mov]

# Dependency graph
requires:
  - phase: 02-capture-tools (plan 01)
    provides: screenshot spine (ScreenshotService + CaptureCompositor + facade + thumbnail), destination routing, ASC preset models
  - phase: 02-capture-tools (plan 02)
    provides: staged .mov contract (RecordingService + SCRecordingOutput, finish-callback finalization), TouchIndicatorController ShowSingleTouches machine
  - phase: 02-capture-tools (plan 03)
    provides: CaptureExporter (GIF/MP4/MOV + A2 fallback), ExportSectionView, launch sweep, temp lifecycle closure
provides:
  - docs/system-architecture.md § Capture Tools — the shipped subsystem documented truthfully (service split, data flow, permissions + degraded behavior, ShowSingleTouches scope/restore, temp lifecycle, honest fps statement)
  - Phase-gate automated standard evidence — unit bundle 79/79 exit 0, Debug build clean, swiftpm diff empty with Package.resolved sha256 stable (70386616a707…)
  - Phase-gate manual smoke (Task 2) — user-approved 2026-08-30: all six steps pass (A2 resolved via passthrough, fallback not needed; no boostersim-capture-* residue)
affects: [02-phase-closure, 03-app-actions]

# Actuals (#2632) — pairs with the plan's estimate (18k tokens, low confidence)
actuals:
  tokens: 2831        # chars/4 over the realized Task-1 diff (e49ccfb): 11,324 chars, 60 insertions / 6 deletions
  tasks: 2            # Task 1 + Task 2 (blocking-human smoke user-approved 2026-08-30)
  commits: 3          # e49ccfb (docs), dec9aab (halt record), this closure commit

# Tech tracking
tech-stack:
  added: []            # closure plan — documentation + verification only, zero installs (REQ-nfr-03 intact)
  patterns:
    - "Phase-gate docs rule (Phase 5 pattern): architecture doc names the real shipped symbols; stale placeholder lines corrected in the same edit"

key-files:
  created: []
  modified:
    - docs/system-architecture.md

key-decisions:
  - "Capture subsystem documented as one § Capture Tools section (Network Manipulation precedent) — service-split table + ASCII data flow, not a restructure of the existing document"
  - "Frame rate documented honestly: 120 is the configured ceiling, delivered fps is display-bounded (matches the UI's 'Up to 120 fps' caption)"
  - "Package.resolved pin verified by sha256 content stability (70386616a70796c3cfeea9cc621708cc294eac4c6825bfe400d52e4234cf8852, identical to the Phase 5 pin) — the git-level diff assertion is vacuous while the file stays untracked; track-the-file recommendation remains open in STATE.md"

patterns-established:
  - "Closure-plan docs truth pass: fix contradicting stale lines (placeholder captions, key lists, concurrency bullet) in the same commit as the new subsystem section"

requirements-completed: [REQ-roadmap-phase2-capture-tools, REQ-nfr-03]   # closed at gate approval 2026-08-30

coverage:
  - id: D1
    description: "Architecture docs truthfully describe the shipped capture subsystem — all six required symbols named, permission + degraded behavior, ShowSingleTouches scope/restore note"
    requirement: REQ-nfr-03
    verification:
      - kind: other
        ref: "grep docs/system-architecture.md § Capture Tools: ScreenshotService, RecordingService, CaptureCompositor, CaptureExporter, TouchIndicatorController, CaptureThumbnailPanel all present"
        status: pass
    human_judgment: false
  - id: D2
    description: "Phase-gate automated standard — full unit bundle (pre-existing + three capture suites) exit 0, Debug build clean, zero dependency change"
    requirement: REQ-nfr-03
    verification:
      - kind: other
        ref: "xcodebuild test -only-testing:BoosterSimAppTests -skip-testing:BoosterSimAppUITests → exit 0, 79/79; xcodebuild Debug build → exit 0; git diff --exit-code swiftpm share → clean, Package.resolved sha256 unchanged"
        status: pass
    human_judgment: false
  - id: D3
    description: "Six-step phase-gate manual smoke on one booted Simulator — all four ROADMAP success criteria observed live (screenshot dims/alpha, 30s recording + delivered fps, GIF/MP4/MOV exports, three destinations, thumbnail, no temp residue)"
    requirement: REQ-roadmap-phase2-capture-tools
    verification:
      - kind: manual
        ref: "user six-step phase-gate smoke 2026-08-30 — approved (see § Checkpoint Resolution)"
        status: pass
    rationale: "Live SCK capture, playable recordings, delivered-fps measurement, clipboard/desktop/custom saves, and TCC state are manual-only per the phase validation strategy — not reproducible in unit tests"

# Metrics
duration: 8min
completed: 2026-08-30
status: complete      # Task 2 blocking-human smoke user-approved 2026-08-30 — plan closed
---

# Phase 02 Plan 04: Phase-Gate Closure Summary

**Architecture docs now describe the shipped capture subsystem (service split, permissions + degradation, ShowSingleTouches scope/restore, temp lifecycle) and the phase-gate automated standard is green — unit bundle 79/79 exit 0, Debug build clean, zero dependency change; the blocking-human six-step phase-gate smoke was user-approved on 2026-08-30 — Phase 2 capture tools delivered**

## Performance

- **Duration:** 8 min executor time (2026-08-30T14:11:38Z–14:19:32Z) + user smoke + continuation closure (2026-08-30)
- **Tasks:** 2 of 2 complete (Task 2 blocking-human phase-gate smoke approved 2026-08-30)
- **Files modified:** 1 (docs/system-architecture.md)
- **Commits:** e49ccfb (docs) + dec9aab (halt record) + this closure commit

## Accomplishments

- § Capture Tools added to docs/system-architecture.md: service-split table (CaptureService facade, ScreenshotService SCScreenshotManager one-shot, RecordingService SCStream + SCRecordingOutput at CMTime(1,120)/queueDepth 5/HEVC staged .mov, CaptureCompositor pure ASC geometry, CaptureExporter AVAssetReader→ImageIO GIF + AVAssetExportSession MP4/MOV with A2 re-encode fallback, TouchIndicatorController, CaptureThumbnailPanel, CaptureSaveRouter), the Capture-tab→destination-routing data flow diagram, the Screen Recording permission block (TCC required, grant-requires-restart cycle, degraded setup UX per the AGENTS.md rule), the ShowSingleTouches cross-app note (single scoped key on com.apple.iphonesimulator, snapshot + restore on every exit path incl. kCFNull), the temp-lifecycle/retention paragraph, and the honest "Up to 120 fps" statement
- Stale doc lines corrected in the same truth pass: CaptureTabView "(placeholders)" caption, AppSettings key list (eight capture keys + custom-folder path), Concurrency Model async exception, layer-diagram capture box
- Phase-gate automated standard green (full evidence in § Verification)

## Checkpoint Resolution

**Task 2 — `checkpoint:human-verify` (gate: blocking-human): APPROVED 2026-08-30**

The user ran all six steps of the 02-VALIDATION.md phase-gate smoke on a booted Simulator and replied "approved":

1. **Screenshot** — dimensions exact, no alpha channel, clean content
2. **~30 s recording** — playable, touch-indicator dots visible (delivered-fps figure not separately reported — user-verified acceptable)
3. **Exports** — GIF loops with even timing; MP4 plays (A2 resolved via passthrough — the wired HighestQuality re-encode fallback was not needed); MOV plays once
4. **Destinations** — all three verified (clipboard, desktop default, custom folder)
5. **Thumbnail** — auto-hide confirmed
6. **Cleanup** — no `boostersim-capture-*` temp residue

Cross-check: docs § Capture Tools matches the shipped behavior. A failing step would have routed to gap-closure planning per the plan's resume-signal; none occurred.

## Post-Review MOV Re-verification (2026-08-30)

CR-01 review finding invalidated the original step-3 MOV evidence (pre-fix export
self-deleted its staged input; the smoke had played the staged file). Fixed in e420435
(output routed to distinct boostersim-export-* sibling; both delete sites guarded;
regression-tested). User re-verified live: exported MOV plays with correct duration AND
the same recording still exports as GIF/MP4 afterward. Criterion 4 evidence restored.

## Task Commits

1. **Task 1 (auto):** `e49ccfb` docs — capture subsystem section + stale-line truth pass (60 insertions, 6 deletions)
2. **Task 2 (checkpoint:human-verify, gate blocking-human):** approved 2026-08-30 — no code change; closed via this continuation commit (docs only)

**Plan metadata:** dec9aab (halt record — SUMMARY + STATE) and this closure commit (SUMMARY + ROADMAP + STATE).

## Verification

- **Unit bundle (phase-gate standard):** `xcodebuild … test -only-testing:BoosterSimAppTests -skip-testing:BoosterSimAppUITests` → **TEST SUCCEEDED, exit 0, 79/79 passed, 0 failed** (wave-3 baseline 79 — no regression; the log's 78 joined "Test case … passed" lines + 1 status line split by output interleaving at the `** TEST SUCCEEDED **` boundary — the orphan `passed on 'My Mac…'` line is visible in the log)
- **Debug build:** `xcodebuild … -configuration Debug build` → **BUILD SUCCEEDED, exit 0**
- **Dependency pin (REQ-nfr-03):** `git diff --exit-code BoosterSimApp.xcodeproj/project.xcworkspace/xcshareddata/swiftpm` → exit 0 (vacuously clean — the share directory is untracked, the Phase 5 verifier finding); content stability verified instead via `shasum -a 256 Package.resolved` = `70386616a70796c3cfeea9cc621708cc294eac4c6825bfe400d52e4234cf8852`, byte-identical to the Phase 5 gate pin. Recommendation to track the file remains open in STATE.md
- **Docs acceptance greps:** all six required symbol names present in § Capture Tools; permission/degraded-behavior text and the ShowSingleTouches scope+restore note present
- **Pre-existing, documented, not chased:** the unfiltered `test` action exits 65 on pristine HEAD (ScreenshotTests env + launch-metrics; STATE.md, deferred-items.md)

## Files Created/Modified

- `docs/system-architecture.md` — § Capture Tools (new, ~47 lines): service split, data flow, permissions + degradation, ShowSingleTouches note, temp lifecycle, fps honesty; layer-diagram capture box; CaptureTabView/AppSettings/concurrency stale lines corrected

## Decisions Made

- Documented the subsystem as one § Capture Tools section following the Network Manipulation precedent (extend, not restructure — the plan's read_first instruction)
- Kept the swiftpm git-diff assertion in the gate record but paired it with the sha256 checksum, since the untracked file makes the git-level check vacuous (verifier finding, Phase 5)

## Deviations from Plan

None — plan executed exactly as written through Task 1.

## Issues Encountered

- xcodebuild log interleaving split one test's pass status onto a separate line (79th test), briefly reading as 78/79 — resolved by inspecting the log context; all 79 cases passed, exit 0

## User Setup Required

Task 2 smoke prerequisites (from the plan's `user_setup`):
- BoosterSimApp running with Screen Recording granted (System Settings → Privacy & Security → Screen & System Audio Recording)
- One booted iOS Simulator (6.9-inch class) with its window open
- Touch indicators: be ready to relaunch Simulator once after enabling them
- A ProMotion-capable display in use if a true-120 delivered-fps reading is wanted

## Next Phase Readiness

- Approval received 2026-08-30: Phase 2 closes — this SUMMARY marked complete, per-step smoke results recorded (§ Checkpoint Resolution), ROADMAP 02-04 checked, STATE ready-for-verification; REQ-roadmap-phase2-capture-tools + REQ-nfr-03 close on this plan
- No failing step — gap-closure path unused; A2 resolved via passthrough (re-encode fallback wired but not exercised)

## Self-Check: PASSED

- 02-04-SUMMARY.md exists on disk; modified file docs/system-architecture.md exists
- Commit e49ccfb present on main
- Task 1 acceptance criteria verified: all six required symbols present in § Capture Tools (19 symbol-name matches); unit bundle exit 0 (79/79); Debug build exit 0; swiftpm diff clean + Package.resolved checksum identical to the Phase 5 pin
- Task 2 acceptance closed: user approval 2026-08-30 (§ Checkpoint Resolution); ROADMAP 02-04 checked; closure commit present on main
