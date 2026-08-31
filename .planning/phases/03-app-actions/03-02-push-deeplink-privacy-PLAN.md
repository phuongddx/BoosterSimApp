---
phase: 03-app-actions
plan: 02
type: execute
wave: 2
depends_on: ["03-01-reset-app-tracer"]
files_modified:
  - BoosterSimApp/Services/DeepLinkService.swift
  - BoosterSimApp/Services/AppActionService.swift
  - BoosterSimApp/Models/PushPayload.swift
  - BoosterSimApp/Models/PrivacyPermission.swift
  - BoosterSimApp/Views/SideWindow/actions/PushNotificationSectionView.swift
  - BoosterSimApp/Views/SideWindow/actions/PrivacySectionView.swift
  - BoosterSimApp/Views/SideWindow/tabs/ActionsTabView.swift
  - BoosterSimApp/App/AppDelegate.swift
  - .planning/codebase/CONVENTIONS.md
  - BoosterSimAppTests/DeepLinkServiceTests.swift
  - BoosterSimAppTests/PrivacyPermissionTests.swift
  - BoosterSimAppTests/PushPayloadTests.swift
autonomous: true
requirements:
  - REQ-roadmap-phase3-app-actions
  - REQ-fr-13
estimate:
  tokens: 42000
  raw_tokens: 42000
  tasks: 2
  confidence: low

must_haves:
  truths:
    - "A validated JSON payload (aps alert/badge/sound, optional Simulator Target Bundle) sent from the Push section is delivered to the selected app on the booted Simulator — simctl confirms with 'Notification sent to <bundle>' — and repeated sends of the same payload deliver N independent notifications with no corruption"
    - "Payloads over 4096 encoded bytes, non-object JSON, and payloads missing the aps key are rejected before any subprocess runs, with a typed error shown inline; empty payload text is rejected, never sent"
    - "Deep links typed or picked from presets/history still open in the Simulator after the service migration onto the SimCtlService seam — behavior identical (URL validation, parse detail, history/favorites persistence) with zero functional regressions"
    - "The 12 documented privacy services grant/revoke per the selected app and reset-all (TCC services only) runs behind a destructive confirm; the UI states plainly that notification permission is NOT among them and is managed by iOS (D-01)"
    - "The push permission control guides the manual grant honestly: it links to the device Settings app (launch verb), shows the guided steps, and verifies via a test-push probe — it never renders a control that claims to silently grant or revoke notification authorization (D-01)"
    - "After this plan, every simctl invocation in the app goes through SimCtlService — the deep-link path's out-of-seam subprocess spawn is deleted, and the async-exemption list in .planning/codebase/CONVENTIONS.md shrinks to CaptureService alone"
  artifacts:
    - BoosterSimApp/Models/PushPayload.swift
    - BoosterSimApp/Models/PrivacyPermission.swift
    - BoosterSimApp/Views/SideWindow/actions/PushNotificationSectionView.swift
    - BoosterSimApp/Views/SideWindow/actions/PrivacySectionView.swift
    - BoosterSimAppTests/PushPayloadTests.swift
    - BoosterSimAppTests/PrivacyPermissionTests.swift
    - BoosterSimAppTests/DeepLinkServiceTests.swift
  key_links:
    - "PushNotificationSectionView send → PushPayload.validate() → AppActionService.sendPush(udid:bundle:) → simCtl.run([push, udid, bundle, \"-\"], stdin: encoded) → output parsed to result caption → @Published pushResult"
    - "PushNotificationSectionView Open Settings → AppActionService.openDeviceSettings(udid:) → simCtl.run([launch, udid, com.apple.Preferences])"
    - "DeepLinkSectionView → DeepLinkService (migrated) → simCtl.run([openurl, udid, urlString]) → lastResult → result caption (unchanged UI contract)"
    - "PrivacySectionView pill → PrivacyPermission.simctlArgs(udid:action:) → AppActionService.setPrivacy → simCtl.run → status caption"
  prohibitions:
    - requirement_id: REQ-roadmap-phase3-app-actions
      category: transparency
      status: unverified
      flagged: true
      statement: "MUST NOT present push permission as settable — no toggle, button, or control claims to grant or revoke notification authorization; the UI states it is managed by iOS, links to Settings, and verifies by test-push probe only (D-01, locked)"
    - requirement_id: REQ-roadmap-phase3-app-actions
      category: privacy
      status: unverified
      flagged: true
      statement: "MUST NOT log push payload content verbatim — logging for push/privacy/deep-link actions carries the verb, outcome, and encoded byte size only, never payload bodies or full URLs with query strings"
    - requirement_id: REQ-roadmap-phase3-app-actions
      category: values
      status: unverified
      flagged: true
      statement: "MUST NOT spawn xcrun/simctl subprocesses outside SimCtlService — this plan's deep-link migration is the cutover that closes the last out-of-seam violation; after it lands the codebase contains zero direct subprocess spawns outside the seam"
  flagged_assumptions:
    - requirement_id: REQ-roadmap-phase3-app-actions
      probe: research-D01
      status: unresolved
      statement: "D-01's 'detects current APNS state' is realized as a test-push probe because no public state read exists (TCC.db has no UserNotifications row — research-proven): the control shows the honest cannot-read-state caption, guides the manual grant, and the probe send + banner observation is the verification. If execution discovers a legitimate spawn-readable state signal, adopt it and record the deviation in the summary — do not block on it"
    - requirement_id: REQ-roadmap-phase3-app-actions
      probe: adjacency
      status: resolved-at-close
      statement: "Verified in unit tests: the privacy enum contains exactly the 12 research-verbatim service strings and no case for the unsupported notification service (PrivacyPermissionTests locks the simctl contract)"
