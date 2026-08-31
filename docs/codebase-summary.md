# Codebase Summary

## Project Stats

- **Language:** Swift 6 (strict concurrency)
- **Frameworks:** AppKit, SwiftUI, Combine, CoreGraphics, ApplicationServices, ServiceManagement, QuartzCore, Network
- **Files:** 139 Swift source files (~18,270 LOC total across app, iOS framework source, CLI, and tests)
- **Targets:** BoosterSimApp (macOS), BoosterSimConnect (iOS framework), test targets
- **External dependencies:** Pulse/PulseProxy SPM (BoosterSimConnect framework only)
- **Test targets:** BoosterSimAppTests (unit tests), BoosterSimAppUITests (UI test scaffolds)

## Directory Structure

```
BoosterSimApp/
├── BoosterSimApp.xcodeproj/
├── BoosterSimApp/                        # Main target
│   ├── BoosterSimAppApp.swift            # @main entry point (23 LOC)
│   ├── App/
│   │   └── AppDelegate.swift             # NSApplicationDelegate (119 LOC)
│   ├── Models/
│   │   ├── SimulatorWindow.swift         # Window data model (25 LOC)
│   │   ├── AppSettings.swift             # @AppStorage settings (52 LOC)
│   │   ├── BuildRecord.swift             # Build history record (28 LOC)
│   │   ├── AXNode.swift                  # Accessibility tree node (18 LOC)
│   │   ├── BoosterCommand.swift          # Condition snapshot + framing + verdict (127 LOC)
│   │   ├── BlockRule.swift               # Domain/path block rule + matcher (43 LOC)
│   │   ├── NetworkConditionProfile.swift # Throttle presets + pacing math (83 LOC)
│   │   ├── AppActionModels.swift        # App-action operation, reset outcomes, argv builders/parsers (148 LOC)
│   │   ├── PrivacyPermission.swift      # 12 verbatim simctl TCC services + argv builders (71 LOC)
│   │   ├── PushPayload.swift            # Push payload model + typed parse + 4096-byte gate (125 LOC)
│   │   ├── DefaultsEntry.swift          # Typed defaults entry + value kinds (49 LOC)
│   │   └── AppAction.swift              # AppAction/EffectLatency/AppActionCatalog — pure searchable catalog (122 LOC)
│   ├── Services/
│   │   ├── SimulatorWindowTracker.swift  # Core detection service (199 LOC)
│   │   ├── WindowEnumerator.swift        # CGWindowList scan (65 LOC)
│   │   ├── WindowObserver.swift          # AXObserver wrapper (158 LOC)
│   │   ├── PermissionManager.swift       # Permission checks/requests (143 LOC)
│   │   ├── AppActionService.swift     # App-action facade: reset/keychain/push/privacy/locale/location/clipboard verbs (906 LOC)
│   │   ├── DerivedDataAppScanner.swift # Pure DerivedData iOS .app scanner (101 LOC)
│   │   ├── UserDefaultsEditorService.swift # Typed defaults editor: plist read + validated spawn writes (213 LOC)
│   │   ├── XcodeDetector.swift           # Xcode path detection (39 LOC)
│   │   ├── SimCtlService.swift           # xcrun simctl executor — serialized seam, concurrent drains, stdin (130 LOC)
│   │   ├── DeepLinkService.swift         # openurl deep links + history/favorites, on the seam (196 LOC)
│   │   ├── StatusBarService.swift        # Status bar config (110 LOC)
│   │   ├── EnvironmentOverrideService.swift # Appearance/accessibility (279 LOC)
│   │   ├── BuildStatsService.swift       # Build history polling (97 LOC)
│   │   ├── AXInspectorService.swift      # AX tree walker (112 LOC)
│   │   ├── CameraService.swift           # Camera menu automation (93 LOC)
│   │   ├── CertificateModels.swift       # CA status / operation / error types (96 LOC)
│   │   ├── CertificateStore.swift        # OpenSSL CA generation + persistence (172 LOC)
│   │   ├── CertificateService.swift      # CA trust management flow (195 LOC)
│   │   ├── ConnectService.swift          # Pulse server host + event pipeline (118 LOC)
│   │   ├── PulseServer.swift             # NWListener TCP server + Bonjour (104 LOC)
│   │   ├── PulseClientConnection.swift   # Per-client protocol handler (183 LOC)
│   │   ├── PulsePacketDecoder.swift      # Binary protocol parser (174 LOC)
│   │   ├── CommandServer.swift           # _booster-cmd._tcp. snapshot server (176 LOC)
│   │   └── NetworkConditionService.swift # Condition state hub + persistence (186 LOC)
│   ├── Windows/
│   │   ├── SideWindowPanel.swift         # NSPanel subclass (37 LOC)
│   │   ├── SideWindowController.swift    # Panel lifecycle, spring tracking (256 LOC)
│   │   ├── PositionCalculator.swift      # Pure frame math, content height + centering (90 LOC)
│   │   └── AXHighlightPanel.swift        # Floating orange border overlay (68 LOC)
│   ├── Views/
│   │   ├── MenuBar/
│   │   │   └── MenuBarView.swift         # MenuBarExtra content (59 LOC)
│   │   ├── SideWindow/
│   │   │   ├── SideWindowView.swift      # Root side panel view, tab-based layout (122 LOC)
│   │   │   ├── SideTab.swift             # Tab enum for side window navigation (27 LOC)
│   │   │   ├── TabBarView.swift          # Icon tab bar with amber underline (71 LOC)
│   │   │   ├── tabs/
│   │   │   │   ├── CaptureTabView.swift  # Capture tab: screenshot, recording, GIF (23 LOC)
│   │   │   │   ├── DesignTabView.swift   # Design tab: grid, safe area, ruler, picker (23 LOC)
│   │   │   │   ├── ActionsTabView.swift  # Actions tab: catalog-driven searchable 9-section surface (122 LOC)
│   │   │   │   └── NetworkTabView.swift  # Network tab: traffic + conditions + rules + certs (70 LOC)
│   │   │   ├── network/
│   │   │   │   ├── NetworkEventModel.swift # NetworkEvent, HTTPMethod, TrafficFilter, ConnectionState (208 LOC)
│   │   │   │   ├── TrafficRowView.swift    # Single request row in traffic list (98 LOC)
│   │   │   │   ├── TrafficList.swift       # Scrollable traffic list + empty state (73 LOC)
│   │   │   │   ├── TrafficDetailView.swift # Sheet: Summary/Headers/Body/Metrics tabs (300 LOC)
│   │   │   │   ├── TrafficFilterBar.swift  # Method + status filter pills + search (136 LOC)
│   │   │   │   ├── ConnectStatusBanner.swift # Connection state dot + label (92 LOC)
│   │   │   │   ├── ConnectSetupView.swift  # Setup instructions + code snippet (89 LOC)
│   │   │   │   ├── CurlExporter.swift        # NetworkEvent → cURL command (49 LOC)
│   │   │   │   ├── NetworkConditionsSectionView.swift # Airplane toggle + profile pills (144 LOC)
│   │   │   │   └── BlockRulesView.swift      # Block-rule editor section (153 LOC)
│   │   │   ├── actions/                   # Phase 3 app-action section views (9 files)
│   │   │   │   ├── AppPickerBar.swift     # Candidate pills + running badge + explicit selection (77 LOC)
│   │   │   │   ├── AppResetSectionView.swift # Reset/uninstall + D-02 keychain dialog (165 LOC)
│   │   │   │   ├── PushNotificationSectionView.swift # Payload editor + D-01 guided grant (263 LOC)
│   │   │   │   ├── PrivacySectionView.swift # 12 TCC grant/revoke rows + reset-all confirm (155 LOC)
│   │   │   │   ├── LocaleSectionView.swift # Locale presets + manual rows, relaunch captions (262 LOC)
│   │   │   │   ├── LocationSectionView.swift # Validated coordinates + city presets + Stop (245 LOC)
│   │   │   │   ├── ClipboardSectionView.swift # Two manual pbsync buttons (128 LOC)
│   │   │   │   ├── UserDefaultsEditorView.swift # Typed key list + edit/add/delete (505 LOC)
│   │   │   │   └── ActionSearchBar.swift  # Collapsible quick search, clear-on-collapse (73 LOC)
│   │   │   ├── DeviceHeaderView.swift    # Active device info (90 LOC)
│   │   │   ├── CollapsedStripView.swift  # 28pt collapsed state (35 LOC)
│   │   │   ├── SideWindowFooter.swift    # Version/status footer (36 LOC)
│   │   │   ├── FeatureSectionView.swift  # Collapsible section (90 LOC)
│   │   │   ├── FeatureRowView.swift      # Individual feature row (74 LOC)
│   │   │   ├── StatusBarSectionView.swift # Status bar preset UI (129 LOC)
│   │   │   ├── EnvironmentOverridesView.swift # Accessibility toggles (145 LOC)
│   │   │   ├── CertificateSectionView.swift # CA trust management UI (177 LOC)
│   │   │   ├── BuildStatsSectionView.swift # Build history section (92 LOC)
│   │   │   ├── BuildChartView.swift      # Canvas bar chart (42 LOC)
│   │   │   ├── AXTreeView.swift          # Accessibility tree list (141 LOC)
│   │   │   └── CameraView.swift          # Camera toggle UI (99 LOC)
│   │   ├── Preferences/
│   │   │   ├── PreferencesView.swift     # Tab container (~30 LOC)
│   │   │   ├── GeneralTab.swift          # Position + launch at login (~45 LOC)
│   │   │   └── AboutTab.swift            # App info + links (79 LOC)
│   │   ├── Onboarding/
│   │   │   ├── OnboardingContainerView.swift  # 4-step flow (114 LOC)
│   │   │   ├── OnboardingStepView.swift       # Single step layout (98 LOC)
│   │   │   └── ProgressDotsView.swift         # Step indicator dots (~25 LOC)
│   │   └── Shared/
│   │       ├── AccentButton.swift        # Amber CTA button (~25 LOC)
│   │       ├── StatusBadge.swift         # Colored dot + label (44 LOC)
│   │       └── CollapsibleSection.swift  # Reusable collapsible header (47 LOC)
│   └── Utilities/
│       ├── AppLogger.swift               # Centralized os.Logger instances (15 LOC)
│       ├── DesignTokens.swift            # Layout/spacing constants (51 LOC)
│       └── SpringAnimator.swift          # CADisplayLink spring physics (112 LOC)
├── BoosterSimAppTests/                   # Unit test target
│   ├── BoosterSimAppTests.swift          # Basic test scaffold (17 LOC)
│   ├── CertificateServiceTests.swift     # Certificate service behavior tests (26 LOC)
│   ├── CommandPayloadTests.swift         # BoosterCommand wire contract + framing (110 LOC)
│   ├── ConditionVerdictTests.swift       # Verdict precedence: guard/airplane/rules/throttle (119 LOC)
│   ├── NetworkConditionServiceTests.swift # State machine + persistence + snapshots (151 LOC)
│   ├── NetworkConditionProfileTests.swift # Presets + ThrottleSchedule pacing math (103 LOC)
│   ├── BlockRuleTests.swift              # Block-rule matcher edge cases (90 LOC)
│   ├── DerivedDataAppScannerTests.swift  # Scanner: dedupe/mtime/symlink/filter contracts (122 LOC)
│   ├── AppActionServiceTests.swift       # Facade: argv builders, parsers, reconcile, keychain delegate (256 LOC)
│   ├── DeepLinkServiceTests.swift        # Seam-migrated deep links: parse/history/favorites (154 LOC)
│   ├── PrivacyPermissionTests.swift      # 12 verbatim TCC strings; notifications-absent (D-01) (71 LOC)
│   ├── PushPayloadTests.swift            # Typed parse + 4096-byte boundary gate (156 LOC)
│   ├── LocaleCommandTests.swift          # Locale/timezone/location/clipboard builders + parsers (244 LOC)
│   ├── UserDefaultsEditorServiceTests.swift # Plist parse + typed write/delete argv (180 LOC)
│   └── AppActionCatalogTests.swift       # Catalog search/filter contracts (124 LOC)
├── BoosterSimAppUITests/                 # UI test target
│   ├── BoosterSimAppUITests.swift        # UI test scaffold (41 LOC)
│   └── BoosterSimAppUITestsLaunchTests.swift # Launch test scaffold (33 LOC)
├── BoosterSimConnect/                    # iOS framework source (loaded into Simulator apps)
│   ├── BoosterSimConnect.swift           # PulseProxy + condition-engine activation (71 LOC)
│   ├── BoosterCommandClient.swift        # Command channel client, NWBrowser (191 LOC)
│   ├── NetworkConditionController.swift  # Snapshot store + schema mirrors (137 LOC)
│   ├── BoosterNetworkProtocol.swift      # URLProtocol condition enforcement (239 LOC)
│   └── ThrottlePacing.swift              # Paced delivery scheduler (95 LOC)
└── plans/                               # Implementation plans
    └── reports/
```

