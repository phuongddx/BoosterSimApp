---
phase: 03-app-actions
verified: 2026-08-31T08:34:41Z
status: passed
score: 31/32 must-haves verified
behavior_unverified: 0
overrides_applied: 0
human_verification:
  - test: "Decide the disposition of the remaining out-of-seam simctl spawn: SimulatorWindowTracker.swift:66-75 directly runs `xcrun simctl list devices --json` via Process() (pre-existing Phase-1 code, live — called at :41 and :179), outside SimCtlService"
    expected: "Maintainer chooses: (a) accept as pre-existing (same class as IN-01) and correct the one overclaiming clause in docs/system-architecture.md § App Actions ('the app's last out-of-seam `Process` spawn is gone') to name the tracker exception, or (b) migrate the tracker's list-devices call onto the seam now"
    why_human: "Phase 3's own code is fully on the seam (prohibition held — zero spawns in any phase file); the falsified clause is an app-wide claim about pre-Phase-3 code no phase plan ever owned. Accept-and-document vs fix-now is a scope decision, not a verification fact"
---

# Phase 3: App Actions Verification Report

**Phase Goal:** Common simulator dev actions (reset, push, deep links, locale, appearance, location, defaults) run from the side panel
**Verified:** 2026-08-31T08:34:41Z
**Status:** human_needed
**Re-verification:** No — initial verification (no prior VERIFICATION.md existed)

## Goal Achievement

**Goal-backward result:** all four ROADMAP success criteria are observably true in the codebase (evidence below), each additionally proven live by the recorded user smokes. One plan-level truth (03-02 truth 6) is partial: its deep-link cutover clause is verified, but its app-wide "every simctl invocation goes through SimCtlService" clause is falsified by a pre-existing Phase-1 spawn outside every phase plan's scope — surfaced for a maintainer decision, not a phase-work failure.

**Judgment basis (per assignment):** criterion 2's permission verb judged against **D-01** (guided manual grant — no fake toggle; platform limit research-proven and user-locked 2026-08-30) and criterion 1's keychain verb against **D-02** (device-wide destructive w/ CA reconcile) per 03-CONTEXT.md. Dark/Dynamic Type/deep links verified as regression-free reuse per CONTEXT "Claude's Discretion", not descoping. The five recorded user approvals (03-01 tracer 7/7 · 2026-08-30; 03-03 9/9 · 2026-08-31; 03-05 phase-gate 6/6 · 2026-08-31; post-review CR-01 live re-check · 2026-08-31; D-01/D-02 flows inside those smokes) are treated as satisfied per the on-record instruction.

### Observable Truths

