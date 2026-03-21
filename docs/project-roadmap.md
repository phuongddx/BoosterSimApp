# Project Roadmap

## Current Status: MVP Shell Complete

The core infrastructure (menu bar, side panel, simulator tracking, permissions, onboarding) is built and functional. Feature implementation begins in Phase 2.

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
- [x] Permission onboarding (Accessibility, Screen Recording, DerivedData)
- [x] Preferences window (position, launch at login)
- [x] AppSettings persistence via @AppStorage
- [x] Design tokens system (Spacing, CornerRadius, SideWindowMetrics)
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

- [ ] Network traffic monitoring (request/response log)
- [ ] Network speed control / throttle
- [ ] Simulator Airplane Mode (per-app, no Mac impact)
- [ ] Request blocking (domain/path rules)
- [ ] Certificate trust management

---

## Phase 6 — Platform & System

**Goal:** Broader Simulator and system integration

- [ ] Configurable status bar (time, battery, signal)
- [ ] Simulator Camera (use Mac camera as Simulator input)
- [ ] Apple Watch Simulator support
- [ ] VoiceOver navigator (accessibility tree inspection)
- [ ] Environment overrides (accessibility settings)
- [ ] Xcode build statistics (build count, time graphs)

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
| Network Tools | 5 | Not started |
| Platform & System | 6 | Not started |
| Distribution Ready | 7 | Not started |
