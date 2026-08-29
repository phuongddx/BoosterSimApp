# Ingested Requirements (from PRD-classified docs)

Sources: docs/project-overview-pdr.md (PRD), docs/project-roadmap.md (PRD).
IDs preserve source numbering for traceability (FR-xx / NFR-xx → REQ-fr-xx / REQ-nfr-xx).

## REQ-fr-01
- source: docs/project-overview-pdr.md
- description: Detect running iOS Simulator windows via CGWindowListCopyWindowInfo
- acceptance: Simulator windows are enumerated via CGWindowListCopyWindowInfo
- scope: simulator detection

## REQ-fr-02
- source: docs/project-overview-pdr.md
- description: Real-time position tracking via AXObserver callbacks (move, resize, minimize events)
- acceptance: AXObserver callbacks deliver move, resize, and minimize events in real time
- scope: simulator detection, panel tracking

## REQ-fr-03
- source: docs/project-overview-pdr.md
- description: Side panel floats above all windows including Simulator (NSPanel level .floating)
- acceptance: Panel renders above all windows, including the Simulator window
- scope: side panel

## REQ-fr-04
- source: docs/project-overview-pdr.md
- description: Panel repositions when Simulator moves or resizes
- acceptance: Panel position follows Simulator move/resize events
- scope: side panel tracking

## REQ-fr-05
- source: docs/project-overview-pdr.md
- description: Panel hides when no Simulator is detected
- acceptance: Panel is hidden while no Simulator window exists
- scope: side panel lifecycle

## REQ-fr-06
- source: docs/project-overview-pdr.md
- description: Supports 4 position modes: left, right, bottom, dynamic
- acceptance: All four position modes (left, right, bottom, dynamic) are selectable and functional
- scope: side panel positioning

## REQ-fr-07
- source: docs/project-overview-pdr.md
- description: Collapse to 28pt strip; expand to 260pt panel
- acceptance: Collapsed state is a 28pt strip; expanded state is a 260pt panel
- scope: side panel dimensions

## REQ-fr-08
- source: docs/project-overview-pdr.md
- description: Menu bar icon shows Simulator connection status
- acceptance: Menu bar icon reflects Simulator connected/disconnected state (bolt.fill / bolt.slash)
- scope: menu bar

## REQ-fr-09
- source: docs/project-overview-pdr.md
- description: First-launch onboarding flow (4 steps, permission setup)
- acceptance: 4-step onboarding runs on first launch covering Accessibility, Screen Recording, DerivedData permissions
- scope: onboarding

## REQ-fr-10
- source: docs/project-overview-pdr.md
- description: Preferences (position, launch at login, Xcode path)
- acceptance: Preferences window exposes panel position, launch-at-login, and Xcode path settings
- scope: preferences

## REQ-fr-11
- source: docs/project-overview-pdr.md
- description: Cmd+B toggles panel; Cmd+W hides it; Cmd+, opens Preferences
- acceptance: All three keyboard shortcuts behave as specified
- scope: keyboard shortcuts

## REQ-fr-12
- source: docs/project-overview-pdr.md
- description: Panel hides when Simulator loses focus (app activation change)
- acceptance: Panel hides on Simulator focus loss and re-shows on Simulator re-focus
- scope: side panel lifecycle

## REQ-fr-13
- source: docs/project-overview-pdr.md
- description: Tab-based navigation (Capture, Design, Actions, Network)
- acceptance: Side panel exposes exactly these four tabs with icon-only tab bar
- scope: side panel navigation

## REQ-fr-14
- source: docs/project-overview-pdr.md
- description: Environment overrides apply instantly (no app relaunch) via xcrun simctl spawn
- acceptance: Toggles take effect immediately without relaunching the target app
- scope: environment overrides

## REQ-fr-15
- source: docs/project-overview-pdr.md
- description: Spring-physics tracking for smooth panel position following (CADisplayLink, reducedMotion-aware)
- acceptance: Panel follows Simulator with spring physics; disables spring under Reduce Motion
- scope: panel animation

