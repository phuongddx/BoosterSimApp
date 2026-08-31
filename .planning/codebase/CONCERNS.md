# Codebase Concerns

**Analysis Date:** 2026-08-31

## Tech Debt

**SimCtlService argv echo (privacy/logging gap — tracked, unfixed):**
- Issue: `SimCtlService.run` prints `xcrun simctl <full argv>` before every invocation. Phase 3 verbs put openurl URLs and `defaults` VALUES into argv, so the echo brushes the project's never-log-values/URLs prohibition at the seam. Related: `AppActionService` fail paths pass simctl stderr through logged `.public` (03-VERIFICATION IN-06).
- Files: `BoosterSimApp/Services/SimCtlService.swift:106`, `BoosterSimApp/Services/AppActionService.swift:600`
- Impact: Sensitive values (deep-link URLs, defaults values, push payload shapes) can land in the unified log/Console. Documented as the "Known logging gap" in `docs/system-architecture.md` § App Actions.
- Fix approach: Redact or parse-argv at the print site (switch to `AppLogger` with verb/outcome-only lines). Tracked as `.planning/phases/03-app-actions/deferred-items.md` #2 and 03-VERIFICATION IN-01/IN-06; deferred to a seam-hygiene pass.

**Stray `print()` diagnostics instead of AppLogger:**
- Issue: ~15 `print("[EnvOverride] …")` calls in `EnvironmentOverrideService` plus the SimCtl echo bypass the app's OSLog convention (`BoosterSimApp/Utilities/AppLogger.swift`); some log udid/enabled state, one logs raw errors (`EnvironmentOverrideService.swift:181`).
- Files: `BoosterSimApp/Services/EnvironmentOverrideService.swift` (throughout, e.g. :109, :155, :181), `BoosterSimApp/Services/SimCtlService.swift:106`
- Impact: Console-only noise, no privacy redaction, no category filtering; inconsistent with every post-Phase-1 service.
- Fix approach: Migrate to `AppLogger` categories (`.actions`/`.system`), redacting values.

**SimulatorWindowTracker bypasses the SimCtlService seam:**
- Issue: `refreshDeviceTypeCache()` spawns its own raw `Process` for `simctl list devices --json`, outside the machine-wide serial queue, and reads stdout with `readDataToEndOfFile()` AFTER `proc.waitUntilExit()` — the exact >64 KB pipe-buffer deadlock pattern `SimCtlService` was specifically hardened against (concurrent drains, `listapps` is already ~33 KB; `list devices --json` grows with runtime/device count).
- Files: `BoosterSimApp/Services/SimulatorWindowTracker.swift:63-95`
- Impact: Latent hang of a background QoS thread (and stale cache) on large device farms; also interleaves with queued SimCtlService invocations.
- Fix approach: Migrate to `SimCtlService.run` (protocol already exposes the seam). Accepted pre-existing deferred item — `.planning/STATE.md` deferred table, milestone v1.x (verifier disposition 2026-08-31).

**LOC-standard overruns (200-LOC house target, `docs/code-standards.md`):**
- Issue: `AppActionService.swift` is 957 LOC carrying refresh/reset/uninstall/keychain-clear/privacy/locale/location/clipboard/push facades plus their pure builders — by far the largest source file. 16 other production files exceed 200 LOC.
- Files: `BoosterSimApp/Services/AppActionService.swift` (957), `BoosterSimApp/Views/SideWindow/actions/UserDefaultsEditorView.swift` (505), `BoosterSimApp/Services/CaptureExporter.swift` (310), `BoosterSimApp/Views/SideWindow/network/TrafficDetailView.swift` (295), `BoosterSimApp/Services/EnvironmentOverrideService.swift` (279), `BoosterSimApp/Windows/SideWindowController.swift` (264), and 11 more (see `wc -l` top of tree)
- Impact: Review/edit friction; locale/location/clipboard sections are candidates for extraction like the earlier `DesignOverlayService+Presets` split.
- Fix approach: Extract extension files per section (the established `+Presets`/`+Import` pattern in `BoosterSimApp/Services/DesignOverlayService+Presets.swift`). RecordingService/CaptureExporter overruns were consciously accepted (02-VERIFICATION deviation note) — single-concern code.

