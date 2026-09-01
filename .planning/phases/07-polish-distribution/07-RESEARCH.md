# Phase 7: Polish & Distribution — Research

**Researched:** 2026-09-01
**Method:** Direct codebase verification (grep/read/bash) + Apple documentation + Sparkle release notes. A first `gsd-phase-researcher` dispatch failed mid-write after ~20 minutes of thorough tool use (transcript recovered via `history://Phase7Researcher` — its intermediate findings are folded in here, re-verified rather than trusted blind).

<critical_findings>
## Two items need a user decision before planning locks in — not guessed here

### 1. Code-signing team mismatch (BLOCKER)

`BoosterSimApp.xcodeproj/project.pbxproj` has `DEVELOPMENT_TEAM = EQ8B89SPCX` with `CODE_SIGN_STYLE = Automatic` (all 3 build configs). Direct verification via `security find-identity -v -p codesigning`:

```
16) 633D175D73094D48FEBD9D99645EA71319C3C46E "Developer ID Application: Doan Duy Phuong (K2TYLYAWMK)"
18) 6037EE31B2E7426301010F5C772428BED2326F1B "Apple Distribution: Doan Duy Phuong (K2TYLYAWMK)"
```

**There is no Developer ID Application certificate for team `EQ8B89SPCX` in this machine's keychain.** Every cert for `EQ8B89SPCX` (there are none listed at all — the 18 identities span teams `FZR6T9D986`, `4L72Q793UP`, `A776CLF9J7`, `8J6FYQG5DS`, `S8WKV7KQZ3`, `8736MVLBTN`, `23JSZ3C425`, `K2TYLYAWMK`, `47LQYKAHQQ`, `5UL96WWTA7` — never `EQ8B89SPCX`) is absent. Developer ID Application (required for notarized direct distribution, as opposed to `Apple Development`/`Apple Distribution` which are for Xcode-managed dev builds / App Store) exists only under team `K2TYLYAWMK`.

**This blocks notarization until resolved.** Options: (a) switch `DEVELOPMENT_TEAM` to `K2TYLYAWMK` (the team with a real Developer ID cert already present) if that's the intended distribution identity, or (b) download/generate a Developer ID Application cert for `EQ8B89SPCX` from developer.apple.com if that team is correct and just missing local keychain state. **Planner must not silently pick one — surface this to the user before Task 1 of the signing plan.**

### 2. Privacy manifest may not apply the way ROADMAP assumed

ROADMAP Phase 7 criterion 4 lists "Privacy manifest" as required. Apple's actual documentation (`developer.apple.com/support/third-party-SDK-requirements/`, `developer.apple.com/documentation/bundleresources/describing-data-use-in-privacy-manifests`) frames privacy manifests (`PrivacyInfo.xcprivacy`, required-reason API declarations) around **App Store Connect submission** — "When you prepare to distribute your app... Xcode will combine the privacy manifests... Refer to this report when you provide your app's privacy details in **App Store Connect**." REQUIREMENTS.md already locks Mac App Store distribution as **Out of Scope** ("Sandbox incompatible with AXIsProcessTrusted/CGWindowList/AXObserver/simctl usage"). A direct-distribution (Developer ID + notarization, no App Store Connect submission) macOS app is not gated by Apple's privacy-manifest enforcement mechanism the same way an App Store submission is — notarization checks signing/malware, not privacy manifests.

**This doesn't mean skip it** — a `PrivacyInfo.xcprivacy` file is still good practice and costs little to add (this app does use several "required reason" API categories, enumerated below), and Sparkle itself may ship its own privacy manifest that Xcode aggregates regardless of distribution channel. But the planner should not treat "must pass an App Store privacy review" as the acceptance bar, since that review never happens for this distribution path. Recommend: add `PrivacyInfo.xcprivacy` documenting the categories below as a transparency/best-practice artifact, not as an App-Store-gate requirement.

</critical_findings>

## 1. Code Signing + Notarization

