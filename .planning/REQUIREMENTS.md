# Requirements: BoosterSimApp

**Defined:** 2026-08-29 (from docs ingest — .planning/intel/)
**Core Value:** Common simulator tasks (env toggles, cert trust, traffic inspection) complete in ≤2 clicks from the side panel.

## v1 Requirements

30 requirements synthesized from docs/project-overview-pdr.md (FR/NFR) and
docs/project-roadmap.md (phase scopes). IDs preserve source numbering for traceability.
Checkbox state reflects the actual delivery state at ingest time (Phases 1 & 6 complete,
Phase 5 in progress).

### Foundation — Simulator Detection & Panel Tracking

- [x] **REQ-fr-01**: Simulator windows are enumerated via CGWindowListCopyWindowInfo
- [x] **REQ-fr-02**: AXObserver callbacks deliver move, resize, and minimize events in real time
- [x] **REQ-fr-04**: Panel position follows Simulator move/resize events
- [x] **REQ-fr-05**: Panel is hidden while no Simulator window exists
- [x] **REQ-fr-12**: Panel hides on Simulator focus loss and re-shows on Simulator re-focus
- [x] **REQ-fr-15**: Panel follows Simulator with spring physics; disables spring under Reduce Motion
- [x] **REQ-nfr-06**: Window tracking degrades to 0.5s polling without Accessibility permission

### Foundation — Side Panel UX

- [x] **REQ-fr-03**: Panel renders above all windows, including the Simulator window (NSPanel .floating level)
- [x] **REQ-fr-06**: All four position modes (left, right, bottom, dynamic) are selectable and functional
- [x] **REQ-fr-07**: Collapsed state is a 28pt strip; expanded state is a 260pt panel
- [x] **REQ-fr-13**: Side panel exposes exactly four tabs (Capture, Design, Actions, Network) with icon-only tab bar

### Foundation — App Shell

- [x] **REQ-fr-08**: Menu bar icon reflects Simulator connected/disconnected state (bolt.fill / bolt.slash)
- [x] **REQ-fr-09**: 4-step onboarding runs on first launch covering Accessibility, Screen Recording, DerivedData permissions
- [x] **REQ-fr-10**: Preferences window exposes panel position, launch-at-login, and Xcode path settings
- [x] **REQ-fr-11**: Cmd+B toggles panel; Cmd+W hides it; Cmd+, opens Preferences

### Platform — Environment Overrides

- [x] **REQ-fr-14**: Environment toggles take effect immediately via `xcrun simctl spawn`, without relaunching the target app

### Network — Certificates & Dependency Policy

- [x] **REQ-fr-16**: CA generation, install, rotate, and reset flows work against the Simulator keychain; trust state persists across sessions
- [x] **REQ-nfr-03**: Apple frameworks only, exception: Pulse/PulseProxy via BoosterSimConnect *(user-resolved variant, 2026-08-29)*

### Non-Functional — Platform & Runtime

- [x] **REQ-nfr-01**: App targets macOS 15 Sequoia minimum; no compatibility shims present
- [x] **REQ-nfr-02**: Swift 6 strict concurrency enforced at compile time
- [x] **REQ-nfr-04**: App runs non-sandboxed; permissions requested at runtime
- [x] **REQ-nfr-05**: App runs as menu-bar agent (LSUIElement = true, no Dock icon)

### Product Quality

- [x] **REQ-product-success-criteria**: (1) panel appears and tracks Simulator position within 0.5s; (2) collapse/expand animation smooth at 0.2s respecting Reduce Motion; (3) onboarding completes and permissions granted before first use; (4) app stays running menu-bar-only when all windows closed; (5) zero crashes across Simulator launch/quit/move/resize lifecycle

### Roadmap Phase Scope

