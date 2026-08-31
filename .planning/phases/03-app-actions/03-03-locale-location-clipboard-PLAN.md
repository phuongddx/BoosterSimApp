---
phase: 03-app-actions
plan: 03
type: execute
wave: 3
depends_on: ["03-02-push-deeplink-privacy"]
files_modified:
  - BoosterSimApp/Services/AppActionService.swift
  - BoosterSimApp/Views/SideWindow/actions/LocaleSectionView.swift
  - BoosterSimApp/Views/SideWindow/actions/LocationSectionView.swift
  - BoosterSimApp/Views/SideWindow/actions/ClipboardSectionView.swift
  - BoosterSimApp/Views/SideWindow/tabs/ActionsTabView.swift
  - BoosterSimAppTests/LocaleCommandTests.swift
autonomous: false
requirements:
  - REQ-roadmap-phase3-app-actions
  - REQ-fr-13
  - REQ-fr-14
user_setup:
  - service: ios-simulator
    why: "Task 3 blocking smoke needs a booted Simulator with an app that (a) can receive push notifications with permission granted (e.g. the user's Xcode app after a manual Settings grant, or Calendar), (b) localizes visibly when the language changes, and (c) reads location (Apple Maps works)"
    dashboard_config:
      - task: "Boot one Simulator; keep an installed app with push permission granted (Settings → Notifications → Allow) — Apple Calendar qualifies if notification permission was ever granted, otherwise use the Xcode-built app"
        location: "Simulator Settings → Notifications → <app> → Allow"
estimate:
  tokens: 38000
  raw_tokens: 38000
  tasks: 3
  confidence: low

must_haves:
  truths:
    - "Choosing a locale preset (or manual language/region) writes AppleLanguages + AppleLocale on the device's global defaults domain and relaunches the selected app in one chain (launch with the terminate-running-process flag), with a caption stating the effect lands on next app launch; choosing a city preset sets the simulated location immediately AND writes the matching AppleTimeZone (GPS + timezone sync in one action)"
    - "Setting coordinates runs the location set verb and Maps/Weather on the device reflect the new location; Clear stops simulation and restores real/none; a visible Stop/Clear control is paired with every active simulation (the start-style verb never runs without one)"
    - "Mac → Simulator and Simulator → Mac clipboard buttons sync the pasteboard via the pbsync verb in both directions (verified round-trip semantics), with a direction-status caption; the sync is manual-trigger only and the UI captions it as a text clipboard"
    - "Dark/light and Dynamic Type remain served by the existing EnvironmentOverridesView at the top of the Actions tab — reused, not rebuilt, and regression-free after this plan's tab edits (criterion 3 reuse items)"
    - "Empty/null inputs fail fast with typed errors, never crashes: empty or non-numeric lat/lon → typed validation error before any verb; out-of-range coordinates (|lat|>90, |lon|>180) are rejected the same way; an empty payload or selection disables the action button rather than erroring downstream"
    - "Repeated identical locale/timezone writes produce identical device state (idempotent re-apply); re-applying a location set while one is active replaces it rather than stacking"
  artifacts:
    - BoosterSimApp/Views/SideWindow/actions/LocaleSectionView.swift
    - BoosterSimApp/Views/SideWindow/actions/LocationSectionView.swift
    - BoosterSimApp/Views/SideWindow/actions/ClipboardSectionView.swift
    - BoosterSimAppTests/LocaleCommandTests.swift
  key_links:
    - "LocaleSectionView apply → AppActionService.applyLocale(languages:locale:udid:bundle:) → spawn-defaults write chain → launch-with-terminate-relaunch → status caption (takes effect on relaunch)"
    - "LocationSectionView preset → AppActionService.applyLocationPreset(city:udid:bundle:) → location set + AppleTimeZone write (+ relaunch for tz) → Maps reflects coordinates; Clear → location clear"
    - "ClipboardSectionView button → AppActionService.syncClipboard(direction:) → pbsync host/device args → direction-status caption"
    - "ActionsTabView → EnvironmentOverridesView (untouched, top of scroll) — the reuse contract for dark/light + Dynamic Type"
  prohibitions:
    - requirement_id: REQ-roadmap-phase3-app-actions
      category: privacy
      status: unverified
      flagged: true
      statement: "MUST NOT read, log, or retain clipboard contents — the pbsync buttons transfer the pasteboard between host and device; BoosterSimApp never inspects, stores, or logs what crosses, and no background auto-sync timer exists (manual triggers only)"
    - requirement_id: REQ-roadmap-phase3-app-actions
      category: safety
      status: unverified
      flagged: true
      statement: "MUST NOT leave a location simulation running without a visible Stop — every set/preset action pairs with an always-visible clear control while a simulation is active (the interpolated-route verb runs until cleared)"
    - requirement_id: REQ-roadmap-phase3-app-actions
      category: transparency
      status: unverified
      flagged: true
      statement: "MUST NOT present locale/timezone writes as instant — every control carries the takes-effect-on-relaunch caption and the write chain always performs the explicit relaunch step (a bare write looks like a no-op)"
  flagged_assumptions:
    - requirement_id: REQ-roadmap-phase3-app-actions
      probe: research-A1
      status: unresolved
      statement: "CLOSES AT TASK 3 SMOKE IF PASS: the single-call relaunch (launch with the terminate-running-process flag) is help-verified but not live-tested end-to-end — the documented fallback is the two-step terminate + launch chain; if the smoke shows the app not relaunching, switch the chain to the two-step form in this plan before approval"
    - requirement_id: REQ-roadmap-phase3-app-actions
      probe: research-A2
      status: unresolved
      statement: "CLOSES AT TASK 3 SMOKE IF PASS: location set moves CLLocation consumers immediately (help-verified mechanics, not visually confirmed) — smoke step 6 observes Maps"
    - requirement_id: REQ-roadmap-phase3-app-actions
      probe: research-A5
      status: unresolved
      statement: "Locale affects only apps launched after the write — the chain's explicit relaunch makes this deterministic for the selected app; other running apps pick it up on their next launch (community + Apple testing docs consensus)"