---

<objective>
Success criterion 2: push notifications (payload + D-01 guided permission), the privacy services section, and the deep-link migration onto the seam.

Two expansions on the proven tracer slice: (1) migrate DeepLinkService onto SimCtlService — deleting the app's last out-of-seam subprocess spawn and its async/await convention exemption while keeping parse/history/favorites behavior identical — plus the PrivacyPermission model and the 12-service privacy section with honest captions; (2) the PushPayload model (aps shape, Simulator Target Bundle, 4096-byte gate) and the push sender/editor UI with the D-01 guided-grant permission control (honest caption + Settings link + test-push probe).

Purpose: 03-RESEARCH.md live-verified the push verb (stdin payload, 4096 B cap, aps key, banner delivery to com.apple.mobilecal), proved notifications absent from simctl privacy (D-01), and flagged DeepLinkService as the convention violation Phase 3 must delete. All verbs ride the plan-01 seam (stdin + concurrent reads now exist).
Output: 4 new files, 4 modified files, 3 Wave 0 Swift Testing files; live push/privacy behavior is proven in plan 03's blocking smoke (this plan is autonomous — unit contracts only).
</objective>

<execution_context>
@~/.claude/gsd-core/workflows/execute-plan.md
@~/.claude/gsd-core/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/ROADMAP.md
@.planning/STATE.md
@.planning/phases/03-app-actions/03-CONTEXT.md
@.planning/phases/03-app-actions/03-RESEARCH.md
@.planning/phases/03-app-actions/03-PATTERNS.md
@.planning/phases/03-app-actions/03-01-SUMMARY.md

