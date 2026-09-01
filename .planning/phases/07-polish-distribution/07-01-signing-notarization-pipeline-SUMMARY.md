---
phase: 07-polish-distribution
plan: 01
subsystem: infra
tags: [codesign, developer-id, notarization, notarytool, stapler, dmg, hdiutil, xcodebuild-archive, release-pipeline]

requires:
  - phase: 06-polish-predecessors
    provides: complete BoosteSimApp build surface (all prior phases) archived here as-is; no prior-phase artifacts consumed beyond the Xcode project itself
provides:
  - DEVELOPMENT_TEAM = K2TYLYAWMK at all 8 pbxproj sites (zero stale EQ8B89SPCX) — the final team ID plan 07-02's Sparkle work builds on
  - ExportOptions.plist (method developer-id, teamID K2TYLYAWMK, signingStyle automatic) — the export contract
  - scripts/build-release.sh — one-command release pipeline (pre-build Connect → archive → Developer-ID export → zip → notarize+staple → DMG) with a credential-free --skip-notarization path
  - docs/deployment-guide.md as the as-shipped runbook (script-first, manual equivalents, human-only credential setup, non-sandbox rationale)
  - A proven credential-free release: Developer-ID-signed BoosterSimApp.app (TeamIdentifier=K2TYLYAWMK, deep-strict codesign clean) + BoosterSim.dmg produced locally
affects: [07-02-sparkle-autoupdate-release-workflow (blocked on this halt: needs final team ID + this script), 07-06-phase-gate-closure (criterion 1 notarization half)]

actuals:
  tokens: 4400   # chars/4 over the realized diff (4 files, 267 insertions + 30 deletions, 17651 diff chars) — estimate said 22000
  tasks: 2       # Tasks 1-2 complete + committed; Task 3 halted at its blocking-human gate by design
  commits: 3     # 9f5545b (team switch + pipeline) + c74feff (docs as-shipped) + this metadata commit

tech-stack:
  added: []   # Apple toolchain only — xcodebuild/notarytool/stapler/ditto/hdiutil; zero packages
  patterns:
    - "Release script carries credentials by keychain-profile NAME only — profile-missing is a fail-fast error printing the exact interactive store-credentials command, never a prompt, never an embed"
    - "Stage-0 dependency pre-build + BUILD_DIR pin: build-system phases that nest xcodebuild inside an archive need their inputs pre-staged in the shared products tree the phase actually reads"

key-files:
  created:
    - ExportOptions.plist
    - scripts/build-release.sh
  modified:
    - BoosterSimApp.xcodeproj/project.pbxproj
    - docs/deployment-guide.md

key-decisions:
  - "Stage 0 pre-build + BUILD_DIR pin (deviation 1+2): the app target's pre-existing 'Build iOS Framework & Copy' phase attempts a nested iphonesimulator xcodebuild when the framework is absent; nested inside a macOS archive its Clang dependency scanner sees both trees' PulseObjCHelpers module maps (redefinition) and the error: lines fail the archive with exit 65. The release script pre-builds BoosterSimConnect into the shared products dir and passes BUILD_DIR=<that dir> to both the pre-build and the archive — the phase then takes its copy branch ('Copied BoosterSimConnect.framework', ARCHIVE SUCCEEDED). This mirrors STATE.md's Phase-5 convention (always build the BoosterSimConnect scheme first)"
  - "The archive action wipes its ArchiveIntermediates BuildProductsPath tree at start (verified: a staged Release-iphonesimulator/ vanished mid-archive) — pre-staging there is impossible; pinning BUILD_DIR on the archive invocation itself is the working seam"
  - "Flagged assumption 1 (export with automatic signing + developer-id method, no entitlements file) RESOLVED live: EXPORT SUCCEEDED, exported app carries Authority=Developer ID Application: Doan Duy Phuong (K2TYLYAWMK)"
  - "Flagged assumption 2 (private key accessible non-interactively) RESOLVED live: archive + export ran fully unattended with no keychain access prompt"
  - "Status halted at the blocking-human notarization gate (the 04-04 halt pattern): requirements stay open until a real accepted ticket + stapler validate + spctl pass — build/export success alone never closes criterion 1's notarization half (plan prohibition)"

