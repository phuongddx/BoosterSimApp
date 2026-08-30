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
  - Phase-gate manual smoke (Task 2) — PENDING user execution on a booted Simulator
affects: [02-phase-closure, 03-app-actions]

# Actuals (#2632) — pairs with the plan's estimate (18k tokens, low confidence)
actuals:
  tokens: 2831        # chars/4 over the realized Task-1 diff (e49ccfb): 11,324 chars, 60 insertions / 6 deletions
  tasks: 1            # Task 1 complete; Task 2 blocking-human smoke outstanding
  commits: 1          # e49ccfb (docs); halt commit follows

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

requirements-completed: []   # REQ-roadmap-phase2-capture-tools + REQ-nfr-03 close at gate approval (Task 2 continuation fills these)

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
    verification: []
    human_judgment: true
    rationale: "Live SCK capture, playable recordings, delivered-fps measurement, clipboard/desktop/custom saves, and TCC state are manual-only per the phase validation strategy — not reproducible in unit tests"

# Metrics
duration: 8min
completed: 2026-08-30
status: halted         # Task 1 green + committed; Task 2 blocking-human phase-gate smoke PENDING user approval
---

# Phase 02 Plan 04: Phase-Gate Closure Summary

**Architecture docs now describe the shipped capture subsystem (service split, permissions + degradation, ShowSingleTouches scope/restore, temp lifecycle) and the phase-gate automated standard is green — unit bundle 79/79 exit 0, Debug build clean, zero dependency change; halted at the blocking-human six-step phase-gate smoke**

## Performance

- **Duration:** 8 min so far (started 2026-08-30T14:11:38Z, halted 2026-08-30T14:19:32Z)
- **Tasks:** 1 of 2 complete (Task 2 = blocking-human phase-gate smoke, PENDING)
- **Files modified:** 1 (docs/system-architecture.md)
- **Commits:** 1 production (e49ccfb) + this halt commit

## Accomplishments

- § Capture Tools added to docs/system-architecture.md: service-split table (CaptureService facade, ScreenshotService SCScreenshotManager one-shot, RecordingService SCStream + SCRecordingOutput at CMTime(1,120)/queueDepth 5/HEVC staged .mov, CaptureCompositor pure ASC geometry, CaptureExporter AVAssetReader→ImageIO GIF + AVAssetExportSession MP4/MOV with A2 re-encode fallback, TouchIndicatorController, CaptureThumbnailPanel, CaptureSaveRouter), the Capture-tab→destination-routing data flow diagram, the Screen Recording permission block (TCC required, grant-requires-restart cycle, degraded setup UX per the AGENTS.md rule), the ShowSingleTouches cross-app note (single scoped key on com.apple.iphonesimulator, snapshot + restore on every exit path incl. kCFNull), the temp-lifecycle/retention paragraph, and the honest "Up to 120 fps" statement
- Stale doc lines corrected in the same truth pass: CaptureTabView "(placeholders)" caption, AppSettings key list (eight capture keys + custom-folder path), Concurrency Model async exception, layer-diagram capture box
- Phase-gate automated standard green (full evidence in § Verification)

## Checkpoint Pending

**Task 2 — `checkpoint:human-verify` (gate: blocking-human): PENDING**

Task 1's automated half is done; the phase gate itself — the six-step manual smoke from 02-VALIDATION.md — requires the user on a live booted Simulator. Nothing further executes until approval; per the plan's resume-signal, failures route to gap-closure planning, not silent closure. A2 (MP4 passthrough) resolves live at step 3 with the re-encode fallback already wired in CaptureExporter.

## Task Commits

1. **Task 1 (auto):** `e49ccfb` docs — capture subsystem section + stale-line truth pass (60 insertions, 6 deletions)
2. **Task 2 (checkpoint:human-verify, gate blocking-human):** PENDING — no code change expected; closes via user approval + continuation

**Plan metadata:** this halt commit (SUMMARY + STATE).

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

- On approval: Phase 2 closes — continuation marks this SUMMARY complete, records the per-step smoke results + delivered-fps line, checks ROADMAP 02-04, and closes REQ-roadmap-phase2-capture-tools + REQ-nfr-03 on this plan
- On any failing step: gap-closure planning (the plan's resume-signal contract — no silent closure); A2 failure specifically triggers the already-wired AVAssetExportPresetHighestQuality re-encode inside CaptureExporter before the phase closes

## Self-Check: PASSED

- 02-04-SUMMARY.md exists on disk; modified file docs/system-architecture.md exists
- Commit e49ccfb present on main
- Task 1 acceptance criteria verified: all six required symbols present in § Capture Tools (19 symbol-name matches); unit bundle exit 0 (79/79); Debug build exit 0; swiftpm diff clean + Package.resolved checksum identical to the Phase 5 pin
- Task 2 acceptance intentionally outstanding — blocking-human gate