**Package.resolved is untracked in git:**
- Issue: `BoosterSimApp.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved` shows as untracked (`?? BoosterSimApp.xcodeproj/project.xcworkspace/xcshareddata/`), so the REQ-nfr-03 dependency-pin assertion (`git diff --exit-code`) is vacuous at the git level; phases substituted sha256 content-stability checks.
- Files: `BoosterSimApp.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`, `.gitignore`
- Impact: A dependency bump would not be caught by the phase-gate git checks.
- Fix approach: Track the file in git (standing recommendation in `.planning/phases/05-network-tools/05-VERIFICATION.md` Known Limitation 2 and `.planning/STATE.md` infra concern).

**CertificateService.rotate is a nested-callback chain with in-memory retry state:**
- Issue: rotate = `keychain reset → deleteStoredFiles → generate → add-root-cert` as nested closures; `lastFailedAction` retry memory lives only in-process (lost on relaunch).
- Files: `BoosterSimApp/Services/CertificateService.swift:71-100,103-113`
- Impact: Deep nesting is hard to extend (e.g. auto-renewal before 90-day expiry); a crash mid-rotate leaves state recoverable only via `reconcileStatus` heuristics.
- Fix approach: Flatten into a `runChain`-style builder (pattern exists in `AppActionService.localeWriteChain`, `AppActionService.swift:770-787`).

**Device-info cache keyed by device display name:**
- Issue: `deviceInfoCache: [String: DeviceInfo]` maps device NAME → (type, udid); two simulators with the same name across runtimes collide (last wins), mis-attributing UDID/type. Window/app matching also compares `localizedName == "Simulator"` hardcoded.
- Files: `BoosterSimApp/Services/SimulatorWindowTracker.swift:27-30,80-95,166-175`
- Impact: Wrong UDID can flow into destructive verbs (reset/uninstall) in multi-device setups with duplicate names.
- Fix approach: Key by window title parse of UDID (window titles already carry the UDID when names are ambiguous) or resolve device↔window via CGWindow owner + `simctl list devices` udid directly.

## Known Bugs

**UI-test host early-exit flake (pre-existing, environmental):**
- Symptoms: `xcodebuild test` exits 65 with "Early unexpected exit, operation never finished bootstrapping … The test runner exited with code 0 before establishing connection" for 3–5 extra app launches after all Swift Testing cases pass.
- Files: `BoosterSimAppUITests/` (whole target), scheme test action
- Trigger: Unfiltered `xcodebuild test` on this machine; reproduced on pristine HEAD (proof in `.planning/phases/05-network-tools/deferred-items.md`).
- Workaround: Run `-only-testing:BoosterSimAppTests -skip-testing:BoosterSimAppUITests` and `-parallel-testing-enabled NO` for targeted suites (parallel runs also intermittently hang — 02-REVIEW-FIX.md). Follow-up (scheme composition / UI-test host permissions) is a documented do-not-fix-inside-a-feature-plan item.

**Bold Text override is the least reliable toggle on iOS 26.x:**
- Symptoms: Prior debugging (`plans/reports/debugger-0327-1228-bold-text-no-effect.md`) found the `com.apple.accessibility.enhanced-text-legibility` Darwin notification absent from UIKitCore on iOS 26.3 and XPC-based accessibility state that may need a SpringBoard respring to apply visually.
- Files: `BoosterSimApp/Services/EnvironmentOverrideService.swift:153-187` (3 plist keys across 2 domains + `notifyutil -p com.apple.accessibility.AccessibilityUIServer`)
- Trigger: Toggle Bold Text on an iOS 26.3 simulator and observe the target app.
- Workaround: None in-app; other 10 overrides are write+notify and verified instant. Treat any Bold-Text bug reports against the XPC-architecture findings first.