patterns-established:
  - "Credential-free-first release scripts: --skip-notarization is the CI/dry-run path; the credential path fails fast with the exact human command instead of prompting"

requirements-completed: []   # REQ-roadmap-phase7-polish-distribution stays open — Task 3's real notarization ticket is the blocking-human gate

coverage:
  - id: D1
    description: "Team switch (K2TYLYAWMK x8, zero stale) + ExportOptions.plist + scripts/build-release.sh with a green credential-free end-to-end run: Developer-ID-signed exported app + DMG"
    requirement: REQ-roadmap-phase7-polish-distribution
    verification:
      - kind: other
        ref: "plan verify chain: grep count 8 | grep -qx 8 PASS; ! grep EQ8B89SPCX PASS; plutil -lint ExportOptions.plist OK; bash -n scripts/build-release.sh OK"
        status: pass
      - kind: other
        ref: "scripts/build-release.sh --skip-notarization -> exit 0 (BUILD SUCCEEDED / Copied BoosterSimConnect.framework / ** ARCHIVE SUCCEEDED ** / ** EXPORT SUCCEEDED ** / stage-4 skip line / DMG created)"
        status: pass
      - kind: other
        ref: "codesign -dv --verbose=2 build/export/BoosterSimApp.app -> TeamIdentifier=K2TYLYAWMK, Authority=Developer ID Application: Doan Duy Phuong (K2TYLYAWMK); codesign --verify --deep --strict PASS; build/BoosterSim.dmg (4,109,918 B) + build/BoosterSimApp.zip (3,575,912 B) present"
        status: pass
    human_judgment: false
  - id: D2
    description: "docs/deployment-guide.md as-shipped: script-first runbook with per-stage manual equivalents, human-only credential runbook, non-sandbox rationale, corrected requirements floor and version"
    requirement: REQ-roadmap-phase7-polish-distribution
    verification:
      - kind: other
        ref: "plan verify chain: no 'planned for Phase 7'; store-credentials, booster-notary, ENABLE_APP_SANDBOX, build-release.sh, 'stapler validate' all present; no 'macOS 15 Sequoia' — all PASS"
        status: pass
    human_judgment: false
  - id: D3
    description: "Real notarization: store-credentials interactively, submit the exported zip, staple, record the accepted ticket id + stapler validate + spctl verdict"
    requirement: REQ-roadmap-phase7-polish-distribution
    verification: []
    human_judgment: true
    rationale: "Apple ID app-specific password creation and interactive xcrun notarytool store-credentials are human-owned credentials that cannot be scripted (plan user_setup; T-07-01). Only Apple's accepted ticket is trustworthy proof (T-07-02/T-07-03) — blocked pending the user's credential setup + submission."

duration: 35min to halt
completed: 2026-09-01
status: halted
---

# Phase 7 Plan 01: Signing & Notarization Pipeline Summary

**Signing switched to the Developer-ID team (K2TYLYAWMK, all 8 pbxproj sites) with a one-command credential-free release pipeline — archive → Developer-ID export → zip → DMG proven end-to-end (exit 0, deep-strict codesign clean) — and the deployment guide converted to the as-shipped runbook; halted exactly as designed at Task 3's blocking-human notarization gate (real Apple ticket pending)**

**STATUS: HALTED at `checkpoint:human-verify gate="blocking-human"` — Task 3 (real notarization) awaits the user. Requirements stay open until the gate resolves (the 04-04 halt pattern).**

## Performance

- **Duration:** 35 min to halt (started 2026-09-01T03:35:17Z, halted ~04:10Z)
- **Tasks:** 2 of 3 complete (Task 1 tracer ✅, Task 2 ✅; Task 3 halted at its blocking-human gate — not attempted, per plan)
- **Files modified:** 4 (pbxproj, ExportOptions.plist, scripts/build-release.sh, docs/deployment-guide.md)

