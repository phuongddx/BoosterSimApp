# BoosterSimApp

## What This Is

BoosterSimApp is a macOS 15+ menu-bar utility for iOS developers that attaches a floating
side panel directly to the iOS Simulator window. The panel exposes common simulator
workflow tools — environment toggles, certificate trust, network traffic inspection,
capture, design overlays, and app actions — without leaving the Simulator context. It is
a Swift 6 app (Xcode 16.3+) with two targets: the BoosterSimApp macOS app and the
BoosterSimConnect iOS framework that streams Pulse network events out of Simulator apps.

## Core Value

Common simulator tasks (env toggles, cert trust, traffic inspection) complete in ≤2 clicks
from the side panel.

## Requirements

### Validated

<!-- Shipped and confirmed valuable (inferred from completed roadmap phases + codebase). -->

- ✓ Simulator attachment — floating panel detects, tracks, and follows the Simulator window across move/resize/minimize with spring physics and a 0.5s polling fallback — Phase 1
- ✓ Full app shell — menu-bar status icon, 4-step permission onboarding, preferences, 4-tab side panel (Capture/Design/Actions/Network) — Phase 1
- ✓ Platform & system integration — status bar overrides, Mac→Simulator camera, 11 instant accessibility environment overrides, Xcode build stats, AX tree inspector — Phase 6
- ✓ Network inspection core — BoosterSimConnect + Pulse TCP pipeline, traffic viewer (filter/detail/cURL export), certificate trust management — delivered pre-.planning (Phase 5 scope)
- ✓ Network manipulation — command-channel engine (`BoosterCommand` v1 wire contract, `_booster-cmd._tcp.` CommandServer, reconcile-on-connect) + per-app Airplane Mode, throttle profiles (off/EDGE/3G/LTE/Wi-Fi, paced chunks), block rules (domain/path matcher + editor) — Phase 5 (verified 20/20)
- ✓ Capture tools — SCScreenshotManager window screenshots with 7 exact ASC presets + bezel modes + solid/gradient backgrounds, floating thumbnail, Desktop/clipboard/custom saves, SCRecordingOutput recordings at the 120 fps ceiling with Simulator-native touch indicators, GIF (centisecond-quantized) / MP4 / MOV export — Phase 2 (verified 4/4)
- ✓ App actions — hardened SimCtlService seam (stdin, concurrent pipes, serialized), DerivedData∩installed∩running app detection with picker, reset/uninstall + destructive keychain clear w/ CA auto-reconcile (D-02), push w/ 4096 gate + guided permission grant (D-01), deep links on-seam, 12-service privacy, locale/timezone relaunch, location presets + tz sync, pbsync clipboard, typed UserDefaults editor + whole-tab quick search — Phase 3 (verified 31/32)

### Active

<!-- Current scope. Building toward these. -->

- [ ] Phase 4 — Design tools: grid/safe-area overlays, ruler, magnifier/color picker, Figma/Sketch comparison
- [ ] Phase 7 — Polish & distribution: signing/notarization, auto-update, tests, privacy manifest, icon

### Out of Scope

<!-- Explicit boundaries. Includes reasoning to prevent re-adding. -->

- Health Data Generator (BoosterHealth companion app + HealthDataService) — built 2026-03-28, then removed from the repo (3b1015f); both journals superseded per user resolution 2026-08-29. Institutional knowledge stays in .planning/intel/context.md only; do not rebuild without explicit new scope.
- Strict zero-external-dependency policy — relaxed 2026-08-29: Apple frameworks only, exception Pulse/PulseProxy via BoosterSimConnect (linked on both native targets).

## Context

- Architecture: SwiftUI `@main` + `@NSApplicationDelegateAdaptor` hybrid; `AppDelegate`
  (@MainActor) owns core services (SimulatorWindowTracker dual-mode AXObserver + polling,
  PermissionManager, WindowEnumerator, WindowObserver, XcodeDetector) and feature
  services; NSPanel-based SideWindowPanel (`.floating` level) managed by
  SideWindowController with SpringAnimator tracking.