**Throttle pacing omits the ÷1000 kilo factor (as-shipped fidelity gap):**
- Symptoms: `chunkInterval = chunkBytes × 8 / downloadKbps` treats Kbps as bps, so 3G paces 1500 B at ~16 s/chunk (a 15 KB body ≈ 160 s) — far slower than physical 3G.
- Files: `BoosterSimApp/Models/NetworkConditionProfile.swift:88-91`, mirrored `BoosterSimConnect/ThrottlePacing.swift:36-43`; documented in `docs/system-architecture.md:467`
- Trigger: Apply the 3G profile and load any page.
- Workaround: None (plan-pinned formula); rescale is a known one-line v2 candidate (`NetworkConditionProfile.swift` + framework mirror must change together).

**MP4 passthrough re-encode fallback wired but never exercised:**
- Symptoms: HEVC-in-MP4 passthrough rejection triggers the A2 `HighestQuality` re-encode path (`CaptureExporter.swift:231-239`); that branch has no recorded exercise in any validation doc.
- Files: `BoosterSimApp/Services/CaptureExporter.swift:229-239`
- Trigger: Export a HEVC staged recording to MP4 on a host where passthrough is rejected.
- Workaround: MOV export passthrough unaffected.

**Docs/code mismatch on the no-Accessibility polling interval:**
- Symptoms: `docs/deployment-guide.md:43` and `.planning/ROADMAP.md` Phase 1 criteria say the panel "falls back to 0.5s polling" without Accessibility; the code polls at 2.0 s (`SimulatorWindowTracker.startPolling`).
- Files: `BoosterSimApp/Services/SimulatorWindowTracker.swift:171-175`, `docs/deployment-guide.md:43`
- Trigger: Launch without Accessibility permission and watch panel tracking latency.
- Workaround: None needed (functional, just slower than documented); fix the docs or the interval.

**Overlay tracking for multiple Simulator windows uses `classified.first`:**
- Symptoms: Active-simulator selection is the first enumerated window; CGWindowList ordering across multiple Simulator windows is not guaranteed stable, so the "active" device can appear to jump.
- Files: `BoosterSimApp/Services/SimulatorWindowTracker.swift:101-110`
- Trigger: Two visible Simulator windows; focus/move one.
- Workaround: None.

## Security Considerations

**Unencrypted CA private key at rest:**
- Risk: The local CA key is generated with openssl `-nodes` (no passphrase) and stored at `~/Library/Application Support/BoosterSimApp/Certificates/ca.key` — any process running as the user can read it and mint trusted certificates for every simulator where the CA is installed as root trust.
- Files: `BoosterSimApp/Services/CertificateStore.swift:12-19,70-93` (`-nodes`, staging dir 0o700, final files 0o600, `isExcludedFromBackup`, atomic backup/restore swap)
- Current mitigation: 0o600/0o700 permissions, backup-exclusion, staged generation, path redaction in errors (`redactPaths`), directory prepared with restrictive umask (0o077) during generation.
- Recommendations: Acceptable for a dev tool, but document the blast radius; consider macOS Keychain storage or key deletion-after-install if distribution ever broadens.

**Loopback command channel with no client authentication:**
- Risk: `CommandServer` binds 127.0.0.1 (threat T-05-01 mitigation — LAN peers cannot connect) and accepts any local process as a "client", advertising `_booster-cmd._tcp.` over Bonjour. A hostile local process could receive condition snapshots (airplane/throttle/block rules) — though it cannot inject anything: the receive loop only detects malformed input and drops the connection, never accepts frames (`CommandServer.swift:118-123`).
- Files: `BoosterSimApp/Services/CommandServer.swift:26-32,118-123`
- Current mitigation: Loopback-only bind, receive-loop drop policy, 10 MB frame cap, `X-Booster-Internal` anti-recursion guard in the enforcement chain.
- Recommendations: None required for local dev tool; if scope ever widens beyond Simulator-host communication, add a shared-secret handshake.

