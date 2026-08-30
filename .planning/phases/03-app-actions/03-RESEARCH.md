# Phase 3: App Actions - Research

**Researched:** 2026-08-31
**Domain:** `xcrun simctl` action surface (reset/keychain, push, deep links, locale/timezone, appearance/Dynamic Type, location, clipboard, UserDefaults) + active-app detection from DerivedData, inside the 260pt Actions tab
**Confidence:** HIGH — every simctl verb below was executed live this session against an iPhone 17 / iOS 26.3 simulator on the project's actual Xcode (26.3 / Build 17C529), and every in-repo claim was read from source this session. The only MEDIUM/LOW areas are flagged in the Assumptions Log.

## Summary

Phase 3 fills the Actions tab. The decisive finding: **the Actions tab is not empty** — it already ships `EnvironmentOverridesView` (appearance dark/light, Dynamic Type via `simctl ui content_size`, increase contrast, and 8 more a11y toggles) and `DeepLinkSectionView` (openurl with history/favorites) [VERIFIED: BoosterSimApp/Views/SideWindow/tabs/ActionsTabView.swift:12-20]. Success-criterion items "toggle dark/light" and "change Dynamic Type size" are therefore **reuse, not build**. Deep links exist but **violate the SimCtlService seam**: `DeepLinkService.openInSimulatorAsync` spawns `/usr/bin/xcrun` via its own `Process` inside `Task.detached` [VERIFIED: BoosterSimApp/Services/DeepLinkService.swift:67-84], contradicting the repo rule "All `xcrun simctl` calls routed through `SimCtlService` / No direct subprocess spawning" [VERIFIED: .planning/codebase/CONVENTIONS.md:136-139,178]. Phase 3 should migrate it onto SimCtlService and retire that second async/await exception.