- Connect pipeline: ConnectService → PulseServer (NWListener TCP + Bonjour `_pulse._tcp.`)
  → PulseClientConnection → PulsePacketDecoder (5-byte header, zlib, Codable events);
  BoosterSimConnect is a loadable iOS framework (Bundle.load, DEBUG builds only).
- Command channel (Phase 5): NetworkConditionService → CommandServer (loopback NWListener
  + Bonjour `_booster-cmd._tcp.`) → BoosterCommandClient (length-prefixed v1 frames,
  CommandFrameAssembler reassembly, backoff restart) → NetworkConditionController →
  BoosterNetworkProtocol verdict enforcement (guard > airplane > rules > throttle).
- Codebase: ~115 Swift files. Design tab is the last placeholder; Actions tab ships the
  full action catalog (reset/keychain/push/deeplink/privacy/locale/location/clipboard/
  defaults + quick search); Network tab ships full inspection + manipulation; Capture
  tab ships screenshots (7 ASC presets), recordings (120 fps ceiling, touch
  indicators), and GIF/MP4/MOV export; Phase 6 views (StatusBar, BuildStats, AXTree,
  Camera) are complete but not yet wired into tabs.
- Institutional knowledge from the docs ingest (2026-08-29): `.planning/intel/`
  (SYNTHESIS.md, requirements/constraints/context/decisions, INGEST-CONFLICTS.md) and
  `.planning/codebase/` (7 codebase-map docs).
- Known open items from the connect journal (v2 candidates, see REQUIREMENTS.md): Code 8
  taskCreated support, real PulseMetrics timing, NWParameters.includePeerToPeer,
  end-to-end Connect verification with a real iOS app.

## Constraints