## Key Files by Role

| Role | File |
|---|---|
| App entry | `BoosterSimAppApp.swift` |
| Service orchestration | `App/AppDelegate.swift` |
| Simulator detection | `Services/SimulatorWindowTracker.swift` |
| Low-level window scan | `Services/WindowEnumerator.swift` |
| Real-time AX events | `Services/WindowObserver.swift` |
| Pulse server + traffic pipeline | `Services/ConnectService.swift` |
| TCP server (NWListener) | `Services/PulseServer.swift` |
| Per-client protocol handler | `Services/PulseClientConnection.swift` |
| Binary protocol parser | `Services/PulsePacketDecoder.swift` |
| Command channel server | `Services/CommandServer.swift` |
| Condition state hub | `Services/NetworkConditionService.swift` |
| Condition payload + verdict | `Models/BoosterCommand.swift` |
| Block rule model | `Models/BlockRule.swift` |
| Throttle profiles + pacing | `Models/NetworkConditionProfile.swift` |
| Framework command client | `BoosterSimConnect/BoosterCommandClient.swift` |
| Framework snapshot store | `BoosterSimConnect/NetworkConditionController.swift` |
| Framework URLProtocol enforcement | `BoosterSimConnect/BoosterNetworkProtocol.swift` |
| Framework paced delivery | `BoosterSimConnect/ThrottlePacing.swift` |
| Network event models | `Views/SideWindow/network/NetworkEventModel.swift` |
| iOS framework activation | `BoosterSimConnect/BoosterSimConnect.swift` |
| Tab-based navigation | `Views/SideWindow/SideTab.swift`, `Views/SideWindow/TabBarView.swift` |
| Panel lifecycle & spring tracking | `Windows/SideWindowController.swift` |
| Position math | `Windows/PositionCalculator.swift` |
| AX element highlight | `Windows/AXHighlightPanel.swift` |
| CA trust management | `Services/CertificateService.swift` |
| CA models & types | `Services/CertificateModels.swift` |
| CA persistence | `Services/CertificateStore.swift` |
| Spring animation physics | `Utilities/SpringAnimator.swift` |
| Centralized logging | `Utilities/AppLogger.swift` |
| Design constants | `Utilities/DesignTokens.swift` |
| Settings persistence | `Models/AppSettings.swift` |
| Build stats polling | `Services/BuildStatsService.swift` |
| AX tree inspection | `Services/AXInspectorService.swift` |
| Camera automation | `Services/CameraService.swift` |
| Environment overrides | `Services/EnvironmentOverrideService.swift` |
| Status bar config | `Services/StatusBarService.swift` |
| App-action facade (reset/keychain/push/privacy/locale/location/clipboard) | `Services/AppActionService.swift` |
| DerivedData app discovery | `Services/DerivedDataAppScanner.swift` |
| UserDefaults editor (active app) | `Services/UserDefaultsEditorService.swift` |
| Deep links (openurl, on the seam) | `Services/DeepLinkService.swift` |
| Push payload + 4096-byte gate | `Models/PushPayload.swift` |
| Privacy TCC service contract (D-01) | `Models/PrivacyPermission.swift` |
| Typed defaults entries | `Models/DefaultsEntry.swift` |
| Action catalog + quick search | `Models/AppAction.swift` |
| App-action state machine + argv builders | `Models/AppActionModels.swift` |
| simctl seam (serialized, stdin-capable) | `Services/SimCtlService.swift` |