**Permission-dependent code paths (Accessibility / Screen Recording):**
- Risk: Core features silently degrade or no-op without TCC grants. Accessibility gates AXObserver window tracking; Screen Recording gates screenshot/recording/pixel-sampling.
- Files: `BoosterSimApp/Services/PermissionManager.swift:35-91` (preflights + 1 s grant-polling timers), `BoosterSimApp/Services/ScreenshotService.swift:39-41`, `BoosterSimApp/Services/RecordingService.swift:98-101`, `BoosterSimApp/Services/CaptureService.swift:202-206`, `BoosterSimApp/Services/PixelSamplerService.swift:33` (injectable preflight seam)
- Current mitigation: Every capture path re-preflights `CGPreflightScreenCaptureAccess()` before use; typed `CaptureError.screenRecordingDenied` with user-facing copy; onboarding flow (`BoosterSimApp/Views/Onboarding/OnboardingContainerView.swift`) polls for grants; degradation documented in `docs/deployment-guide.md`.
- Recommendations: Re-check permission state on app re-activation (revocation while running is only noticed on next preflight — acceptable, but worth a menu-bar indicator refresh).

**Non-sandboxed app:**
- Risk: `ENABLE_APP_SANDBOX = NO` is required for AX/CGWindowList/simctl; the app therefore has full user-level file access, and the DerivedData grant is honor-system.
- Files: `BoosterSimApp.xcodeproj` (build settings), `docs/deployment-guide.md` § Sandboxing Considerations
- Current mitigation: Documented as a deliberate distribution constraint (blocks Mac App Store; Phase 7 must notarize DMG instead).
- Recommendations: Keep surface minimal; do not add file-wide access features.

**DerivedData security-scoped bookmark handling is sloppy:**
- Risk: `checkDerivedData` discards the `startAccessingSecurityScopedResource()` result and never calls `stopAccessingSecurityScopedResource`; stale bookmarks fail silently (`derivedDataAccessGranted` stays false with no user signal). In a non-sandboxed app the scope calls are largely inert, making the `.withSecurityScope` usage misleading.
- Files: `BoosterSimApp/Services/PermissionManager.swift:129-157`
- Current mitigation: Manual re-selection path (`selectDerivedData`).
- Recommendations: Handle stale bookmarks by prompting re-grant; drop or correctly balance the scope calls.

**Destructive verbs are guarded but real:**
- Risk: `simctl keychain reset` (Clear Keychain / CA rotate) wipes the ENTIRE simulator keychain — other tools' certificates, passwords, tokens. "Reset App" clears the app container.
- Files: `BoosterSimApp/Services/AppActionService.swift:168-231` (`clearKeychain` with `isDestructiveUDID` guard + busy-guards + bounded waits), `BoosterSimApp/Views/SideWindow/CertificateSectionView.swift:34-39` (blast-radius confirmation dialog), `BoosterSimApp/Services/CertificateService.swift:91-107`
- Current mitigation: Confirmation dialogs naming the blast radius, ambiguous-UDID rejection (`booted`/empty), re-entrancy locks, automatic CA re-install after wipe.
- Recommendations: None — this is the model pattern; keep it for future destructive verbs.