- **Platform (Tech stack)**: macOS 15+ only, no backwards-compat shims; Xcode 16.3+; iOS Simulator installed — target runtime is the two-target product (BoosterSimApp + BoosterSimConnect).
- **Language/concurrency**: Swift 6 strict concurrency enforced at compile time; @MainActor isolation; Combine @Published + Timer only, no async/await.
- **Dependencies**: Apple frameworks only — exception: Pulse/PulseProxy via BoosterSimConnect (user-resolved 2026-08-29).
- **Security model**: Non-sandboxed (ENABLE_APP_SANDBOX = NO) — required for Accessibility API, CGWindowList, simctl control; permissions requested at runtime (AXIsProcessTrusted, CGPreflightScreenCaptureAccess).
- **App lifecycle**: LSUIElement = true (menu-bar agent, no Dock icon).
- **Design system (SPEC)**: 12 constraints from docs/design-guidelines.md — utility-first native macOS feel; amber accent via asset catalog (#E8720C light / #F59E0B dark) for primary CTA/active indicators only; semantic system colors only; SF Pro + SF Symbols exclusively; 4pt spacing grid (Spacing enum); CornerRadius enum; SideWindowMetrics (260pt expanded / 28pt collapsed / 400pt min height); collapse/expand 0.2s ease-in-out (0.1s under Reduce Motion); panel frame animations via NSAnimationContext. Full detail: .planning/intel/constraints.md.
- **Code standards**: design tokens mandatory (never hardcode layout values); files < 200 LOC; all `xcrun simctl` through SimCtlService with UDID; AppLogger with sensitive-data redaction; try! / as! on user data prohibited. Full detail: .planning/intel/context.md (code-standards topic).

## Key Decisions

<!-- 0 ADRs ingested — none of these are locked; synthesized from system-architecture and code-standards intel. -->

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| SwiftUI @main + @NSApplicationDelegateAdaptor hybrid, MenuBarExtra .menu style | SwiftUI scene system + AppKit service ownership | ✓ Good |
| NSPanel (.floating, hidesOnDeactivate=false, fullScreenAuxiliary) over NSWindow | Panel must float above Simulator with custom focus rules | ✓ Good |
| Dual-mode Simulator tracking (AXObserver real-time + 0.5s CGWindowList polling fallback) | Functional before/without Accessibility permission | ✓ Good |
| `xcrun simctl spawn` for environment overrides | Instant effect, no target-app relaunch | ✓ Good |
| NWListener server-mode Connect with Bonjour (replaced NWBrowser client mode) | Simulator apps are Pulse clients; macOS must host the server | ✓ Good |
| BoosterSimConnect as loadable framework (Bundle.load, DEBUG builds only) | iOS framework cannot ship in macOS Contents/Frameworks (platform-strict validation) | ✓ Good |
| Pulse/PulseProxy exception to the Apple-only dependency policy | User-resolved 2026-08-29; powers Connect network inspection | — Pending |
| Non-sandboxed runtime | Required for AXIsProcessTrusted, CGWindowList, AXObserver, simctl | ✓ Good |
| Spring-physics panel tracking (CADisplayLink, stiffness 280 / damping 22, Reduce Motion aware) | Smooth follow; rigid 1:1 under Reduce Motion | ✓ Good |
| No async/await — Combine @Published + Timer only | Codebase-wide concurrency convention | ✓ Good |
| BoosterCommand v1 wire contract over `_booster-cmd._tcp.` (loopback NWListener + Bonjour, reconcile-on-connect) | Phase 5 manipulation channel mirrors the Connect server-mode pattern | ✓ Good |
| Verdict precedence guard > airplane > block rules > throttle in BoosterNetworkProtocol | Deterministic, testable ordering; guard unconditionally wins | ✓ Good |
| Throttle = latency delay + 1500-byte paced chunks via ThrottlePacing (as-shipped formula omits ÷1000 kilo factor — rescale is a v2 candidate) | Plan-pinned contract, unit-tested, docs disclose fidelity gap | ✓ Good (v2 rescale noted) |
| CommandBroadcasting protocol injection in NetworkConditionService | Unit tests/previews run without binding real NWListener/Bonjour (review WR-02) | ✓ Good |
| Screenshot via SCScreenshotManager one-shot + desktopIndependentWindow; recordings via SCStream + SCRecordingOutput direct-to-disk (finish-callback finalization) | Phase 2 capture spine; zero frame accumulation; macOS 15 floor | ✓ Good |
| Touch indicators via Simulator's own ShowSingleTouches pref (CFPreferences snapshot/restore, single scoped key) | Simulator renders the dots — capture includes them for free; no subprocess | ✓ Good |
| GIF export = AVAssetReader→ImageIO integer-centisecond delays, loop 0; MP4/MOV via AVAssetExportSession passthrough (HighestQuality re-encode fallback wired) | Apple-frameworks-only; deterministic timing | ✓ Good |
| Bezel modes none/simulatorNative/drawn (photoreal asset frames deferred pending license) | License-clean resolution recorded in 02-RESEARCH Open Questions | ✓ Good (v2 asset decision open) |
| SimCtlService as the sole simctl seam: concurrent pipe drains (deadlock-free >64KB), stdin support (≤64KB typed bound), machine-wide serialized invocations | Phase 3 spine; every destructive verb UDID-scoped, empty/booted refused | ✓ Good |
| D-01: push permission = guided manual grant (APNS probe + Open Settings, honest caption) | simctl privacy has NO notifications service — research-proven via positive controls | ✓ Good (platform limit documented) |
| D-02: keychain clear = device-wide destructive w/ red-typed blast-radius confirm + CertificateService resetKeychain → reconcile → CA reinstall | Per-app keychain clear does not exist on Simulator; reconcileStatus alone is status-only (would never restore trust) | ✓ Good |
| Active app = DerivedData scan ∩ listapps installed ∩ launchctl running badge + explicit picker | No frontmost verb exists; honest explicit selection over guessing | ✓ Good |
| UserDefaults editor reads the container plist file; writes via allowlist-validated spawn defaults (export verb silently unsupported) | Typed, testable, avoids the silent-empty-output trap | ✓ Good |

---
*Last updated: 2026-08-31 after Phase 3 (App Actions) completion*