- [x] **REQ-roadmap-phase1-foundation**: Core app shell with simulator attachment — SwiftUI+AppKit entry, menu bar icon, floating panel, window detection, position sync, 4 position modes, collapse/expand, spring tracking, onboarding, preferences, design tokens, 4-tab UI (complete)
- [ ] **REQ-roadmap-phase2-capture-tools**: Screenshot and screen recording from the side panel — ScreenCaptureKit capture, device bezels, wallpaper/background padding, App Store Connect framing, floating thumbnail, save to Desktop/clipboard/custom path, ScreenCaptureKit recording, 120 FPS, touch indicators, GIF export, MP4/MOV export
- [ ] **REQ-roadmap-phase3-app-actions**: Common simulator dev actions — reset app (terminate + clear container), clear Keychain items, send push notification, grant/revoke push permission, trigger deep link, bidirectional clipboard sync, locale switcher, dark/light toggle, Dynamic Type control, location simulation + timezone sync, UserDefaults editor, quick action search, bundle ID detection from DerivedData
- [ ] **REQ-roadmap-phase4-design-tools**: Visual overlays — 8pt/4pt grid, safe-area insets, ruler with distance measurement, magnifier with color picker, Figma/Sketch design comparison, focus-persistent overlays, per-tool toggle persistence *(in progress — plans 04-01/04-02 done)*
- [ ] **REQ-roadmap-phase5-network-tools**: Network inspection and manipulation — ConnectService/PulseServer/PulsePacketDecoder pipeline, BoosterSimConnect framework, traffic viewer (filter, auto-scroll, detail sheet, cURL export), connection UI, certificate trust management complete; network speed control/throttle, Simulator Airplane Mode (per-app, no Mac impact), request blocking (domain/path rules) pending *(in progress)*
- [x] **REQ-roadmap-phase6-platform-system**: Status bar overrides (4 presets + custom), Simulator camera (Mac camera input via AX menu automation), 11 accessibility environment overrides, Xcode build statistics (count + time graphs), accessibility tree inspector with highlight overlay (complete in source; **reachability gap confirmed 2026-09-01** — status bar/camera/build-stats/AX-tree views have zero call sites outside their own #Preview blocks, only env overrides are wired into the shipping tab UI; wiring closes under REQ-roadmap-phase7-polish-distribution)
- [ ] **REQ-roadmap-phase7-polish-distribution**: Distribution readiness — code signing + notarization, App Sandbox evaluation (or documented non-sandbox requirement), Sparkle/MAS auto-update, unit tests (PositionCalculator, WindowEnumerator, AppSettings), onboarding UI tests, privacy manifest, app icon, marketing page/README polish, **plus wiring Phase 6's orphaned StatusBarSectionView/BuildStatsSectionView/AXTreeView/CameraView into the side panel**

## v2 Requirements

Deferred candidates surfaced by the 2026-04-12 connect journal (not in current roadmap scope):

### Network Inspection Enhancements

- **NET-01**: Support Pulse Code 8 (taskCreated) events in the Connect pipeline
- **NET-02**: Replace placeholder timing data in TrafficDetailView metrics with real PulseMetrics
- **NET-03**: Evaluate NWParameters.includePeerToPeer for the Connect listener
- **NET-04**: End-to-end Connect verification with a real iOS app embedding BoosterSimConnect (Bonjour discoverability from Simulator, 10 MB buffer behavior under load)

## Out of Scope

| Feature | Reason |
|---------|--------|
| Health Data Generator (BoosterHealth companion app + HealthDataService) | Built 2026-03-28, removed from repo (3b1015f); journals superseded per user resolution 2026-08-29 — knowledge preserved in .planning/intel/context.md only |
| Strict zero-external-dependency policy | Relaxed 2026-08-29: Pulse/PulseProxy SPM allowed via BoosterSimConnect (linked on both native targets) |
| Backwards compatibility below macOS 15 | REQ-nfr-01: no compat shims by design |
| Sandboxed (Mac App Store) distribution | Sandbox incompatible with AXIsProcessTrusted/CGWindowList/AXObserver/simctl usage; Phase 7 documents the non-sandbox requirement instead |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| REQ-fr-01 | Phase 1 | Complete |
| REQ-fr-02 | Phase 1 | Complete |
| REQ-fr-03 | Phase 1 | Complete |
| REQ-fr-04 | Phase 1 | Complete |
| REQ-fr-05 | Phase 1 | Complete |
| REQ-fr-06 | Phase 1 | Complete |
| REQ-fr-07 | Phase 1 | Complete |
| REQ-fr-08 | Phase 1 | Complete |
| REQ-fr-09 | Phase 1 | Complete |
| REQ-fr-10 | Phase 1 | Complete |
| REQ-fr-11 | Phase 1 | Complete |
| REQ-fr-12 | Phase 1 | Complete |
| REQ-fr-13 | Phase 1 | Complete |
| REQ-fr-15 | Phase 1 | Complete |
| REQ-nfr-01 | Phase 1 | Complete |
| REQ-nfr-02 | Phase 1 | Complete |
| REQ-nfr-04 | Phase 1 | Complete |
| REQ-nfr-05 | Phase 1 | Complete |
| REQ-nfr-06 | Phase 1 | Complete |
| REQ-product-success-criteria | Phase 1 | Complete |
| REQ-roadmap-phase1-foundation | Phase 1 | Complete |
| REQ-roadmap-phase2-capture-tools | Phase 2 | Pending |
| REQ-roadmap-phase3-app-actions | Phase 3 | Pending |
| REQ-roadmap-phase4-design-tools | Phase 4 | In Progress |
| REQ-fr-16 | Phase 5 | Complete |
| REQ-nfr-03 | Phase 5 | Complete |
| REQ-roadmap-phase5-network-tools | Phase 5 | In Progress |
| REQ-fr-14 | Phase 6 | Complete |
| REQ-roadmap-phase6-platform-system | Phase 6 | Complete |
| REQ-roadmap-phase7-polish-distribution | Phase 7 | Pending |

**Coverage:**

- v1 requirements: 30 total
- Mapped to phases: 30
- Unmapped: 0 ✓

---
*Requirements defined: 2026-08-29 (docs ingest)*
*Last updated: 2026-08-29 after roadmap creation (traceability populated)*
