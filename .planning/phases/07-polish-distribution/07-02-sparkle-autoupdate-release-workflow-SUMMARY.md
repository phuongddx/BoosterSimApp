---
phase: 07-polish-distribution
plan: 02
subsystem: infra
tags: [sparkle, auto-update, eddsa, appcast, spm, github-actions, release-workflow, info-plist, package-resolved]

requires:
  - phase: 07-polish-distribution (plan 01)
    provides: DEVELOPMENT_TEAM = K2TYLYAWMK at all 8 pbxproj sites (final team ID), ExportOptions.plist, scripts/build-release.sh (archive → Developer-ID export → notarize → staple → DMG) — the pipeline release.yml calls
provides:
  - Sparkle 2.9.6 as an SPM dependency of the BoosterSimApp target ONLY (4 Pulse-template pbxproj edits; BoosterSimConnect stays Pulse-only)
  - Package.resolved tracked in git for the first time with exactly 2 pins (pulse 5.2.2 + sparkle 2.9.6) — the Phase 2–5 infra gap closed; plan 07-06's git-level pin gate is real for the first time
  - Sparkle named as the second explicit exception to the Apple-frameworks-only policy (PROJECT.md Constraints + Out-of-Scope + Key Decisions; REQUIREMENTS.md REQ-nfr-03 + Out-of-Scope)
  - Runtime update chain: SPUStandardUpdaterController in AppDelegate's service block + "Check for Updates…" menu item + SUFeedURL (GitHub Releases appcast URL) in the built Info.plist; SUPublicEDKey present-but-empty pending the human gate
  - SparkleInfo.plist + INFOPLIST_FILE merge mechanism (both app configs) — the working route for arbitrary Info.plist keys under GENERATE_INFOPLIST_FILE
  - .github/workflows/release.yml — tag-push (v*) pipeline: cert import → notarytool ASC credentials → build-release.sh → generate_appcast → GitHub Release (DMG + appcast.xml), credentials as named secrets only
  - docs/deployment-guide.md CI release secrets runbook (p12 export, ASC key creation, generate_keys -x export)
affects: [07-06-phase-gate-closure (blocked on this halt: EdDSA key + first real pin gate), 07-01 gate (parallel human credential step on the same release machine)]

actuals:
  tokens: 5000    # chars/4 over the realized diff (20,058 diff chars, 6130b68..9689e73) — estimate said 25000
  tasks: 2        # Tasks 1-2 complete + committed; Task 3 halted at its blocking-human gate by design
  commits: 3      # 0bfba56 (dependency + policy) + 9689e73 (wiring + workflow) + this metadata commit

tech-stack:
  added: [Sparkle 2.9.6 (SPM, macOS app target only)]
  patterns:
    - "Arbitrary Info.plist keys under GENERATE_INFOPLIST_FILE go through a real INFOPLIST_FILE (merge), never an INFOPLIST_KEY_* prefix — Xcode 26.3's generated-plist table drops unknown prefixes (proven by built-plist dump)"
    - "Release workflows reference credentials only as secrets.* by name and hard-code only names; the 'Required repository secrets' comment block at the top of the workflow mirrors the deployment-guide runbook"

key-files:
  created:
    - .github/workflows/release.yml
    - SparkleInfo.plist
  modified:
    - BoosterSimApp.xcodeproj/project.pbxproj
    - BoosterSimApp.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved (tracked for the first time)
    - BoosterSimApp/App/AppDelegate.swift
    - BoosterSimApp/Views/MenuBar/MenuBarView.swift
    - .planning/PROJECT.md
    - .planning/REQUIREMENTS.md
    - docs/deployment-guide.md

