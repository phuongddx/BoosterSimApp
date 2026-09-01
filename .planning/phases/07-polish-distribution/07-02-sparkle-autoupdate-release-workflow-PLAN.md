---
phase: 07-polish-distribution
plan: 02
type: execute
wave: 2
depends_on: ["07-01"]
files_modified:
  - .github/workflows/release.yml
  - docs/deployment-guide.md
  - BoosterSimApp/App/AppDelegate.swift
  - BoosterSimApp/Views/MenuBar/MenuBarView.swift
  - .github/workflows/release.yml
  - .planning/PROJECT.md
  - .planning/REQUIREMENTS.md
autonomous: false
requirements:
  - REQ-roadmap-phase7-polish-distribution
user_setup:
  - service: sparkle-eddsa
    why: "Task 3's EdDSA keypair generation stores the private key in the LOCAL keychain via Sparkle's generate_keys — a one-time human-credential step on the release machine (the same machine that owns the notary profile)"
    dashboard_config:
      - task: "Run Sparkle's generate_keys (path provided in the runbook) — prints/stores the EdDSA keypair; keep the terminal output for pasting SUPublicEDKey"
        location: "Terminal (Developer)'s keychain + Sparkle generate_keys binary"
estimate:
  tokens: 25000
  raw_tokens: 25000
  tasks: 3
  confidence: low

must_haves:
  truths:
    - "ROADMAP C2 (dependency half): Sparkle 2.9.6 is an SPM dependency of the BoosterSimApp target ONLY (the four coordinated pbxproj edits mirroring Pulse — package reference, project packageReferences, product dependency, app-target attach; BoosterSimConnect gets nothing), and Package.resolved is TRACKED in git for the first time with exactly two pins (Pulse 5.2.2 + Sparkle 2.9.6) — closing the long-standing infra gap from STATE.md"
    - "ROADMAP C2 (policy half): Sparkle is a second NAMED exception to the Apple-frameworks-only policy — PROJECT.md Constraints + Out-of-Scope lines and REQUIREMENTS.md REQ-nfr-03 are edited explicitly to name it (user-resolved 2026-09-01, 07-CONTEXT decision 1, D-1); the policy is never silently widened"
    - "ROADMAP C2 (runtime half): SPUStandardUpdaterController lives in AppDelegate's service block, a 'Check for Updates…' menu item sits in MenuBarView calling checkForUpdates, and SUFeedURL (GitHub Releases appcast URL) is set via INFOPLIST_KEY build settings — the app builds and the unit bundle stays green"
    - "ROADMAP C2 (release half): .github/workflows/release.yml builds, signs, notarizes, staples, DMGs, and generate_appcasts an appcast.xml on tag push — a well-formed sibling of ci.yml using named GitHub secrets for all credentials"
    - "ROADMAP C2 (key half): the blocking human checkpoint generates the Sparkle EdDSA keypair (keychain-stored private key) and wires the real SUPublicEDKey value into both app-config INFOPLIST_KEY sites — updates cannot be trusted before this, so the phase never claims C2 without it"
  artifacts:
    - .github/workflows/release.yml
    - .planning/PROJECT.md (policy edit)
    - .planning/REQUIREMENTS.md (REQ-nfr-03 wording edit)
  key_links:
    - "pbxproj Sparkle product dependency (app target only) → AppDelegate SPUStandardUpdaterController → MenuBarView 'Check for Updates…' → SUFeedURL appcast → SUPublicEDKey EdDSA verification — the update chain criterion 2 is made of"
    - "tag push → release.yml → scripts/build-release.sh (07-01) → GitHub Release (DMG + appcast.xml) → SUFeedURL — the distribution loop"
  prohibitions:
    - requirement_id: REQ-roadmap-phase7-polish-distribution
      category: transparency
      status: unverified
      flagged: true
      verification: judgment
      statement: "MUST NOT silently expand the Apple-frameworks-only policy — Sparkle ships as an explicit second named exception with PROJECT.md/REQUIREMENTS.md wording edits in the same change set as the pbxproj edit; and MUST NOT claim auto-update works before SUPublicEDKey carries the real EdDSA public key — an empty or placeholder key is an honest open item, not a finished update chain"
  flagged_assumptions:
    - "INFOPLIST_KEY_SUFeedURL / INFOPLIST_KEY_SUPublicEDKey build settings flow into the generated Info.plist under GENERATE_INFOPLIST_FILE = YES (the INFOPLIST_KEY_ prefix mechanism accepts arbitrary keys) — verified in Task 2 by dumping the built app's Info.plist"
    - "release.yml cannot be end-to-end proven from this machine (needs GitHub secrets + a real tag push) — its acceptance here is structural: valid YAML, correct job/step graph, secrets never echoed; the first real run is recorded as a follow-up at the phase gate"