Source-of-truth analogs (read before writing each file — PATTERNS.md carries near-verbatim excerpts):
@BoosterSimApp/Services/DeepLinkService.swift
@BoosterSimApp/Services/SimCtlService.swift
@BoosterSimApp/Services/AppActionService.swift
@BoosterSimApp/Views/SideWindow/DeepLinkSectionView.swift
@BoosterSimApp/Views/SideWindow/network/NetworkConditionsSectionView.swift
@BoosterSimApp/Models/BoosterCommand.swift
@BoosterSimApp/Models/AppSettings.swift
@BoosterSimAppTests/BlockRuleTests.swift
@BoosterSimAppTests/CommandPayloadTests.swift
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: DeepLinkService onto the seam (delete the out-of-seam spawn) + PrivacyPermission model + 12-service privacy section</name>
  <files>
    BoosterSimApp/Services/DeepLinkService.swift,
    BoosterSimApp/Services/AppActionService.swift,
    BoosterSimApp/Models/PrivacyPermission.swift,
    BoosterSimApp/Views/SideWindow/actions/PrivacySectionView.swift,
    BoosterSimApp/Views/SideWindow/tabs/ActionsTabView.swift,
    BoosterSimApp/App/AppDelegate.swift,
    .planning/codebase/CONVENTIONS.md,
    BoosterSimAppTests/DeepLinkServiceTests.swift,
    BoosterSimAppTests/PrivacyPermissionTests.swift
  </files>
  <read_first>
    - .planning/phases/03-app-actions/03-CONTEXT.md — D-01 verbatim (locked: guided manual grant + honest caption; no fake toggle)
    - .planning/phases/03-app-actions/03-RESEARCH.md — Verified Surface rows for privacy (12 verbatim service strings + terminate warning + notifications absence) and openurl; Pitfalls 1 (no notifications service), 7 (privacy may terminate the app), 9 (convention regression risk); Problem Domain §2; Security Domain V5 row
    - .planning/phases/03-app-actions/03-PATTERNS.md — DeepLinkService migration assignment (DELETE block lines 54-87, KEEP parseURL lines 124-146 + history/favorites lines 148-186), PrivacyPermission ← SideWindowPosition/HTTPMethod raw-value discipline, PrivacySectionView ← NetworkConditionsSectionView (pills + scope caption), BlockRuleTests contract style
    - BoosterSimApp/Services/DeepLinkService.swift (whole file — the migration target)
    - BoosterSimApp/Services/SimCtlService.swift (the Task-1-of-plan-01 seam incl. stdin parameter)
    - BoosterSimApp/Services/AppActionService.swift (plan 01 version — the facade being extended)
    - BoosterSimApp/Views/SideWindow/DeepLinkSectionView.swift (input + presets + result-caption shape the push section reuses in Task 2; note its flagged raw 12/8/6 spacing deviation)
    - BoosterSimApp/Views/SideWindow/network/NetworkConditionsSectionView.swift lines 4-20 (CollapsibleSection shell) and 139-143 (honest scope caption)
    - BoosterSimApp/Models/AppSettings.swift lines 9-16 (SideWindowPosition raw-value enum presentation)
    - BoosterSimAppTests/BlockRuleTests.swift (negative-case contract discipline)
    - .planning/codebase/CONVENTIONS.md line 8 area (the async-exemption list this task shrinks) and Shell Commands section
    - AGENTS.md GitNexus section — run gitnexus_impact upstream on DeepLinkService BEFORE the migration (callers: AppDelegate construction, ActionsTabView/DeepLinkSectionView consumption, SideWindowView injection) and record blast radius
  </read_first>
  <behavior>
    - DeepLinkServiceTests: parseURL extracts scheme/host/path/query/fragment for representative URLs and returns nil for invalid input
    - DeepLinkServiceTests: the open-url command builder produces the exact argv [openurl, udid, urlString] with the booted-fallback when udid is nil; empty and scheme-less URLs are rejected by validation before any builder runs
    - DeepLinkServiceTests: history/favorites round-trip through an isolated UserDefaults suite (never the shared standard suite) — add, persist, re-init service, entries survive; dedupe/most-recent-first ordering preserved
    - PrivacyPermissionTests: allCases rawValues equal EXACTLY the 12 research-verbatim per-app service strings — calendar, contacts-limited, contacts, location, location-always, photos-add, photos, media-library, microphone, motion, reminders, siri (PATTERNS pins this set; the help text's reset-everything shortcut token is NOT a per-app case — it appears only inside resetAllArgs)
    - PrivacyPermissionTests: no case exists for the unsupported notification service (the enum is not constructible for it — assert the rawValue initializer returns nil for that string)
    - PrivacyPermissionTests: simctlArgs(udid:action:) composes [privacy, udid, grant|revoke, service] exactly; resetAll composes [privacy, udid, reset, all]
  </behavior>
  <action>
    Write DeepLinkServiceTests.swift and PrivacyPermissionTests.swift FIRST (red), then implement green. The per-service enum carries the 12 named services (grantable/revocable individually); the reset-all verb is a static builder, not a 13th pill — the test asserting rawValues covers whichever exact set you ship, pinned to the research table.

    BoosterSimApp/Services/DeepLinkService.swift (modify — gitnexus_impact first): keep the class @MainActor ObservableObject and its published lastResult/history/favorites contract EXACTLY (DeepLinkSectionView must not change behavior). Add init(simCtl: SimCtlService). Replace the async open implementation (the detached-spawn block, current lines 54-87) with a Combine chain: validate (empty → error, URL(string:) + scheme != nil → error), then simCtl.run(["openurl", udid ?? "booted", urlString]) sinking into lastResult (.success(url) / .error(message-from-stderr)), stored in &cancellables. Keep parseURL, scheme presets, and the history/favorites persistence block (lines 148-186) byte-for-byte in behavior. The migration deletes the direct process spawn AND the coroutine-shaped public API — the public open method becomes synchronous (Combine-backed), which is what removes this file from the exemption list.

    BoosterSimApp/Models/PrivacyPermission.swift (new): enum PrivacyPermission: String, CaseIterable, Sendable whose raw values are the verbatim simctl service strings from the research table (raw values are exec-argv contract, NOT presentation — SideWindowPosition discipline); computed label (human-readable title-cased); computed bundleScoped note if needed for captions; func simctlArgs(udid: String, action: PrivacyAction) -> [String] with enum PrivacyAction { grant, revoke }; static func resetAllArgs(udid: String) -> [String].

    BoosterSimApp/Services/AppActionService.swift (modify): add setPrivacy(_ permission: PrivacyPermission, action: PrivacyAction, udid: String) and resetAllPrivacy(udid:) — one shared verb helper through runSimCtl (30s timeout), status captions, AppLogger.actions verb+outcome logging. Also add openDeviceSettings(udid:) building the launch verb for com.apple.Preferences (consumed by Task 2's D-01 control; landing it here keeps all verb routing in the facade). Keep the file within the house LOC target — these are thin single-hop verbs.

    BoosterSimApp/Views/SideWindow/actions/PrivacySectionView.swift (new): CollapsibleSection(title: "Privacy", icon: "hand.raised", …) over the enum: one compact row/pill per service with a Grant/Revoke segmented control or menu (NetworkConditionsSectionView pill anatomy, tokens only), scoped to the active app from the picker; Reset All Privacy behind .confirmationDialog(role: .destructive) noting it resets TCC services device-wide. TWO honest captions: (a) Apple's verbatim warning that some permission changes will terminate the running app; (b) a D-01 pointer line — notification permission is not among these services; it is managed by iOS (see the Push section). Never render any control for the unsupported notification service.

    BoosterSimApp/Views/SideWindow/tabs/ActionsTabView.swift (modify): mount PrivacySectionView after the deep-link section, passing the active bundle/udid providers.

    BoosterSimApp/App/AppDelegate.swift (modify): construct deepLinkService with simCtlService (init signature change from the migration) — the one wiring edit the migration requires.

    .planning/codebase/CONVENTIONS.md (modify, one line): remove DeepLinkService from the async/await exemption list — after this task the sole documented exemption is CaptureService (ScreenCaptureKit). Keep the edit scoped to that list.
  </action>
  <verify>
    <automated>xcodebuild -project BoosterSimApp.xcodeproj -scheme BoosterSimApp -destination 'platform=macOS' test -only-testing:BoosterSimAppTests/DeepLinkServiceTests -only-testing:BoosterSimAppTests/PrivacyPermissionTests -parallel-testing-enabled NO && xcodebuild -project BoosterSimApp.xcodeproj -scheme BoosterSimApp -configuration Debug build</automated>
  </verify>
  <acceptance_criteria>
    - DeepLinkServiceTests.swift and PrivacyPermissionTests.swift exist, import Testing, and cover every behavior bullet (parse/validation/argv builder; isolated-suite history round-trip; the exact verbatim service-string set; nil-initializer proof for the unsupported notification service; args composition)
    - DeepLinkService.swift contains zero occurrences of the detached-spawn token and zero direct process-launch constructor calls — the open path routes through simCtl.run with the booted fallback; parseURL/history/favorites behavior is unchanged (tests pin it)
    - PrivacyPermission.swift declares raw values that are the verbatim simctl service strings (tests lock the set); no case exists for the unsupported notification service
    - PrivacySectionView.swift renders the terminate-warning caption and the notification-not-settable pointer caption; its only destructive action sits inside a confirmationDialog with role: .destructive
    - .planning/codebase/CONVENTIONS.md exemption list no longer names DeepLinkService
    - Both xcodebuild commands exit 0 (the Debug build proves the AppDelegate wiring change compiles)
  </acceptance_criteria>
  <reversibility rating="costly">The DeepLinkService init signature changes with d=1 callers (AppDelegate) — updated in the same commit; the PrivacyPermission raw values are an exec-argv contract locked by tests, so they are effectively frozen once shipped.</reversibility>
  <done>Deep links open through the seam with identical behavior and one less convention exemption; the 12 privacy services grant/revoke/reset with honest captions; both test files green; app builds.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: PushPayload model + stdin push sender + payload editor UI with the D-01 guided-grant permission control</name>
  <files>
    BoosterSimApp/Models/PushPayload.swift,
    BoosterSimApp/Services/AppActionService.swift,
    BoosterSimApp/Views/SideWindow/actions/PushNotificationSectionView.swift,
    BoosterSimApp/Views/SideWindow/tabs/ActionsTabView.swift,
    BoosterSimAppTests/PushPayloadTests.swift
  </files>
  <read_first>
    - .planning/phases/03-app-actions/03-CONTEXT.md — D-01 verbatim (detect + Settings link + honest caption, documented platform limitation)
    - .planning/phases/03-app-actions/03-RESEARCH.md — Verified Surface push row (payload spec: top-level object, aps required, 4096-byte cap, Simulator Target Bundle top-level key replacing the bundle arg, remote-app-notifications only), live delivery evidence, Problem Domain §2, Don't Hand-Roll push row, Security Domain V5 (input validation)
    - .planning/phases/03-app-actions/03-PATTERNS.md — PushPayload ← BoosterCommand/ThrottleSpec + BlockRule validation style; PushNotificationSectionView ← DeepLinkSectionView (input + presets + result caption + parsed-detail toggle; fix the flagged raw 12/8/6 spacing — use tokens)
    - BoosterSimApp/Models/BoosterCommand.swift lines 18-46 (versioned Codable payload discipline)
    - BoosterSimApp/Views/SideWindow/DeepLinkSectionView.swift lines 14-56 + 157-170 (vertical flow: input row → preset pills → result block with 0.1-opacity background + CornerRadius → caption toggle)
    - The Task 1 versions of AppActionService.swift and ActionsTabView.swift; BoosterSimApp/Services/SimCtlService.swift stdin parameter (plan 01)
  </read_first>
  <behavior>
    - PushPayloadTests: encode round-trip — aps(alert/badge/sound) and the Simulator Target Bundle key map to/from JSON exactly (CodingKeys pin the top-level string "Simulator Target Bundle")
    - PushPayloadTests: validate() accepts a well-formed minimal payload; rejects payloads whose encoded size exceeds 4096 bytes (boundary: 4095 passes, 4097 fails); rejects non-object roots and payloads missing the aps key; empty input is rejected
    - PushPayloadTests: template presets (alert / badge / sound combos) encode to valid payloads under the size gate
    - PushPayloadTests: malformed JSON text produces the typed parse error, never a crash
  </behavior>
  <action>
    Write PushPayloadTests.swift FIRST (red), then:

    BoosterSimApp/Models/PushPayload.swift (new): struct PushPayload: Codable, Equatable with nested Aps (alert String?, badge Int?, sound String?) and optional simulatorTargetBundle mapped via CodingKeys to the verbatim top-level key "Simulator Target Bundle" (BoosterCommand versioning discipline not needed — no persistence — but Equatable + Codable purity is). Pure func validate(encodedSize:) or validate() -> PushPayloadError? where PushPayloadError covers missingAPS, tooLarge(ByteCount), notObject — the gate is measured on JSONEncoder output bytes (4096 cap per the verified verb spec). static template funcs for the preset pills (alert-only, alert+sound, badge+alert). JSON parse entry: static func parse(_ text: String) -> Result<PushPayload, PushPayloadError> for the editor text.

    BoosterSimApp/Services/AppActionService.swift (modify): sendPush(udid: String, bundle: String?, payloadText: String) — parse via PushPayload.parse, validate, then simCtl.run(["push", udid, bundle ?? "-", "-"], stdin: encoded) using the explicit bundle arg (arg overrides the payload key — explicit targeting beats embedded), mapping output containing "Notification sent to" to a success caption and stderr/exit to typed error captions; @Published pushResult. openDeviceSettings from Task 1 is the Settings link verb. Log verb + byte size + outcome ONLY — payload bodies never reach AppLogger (prohibition). Also publish the encoded-size computation for the live counter.

    BoosterSimApp/Views/SideWindow/actions/PushNotificationSectionView.swift (new): DeepLinkSectionView flow with tokens (Spacing.xs / CornerRadius.medium — not the flagged raw literals): JSON TextEditor bound to payload text, template preset pills (alert / alert+sound / badge+alert), live byte counter caption "n / 4096 bytes" turning warning-colored near the cap, Send button (disabled without booted device or active bundle; validation errors render inline before any send), result caption block (success/error styling like the deep-link result). PERMISSION BLOCK per D-01 (guideded manual grant, locked): a caption stating notification permission is managed by iOS and not settable from simctl (honest limitation, verbatim intent from D-01); an "Open Settings" button calling appActionService.openDeviceSettings; the guided steps spelled inline (Settings → Notifications → <active app> → Allow); and the test-push probe as the verify path — the Send button IS the probe; the caption after a successful send reminds that a banner appears only when permission is granted. No control anywhere claims to toggle permission state (flagged assumption: probe-based detection because no public state read exists).

    BoosterSimApp/Views/SideWindow/tabs/ActionsTabView.swift (modify): mount PushNotificationSectionView between the deep-link and privacy sections.
  </action>
  <verify>
    <automated>xcodebuild -project BoosterSimApp.xcodeproj -scheme BoosterSimApp -destination 'platform=macOS' test -only-testing:BoosterSimAppTests/PushPayloadTests -parallel-testing-enabled NO</automated>
  </verify>
  <acceptance_criteria>
    - PushPayloadTests.swift exists, imports Testing, and covers every behavior bullet incl. the 4095/4097 boundary pair and the malformed-JSON typed error
    - PushPayload.swift maps the verbatim top-level key "Simulator Target Bundle" via CodingKeys and exposes the pure validation gate; JSONEncoder is the only encoder used
    - AppActionService.sendPush routes through simCtl.run with the stdin parameter and the explicit bundle arg; the file contains no payload-body logging (grep: logging lines reference size/verb/outcome only)
    - PushNotificationSectionView.swift renders the byte counter with the 4096 cap, template pills, validation-before-send, the D-01 caption naming iOS-managed permission, an Open Settings action, and zero controls that grant/revoke notification permission
    - No raw spacing literals (bare-integer padding/cornerRadius) in PushNotificationSectionView.swift — design tokens only (fixing the DeepLinkSectionView deviation, not copying it)
    - The test command exits 0
  </acceptance_criteria>
  <reversibility rating="reversible">All additive: a new model, one facade verb, one section view; no existing contract changes.</reversibility>
  <done>Success criterion 2 code-complete: validated push payloads send through the stdin seam to the selected app; the D-01 guided-grant control ships honestly; deep links + privacy services landed in Task 1; live behavior proven in plan 03's blocking smoke.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| User JSON text → push payload → device notification pipeline | Arbitrary user-entered JSON crosses into simctl argv/stdin and the device's notification system |
| URL text → openurl on the device | Untrusted/prompt-injection-style URLs cross from the editor into device-side scheme handling |
| BoosterSimApp → device TCC privacy state | privacy verbs mutate trust state for the selected app |

## STRIDE Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation Plan |
|-----------|----------|-----------|----------|-------------|-----------------|
| T-03-05 | Information Disclosure | Push payload content in logs / result captions stored | medium | mitigate | AppLogger.actions logs verb + encoded byte size + outcome only; result captions show simctl's own summary line, not echoed payload bodies; no persistence of payload text beyond the session editor state |
| T-03-06 | Tampering | Prompt-injection URLs into openurl | medium | mitigate | Existing URL/scheme validation retained through the migration (DeepLinkServiceTests pin it); argv-only invocation — no shell interpolation anywhere (research Security table) |
| T-03-07 | Tampering/Transparency | A fake notification-permission toggle misleading the user (D-01) | high | mitigate | No permission-toggling control exists; honest caption + Settings launch + test-push probe; PrivacyPermissionTests lock the service set so the unsupported service can never silently appear as a case |
| T-03-12 | DoS | Oversized/malformed payload reaching the verb | low | mitigate | 4096-byte + shape validation runs before any subprocess (PushPayloadTests boundary pair); typed errors, no crash path |
| T-03-SC | Tampering | Package installs | high | mitigate | Zero package installs this plan — Apple frameworks only; asserted at the phase gate (plan 05) |
</threat_model>

<verification>
- Task 1/2 automated: DeepLinkServiceTests, PrivacyPermissionTests, PushPayloadTests green via the plan's xcodebuild commands; Debug build proves the AppDelegate init change and section mounts compile.
- Live push delivery, guided grant, and privacy behavior are proven in plan 03's blocking smoke (house pattern: re-verify quickly at the next checkpoint rather than blocking twice).
- No SPM/pbxproj package changes this plan.
</verification>

<success_criteria>
- The 6 must_haves truths hold at the unit-contract level now and at the live level after plan 03's smoke.
- All three Wave 0 test files green; app builds; the seam exemption list shrinks (DeepLinkService migrated, CaptureService sole exemption).
- Push validation is airtight before any subprocess (size gate, shape gate, typed errors).
</success_criteria>

## Artifacts this phase produces

Created by THIS plan (new symbols):
- PushPayload (+ Aps, PushPayloadError, template presets) — BoosterSimApp/Models/PushPayload.swift
- PrivacyPermission (+ PrivacyAction, simctlArgs builders) — BoosterSimApp/Models/PrivacyPermission.swift
- PushNotificationSectionView, PrivacySectionView — BoosterSimApp/Views/SideWindow/actions/
- Tests: PushPayloadTests, PrivacyPermissionTests, DeepLinkServiceTests

Modified: DeepLinkService (seam migration — out-of-seam spawn deleted, coroutine-shaped API replaced by Combine, behavior pinned by tests), AppActionService (+ setPrivacy/resetAllPrivacy/openDeviceSettings/sendPush), ActionsTabView (+ two sections), AppDelegate (deepLinkService init wiring), .planning/codebase/CONVENTIONS.md (exemption list shrunk to CaptureService).

Later plans add: locale/location/clipboard verbs + section views (03), AppAction catalog + search + defaults editor (04), docs + phase gate (05).

<output>
Create `.planning/phases/03-app-actions/03-02-SUMMARY.md` when done
</output>