key-decisions:
  - "SU keys live in SparkleInfo.plist consumed via INFOPLIST_FILE + GENERATE_INFOPLIST_FILE merge in both app configs — the plan's flagged assumption (arbitrary INFOPLIST_KEY_* prefixes flow into the generated plist) was DISPROVEN by dumping a built Info.plist: the setting was present in -showBuildSettings while the key was absent from the plist; known keys (NSHumanReadableCopyright) pass, unknown keys (SUFeedURL) are dropped. Task 3's paste site for the EdDSA public key is therefore SparkleInfo.plist's SUPublicEDKey, not an INFOPLIST_KEY value (plan wording deviation, documented below)"
  - "Sparkle attaches to the BoosterSimApp target only — a macOS package must not link into the iphonesimulator BoosterSimConnect target (07-PATTERNS single-target delta); verified by Sparkle.framework 2.9.6 embedded + linked (@rpath/Sparkle.framework/Versions/B/Sparkle) in the app and both schemes building green"
  - "MenuBarView needs its own `import Sparkle` under SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY — member visibility requires the defining module's import at every call site, not just where the service lives"
  - "Halted at the blocking-human EdDSA gate (07-01's pattern): requirements stay open, plan counter not advanced — Task 3's keypair generation is a human-credential step on the release machine"

patterns-established:
  - "Named-secrets-only release workflows with a top-of-file secret manifest mirroring the runbook doc (single place to look: workflow comment + deployment-guide table)"

requirements-completed: []   # REQ-roadmap-phase7-polish-distribution stays open — Task 3's real EdDSA keypair is the blocking-human gate

coverage:
  - id: D1
    description: "Sparkle 2.9.6 SPM dependency on the app target only + Package.resolved tracked with exactly 2 pins + the policy exception named in PROJECT.md and REQUIREMENTS.md"
    requirement: REQ-roadmap-phase7-polish-distribution
    verification:
      - kind: other
        ref: "plan verify chain: grep Sparkle repositoryURL PASS; grep minimumVersion = 2.9.6 PASS; git ls-files --error-unmatch Package.resolved PASS; python pins == {pulse, sparkle} PASS; grep Sparkle in PROJECT.md + REQUIREMENTS.md PASS"
        status: pass
      - kind: other
        ref: "xcodebuild BoosterSimApp (macOS) + BoosterSimConnect (generic/platform=iOS Simulator) both ** BUILD SUCCEEDED **; otool on the built app: @rpath/Sparkle.framework/Versions/B/Sparkle linked, Sparkle.framework embedded in Contents/Frameworks"
        status: pass
    human_judgment: false
  - id: D2
    description: "Runtime updater: SPUStandardUpdaterController service + 'Check for Updates…' menu item + SUFeedURL in the built Info.plist (SUPublicEDKey honestly empty pending the gate); unit bundle green"
    requirement: REQ-roadmap-phase7-polish-distribution
    verification:
      - kind: other
        ref: "greps: SPUStandardUpdaterController in AppDelegate, 'Check for Updates' in MenuBarView, INFOPLIST_FILE = SparkleInfo.plist in both app configs (x2)"
        status: pass
      - kind: other
        ref: "xcodebuild Debug build (build/updater-check) ** BUILD SUCCEEDED **; PlistBuddy Print :SUFeedURL -> https://github.com/phuongddx/BoosterSimApp/releases/latest/download/appcast.xml; :SUPublicEDKey present-empty (merge proven: LSUIElement/NSHumanReadableCopyright/CFBundleDisplayName still generated)"
        status: pass
      - kind: unit
        ref: "xcodebuild test -only-testing:BoosterSimAppTests (Swift Testing, 27 suites) -> ** TEST SUCCEEDED **"
        status: pass
    human_judgment: false
  - id: D3
    description: ".github/workflows/release.yml (tag-push v*: cert import → notarytool ASC credentials → scripts/build-release.sh → generate_appcast → GitHub Release with DMG + appcast.xml) + CI-secrets runbook in docs/deployment-guide.md"
    requirement: REQ-roadmap-phase7-polish-distribution
    verification:
      - kind: other
        ref: "python3 yaml.safe_load(release.yml) OK; grep build-release.sh PASS; grep generate_appcast PASS; ! grep -qi 'password.*:' PASS (zero literal credentials — named secrets only)"
        status: pass
    human_judgment: false
  - id: D4
    description: "Sparkle EdDSA keypair: generate_keys on the release machine, real SUPublicEDKey wired, keychain entry confirmed"
    requirement: REQ-roadmap-phase7-polish-distribution
    verification: []
    human_judgment: true
    rationale: "EdDSA private-key generation stores a credential in the LOCAL keychain via Sparkle's generate_keys — a one-time human-credential step (plan user_setup; T-07-05). Updates cannot be trusted before the real public key is pinned: an empty SUPublicEDKey is an honest open item, never a finished update chain (plan transparency prohibition)."