| # | Truth (source plan) | Status | Evidence |
|---|---------------------|--------|----------|
| 1 | Picker lists DerivedData ∩ installed apps, running-badged, newest default; Reset terminates → uninstalls → reinstalls → fresh (03-01) | ✓ VERIFIED | `AppActionService.refreshApps` (AppActionService.swift:57-90) scans + parses listapps XML + launchctl, `publishCandidates`→`reconcileCandidates` (:671-684) defaults to `candidates.first` (newest); `resetApp` (:88-152) chains terminate→presence→uninstall→install w/ honest A6 degrade (`ResetOutcome.reinstallFailed`, AppActionModels.swift:46); `AppPickerBar.swift:28` badge, `:55-57` alternatives tooltip. Live: 03-01 smoke steps 1-4 approved |
| 2 | Repeated reset idempotent; listapps presence pre-check decides outcome (03-01) | ✓ VERIFIED | Presence guard emits `.absent` without uninstall (:106-110); CR-01 regression tests `resetReachesTheUninstallLegWhenTerminateFailsForANotRunningApp` + `resetReportsAbsentWithoutUninstallWhenTerminateFailsAndAppIsMissing` passed in this verification's own suite run; live: smoke step 4 + gate group 2 (second reset idempotent) approved |
| 3 | D-02 keychain: typed blast-radius confirm; wipe; CA auto re-reconciled, zero manual steps (03-01) | ✓ VERIFIED | Dialog text names EVERY app's keychains + local CA + automatic re-install + "No undo" (AppResetSectionView.swift:63-71); wipe call site exists only inside the destructive confirmation closure; `clearKeychain` (AppActionService.swift:167-225) delegates resetKeychain→reconcileStatus→install-if-CA, both waits 30s-bounded (WR-06 fix), branch-honest logging; unit `clearKeychainDelegatesThenReconcilesExactlyOnce`, `clearKeychainReinstallsTheCAWhenOneExists`, `clearKeychainReportsCertificateFailureHonestly` passed in own run; live: smoke steps 5-6 approved. 03-01 key-decision (reconcileStatus is status-only → install required) implemented as recorded |
| 4 | Seam survives large outputs; serialized; recoverable idle; source-compatible stdin (03-01) | ✓ VERIFIED | SimCtlService.drainAndComplete (:147-186): both pipes drained on concurrent lanes, promise resolves after exit AND both EOFs, 60s-bounded drain, exactly-once `Once` resolution; static serial `invocationQueue` (:50-52); `stdin: Data? = nil` optional param — all pre-existing callers compile (suite green); >64 KB stdin rejected pre-subprocess w/ typed `stdinTooLarge` (:96-98, test passed in own run) |
| 5 | Duplicate bundle IDs → one candidate (newest), alternatives visible; symlinks collapse (03-01) | ✓ VERIFIED | DerivedDataAppScanner: symlink resolution before dedupe, newest-wins w/ `alternativePaths` retained; `duplicateBundleIDsResolveToNewestWithVisibleAlternatives` + `symlinkedTreeResolvesToSameTreeWithoutDuplicates` passed in own run |
| 6 | No booted Simulator → degraded state, no crash, destructive disabled (03-01) | ✓ VERIFIED | `helperBanner` when `activeUDID == nil` (AppResetSectionView.swift:28-30); every verb guards `!udid.isEmpty` with typed captions (AppActionService.swift:315, 364, 469, 496, 561); `LocaleCommandTests/verbsWithoutASimulatorSurfaceTypedCaptions` passed; destructive verbs additionally refuse `booted` (`isDestructiveUDID`, AppActionModels.swift:74-76); live: smoke step 7 approved |
| 7 | Validated payload delivered via stdin seam; repeated sends independent (03-02) | ✓ VERIFIED | `sendPush` (AppActionService.swift:310-337): parse→validate→encode→`[push, udid, bundle ?? "-", "-"]` over stdin; success caption maps simctl's "Notification sent to…" line (:339-342); live: banner + tap-through approved (03-03 smoke step 2, gate group 3) |
| 8 | Over-cap / non-object / missing-aps / empty rejected before subprocess w/ typed errors (03-02) | ✓ VERIFIED | `PushPayload.parse` (PushPayload.swift:75-99): emptyInput/invalidJSON/notObject/missingAPS/invalidShape/unsupportedKeys (WR-04 reject-not-strip); `validate` gates `> 4096` on encoded bytes (:101-104); view disables send on empty (`isEditorEmpty`/`canSend`); PushPayloadTests 15 cases green (03-05 run + suite); live: >4096 rejected inline, no send (smoke step 3) |
| 9 | Deep links regression-free after seam migration (03-02) | ✓ VERIFIED | DeepLinkService.swift: no `Process`/`Task.detached` (grep-verified across tree); Combine chain + 30s timeout (:58-75, WR-05); validation/argv pure statics (:122-130); history/favorites persistence intact w/ injectable defaults; 12 DeepLinkServiceTests green; live: preset deep link opened (smoke step 4, gate group 3) |
| 10 | 12 TCC services grant/revoke per active app; reset-all behind confirm; notifications-excluded captions (03-02) | ✓ VERIFIED | PrivacyPermission.swift: exactly 12 verbatim cases, no notifications case; `setPrivacy` appends optional bundle arg (AppActionService.swift:240-253); `resetAllPrivacy` destructive-gated + UDID-refused (:256-272); "managed by iOS" captions in PrivacySectionView.swift:50,128; PrivacyPermissionTests green (D-01 contract locked) |
| 11 | D-01 guided grant honest: caption + Settings link + steps + probe; never a fake toggle (03-02) | ✓ VERIFIED | PushNotificationSectionView.swift:199 caption "Notification permission is managed by iOS — it cannot be set from here.", `:213` Open Settings button → `launch com.apple.Preferences` (AppActionService.swift:283); no permission-toggling control anywhere in the section (full read); live: guided grant flow approved (03-03 smoke step 1, gate group 3) |
| 12 | Every simctl invocation through SimCtlService; deep-link spawn deleted; exemption list = CaptureService (03-02) | ? UNCERTAIN | **Partial.** Cutover clause VERIFIED: DeepLinkService spawn deleted, zero subprocess spawns in any Phase-3 file, CONVENTIONS.md:8 async-exemption is CaptureService alone (edited in d31d6a3). App-wide clause FALSIFIED: `SimulatorWindowTracker.swift:66-75` still directly runs `xcrun simctl list devices --json` via `Process()` — live code (called :41, :179), pre-existing Phase-1 (last touched 53194b1, 2026-06-16), documented in CONVENTIONS.md:11, outside every Phase-3 plan's files_modified. docs/system-architecture.md § App Actions repeats the overclaim ("the app's last out-of-seam `Process` spawn is gone"). See Human Verification |
| 13 | Locale preset writes global-domain keys + relaunches in one chain, captioned; city preset = GPS + tz sync (03-03) | ✓ VERIFIED | `localeWriteChain` (AppActionService.swift:758-770): AppleLanguages `-array` + AppleLocale `-string` (+ tz) then `launch --terminate-running-process` LAST; `applyLocale` runs it via `runChain` (WR-07 single source of truth); `cityPresetChain` (:917-923) = location set + timezoneArgs + optional relaunch; relaunch caption adjacent to every apply control (LocaleSectionView.swift:104, 178, 185-189); LocaleCommandTests 21 green; live: A1 relaunch-localization + Tokyo preset tz approved (smoke steps 5, gate group 4) |
| 14 | Coordinates → location set; Clear paired and visible while active (03-03) | ✓ VERIFIED | `setLocation`/`clearLocation` (AppActionService.swift:465-520); `hasSimulatedLocation` drives prominent Clear w/ a11y label (LocationSectionView.swift:111-129) + "Simulation active" caption (:67); live: Maps/Weather moved, Clear visible throughout (smoke step 6, A2 closed) |
| 15 | Bidirectional pbsync, direction captions, manual-only, text-clipboard caption (03-03) | ✓ VERIFIED | `pbsyncCommand` exact two forms (AppActionService.swift:926-930); ClipboardSectionView: manual buttons only, zero Timer/onReceive (grep-verified); direction-status captions (:566-578); clipboard content never read — no NSPasteboard anywhere on the sync path (grep: all NSPasteboard use is pre-existing Capture/Design/Network export features); live: round-trip both directions approved (smoke step 7) |
| 16 | Dark/light + Dynamic Type served by existing EnvironmentOverridesView, reused regression-free (03-03) | ✓ VERIFIED | ActionsTabView section table renders `EnvironmentOverridesView(udid:)` for `.environment` — first section in catalog order (AppAction.swift:60-63, AppActionSection case order); EnvironmentOverridesView.swift untouched this phase (git diff); live: both applied instantly via existing section (smoke step 8, gate group 4) |
| 17 | Empty/invalid inputs fail fast typed, never crash (03-03) | ✓ VERIFIED | `coordinatePair` (AppActionService.swift:857-868): empty/non-numeric/out-of-range typed CoordinateError cases, NO argv on invalid; `setLocationWithInvalidInputFailsFastWithoutSimulating` passed in own run; empty payload/selection disables buttons; live: empty lat/lon → inline typed error (smoke step 9) |
| 18 | Locale/tz re-apply idempotent; location re-apply replaces (03-03) | ✓ VERIFIED | Chain argv identical by construction (pure builders over pinned values); idempotency pinned by chain tests (now pinning production builders per WR-07); location `set` replaces by simctl semantics w/ single active flag; live: re-apply stable (smoke step 9, gate group 2) |
| 19 | Defaults editor: typed view/edit/add/delete, reload-on-write, idempotent, empty plist = empty list (03-04) | ✓ VERIFIED | UserDefaultsEditorService: plist FILE read via `get_app_container data` (:171-175), missing file → `[]` not error (:196-199); typed write/delete argv + reload (:125-165); WR-02 regression tests `loadDuringLoadingSupersedesTheInFlightLoadWithTheNewestTarget` + `loadClearsThePreviousDomainRowsAtStart` passed in own run; view: type capsule rows, inline edit, add-row w/ type Picker (:251-253), delete; live: gate group 5 approved (edit landed next launch, add/delete, re-edit identical) |
| 20 | Quick search filters every section via pure catalog; deterministic; honest no-match (03-04) | ✓ VERIFIED | `AppActionCatalog.filter` sole matching point (AppAction.swift:110+); ActionsTabView: zero query contains-chains in body — `visibleSections` = filter result or `allCases` (:29-43), no-match caption (:113-117), matched-actions disclosure; AppActionCatalogTests 9 green; live: search + clear restored fixed-order tab (gate groups 1, 5) |
| 21 | Key/domain allowlist-validated before argv; typed error, no subprocess (03-04) | ✓ VERIFIED | `writeArgs`/`deleteArgs` guard `isValidName` (`[A-Za-z0-9._-]`) → typed DefaultsEditorError, NO argv (UserDefaultsEditorService.swift:178-192); unit-pinned (allowlist rejection w/ zero argv) |
| 22 | Editor targets picker's active app; cfprefsd + relaunch captions (03-04) | ✓ VERIFIED | View binds `activeBundleID` from AppActionService via udidProvider; captions at UserDefaultsEditorView.swift:319-327 ("Writes land via cfprefsd…", "Keys read at launch time … need an app relaunch") |
| 23 | UserDefaults values never logged (03-04) | ✓ VERIFIED | All 36 `AppLogger.actions` sites enumerated: verb/outcome/byte-size/count/domain/key only — no value, payload body, or URL interpolation anywhere (AppActionService.swift + UserDefaultsEditorService.swift sweep) |
| 24 | Full suite green in one run, all 8 Phase-3 suites + pre-existing (03-05) | ✓ VERIFIED | Own independent run this verification: `xcodebuild test -only-testing:BoosterSimAppTests -skip-testing:BoosterSimAppUITests` → **exit 0** (xcodebuild fails on any test failure), tail shows Phase-3 suites passing incl. all review-fix regressions; recorded 189/0 at HEAD (code commits after that run are docs-only: 6d124b8..88b9996). All 8 suites + ScriptedSimCtl + SimCtlServiceTests exist on disk |
| 25 | Idempotency probe truth (03-05) | ✓ VERIFIED | Unit contracts (repeat-write argv identity, reset presence path, push N-sends) + gate-level observation recorded approved (group 2 repeated reset/defaults/push stability) |
| 26 | Concurrency probe truth: serialized seam, recoverable idle, atomic writes (03-05) | ✓ VERIFIED | Static serial queue (SimCtlService.swift:50-52); every verb 30s-timeouted, drain 60s-bounded, exactly-once promise — machine cannot wedge (code + SimCtlServiceTests stdin-bound case passed); single `spawn defaults` verbs are cfprefsd-atomic by OS contract; gate observation recorded approved |
| 27 | Empty probe truth (03-05) | ✓ VERIFIED | Typed empty-input paths across models (emptyInput/noDevice/latitudeEmpty/cannot-send-disabled); `verbsWithoutASimulatorSurfaceTypedCaptions` passed in own run |
| 28 | Ordering probe truth (03-05) | ✓ VERIFIED | Catalog fixed order + stable filter (AppActionCatalogTests); scanner deterministic mtime sort + key sort in `parseEntries` (:196-199); unit green |
| 29 | Adjacency probe truth (03-05) | ✓ VERIFIED | Single newest candidate w/ visible alternatives (scanner tests passed in own run); sections independent via catalog table; symlinked trees collapse to one candidate |
| 30 | Phase-gate six-group smoke recorded per-group (03-05) | ✓ VERIFIED | 03-05-SUMMARY Checkpoint Resolution: DETECTION / RESET / PUSH+DEEP LINK / ENVIRONMENT / DEFAULTS / DOCS all ✓, user-approved 2026-08-31 — treated as satisfied per on-record instruction |
| 31 | Docs honesty: split, reconcile, seam hardening + why, latency table, both platform limits verbatim-intent (03-05) | ✓ VERIFIED | docs/system-architecture.md § App Actions (lines 498+): all required content present; D-01 caption quoted in docs is byte-identical to PushNotificationSectionView.swift:199; D-02 dialog text matches AppResetSectionView.swift:66-70; known-gap (IN-01) honestly documented. 8/8 core symbols in BOTH docs (discriminating check exit 0). Caveat: one clause overclaims — folded into truth #12 finding |
| 32 | Package.resolved byte-identical to phase start (03-05) | ✓ VERIFIED | sha256 `70386616a707…` matches the recorded Phase 5/2 pin; sole pin Pulse 5.2.2 (the documented exception); file untracked as documented (git-level diff vacuous — infra note + track-the-file recommendation on record) |

