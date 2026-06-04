# Project Roadmap

## Current Status: Phase 1 Complete + Phase 5 (partial) + Phase 6 Complete

Core infrastructure (Phase 1), tab-based UI, and developer tool features (Phase 6) are fully implemented. Phase 5 certificate trust management, Connect traffic viewer, and Pulse protocol server are complete. BoosterSimConnect iOS framework is fully activated with Pulse/PulseProxy SPM. Phases 2-4, remaining Phase 5 items (throttle, block), and Phase 7 (distribution) are not started.

---

## Phase 1 — Foundation (Complete)

**Goal:** Core app shell with simulator attachment

- [x] SwiftUI App + AppKit hybrid entry point
- [x] Menu bar icon (bolt.fill / bolt.slash)
- [x] Floating side panel (NSPanel, .floating level)
- [x] Simulator window detection (CGWindowListCopyWindowInfo)
- [x] Real-time position sync (AXObserver + 0.5s poll fallback)
- [x] 4 position modes: left, right, bottom, dynamic
- [x] Collapse/expand animation (respects Reduce Motion)
- [x] Spring-physics panel tracking (CADisplayLink-driven, auto-stops at rest)
- [x] Smart side-switch detection (snap + spring on position mode change)
- [x] Permission onboarding (Accessibility, Screen Recording, DerivedData)
- [x] Preferences window (position, launch at login)
- [x] AppSettings persistence via @AppStorage
- [x] Design tokens system (Spacing, CornerRadius, SideWindowMetrics)
- [x] Tab-based UI (Capture, Design, Actions, Network tabs with icon-only header)
- [x] Feature section placeholders (Captures, App Actions, Design Tools, Network)

---

## Phase 2 — Capture Tools

**Goal:** Screenshot and screen recording from side panel

- [ ] Screenshot capture (ScreenCaptureKit)
- [ ] Device bezels overlay on screenshots
- [ ] Wallpaper / background padding for screenshots
- [ ] App Store Connect framing optimization
- [ ] Floating thumbnail preview after capture
- [ ] Save to Desktop / clipboard / custom path
- [ ] Screen recording (ScreenCaptureKit)
- [ ] 120 FPS recording support
- [ ] Touch indicators visible during recordings
- [ ] GIF export from recording
- [ ] Video export (MP4/MOV)

---

## Phase 3 — App Actions

**Goal:** Common simulator dev actions from side panel

- [ ] Reset app (terminate + clear app container)
- [ ] Clear Keychain items for active app
- [ ] Send push notification (APNs simulator payload)
- [ ] Grant / revoke push notification permissions
- [ ] Trigger deep link (open URL in simulator)
- [ ] Clipboard sync (Mac ↔ Simulator bidirectional)
- [ ] Locale switcher (relaunch in different locale)
- [ ] Dark / light mode quick toggle
- [ ] Dynamic Type size control
- [ ] Location simulation (GPS coordinates + timezone sync)
- [ ] UserDefaults editor (view / edit / add keys)
- [ ] Quick Action search (filter long action lists)
- [ ] App bundle ID detection from DerivedData

---

## Phase 4 — Design Tools

**Goal:** Visual overlays on top of Simulator window

- [ ] Grid overlay (8pt / 4pt grid lines)
- [ ] Safe area overlay (display safe area insets)
- [ ] Ruler tool with distance measurement between rulers
- [ ] Magnifier with color picker (sample pixel from screen)
- [ ] Design comparison overlay (import Figma / Sketch artboard)
- [ ] Overlay persists when app loses focus
- [ ] Overlay persistence (toggle on/off per tool)

---

## Phase 5 — Network Tools

**Goal:** Network inspection and manipulation

- [x] ConnectService — Pulse TCP server (NWListener) receiving events from Simulator apps
- [x] PulseServer + PulseClientConnection — NWListener TCP server, per-client protocol handler
- [x] PulsePacketDecoder — Binary protocol parser (5-byte header, zlib, Codable Pulse events)
- [x] BoosterSimConnect — iOS framework with PulseProxy activation (Pulse/PulseProxy SPM integrated)
- [x] Traffic viewer — Filter by method/status, traffic list with auto-scroll, detail sheet (Summary/Headers/Body/Metrics), cURL export
- [x] Connection UI — Status banner, setup instructions with copy-to-clipboard
- [x] Certificate trust management (CA generation, install/rotate/reset in Simulator keychain)
- [x] Network event parsing (Pulse binary protocol decode via PulsePacketDecoder)
- [ ] Network speed control / throttle
- [ ] Simulator Airplane Mode (per-app, no Mac impact)
- [ ] Request blocking (domain/path rules)

---

## Phase 6 — Platform & System (Complete)

**Goal:** Broader Simulator and system integration

- [x] Configurable status bar (time, battery, signal) — 4 presets + custom controls
- [x] Simulator Camera (use Mac camera as Simulator input) — AX menu automation
- [x] Environment overrides (accessibility settings) — 11 a11y toggles (appearance, contrast, motion, bold text, smart invert, reduce transparency, grayscale, on/off labels, button shapes, differentiate, grayscale)
- [x] Xcode build statistics (build count, time graphs) — build history polling + Canvas bar chart
- [x] Accessibility tree inspector (VoiceOver navigator) — lazy AX tree walker + highlight overlay

---

## Phase 7 — Polish & Distribution

**Goal:** App Store or direct distribution readiness

- [ ] Code signing + notarization
- [ ] App Sandbox evaluation (or document non-sandbox requirement)
- [ ] Sparkle auto-update (or Mac App Store updates)
- [ ] Comprehensive unit tests (PositionCalculator, WindowEnumerator, AppSettings)
- [ ] UI tests for onboarding flow
- [ ] Privacy manifest (required for App Store)
- [ ] App icon design
- [ ] Marketing page / README polish

---

## Milestones

| Milestone | Phase | Status |
|---|---|---|
| MVP Shell | 1 | Complete |
| Screenshot & Recording | 2 | Not started |
| App Actions | 3 | Not started |
| Design Overlays | 4 | Not started |
| Network Tools | 5 | In progress (Connect + Certificates + Traffic Viewer + Protocol Parsing complete; throttle/block pending) |
| Platform & System | 6 | Complete |
| Distribution Ready | 7 | Not started |