duration: 12min to halt
completed: 2026-09-01
status: halted
---

# Phase 7 Plan 02: Sparkle Auto-Update & Release Workflow Summary

**Sparkle 2.9.6 shipped as the second named SPM exception (app target only, Package.resolved tracked for the first time with pins pulse 5.2.2 + sparkle 2.9.6), the updater wired end-to-end (SPUStandardUpdaterController + "Check for Updates…" + GitHub-Releases appcast feed URL in the built Info.plist), and a tag-push release workflow that notarizes/DMGs/appcasts with named GitHub secrets only — halted exactly as designed at Task 3's blocking-human EdDSA keypair gate (SUPublicEDKey honestly empty)**

**STATUS: HALTED at `checkpoint:human-verify gate="blocking-human"` — Task 3 (Sparkle EdDSA keypair) awaits the user. Requirements stay open until the gate resolves (the 07-01/04-04 halt pattern).**

## Performance

- **Duration:** 12 min to halt (started 2026-09-01T05:05:01Z, halted ~05:17Z)
- **Tasks:** 2 of 3 complete (Task 1 ✅, Task 2 ✅; Task 3 halted at its blocking-human gate — not attempted, per plan)
- **Files modified:** 9 (pbxproj, Package.resolved [newly tracked], AppDelegate.swift, MenuBarView.swift, PROJECT.md, REQUIREMENTS.md, release.yml, SparkleInfo.plist, deployment-guide.md)

## Accomplishments

- **Dependency (ROADMAP C2 dependency half):** Sparkle 2.9.6 added via the four coordinated Pulse-template pbxproj edits (fresh ids `FFD01CD7…` package ref + `AD727C48…` product dep), attached to the BoosterSimApp target only; both schemes build green; Sparkle.framework 2.9.6 embedded and linked in the app (`@rpath/Sparkle.framework/Versions/B/Sparkle`)
- **Pin gate made real:** `Package.resolved` tracked in git for the first time (the Phase 2–5 infra gap from STATE.md) with exactly two pins — pulse 5.2.2 + sparkle 2.9.6
- **Policy truth (C2 policy half):** PROJECT.md (Constraints, Out of Scope, Key Decisions row) and REQUIREMENTS.md (REQ-nfr-03, Out-of-Scope table) name Sparkle as the second explicit exception, user-resolved 2026-09-01 — the Apple-frameworks-only policy is never silently widened
- **Runtime wiring (C2 runtime half):** `SPUStandardUpdaterController(startingUpdater: true, …)` as a lazy service in AppDelegate's Feature Services block; "Check for Updates…" between Preferences and About calling `checkForUpdates(nil)`; SUFeedURL = `https://github.com/phuongddx/BoosterSimApp/releases/latest/download/appcast.xml` verified **in the built app's Info.plist**; unit bundle green with Sparkle linked
- **Release pipeline (C2 release half):** `.github/workflows/release.yml` — `on: push: tags ['v*']`, macos-26, sibling of ci.yml — imports the Developer ID cert from `APPLE_CERTIFICATE_P12` into a temporary keychain, stores notarytool credentials in ASC API-key form, runs `scripts/build-release.sh` (no pipeline duplication), signs the appcast via `generate_appcast --ed-key-file` with the key from `SPARKLE_PRIVATE_KEY`, and publishes the GitHub Release with DMG + appcast.xml; every credential is a named secret and the workflow hard-codes only names
- **Runbook:** docs/deployment-guide.md gained the "CI release secrets" subsection — the six secrets, where each value comes from, and the SUFeedURL/SUPublicEDKey pairing warning

## Task 1 Evidence (plan verify chain, verbatim run)

| Check | Result |
|---|---|
| `grep -q 'repositoryURL = "https://github.com/sparkle-project/Sparkle.git"' pbxproj` | **PASS** |
| `grep -q 'minimumVersion = 2.9.6' pbxproj` | **PASS** |
| `git ls-files --error-unmatch …/Package.resolved` | **PASS** (tracked for the first time) |
| python pins assertion | **{pulse, sparkle}** — exactly 2 pins |
| `grep -q 'Sparkle'` PROJECT.md / REQUIREMENTS.md | **PASS / PASS** |
| `xcodebuild -scheme BoosterSimApp -destination 'platform=macOS' build` | **BUILD SUCCEEDED** |
| `xcodebuild -scheme BoosterSimConnect -destination 'generic/platform=iOS Simulator' build` | **BUILD SUCCEEDED** |
| Link proof (extra) | `otool -L …/BoosterSimApp.debug.dylib` → `@rpath/Sparkle.framework/Versions/B/Sparkle (compatibility 1.6.0, current 2.9.6)`; Sparkle.framework in `Contents/Frameworks` |

