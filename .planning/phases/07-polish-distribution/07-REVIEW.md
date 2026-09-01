---
phase: 07-polish-distribution
reviewed: 2026-09-01T06:07:20Z
depth: deep
files_reviewed: 27
files_reviewed_list:
  - .github/workflows/release.yml
  - BoosterSimApp.xcodeproj/project.pbxproj
  - BoosterSimApp.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved
  - BoosterSimApp/App/AppDelegate.swift
  - BoosterSimApp/Assets.xcassets/AppIcon.appiconset/Contents.json (+ 10 generated PNGs)
  - BoosterSimApp/Models/AppAction.swift
  - BoosterSimApp/PrivacyInfo.xcprivacy
  - BoosterSimApp/Services/WindowEnumerator.swift
  - BoosterSimApp/Views/MenuBar/MenuBarView.swift
  - BoosterSimApp/Views/Onboarding/OnboardingContainerView.swift
  - BoosterSimApp/Views/Onboarding/OnboardingStepView.swift
  - BoosterSimApp/Views/SideWindow/CameraView.swift
  - BoosterSimApp/Views/SideWindow/SideWindowView.swift
  - BoosterSimApp/Views/SideWindow/tabs/ActionsTabView.swift
  - BoosterSimAppTests/AppActionCatalogTests.swift
  - BoosterSimAppTests/AppSettingsTests.swift
  - BoosterSimAppTests/PositionCalculatorTests.swift
  - BoosterSimAppTests/WindowEnumeratorTests.swift
  - BoosterSimAppUITests/OnboardingFlowUITests.swift
  - ExportOptions.plist
  - SparkleInfo.plist
  - scripts/build-release.sh
  - scripts/generate-placeholder-icon.swift
  - docs/deployment-guide.md
  - docs/system-architecture.md
  - docs/codebase-summary.md
  - README.md
findings:
  critical: 2
  warning: 4
  info: 6
  total: 12
status: issues_found
fix_status: critical_resolved_warnings_3_of_4_resolved
---

# Phase 07: Code Review Report — Polish & Distribution

**Reviewed:** 2026-09-01T06:07:20Z
**Depth:** deep (cross-file traces + empirical probes of the release tooling against the real Sparkle 2.9.6 SPM checkout)
**Files Reviewed:** 27 (full git range 10ed814..196f303, plans 07-01 → 07-06)
**Status:** issues_found

## Summary

Phase 7's app-side work is solid: the pid/udid threading is type-safe end to end (`pid_t?` from
`SimulatorWindow.pid` through `SideWindowView` → `ActionsTabView` → `CameraView`/`AXTreeView`), the
13-section/18-action catalog grew with a genuinely exhaustive order-pinning test, the four new test
suites pin real contracts with hand-computed expectations and boundary-exact clamps, the
`-uitest-reset-onboarding` seam is correctly ordered before the onboarding read and is launch-argument
gated only, the icon generator derives every path from `#filePath` (no hardcoded machine paths) and the
10 PNGs match `Contents.json` exactly (verified via `sips`), and the pbxproj team switch + Sparkle SPM
attachment are consistent across all 8 `DEVELOPMENT_TEAM` sites and app-target-only.