## Accomplishments

- **Team switch (D-4):** all 8 `DEVELOPMENT_TEAM` occurrences switched `EQ8B89SPCX` → `K2TYLYAWMK` (project Debug+Release, app ×2, tests ×2, UITests ×2); `CODE_SIGN_STYLE = Automatic`, `ENABLE_HARDENED_RUNTIME = YES`, `ENABLE_APP_SANDBOX = NO` untouched; zero stale team strings anywhere in the repo
- **Release pipeline:** `scripts/build-release.sh` (stages 0–5, each header-logged) + `ExportOptions.plist` — one command produces a Developer-ID-signed app and DMG from a clean Release archive; the notarize stage is fully scripted but inert until the `booster-notary` keychain profile exists (fail-fast with the exact interactive command, never a prompt, zero credential material in the script)
- **Credential-free run proven:** full `--skip-notarization` run exit 0 — `** ARCHIVE SUCCEEDED **`, `** EXPORT SUCCEEDED **`, stage-4 skip line logged, `build/BoosterSim.dmg` + `build/BoosterSimApp.zip` produced; exported app `TeamIdentifier=K2TYLYAWMK`, `Authority=Developer ID Application: Doan Duy Phuong (K2TYLYAWMK)`, `codesign --verify --deep --strict` clean
- **Docs as-shipped:** deployment-guide's deferred "Distribution (Future)" skeleton replaced by the shipped runbook — script-first stage table with per-stage manual equivalents, one-time human-only credential setup (`store-credentials booster-notary`, placeholder markup only), tightened non-sandbox rationale with the Developer-ID-compatibility statement, requirements floor corrected to macOS 26.2 / Xcode 26.3, version aligned to MARKETING_VERSION = 1.0, `hdiutil` documented as shipped (create-dmg rejected)

## Task 1 Evidence (plan verify chain, verbatim run)

| Check | Result |
|---|---|
| `grep -c 'DEVELOPMENT_TEAM = K2TYLYAWMK' pbxproj` | **8** (required: 8) |
| `grep -q 'EQ8B89SPCX' pbxproj` | **no match** (stale team gone; repo-wide grep also clean) |
| `plutil -lint ExportOptions.plist` | **OK** |
| `bash -n scripts/build-release.sh` | **OK** |
| `scripts/build-release.sh --skip-notarization` | **exit 0** — BUILD SUCCEEDED (stage 0) → `Copied BoosterSimConnect.framework` → **ARCHIVE SUCCEEDED** → **EXPORT SUCCEEDED** → zip → `Notarization SKIPPED (--skip-notarization): no ticket, no staple` → DMG |
| `test -f build/BoosterSim.dmg` | **PASS** (4,109,918 bytes; zip 3,575,912 bytes) |
| `codesign -dv` on exported app | `Identifier=sim-dev.BoosterSimApp`, `TeamIdentifier=K2TYLYAWMK`, `Authority=Developer ID Application: Doan Duy Phuong (K2TYLYAWMK)` → chain Developer ID CA → Apple Root CA |
| `codesign --verify --deep --strict build/export/BoosterSimApp.app` | **PASS** (exit 0) |

Flagged assumptions (plan frontmatter), dispositioned live:
- **A1 — export with automatic signing + developer-id method, no entitlements file:** RESOLVED (EXPORT SUCCEEDED; Developer-ID re-sign verified)
- **A2 — K2TYLYAWMK private key accessible non-interactively:** RESOLVED (archive + export ran fully unattended, no keychain prompt)

## Task 3 — HALTED: blocking-human notarization checkpoint

Task 3 is `checkpoint:human-verify gate="blocking-human"` and was **not** attempted, per plan: the Apple ID app-specific password and interactive `xcrun notarytool store-credentials` are human-owned (plan `user_setup`; threat T-07-01). The machine-checkable half (`stapler validate`, `spctl --assess`) runs only after a real submission exists.