## Task 2 Evidence (verify chain; SUFeedURL component adapted to the INFOPLIST_FILE mechanism — see deviation 1)

| Check | Result |
|---|---|
| `grep SPUStandardUpdaterController` AppDelegate.swift | **PASS** (lazy service, Feature Services block) |
| `grep 'Check for Updates'` MenuBarView.swift | **PASS** (between Preferences and About) |
| SUFeedURL in both app configs | **PASS** — as `INFOPLIST_FILE = SparkleInfo.plist` (×2) + SUFeedURL in SparkleInfo.plist (the plan's `grep -c INFOPLIST_KEY_SUFeedURL = 2` form was replaced by its intent — see deviation 1) |
| `python3 -c "yaml.safe_load(release.yml)"` | **PASS** (PyYAML 6.0.3) |
| `grep build-release.sh` / `grep generate_appcast` release.yml | **PASS / PASS** |
| `! grep -qi 'password.*:' release.yml` | **PASS** — zero literal credentials; all values `secrets.*` |
| `xcodebuild … Debug -derivedDataPath build/updater-check build` | **BUILD SUCCEEDED** |
| `PlistBuddy -c 'Print :SUFeedURL' …/Info.plist` | `https://github.com/phuongddx/BoosterSimApp/releases/latest/download/appcast.xml` |
| `PlistBuddy -c 'Print :SUPublicEDKey'` | present, empty string (honest open item for the gate) |
| Unit bundle (`-only-testing:BoosterSimAppTests`, Swift Testing) | **TEST SUCCEEDED** (must_haves: "the unit bundle stays green") |

## Task 3 — HALTED: blocking-human EdDSA checkpoint

Task 3 is `checkpoint:human-verify gate="blocking-human"` and was **not** attempted, per plan: Sparkle's `generate_keys` stores the EdDSA private key in the LOCAL keychain — a one-time human-credential step on the release machine (the same machine that owns the notary profile), not scriptable without keychain access prompts (plan `user_setup`; threat T-07-05). Without the real public key, updates cannot be verified — the plan's transparency prohibition forbids a placeholder.

**Runbook presented to the user (docs/deployment-guide.md § "CI release secrets" carries the same steps):**
1. Locate Sparkle's generate_keys: `find build ~/Library/Developer/Xcode/DerivedData -path '*Sparkle*bin/generate_keys' -type f 2>/dev/null | head -1` (the SPM checkout is already on this machine from Task 1's resolve)
2. Run it — creates the EdDSA keypair, private key stored in the login keychain (service `https://sparkle-project.org`), public key printed to terminal
3. Paste the printed public key as the **`SUPublicEDKey` value in `SparkleInfo.plist`** (repo root) — NOTE: the plan's original wording said "both BoosterSimApp configs (`INFOPLIST_KEY_SUPublicEDKey`)", but that mechanism was disproven (deviation 1); the single `SparkleInfo.plist` feeds BOTH app configurations via `INFOPLIST_FILE`, so one paste covers Debug and Release
4. Optional now / required before the first real release: `generate_keys -x <file>` export → GitHub secret `SPARKLE_PRIVATE_KEY` for appcast signing in CI