## Largest Files (by LOC)

| Rank | File | LOC | Notes |
|---|---|---|---|
| 1 | `Services/AppActionService.swift` | 906 | App-action facade + preset models/builders co-located (plan file-list constraint) — flagged for split (03-03 deviation 4) |
| 2 | `actions/UserDefaultsEditorView.swift` | 505 | Whole editor surface in one view (plan file-list constraint) — flagged (03-04 deviation 6) |
| 3 | `TrafficDetailView.swift` | 295 | Network detail sheet (4 tabs) — candidate for split |
| 4 | `EnvironmentOverrideService.swift` | 279 | Candidate for split |
| 5 | `actions/PushNotificationSectionView.swift` | 263 | Payload editor + D-01 guided-grant block |
| 6 | `actions/LocaleSectionView.swift` | 262 | Presets + manual rows + captions |
| 7 | `SideWindowController.swift` | 234 | Monitor growth |
| 8 | `NetworkEventModel.swift` | 208 | Network event + filter models |
| 9 | `SimulatorWindowTracker.swift` | 199 | — |

## Feature Sections (Side Panel — Tab-Based UI)

| Tab | Section | Features | Status |
|---|---|---|---|
| Capture | Captures | Screenshot, Record Screen, GIF Recording, Video Export | Complete (Phase 2) |
| Design | Design Tools | Grid Overlay, Safe Area Overlay, Ruler, Color Picker | Placeholder |
| Actions | Environment | Dark/Light Mode, Increase Contrast, Dynamic Type, Reduce Motion, Bold Text, Smart Invert, Reduce Transparency, Grayscale, On/Off Labels, Button Shapes, Differentiate Without Color | Complete |
| Actions | App Picker + Reset | DerivedData ∩ installed picker w/ running badge; Reset App Data, Uninstall, Clear Keychain (D-02, CA auto-reconcile) | Complete (Phase 3) |
| Actions | Deep Links | openurl with history/favorites (DeepLinkService, on the seam) | Complete |
| Actions | Push | Payload editor + templates + 4096-byte gate + D-01 guided grant | Complete (Phase 3) |
| Actions | Privacy | 12 TCC services grant/revoke (active-app scoped) + device-wide reset | Complete (Phase 3) |
| Actions | Locale | Language/locale/timezone presets + manual rows, relaunch-captioned | Complete (Phase 3) |
| Actions | Location | Validated coordinates + 6 city presets (tz-syncing) + visible Stop | Complete (Phase 3) |
| Actions | Clipboard | Two manual pbsync buttons, Mac ↔ Simulator | Complete (Phase 3) |
| Actions | Defaults | Typed UserDefaults editor (view/edit/add/delete) for the active app | Complete (Phase 3) |
| Actions | Quick Search | AppActionCatalog-driven section filter over all 9 sections | Complete (Phase 3) |
| Network | Network Conditions | Airplane Mode, Throttle Profiles (Off/EDGE/3G/LTE/Wi-Fi), effective-condition status, URLSession-scope caption | Complete |
| Network | Block Rules | Domain/path rule editor (add/toggle/delete, 50-rule cap), snapshot push | Complete |