**Runbook presented to the user (docs/deployment-guide.md carries the same steps):**
1. Create an app-specific password at appleid.apple.com → Sign-In and Security → App-Specific Passwords
2. `xcrun notarytool store-credentials booster-notary --apple-id <Apple ID> --team-id K2TYLYAWMK --password <app-specific password>` (interactive — human-owned)
3. `scripts/build-release.sh` (full path — submits the zip, waits, staples, validates)
4. Read back the ticket: `xcrun notarytool history --keychain-profile booster-notary` → Accepted + id

**Resume signal:** reply "notarized" (with the ticket id if handy); after that the machine half runs (`xcrun stapler validate build/export/BoosterSimApp.app`, `spctl --assess --type execute -vv build/export/BoosterSimApp.app`) and the ticket id, submit→accept duration, and both verdicts get recorded here. A rejected submission is captured verbatim (notarytool log) — criterion 1's notarization half is not claimed either way until then.

**Known risk to watch at submission (as-shipped fact, recorded for the gate):** the exported app embeds `BoosterSimConnect.framework` (an iOS-simulator framework) in `Contents/Resources` — placed there by the app target's pre-existing copy phase, loaded only in DEBUG builds. If Apple's notary service rejects on it, the rejection reason will be surfaced verbatim rather than papered over.

## Task Commits

1. **Task 1: team switch + release pipeline** — `9f5545b` (feat: pbxproj ×8, ExportOptions.plist, scripts/build-release.sh; verify chain all-pass)
2. **Task 2: deployment guide as-shipped** — `c74feff` (docs: runbook + credential setup + non-sandbox rationale + corrected floor/version)
3. **Task 3: no commit** — halted at the blocking-human gate (no files)

**Plan metadata:** this commit (docs: signing/notarization pipeline halted at human gate).

## Files Created/Modified

- `BoosterSimApp.xcodeproj/project.pbxproj` — DEVELOPMENT_TEAM K2TYLYAWMK ×8 (only change; verified nothing else touched)
- `ExportOptions.plist` — method developer-id, teamID K2TYLYAWMK, signingStyle automatic; no provisioning keys
- `scripts/build-release.sh` — stages 0–5; env-configurable (PROJECT/SCHEME/CONFIGURATION/BUILD_DIR/NOTARY_PROFILE); `--skip-notarization`; fail-fast profile check printing the exact `store-credentials` command; ends by printing every artifact path
- `docs/deployment-guide.md` — as-shipped distribution runbook (truth-gated: every command/path matches the shipped script)

## Decisions Made

- Stage-0 pre-build + BUILD_DIR pin instead of touching the pbxproj script phase (the plan forbids pbxproj changes beyond the team string) — see deviations 1–2
- Halt pattern per 04-04: halted SUMMARY (`status: halted`, `requirements-completed: []`), plan counter NOT advanced, requirements NOT marked — close-out happens when the gate resolves
- 07-02 (Sparkle) reads the final team ID and this script from here, but stays blocked until this halt resolves

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Archive failed inside the app target's nested iOS-framework build**
- **Found during:** Task 1 (first release run)
- **Issue:** `xcodebuild archive` exited 65 with `error: Redefinition of module 'PulseObjCHelpers'` / `Clang dependency scanner failure` — the app target's pre-existing "Build iOS Framework & Copy" script phase runs a nested `xcodebuild -sdk iphonesimulator` whose scanner sees both the iphonesimulator and the archive's macOS generated module maps in the shared DerivedData; the `error:` lines fail the archive even though every phase completed
- **Fix:** `scripts/build-release.sh` stage 0 pre-builds `BoosterSimConnect` (Release/iphonesimulator) before the archive — the documented STATE.md Phase-5 convention — so the script phase takes its copy branch (`Copied BoosterSimConnect.framework`) and never nests
- **Files modified:** scripts/build-release.sh
- **Verification:** clean `--skip-notarization` run exit 0 with `** ARCHIVE SUCCEEDED **`; zero redefinition errors in the log
- **Committed in:** 9f5545b