---

<objective>
Make the app updatable: add Sparkle 2.9.6 as the second named SPM exception, wire the updater into the menu-bar app, generate the EdDSA signing identity, and ship the tag-push release workflow that produces the notarized DMG + signed appcast.

Task 1 is the dependency + policy change set (pbxproj via the exact Pulse template, app target only, Package.resolved tracked for the first time, PROJECT.md/REQUIREMENTS.md exception wording). Task 2 is the runtime wiring (AppDelegate controller, MenuBarView menu item, Info.plist keys) plus the GitHub Actions release workflow as a sibling of ci.yml. Task 3 is the second and last genuinely human-credential step of the phase: Sparkle EdDSA keypair generation and the real SUPublicEDKey.

Purpose: ROADMAP C2 (auto-update works) on the Sparkle path — MAS distribution is already Out of Scope, so this is the only realistic update channel (07-CONTEXT decision 1).
Output: Sparkle-integrated app, tracked pin file, release.yml, EdDSA key on record.
</objective>

<execution_context>
@~/.claude/gsd-core/workflows/execute-plan.md
@~/.claude/gsd-core/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/ROADMAP.md
@.planning/STATE.md
@.planning/phases/07-polish-distribution/07-CONTEXT.md
@.planning/phases/07-polish-distribution/07-RESEARCH.md
@.planning/phases/07-polish-distribution/07-PATTERNS.md
@BoosterSimApp/App/AppDelegate.swift
@BoosterSimApp/Views/MenuBar/MenuBarView.swift
@.github/workflows/ci.yml
@docs/deployment-guide.md
</context>

<tasks>

<task type="auto">
  <name>Task 1: Sparkle SPM dependency (app target only) + Package.resolved tracked + policy exception named</name>
  <files>
    BoosterSimApp.xcodeproj/project.pbxproj,
    .planning/PROJECT.md,
    .planning/REQUIREMENTS.md
  </files>
  <read_first>
    - BoosterSimApp.xcodeproj/project.pbxproj — the Pulse template sites this edit mirrors exactly: XCRemoteSwiftPackageReference block (:80-87), project packageReferences list (:312-314), XCSwiftPackageProductDependency section (:416-436), app-target packageProductDependencies (:199-202) vs BoosterSimConnect's (:271-274)
    - .planning/phases/07-polish-distribution/07-PATTERNS.md "project.pbxproj — Sparkle via the Pulse template" — the four-edit table including the single-target delta (Sparkle attaches to BoosterSimApp ONLY; linking a macOS package into the iphonesimulator BoosterSimConnect target is wrong by platform)
    - .planning/PROJECT.md Constraints + Out of Scope lines and .planning/REQUIREMENTS.md REQ-nfr-03 (line 44) + Out-of-Scope table (line 83) — the exact exception wordings to amend
  </read_first>
  <action>
    pbxproj — four coordinated edits, fresh 24-hex object ids, mirroring Pulse:
    1. New XCRemoteSwiftPackageReference "Sparkle" block: repositoryURL https://github.com/sparkle-project/Sparkle.git, requirement kind upToNextMajorVersion, minimumVersion 2.9.6;
    2. Append its id to the project packageReferences list beside Pulse's;
    3. One XCSwiftPackageProductDependency entry: productName Sparkle, pointing at the new package (unlike Pulse there is NO second per-target entry);
    4. Attach that product dependency to the BoosterSimApp target's packageProductDependencies (:199-202 list). BoosterSimConnect's list stays Pulse-only.
    The repo uses synchronized file groups, so no source-file references are needed — these four edits are the whole pbxproj change.

    Track the pin file: `git add BoosterSimApp.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved` in this same change — the file has been untracked through Phases 2-5 (STATE.md infra gap; every prior pin assertion was vacuous at the git level). Adding Sparkle rewrites it with two pins; tracking it turns plan 07-06's pin gate into a real assertion for the first time.

    Policy edits (same change set, per 07-CONTEXT decision 1 — never a silent widening):
    - .planning/PROJECT.md Constraints: "Apple frameworks only — exceptions: Pulse/PulseProxy via BoosterSimConnect (user-resolved 2026-08-29); Sparkle 2.x (auto-update) via the BoosterSimApp target (user-resolved 2026-09-01)". Mirror the same naming in PROJECT.md's Out of Scope "Strict zero-external-dependency policy" line, and add a Key Decisions table row for the Sparkle exception.
    - .planning/REQUIREMENTS.md REQ-nfr-03 wording: extend to name both exceptions (Pulse/PulseProxy AND Sparkle), and add the matching half-sentence to the Out-of-Scope table row at line 83.

    Resolve + build both schemes (BoosterSimApp AND BoosterSimConnect — the Phase 5 lesson in STATE.md: always build the framework scheme too; the app target compiles that folder empty).
  </action>
  <verify>
    <automated>grep -q 'repositoryURL = "https://github.com/sparkle-project/Sparkle.git"' BoosterSimApp.xcodeproj/project.pbxproj && grep -q 'minimumVersion = 2.9.6' BoosterSimApp.xcodeproj/project.pbxproj && git ls-files --error-unmatch BoosterSimApp.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved && python3 -c "import json;p=json.load(open('BoosterSimApp.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved'));pins={x['identity'] for x in p['pins']};assert pins=={'pulse','sparkle'},pins" && grep -q 'Sparkle' .planning/PROJECT.md && grep -q 'Sparkle' .planning/REQUIREMENTS.md && xcodebuild -project BoosterSimApp.xcodeproj -scheme BoosterSimApp -destination 'platform=macOS' build && xcodebuild -project BoosterSimApp.xcodeproj -scheme BoosterSimConnect -destination 'platform=macOS' build</automated>
    <fails_when>any step fails — Sparkle URL/version absent, pin file still untracked, pins ≠ {pulse, sparkle}, policy docs unchanged, or either scheme fails to build</fails_when>
  </verify>
  <done>Sparkle 2.9.6 linked into the app target only, both schemes green, Package.resolved tracked with exactly two pins, and the Apple-frameworks-only policy names Sparkle as the second explicit exception in both PROJECT.md and REQUIREMENTS.md.</done>
