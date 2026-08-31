# Roadmap: BoosterSimApp

## Overview

BoosterSimApp attaches a floating tool panel to the iOS Simulator so common simulator
tasks complete in ≤2 clicks. The foundation (app shell, panel tracking, onboarding,
tabs) and the platform/system integrations are already complete, and the Connect
network-inspection core is delivered with manipulation tools pending. This roadmap
finishes Network Tools, then delivers the three placeholder tool tabs (Capture, App
Actions, Design), and closes with distribution readiness. Phase numbering preserves
docs/project-roadmap.md so REQ-roadmap-phaseN requirements stay traceable.

## Phases

**Phase Numbering:**

- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

- [x] **Phase 1: Foundation** - Core app shell with simulator attachment (complete)
- [x] **Phase 2: Capture Tools** - Screenshots and screen recording from the side panel (completed 2026-08-30)
- [ ] **Phase 3: App Actions** - Common simulator dev actions from the side panel
- [ ] **Phase 4: Design Tools** - Visual overlays on top of the Simulator window
- [x] **Phase 5: Network Tools** - Inspection delivered; finish throttle, airplane mode, request blocking (completed 2026-08-30)
- [x] **Phase 6: Platform & System** - Status bar, camera, env overrides, build stats, AX inspector (complete)
- [ ] **Phase 7: Polish & Distribution** - Signing, notarization, updates, tests, privacy, icon

## Phase Details

### Phase 1: Foundation

**Goal**: Core app shell with simulator attachment — a menu-bar app whose floating side panel detects and tracks the Simulator window
**Depends on**: Nothing (first phase)
**Status**: Complete (delivered pre-.planning)
**Requirements**: REQ-fr-01, REQ-fr-02, REQ-fr-03, REQ-fr-04, REQ-fr-05, REQ-fr-06, REQ-fr-07, REQ-fr-08, REQ-fr-09, REQ-fr-10, REQ-fr-11, REQ-fr-12, REQ-fr-13, REQ-fr-15, REQ-nfr-01, REQ-nfr-02, REQ-nfr-04, REQ-nfr-05, REQ-nfr-06, REQ-product-success-criteria, REQ-roadmap-phase1-foundation
**Success Criteria** (what must be TRUE):

  1. Panel appears when a Simulator window opens and follows move/resize/minimize in real time (AXObserver; 0.5s polling fallback without Accessibility permission)
  2. Panel floats above all windows including the Simulator, hides when no Simulator exists, and hides/re-shows on Simulator focus loss/re-focus
  3. All four position modes (left/right/bottom/dynamic) work; collapse/expand between 28pt strip and 260pt panel with Reduce Motion respected (spring-physics tracking)
  4. Menu bar icon reflects connection state; Cmd+B / Cmd+W / Cmd+, shortcuts behave as specified; the four tabs (Capture, Design, Actions, Network) navigate via icon-only tab bar
  5. First launch runs the 4-step onboarding (Accessibility, Screen Recording, DerivedData); Preferences exposes position, launch-at-login, and Xcode path

**Plans**: N/A — completed before .planning bootstrap (no GSD plan files)
**UI hint**: yes

### Phase 2: Capture Tools

**Goal**: Users capture App-Store-ready screenshots and recordings of the Simulator directly from the side panel
**Depends on**: Phase 1
**Requirements**: REQ-roadmap-phase2-capture-tools
**Success Criteria** (what must be TRUE):

  1. User can capture a Simulator screenshot (ScreenCaptureKit) with device bezels, wallpaper/background padding, and App Store Connect framing optimization
  2. User can save captures to Desktop, clipboard, or a custom path, with a floating thumbnail preview after capture
  3. User can record the Simulator screen (ScreenCaptureKit), including 120 FPS, with touch indicators visible during recordings
  4. User can export a recording as GIF or video (MP4/MOV)

**Plans**: 4/4 plans executed
Plans:
**Wave 1**