**Current state:** `DEVELOPMENT_TEAM = EQ8B89SPCX`, `CODE_SIGN_STYLE = Automatic`, hardened runtime already enabled (confirmed via pbxproj grep), `GENERATE_INFOPLIST_FILE = YES`. `ENABLE_APP_SANDBOX = NO` (documented, locked constraint). No `.entitlements` file exists in the repo (`find -iname "*.entitlements"` returns empty) — the app currently relies on implicit/default entitlements from hardened-runtime + automatic signing.

**Notarization does not require sandboxing.** Hardened Runtime + notarization is compatible with `AXIsProcessTrusted`, `CGWindowListCopyWindowInfo`, `AXObserverCreate`, and `xcrun simctl` usage — none of these require sandbox exceptions; they require **runtime permission grants** (Accessibility, Screen Recording), which are orthogonal to code signing and already handled by this app's existing onboarding flow. The existing `docs/deployment-guide.md` (113 lines, already in the repo) has a "Distribution (Future)" section explicitly marked "planned for Phase 7" with the skeleton commands: `xcodebuild archive` → `-exportArchive` → `xcrun notarytool submit --keychain-profile ... --wait` → `xcrun stapler staple`. This is the right shape; Phase 7 fills in the real `ExportOptions.plist`, sets up the `notarytool` keychain profile (`xcrun notarytool store-credentials`), and resolves the team mismatch above first.

**DMG creation:** `create-dmg` is NOT installed locally (`command -v create-dmg` fails). `hdiutil create` (already sketched in deployment-guide.md) needs no extra tooling and is sufficient — recommend sticking with `hdiutil`, not adding a new dependency for this.

**Gatekeeper/quarantine:** a notarized + stapled DMG lets Gatekeeper verify offline (no network check needed at first launch) — standard behavior once stapling succeeds. No special entitlement needed for this beyond the hardened runtime + notarization ticket.

## 2. Sparkle Auto-Update

**Latest stable:** Sparkle **2.9.6** (released 2026-08-17, tag `2.9.6`, repo `https://github.com/sparkle-project/Sparkle` — verified live via GitHub releases page: "Release 2.9.6 Appcast Improvements", security-fix release for installer symlink handling and root-privilege escalation).

**SPM coordinates:** `.package(url: "https://github.com/sparkle-project/Sparkle", from: "2.9.6")`, product `Sparkle`. Follows the exact same pbxproj pattern as the existing Pulse dependency (`XCRemoteSwiftPackageReference` + `packageReferences` + product dependency attached to the **app target only** — BoosterSimConnect is an iOS framework and has no update-checking role, mirrors how Pulse/PulseProxy split across targets but Sparkle is macOS-only so it attaches solely to BoosterSimApp).

**Menu-bar app compatibility:** Sparkle's `SPUStandardUpdaterController` does not require a Dock icon or main window — it's driven programmatically (`checkForUpdates()`) and can present its UI (update alert, permission prompt) as a standalone panel/alert regardless of `LSUIElement`. This is a well-established pattern for menu-bar-only utilities; no blocker for this app's `AppDelegate` + `@NSApplicationDelegateAdaptor` shape. Minimal integration: instantiate `SPUStandardUpdaterController` in `AppDelegate` (mirrors how other services are lazily constructed there per `AppDelegate.swift:28-29,37-38` pattern used for Design Tools services), wire a "Check for Updates…" menu item into the existing `MenuBarView.swift` menu, and add `SUFeedURL` + `SUPublicEDKey` to `Info.plist` (or via `GENERATE_INFOPLIST_FILE` build settings, matching the project's existing Info.plist-generation convention).