**Score:** 31/32 truths verified (0 present-but-behavior-unverified; 1 UNCERTAIN → human decision, below)

### Required Artifacts

All 29 declared artifacts (5 plans) exist, are substantive, and are wired. Highlights:

| Artifact | Status | Details |
|----------|--------|---------|
| `Services/SimCtlService.swift` | ✓ VERIFIED | Hardened seam: concurrent drains, bounded stdin/drain, serial queue, `SimCtlRunning` protocol — 402 LOC, no stubs |
| `Services/DerivedDataAppScanner.swift` | ✓ VERIFIED | Pure FS scanner, injectable root, newest-wins w/ alternatives — wired into `refreshApps` |
| `Services/AppActionService.swift` | ✓ VERIFIED | 957 LOC facade, every verb + pure builder present — wired to all 9 section views |
| `Services/UserDefaultsEditorService.swift` | ✓ VERIFIED | 237 LOC, plist-file read + validated writes — wired to editor view |
| `Services/DeepLinkService.swift` ✓ (modified) | ✓ VERIFIED | Seam-migrated, timeout-armed, zero out-of-seam spawns in file |
| `Models/{AppActionModels,PushPayload,PrivacyPermission,DefaultsEntry,AppAction}.swift` | ✓ VERIFIED | All substantive; types consumed by services/views/tests |
| `Views/SideWindow/actions/` (9 views) + `ActionsTabView` | ✓ VERIFIED | All mounted via catalog section table; no placeholder content; degraded states real |
| 8 Wave-0 test suites + `ScriptedSimCtl.swift` + `SimCtlServiceTests.swift` | ✓ VERIFIED | All exist; suite run green this verification |
| `docs/system-architecture.md` § App Actions, `docs/codebase-summary.md` | ✓ VERIFIED | Truth-passed; symbol cross-check 8/8 both docs |