- [x] 02-01-screenshot-tracer-PLAN.md — Tracer: SCScreenshotManager window screenshot → ASC-preset compositor → Desktop save + floating thumbnail, end-to-end (criterion 1 + destination spine)

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 02-02-recording-pipeline-PLAN.md — SCRecordingOutput direct-to-disk recording (CMTime 1/120, queueDepth 5) + ShowSingleTouches touch indicators (criterion 3)

**Wave 3** *(blocked on Wave 2 completion)*

- [x] 02-03-export-formats-PLAN.md — GIF (ImageIO centisecond quantization) + MP4/MOV (AVAssetExportSession) export with destination routing (criterion 4)

**Wave 4** *(blocked on Wave 3 completion)*

- [x] 02-04-phase-gate-closure-PLAN.md — Docs update, full-suite + no-SPM-change gate, phase-gate manual smoke

**UI hint**: yes

### Phase 3: App Actions

**Goal**: Common simulator dev actions (reset, push, deep links, locale, appearance, location, defaults) run from the side panel
**Depends on**: Phase 1
**Requirements**: REQ-roadmap-phase3-app-actions
**Success Criteria** (what must be TRUE):

  1. User can reset the active app (terminate + clear container) and clear its Keychain items
  2. User can grant/revoke push notification permission, send a push notification payload, and trigger deep links (open URL) in the Simulator
  3. User can switch locale (with relaunch), toggle dark/light mode, change Dynamic Type size, simulate location (GPS coordinates + timezone sync), and sync the clipboard bidirectionally Mac ↔ Simulator
  4. User can view/edit/add UserDefaults keys for the active app (bundle ID detected from DerivedData) and filter long action lists via quick search

**Plans**: 4/5 plans executed
Plans:

**Wave 1**

- [x] 03-01-reset-app-tracer-PLAN.md — Tracer: seam-hardened SimCtlService + DerivedDataAppScanner + AppPickerBar → reset-app end-to-end; D-02 destructive keychain w/ CA reconcile (criterion 1)

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 03-02-push-deeplink-privacy-PLAN.md — DeepLinkService seam migration + 12-service privacy section + PushPayload/stdin push sender with D-01 guided grant (criterion 2)

**Wave 3** *(blocked on Wave 2 completion)*

- [x] 03-03-locale-location-clipboard-PLAN.md — Locale/timezone w/ relaunch, location + tz-syncing presets, clipboard pbsync both directions + push/location/clipboard blocking smoke (criterion 3)

**Wave 4** *(blocked on Wave 3 completion)*

- [x] 03-04-defaults-editor-search-PLAN.md — UserDefaults editor (typed plist read + validated spawn writes) + AppActionCatalog quick search (criterion 4)

**Wave 5** *(blocked on Wave 4 completion)*

- [ ] 03-05-phase-gate-closure-PLAN.md — Docs update, full suite + dependency-pin gate, phase-gate manual smoke

**UI hint**: yes

### Phase 4: Design Tools

**Goal**: Pixel-inspection and comparison overlays rendered on top of the Simulator window
**Depends on**: Phase 1
**Requirements**: REQ-roadmap-phase4-design-tools
**Success Criteria** (what must be TRUE):

  1. User can overlay an 8pt/4pt grid and safe-area insets on the Simulator window
  2. User can measure distances between rulers and sample pixel colors with the magnifier/color picker
  3. User can import a Figma/Sketch artboard as a design comparison overlay
  4. Overlays persist when the app loses focus and can be toggled on/off per tool

**Plans**: TBD
**UI hint**: yes

### Phase 5: Network Tools