**Open review advisories (Info-tier, consciously left open):**
- Risk: Minor honesty/hardening gaps: "Snapshot pushed to connected apps" caption overclaims when zero clients are connected (`BoosterSimApp/Views/SideWindow/network/NetworkConditionsSectionView.swift:126`, 05-REVIEW IN-01); 50-rule cap enforced only in the view, not `NetworkConditionService.addRule` (`BoosterSimApp/Services/NetworkConditionService.swift:118-136`, IN-03 — a bypassing caller silently defeats the bounded-matching invariant); Mac `BoosterCommand` fields are `var` vs framework mirror `let` (`BoosterSimApp/Models/BoosterCommand.swift:24-26`, IN-04 — drift invitation); hardcoded 2pt padding vs `Spacing.xxs` token (`BoosterSimApp/Views/SideWindow/network/BlockRulesView.swift:67`, IN-02).
- Files: as listed; full reports in `.planning/phases/05-network-tools/05-REVIEW.md:141-143` and `.planning/phases/02-capture-tools/02-REVIEW.md:124-142` (IN-01 gradient token `BoosterSimApp/Models/BezelMode.swift:39-49`; IN-02 raw `localizedDescription` reaching UI, `BoosterSimApp/Services/ScreenshotService.swift:17-22`; IN-03 eager Desktop folder creation, `BoosterSimApp/Services/CaptureService.swift:228-230`)
- Impact: Low; each has a recorded rationale for deferral.
- Fix approach: One cleanup pass can sweep all IN-tier items.

## Performance Bottlenecks

**Machine-wide serial simctl queue:**
- Problem: Every `xcrun simctl` invocation queues behind one global serial `DispatchQueue`; a slow verb (install, listapps ~33 KB) delays all UI verbs app-wide. Per-verb Combine timeout 30 s; drain backstop 60 s.
- Files: `BoosterSimApp/Services/SimCtlService.swift:94-99,140-147,171-175`
- Cause: Deliberate (03-REVIEW WR-03) to prevent pipe deadlocks and interleaving.
- Improvement path: Acceptable at current scale; if latency bites, partition queues per-udid or move read-only verbs to a second lane. Note `EnvironmentOverrideService` init spawns a `defaults read` per key at startup — ~12 sequential spawns through the single lane on every launch (`BoosterSimApp/Services/EnvironmentOverrideService.swift:52-104`).

**Main-thread window scanning cadence:**
- Problem: `SimulatorWindowTracker` runs a full `CGWindowList` scan + classification every 2.0 s on the main thread, plus a full `scanAndUpdate()` on every AX lifecycle event; device cache refresh parses full `list devices --json`.
- Files: `BoosterSimApp/Services/SimulatorWindowTracker.swift:97-126,171-175`
- Cause: Poll is the no-Accessibility fallback and edge-case backstop; drag has an AX fast path (`WindowObserver.onFrameChanged`) that bypasses scans.
- Improvement path: Coalesce scans, diff before publishing, or move classification off-main (device cache already is).

**Permission polling timers:**
- Problem: Two 1 s repeating Timers during onboarding permission flow (Accessibility, Screen Recording).
- Files: `BoosterSimApp/Services/PermissionManager.swift:65-91`
- Cause: TCC has no grant notification API.
- Improvement path: Negligible; keep bounded lifetime (timers self-invalidate on grant) — they do.

**Bounded buffers (healthy, listed for reference):**
- Traffic events capped at 500 (`BoosterSimApp/Services/ConnectService.swift:16,112-117`); Pulse receive buffer capped at 10 MB (`BoosterSimApp/Services/PulseClientConnection.swift:25,88-91`); stdin capped at 64 KB pipe bound (`BoosterSimApp/Services/SimCtlService.swift:28-31`).

## Fragile Areas