**Wired sections** (exist in tabs, fully functional):
- Actions tab: `EnvironmentOverridesView` (11 a11y toggles) + the Phase 3 app-action surface — `AppPickerBar`, `AppResetSectionView`, `DeepLinkSectionView`/`DeepLinkService`, `PushNotificationSectionView`, `PrivacySectionView`, `LocaleSectionView`, `LocationSectionView`, `ClipboardSectionView`, `UserDefaultsEditorView` — behind `ActionSearchBar` quick search (`ActionsTabView`, catalog-driven)
- Network tab: `ConnectService` + `PulseServer` + `TrafficList`/`TrafficDetailView` + `CertificateSectionView`
- Network tab: `NetworkConditionService` + `CommandServer` pushing snapshots over `_booster-cmd._tcp.` (`NetworkConditionsSectionView`, `BlockRulesView`)

**Standalone views** (exist but not wired into tabs yet):
- `StatusBarSectionView` — status bar presets + custom (Complete)
- `BuildStatsSectionView` / `BuildChartView` — build history + bar chart (Complete)
- `AXTreeView` — accessibility tree inspector with lazy loading (Complete)
- `CameraView` — Mac camera input toggle (Complete)

### Network Manipulation (Phase 5) — primary types

| File | Primary types |
|---|---|
| `BoosterSimApp/Models/BoosterCommand.swift` | `BoosterCommand`, `ThrottleSpec`, `CommandFrame`, `ConditionVerdict`, `evaluate(request:snapshot:)`, `BoosterInternalGuard` |
| `BoosterSimApp/Models/BlockRule.swift` | `BlockRule` (+ `matches(_:)` string-only matcher) |
| `BoosterSimApp/Models/NetworkConditionProfile.swift` | `NetworkConditionProfile`, `ThrottleSchedule` |
| `BoosterSimApp/Services/CommandServer.swift` | `CommandServer` (`_booster-cmd._tcp.`, loopback bind, reconcile-on-connect) |
| `BoosterSimApp/Services/NetworkConditionService.swift` | `NetworkConditionService`, `NetworkConditionState` |
| `BoosterSimApp/Views/SideWindow/network/NetworkConditionsSectionView.swift` | `NetworkConditionsSectionView` |
| `BoosterSimApp/Views/SideWindow/network/BlockRulesView.swift` | `BlockRulesView` |
| `BoosterSimConnect/BoosterCommandClient.swift` | `BoosterCommandClient` (+ mirrored frame decode) |
| `BoosterSimConnect/NetworkConditionController.swift` | `NetworkConditionController`, mirrored `BoosterCommand`/`ThrottleSpec`/`BlockRule`, `ConditionVerdict`, `evaluateCondition(request:snapshot:)` |
| `BoosterSimConnect/BoosterNetworkProtocol.swift` | `BoosterNetworkProtocol` (chained URLSession init exchange) |
| `BoosterSimConnect/ThrottlePacing.swift` | `ThrottlePacing` (+ `Plan`, `plan(spec:chunkBytes:totalBytes:)`) |