Every action the roadmap lists has a **verified simctl mechanism on Xcode 26.3** — with two scope-honest exceptions: (1) **`simctl privacy` has NO `notifications` service** (empirically: `grant notifications <bundle>` exits 1 "Operation not permitted" while the documented `photos` grant exits 0; the 12 documented services don't include notifications; the device TCC.db contains no UserNotifications service). Silent grant/revoke of push permission is **not possible via public simctl** — the plan must present the 12 supported privacy services + an honest caption, not a fake toggle. (2) **Per-app keychain clear does not exist**: `simctl keychain` supports only `add-root-cert`/`add-cert`/`reset`, and reset is **device-wide**; keychain items also survive `uninstall` (by design, multiple sources). "Clear Keychain items" ships as a destructive device-wide reset with an explicit warning — and it **wipes the Phase 5 CA**, so CertificateService trust state must reconcile afterwards.

Everything else verified clean: `push` delivers JSON payloads (≤4096 B, `aps` key, `Simulator Target Bundle` shortcut — live "Notification sent to 'com.apple.mobilecal'"); **clipboard bidirectional sync is a first-class verb** — `simctl pbsync host <udid>` and `pbsync <udid> host` both verified round-trip (plus `pbcopy`/`pbpaste`); locale (`AppleLanguages`/`AppleLocale`) and timezone (`AppleTimeZone`) are `spawn defaults write` global-domain keys that take effect on next app launch (relaunch via `launch --terminate-running-process`); `location` has set/clear **plus waypoint route simulation** (`start --speed/--distance/--interval`); UserDefaults editing verified end-to-end (typed writes land in `data/Library/Preferences/<domain>.plist` instantly — read the plist file for structure, write/delete via `spawn defaults`).

**Primary recommendation:** Build a thin `AppActionService` facade + `DerivedDataAppScanner` + `UserDefaultsEditorService` over an extended `SimCtlService` (add stdin support; fix the latent pipe-deadlock), render them as collapsible sections in `ActionsTabView` behind a searchable pure `AppActionCatalog` (TrafficFilterBar analog), migrate `DeepLinkService` onto SimCtlService, and present push-permission and keychain-clear as scope-honest destructive/limited actions. No new packages.

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| REQ-roadmap-phase3-app-actions | Reset app (terminate + clear container), clear Keychain items, send push payload, grant/revoke push permission, deep links, bidirectional clipboard sync, locale switcher (relaunch), dark/light toggle, Dynamic Type, location simulation + timezone sync, UserDefaults editor, quick search, bundle ID from DerivedData | Every mechanism verified live this session (see **Verified simctl Surface**): terminate/uninstall/get_app_container, keychain reset (device-wide — scope-honest), push (payload spec + live delivery), privacy services (notifications unsupported — scope-honest), openurl (migrate to seam), pbsync/pbcopy/pbpaste (both directions live), AppleLanguages/AppleLocale/AppleTimeZone + relaunch, ui appearance + content_size (already shipped — reuse), location set/clear/start + AppleTimeZone, defaults write/read/delete + on-disk plist (editor design), DerivedData scan design (project's own DerivedData has no iOS .app — scanner must be generic) |
| REQ-fr-13 (related) | Four tabs with Actions as third tab | Tab shell exists: `ActionsTabView` composes `EnvironmentOverridesView` + `DeepLinkSectionView` [VERIFIED: BoosterSimApp/Views/SideWindow/tabs/ActionsTabView.swift:12-20] — Phase 3 adds sections to the same tab body |
| REQ-fr-14 (related) | Env toggles instant via `simctl spawn`, no relaunch | Precedent pattern to reuse: write → Darwin-notification via `notifyutil -p` chain [VERIFIED: BoosterSimApp/Services/EnvironmentOverrideService.swift:269-278]; locale/timezone are the documented counter-case (relaunch required) |
| REQ-nfr-01 / REQ-nfr-02 (related) | macOS 15 min; Swift 6 strict concurrency | All recommended APIs are simctl subprocess calls — no OS-version sensitivity above the repo floor; concurrency via `@MainActor` + Combine per CONVENTIONS (no async/await) |
| REQ-nfr-03 (related) | Apple frameworks only (Pulse exception) | Zero new packages — Foundation/AppKit/SwiftUI/Combine only; Package Legitimacy Audit: n/a |
</phase_requirements>

## Project Constraints (from CLAUDE.md + AGENTS.md)

1. **Think before coding; simplicity first; surgical changes; goal-driven verification** (repo CLAUDE.md) — plan minimal new units; reuse the Actions tab body.
2. **Swift 6 strict concurrency; Combine-only, no async/await outside exempted services** — the only documented exceptions are `CaptureService.swift` (ScreenCaptureKit) and `DeepLinkService.swift` (`simctl openurl`) [VERIFIED: .planning/codebase/CONVENTIONS.md:8]. Phase 3 must **shrink** this list (migrate DeepLinkService), not grow it.
3. **All `xcrun simctl` through SimCtlService; UDID-scoped; no direct Process spawns elsewhere** [VERIFIED: .planning/codebase/CONVENTIONS.md:134-139,178].
4. **Design tokens, no hardcoded layout** (`Utilities/DesignTokens.swift`); SF Pro/SF Symbols only; amber accent; `@AppStorage` persistence in `AppSettings`; `AppLogger` categories (never log sensitive data — extends to UserDefaults values).
5. **File conventions:** PascalCase files matching primary type, `// File — purpose` header, MARK order, `<200 LOC` target, `final class` + `@MainActor` services with init-injected dependencies, Swift Testing (`@Test`/`#expect`) for units.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Reset / uninstall / keychain / privacy / push / openurl / location / clipboard / defaults | Mac app (SimCtlService subprocess) | — | All are simctl verbs; the Mac is the only tier that can invoke them |
| Bundle-ID ("active app") detection | Mac app (DerivedData filesystem scan) | simctl listapps + launchctl cross-check | Requirement pins DerivedData; device-side state only validates candidates |
| Dark/light + Dynamic Type | Mac app (existing `EnvironmentOverrideService`) | — | Already shipped in Phase 6; the Actions tab already renders them |
| Locale/timezone switch | Mac app (`spawn defaults write` + `launch` relaunch) | — | Global-domain keys read by apps at launch; no in-app cooperation needed |
| Push permission grant/revoke | **Not achievable via simctl** | (v2) in-app via BoosterSimConnect command channel | No public write path (verified); in-app `requestAuthorization` can only prompt, never silently grant |
| UserDefaults editor UI | Mac app (SwiftUI) | on-disk plist read + spawn write | cfprefsd live-writes; file read gives typed structure |

## Verified simctl Surface (Xcode 26.3, Build 17C529 — executed live 2026-08-31 unless noted)

All commands below were run against booted device `5DD825B4…` (iPhone 17, iOS 26.3). Tag `[VERIFIED: simctl live-run 2026-08-31]` applies to the whole table; help-text-only items are marked.

| Verb (verified usage) | Behavior | Verified result |
|---|---|---|
| `terminate <udid> <bundle>` | Kills a running app | exit 0 on `com.apple.mobilecal` |
| `uninstall <udid> <bundle>` | Removes app **+ its data container** | **exit 0 even when app is NOT installed** (idempotent — exit code cannot detect absence; pre-check `listapps`) |
| `get_app_container <udid> <bundle> [app\|data\|groups\|<gid>]` | Prints absolute container path | returned `…/Devices/<udid>/data/Containers/Data/Application/<uuid>` |
| `keychain <udid> reset` | **Device-wide** keychain reset; only ops are `add-root-cert`/`add-cert`/`reset` — **no per-app option** | help-verified; device keychain is one shared db (`data/Library/Keychains/keychain-2-debug.db`) |
| `privacy <udid> grant\|revoke\|reset <service> [<bundle>]` | Services (verbatim from help): `all, calendar, contacts-limited, contacts, location, location-always, photos-add, photos, media-library, microphone, motion, reminders, siri` — **no `notifications`** | `grant photos com.example.test` → exit 0 (works even uninstalled); `grant notifications …` → exit 1 "Operation not permitted" (identical to a bogus service); TCC.db (`data/Library/TCC/TCC.db`, sqlite-readable) has no UserNotifications service. Help verbatim: *"Some permission changes will terminate the application if running."* |
| `push <udid> [<bundle>] (<json file>\|-)` | Sends simulated remote push; payload: top-level object, `aps` key required, **≤4096 bytes**, `Simulator Target Bundle` top-level key may replace the bundle arg (arg overrides payload); remote app notifications only (no VoIP/complication) | `push <udid> - < payload.json` → "Notification sent to 'com.apple.mobilecal'", exit 0; malformed JSON → NSCocoaErrorDomain 3840 |
| `openurl <udid> <URL>` | Opens URL in device | exists (used today by DeepLinkService — outside the seam) |
| `ui <udid> appearance [light\|dark]` / `content_size [increment\|decrement\|<size>]` | Appearance + Dynamic Type, instant | **Already shipped** in `EnvironmentOverrideService` (12 content sizes, read-back support) [VERIFIED: BoosterSimApp/Services/EnvironmentOverrideService.swift:37-43,108-143,262-266] |
| `location <udid> set <lat>,<lon>` / `clear` | Point simulation / stop | help-verified; `list` (scenarios) and **`start [--speed=<m/s>] [--distance=<m>\|--interval=<s>] <lat>,<lon> <latN>,<lonN>…`** (waypoint routes, stdin `-` supported) also available |
| `pbsync [-pv] <src\|host> <dst\|host>` | Syncs pasteboard between Mac host and device (`-p` keeps promise-data provider alive) | **Bidirectional round-trip verified**: `echo … \| pbcopy; pbsync host <udid>; pbpaste <udid>` → Mac text on device; `pbsync <udid> host` → exit 0. `pbcopy` (stdin→device) and `pbpaste` (device→stdout) also present |
| `spawn <udid> defaults read\|write\|delete <domain> [key] [type val]` | Typed defaults ops on **any** domain (app bundle IDs are domains) | `-string/-int/-bool/-array` round-trip exit 0; writes land **immediately** in `data/Library/Preferences/<domain>.plist` (file reflected int 42/bool true/array). Global keys verified present: `AppleLanguages` (array `"en-US","en-VN","vi-VN"`), `AppleLocale` (string `"en_VN"`), `AppleTimeZone` (write `"Asia/Tokyo"` → read back → delete restores unset) |
| `launch <udid> <bundle> [--terminate-running-process]` | Launch/relaunch | help-verified; `--terminate-running-process` gives one-call relaunch for the locale flow [ASSUMED: not live-tested end-to-end] |
| `listapps <udid>` | XML plist of installed apps (`CFBundleIdentifier`, `CFBundleName`, …) | 33,246 bytes on near-stock device |
| `spawn <udid> launchctl list` | Running processes; apps appear as `UIKitApplication:<bundle-id>[<hex>][rb-legacy]` rows | verified: 372 rows incl. `UIKitApplication:com.apple.mobilecal[76eb][rb-legacy]`; SpringBoard present. Gives **running** set, **not frontmost** — no public frontmost verb exists |
| `defaults export <domain> -plist` | **Silently unsupported in simulator** — empty output, exit 0 | live-verified — never build the editor on it; `defaults read` emits old-style plist (no Swift parser) — read the plist **file** instead |
| `erase <udid>` | Nukes entire device | help-only — rejected as reset mechanism (too destructive) |

## Problem Domain — Available Approaches & Tradeoffs

### 1. "Reset active app" (terminate + clear container)
| Approach | Tradeoff |
|---|---|
| **terminate → uninstall** (recommended) | Terminated + data container removed by uninstall; idempotent; needs listapps pre-check (exit 0 on missing app); leaves app uninstalled |
| terminate → uninstall → reinstall (from DerivedData `.app` if available) | Restores "fresh install of the build I just made" UX; only possible when scanner found the `.app`; otherwise degrade to uninstall |
| delete `get_app_container data` contents manually | Dangerous (container UUID tracking, cfprefsd side-files), no benefit over uninstall |
| `simctl erase` | Nukes the whole device — rejected |
| Keychain part | **No per-app mechanism exists** (items survive uninstall by design). Ship device-wide `keychain reset` as a separate destructive action with warning + CertificateService reconciliation |

### 2. Push: permission + payload
| Approach | Tradeoff |
|---|---|
| **Payload sender** (recommended): validated JSON editor + `push <udid> -` (stdin) or temp file | Fully supported; template payloads (alert/badge/sound); 4096-byte pre-validation |
| Permission toggle | **Unsupported** (no service, no TCC path). Options: (a) honest caption + supported-services privacy section; (b) v2: prompt via BoosterSimConnect command channel (`UNUserNotificationCenter.requestAuthorization` in-app — still a prompt, not a silent grant) |
| Permission reset | `privacy <udid> reset all` is supported (TCC services only) — ship as part of the privacy section |

### 3. Locale / timezone (relaunch domain)
| Approach | Tradeoff |
|---|---|
| **`spawn defaults write` AppleLanguages + AppleLocale (+ AppleTimeZone) on `Apple Global Domain` → `launch --terminate-running-process`** (recommended) | Community-standard keys, live-verified; explicit relaunch makes effect deterministic; caption "takes effect on relaunch" |
| Per-app `AppleLanguages` in the app's own domain | Affects only one app — arguably nicer, but the roadmap says "switch locale" for the device context; global is the familiar Simulator behavior |
| Simulator Settings UI automation via AX | Fragile; rejected (repo precedent: CameraService AX automation exists but is a last resort) |

### 4. Clipboard sync
| Approach | Tradeoff |
|---|---|
| **`pbsync host <udid>` / `pbsync <udid> host` buttons** (recommended) | Verified both directions; no stdin plumbing; `-p` for promise data |
| `pbcopy`/`pbpaste` via stdin/stdout | Equivalent result but requires new SimCtlService stdin support (worth adding anyway for `push -`) |
| Background auto-sync timer | `pbsync` runs until promise data resolves (`-p`); polling both directions continuously is wasteful and fights Simulator.app's own (sometimes broken — Xcode 26.4 reports) auto-sync; manual triggers v1, revisit later |

### 5. "Active app" bundle ID
| Approach | Tradeoff |
|---|---|
| **DerivedData scan** (requirement-pinned): `~/Library/Developer/Xcode/DerivedData/*/Build/Products/*-iphonesimulator/*.app`, mtime-ordered, read `CFBundleIdentifier` from each `.app/Info.plist`; `info.plist` `WorkspacePath` can prefer the workspace's own DerivedData | Works without device state; **this project's own DerivedData has NO iOS `.app`** (only `BoosterSimConnect.framework` + `.o` files) — proof the scanner must be generic across all DerivedData dirs [VERIFIED: live FS inspection 2026-08-31] |
| Running-process filter (`launchctl list` → `UIKitApplication:` regex) | Verifies what's actually running; complements, doesn't replace (a freshly built app may not be running) |
| Installed filter (`listapps`) | Eliminates stale DerivedData candidates; plist parse cost trivial |
| Frontmost app | No public verb — cannot be done; document |

**Recommendation:** candidates = DerivedData recent iOS apps ∩ installed-on-device; badge the ones currently running; user picks from a compact picker bar (defaults to most recent). "Active" is explicit user selection, not a guess.

### 6. UserDefaults editor
| Approach | Tradeoff |
|---|---|
| **Read `data/Library/Preferences/<bundle>.plist` directly (typed, structured) + write/delete via `spawn defaults`** (recommended) | Verified: writes reflect on disk instantly; full type fidelity via `PropertyListSerialization`/`NSDictionary(contentsOf:)`; cfprefsd-coherent for running apps |
| Parse `defaults read` old-style output | No Swift parser for old-style plists; nested structures fragile — rejected |
| `defaults export -plist` | Silently unsupported in simulator (empty output, exit 0) — trap documented above |

## Recommended Approach (file split + service names)

```
BoosterSimApp/
├── Services/
│   ├── AppActionService.swift            # @MainActor ObservableObject facade (CaptureService pattern):
│   │                                     #   reset/clearKeychain/push/openurl (via SimCtlService)/locale/
│   │                                     #   location/clipboardSync; owns published per-action status
│   ├── DerivedDataAppScanner.swift       # Pure FS scan + Info.plist parse → [DiscoveredApp] (bundleID,
│   │                                     #   name, productPath, lastBuiltAt); WorkspacePath filter hook
│   ├── UserDefaultsEditorService.swift   # loadDomain(bundleID:) via plist file; write/delete via
│   │                                     #   spawn defaults; typed DefaultsEntry values
│   └── SimCtlService.swift               # EXTEND: stdin support (push -, pbcopy); read pipes
│                                         #   concurrently with waitUntilExit (deadlock fix, see Pitfalls 2)
├── Models/
│   ├── AppAction.swift                   # Pure, searchable ActionCatalog: id/title/keywords/section/
│   │                                     #   EffectLatency (instant|relaunch|deviceWide) — unit-test core
│   ├── PushPayload.swift                 # Codable: aps alert/badge/sound + SimulatorTargetBundle;
│   │                                     #   4096-byte validation
│   ├── PrivacyPermission.swift           # Enum of the 12 verbatim service strings + action mapping
│   └── DefaultsEntry.swift               # Typed value wrapper (string/int/bool/array/JSON)
├── Views/SideWindow/actions/
│   ├── AppPickerBar.swift                # DerivedData candidate picker (active-app selection)
│   ├── ActionSearchBar.swift             # TrafficFilterBar-analog filter over AppActionCatalog
│   ├── AppResetSectionView.swift         # Reset + Keychain clear (destructive confirmations)
│   ├── PushNotificationSectionView.swift # Payload editor/templates + send
│   ├── PrivacySectionView.swift          # 12 services grant/revoke/reset + honest caption
│   ├── LocaleSectionView.swift           # Locale/timezone presets + relaunch caption
│   ├── LocationSectionView.swift         # lat/lon entry, city presets, clear, route (optional)
│   ├── ClipboardSectionView.swift        # Push/Pull buttons + direction status
│   └── UserDefaultsEditorView.swift      # Searchable key list, edit/add/delete with type picker
└── Views/SideWindow/tabs/ActionsTabView.swift   # EXTEND: compose the new sections under
                                                  # EnvironmentOverridesView + DeepLinkSectionView
```

Wiring follows the shipped pattern exactly: `AppDelegate` constructs `lazy var appActionService = AppActionService(simCtl: simCtlService, …)` and passes it down; `SideWindowView` injects via `.environmentObject` [VERIFIED: BoosterSimApp/App/AppDelegate.swift:13-26; BoosterSimApp/Views/SideWindow/SideWindowView.swift:11-17,111-113].

**Also in scope (cutover):** migrate `DeepLinkService.openInSimulatorAsync` to `SimCtlService.run(["openurl", udid, url])` (deletes the direct `Process` + `Task.detached`, and removes the async/await convention exception for it), and add `AppLogger.actions` category (AppLogger is a static-enum registry [VERIFIED: BoosterSimApp/Utilities/AppLogger.swift:7-15]).

## Action Latency & Effect Table (UX honesty — plan should surface these as captions)

| Action | Effect timing | Scope | Relaunch? |
|---|---|---|---|
| Terminate / uninstall (reset) | immediate | per-app | app relaunched by user |
| Keychain reset | immediate | **whole device** (wipes Phase 5 CA) | — |
| Privacy grant/revoke/reset | immediate | per-service; `all` = device | may terminate the app (Apple help verbatim) |
| Push send | immediate | per-app | — |
| Deep link (openurl) | immediate | device | — |
| Appearance dark/light | immediate | device | no (already shipped) |
| Dynamic Type (content_size) | immediate | device | no (already shipped) |
| Locale (AppleLanguages/AppleLocale) | **next app launch** | device | **yes** → `launch --terminate-running-process` |
| Timezone (AppleTimeZone) | **next app launch** | device | **yes** |
| Location set/clear | immediate | device | no |
| Clipboard pbsync | immediate | host ↔ device | no |
| Defaults write/delete | immediate via cfprefsd; at-launch reads need relaunch | per-domain | only for launch-time keys |

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Push payload delivery | APNs mock server, UNUserNotificationCenter hacks | `simctl push` | First-class verb, exact payload semantics verified |
| Clipboard transport | pasteboard daemons, private APIs, AX menu automation | `simctl pbsync host <udid>` / reverse | Verified both directions; Simulator's own sync is flaky on Xcode 26.4 per community reports |
| Locale switching | app relaunch + per-app locale plist surgery | global-domain `spawn defaults write` + relaunch | Standard, deterministic, verified |
| Key/value store editing | plist byte editing, cfprefsd poking | `spawn defaults write/delete` + file read | cfprefsd coherence handled by the OS |
| Search filtering | per-view ad-hoc `contains` chains | pure `AppActionCatalog.filter(query:)` (TrafficFilter precedent: `TrafficFilter` struct) | Unit-testable, one behavior |
| Permission state store | custom TCC.db writer | `simctl privacy` verbs (+ read-only TCC.db sqlite if state display is wanted — verified readable) | Public interface; direct TCC writes are undocumented and brittle |

## Common Pitfalls

1. **`simctl privacy` has no `notifications` service.** What/why: silent push-permission toggling is impossible via public simctl (verified vs positive control). Avoid: ship the 12 documented services + explicit caption "Notification permission is managed by iOS — not settable from simctl." Warning sign: a plan task that types `privacy <udid> grant notifications` — it fails at runtime with "Operation not permitted".
2. **SimCtlService pipe deadlock on large outputs.** `run()` calls `proc.waitUntilExit()` **then** `readDataToEndOfFile()` [VERIFIED: BoosterSimApp/Services/SimCtlService.swift:53-57]. `listapps` is already 33 KB on a near-stock device; >64 KB fills the pipe buffer, the child blocks writing, `waitUntilExit` never returns → hang. Avoid: read both pipes concurrently with the wait (or before it). Warning sign: Actions tab freezes on "load apps".
3. **`uninstall` exits 0 for a missing app.** Can't detect failure by exit code. Avoid: `listapps` presence check before claiming success; drives the reset UX.
4. **Keychain reset is device-wide and kills the Phase 5 CA.** Avoid: destructive confirmation + trigger the existing CertificateService reconcile path after reset (SideWindowController already reconciles on simulator change). Warning sign: user reports cert trust broken after "clear keychain".
5. **`defaults export` silently does nothing in the simulator** (empty output, exit 0). Avoid: never parse its output; read the Preferences plist file. Warning sign: editor shows an empty list for every domain.
6. **Locale/timezone need relaunch** — a write alone looks like a no-op. Avoid: always follow with `launch --terminate-running-process` and caption it. 
7. **Privacy changes may terminate the running app** (Apple help verbatim). Avoid: surface as a caption, not a bug.
8. **`pbcopy` needs stdin — SimCtlService has no stdin path** [VERIFIED: run() writes only stdout/stderr pipes, SimCtlService.swift:47-48]. Avoid: add stdin support once (also serves `push <udid> -`) or stick to `pbsync`.
9. **Convention regression risk:** copying `DeepLinkService`'s direct-`Process` + `async/await` style. Avoid: route every new verb through SimCtlService; keep the facade Combine-only.
10. **`location start` runs indefinitely** (waypoint interpolation). Avoid: pair every start with a visible "Stop" (`location clear`).
11. **"Active app" guessing.** No frontmost verb exists; DerivedData alone can point at apps not installed on the booted device. Avoid: candidate ∩ installed ∩ (running badge) + explicit picker.
12. **Swift 6 Combine chains:** follow the shipped `[weak self]` + `flatMap` + `.store(in: &cancellables)` chain style [VERIFIED: BoosterSimApp/Services/EnvironmentOverrideService.swift:159-187]; no `Task {}` in services.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | Swift Testing (`import Testing`, `@Test`, `#expect`); UI tests XCTest (untouched) |
| Config file | none — Xcode default runner (house standard) |
| Quick run command | `xcodebuild test -project BoosterSimApp.xcodeproj -scheme BoosterSimApp -destination 'platform=macOS' -only-testing:BoosterSimAppTests -skip-testing:BoosterSimAppUITests -parallel-testing-enabled NO` |
| Full suite command | same without `-only-testing:` (house phase gate: unit bundle + both scheme builds; baseline 83 unit cases green at HEAD) |

### Phase Requirements → Test Map
| Req (criterion) | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| SC1 | Reset command sequence builder (terminate → uninstall → optional reinstall; listapps pre-check) | unit (pure arg builders) | `-only-testing:BoosterSimAppTests/AppActionServiceTests` | ❌ Wave 0 |
| SC1 | Privacy service enum maps to verbatim simctl service strings; notifications absent | unit | `…/PrivacyPermissionTests` | ❌ Wave 0 |
| SC2 | PushPayload encodes aps/alert/badge/sound + Simulator Target Bundle; rejects >4096 B / non-object | unit | `…/PushPayloadTests` | ❌ Wave 0 |
| SC2 | Deep-link URL validation & migration keeps behavior (parse tests already-shaped like `parseURL`) | unit | `…/DeepLinkServiceTests` | ❌ Wave 0 |
| SC3 | Locale/timezone arg builders (`AppleLanguages` array, `AppleLocale`, `AppleTimeZone`, relaunch sequence) | unit | `…/LocaleCommandTests` | ❌ Wave 0 |
| SC3 | DerivedDataAppScanner: fixture DerivedData tree → bundle IDs, mtime ordering, `-iphonesimulator` filter, WorkspacePath preference | unit | `…/DerivedDataAppScannerTests` | ❌ Wave 0 |
| SC4 | UserDefaultsEditorService: fixture plist → typed DefaultsEntry list; write/delete arg builders | unit | `…/UserDefaultsEditorServiceTests` | ❌ Wave 0 |
| SC4 | ActionCatalog search: keywords/section filtering, empty query, no-match | unit | `…/AppActionCatalogTests` | ❌ Wave 0 |
| SC1–4 | Live-device effects (push banner arrives, Maps shows location, clipboard paste, locale relaunch, keychain wipe + cert reconcile) | manual smoke (phase-gate plan, user-approved per house pattern) | scripted checklist | n/a |

### Sampling Rate
- **Per task commit:** quick unit command (targeted `AppAction*Tests` files) — seconds
- **Per wave merge:** full unit bundle via the quick command above (house standard `-parallel-testing-enabled NO` per STATE.md infra note)
- **Phase gate:** unit bundle exit 0 + Debug build + live-simulator manual smoke checklist (booted device required) — mirrors Phase 2's 02-04 pattern

### Wave 0 Gaps
- [ ] `BoosterSimAppTests/AppActionServiceTests.swift` — command builders + sequencing state
- [ ] `BoosterSimAppTests/PushPayloadTests.swift` — encode + 4096 gate
- [ ] `BoosterSimAppTests/PrivacyPermissionTests.swift` — verbatim service strings (lock the simctl contract)
- [ ] `BoosterSimAppTests/DerivedDataAppScannerTests.swift` — fixture DerivedData tree in test bundle
- [ ] `BoosterSimAppTests/UserDefaultsEditorServiceTests.swift` — fixture plist parsing + arg builders
- [ ] `BoosterSimAppTests/AppActionCatalogTests.swift` — search behavior
- [ ] Framework install: none — Swift Testing already configured

## Security Domain

### Applicable ASVS Categories
| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | n/a (local dev tool) |
| V3 Session Management | no | n/a |
| V4 Access Control | yes (destructive ops) | Confirmation dialogs for reset/keychain-reset; keychain reset scoped-warning |
| V5 Input Validation | yes | PushPayload shape + 4096-byte validation; defaults domain/key allowlist (`[A-Za-z0-9._-]`) before Process args (args are exec-argv, not shell — injection surface is arg-shape only); URL scheme validation already in DeepLinkService.parseURL |
| V6 Cryptography | no | n/a — never hand-roll; keychain reset is operational, not cryptographic |

### Known Threat Patterns for this stack
| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Secrets leaked via logs (`defaults read` of auth tokens) | Information Disclosure | AppLogger: log domain + key only, never values (extends house "never log sensitive data" rule) |
| Unintended destructive simctl (erase/reset/uninstall wrong UDID) | Tampering/Elevation | UDID always from tracker's active simulator; confirm dialog names device + app |
| Pipe hang DoS on big outputs | Denial of Service | Concurrent pipe reads (Pitfall 2) |
| Prompt-injection-style URLs into openurl | Tampering | Existing URL/scheme validation; no shell interpolation anywhere (Process argv only) |

## Package Legitimacy Audit

Not applicable — **Phase 3 installs zero external packages** (Foundation/AppKit/SwiftUI/Combine only; the sole repo dependency exception remains Pulse/PulseProxy via BoosterSimConnect, REQ-nfr-03). No `npm`/SPM additions → no legitimacy gate required. All mechanisms are first-party `xcrun simctl` verbs verified on-device this session.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| xcrun/simctl | every action | ✓ | Xcode 26.3 (17C529) | — (hard requirement, repo floor Xcode 16.3+) |
| iOS runtime device | live actions | ✓ | iOS 26.3 (3 devices present; none booted at research time — actions must degrade with "no booted device" state when tracker has no active simulator) | — |
| DerivedData write access | app scanner | ✓ | PermissionManager already gates DerivedData (onboarding step 3) | — |
| openssl | (existing CertificateService) | ✓ | already shipped | — |

**Missing dependencies with no fallback:** none. **With fallback:** none.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `launch --terminate-running-process` performs a clean single-call relaunch for the locale flow (help-verified; not live-tested end-to-end) | Verified Surface / Locale | Low — fallback is terminate + launch two-step |
| A2 | `simctl location set` immediately moves CLLocation consumers (help-verified mechanics; not visually confirmed in Maps) | Verified Surface | Low — manual smoke catches it |
| A3 | Notification authorization state survives `uninstall` on the simulator (real-iOS behavior; untested here) | Problem Domain §1 | Cosmetic — affects whether reset also resets push prompts |
| A4 | `pbsync` transfers rich/formatted pasteboard types, not just plain text (plain-text verified; rich types untested; `-p` promise flag exists for this) | Clipboard | Low — v1 captions "text clipboard"; extend later |
| A5 | Locale change affects only newly launched apps (global domain read at launch — community + Apple testing docs consensus) | Locale | Low |

## Open Questions

1. **Reset = uninstall only, or uninstall + reinstall when a `.app` is known?**
   - What we know: uninstall removes the container; DerivedData `.app` exists only for iOS targets the user actually built.
   - Recommendation: two buttons — "Reset App Data" (terminate+uninstall+reinstall when possible, else uninstall+caption) and plain "Uninstall"; both behind confirmation.
2. **Push permission: accept scope-honest caption in v1, or wire a v2 in-app prompt?**
   - What we know: no simctl path (verified). The Phase 5 command channel (`_booster-cmd._tcp.` → BoosterCommandClient) could carry a "request notification authorization" command that fires `UNUserNotificationCenter.requestAuthorization` in the app — a prompt, not a silent grant.
   - Recommendation: v1 caption + supported privacy services; file the channel-based prompt as a v2 candidate (needs framework mirror discipline).
3. **UserDefaults editor scope: active-app domain only, or any of the ~238 device domains?**
   - Recommendation: active-app domain default + optional "show all domains" toggle; favorites persisted via AppSettings.
4. **Location timezone sync shape:** auto-derive `AppleTimeZone` from a chosen city preset (city → lat/lon/tz triple), or independent pickers?
   - Recommendation: city presets that set both location and timezone in one action (matches "timezone sync" wording), plus manual lat/lon entry.

## Sources

### Primary (HIGH confidence)
- Live execution on this machine, 2026-08-31: Xcode 26.3 (Build 17C529) `simctl help` + per-verb `help`; empirical battery against booted iPhone 17 / iOS 26.3 (privacy positive-control, push delivery, pbsync round-trip, defaults typed round-trips, AppleLanguages/AppleLocale/AppleTimeZone, TCC.db schema query, container paths, launchctl listing, listapps) — all findings tagged `[VERIFIED: simctl live-run 2026-08-31]`
- `xcrun simctl <verb> help` verbatim usage strings (push 4096-byte/aps rules, privacy service list + terminate warning, location waypoints, keychain ops)
- In-repo source read this session: SimCtlService.swift; EnvironmentOverrideService.swift; DeepLinkService.swift; XcodeDetector.swift; ActionsTabView.swift; AppSettings.swift; AppLogger.swift; BuildStatsService.swift; AppDelegate.swift (wiring); SideWindowView.swift (injection); TrafficFilterBar.swift (search analog)
- `.planning/codebase/CONVENTIONS.md` (simctl seam, no-subprocess, async exceptions), `.planning/codebase/TESTING.md` (Swift Testing patterns, mock/DI guidance)

### Secondary (MEDIUM confidence)
- stackoverflow.com/questions/18911434 (keychain survives uninstall, iOS 10.3 beta history); apple.stackexchange.com/questions/332574 (same, device-wide reset context)
- gist.github.com/koke/e3106e4531e40d2ba423b76ad789caff + fastlane/fastlane#1643 (AppleLanguages/AppleLocale keys, underscore-vs-hyphen note)
- stackoverflow.com/questions/38046342 + developer.apple.com/forums/thread/820393 + samwize.com/2026/03/30 (Simulator pasteboard sync behavior/flakiness; pbsync/pbcopy as workaround)
- nshipster.com/simctl (pasteboard sync overview)

### Tertiary (LOW confidence)
- appium discuss (mobile: clearKeychains implementation hint — cited only as corroboration that per-app keychain clear requires non-public means)

## Metadata

**Confidence breakdown:**
- simctl surface: HIGH — every verb executed live this session on the project's exact Xcode
- Architecture/service split: HIGH — mirrors shipped Phase 2/5/6 patterns read from source
- Pitfalls: HIGH — all but A1–A2 reproduced or read directly from help/source
- Scope-honest gaps (push permission, per-app keychain): HIGH — negative results proven via positive controls

**Research date:** 2026-08-31
**Valid until:** ~2026-09-30 (Xcode 26.3 pinned; re-verify privacy service list if Xcode upgrades)