**Artifacts:** 29/29 verified (0 stub, 0 missing, 0 orphaned)

### Key Link Verification

| From | To | Via | Status |
|------|----|----|--------|
| AppPickerBar selection | AppActionService.activeBundleID → all sections | @Published + @EnvironmentObject | ✓ WIRED |
| Reset/Uninstall/Keychain buttons | simctl terminate/listapps/uninstall/install · CertificateService verbs | confirmationDialog → facade → seam | ✓ WIRED |
| Push editor Send | `[push, udid, bundle, "-"]` + stdin | PushPayload.parse/validate → sendPush → seam | ✓ WIRED |
| Open Settings | `launch com.apple.Preferences` | PushNotificationSectionView:213 → openDeviceSettings:283 | ✓ WIRED |
| Locale/city presets | spawn-defaults writes + relaunch | localeWriteChain/cityPresetChain → runChain → seam | ✓ WIRED |
| Editor row edit/add/delete | spawn-defaults typed verbs + reload | UserDefaultsEditorService → seam → loadDomain | ✓ WIRED |
| ActionSearchBar query | Section visibility | AppActionCatalog.filter → ActionsTabView.visibleSections | ✓ WIRED |
| AppDelegate construction | SideWindowController → environmentObject → views | lazy services (AppDelegate.swift:25-27, 51-55) + injection (SideWindowController.swift:227+) | ✓ WIRED |