Modified mount points (plans 01–03): `NetworkTabView` (sections mounted), `AppDelegate`/`SideWindowController`/`SideWindowView` (service ownership + environment injection), `BoosterSimConnect.swift` (`activate()` enables `BoosterNetworkProtocol` + `BoosterCommandClient`), `AppLogger` (new `network` category). See `docs/system-architecture.md` § Network Manipulation for the command flow, verdict order, scope limitations, pacing fidelity note, and persistence keys.

### App Actions (Phase 3) — primary types

| File | Primary types |
|---|---|
| `BoosterSimApp/Services/AppActionService.swift` | `AppActionService` (facade: refreshApps/resetApp/uninstallApp/clearKeychain, setPrivacy/resetAllPrivacy/openDeviceSettings, sendPush, applyLocale/setTimezone/readLocaleState, setLocation/clearLocation/applyLocationPreset, syncClipboard), `LocalePreset`, `CityPreset`, `ClipboardDirection`, `CoordinateError`, pure argv builders/parsers |
| `BoosterSimApp/Services/DerivedDataAppScanner.swift` | `DerivedDataAppScanner` (`scan(root:)`), `DiscoveredApp` (with `alternativePaths`) |
| `BoosterSimApp/Services/UserDefaultsEditorService.swift` | `UserDefaultsEditorService`, `UserDefaultsEditorOperation`, `DefaultsEditorError` |
| `BoosterSimApp/Services/SimCtlService.swift` | `SimCtlService.run(_:stdin:)` — serialized seam, concurrent pipe drains (modified, Phase 3) |
| `BoosterSimApp/Services/DeepLinkService.swift` | `DeepLinkService` — migrated onto the seam; `init(simCtl:defaults:)` (modified, Phase 3) |
| `BoosterSimApp/Models/AppActionModels.swift` | `AppActionOperation`, `ResetOutcome`, `AppKeychainResetting`, listapps/launchctl parsers, destructive-UDID guard |
| `BoosterSimApp/Models/PrivacyPermission.swift` | `PrivacyPermission` (12 verbatim TCC services), `PrivacyAction` |
| `BoosterSimApp/Models/PushPayload.swift` | `PushPayload` (+ `Aps`), `PushPayloadError`, `PushActionResult` |
| `BoosterSimApp/Models/DefaultsEntry.swift` | `DefaultsEntry`, `DefaultsEntryValue` (+ `simctlTypeArg`) |
| `BoosterSimApp/Models/AppAction.swift` | `AppAction`, `AppActionSection`, `EffectLatency`, `AppActionCatalog.filter(query:)` |
| `BoosterSimApp/Views/SideWindow/actions/*.swift` | `AppPickerBar`, `AppResetSectionView`, `PushNotificationSectionView`, `PrivacySectionView`, `LocaleSectionView`, `LocationSectionView`, `ClipboardSectionView`, `UserDefaultsEditorView`, `ActionSearchBar` |

Wave 0 suites (8 files): `AppActionServiceTests`, `DerivedDataAppScannerTests`, `DeepLinkServiceTests`, `PrivacyPermissionTests`, `PushPayloadTests`, `LocaleCommandTests`, `UserDefaultsEditorServiceTests`, `AppActionCatalogTests`.

Modified mount points (plans 01–04): `ActionsTabView` (catalog-driven section table + search), `AppDelegate`/`SideWindowController`/`SideWindowView` (service ownership + environment injection), `AppLogger` (new `actions` category), `.planning/codebase/CONVENTIONS.md` (async-exemption list shrinks to `CaptureService` alone). See `docs/system-architecture.md` § App Actions for the service split, seam hardening, active-app reconcile, effect-latency caption contract, defaults data path, and both platform limits (D-01/D-02).