## REQ-fr-16
- source: docs/project-overview-pdr.md
- description: Certificate trust management (CA generation, install, rotate, reset in Simulator keychain)
- acceptance: CA generation, install, rotate, and reset flows work against the Simulator keychain; trust state persists across sessions
- scope: certificates

## REQ-nfr-01
- source: docs/project-overview-pdr.md
- description: macOS 15+ only (no backwards compat shims)
- acceptance: App targets macOS 15 Sequoia minimum; no compatibility shims present
- scope: platform support

## REQ-nfr-02
- source: docs/project-overview-pdr.md
- description: Swift 6 strict concurrency (no data races)
- acceptance: Swift 6 strict concurrency enforced at compile time
- scope: language/concurrency

## REQ-nfr-03
- source: docs/project-overview-pdr.md
- description: Zero external dependencies (Apple frameworks only)
- acceptance: No external package dependencies; Apple frameworks only
- scope: external dependencies
- VARIANT CONFLICT (see INGEST-CONFLICTS.md WARNING): docs/project-roadmap.md Phase 5 records
  "BoosterSimConnect — iOS framework with PulseProxy activation (Pulse/PulseProxy SPM integrated)";
  BoosterSimApp.xcodeproj/project.pbxproj links Pulse 5.1.0+ (github.com/kean/Pulse.git) and
  PulseProxy on BOTH the BoosterSimApp and BoosterSimConnect native targets. Both variants
  preserved; user must resolve.

## REQ-nfr-04
- source: docs/project-overview-pdr.md
- description: Non-sandboxed (runtime permissions via AXIsProcessTrusted, CGPreflightScreenCaptureAccess)
- acceptance: App runs non-sandboxed; permissions requested at runtime
- scope: security model

## REQ-nfr-05
- source: docs/project-overview-pdr.md
- description: LSUIElement = true (no Dock icon)
- acceptance: App runs as menu-bar agent (no Dock icon)
- scope: app lifecycle

## REQ-nfr-06
- source: docs/project-overview-pdr.md
- description: 0.5s polling fallback when Accessibility permission not granted
- acceptance: Window tracking degrades to 0.5s polling without Accessibility permission
- scope: simulator detection

## REQ-product-success-criteria
- source: docs/project-overview-pdr.md
- description: Product-level success criteria for the delivered MVP scope
- acceptance: (1) Side panel appears and tracks Simulator position within 0.5s; (2) collapse/expand
  animation is smooth (0.2s, respects reduced motion); (3) onboarding completes and permissions
  are granted before first use; (4) app stays running when all windows closed (menu bar only);
  (5) zero crashes on Simulator launch/quit/move/resize lifecycle
- scope: product quality

## REQ-roadmap-phase1-foundation
- source: docs/project-roadmap.md
- description: Core app shell with simulator attachment. Status per source: Complete.
- acceptance: [x] SwiftUI App + AppKit hybrid entry point; [x] menu bar icon (bolt.fill / bolt.slash);
  [x] floating side panel (NSPanel, .floating level); [x] Simulator window detection
  (CGWindowListCopyWindowInfo); [x] real-time position sync (AXObserver + 0.5s poll fallback);
  [x] 4 position modes (left, right, bottom, dynamic); [x] collapse/expand animation (respects
  Reduce Motion); [x] spring-physics panel tracking (CADisplayLink, auto-stops at rest);
  [x] smart side-switch detection (snap + spring on position mode change); [x] permission
  onboarding (Accessibility, Screen Recording, DerivedData); [x] preferences window (position,
  launch at login); [x] AppSettings persistence via @AppStorage; [x] design tokens system
  (Spacing, CornerRadius, SideWindowMetrics); [x] tab-based UI (Capture, Design, Actions,
  Network, icon-only header); [x] feature section placeholders
- scope: foundation

## REQ-roadmap-phase2-capture-tools
- source: docs/project-roadmap.md
- description: Screenshot and screen recording from side panel. Status per source: Not started.
- acceptance: [ ] Screenshot capture (ScreenCaptureKit); [ ] device bezels overlay on screenshots;
  [ ] wallpaper / background padding for screenshots; [ ] App Store Connect framing optimization;
  [ ] floating thumbnail preview after capture; [ ] save to Desktop / clipboard / custom path;
  [ ] screen recording (ScreenCaptureKit); [ ] 120 FPS recording support; [ ] touch indicators
  visible during recordings; [ ] GIF export from recording; [ ] video export (MP4/MOV)