</task>

<task type="auto">
  <name>Task 2: Updater wiring (AppDelegate + menu item + Info.plist keys) and the tag-push release workflow</name>
  <files>
    BoosterSimApp/App/AppDelegate.swift,
    BoosterSimApp/Views/MenuBar/MenuBarView.swift,
    BoosterSimApp.xcodeproj/project.pbxproj,
    .github/workflows/release.yml
  </files>
  <read_first>
    - BoosterSimApp/App/AppDelegate.swift — the lazy-var service block (:17-39) where SPUStandardUpdaterController belongs; the class is @MainActor final — Sparkle is main-thread ObjC, compatible with the no-async/await rule (07-PATTERNS "Updater wiring")
    - BoosterSimApp/Views/MenuBar/MenuBarView.swift — menu structure; the natural slot for "Check for Updates…" is with Preferences/About (before the About item); the view already holds @EnvironmentObject var appDelegate
    - .github/workflows/ci.yml — the sibling to copy conventions from (runner macos-26, SPM resolve + cache pattern, env block)
    - scripts/build-release.sh (07-01) — the workflow calls THIS script; do not duplicate the pipeline in YAML
    - docs/deployment-guide.md — append the CI-secrets runbook subsection here after writing the workflow
  </read_first>
  <action>
    AppDelegate.swift: `import Sparkle` + one lazy service in the Feature Services block: `lazy var updaterController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)` — same ownership shape as every other service (07-PATTERNS: never a @StateObject in a view).
    MenuBarView.swift: add `Button("Check for Updates…") { appDelegate.updaterController.checkForUpdates(nil) }` between the Preferences link and About. No other menu changes.
    pbxproj (both BoosterSimApp configs, beside the existing INFOPLIST_KEY_* lines): `INFOPLIST_KEY_SUFeedURL = "https://github.com/phuongddx/BoosterSimApp/releases/latest/download/appcast.xml"` (the zero-infra GitHub Releases appcast hosting, 07-RESEARCH §2 / 07-CONTEXT specifics). Add `INFOPLIST_KEY_SUPublicEDKey` in the same edit but leave its value EMPTY here — Task 3's human supplies the real EdDSA public key; a placeholder/fake value is prohibited (the transparency prohibition). After building, dump the generated Info.plist and confirm SUFeedURL landed (validates the flagged INFOPLIST_KEY assumption).

    .github/workflows/release.yml — sibling of ci.yml, `on: push: tags: ['v*']`, one `release` job on macos-26:
    checkout → resolve SPM (same cache pattern as ci.yml) → import Developer ID cert from secret APPLE_CERTIFICATE_P12 (base64) into a temporary keychain → store notarytool credentials from secrets (ASC API-key form: key id / issuer id / key file) → run scripts/build-release.sh (full path — archive/export/notarize/staple/DMG) → generate appcast.xml with Sparkle's generate_appcast (run from the SPM checkout's Sparkle bin; signs with the EdDSA key imported from secret SPARKLE_PRIVATE_KEY) → create the GitHub Release with DMG + appcast.xml assets.
    All credentials come from `secrets.*` — never `echo`d, never logged; the workflow hard-codes only names. Add a "Required repository secrets" comment block at the top of the file listing each secret and where its value comes from (mirroring the deployment-guide runbook subsection you append: cert p12 export, notarytool ASC key creation, Sparkle `generate_keys -x` private-key export). If a step needs an output directory from the script, read the artifact paths the script prints (build/export/, build/BoosterSim.dmg).
  </action>
  <verify>
    <automated>grep -q 'SPUStandardUpdaterController' BoosterSimApp/App/AppDelegate.swift && grep -q 'Check for Updates' BoosterSimApp/Views/MenuBar/MenuBarView.swift && grep -c 'INFOPLIST_KEY_SUFeedURL' BoosterSimApp.xcodeproj/project.pbxproj | grep -qx 2 && python3 -c "import yaml;yaml.safe_load(open('.github/workflows/release.yml'))" && grep -q 'build-release.sh' .github/workflows/release.yml && grep -q 'generate_appcast' .github/workflows/release.yml && ! grep -qi 'password.*:' .github/workflows/release.yml && xcodebuild -project BoosterSimApp.xcodeproj -scheme BoosterSimApp -destination 'platform=macOS' -configuration Debug -derivedDataPath build/updater-check build && /usr/libexec/PlistBuddy -c 'Print :SUFeedURL' build/updater-check/Build/Products/Debug/BoosterSimApp.app/Contents/Info.plist</automated>
    <fails_when>any step fails — wiring symbols absent, SUFeedURL not in both configs, workflow YAML invalid or missing the script/appcast steps, a literal password in the workflow, build failure, or SUFeedURL missing from the generated Info.plist</fails_when>
  </verify>
  <done>The running app has a working Check for Updates entry point and a real feed URL; the release pipeline is one tag push away, with every credential in GitHub secrets and the CI-secrets runbook documented.</done>
