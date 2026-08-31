---
phase: 03-app-actions
plan: 04
type: execute
wave: 4
depends_on: ["03-03-locale-location-clipboard"]
files_modified:
  - BoosterSimApp/Models/DefaultsEntry.swift
  - BoosterSimApp/Services/UserDefaultsEditorService.swift
  - BoosterSimApp/Views/SideWindow/actions/UserDefaultsEditorView.swift
  - BoosterSimApp/Views/SideWindow/tabs/ActionsTabView.swift
  - BoosterSimApp/App/AppDelegate.swift
  - BoosterSimApp/Views/SideWindow/SideWindowView.swift
  - BoosterSimApp/Models/AppAction.swift
  - BoosterSimApp/Views/SideWindow/actions/ActionSearchBar.swift
  - BoosterSimAppTests/UserDefaultsEditorServiceTests.swift
  - BoosterSimAppTests/AppActionCatalogTests.swift
autonomous: true
requirements:
  - REQ-roadmap-phase3-app-actions
  - REQ-fr-13
estimate:
  tokens: 40000
  raw_tokens: 40000
  tasks: 2
  confidence: low

must_haves:
  truths:
    - "The Defaults section lists the active app's UserDefaults as typed entries (string/int/bool/array/JSON capsule per row) read from the app's on-disk Preferences plist via its data container; editing a value writes through the spawn-defaults typed verb and the list reflects the new value after reload; adding a key requires choosing a type; deleting removes the key — repeated identical typed writes produce identical plist state (idempotent), and an empty plist renders an empty list, not an error"
    - "The Actions tab quick search filters every section (environment, deep links, reset, push, privacy, locale, location, clipboard, defaults) through the pure catalog: empty query shows the full tab in fixed section order; a query narrows to matching sections; equal-keyword matches never shuffle between queries (deterministic stable ranking); no-match renders an honest empty result, never a blank tab"
    - "Key and domain names are validated (allowlist characters) before any argv is built; invalid input produces a typed inline error and no subprocess"
    - "The editor targets the active app's domain from the picker; the section captions that writes land via cfprefsd and that launch-time keys need an app relaunch"
    - "UserDefaults values are never logged — logs carry domain and key names only"
  artifacts:
    - BoosterSimApp/Models/DefaultsEntry.swift
    - BoosterSimApp/Services/UserDefaultsEditorService.swift
    - BoosterSimApp/Views/SideWindow/actions/UserDefaultsEditorView.swift
    - BoosterSimApp/Models/AppAction.swift
    - BoosterSimApp/Views/SideWindow/actions/ActionSearchBar.swift
    - BoosterSimAppTests/UserDefaultsEditorServiceTests.swift
    - BoosterSimAppTests/AppActionCatalogTests.swift
  key_links:
    - "UserDefaultsEditorView row edit → UserDefaultsEditorService.write(entry) → validated spawn-defaults write args → simCtl.run → loadDomain reload (plist file re-read) → @Published entries"
    - "loadDomain(udid:bundle:) → get_app_container data → <container>/Library/Preferences/<bundle>.plist → NSDictionary(contentsOf:) → [DefaultsEntry] (NEVER the plist-export verb — silently unsupported, RESEARCH Pitfall 5)"
    - "ActionSearchBar query binding → AppActionCatalog.filter(query:) → ActionsTabView section visibility in catalog order → sections render only when matched (empty query = all)"
    - "AppDelegate lazy var userDefaultsEditorService = UserDefaultsEditorService(simCtl:) → SideWindowView .environmentObject → ActionsTabView/UserDefaultsEditorView"
  prohibitions:
    - requirement_id: REQ-roadmap-phase3-app-actions
      category: privacy
      status: unverified
      flagged: true
      statement: "MUST NOT log UserDefaults values — domains and key names only in AppLogger.actions output (values can be auth tokens; extends the house never-log-sensitive-data rule to the editor)"
    - requirement_id: REQ-roadmap-phase3-app-actions
      category: values
      status: unverified
      flagged: true
      statement: "MUST NOT write defaults outside the user-selected target domain — no cross-app preference mutation beyond the explicit editor action on the picked app and the documented scoped keys (ShowSingleTouches, AppleLanguages/AppleLocale/AppleTimeZone)"
    - requirement_id: REQ-roadmap-phase3-app-actions
      category: transparency
      status: unverified
      flagged: true
      statement: "MUST NOT build the editor on the plist-export verb — it silently does nothing in the simulator (empty output, exit 0); reads come from the on-disk Preferences plist file, writes from typed spawn-defaults verbs (RESEARCH Pitfall 5)"
  flagged_assumptions:
    - requirement_id: REQ-roadmap-phase3-app-actions
      probe: research-OQ3
      status: resolved
      statement: "Editor scope ships as the active app's domain only (research Open Question 3 recommends active-app default with an OPTIONAL all-domains toggle — the optional half is intentionally not built; ~238 device domains would swamp the 260pt panel; revisit as a v2 candidate, not a phase gap)"
