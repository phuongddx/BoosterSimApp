---
phase: 07-polish-distribution
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - BoosterSimApp.xcodeproj/project.pbxproj
  - ExportOptions.plist
  - scripts/build-release.sh
  - docs/deployment-guide.md
autonomous: false
requirements:
  - REQ-roadmap-phase7-polish-distribution
user_setup:
  - service: apple-notarytool
    why: "Task 3's real notarization submission needs an Apple ID (member of team K2TYLYAWMK) with an app-specific password, stored once via the interactive xcrun notarytool store-credentials — cannot be scripted blind"
    dashboard_config:
      - task: "Create an app-specific password at appleid.apple.com (sign-in → App-Specific Passwords) for the notary profile"
        location: "https://appleid.apple.com → Sign-In and Security → App-Specific Passwords"
estimate:
  tokens: 22000
  raw_tokens: 22000
  tasks: 3
  confidence: low

must_haves:
  truths:
    - "ROADMAP C1 (signing half): DEVELOPMENT_TEAM is K2TYLYAWMK in every build configuration and zero stale-team occurrences remain; Release archive → Developer-ID export → signed .app → DMG all succeed locally against the real Developer ID Application certificate in the keychain (07-CONTEXT decision 4, D-4)"
    - "ROADMAP C1 (flow half): a real ExportOptions.plist (method developer-id, teamID K2TYLYAWMK) and scripts/build-release.sh encode archive → export → zip → notarytool submit --wait → staple → DMG; the script's credential-free path (--skip-notarization) runs end-to-end unattended"
    - "ROADMAP C1 (documentation half): docs/deployment-guide.md tells the as-shipped truth — the deferred-distribution placeholder section is replaced by the real runbook, the non-sandbox rationale (ENABLE_APP_SANDBOX = NO required by AXIsProcessTrusted/CGWindowList/AXObserver/simctl) is documented, and the stale macOS-15/Xcode-16.3 requirement lines match the project's real deployment target (26.2)"
    - "ROADMAP C1 (notarization half): a REAL notarization is on record — the blocking human checkpoint stores notarytool credentials interactively, submits the exported app, and records the accepted ticket id plus a passing stapler validate; build success alone never closes this"
  artifacts:
    - ExportOptions.plist
    - scripts/build-release.sh
    - docs/deployment-guide.md
  key_links:
    - "pbxproj DEVELOPMENT_TEAM (8 occurrences: project-level × 2 configs + BoosterSimApp × 2 + BoosterSimAppTests × 2 + BoosterSimAppUITests × 2) → keychain Developer ID Application cert (team K2TYLYAWMK) → export re-sign → notarytool keychain profile → stapler ticket — the chain criterion 1 is made of"
    - "scripts/build-release.sh ↔ docs/deployment-guide.md — the script is the executable form of the documented runbook; the two must name the same profile name and artifact paths"
  prohibitions:
    - requirement_id: REQ-roadmap-phase7-polish-distribution
      category: security
      status: unverified
      flagged: true
      verification: judgment
      statement: "MUST NOT embed Apple IDs, app-specific passwords, or keychain passwords in scripts, workflow files, or docs — notarytool credentials live ONLY in the keychain profile referenced by name; and MUST NOT close criterion 1 on archive/export success alone — only a real accepted notarization ticket plus a passing stapler validate closes it"
  flagged_assumptions:
    - "Export with automatic signing + developer-id method succeeds with no entitlements file (none exists; hardened runtime already on) — proven live by Task 1's export stage"
    - "The K2TYLYAWMK Developer ID cert's private key is accessible in the login keychain for non-interactive xcodebuild use — proven by Task 1's archive/export; if key access prompts, record it in the SUMMARY and surface at the Task 3 gate"
---

<objective>
Make the app distributable: switch signing to the team that actually owns a Developer ID Application certificate (per 07-CONTEXT decision 4), and prove the archive → export → notarize → staple → DMG pipeline end-to-end, converting docs/deployment-guide.md's deferred-distribution skeleton into the as-shipped runbook.

Task 1 is the phase tracer: one command path from pbxproj config through archive, Developer-ID export, and DMG creation — everything except the two human-credential moments (interactive credential storage, real submission). Task 2 converts the deployment guide from planned to as-shipped, including the non-sandbox documentation ROADMAP C1 explicitly requires. Task 3 is the one blocking-human step this plan genuinely needs: the developer stores notarytool credentials interactively and runs the real submission, confirming a real ticket.

Purpose: ROADMAP C1 is the phase's foundation — the Sparkle release workflow (plan 07-02) builds on the final team ID and this script.
Output: ExportOptions.plist, scripts/build-release.sh, as-shipped docs/deployment-guide.md, one recorded real notarization.
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
@docs/deployment-guide.md
@BoosterSimApp.xcodeproj/project.pbxproj
</context>