**Links:** 8/8 WIRED

### Data-Flow Trace (Level 4)

| Surface | Source | Status |
|---------|--------|--------|
| Picker candidates | DerivedData FS scan ∩ listapps XML ∩ launchctl parse | ✓ FLOWING (live-verified, gate group 1) |
| Defaults entries | `<data-container>/Library/Preferences/<bundle>.plist` via `get_app_container` | ✓ FLOWING (live-verified, gate group 5) |
| Push result caption | simctl push stdout ("Notification sent to …") | ✓ FLOWING (live banner + tap-through) |
| Locale current-state fields | three `defaults read` global-domain parses | ✓ FLOWING (live reload on apply) |
| Search results | pure AppActionCatalog.filter | ✓ FLOWING (deterministic, live-verified) |

No static/hollow data paths found.

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Full unit bundle (all Phase-3 + pre-existing suites) | `xcodebuild test -project BoosterSimApp.xcodeproj -scheme BoosterSimApp -destination 'platform=macOS' -only-testing:BoosterSimAppTests -skip-testing:BoosterSimAppUITests` | exit 0; visible passes incl. CR-01 (`resetReachesTheUninstallLeg…`, `resetReportsAbsentWithoutUninstall…`), WR-02 (`loadDuringLoadingSupersedes…`, `loadClearsThePreviousDomainRowsAtStart`), WR-03 (`runRejectsStdinOverThePipeBound…`), keychain delegate-order set, scanner dedupe/symlink set | ✓ PASS |
| Dependency pin | `shasum -a 256 Package.resolved` | `70386616a707…` = recorded Phase 5/2 pin; sole package Pulse 5.2.2 | ✓ PASS |
| Docs symbol cross-check | discriminating grep, 8 core types × both docs | DOCS-SYMBOLS OK (exit 0) | ✓ PASS |
| D-01 caption presence | grep "managed by iOS" | 3 sites (Push:199, Privacy:50,128) | ✓ PASS |
| Prohibition sweep: subprocess spawns | grep `Process()`/`NSTask`/`Task.detached` across BoosterSimApp/ | Only seam + 2 pre-existing non-phase sites (see truth #12) | ✓ PASS (phase scope) |
| Prohibition sweep: logging | all 36 `AppLogger.actions` sites enumerated | verb/outcome/size/count/domain/key only | ✓ PASS |

### Probe Execution

Step 7c: SKIPPED — no `scripts/*/tests/probe-*.sh` probes are declared by any Phase-3 plan; the "probe truths" are plan must_haves (verified above as truths #25-29), not shell probes.

### Requirements Coverage

**REQ-roadmap-phase3-app-actions** — all 13 actions verified in code (+ live where device-state-bound):

| Action | Evidence | Status |
|--------|----------|--------|
| Reset app (terminate + clear container) | resetApp chain + live smoke | ✓ SATISFIED |
| Clear Keychain items | D-02 clearKeychain + live smoke | ✓ SATISFIED (per D-02: device-wide w/ CA reconcile) |
| Send push notification | sendPush stdin seam + live banner | ✓ SATISFIED |
| Grant/revoke push permission | D-01 guided grant (caption + Settings link + probe) — no toggle exists, by locked decision | ✓ SATISFIED (per D-01; platform limit documented in UI + docs) |
| Trigger deep link | seam-migrated DeepLinkService + live | ✓ SATISFIED |
| Bidirectional clipboard sync | pbsync both directions + live round-trip | ✓ SATISFIED |
| Locale switcher | applyLocale + relaunch chain + live | ✓ SATISFIED |
| Dark/light toggle | EnvironmentOverridesView reuse + live | ✓ SATISFIED |
| Dynamic Type control | EnvironmentOverridesView reuse + live | ✓ SATISFIED |
| Location simulation + timezone sync | setLocation/cityPresetChain + live Maps/tz | ✓ SATISFIED |
| UserDefaults editor | UserDefaultsEditorService/View + live | ✓ SATISFIED |
| Quick action search | AppActionCatalog + ActionSearchBar + live | ✓ SATISFIED |
| Bundle ID detection from DerivedData | DerivedDataAppScanner + live picker | ✓ SATISFIED |

**REQ-fr-13** (four icon-only tabs) — ✓ SATISFIED: the Actions tab is now the real 9-section catalog surface behind the existing Phase-1 tab shell; no placeholder remains (stale placeholder row already corrected in docs).

Orphaned requirements: none — REQUIREMENTS.md maps exactly the two IDs above to Phase 3, both declared in plans and closed on 03-05 per the shared-ID gate.

### Prohibition Verification (all 14 across 5 plans)

| Prohibition | Status | Evidence |
|-------------|--------|----------|
| No unconfirmed/ambiguous-UDID keychain wipe (D-02, 03-01) | ✓ HELD | Single wipe call site inside typed destructive confirm; `isDestructiveUDID` refuses empty/`booted` (unit-tested) |
| No simctl spawns outside seam in new Phase-3 code (03-01) | ✓ HELD | Zero `Process()` in any phase file |
| No logging of bundle IDs/UDIDs/paths (03-01) | ✓ HELD | 36 log sites: verbs/counts/outcomes only |
| No push-permission toggle (D-01, 03-02) | ✓ HELD | Guided-grant block only; grep + full read confirm no state-toggling control |
| No payload/URL logging (03-02) | ✓ HELD | push logs carry size only; seam argv echo is the pre-existing IN-01 gap (documented, tracked) |
| Seam cutover closes out-of-seam spawns (03-02) | ✓ HELD (phase scope) | Deep-link spawn deleted; app-wide claim falsified by pre-existing tracker spawn → truth #12 |
| No clipboard read/log/retain; no auto-sync timer (03-03) | ✓ HELD | pbsync delegation only; no NSPasteboard on sync path; no Timer/onReceive |
| No active simulation without visible Stop (03-03) | ✓ HELD | State-driven always-visible Clear (hasSimulatedLocation) |
| No locale/tz write presented as instant (03-03) | ✓ HELD | Relaunch caption adjacent to every apply control; explicit relaunch hop in chain |
| No logging of UserDefaults values (03-04) | ✓ HELD | domain/key/count only (T-03-10) |
| No defaults writes outside selected domain (03-04) | ✓ HELD | Editor verbs target picker bundle; scoped documented keys only (AppleLanguages/Locale/TimeZone, ShowSingleTouches pre-existing) |
| No editor on `defaults export` verb (03-04) | ✓ HELD | `"export"` token absent from entire tree (grep exit 1); plist FILE read path |
| No new packages / SPM pin changes (03-05) | ✓ HELD | sha256 pin byte-identical; zero installs |
| No documenting capabilities the platform lacks (03-05) | ✓ HELD | Both limits restated exactly as UI presents; one unrelated overclaim clause surfaced (truth #12) |

### Anti-Patterns Found

| File | Pattern | Severity | Impact |
|------|---------|----------|--------|
| Services/AppActionService.swift (957 LOC), Views/SideWindow/actions/UserDefaultsEditorView.swift (505 LOC) | House <200 LOC budget exceeded | ℹ️ Info | IN-02 — pre-flagged in summaries, recorded at review, gate decision on record; split needs the facade-state refactor |
| Services/SimCtlService.swift:92 | Pre-existing argv echo (URLs + defaults values) | ℹ️ Info | IN-01 — documented in docs § App Actions "Known logging gap" + deferred-items.md #2; redaction deferred to seam-hygiene pass (IN-06 rides along) |
| AppAction.swift:79 | "camera" keyword surfaces Privacy section w/o camera row | ℹ️ Info | IN-03 — open advisory w/ rationale (product decision) |
| UserDefaultsEditorView json add-kind | "json" label writes opaque data blob | ℹ️ Info | IN-04 — open advisory (capsule design documented) |
| AppActionService.swift:600 (fail) | stderr passthrough logged `.public` | ℹ️ Info | IN-06 — rides the IN-01 redaction sweep |
| AppActionService.swift:846+ / editor plist path | coordinate spelling verbatim / read-path allowlist asymmetry | ℹ️ Info | IN-05 — open advisory (hardening nice-to-have) |

Zero debt markers (TBD/FIXME/XXX/TODO/HACK/PLACEHOLDER) across all 20 phase source files — clean. No stub returns; all empty states are honest captions backed by real data paths.

### Human Verification Required

**On record and satisfied (per assignment instruction — not re-opened):**

1. 03-01 tracer live smoke — 7/7 steps, user-approved 2026-08-30 (reset, uninstall, D-02 dialog + CA reconcile, degraded state)
2. 03-03 locale/location/clipboard live smoke — 9/9 steps, user-approved 2026-08-31 (D-01 guided grant, push banner, payload gate, privacy, locale A1, location A2, clipboard round-trip, reuse regression, idempotency/empty)
3. 03-05 phase-gate six-group smoke — 6/6 groups, user-approved 2026-08-31 (detection, reset+keychain, push+deep link, environment, defaults+search, docs)
4. Post-review CR-01 live re-check — user-verified 2026-08-31 (reset on not-running app completes via presence/reinstall with honest caption)
5. D-01 grant flow + D-02 wipe — verified inside smokes 1-3 above

**Pending decision (1 item):**

### Remaining out-of-seam simctl spawn — SimulatorWindowTracker (truth #12 disposition)

**Test:** Decide: (a) accept `SimulatorWindowTracker.swift:66-75` (direct `xcrun simctl list devices --json` via `Process()`, pre-existing Phase-1 code, live at :41/:179) as pre-existing — same disposition class as IN-01 — and correct the one overclaiming clause in docs/system-architecture.md § App Actions ("the app's last out-of-seam `Process` spawn is gone") to name the tracker exception; or (b) migrate the tracker's list-devices call onto the seam now.
**Expected:** Either a one-line docs correction (option a) or a small seam migration (option b); 03-02 SUMMARY's "codebase contains zero direct subprocess spawns outside the seam" claim is falsified either way and should not survive uncorrected.
**Why human:** Phase 3's own code is fully compliant — the prohibition (must-NOT on phase code) held. The falsified clause concerns pre-Phase-3 code no plan owned; accept-and-document vs fix-now is a scope decision. (Note: `CertificateStore.swift:67` also spawns `/usr/bin/openssl` directly — not a simctl verb, by design outside the seam's charter, noted for completeness.)

### Gaps Summary

No goal-level gaps: all four ROADMAP success criteria are verified in code and were proven live by the recorded smokes; all 29 artifacts substantive and wired; all 8 key links wired; all data paths flowing; all 14 prohibitions held for phase code; requirements coverage complete. The single UNCERTAIN truth (#12) is an app-wide claim in 03-02's truth text, SUMMARY, commit message, and docs that is falsified by a pre-existing Phase-1 spawn the phase never touched — surfaced for a maintainer decision rather than scored as phase-work failure, because the phase's own obligation (the cutover) is fully implemented and verified.

Deferred (informational, not gaps): deferred-items.md #1 (Phase-2 tree backfill in codebase-summary — Phase-2 docs scope) and #2 (seam argv-echo redaction — IN-01/IN-06 sweep); IN-01..IN-06 open advisories carry recorded rationale at 03-REVIEW.md Fix Resolution.

---

_Verified: 2026-08-31T08:34:41Z_
_Verifier: Claude (gsd-verifier)_

## Maintainer Disposition (2026-08-31)

Item surfaced as human_needed — 03-02 truth #12's app-wide zero-spawn clause vs the
pre-existing Phase-1 spawn in SimulatorWindowTracker.swift:66-75 (outside all phase
plans' scope; phase-owned code fully on the seam). Maintainer decision: ACCEPT as
pre-existing (IN-01 class) + docs correction. Applied: docs/system-architecture.md
and 03-02 SUMMARY now scope the claim to phase-owned code and record the tracker
migration as a follow-up. Truth #12 scored VERIFIED under the corrected wording;
recorded approvals stand. Status → passed.