**Window-system integration (tracking + overlay placement):**
- Files: `BoosterSimApp/Services/SimulatorWindowTracker.swift`, `BoosterSimApp/Services/WindowObserver.swift`, `BoosterSimApp/Services/WindowEnumerator.swift`, `BoosterSimApp/Windows/PositionCalculator.swift`, `BoosterSimApp/Windows/DesignOverlayController.swift`
- Why fragile: AXObserver C-callback bridging with a hand-managed retained `refcon` pointer (`WindowObserver.swift:31` `selfPtr`, released in `stopObserving`); Quartz(top-origin)→AppKit(bottom-origin) Y-flip against the primary screen height (`WindowObserver.swift:136-143`); force casts `val as! AXValue` (`BoosterSimApp/Services/AXInspectorService.swift:95`, `BoosterSimApp/Services/WindowObserver.swift:138-140` — guarded by `CFGetTypeID` checks but crash-on-mistake style); device classification by `deviceTypeIdentifier` substring heuristics (`SimulatorWindowTracker.swift:76-87`).
- Safe modification: Change tracking behavior behind the existing seams (`WindowObserver` callbacks, `onFrameChanged` fast path); never touch the refcon lifecycle without reading `axCallback`. Tests: none cover this layer (see Test Coverage Gaps) — verify manually with Simulator move/resize/minimize.
- Test coverage: No unit tests for tracker/observer/enumerator or PositionCalculator placement math against live windows (Phase 7 plans PositionCalculator coverage).

**Schema-synced framework mirrors (BoosterSimConnect):**
- Files: `BoosterSimApp/Models/BoosterCommand.swift` ⇄ `BoosterSimConnect/BoosterNetworkProtocol.swift`; `BoosterSimApp/Models/BlockRule.swift` (`matches`) ⇄ `BoosterSimConnect/NetworkConditionController.swift` (matcher mirror); `BoosterSimApp/Models/NetworkConditionProfile.swift` (`ThrottleSchedule`) ⇄ `BoosterSimConnect/ThrottlePacing.swift`
- Why fragile: Enforcement semantics must stay byte-identical across the macOS app target and the iOS framework target; the macOS app compiles the shared folder EMPTY (`#if DEBUG && targetEnvironment(simulator)`), so a framework-only break does not fail the app build — this already shipped one undetected break (ea7b024 deleted `BoosterCommandClient` frame constants; restored in 3a7b…/3a1bb34 per STATE decisions).
- Safe modification: Every semantic change edits BOTH files in the same commit and builds the `BoosterSimConnect` scheme explicitly; Data-slice offset math must copy to `[UInt8]` first (the startIndex SIGTRAP trap, fixed in `BoosterSimApp/Models/BoosterCommand.swift:79-83`).
- Test coverage: `BoosterSimAppTests/CommandPayloadTests.swift`, `ConditionVerdictTests.swift`, `BlockRuleTests.swift`, `NetworkConditionProfileTests.swift` pin both sides' semantics.

**Certificate trust state machine + reconcile heuristic:**
- Files: `BoosterSimApp/Services/CertificateService.swift:31-163`, `BoosterSimApp/Services/CertificateStore.swift`
- Why fragile: `reconcileStatus` never queries the simulator's actual trust store — it infers installed state from a persisted fingerprint+UDID pair in UserDefaults ("high confidence" comment at `CertificateService.swift:139-146`). Wiping the simulator keychain outside the app (xcodebuild resets, `simctl erase`) desyncs the UI status. `rotate` is a 4-step nested chain; `retry` depends on in-memory `lastFailedAction`.
- Safe modification: Extend via the `AppKeychainResetting` protocol seam (tests pin delegate order with a scripted double — `BoosterSimApp/Models/AppActionModels.swift:134-148`).
- Test coverage: `BoosterSimAppTests/CertificateServiceTests.swift` covers operation transitions; reconcile heuristics are not covered against live simctl.

**SimCtlService seam:**
- Files: `BoosterSimApp/Services/SimCtlService.swift`
- Why fragile: Correctness depends on three interlocking invariants — concurrent pipe drains (else >64 KB deadlock), stdin bounded to 64 KB, promise-fires-exactly-once (`Once`) across drain-timeout vs late-reader races. Any refactor must preserve all three; a hung grandchild process is NOT killed on drain timeout (the queue frees but the orphan lives).
- Safe modification: Add verbs via the `SimCtlRunning` protocol; keep pipe plumbing untouched. Tests: `BoosterSimAppTests/SimCtlServiceTests.swift`, scripted doubles in `BoosterSimAppTests/ScriptedSimCtl.swift`.