**EdDSA signing:** Sparkle ships its own `generate_keys` binary (available after adding the SPM dependency, under the built package's `bin/` or via `Sparkle/bin/generate_keys` in a manual download) — generates an EdDSA keypair, stores the private key in the local Keychain, and the public key (`SUPublicEDKey`) goes in Info.plist. This is a one-time setup step for whoever controls releases (ties into the signing-identity decision above — should be the same person/team that owns notarization credentials).

**Appcast hosting:** given the repo is `github.com/phuongddx/BoosterSimApp`, the zero-infra-cost pattern is: GitHub Actions release workflow (there's already `.github/workflows/ci.yml`, 192 lines — a release workflow would be a sibling) builds + signs + notarizes + generates `appcast.xml` (via Sparkle's `generate_appcast` tool) on tag push, then commits the appcast to a `gh-pages` branch or attaches it as a release asset referenced by a stable URL (`https://github.com/phuongddx/BoosterSimApp/releases/latest/download/appcast.xml`). This avoids needing any separate hosting infrastructure.

**Package.resolved impact:** current pin is `Pulse 5.2.2` only (`.../Package.resolved` — untracked in git, confirmed via `git status --porcelain`, matching every prior phase-gate's noted infra gap). Adding Sparkle adds a second pin. This is a natural, low-risk forcing function to finally `git add` the file — tracking it doesn't conflict with the sha256 content-stability pattern used in every prior gate (Phase 2/3/4/5 all diffed `git diff --exit-code` as a no-op check because the file was untracked; once tracked, the same check becomes meaningful instead of vacuous — a strict improvement, not a behavior change).

## 3. Privacy Manifest — Concrete API Usage

(See Critical Findings #2 for scope caveat — building this as a transparency artifact, not an App Store gate.)

Grep-verified actual "required reason" API usage in `BoosterSimApp/`:

| Category | Files | Notes |
|---|---|---|
| Accessibility API (`AXIsProcessTrusted`, `AXObserver*`, `AXUIElement*`) | `Services/AXInspectorService.swift`, `Services/SimulatorWindowTracker.swift`, `Services/WindowObserver.swift`, `Services/PermissionManager.swift`, `Services/CameraService.swift` | Not one of Apple's iOS-scoped "required reason API" categories (those are UserDefaults, file timestamp, system boot time, disk space) — Accessibility API has its own separate `NSAccessibilityUsageDescription` Info.plist key mechanism, already presumably present since onboarding requests this permission. |
| ScreenCaptureKit (`SCShareableContent`, `SCStream`) | `Services/ScreenshotService.swift`, `Services/RecordingService.swift` | Gated by `NSScreenCaptureUsageDescription` (Info.plist string), not a privacy-manifest required-reason category either. |
| `UserDefaults`/`@AppStorage` | 17 files (grep count) | **This IS one of Apple's four required-reason API categories** (`NSPrivacyAccessedAPICategoryUserDefaults`). Approved reason codes per Apple's published list: `CA92.1` (access info from same app via App Group), `1C8F.1` (access info from same app, no App Group), `C56D.1` (access managed by CMS), `AC6B.1` (declared web-page bundle ID). This app has no App Group and no CMS; the correct code is **`1C8F.1`** — "Read/write UserDefaults data that isn't accessed by other apps or shared with a third party." |
| File timestamp APIs (`stat`, `creationDate`, `contentModificationDate`, `getattrlist`) | none found (grep returned 0 matches beyond incidental strings) | No file-timestamp required-reason declaration needed. |

**Net scope for `PrivacyInfo.xcprivacy` if the planner adds one:** a single `NSPrivacyAccessedAPICategoryUserDefaults` entry with reason `1C8F.1`. Everything else the app touches (Accessibility, ScreenCaptureKit, simctl) is governed by separate usage-description strings already required at runtime, not by the privacy-manifest required-reason mechanism.

## 4. Phase 6 Wiring Placement

See `.planning/phases/07-polish-distribution/07-PATTERNS.md` (produced by a parallel `gsd-pattern-mapper` dispatch, completed successfully) for the full file:line mapping. Summary of its key findings, cross-checked against this research pass:

- Injection is **already complete end-to-end**: `AppDelegate.swift:17-21,43-59` constructs `statusBarService`/`buildStatsService`/`axInspectorService`/`cameraService` → `SideWindowController.swift:227-231` injects them as `EnvironmentObject`s → `SideWindowView.swift:11-17` already declares `@EnvironmentObject` properties for them. **The wiring gap is view instantiation only** — no service construction or dependency plumbing needed.
- `REQ-fr-13` enforcement point is `TabBarView.swift:13`, `ForEach(SideTab.allCases)` — confirms no 5th tab is structurally possible without changing `SideTab`'s `CaseIterable` set, which would violate the locked requirement.
- Three existing host-tab mount conventions identified: `ActionsTabView`'s catalog-table pattern (most reusable — sections join `AppActionSection`/`AppActionCatalog.all`), `NetworkTabView`'s flat stack, `CaptureTabView`'s `CollapsibleSection` rows.
- **Trap found by pattern-mapper, re-confirmed here:** `CameraService.probeSupport(pid:)` has zero call sites anywhere — mounting `CameraView` requires adding an `onAppear`/`onChange` probe call (following `EnvironmentOverridesView.swift:65-70`'s existing convention for a similar probe-on-appear pattern), or `CameraView` will render with stale/absent support-detection state.
- `AXTreeView`/`CameraView` take a `pid` parameter (from `SimulatorWindow.swift:24`'s `activeSim?.pid`), not a `udid` string like the Actions-tab views — a signature mismatch to account for when writing the mount call, not a redesign.
- `AXTreeView` loads only on a manual refresh tap — no auto-load by design (existing behavior, preserve it).
- `AppActionCatalogTests.swift` greps show `count`/`allCases`/`sections` assertions — **adding new sections to the Actions tab's catalog will likely require updating a pinned section-count assertion in that test file.** Flag this for the planner so it isn't a surprise mid-implementation.

## 5. Unit / UI Test Coverage

Confirmed via direct read: `BoosterSimApp/Models/AppSettings.swift`, `BoosterSimApp/Windows/PositionCalculator.swift`, `BoosterSimApp/Services/WindowEnumerator.swift` all exist and are real (not stubs). **None currently have a dedicated test suite** (grep against `BoosterSimAppTests/` for their type names returns no hits) — this is genuinely new coverage, consistent with them being pre-`.planning` Phase-1 code that predates the test-suite convention established in Phase 2 onward.

**Existing test convention (24 suites, all Swift Testing):** every suite in `BoosterSimAppTests/` uses `import Testing` / `@Test` / `#expect` — zero `XCTest` imports anywhere in that target (confirmed by grep). New suites for `PositionCalculator`/`WindowEnumerator`/`AppSettings` must match this convention, not introduce `XCTest`.

**UI tests:** `BoosterSimAppUITests/` currently has 3 files: `BoosterSimAppUITests.swift`, `BoosterSimAppUITestsLaunchTests.swift`, `ScreenshotTests.swift` (95 lines — an existing precedent for driving the app's onboarding-adjacent UI via `XCUIApplication`). Onboarding flow views: `BoosterSimApp/Views/Onboarding/OnboardingContainerView.swift` (53 lines) and `OnboardingStepView.swift` (99 lines) — the 4-step flow (Welcome → Accessibility → Screen Recording → Ready per docs/design-guidelines.md) is a real, existing, unstubbed flow to test against. No `accessibilityIdentifier` usage found anywhere in the app yet (grep returned effectively empty) — onboarding UI tests will need identifiers added to the relevant buttons/steps for reliable `XCUIElement` queries, a small addition to the onboarding views themselves.

## Package.resolved / CI Notes

- `.github/workflows/ci.yml` exists (192 lines) — a Phase 7 release workflow (build → sign → notarize → staple → DMG → appcast) is a natural sibling file, not a from-scratch CI setup.
- `docs/deployment-guide.md` already has a "Distribution (Future)" section explicitly deferred to Phase 7 — Phase 7's docs work should convert this from "planned" to "as-shipped," not write a new file from scratch.

---
*Research completed: 2026-09-01*