The release tooling is where the phase's blocked-from-execution status bit: **both halves of the
appcast step in `release.yml` are broken and were only ever grep-validated** — the `find` looks for the
binary in `SourcePackages/checkouts`, but Sparkle 2.9.6 ships it as a *binary SPM artifact* under
`SourcePackages/artifacts/`, and the invocation passes an `.app` bundle where the tool requires a
directory of update archives (empirically reproduced: exit 1, "No usable archives found"). Every tag
push would die at that step. Both are fixed and the corrected invocation was proven end-to-end against
the real binary with a scratch DMG + throwaway EdDSA key. Two further warnings were fixed (Sparkle never
starting automatically due to its lazy-only instantiation; the deployment guide directing the EdDSA
human gate to the wrong paste site), and two are left as findings (privacy-manifest reason codes that
drifted from Apple's current definitions; a stale-probe race in `CameraService`).

The five phase-specific security focuses were each verified:

1. **release.yml credential exposure** — clean. All secrets flow via `env:` into commands; nothing
   echoes values (`ls -la build/appcast` prints names only; build-release.sh prints the profile *name*
   only). GitHub auto-masks registered secrets in logs. The `base64 --decode -o` form was verified
   against macOS 26's system (FreeBSD) base64 — both flags work, so the decode steps are sound on the
   `macos-26` runner. (My first local test "failed" only because a Homebrew base64 0.8.0 shadows the
   system one in my shell PATH — runner PATH resolves `/usr/bin/base64`.)
2. **build-release.sh credential literals** — clean. Contains only the notary profile *name*
   (`booster-notary`), the public team ID, and `<Apple ID>`/`<app-specific password>` placeholders in
   the human-run instructions. Grep sweep for credential-shaped literals across release.yml, scripts/,
   both plists, and deployment-guide.md: zero matches.
3. **`-uitest-reset-onboarding` seam** — safe. Single check of `ProcessInfo.processInfo.arguments` at
   `applicationDidFinishLaunching` (AppDelegate.swift:108-111), placed *before* the
   `if !completedOnboarding` read (:114). Not reachable via network, deep link, or persisted state; a
   Release build carrying it only lets a local process launcher reset that user's own onboarding flag —
   equivalent to any fresh launch.
4. **PrivacyInfo.xcprivacy accuracy** — one category wrong, see WR-03. `CA92.1` for UserDefaults
   verified correct against Apple's current wording ("read and write information that is only
   accessible to the app itself"). The FileTimestamp pair `C617.1`+`3B52.1` no longer matches Apple's
   current definitions (3B52.1 is now third-party-SDK-only; the app-container reason is DDA9.1).
5. **CameraView probeSupport wiring** — no retain cycle (the AX work captures only `pid` + path
   values; the main-queue hop uses `[weak self]`), and the onAppear/onChange split covers every mount
   and pid-change path. But the probe itself has no ordering guard → WR-04.

Cross-file traces performed: release.yml ↔ build-release.sh ↔ ExportOptions.plist ↔ pbxproj (signing
team, `INFOPLIST_FILE` merge, hardened runtime); SparkleInfo.plist ↔ deployment-guide ↔ 07-02 summary
(EdDSA paste site); `AppActionCatalog` ↔ `ActionsTabView` switch ↔ `AppActionSection.allCases`; the
onboarding seam ↔ `@AppStorage` sites ↔ UI-test launch arguments; PrivacyInfo ↔ all required-reason API
use sites (grep sweep found FileTimestamp ×3, UserDefaults, and **no** disk-space/boot-time/keyboard
usage — those categories are correctly absent from the manifest).

Scope note: `.planning/` artifacts (PROJECT.md, REQUIREMENTS.md) follow the established review-file
filter and were read for context but not reviewed as source. `BoosterSimApp/Windows/PositionCalculator.swift`
and `AppSettings.swift` sources are unchanged in this range — only their tests shipped (correct: the
tests pin existing contracts).

## Fixes Applied This Review

Committed separately from this document (per review protocol):

| Finding | Fix | Verification |
|---|---|---|
| CR-01, CR-02 | `release.yml`: appcast step now finds the binary under `SourcePackages` (artifact location), feeds it a directory containing the DMG, drops the invalid `-o <dir>`, `trap`-removes the EdDSA key file, and uploads `build/appcast/BoosterSim.dmg` so the enclosure name matches the released asset | Corrected invocation run locally against the real `generate_appcast` 2.9.6 binary with a scratch signed DMG + throwaway EdDSA key: exit 0, `appcast.xml` written beside the DMG with relative enclosure `url="Test-1.0.dmg"`. (EdDSA signing leg additionally requires the app's embedded Sparkle 2.9.6 — the real app sets `requiresSignedAppcast`; the synthetic test app doesn't embed Sparkle, so it exercised the unsigned path.) |
| WR-01 | `AppDelegate.swift`: `_ = updaterController` at launch so Sparkle's scheduled automatic checks actually run | `xcodebuild -scheme BoosterSimApp` **BUILD SUCCEEDED** |
| WR-02 | `docs/deployment-guide.md`: EdDSA paste site corrected to `SUPublicEDKey` in `SparkleInfo.plist` (with the why: unknown `INFOPLIST_KEY_*` prefixes are dropped by the generated-plist merge) | Matches SparkleInfo.plist's own comment and the 07-02 summary's empirically-proven merge behavior |
| WR-03 | `BoosterSimApp/PrivacyInfo.xcprivacy`: FileTimestamp reasons corrected to `DDA9.1` alone (dropped inaccurate `C617.1`/`3B52.1`); DerivedData mtime reads left honestly uncovered per an inline XML comment rather than padded with an inapplicable reason; `docs/codebase-summary.md` line updated to match | `plutil -lint` OK, structural assert (exactly `{CA92.1}` + `{DDA9.1}`) passes, Debug build green — fixed post-review by the orchestrating agent, applied outside the reviewer's own fix pass |

## Critical Issues

### CR-01: release.yml can never find generate_appcast — the binary ships as an SPM *artifact*, not in checkouts

**File:** `.github/workflows/release.yml:104` (shipped revision)

**Issue:** The step resolves the tool with
`find SourcePackages/checkouts -path '*Sparkle*/bin/generate_appcast' -type f`. Against the pinned
Sparkle 2.9.6 checkout (verified on this machine's `SourcePackages` for the same pin):
`checkouts/Sparkle/bin/` contains **only** `old_dsa_scripts/`; `checkouts/Sparkle/generate_appcast`
is a *directory of Swift sources* (Appcast.swift, main.swift, …), not an executable. The actual
executable lives in the binary distribution: `SourcePackages/artifacts/sparkle/Sparkle/bin/generate_appcast`.
The `find` therefore returns empty and the step exits 1 ("generate_appcast not found in the Sparkle SPM
checkout") on **every** tag push. The 07-02 summary's verification for this step was
`yaml.safe_load` + greps — structural only, so this never surfaced.

**Fix (applied):** Search all of `SourcePackages` (the artifacts tree lives under it) for
`'*Sparkle*/bin/generate_appcast' -type f`, with the error message naming the expected artifact path.

### CR-02: generate_appcast invoked with an .app bundle and a directory as `-o` — "No usable archives found", and the appcast filename could never match

**File:** `.github/workflows/release.yml:104-116` (shipped revision)

**Issue:** Two independent defects in the invocation, both verified against the real binary's source
and behavior:

1. `generate_appcast` takes "**the path to the directory containing the update archives and delta
   files**" (its own `--help`; `unarchiveUpdates` scans the directory's children for
   zip/tar/gz/dmg/… extensions and skips directories). Passing `build/export/BoosterSimApp.app` makes
   it scan `Contents/`, find no archives, and throw `No usable archives found in
   .../BoosterSimApp.app` — **empirically reproduced**: exit 1, exactly that error, against the real
   2.9.6 binary with a scratch DMG-backed fixture.
2. `-o` is "Path to **filename** for the generated appcast" (source: `outputPathURL` is used directly
   as `appcastDestPath`), but the step passes `build/appcast` — a directory it `mkdir -p`'d two lines
   earlier — and the release step then expects `build/appcast/appcast.xml`, which neither invocation
   form could ever produce.

Net effect: even after fixing CR-01, the workflow fails at this step; the release never publishes.

**Fix (applied):** Copy `build/BoosterSim.dmg` into `build/appcast/`, run
`"$GENERATE_APPCAST" --ed-key-file "$KEY_FILE" build/appcast` (the tool writes `appcast.xml` beside
the archive, enclosure = the archive's file name), and upload `build/appcast/BoosterSim.dmg` +
`build/appcast/appcast.xml` from the release step so the enclosure resolves against the stable
`releases/latest/download/<asset>` feed URL. Verified end-to-end locally: exit 0, appcast written,
`<enclosure url="Test-1.0.dmg" …>`.

## Warnings

### WR-01: Sparkle updater never starts automatically — it is instantiated only on the first menu click

**File:** `BoosterSimApp/App/AppDelegate.swift:41` (lazy property); sole reader
`BoosterSimApp/Views/MenuBar/MenuBarView.swift:45`

**Issue:** `updaterController` is a `lazy var`, and its only reference is inside the
"Check for Updates…" button action. A `SPUStandardUpdaterController` schedules automatic update
checks when it is created (`startingUpdater: true`) — but since nothing touches the property until
the user clicks the menu item, every launch runs with **no updater instance at all**: no scheduled
checks, ever. The shipped wiring is manual-check-only, contradicting both the phase claim ("updater
wiring", 07-02) and README's "the app watches the appcast feed".

**Fix (applied):** Touch the property once in `applicationDidFinishLaunching` (with a comment
explaining why the lazy property must be eagerly started). Compile-verified.

### WR-02: Deployment guide directs the EdDSA human gate to a paste site that silently doesn't work

**File:** `docs/deployment-guide.md:146` and `:148` (shipped revision)

**Issue:** Both spots instruct the human to paste the generated public key into
`INFOPLIST_KEY_SUPublicEDKey` in `project.pbxproj`. The 07-02 summary **itself disproved that
route** ("arbitrary INFOPLIST_KEY_* prefixes flow into the generated plist … was DISPROVEN by dumping
a built Info.plist … unknown keys (SUFeedURL) are dropped"), and the real paste site is
`SUPublicEDKey` in `SparkleInfo.plist` (its comment says exactly that). A human closing the EdDSA
gate by following the guide would put the key where it never reaches the built Info.plist — the gate
would appear closed while every update still fails signature verification.

**Fix (applied):** Both spots now point at `SUPublicEDKey` in `SparkleInfo.plist`, with the
INFOPLIST_KEY-drop explanation preserved so the mistake isn't re-made.

### WR-03 (RESOLVED post-review): PrivacyInfo.xcprivacy FileTimestamp reason codes don't match Apple's current definitions — 3B52.1 is third-party-SDK-only, and the app-container reason is now DDA9.1

**File:** `BoosterSimApp/PrivacyInfo.xcprivacy:24-31`; actual use sites:
`BoosterSimApp/Services/DerivedDataAppScanner.swift:75` (`.modificationDate`),
`BoosterSimApp/Services/CaptureExporter.swift:299-304` (`.contentModificationDateKey` — temp-dir sweep),
`BoosterSimApp/Services/BuildStatsService.swift:52` (`.contentModificationDateKey`)

**Issue:** Re-verified against Apple's current "Describing use of required reason API" documentation
(fetched during this review):

- **3B52.1** now reads "Declare this reason if your **third-party SDK** is providing a wrapper
  function around file timestamp API(s) … This reason **may only be declared by third-party SDKs**."
  An app manifest declaring it is inaccurate on its face.
- **C617.1** now covers "files or directories that the **user specifically granted access to**, such
  as using a document picker" — the app-container reason is **DDA9.1** ("files inside the app
  container, app group container, or the app's CloudKit container"). Neither the shipped pair nor the
  current wording's meaning matches what the code does: the temp sweep reads the app's own
  tmp directory (DDA9.1 territory), while the DerivedData mtime reads are outside the app container
  and not user-granted — no listed reason honestly covers them.

Impact is bounded: this is a macOS Developer ID app — required-reason enforcement is an App Store
Connect gate and Apple's policy text enumerates iOS/iPadOS/tvOS/visionOS/watchOS, not macOS — so the
manifest is best-practice here, not a shipping blocker. But it is the phase's own stated best-practice
deliverable, and it currently misstates both the reasons and, via 3B52.1, the declarer's identity.
Not auto-fixed: choosing the reason set (DDA9.1 alone, vs DDA9.1 + C617.1 for the user-selected
capture folder) plus an honest note about the uncovered DerivedData reads is a policy call for the
executor.

**Fix (suggested):**
```xml
<dict>
  <key>NSPrivacyAccessedAPIType</key>
  <string>NSPrivacyAccessedAPICategoryFileTimestamp</string>
  <key>NSPrivacyAccessedAPITypeReasons</key>
  <array>
    <string>DDA9.1</string><!-- app tmp sweep -->
    <!-- DerivedData mtime reads (DerivedDataAppScanner, BuildStatsService) sit outside every
         listed reason; keep the manifest minimal and honest rather than padding reasons. -->
  </array>
</dict>
```
…and update `docs/codebase-summary.md`'s PrivacyInfo line to match.

### WR-04: probeSupport has no ordering guard — a stale probe can overwrite a newer simulator's camera state

**File:** `BoosterSimApp/Services/CameraService.swift:49-62` (service); second trigger site added this
phase at `BoosterSimApp/Views/SideWindow/CameraView.swift` (`onChange(of: pid)`)

**Issue:** `probeSupport(pid:)` dispatches a `DispatchQueue.global` AX walk (synchronous
`AXUIElement` IPC — against a hung Simulator these calls block for the AX timeout, i.e. seconds) and
unconditionally writes `isSupported/isFrontEnabled/isBackEnabled` on the main queue when it finishes.
Nothing serializes or versions probes: switching simulators A→B in quick succession can let A's slow
probe complete *after* B's, leaving B's panel showing A's camera support state. Phase 6's single
onAppear trigger made the window narrow; Phase 7's added onChange trigger widens it. No retain cycle
exists (the AX closure captures only `pid`/paths; the main hop is `[weak self]`). Not auto-fixed —
the fix belongs to the Phase 6 service owner (generation-token or `pid`-check before the state write)
and deserves a regression test with a scripted double.

**Fix (suggested):**
```swift
func probeSupport(pid: pid_t) {
    let front = frontPath; let back = backPath
    DispatchQueue.global(qos: .userInitiated).async {
        let app       = AXUIElementCreateApplication(pid)
        let supported = axFindMenuItem(in: app, path: ["Features", "Camera"]) != nil
        let frontOn   = axFindMenuItem(in: app, path: front).map { axReadCheckmark($0) } ?? false
        let backOn    = axFindMenuItem(in: app, path: back).map  { axReadCheckmark($0) } ?? false
        DispatchQueue.main.async { [weak self] in
            guard let self, self.lastProbedPID == pid else { return }  // drop stale probe
            self.isSupported    = supported
            self.isFrontEnabled = frontOn
            self.isBackEnabled  = backOn
        }
    }
    lastProbedPID = pid  // @Published not required; bookkeeping only
}
```

## Info

### IN-01: CI keychain reuses the p12 passphrase; private-key temp files are never explicitly removed

**File:** `.github/workflows/release.yml:70-88` (cert import), `:91-99` (ASC key)

**Issue:** `APPLE_CERTIFICATE_P12_PASSPHRASE` doubles as the temporary keychain password and is passed
as argv to `security create-keychain -p` / `set-key-partition-list -k` — argv is visible to same-host
processes for the step's duration, though the runner is ephemeral and GitHub masks registered secrets
in logs. This is the standard import pattern; noting for the record. Similarly, the `mktemp` CERT_DIR
(.p12) and KEY_DIR (.p8) are never `rm -rf`'d — only the keychain is cleaned up in the `if: always()`
step. Suggest exporting the temp dirs to `GITHUB_ENV` and sweeping them in the cleanup step. The
review fix added a `trap … rm -f` for the most sensitive item, the EdDSA key file.

### IN-02: The DMG itself is not notarized — only the app inside is stapled

**File:** `scripts/build-release.sh:143-149` (stage 5 after stapling); `docs/deployment-guide.md`
"Direct Distribution (DMG)"

**Issue:** Gatekeeper accepts a stapled app inside an unsigned DMG at first-launch assessment, so the
distribution path works. But notarizing the DMG itself (notarytool accepts a DMG directly; then
`stapler staple <dmg>`) removes the remaining "unidentified"-friction surface and is Apple's
recommended shape for DMG distribution. A stage 6 after the current stage 5 would do it. Cosmetic-ish;
no correctness impact.

### IN-03: parseSimulatorWindow is internal-for-tests but still sits under `// MARK: - Private`

**File:** `BoosterSimApp/Services/WindowEnumerator.swift:19-24`

**Issue:** The 07-03 visibility change (`private` → internal) is the right test seam and stays
module-scoped, but the function now lives under a `// MARK: - Private` header it no longer satisfies.
Add a one-line doc comment (`/// Internal (not private) so WindowEnumeratorTests can pin the parse
contract; not for app-callers.`) or move the MARK when this file is next touched — cosmetic drift
guard, zero behavior.

### IN-04: Workflow actions pinned by tag, not commit SHA

**File:** `.github/workflows/release.yml:42,58,66`

**Issue:** `actions/checkout@v4`, `actions/cache@v4` resolve to mutable tags inside a pipeline whose
whole job is credential custody and publishing. Pin both to full commit SHAs (dependabot can maintain
them). Supply-chain hardening, no current exposure.

### IN-05: Two of the four new accessibilityIdentifiers are never queried

**File:** `BoosterSimApp/Views/Onboarding/OnboardingContainerView.swift:92` (`onboarding.root` +
`.accessibilityElement(children: .contain)`), `BoosterSimApp/Views/Onboarding/OnboardingStepView.swift`
(`onboarding.cta`)

**Issue:** `OnboardingFlowUITests` drives everything through `onboarding.stepTitle`,
`onboarding.stepIndicator`, `onboarding.skip`, and the window title — `onboarding.root` and
`onboarding.cta` are unreferenced (fine as spec'd anchors for future flows), and `.contain` on the
container is harmless here. Trim or wire them when the CTA-path test lands; noting so the unused
surface is a conscious choice.

### IN-06: `completedOnboarding` key literal now appears in four places

**File:** `BoosterSimApp/App/AppDelegate.swift:67,111`, `BoosterSimApp/Views/MenuBar/MenuBarView.swift:8`,
`BoosterSimApp/Views/Onboarding/OnboardingContainerView.swift:7`

**Issue:** The 07-03 seam writes the raw string `"completedOnboarding"` while three `@AppStorage`
declarations repeat it. Functionally correct today (`UserDefaults.standard.set` is exactly what
`@AppStorage` reads), but a single `AppSettings.onboardingCompletedKey` (or an `AppStorage`-writable
property on AppDelegate) would remove the drift risk the seam adds. Fold into the next touch of any
of these files.

---

_Verification performed during this review: (1) listed the pinned Sparkle 2.9.6 SPM checkout and
artifact trees — `checkouts/Sparkle/bin/` has no generate_appcast, `artifacts/sparkle/Sparkle/bin/`
does; (2) read `generate_appcast`'s ArgumentParser help + `Unarchive.swift`/`Appcast.swift`/
`ArchiveItem.swift`/`Secret.swift` sources to pin the input contract, `-o` semantics, and EdDSA key
file format (base64 of the 32-byte seed); (3) ran the shipped invocation — exit 1, "No usable archives
found in …/Test.app"; (4) ran the corrected invocation with a scratch ad-hoc-signed DMG + throwaway
EdDSA seed — exit 0, appcast.xml written with relative enclosure; (5) `/usr/bin/base64 --decode -o`
round-trip on this macOS 26 machine (runner OS family) — works; (6) `sips` pixel-size audit of all 10
shipped PNGs against Contents.json; (7) `xcodebuild` Debug build after the AppDelegate fix — BUILD
SUCCEEDED; (8) Apple required-reason documentation fetched and compared against a grep sweep of the
app sources for all five required-reason API categories._

_Reviewed: 2026-09-01T06:07:20Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: deep_