## Scaling Limits

**Single serial simctl lane:**
- Current capacity: One subprocess at a time; each verb ≤30 s timeout.
- Limit: Parallel multi-device tooling or long installs will serialize visibly (e.g. startup performs ~12 queued `defaults read` spawns).
- Scaling path: Per-UDID queues or a read-only fast lane (see Performance Bottlenecks).

**Traffic history window:**
- Current capacity: 500 events in memory (`ConnectService.swift:16`).
- Limit: Long inspection sessions silently drop oldest events; no persistence/export of the full stream beyond per-event cURL copy.
- Scaling path: Ring-buffer to disk or raise cap with lazy rendering.

**Device farm:**
- Current capacity: All booted simulators tracked; AX observer per Simulator-app PID.
- Limit: `list devices --json` growth (deadlock-prone raw spawn, see Tech Debt) and duplicate device-name cache collisions.
- Scaling path: SimCtlService migration + UDID-keyed cache (fixes above).

## Dependencies at Risk

**Pulse 5.2.2 (sole third-party SPM dependency):**
- Risk: Explicit policy exception to the Apple-only dependency rule (user-resolved 2026-08-29, STATE decisions); upstream API changes or abandonment affect the inspection core and the schema-mirrored framework files.
- Impact: Traffic ingestion, decode, and detail views.
- Migration plan: The seam is narrow (`PulseServer`/`PulseClientConnection`/`PulsePacketDecoder` in `BoosterSimApp/Services/`); the protocol is small enough to vendor if frozen.

**System binaries invoked by absolute path:**
- Risk: `/usr/bin/xcrun` (`SimCtlService.swift:116`) and `/usr/bin/openssl` (`CertificateStore.swift:74-76`, existence-checked) are hardcoded; Apple has deprecated the openssl binary for years.
- Impact: Missing/moved binaries produce typed failures (`xcrunNotFound`, `opensslNotFound`) — graceful, but no alternative path.
- Migration plan: `xcrun` is stable; for openssl consider CryptoKit/system Security frameworks long-term (cert generation is the only use).

**macOS 15+ APIs:**
- Risk: SCRecordingOutput (`stream.addRecordingOutput`), ScreenCaptureKit preflights, `sizingOptions` SwiftUI APIs pin the floor at macOS 15 Sequoia; no availability fallbacks exist.
- Impact: None locally (dev machine is on 25.x); restricts distribution reach (Phase 7 decision).
- Migration plan: Accept as minimum OS; document in deployment guide (already noted).

## Missing Critical Features

**Phase 6 views not wired into the side panel:**
- Problem: `StatusBarSectionView`, `BuildStatsSectionView`/`BuildChartView`, `AXTreeView`, `CameraView` are complete implementations with no tab mount point — repeatedly deferred (Phases 5, 2, 3 all closed without wiring; standing STATE.md concern).
- Files: `BoosterSimApp/Views/SideWindow/` (`tabs/`, `MenuBar/` per `docs/codebase-summary.md:274-277`); services exist (`BoosterSimApp/Services/StatusBarService.swift`, `BuildStatsService.swift`, `AXInspectorService.swift`, `CameraService.swift`)
- Blocks: Phase 6 user-facing value; the "11 accessibility overrides" and AX inspector criteria are only reachable pre-wiring via nothing.

**Distribution readiness (Phase 7 not started):**
- Problem: No code signing team, notarization, Sparkle auto-update, privacy manifest, or app icon polish; non-sandbox documented but DMG pipeline unexecuted.
- Files: `BoosterSimApp.xcodeproj`, `docs/deployment-guide.md` § Distribution (Future)
- Blocks: Any external distribution; REQ-roadmap-phase7-polish-distribution.