---

<objective>
Success criterion 3 remainder: locale/timezone switching with relaunch, location simulation with timezone sync, and bidirectional clipboard sync — plus the phase's mid-point blocking smoke covering push, location, clipboard, and locale live.

Dark/light and Dynamic Type need NO new work: they already ship in EnvironmentOverridesView at the top of the Actions tab (criterion 3 reuse items per 03-CONTEXT.md discretion) — this plan proves them regression-free and builds the three new sections below them: LocaleSectionView (preset pills + manual pickers, always captioned takes-effect-on-relaunch), LocationSectionView (validated lat/lon, city presets that set coordinates + timezone together, Clear paired with every active simulation), ClipboardSectionView (two explicit pbsync buttons, manual only).

Purpose: 03-RESEARCH.md live-verified every mechanism (AppleLanguages/AppleLocale/AppleTimeZone spawn-defaults round-trip, location set/clear, pbsync both directions) and pins the relaunch-required semantics (Pitfall 6) and the location stop pairing (Pitfall 10). The blocking smoke also proves plan 02's push/deep-link/privacy work live (house pattern: re-verify the previous plan's checkpoint path quickly instead of blocking twice).
Output: 3 new section views, one facade extension, one Wave 0 test file, one recorded blocking smoke.
</objective>

<execution_context>
@~/.claude/gsd-core/workflows/execute-plan.md
@~/.claude/gsd-core/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/ROADMAP.md
@.planning/STATE.md
@.planning/phases/03-app-actions/03-RESEARCH.md
@.planning/phases/03-app-actions/03-PATTERNS.md
@.planning/phases/03-app-actions/03-01-SUMMARY.md
@.planning/phases/03-app-actions/03-02-SUMMARY.md