**2. [Rule 3 - Blocking] Pre-staged framework vanished — archive wipes its BuildProductsPath**
- **Found during:** Task 1 (fix iteration for deviation 1)
- **Issue:** staging the pre-built framework at the archive's `ArchiveIntermediates/.../BuildProductsPath/Release-iphonesimulator/` did not trigger the copy branch — the archive action wipes that tree at start (verified: the staged directory disappeared)
- **Fix:** the script resolves the scheme's shared products dir via `-showBuildSettings` and passes `BUILD_DIR=<products dir>` on **both** the stage-0 pre-build and the archive invocation — the script phase then reads the shared tree where the framework already sits
- **Files modified:** scripts/build-release.sh
- **Verification:** `Copied BoosterSimConnect.framework to …/Build/Products/Release/BoosterSimApp.app/Contents/Resources` + `** ARCHIVE SUCCEEDED **` + `** EXPORT SUCCEEDED **`, exit 0
- **Committed in:** 9f5545b

**3. [Rule 1 - Truth] Stale `cd BoosterSimApp` line in the doc's Build & Run block**
- **Found during:** Task 2
- **Issue:** the dev-build snippet's `cd BoosterSimApp` pointed below the repo root where no `.xcodeproj` lives (pre-existing staleness, adjacent to the Requirements block the plan did scope)
- **Fix:** dropped the line (the `.xcodeproj` is at repo root) while correcting the Requirements floor in the same section
- **Files modified:** docs/deployment-guide.md
- **Verification:** the doc's commands now run verbatim from repo root
- **Committed in:** c74feff

---

**Total deviations:** 3 auto-fixed (2 blocking, 1 truth)
**Impact on plan:** Deviations 1–2 were required for the task's own `<verify>` to pass (no release run → no DMG → no proof); both live inside the new script, zero pbxproj/script-phase changes, no scope creep. Deviation 3 is a one-line truth fix inside the section Task 2 already owned.

## Issues Encountered

- Two archive failures (exit 65) before the stage-0 + BUILD_DIR fix landed — full diagnosis in deviations 1–2; final pipeline run is green and reproducible
- No permission errors, file locks, or keychain access prompts were encountered at any point

## Known Stubs

None — no stubs introduced. The notarization stage is not a stub: it is fully implemented and deliberately inert (credential-free path) until the human-owned keychain profile exists.

## User Setup Required

**One-time, human-only (blocks Task 3):** an Apple ID app-specific password for the notary profile — appleid.apple.com → Sign-In and Security → App-Specific Passwords — then the interactive `xcrun notarytool store-credentials booster-notary --apple-id <Apple ID> --team-id K2TYLYAWMK --password <app-specific password>` and `scripts/build-release.sh`. Full steps: docs/deployment-guide.md § "One-time credential setup".

## Next Phase Readiness

- 07-02 (Sparkle + release workflow) consumes this plan's outputs (final team ID, build-release.sh) but is **blocked** until this halt resolves — resume via the checkpoint reply, then re-summarize as `complete`
- Criterion 1 status: signing half ✅ proven; documentation half ✅; flow half ✅ (script proven credential-free); notarization half ⏸ pending the real ticket
- After the gate: record ticket id + durations + stapler/spctl verdicts, flip SUMMARY to `complete`, `requirements-completed: [REQ-roadmap-phase7-polish-distribution]` stays with the phase's other plans (07-01 only partially carries it — requirement closes at phase level)

---
*Phase: 07-polish-distribution*
*Halted at blocking-human notarization gate: 2026-09-01*

## Self-Check: PASSED

ExportOptions.plist, scripts/build-release.sh, docs/deployment-guide.md and this SUMMARY exist on disk; commits 9f5545b + c74feff present on main; Task 1 verify chain re-run verbatim (all eight checks, outputs above); Task 2 grep gate re-run verbatim (all seven checks PASS); pbxproj carries 8× K2TYLYAWMK and zero EQ8B89SPCX. Task 3 intentionally not executed — halted at its blocking-human gate.