**Network timing truth (v2 candidates NET-01…04):**
- Problem: `TrafficDetailView` metrics tab shows placeholder timing data (real `PulseMetrics` deferred); Pulse Code 8 (`taskCreated`) in-progress tracking unsupported; `includePeerToPeer` flag value uninvestigated (`docs/journals/2026-04-12-booster-sim-connect-activation.md:94-96`).
- Files: `BoosterSimApp/Views/SideWindow/network/TrafficDetailView.swift`, `BoosterSimApp/Services/CommandServer.swift:28`
- Blocks: Accurate per-request latency display.

**Photoreal bezel assets:**
- Problem: License-clean drawn/screenshot background modes shipped; photoreal device-frame images deferred pending a licensing decision (STATE deferred table, v2).
- Files: `BoosterSimApp/Models/BezelMode.swift`, `BoosterSimApp/Utilities/CaptureCompositor.swift`

## Test Coverage Gaps

**Window tracking layer (highest-value gap):**
- What's not tested: `SimulatorWindowTracker` (device classification, cache, scan/observer lifecycle), `WindowObserver` (AX bridging, Y-flip), `WindowEnumerator`, `PositionCalculator`.
- Files: `BoosterSimApp/Services/SimulatorWindowTracker.swift`, `BoosterSimApp/Services/WindowObserver.swift`, `BoosterSimApp/Services/WindowEnumerator.swift`, `BoosterSimApp/Windows/PositionCalculator.swift`
- Risk: The most geometry- and API-sensitive code has zero regression protection; the known duplicate-name and first-window bugs above would be caught trivially by pure-function tests.
- Priority: High (Phase 7 roadmap already names PositionCalculator/WindowEnumerator).

**Permissions and platform services:**
- What's not tested: `PermissionManager` (bookmark resolve/polling), `StatusBarService`, `CameraService`, `BuildStatsService`, `XcodeDetector`.
- Files: `BoosterSimApp/Services/PermissionManager.swift`, `BoosterSimApp/Services/StatusBarService.swift`, `BoosterSimApp/Services/CameraService.swift`, `BoosterSimApp/Services/BuildStatsService.swift`, `BoosterSimApp/Services/XcodeDetector.swift`
- Risk: Permission regressions surface only in manual runs; Xcode path resolution drift breaks DerivedData app scanning.
- Priority: Medium.

**Connect transport:**
- What's not tested: `PulseServer`, `PulseClientConnection`, `PulsePacketDecoder` have no dedicated suites (framing coverage lives in `BoosterSimAppTests/CaptureFramingTests.swift`/`CommandPayloadTests.swift` at the payload level, not the live transport); no e2e Connect test (explicit v2 candidate NET-04).
- Files: `BoosterSimApp/Services/PulseServer.swift`, `BoosterSimApp/Services/PulseClientConnection.swift`, `BoosterSimApp/Services/PulsePacketDecoder.swift`
- Risk: Decode/transport regressions (the class of SIGTRAP and split-frame bugs already hit in Phase 5) reach users first.
- Priority: Medium.

**Media pipelines:**
- What's not tested: `RecordingService`/`ScreenshotService`/`CaptureExporter` beyond config/builders (`CaptureExportConfigTests`, `CaptureSettingsTests`); actual SCK/AVFoundation behavior requires a live window and is validated by manual smoke only.
- Files: `BoosterSimApp/Services/RecordingService.swift`, `BoosterSimApp/Services/ScreenshotService.swift`, `BoosterSimApp/Services/CaptureExporter.swift`
- Risk: Accepted project-wide (TCC-gated APIs); the MP4 A2 re-encode branch is the one unexercised branch with a plausible failure mode.
- Priority: Low (structural choice), with a targeted smoke for A2.

---

*Concerns audit: 2026-08-31*