---

<objective>
Success criterion 4 completion: the UserDefaults editor for the active app and the quick search over the whole Actions tab.

Two expansions on the proven slice: (1) DefaultsEntry (typed value wrapper) + UserDefaultsEditorService (on-disk plist read through the app's data container, typed spawn-defaults writes/deletes with validated keys) + UserDefaultsEditorView (searchable key list, edit/add/delete with type picker, honest captions); (2) the pure AppActionCatalog (id/title/keywords/section/effect-latency in fixed order) + ActionSearchBar (TrafficFilterBar analog, clear-on-collapse) driving section visibility across the entire Actions tab — the long-list filter the roadmap requires.

Purpose: 03-RESEARCH.md verified typed defaults round-trips land instantly in data/Library/Preferences/<domain>.plist, proved the plist-export verb silently does nothing in the simulator (Pitfall 5 — the trap this plan forbids), and pinned the search as a pure filter struct (TrafficFilter precedent) rather than view-body filtering. Bundle-ID detection from DerivedData already landed in plan 01's scanner + picker — this plan consumes it.
Output: 5 new files, 3 modified files, 2 Wave 0 Swift Testing files; live editor behavior proven in plan 05's phase-gate smoke.
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
@.planning/phases/03-app-actions/03-03-SUMMARY.md

Source-of-truth analogs (read before writing each file — PATTERNS.md carries near-verbatim excerpts):
@BoosterSimApp/Services/EnvironmentOverrideService.swift
@BoosterSimApp/Services/CertificateService.swift
@BoosterSimApp/Models/AppSettings.swift
@BoosterSimApp/Views/SideWindow/network/BlockRulesView.swift
@BoosterSimApp/Views/SideWindow/network/TrafficFilterBar.swift
@BoosterSimApp/Views/SideWindow/network/NetworkEventModel.swift
@BoosterSimAppTests/NetworkConditionServiceTests.swift
@BoosterSimAppTests/ConditionVerdictTests.swift
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: UserDefaults editor — typed model, plist-file read + spawn-write service, editor UI</name>
  <files>
    BoosterSimApp/Models/DefaultsEntry.swift,
    BoosterSimApp/Services/UserDefaultsEditorService.swift,
    BoosterSimApp/Views/SideWindow/actions/UserDefaultsEditorView.swift,
    BoosterSimApp/Views/SideWindow/tabs/ActionsTabView.swift,
    BoosterSimApp/App/AppDelegate.swift,
    BoosterSimApp/Views/SideWindow/SideWindowView.swift,
    BoosterSimAppTests/UserDefaultsEditorServiceTests.swift
  </files>
  <read_first>
    - .planning/phases/03-app-actions/03-RESEARCH.md — Verified Surface spawn-defaults row (typed writes land instantly in data/Library/Preferences/<domain>.plist) and get_app_container row; the plist-export row (silently unsupported — empty output, exit 0; never build on it); Problem Domain §6; Don't Hand-Roll key/value row; Security Domain V5 (domain/key allowlist before argv) + log-secrets row; Assumption-adjacent OQ3 scope decision (active-app domain only)
    - .planning/phases/03-app-actions/03-PATTERNS.md — DefaultsEntry ← CertificateStatus associated-value style; UserDefaultsEditorService ← EnvironmentOverrideService (spawn-defaults home turf; drift guard: never the export verb, never logged values); UserDefaultsEditorView ← BlockRulesView row anatomy (capsule + toggle + trash + a11y labels, add-row, empty captions); UserDefaultsEditorServiceTests ← NetworkConditionServiceTests isolated-suite + fixture style
    - BoosterSimApp/Services/EnvironmentOverrideService.swift lines 89-103 + 269-278 (the repo's spawn-defaults read/write shapes)
    - BoosterSimApp/Services/CertificateService.swift lines 14-37 (service shell + runSimCtl timeout helper — reuse the same shape)
    - BoosterSimApp/Views/SideWindow/network/BlockRulesView.swift lines 30-34 (empty caption), 48-84 (row anatomy), 101-151 (add-row + captions)
    - The plan-03 versions of ActionsTabView.swift and AppActionService.swift (active bundle source); BoosterSimApp/App/AppDelegate.swift lazy block; BoosterSimApp/Views/SideWindow/SideWindowView.swift injection chain
    - AGENTS.md GitNexus section — gitnexus_impact not required (all-new files) but run gitnexus_detect_changes before the commit per house self-check
  </read_first>
  <behavior>
    - UserDefaultsEditorServiceTests: a fixture plist (test-bundle resource with string/int/bool/string-array/data keys) parses to typed [DefaultsEntry] with correct kinds; a missing plist yields an empty list, not an error; entries sort stably by key
    - UserDefaultsEditorServiceTests: write args per kind are exact — ["spawn", udid, "defaults", "write", domain, key, "-string", v] / "-int" / "-bool YES|NO" / "-array" spread; delete args are ["spawn", udid, "defaults", "delete", domain, key]
    - UserDefaultsEditorServiceTests: key/domain validation — names outside the allowlist character set (letters, digits, dot, underscore, hyphen) return a typed validation error and build NO args; the empty string is invalid
    - UserDefaultsEditorServiceTests: the container-path builder composes get_app_container output + Library/Preferences/<domain>.plist exactly (pure function over the container string)
    - UserDefaultsEditorServiceTests: array/JSON values round-trip through the typed wrapper without value loss (Equatable)
  </behavior>
  <action>
    Write UserDefaultsEditorServiceTests.swift FIRST (red), then:

    BoosterSimApp/Models/DefaultsEntry.swift (new): enum DefaultsEntryValue: Equatable { string, int, bool, array([String]), json(Data) } + struct DefaultsEntry: Identifiable, Equatable (key, value, computed typeLabel for the row capsule) in the CertificateStatus associated-value style. Pure computed var simctlTypeArg: [String] producing the typed flag + serialized value per kind (unit-tested arg builder — the service never string-builds inline).

    BoosterSimApp/Services/UserDefaultsEditorService.swift (new): @MainActor final class UserDefaultsEditorService: ObservableObject, init(simCtl: SimCtlService), @Published entries/[loadError]/operation in the CertificateService shell. loadDomain(udid:bundle:): resolve the data container via simCtl.run(["get_app_container", udid, bundle, "data"]) then read <container>/Library/Preferences/<bundle>.plist with NSDictionary(contentsOf:) mapping to [DefaultsEntry] — NEVER by parsing the output of the plist-export verb (silently unsupported in the simulator — RESEARCH Pitfall 5; prohibition). write(entry:udid:bundle:) / delete(key:) build validated spawn-defaults args (allowlist characters for domain AND key — typed error, no subprocess on violation) then reload the domain after the verb lands. The container-path composition and arg builders are internal static/pure for the tests. Log domain + key names ONLY — values never reach AppLogger (prohibition). Combine-only chains.

    BoosterSimApp/Views/SideWindow/actions/UserDefaultsEditorView.swift (new): CollapsibleSection(title: "Defaults", icon: "gearshape", …): searchable key list (local as-you-type filter with an honest empty state), rows in the BlockRulesView anatomy (key + typed-value capsule + edit/delete with a11y labels), add-row (key field + type picker + value field), edit sheet/inline row writing ONLY through the service, reload button, and two captions: writes land via cfprefsd, and launch-time keys need an app relaunch to take effect. Disabled state without active bundle/device. Tokens only; no value text in any status caption beyond the edited key name.

    Wiring: AppDelegate gains lazy var userDefaultsEditorService = UserDefaultsEditorService(simCtl: simCtlService); SideWindowView injects it into the .environmentObject chain; ActionsTabView mounts UserDefaultsEditorView after the clipboard section (final mount order fixed by Task 2's catalog).
  </action>
  <verify>
    <automated>xcodebuild -project BoosterSimApp.xcodeproj -scheme BoosterSimApp -destination 'platform=macOS' test -only-testing:BoosterSimAppTests/UserDefaultsEditorServiceTests -parallel-testing-enabled NO && xcodebuild -project BoosterSimApp.xcodeproj -scheme BoosterSimApp -configuration Debug build</automated>
  </verify>
  <acceptance_criteria>
    - UserDefaultsEditorServiceTests.swift exists, imports Testing, and covers every behavior bullet (typed fixture parse, missing-plist empty list, exact write/delete argv per kind, allowlist rejection with zero args built, container-path composition, value round-trip)
    - UserDefaultsEditorService.swift reads the Preferences plist FILE (NSDictionary/PropertyListSerialization); the two-word export subcommand token ("defaults" + "export" adjacent) occurs zero times in the file
    - The service's logging lines reference domain/key names only — no value interpolation into any log call (grep the file for log statements: values absent)
    - Domain and key names pass allowlist validation before any argv is built (typed error path unit-tested)
    - UserDefaultsEditorView.swift performs writes/deletes exclusively through the service — the standard defaults singleton token occurs zero times in the view file
    - Both xcodebuild commands exit 0
  </acceptance_criteria>
  <reversibility rating="costly">The editor writes real app preferences — a bad write corrupts a dev iteration's state; validation + typed verbs mitigate, but the surface is inherently mutating.</reversibility>
  <done>The active app's defaults are viewable/editable/addable/deletable as typed entries through validated verbs; UserDefaultsEditorServiceTests green; app builds with full wiring.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: AppActionCatalog + ActionSearchBar — quick search over the whole Actions tab</name>
  <files>
    BoosterSimApp/Models/AppAction.swift,
    BoosterSimApp/Views/SideWindow/actions/ActionSearchBar.swift,
    BoosterSimApp/Views/SideWindow/tabs/ActionsTabView.swift,
    BoosterSimAppTests/AppActionCatalogTests.swift
  </files>
  <read_first>
    - .planning/phases/03-app-actions/03-RESEARCH.md — Recommended Approach (searchable pure AppActionCatalog, TrafficFilterBar analog); Don't Hand-Roll search row (pure filter, one behavior); Action Latency & Effect Table (the EffectLatency data source — instant/relaunch/deviceWide per action)
    - .planning/phases/03-app-actions/03-PATTERNS.md — AppAction ← TrafficFilter (NetworkEventModel.swift lines 45-62) exact assignment with drift guard (never filter in the view body); ActionSearchBar ← TrafficFilterBar lines 4-62 (declaration shape, magnifyingglass toggle, clear-on-collapse, compactRowHeight); AppActionCatalogTests ← ConditionVerdictTests/BlockRuleTests pure-matcher contract
    - BoosterSimApp/Views/SideWindow/network/NetworkEventModel.swift lines 45-62 (TrafficFilter.matches — the pure-filter shape to mirror)
    - BoosterSimApp/Views/SideWindow/network/TrafficFilterBar.swift (whole file — toggle + clear-on-hide behavior to preserve)
    - BoosterSimApp/Views/SideWindow/network/NetworkTabView.swift lines 19-20 (house wiring: view filters through the pure struct, never ad hoc)
    - The Task 1 version of ActionsTabView.swift (current full section inventory — the catalog must cover every section incl. defaults and the pre-existing environment/deep-link sections)
  </read_first>
  <behavior>
    - AppActionCatalogTests: keyword hit — a query matching a title or keyword returns that action's section; case-insensitive matching
    - AppActionCatalogTests: empty query returns the complete catalog in the fixed section order; sections never reorder between differing non-empty queries (deterministic stable ranking — equal-relevance matches keep catalog order)
    - AppActionCatalogTests: no-match returns an empty result (rendered as an honest empty state, never a crash/blank tab)
    - AppActionCatalogTests: the catalog covers every section the Actions tab renders (environment overrides, deep links, app reset, push, privacy, locale, location, clipboard, defaults) — one test enumerates sections against the tab's section list
    - AppActionCatalogTests: every entry's effectLatency is one of the three cases and matches the research Action Latency table (locale/timezone = relaunch, keychain = deviceWide, the rest = instant)
  </behavior>
  <action>
    Write AppActionCatalogTests.swift FIRST (red), then:

    BoosterSimApp/Models/AppAction.swift (new): struct AppAction: Identifiable, Sendable (id, title, keywords, section, effectLatency) + enum EffectLatency { instant, relaunch, deviceWide } + caseless enum AppActionCatalog with static let all: [AppAction] in FIXED section order covering every Actions-tab capability above (the pre-existing environment + deep-link sections included — reuse entries, per CONTEXT.md discretion) and static func filter(_ actions: [AppAction] = all, query: String) -> [AppAction] — lowercased contains over title + keywords + section, empty query returns all, order always the catalog order (TrafficFilter.matches discipline; views NEVER filter ad hoc).

    BoosterSimApp/Views/SideWindow/actions/ActionSearchBar.swift (new): the TrafficFilterBar search anatomy — magnifyingglass toggle button, TextField bound to the query with clear-on-collapse (collapsing search resets the query so a hidden filter never silently narrows the tab), compactRowHeight, tokens only, a11y labels.

    BoosterSimApp/Views/SideWindow/tabs/ActionsTabView.swift (modify): hold @State query; render ActionSearchBar pinned at the top of the scroll (above/with AppPickerBar); compute the visible-section set through AppActionCatalog.filter(query:) — non-empty query renders only matching sections in catalog order with a small matched-actions disclosure; empty query renders the full tab exactly as before; no-match renders the honest empty-state caption. Section mount order is now the catalog's fixed order (picker stays pinned regardless). The per-section filtering decision goes through the pure catalog — zero contains-chains in the view body.
  </action>
  <verify>
    <automated>xcodebuild -project BoosterSimApp.xcodeproj -scheme BoosterSimApp -destination 'platform=macOS' test -only-testing:BoosterSimAppTests/AppActionCatalogTests -only-testing:BoosterSimAppTests/UserDefaultsEditorServiceTests -parallel-testing-enabled NO</automated>
  </verify>
  <acceptance_criteria>
    - AppActionCatalogTests.swift exists, imports Testing, and covers every behavior bullet (keyword/case-insensitivity, empty-query completeness + fixed order, no-match empty, section coverage, latency mapping)
    - AppAction.swift declares the pure catalog with the static filter; ActionsTabView.swift contains no ad hoc contains-based section filtering (grep: filtering routes through AppActionCatalog)
    - ActionSearchBar.swift clears the query when search collapses (clear-on-hide preserved)
    - With an empty query the tab renders every section exactly as plan 03 left it (no section lost to the search wiring)
    - The test command exits 0
  </acceptance_criteria>
  <reversibility rating="reversible">Additive model + bar + view wiring; the catalog is pure data and trivially editable.</reversibility>
  <done>Success criterion 4 complete: defaults editor live for the active app and quick search filtering the whole tab deterministically; both Wave 0 test files green.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| App preference store → editor UI | Another app's persisted state (potentially auth tokens) is read and mutated |
| Free-text key/domain input → simctl argv | User-typed identifiers cross into argv |
| On-disk plist file → app memory | Device filesystem content is parsed (plist) |

## STRIDE Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation Plan |
|-----------|----------|-----------|----------|-------------|-----------------|
| T-03-10 | Information Disclosure | Defaults values (auth tokens) leaked via logs | high | mitigate | AppLogger.actions carries domain + key names only — value interpolation into log calls is prohibited and grep-checked; result captions show key names, not values |
| T-03-11 | Tampering | Key/domain strings injecting into argv | medium | mitigate | Allowlist character validation (letters/digits/dot/underscore/hyphen) BEFORE argv construction — typed error, no subprocess on violation; argv-only invocation, never shell (ASVS V5) |
| T-03-14 | Tampering | Cross-app preference mutation beyond the selected domain | medium | mitigate | Writes carry the picker-selected bundle domain only; no global-domain writes in the editor (prohibition); research-documented scoped keys stay in their owning services |
| T-03-15 | DoS | Plist-export silently-empty reads making the editor look broken (false-empty domain) | low | mitigate | The read path is the plist FILE through the app container — the silently-unsupported export verb is forbidden by prohibition + acceptance grep |
| T-03-SC | Tampering | Package installs | high | mitigate | Zero package installs this plan — Apple frameworks only; asserted at the phase gate (plan 05) |
</threat_model>

<verification>
- Task 1/2 automated: UserDefaultsEditorServiceTests + AppActionCatalogTests green via the plan's xcodebuild commands; Debug build proves wiring + mounts compile.
- Live editor round-trip (write → app reads new value on next launch) and live search behavior are proven in plan 05's phase-gate smoke (VALIDATION Manual-Only row "Defaults edits land live" + gate step 5).
- No SPM/pbxproj package changes this plan.
</verification>

<success_criteria>
- The 5 must_haves truths hold at the unit-contract level now and at the live level after plan 05's smoke.
- Both Wave 0 test files green; app builds; the tab's full section set survives the search wiring (empty query = full tab, fixed order).
- Editor surface is privacy-clean (no value logging, validated argv, selected-domain writes only).
</success_criteria>

## Artifacts this phase produces

Created by THIS plan (new symbols):
- DefaultsEntry (+ DefaultsEntryValue typed wrapper, simctlTypeArg builder) — BoosterSimApp/Models/DefaultsEntry.swift
- UserDefaultsEditorService (plist-file load + validated typed write/delete) — BoosterSimApp/Services/UserDefaultsEditorService.swift
- AppAction + EffectLatency + AppActionCatalog (pure searchable catalog, fixed order) — BoosterSimApp/Models/AppAction.swift
- UserDefaultsEditorView, ActionSearchBar — BoosterSimApp/Views/SideWindow/actions/
- Tests: UserDefaultsEditorServiceTests (fixture plist), AppActionCatalogTests

Modified: ActionsTabView (search bar + catalog-driven section visibility + defaults section mount), AppDelegate (userDefaultsEditorService construction), SideWindowView (.environmentObject injection).

Later plan adds: docs + full-suite + phase-gate smoke (05).

<output>
Create `.planning/phases/03-app-actions/03-04-SUMMARY.md` when done
</output>