- scope: capture tools

## REQ-roadmap-phase3-app-actions
- source: docs/project-roadmap.md
- description: Common simulator dev actions from side panel. Status per source: Not started.
- acceptance: [ ] Reset app (terminate + clear app container); [ ] clear Keychain items for active
  app; [ ] send push notification (APNs simulator payload); [ ] grant / revoke push notification
  permissions; [ ] trigger deep link (open URL in simulator); [ ] clipboard sync (Mac ↔ Simulator
  bidirectional); [ ] locale switcher (relaunch in different locale); [ ] dark / light mode quick
  toggle; [ ] Dynamic Type size control; [ ] location simulation (GPS coordinates + timezone sync);
  [ ] UserDefaults editor (view / edit / add keys); [ ] quick Action search (filter long action
  lists); [ ] app bundle ID detection from DerivedData
- scope: app actions

## REQ-roadmap-phase4-design-tools
- source: docs/project-roadmap.md
- description: Visual overlays on top of Simulator window. Status per source: Not started.
- acceptance: [ ] Grid overlay (8pt / 4pt grid lines); [ ] safe area overlay (display safe area
  insets); [ ] ruler tool with distance measurement between rulers; [ ] magnifier with color
  picker (sample pixel from screen); [ ] design comparison overlay (import Figma / Sketch
  artboard); [ ] overlay persists when app loses focus; [ ] overlay persistence (toggle on/off
  per tool)
- scope: design tools

## REQ-roadmap-phase5-network-tools
- source: docs/project-roadmap.md
- description: Network inspection and manipulation. Status per source: In progress — Connect,
  traffic viewer, certificates, protocol parsing complete; throttle/airplane/block pending.
- acceptance: [x] ConnectService — Pulse TCP server (NWListener) receiving events from Simulator
  apps; [x] PulseServer + PulseClientConnection; [x] PulsePacketDecoder — binary protocol parser
  (5-byte header, zlib, Codable Pulse events); [x] BoosterSimConnect — iOS framework with
  PulseProxy activation (Pulse/PulseProxy SPM integrated); [x] traffic viewer — filter by
  method/status, auto-scroll list, detail sheet (Summary/Headers/Body/Metrics), cURL export;
  [x] connection UI — status banner, setup instructions with copy-to-clipboard; [x] certificate
  trust management (CA generation, install/rotate/reset in Simulator keychain); [x] network
  event parsing; [ ] network speed control / throttle; [ ] Simulator Airplane Mode (per-app,
  no Mac impact); [ ] request blocking (domain/path rules)
- scope: network tools

## REQ-roadmap-phase6-platform-system
- source: docs/project-roadmap.md
- description: Broader Simulator and system integration. Status per source: Complete.
- acceptance: [x] Configurable status bar (time, battery, signal) — 4 presets + custom controls;
  [x] Simulator camera (Mac camera as Simulator input) — AX menu automation; [x] environment
  overrides (accessibility settings) — 11 a11y toggles; [x] Xcode build statistics (build count,
  time graphs) — build history polling + Canvas bar chart; [x] accessibility tree inspector
  (VoiceOver navigator) — lazy AX tree walker + highlight overlay
- scope: platform & system

## REQ-roadmap-phase7-polish-distribution
- source: docs/project-roadmap.md
- description: App Store or direct distribution readiness. Status per source: Not started.
- acceptance: [ ] Code signing + notarization; [ ] App Sandbox evaluation (or document
  non-sandbox requirement); [ ] Sparkle auto-update (or Mac App Store updates); [ ] comprehensive
  unit tests (PositionCalculator, WindowEnumerator, AppSettings); [ ] UI tests for onboarding
  flow; [ ] privacy manifest (required for App Store); [ ] app icon design; [ ] marketing
  page / README polish
- scope: distribution