**Goal**: Complete network tooling — finish manipulation (throttle, airplane mode, request blocking) on top of the delivered inspection core
**Depends on**: Phase 1
**Status**: In progress — Connect pipeline, traffic viewer, and certificates delivered; throttle/airplane mode/request blocking open
**Requirements**: REQ-fr-16, REQ-nfr-03, REQ-roadmap-phase5-network-tools
**Success Criteria** (what must be TRUE):

  1. (delivered) Simulator apps embedding BoosterSimConnect stream Pulse events into the traffic viewer — filter by method/status, auto-scroll list, Summary/Headers/Body/Metrics detail sheet, cURL export with sensitive-header redaction
  2. (delivered) User can generate, install, rotate, and reset a local CA against the Simulator keychain; trust state persists across sessions
  3. User can control Simulator network speed (throttle) from the side panel
  4. User can toggle per-app Simulator Airplane Mode with no impact on Mac connectivity
  5. User can block requests by domain/path rules

**Plans**: 4/4 plans executed
Plans:
**Wave 1**

- [x] 05-01-command-channel-tracer-PLAN.md — Tracer: command channel (_booster-cmd._tcp.) + Airplane Mode end-to-end (engine: payload, transport, verdict enforcement, Network tab toggle)

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 05-02-throttle-profiles-PLAN.md — Throttle profiles (off/EDGE/3G/LTE/Wi-Fi) with latency + paced-chunk enforcement and picker UI
- [x] 05-03-block-rules-PLAN.md — Block rules: matcher hardening (string-ops only) + rules editor UI in the Network tab

**Wave 3** *(blocked on Wave 2 completion)*

- [x] 05-04-phase-gate-closure-PLAN.md — Docs update, full suite + dependency-pin assertions, phase-gate manual smoke

**UI hint**: yes

### Phase 6: Platform & System

**Goal**: Broader Simulator and system integration surfaced through the panel
**Depends on**: Phase 1
**Status**: Complete (delivered pre-.planning)
**Requirements**: REQ-fr-14, REQ-roadmap-phase6-platform-system
**Success Criteria** (what must be TRUE):

  1. User can override the Simulator status bar (time, battery, signal) via 4 presets + custom controls
  2. User can use the Mac camera as the Simulator camera input
  3. User can toggle 11 accessibility environment overrides that take effect instantly, with no target-app relaunch
  4. User can view Xcode build statistics (build count, time graphs)
  5. User can inspect the Simulator accessibility tree with a highlight overlay

**Plans**: N/A — completed before .planning bootstrap (note: these views are complete but not yet wired into the side panel tabs — see STATE.md concerns)
**UI hint**: yes

### Phase 7: Polish & Distribution

**Goal**: The app is distributable — signed, notarized, updatable, tested, and store-ready
**Depends on**: Phase 2, Phase 3, Phase 4, Phase 5
**Requirements**: REQ-roadmap-phase7-polish-distribution
**Success Criteria** (what must be TRUE):

  1. App is code-signed and notarized (archive → notarytool → stapler → DMG), and the non-sandbox requirement is documented (sandbox is incompatible with AX/CGWindowList/simctl usage)
  2. Auto-update works (Sparkle or Mac App Store updates)
  3. Unit tests cover PositionCalculator, WindowEnumerator, and AppSettings; UI tests cover the onboarding flow
  4. Privacy manifest, app icon, and README/marketing polish are complete

**Plans**: TBD

## Progress

**Execution Order:**
Finish Phase 5 (in progress) → 2 → 3 → 4 → 7. Phases 1 and 6 are already complete.
Phase numbering preserves docs/project-roadmap.md for requirement traceability
(REQ-roadmap-phaseN), so numeric order and remaining-work order differ.

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Foundation | — | Complete | pre-.planning |
| 2. Capture Tools | 4/4 | Complete    | 2026-08-30 |
| 3. App Actions | 4/5 | In Progress|  |
| 4. Design Tools | 0/TBD | Not started | - |
| 5. Network Tools | 4/4 | Complete    | 2026-08-30 |
| 6. Platform & System | — | Complete | pre-.planning |
| 7. Polish & Distribution | 0/TBD | Not started | - |