<tasks>

<task type="tracer">
  <name>Task 1: Team switch + one-command release path — archive → Developer-ID export → DMG (credential-free)</name>
  <files>
    BoosterSimApp.xcodeproj/project.pbxproj,
    ExportOptions.plist,
    scripts/build-release.sh
  </files>
  <read_first>
    - BoosterSimApp.xcodeproj/project.pbxproj — the 8 DEVELOPMENT_TEAM = EQ8B89SPCX sites (grep-verified at :477, :543, :574, :610, :644, :666, :687, :707) and the app target's existing INFOPLIST_KEY_* / GENERATE_INFOPLIST_FILE block
    - docs/deployment-guide.md — the existing "Distribution" skeleton commands this script systematizes
    - .planning/phases/07-polish-distribution/07-RESEARCH.md §1 — signing state (Automatic style, hardened runtime on, no entitlements file, hdiutil over create-dmg) and §critical_findings #1 (the team mismatch, decision 4)
  </read_first>
  <precondition>The keychain holds a valid "Developer ID Application: … (K2TYLYAWMK)" identity with an accessible private key — assert with `security find-identity -v -p codesigning | grep "Developer ID Application.*K2TYLYAWMK"` before starting; halt and surface if absent.</precondition>
  <action>
    pbxproj: replace every DEVELOPMENT_TEAM = EQ8B89SPCX occurrence with K2TYLYAWMK — there are 8 (project-level Debug+Release, BoosterSimApp × 2, BoosterSimAppTests × 2, BoosterSimAppUITests × 2; 07-CONTEXT decision 4 says "all 3 build configs" meaning the project's whole config surface — a global replace of the stale team string is the intent, BoosterSimConnect has no DEVELOPMENT_TEAM line today and must not gain one). Touch nothing else in the file — CODE_SIGN_STYLE = Automatic, ENABLE_HARDENED_RUNTIME = YES, and ENABLE_APP_SANDBOX = NO stay exactly as they are (07-CONTEXT "already locked by prior phases").

    ExportOptions.plist (repo root, next to the xcodeproj): minimal real file — method developer-id, teamID K2TYLYAWMK, signingStyle automatic. No provisioning profile keys (direct distribution).

    scripts/build-release.sh: bash, `set -euo pipefail`, run from repo root, configurable via env with defaults (PROJECT=BoosterSimApp.xcodeproj, SCHEME=BoosterSimApp, CONFIGURATION=Release, BUILD_DIR=build, NOTARY_PROFILE=booster-notary). Stages, each logged with a clear header:
    1. archive — `xcodebuild archive` to $BUILD_DIR/BoosterSimApp.xcarchive;
    2. export — `xcodebuild -exportArchive` with ExportOptions.plist to $BUILD_DIR/export (this is where the app is re-signed Developer ID);
    3. zip — `ditto -c -k --keepParent` the exported .app to BoosterSimApp.zip (notarytool's submission format);
    4. notarize — submit the zip with `xcrun notarytool submit --keychain-profile $NOTARY_PROFILE --wait`, then `xcrun stapler staple` the .app and `xcrun stapler validate` it. With `--skip-notarization` this stage is skipped with an explicit log line (used by Task 1 and by CI dry runs). Without the flag, first check the profile exists (any notarytool invocation with --keychain-profile that fails with a profile-not-found error) and exit non-zero with the exact `xcrun notarytool store-credentials` command to run — never prompt for credentials inside the script;
    5. dmg — `hdiutil create -volname "BoosterSim" -srcfolder <exported .app> -ov -format UDZO $BUILD_DIR/BoosterSim.dmg` (hdiutil, not create-dmg — 07-RESEARCH §1).
    End by printing each produced artifact path. No credentials, tokens, or passwords anywhere in the script — only the profile NAME.

    Run the credential-free path: `scripts/build-release.sh --skip-notarization`. Expect stage 4's skip line; the .app must be Developer-ID-signed.
  </action>
  <verify>
    <automated>grep -c 'DEVELOPMENT_TEAM = K2TYLYAWMK' BoosterSimApp.xcodeproj/project.pbxproj | grep -qx 8 && ! grep -q 'EQ8B89SPCX' BoosterSimApp.xcodeproj/project.pbxproj && plutil -lint ExportOptions.plist && bash -n scripts/build-release.sh && scripts/build-release.sh --skip-notarization && test -f build/BoosterSim.dmg && codesign -dv --verbose=2 build/export/BoosterSimApp.app 2>&1 | grep -q 'TeamIdentifier=K2TYLYAWMK' && codesign --verify --deep --strict build/export/BoosterSimApp.app</automated>
    <fails_when>any chained command fails — count ≠ 8, stale team string survives, plist fails lint, script syntax error, the release path aborts, no DMG, or the exported app is not signed by team K2TYLYAWMK</fails_when>
  </verify>
  <done>One command produces a Developer-ID-signed BoosterSimApp.app (team K2TYLYAWMK) and BoosterSim.dmg from a clean Release archive; the notarize stage is fully scripted but inert until the keychain profile exists; all committed.</done>
</task>

<task type="auto">
  <name>Task 2: Deployment guide as-shipped — runbook, non-sandbox rationale, corrected requirements</name>
  <files>docs/deployment-guide.md</files>
  <read_first>
    - docs/deployment-guide.md in full — the "Distribution" placeholder section to convert, the Sandboxing Considerations section to keep and reference, the stale Requirements block, and the Version Scheme section (says 0.1.0 while pbxproj carries MARKETING_VERSION = 1.0)
    - scripts/build-release.sh (Task 1) — profile name and artifact paths the doc must match exactly
    - README.md Requirements section — the current truth for deployment target / Xcode lines (macOS 26.2+, Xcode 26.3), corroborated by pbxproj MACOSX_DEPLOYMENT_TARGET = 26.2
  </read_first>
  <action>
    Convert the deferred-distribution section from planned to as-shipped:
    - Replace the "planned for Phase 7" framing with the real flow: `scripts/build-release.sh` as the primary path (stage-by-stage explanation), with the raw xcodebuild/notarytool/hdiutil commands kept as the manual equivalent of each stage.
    - Add the credential runbook subsection: one-time `xcrun notarytool store-credentials booster-notary --apple-id <Apple ID> --team-id K2TYLYAWMK --password <app-specific password>` (interactive by design — never scripted), followed by the submit/staple invocation the script performs. Use placeholder markup like `<Apple ID>`, never a real credential.
    - Keep and tighten the Sandboxing Considerations section — it already carries ROADMAP C1's required non-sandbox documentation (AXIsProcessTrusted, CGWindowListCopyWindowInfo, AXObserverCreate, xcrun simctl spawn all require ENABLE_APP_SANDBOX = NO); state plainly that Developer ID + hardened runtime + notarization + stapling is fully compatible with the non-sandboxed runtime and that Mac App Store distribution stays Out of Scope.
    - Fix the stale Requirements block to the project's real floor (macOS 26.2 / Xcode 26.3 per pbxproj and README), and align the Version Scheme "Current" line with MARKETING_VERSION = 1.0.
    - DMG section: document the hdiutil invocation as shipped (create-dmg was evaluated and rejected — extra dependency for zero gain, 07-RESEARCH §1).
    Truth-gate: every command and path in the doc must match what Task 1 shipped — no aspirational commands.
  </action>
  <verify>
    <automated>! grep -q 'planned for Phase 7' docs/deployment-guide.md && grep -q 'store-credentials' docs/deployment-guide.md && grep -q 'booster-notary' docs/deployment-guide.md && grep -q 'ENABLE_APP_SANDBOX' docs/deployment-guide.md && grep -q 'build-release.sh' docs/deployment-guide.md && grep -q 'stapler validate' docs/deployment-guide.md && ! grep -q 'macOS 15 Sequoia' docs/deployment-guide.md</automated>
    <fails_when>any check fails — the deferred framing survives, the runbook or profile name is missing, the non-sandbox rationale was dropped, the doc doesn't reference the script, or the stale requirements line remains</fails_when>
  </verify>
  <done>docs/deployment-guide.md describes exactly what ships: script-first runbook, interactive credential setup called out as human-only, non-sandbox rationale per ROADMAP C1, corrected version/target facts.</done>
</task>

<task type="checkpoint:human-verify" gate="blocking-human">
  <name>Task 3: Real notarization — store credentials, submit, staple, confirm the ticket</name>
  <files>none</files>
  <read_first>
    - docs/deployment-guide.md (Task 2) — the runbook this checkpoint executes
    - .planning/phases/07-polish-distribution/07-RESEARCH.md §critical_findings #1 — why this step is human-bound (Apple ID credentials, interactive store-credentials)
  </read_first>
  <action>
    Present the runbook to the user (user_setup frontmatter covers the app-specific password prerequisite):
    1. `xcrun notarytool store-credentials booster-notary --apple-id <their Apple ID> --team-id K2TYLYAWMK --password <app-specific password>` — interactive, human-owned;
    2. `scripts/build-release.sh` (full path — submits the zip, waits, staples, validates);
    3. `xcrun notarytool history --keychain-profile booster-notary` to read back the accepted ticket id.
    After the user reports completion, run the machine-checkable half yourself: `xcrun stapler validate build/export/BoosterSimApp.app` and `spctl --assess --type execute -vv build/export/BoosterSimApp.app` (Gatekeeper's offline verdict on the stapled ticket). Record in the SUMMARY: ticket id, submit→accept duration, stapler validate output, spctl verdict. If the submission is REJECTED, capture notarytool's log (`xcrun notarytool log <id> --keychain-profile booster-notary`), surface the concrete rejection reason to the user, and record it — do not retry blind and do not paper over it.
  </action>
  <verify>
    <automated>xcrun stapler validate build/export/BoosterSimApp.app && spctl --assess --type execute -vv build/export/BoosterSimApp.app</automated>
    <fails_when>stapler validate reports no/invalid ticket, or spctl does not accept the stapled app</fails_when>
    <human-check>A real notarization ticket was issued for BoosterSimApp: the user ran store-credentials interactively, the submission was ACCEPTED (not rejected), and notarytool history shows the Accepted record with an id recorded in the SUMMARY.</human-check>
  </verify>
  <acceptance_criteria>
    - Ticket id + Accepted status recorded in the SUMMARY (from notarytool history)
    - stapler validate passes on the exported app; spctl accepts it offline
    - No credential material appears in the SUMMARY, scripts, or docs — only the profile name
    - If Apple rejected the submission, the rejection reason is captured verbatim and the phase does NOT claim criterion 1's notarization half
  </acceptance_criteria>
  <what-built>The complete credential-free release pipeline from Task 1 (pbxproj team switch, ExportOptions.plist, scripts/build-release.sh) plus the as-shipped deployment guide from Task 2 — this checkpoint adds the only missing link: Apple's notarization verdict on the real artifact.</what-built>
  <how-to-verify>
    1. Create the app-specific password (user_setup) if not already made
    2. Run `xcrun notarytool store-credentials booster-notary --apple-id <Apple ID> --team-id K2TYLYAWMK --password <app-specific password>` (interactive — human-owned)
    3. Run `scripts/build-release.sh` (full path — submit, wait, staple, validate)
    4. Read back the ticket: `xcrun notarytool history --keychain-profile booster-notary` → Accepted + id
    5. Machine half: `xcrun stapler validate build/export/BoosterSimApp.app` and `spctl --assess --type execute -vv build/export/BoosterSimApp.app`
  </how-to-verify>
  <resume-signal>Reply "notarized" (with the ticket id if handy) to close this plan, or paste the notarytool rejection/failure output — a rejected submission needs a diagnosis inside this phase before the release workflow (07-02) can be trusted.</resume-signal>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| Developer keychain → build script | The script triggers signing/notarization under the developer's stored identity and notary profile; it must never carry the credentials themselves |
| Apple notary service → local artifact | The accepted ticket + staple is the only trustworthy proof the artifact passed Apple's malware scan — everything else is claim, not proof |
| Exported DMG → end users | Gatekeeper verdict at first launch depends on the staple chain this plan builds |

## STRIDE Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation Plan |
|-----------|----------|-----------|----------|-------------|-----------------|
| T-07-01 | Information disclosure | scripts/build-release.sh, docs | high | mitigate | Credentials live only in the keychain profile referenced by name; script exits with instructions (never prompts, never embeds); docs use placeholder markup; SUMMARY records ticket id only |
| T-07-02 | Tampering | exported .app / DMG | high | mitigate | `codesign --verify --deep --strict` in Task 1's verify; `stapler validate` + `spctl --assess` in Task 3 — the ticket and Gatekeeper verdict are machine-checked, not assumed |
| T-07-03 | Repudiation | Phase criterion 1 closure | medium | mitigate | Blocking-human gate records ticket id + Accepted status; a rejected submission is recorded verbatim and blocks closure (the transparency prohibition) |
| T-07-04 | Elevation of privilege | hdiutil/ditto invocation | low | accept | Standard macOS tooling on local build artifacts; no network, no privileged context |
</threat_model>

<verification>
- Task 1: 8/8 team occurrences switched, zero stale-team strings, script lint + full credential-free run green, DMG exists, codesign team + deep verify pass
- Task 2: deployment-guide grep gate — runbook present, deferred framing gone, non-sandbox rationale retained, stale floor corrected
- Task 3: real ticket Accepted + stapler validate + spctl pass, recorded in the SUMMARY
</verification>

<success_criteria>
- ROADMAP C1 fully TRUE: signed + notarized + stapled + DMG, non-sandbox documented, runbook as-shipped
- Everything except the two credential moments reproducible by one command
- 07-02 (Sparkle + release workflow) unblocked with the final team ID in place
</success_criteria>

<output>
Create `.planning/phases/07-polish-distribution/07-01-signing-notarization-pipeline-SUMMARY.md` when done
</output>