**Machine half (runs after the user reports the key pasted):** rebuild Debug, `PlistBuddy Print :SUPublicEDKey` (non-empty, >20 chars), `security find-generic-password -s "https://sparkle-project.org"` (or accept the user's visual keychain confirmation if the service name differs by Sparkle version). Record the public key fingerprint/first chars here.

**Resume signal:** reply "key wired" to close this plan, or report the generate_keys failure — without a real EdDSA key the update chain is honestly incomplete and the phase gate (07-06) carries it as an open item.

## Task Commits

1. **Task 1: Sparkle SPM dependency + policy exception + tracked pin** — `0bfba56` (feat: pbxproj 4 edits, Package.resolved tracked, PROJECT.md + REQUIREMENTS.md wording; verify chain all-pass)
2. **Task 2: updater wiring + release workflow + runbook** — `9689e73` (feat: AppDelegate + MenuBarView + SparkleInfo.plist/INFOPLIST_FILE + release.yml + deployment-guide; verify chain all-pass, unit bundle green)
3. **Task 3: no commit** — halted at the blocking-human gate (no files)

**Plan metadata:** this commit (docs: Sparkle auto-update halted at human gate).

## Files Created/Modified

- `BoosterSimApp.xcodeproj/project.pbxproj` — Sparkle package ref + packageReferences + product dependency + app-target attach; `INFOPLIST_FILE = SparkleInfo.plist` in both app configs
- `BoosterSimApp.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved` — tracked for the first time; 2 pins
- `BoosterSimApp/App/AppDelegate.swift` — `import Sparkle` + lazy `updaterController` (SPUStandardUpdaterController)
- `BoosterSimApp/Views/MenuBar/MenuBarView.swift` — `import Sparkle` + "Check for Updates…" item
- `SparkleInfo.plist` — SUFeedURL + SUPublicEDKey (empty pending gate); merged into the generated Info.plist for both configs
- `.github/workflows/release.yml` — tag-push release pipeline (secrets manifest at top)
- `docs/deployment-guide.md` — "CI release secrets (GitHub Actions)" subsection
- `.planning/PROJECT.md`, `.planning/REQUIREMENTS.md` — Sparkle named as second policy exception

## Decisions Made

- SU keys via `SparkleInfo.plist` + `INFOPLIST_FILE` merge instead of `INFOPLIST_KEY_*` prefixes (deviation 1 — flagged assumption disproven live)
- `import Sparkle` added to MenuBarView as well as AppDelegate (member-import visibility, deviation 2)
- Halt pattern per 07-01: halted SUMMARY (`status: halted`, `requirements-completed: []`), plan counter NOT advanced, requirements NOT marked — close-out happens when the gate resolves
- Task 3 paste site re-pointed to SparkleInfo.plist (documented in the runbook above and the checkpoint message; the verify's `INFOPLIST_KEY_SUPublicEDKey` grep form is superseded by "non-empty SUPublicEDKey in SparkleInfo.plist AND in the built Info.plist")

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Arbitrary INFOPLIST_KEY_* prefixes are dropped by the generated-Info.plist mechanism — SU keys moved to SparkleInfo.plist via INFOPLIST_FILE merge**
- **Found during:** Task 2 (first build + plist dump)
- **Issue:** the plan's flagged assumption ("INFOPLIST_KEY_ prefix accepts arbitrary keys") is false on this toolchain: with `INFOPLIST_KEY_SUFeedURL` present in `-showBuildSettings`, the freshly built Info.plist carried known keys (NSHumanReadableCopyright, LSUIElement) but NOT SUFeedURL — unknown prefixes are silently dropped, so Sparkle would have no feed URL at runtime
- **Fix:** new repo-root `SparkleInfo.plist` (SUFeedURL + empty SUPublicEDKey) consumed by `INFOPLIST_FILE = SparkleInfo.plist` in both app configs with `GENERATE_INFOPLIST_FILE = YES` (Xcode 13+ merge: file keys + INFOPLIST_KEY_* + generated keys). The dead `INFOPLIST_KEY_SU*` lines were removed (no second source of truth). Sparkle has no code-side API for SUPublicEDKey, so a plist file is the minimal correct mechanism
- **Files modified:** SparkleInfo.plist (new), BoosterSimApp.xcodeproj/project.pbxproj
- **Verification:** rebuilt Debug app: `SUFeedURL` present with the correct URL, `SUPublicEDKey` present-empty, `LSUIElement`/`NSHumanReadableCopyright`/`CFBundleDisplayName` still generated (merge, not replacement); the plan-verify grep component `grep -c INFOPLIST_KEY_SUFeedURL = 2` was replaced by its intent (INFOPLIST_FILE in both configs + PlistBuddy dump)
- **Committed in:** 9689e73

**2. [Rule 1 - Bug] MenuBarView needed its own `import Sparkle`**
- **Found during:** Task 2 (first build)
- **Issue:** `checkForUpdates` call failed to compile — "instance method 'checkForUpdates' is not available due to missing import of defining module 'Sparkle'" (`SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY = YES` on the target); the plan's action listed the import only for AppDelegate
- **Fix:** `import Sparkle` added to MenuBarView.swift
- **Files modified:** BoosterSimApp/Views/MenuBar/MenuBarView.swift
- **Verification:** Debug build green; menu item compiles and calls the controller
- **Committed in:** 9689e73

---

**Total deviations:** 2 auto-fixed (1 blocking-mechanism, 1 bug)
**Impact on plan:** Deviation 1 changes WHERE the SU keys live (file vs build-setting prefix) while strengthening the plan's own acceptance (SUFeedURL is now proven in the built plist, which the original mechanism could never deliver); Task 3's paste site is re-pointed accordingly. Deviation 2 is a one-line compile fix. No scope creep; both were required for the task's `<verify>` to pass.

## Issues Encountered

- A self-inflicted edit briefly replaced `import Combine` with `import Sparkle` in AppDelegate (compile error `AnyCancellable not found`); fixed immediately, never committed
- **Pre-existing (out of scope, not fixed):** building the BoosterSimApp scheme into a FRESH derived-data path emits two `error: Multiple commands produce …/Debug-iphonesimulator/BoosterSimApp.app/…` lines from the app target's "Build iOS Framework & Copy" script phase (its nested iphonesimulator fallback); the outer build still SUCCEEDS. Proven pre-existing by reproducing identically at the pre-Sparkle commit `6130b68` on a fresh derived-data path. The release path never hits it (build-release.sh stage 0 pre-builds the framework); recorded here for the phase gate
- The `6130b68` comparison build silently rewrote Package.resolved to the single pulse pin; restored by re-running `-resolvePackageDependencies` (pins re-verified {pulse, sparkle}) before the Task 2 commit

## Known Stubs

- `SparkleInfo.plist` → `SUPublicEDKey` = **empty string by design** until the Task 3 blocking-human gate supplies the real EdDSA public key (plan transparency prohibition: a placeholder/fake value is prohibited). Recorded in `.planning/WINDOWS.md`. Nothing else is stubbed: the updater controller, menu item, feed URL, and release workflow are real implementations.

## User Setup Required

**One-time, human-only (blocks Task 3):** run Sparkle's `generate_keys` on this machine (release machine — the same one that owns the notary profile), paste the printed public key into `SparkleInfo.plist`'s `SUPublicEDKey`, and optionally export the private key (`generate_keys -x`) to GitHub secret `SPARKLE_PRIVATE_KEY`. Full steps: the Task 3 runbook above and docs/deployment-guide.md § "CI release secrets". Additionally (GitHub side, before the first workflow run): create the six repository secrets listed in the runbook.

## Next Phase Readiness

- 07-06 (phase gate) is blocked until BOTH 07-01's notarization gate and this plan's EdDSA gate resolve; after "key wired" + "notarized", 07-06 runs the first real git-level pin gate (Package.resolved is finally tracked)
- Criterion 2 status: dependency half ✅ (named exception, pinned, tracked, app-target-only); runtime half ✅ (controller, menu item, feed URL in built plist, unit bundle green); release half ✅ structurally (valid YAML, correct job graph, secrets-only credentials — flagged assumption 2 stays open: the first real tag-push run is a follow-up at the phase gate); **key half ⏸ pending the human EdDSA gate**
- After the gate: record the public key fingerprint here, flip this SUMMARY to `complete`, and requirements close at phase level with 07-01/07-06

---
*Phase: 07-polish-distribution*
*Halted at blocking-human EdDSA gate: 2026-09-01*

## Self-Check: PASSED

release.yml, SparkleInfo.plist and this SUMMARY exist on disk; commits 0bfba56 + 9689e73 present on main; Task 1 verify chain re-run verbatim (all checks PASS, table above); Task 2 verify chain re-run with the SUFeedURL component in its intent-equivalent INFOPLIST_FILE form (all checks PASS, table above); pins == {pulse, sparkle}; unit bundle **TEST SUCCEEDED**. Task 3 intentionally not executed — halted at its blocking-human gate. Empty SUPublicEDKey recorded in .planning/WINDOWS.md.