</task>

<task type="checkpoint:human-verify" gate="blocking-human">
  <name>Task 3: Sparkle EdDSA keypair — generate, wire SUPublicEDKey, confirm keychain entry</name>
  <files>BoosterSimApp.xcodeproj/project.pbxproj</files>
  <read_first>
    - .planning/phases/07-polish-distribution/07-RESEARCH.md §2 EdDSA signing — generate_keys ships with the SPM checkout; private key stays in the local Keychain, public key goes to Info.plist
    - docs/deployment-guide.md CI-secrets runbook (Task 2) — the SPARKLE_PRIVATE_KEY export step (generate_keys -x) for the release workflow
  </read_first>
  <action>
    Present the runbook to the user (one-time, on the release machine — the same machine that owns the notary profile):
    1. Locate Sparkle's generate_keys: `find build ~/Library/Developer/Xcode/DerivedData -path '*Sparkle*bin/generate_keys' -type f 2>/dev/null | head -1` (or DerivedData/SourcePackages/checkouts/Sparkle/bin/generate_keys);
    2. Run it — creates the EdDSA keypair with the private key stored in the login keychain (service https://sparkle-project.org) and prints the public key;
    3. Paste the printed public key as the INFOPLIST_KEY_SUPublicEDKey value in BOTH BoosterSimApp configs (Task 2 left it empty for exactly this);
    4. Optional now / required before the first real release: `generate_keys -x` export → GitHub secret SPARKLE_PRIVATE_KEY for appcast signing in CI.
    After the user reports the key pasted, run the machine-checkable half: build and dump Info.plist to confirm SUPublicEDKey is present and non-empty, and probe the keychain for the Sparkle entry (`security find-generic-password -s "https://sparkle-project.org"` — if the service/account name differs by Sparkle version, accept the user's visual confirmation of the Keychain entry as the human-check half). Record the public key fingerprint/first chars in the SUMMARY.
  </action>
  <verify>
    <automated>grep -c 'INFOPLIST_KEY_SUPublicEDKey = "' BoosterSimApp.xcodeproj/project.pbxproj | grep -qx 2 && ! grep -q 'INFOPLIST_KEY_SUPublicEDKey = "";' BoosterSimApp.xcodeproj/project.pbxproj && xcodebuild -project BoosterSimApp.xcodeproj -scheme BoosterSimApp -destination 'platform=macOS' -configuration Debug -derivedDataPath build/eddsa-check build && PUB=$(/usr/libexec/PlistBuddy -c 'Print :SUPublicEDKey' build/eddsa-check/Build/Products/Debug/BoosterSimApp.app/Contents/Info.plist) && test ${#PUB} -gt 20 && echo "SUPublicEDKey wired (${#PUB} chars)"</automated>
    <fails_when>either config still lacks a real key value, the build fails, or the generated Info.plist carries an empty/missing SUPublicEDKey</fails_when>
    <human-check>The EdDSA keypair exists: Sparkle's generate_keys ran on this machine, the private key is visible in the login keychain, and the public key now in the pbxproj is the one generate_keys printed.</human-check>
  </verify>
  <acceptance_criteria>
    - SUPublicEDKey non-empty in both configs and present in the built app's Info.plist
    - Sparkle keychain entry confirmed by the user (name recorded in the SUMMARY)
    - SPARKLE_PRIVATE_KEY CI export either done or explicitly recorded as pending-first-release
    - No private-key material pasted into the repo — only the public key
  </acceptance_criteria>
  <what-built>The complete Sparkle update chain from Tasks 1-2 (SPM dependency + named policy exception + tracked pin, updater controller, menu item, feed URL, release workflow) — this checkpoint adds the trust anchor: the EdDSA signing identity that makes appcasts verifiable.</what-built>
  <how-to-verify>
    1. Locate generate_keys: `find build ~/Library/Developer/Xcode/DerivedData -path '*Sparkle*bin/generate_keys' -type f 2>/dev/null | head -1`
    2. Run it — private key lands in the login keychain (service https://sparkle-project.org), public key prints to terminal
    3. Paste the public key into INFOPLIST_KEY_SUPublicEDKey in BOTH BoosterSimApp configs
    4. Optional now (required before first release): `generate_keys -x <file>` export → GitHub secret SPARKLE_PRIVATE_KEY
    5. Machine half: rebuild and dump Info.plist :SUPublicEDKey (non-empty), probe `security find-generic-password -s "https://sparkle-project.org"`
  </how-to-verify>
  <resume-signal>Reply "key wired" to close this plan, or report the generate_keys failure — without a real EdDSA key the update chain is honestly incomplete and the phase gate (07-06) will carry it as an open item.</resume-signal>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| SPM registry → build | A new third-party package enters the dependency graph (first addition since Pulse) |
| Update feed → app | The appcast the shipped app fetches is remote content; EdDSA + SUPublicEDKey is the entire integrity boundary |
| GitHub secrets → release workflow | CI holds signing/notary/EdDSA credentials; the workflow must only ever reference them by name |

## STRIDE Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation Plan |
|-----------|----------|-----------|----------|-------------|-----------------|
| T-07-SC | Tampering | SPM install (Sparkle) | high | mitigate | Package legitimacy: research-verified official repo https://github.com/sparkle-project/Sparkle at 2.9.6 (live-checked 2026-09-01, 07-RESEARCH §2 — a security-fix release); pin recorded in tracked Package.resolved; this blocking gate is the 07-01/07-02 human reviews of the diff itself |
| T-07-05 | Tampering | update feed (appcast) | critical | mitigate | EdDSA end-to-end: keypair generated on the release machine (Task 3 gate), SUPublicEDKey pinned into Info.plist before any release, appcast signed via generate_appcast; empty-key prohibition keeps the chain honest until real |
| T-07-06 | Information disclosure | release.yml + CI secrets | high | mitigate | Credentials only as secrets.* by name; no echo/no log of secret values; verify greps the workflow for literal password fields; runbook keeps values out of the repo |
| T-07-07 | Spoofing | SPM dependency scope | medium | mitigate | App-target-only attach (verified by build of both schemes — a wrong-target link fails to build); Package.resolved pin tracked so 07-06's git-level pin gate is real |
</threat_model>

<verification>
- Task 1: Sparkle pbxproj sites present, pin file tracked with pins == {pulse, sparkle}, policy docs name the exception, both schemes build
- Task 2: updater symbols wired in both files, SUFeedURL in 2 configs and in the BUILT Info.plist, release.yml valid YAML with script + appcast steps and zero literal credentials
- Task 3: non-empty SUPublicEDKey in both configs and the built plist + user-confirmed keychain keypair
</verification>

<success_criteria>
- ROADMAP C2 TRUE: auto-update ships on the Sparkle path — dependency (named exception, pinned, tracked), runtime entry point, feed URL, EdDSA identity, and the tag-push release pipeline that feeds the appcast
- The Apple-frameworks-only policy tells the truth with two named exceptions
- CI secrets documented; no credential material in the repo
</success_criteria>

<output>
Create `.planning/phases/07-polish-distribution/07-02-sparkle-autoupdate-release-workflow-SUMMARY.md` when done
</output>