Source-of-truth analogs (read before writing each file — PATTERNS.md carries near-verbatim excerpts):
@BoosterSimApp/Services/EnvironmentOverrideService.swift
@BoosterSimApp/Services/AppActionService.swift
@BoosterSimApp/Views/SideWindow/EnvironmentOverridesView.swift
@BoosterSimApp/Views/SideWindow/network/BlockRulesView.swift
@BoosterSimApp/Views/SideWindow/network/NetworkConditionsSectionView.swift
@BoosterSimAppTests/NetworkConditionServiceTests.swift
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: Locale + timezone — global-domain write chain, explicit relaunch, presets with honest captions</name>
  <files>
    BoosterSimApp/Services/AppActionService.swift,
    BoosterSimApp/Views/SideWindow/actions/LocaleSectionView.swift,
    BoosterSimApp/Views/SideWindow/tabs/ActionsTabView.swift,
    BoosterSimAppTests/LocaleCommandTests.swift
  </files>
  <read_first>
    - .planning/phases/03-app-actions/03-RESEARCH.md — Verified Surface spawn-defaults row (AppleLanguages array / AppleLocale string / AppleTimeZone write-read-delete round-trip on the global domain) and launch row (--terminate-running-process one-call relaunch); Problem Domain §3; Pitfall 6 (relaunch or it looks like a no-op); Action Latency table locale/timezone rows; Assumptions A1, A5
    - .planning/phases/03-app-actions/03-PATTERNS.md — LocaleSectionView ← EnvironmentOverridesView assignment (same service family, onAppear/onChange reload, effectiveUDID guards); the EnvironmentOverrideService multi-write chain (lines 160-186 style) and write→notifyutil chain (lines 269-278) as the chain template
    - BoosterSimApp/Services/EnvironmentOverrideService.swift lines 89-103 (typed defaults reads publishing state), 159-187 (3-write chain), 269-278 (write → flatMap second hop)
    - BoosterSimApp/Views/SideWindow/EnvironmentOverridesView.swift lines 15-16 (effectiveUDID/isDisabled guards), 28-73 (grouped controls), onAppear/onChange reload block
    - The plan-02 version of AppActionService.swift and ActionsTabView.swift
    - BoosterSimAppTests/NetworkConditionServiceTests.swift (suite style for the command tests)
  </read_first>
  <behavior>
    - LocaleCommandTests: language write args are exactly [spawn, udid, defaults, write, <global domain token>, AppleLanguages, -array, en-US, …] — the global-domain token is a single named constant the tests pin
    - LocaleCommandTests: locale and timezone writes use -string with the exact key spellings AppleLocale / AppleTimeZone; restore-to-unset uses the delete verb
    - LocaleCommandTests: relaunch args are [launch, udid, bundle, --terminate-running-process]; the fallback two-step builder composes terminate-then-launch for the same bundle
    - LocaleCommandTests: preset model — each preset expands to (languages array, locale string, timezone string) deterministically; applying the same preset twice produces identical arg sequences (idempotent re-apply)
    - LocaleCommandTests: current-state read args for the three keys round-trip through the parser (trimmed string / array joined) — pure parse function over fixture output
  </behavior>
  <action>
    Write LocaleCommandTests.swift FIRST (red), then:

    BoosterSimApp/Services/AppActionService.swift (modify): add pure, internal, unit-tested builders — languageArgs/localeArgs/timezoneArgs/deleteKeyArgs/relaunchArgs/fallbackRelaunchArgs — against a single global-domain constant (the research-verified global domain; if the primary token misbehaves at the smoke, the documented equivalent spelling is the fallback — note it in the summary, do not fork both). applyLocale(languages:locale:udid:bundle:) = the EnvironmentOverrideService chain shape: write AppleLanguages (-array) → flatMap write AppleLocale → flatMap relaunch (launch with the terminate-running-process flag; flagged assumption A1 — fallback two-step builder already unit-tested if needed) → finish with the honest takes-effect-on-relaunch caption. setTimezone(tz:udid:bundle:) = write → relaunch chain. readLocaleState(udid:) publishes current AppleLanguages/AppleLocale/AppleTimeZone via three typed defaults reads (EnvironmentOverrideService lines 89-103 pattern). Log verbs + outcomes only.

    BoosterSimApp/Views/SideWindow/actions/LocaleSectionView.swift (new): CollapsibleSection(title: "Locale & Region", icon: "globe", …) in the EnvironmentOverridesView control idiom: preset pills (at minimum English/US, English/UK, Vietnamese/VN, Japanese/JP — each pill = languages + locale + optional timezone triple), manual rows (language, locale, timezone) for custom values, Apply button disabled without booted device/active bundle. EVERY write surface carries the caption "Takes effect on next app launch — the app is relaunched automatically" (Pitfall 6 — never present these as instant, prohibition). onAppear/onChange(of: udid) reload current state through readLocaleState and display it. Tokens only; Reduce Motion animation helper.
  </action>
  <verify>
    <automated>xcodebuild -project BoosterSimApp.xcodeproj -scheme BoosterSimApp -destination 'platform=macOS' test -only-testing:BoosterSimAppTests/LocaleCommandTests -parallel-testing-enabled NO</automated>
  </verify>
  <acceptance_criteria>
    - LocaleCommandTests.swift exists, imports Testing, and pins every behavior bullet (exact argv forms incl. the -array language write and the relaunch flag, fallback two-step, preset determinism/idempotency, read parsing)
    - AppActionService locale chains end in the relaunch hop (grep: the chain's last verb is the launch form with the terminate flag) and log no key VALUES beyond verb/outcome
    - LocaleSectionView.swift renders the takes-effect-on-relaunch caption adjacent to every apply control and reloads current state on appear/udid-change
    - The section uses design tokens only (no bare-integer padding/cornerRadius literals outside comments)
    - The test command exits 0
  </acceptance_criteria>
  <reversibility rating="reversible">Additive verbs + one section view; device-side global-domain writes are user-visible but restorable (delete-verb restore is unit-tested).</reversibility>
  <done>Locale/timezone switch with explicit relaunch and honest captions; LocaleCommandTests green; presets deterministic.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: Location simulation (validated coords + city presets with timezone sync + paired Stop) and bidirectional clipboard sync</name>
  <files>
    BoosterSimApp/Services/AppActionService.swift,
    BoosterSimApp/Views/SideWindow/actions/LocationSectionView.swift,
    BoosterSimApp/Views/SideWindow/actions/ClipboardSectionView.swift,
    BoosterSimApp/Views/SideWindow/tabs/ActionsTabView.swift
  </files>
  <read_first>
    - .planning/phases/03-app-actions/03-RESEARCH.md — Verified Surface location row (set lat,lon / clear / list / waypoint start with speed/distance/interval flags), pbsync row (both directions round-trip verified, -p promise flag), Problem Domain §4 + Open Question 4 (city presets setting both location and timezone), Pitfall 10 (pair every start with a visible stop), Assumption A4 (text clipboard caption)
    - .planning/phases/03-app-actions/03-PATTERNS.md — LocationSectionView ← BlockRulesView validated add-row + captions; ClipboardSectionView ← NetworkConditionsSectionView shell + animation helper
    - BoosterSimApp/Views/SideWindow/network/BlockRulesView.swift lines 16-18 (animation helper), 101-104 (validated TextField row), 147-151 (cap/empty captions)
    - BoosterSimApp/Views/SideWindow/network/NetworkConditionsSectionView.swift lines 4-20 (section shell) and 139-143 (scope caption)
    - The Task 1 versions of AppActionService.swift and ActionsTabView.swift
  </read_first>
  <behavior>
    - Location coordinate validation is a pure function: ("35.6762","139.6503") builds ["location", udid, "set", "35.6762,139.6503"]; empty, non-numeric, and out-of-range inputs (|lat| > 90, |lon| > 180) return typed errors and build NO args
    - City presets expand deterministically to (name, lat, lon, timezone) — applying a preset composes the location-set args AND the timezone-write args; re-applying produces identical sequences
    - Clear composes ["location", udid, "clear"]; the service tracks an active-simulation flag set by set/preset and cleared by clear (Stop visibility driver)
    - Clipboard args are exactly ["pbsync", "host", udid] (Mac → device) and ["pbsync", udid, "host"] (device → Mac); the direction enum maps to exactly these two forms
  </behavior>
  <action>
    Unit-test the pure builders inside LocaleCommandTests' sibling — add the location/clipboard builder cases as a new MARK group in LocaleCommandTests.swift or a small extension of it (keep test-file count aligned with 03-VALIDATION; the builders live as internal statics on AppActionService). Then:

    BoosterSimApp/Services/AppActionService.swift (modify): add setLocation(lat:lon:udid:) (validate → set → publish active-simulation flag), clearLocation(udid:) (clear → clear flag), applyLocationPreset(preset:udid:bundle:) (set + timezone write, relaunch optional-but-captioned per Task 1's chain reuse), syncClipboard(direction:) for the two pbsync forms with a direction-status caption. Publish hasSimulatedLocation so the Stop control is state-driven, not guesswork. Log verbs only — clipboard CONTENT is never logged (prohibition).

    BoosterSimApp/Views/SideWindow/actions/LocationSectionView.swift (new): CollapsibleSection(title: "Location", icon: "location", …): validated lat/lon TextFields (BlockRulesView add-row anatomy — typed error caption for invalid/out-of-range input BEFORE any verb), Set + Clear buttons where Clear is prominent whenever hasSimulatedLocation is true (Pitfall 10 pairing — the stop is always visible while a simulation is active), city preset pills (at minimum San Francisco, New York, London, Tokyo, Singapore, Sydney with correct lat/lon/timezone triples) each setting location + timezone in one action with the relaunch caption for the timezone half, and the honest scope caption (device-wide simulation, applies to CoreLocation consumers). No waypoint-route UI this phase (route flags documented as available; keep the UI minimal per research tradeoff).

    BoosterSimApp/Views/SideWindow/actions/ClipboardSectionView.swift (new): CollapsibleSection(title: "Clipboard", icon: "doc.on.doc", …) with exactly two explicit buttons — "Mac → Simulator" and "Simulator → Mac" — a direction-status caption after each run, the honest "text clipboard" caption (A4: rich types untested), and NO auto-sync timer of any kind (prohibition — manual triggers only; research rejected background polling).

    BoosterSimApp/Views/SideWindow/tabs/ActionsTabView.swift (modify): mount LocaleSectionView, LocationSectionView, ClipboardSectionView after the privacy section, below the untouched EnvironmentOverridesView (the reuse contract).
  </action>
  <verify>
    <automated>xcodebuild -project BoosterSimApp.xcodeproj -scheme BoosterSimApp -destination 'platform=macOS' test -only-testing:BoosterSimAppTests/LocaleCommandTests -parallel-testing-enabled NO && xcodebuild -project BoosterSimApp.xcodeproj -scheme BoosterSimApp -configuration Debug build</automated>
  </verify>
  <acceptance_criteria>
    - The location/clipboard builder tests cover the behavior bullets (valid/empty/non-numeric/out-of-range, preset determinism, clear args, both pbsync directions) and are green
    - LocationSectionView.swift shows the Clear control whenever hasSimulatedLocation is true (state-driven Stop) and rejects invalid input inline before any verb
    - City presets set BOTH location and timezone (grep: preset apply path references the timezone write from Task 1)
    - ClipboardSectionView.swift contains exactly two sync buttons and zero timer/scheduler tokens (no auto-sync)
    - ActionsTabView still renders EnvironmentOverridesView first, untouched; the three new sections mount below
    - Both xcodebuild commands exit 0
  </acceptance_criteria>
  <reversibility rating="reversible">Additive sections + verbs; location clears and clipboard syncs leave no persistent state.</reversibility>
  <done>Criterion 3 complete: locale/timezone with relaunch, location with paired Stop and tz-syncing presets, clipboard both directions — plus regression-free reuse of appearance/Dynamic Type.</done>
</task>

<task type="checkpoint:human-verify" gate="blocking-human">
  <name>Task 3: Push/location/clipboard smoke — guided grant live, Maps moves, pasteboards round-trip, locale relaunch, reuse regression</name>
  <files>none</files>
  <read_first>
    - .planning/phases/03-app-actions/03-VALIDATION.md — Manual-Only Verifications rows: push banner + tap-through, push permission guided grant, location in Maps, clipboard both directions, locale/appearance/DTC take effect
    - .planning/phases/03-app-actions/03-RESEARCH.md — Pitfalls 1, 6, 10; Assumptions A1 (relaunch), A2 (location immediacy), A4 (text clipboard), A5 (newly-launched apps only)
    - .planning/phases/03-app-actions/03-02-SUMMARY.md (what plan 02 actually shipped — smoke steps 1-4 re-verify it)
  </read_first>
  <action>
    Blocking human checkpoint — live proof of criterion 3 and plan 02's criterion-2 surface. Prerequisites (user_setup): booted Simulator with an app holding granted notification permission and visible localization; Apple Maps available. Execute the nine steps in how-to-verify, recording per-step pass/fail. Steps 4-5 close flagged assumptions A1 (one-call relaunch — if the app does not relaunch, apply the unit-tested two-step fallback INSIDE this plan before approval) and A2 (Maps moves). Step 1 is the D-01 proof: the permission control must guide, never claim to toggle.
  </action>
  <verify>
    <human-check>All nine smoke steps observed and recorded pass/fail in the summary; specifically: the D-01 guided grant flow works end-to-end (caption + Settings launch + probe banner), Maps reflects set/cleared coordinates, the clipboard round-trips both directions, the locale switch relaunches and localizes, and dark/Dynamic Type toggles still apply instantly.</human-check>
  </verify>
  <acceptance_criteria>
    - Summary contains a per-step pass/fail record for all 9 smoke steps
    - D-01 guided grant passes: deny → caption + Open Settings → manual grant → test push banner arrives and taps through (steps 1-2)
    - Push payload validation gates hold live: over-cap payload rejected inline, template sends succeed (step 3)
    - Privacy grant/revoke on a service works and the terminate-warning caption is visible; deep link still opens after the migration (step 4)
    - Locale preset relaunches and localizes the app (A1 closes); timezone moves with the city preset (step 5)
    - Maps follows set coordinates and Clear restores (A2 closes); Stop/Clear visible while active (step 6)
    - Clipboard round-trips Mac→Sim and Sim→Mac (step 7); dark mode + Dynamic Type still instant via the existing section (step 8); repeated locale apply is stable, no crash on empty inputs (step 9)
  </acceptance_criteria>
  <what-built>Criterion 3 delivered and criterion 2 proven live: LocaleSectionView (presets + manual, relaunch-captioned writes), LocationSectionView (validated coords, tz-syncing city presets, state-driven Stop), ClipboardSectionView (two manual pbsync buttons) on the AppActionService facade; push/deep-link/privacy from plan 02 verified on-device; EnvironmentOverridesView reuse regression-free.</what-built>
  <how-to-verify>
    With BoosterSimApp running and the prepared booted Simulator:
    1. D-01 GUIDED GRANT — in the Push section with permission DENIED: the control shows the honest cannot-set caption; click Open Settings → the device Settings app opens; navigate Notifications → <app> → Allow
    2. Back in BoosterSimApp: Send Test Push with the alert template — the banner arrives and taps through to the app
    3. Paste a >4096-byte payload — rejected inline with the size error, no send; a template payload sends again fine
    4. PRIVACY + DEEP LINK — grant then revoke a service (e.g. photos) for the active app; the terminate warning caption is visible; a preset deep link still opens in the Simulator
    5. LOCALE — apply the Japanese preset on a localizable app → the app relaunches (A1) and localizes; apply the Tokyo city preset → timezone changes with it; restore the original locale preset afterward
    6. LOCATION — set Tokyo coordinates manually → Maps/Weather reflect them (A2); Clear restores; the Clear control is visible the whole time a simulation is active
    7. CLIPBOARD — copy text on the Mac → Mac → Simulator → paste into a device text field shows it; copy different text on the device → Simulator → Mac → paste on the Mac shows it
    8. REUSE REGRESSION — toggle Dark Mode and change Dynamic Type in the existing Environment section — both apply instantly, no relaunch
    9. IDEMPOTENCY + EMPTY INPUTS — re-apply the same locale preset (stable, no error); clear the lat/lon fields and click Set (typed inline error, nothing sent); with the Simulator shut down, all sections show degraded/disabled states, no crash
  </how-to-verify>
  <resume-signal>Reply "approved" to unblock wave 4 (plan 04 defaults editor + search), or describe the failing step — a failed relaunch requires switching to the unit-tested two-step fallback in this plan; a fake-looking permission toggle or a missing Stop is a prohibition violation and blocks approval.</resume-signal>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| Mac pasteboard ↔ Simulator pasteboard | Real user clipboard content crosses host/device during pbsync |
| BoosterSimApp → device global state | Global-domain defaults writes (locale/timezone) and location simulation affect EVERY app on the device |
| Free-text lat/lon input → simctl argv | User-typed coordinates cross into argv |

## STRIDE Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation Plan |
|-----------|----------|-----------|----------|-------------|-----------------|
| T-03-08 | Information Disclosure | Clipboard content exposure via logs/retention/auto-sync | high | mitigate | Two explicit manual buttons only — no timer, no polling, no content logging (prohibition); direction-status captions carry no content; research rejected background sync as privacy-hostile and flaky |
| T-03-09 | Tampering | Device-global locale/timezone/location writes surprise other apps | medium | mitigate | Honest scope captions (device-wide, takes-effect-on-relaunch); restore paths (delete-verb, Clear) unit-tested; Apple's own Simulator Settings behave identically |
| T-03-13 | DoS/Tampering | Malformed coordinate text reaching argv | low | mitigate | Pure validation (numeric + range) builds NO args on invalid input — typed inline errors; argv-only invocation, no shell |
| T-03-SC | Tampering | Package installs | high | mitigate | Zero package installs this plan — Apple frameworks only; asserted at the phase gate (plan 05) |
</threat_model>

<verification>
- Task 1/2 automated: LocaleCommandTests (incl. location/clipboard builder groups) green; Debug build proves section mounts compile.
- Task 3: blocking human smoke (9 steps) — live proof of criterion 3, plan 02's push/privacy/deep-link surface, the D-01 guided grant, and the reuse regression check; closes flagged assumptions A1/A2.
- No SPM/pbxproj package changes this plan.
</verification>

<success_criteria>
- The 6 must_haves truths hold; the live smoke proves the guided grant (D-01), Maps movement, clipboard round-trip, locale relaunch + localization, and instant appearance/Dynamic Type reuse.
- LocaleCommandTests green; app builds; all three sections mounted below the untouched EnvironmentOverridesView.
- Idempotent re-apply and typed empty-input errors observed (smoke step 9).
</success_criteria>

## Artifacts this phase produces

Created by THIS plan (new symbols):
- LocaleSectionView, LocationSectionView, ClipboardSectionView — BoosterSimApp/Views/SideWindow/actions/
- AppActionService locale/timezone/location/clipboard verbs + pure command builders (languageArgs, relaunchArgs, locationSet/clear, pbsync directions, coordinate validation)
- Tests: LocaleCommandTests (locale/timezone/relaunch + location/clipboard builders)

Modified: AppActionService (verb set completed for criterion 3), ActionsTabView (three new sections below the untouched environment section).

Later plans add: AppAction catalog + ActionSearchBar + DefaultsEntry + UserDefaultsEditorService + editor view (04), docs + phase gate (05).

<output>
Create `.planning/phases/03-app-actions/03-03-SUMMARY.md` when done
</output>
