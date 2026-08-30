# Phase 2: Capture Tools - Research

**Researched:** 2026-08-30
**Domain:** macOS ScreenCaptureKit capture (screenshot + recording), device-bezel/background compositing for App Store Connect framing, GIF/MP4/MOV export, floating-thumbnail and save UX in the 260pt side panel
**Confidence:** HIGH for architecture and API surface (every load-bearing API verified against Apple docs this session; every in-repo claim read from source this session); MEDIUM for framing/UX defaults and 120 fps real-world delivery (device-dependent)

## Summary

Phase 2 turns the Capture tab from a partial scaffold into the real tool. The decisive repo finding: **a `CaptureService.swift` already exists and is wired end-to-end (AppDelegate → SideWindowController → CaptureTabView), but it is a defective scaffold, not a placeholder to extend.** It captures the **entire desktop** (`SCContentFilter(display:excludingApplications: [], exceptingWindows: [])` — [VERIFIED: BoosterSimApp/Services/CaptureService.swift:90]), accumulates **every frame of a recording in an unbounded in-memory array** (line 97–99), tops out at **15 fps** (`CaptureQuality.fps` returns 8/12/15 — lines 38–44), has **no screenshot path at all** (no `SCScreenshotManager`), never renders its touch points, and builds GIFs with a fresh `CIContext` per frame. The plan must be a clean rewrite of this service (split for the <200-LOC rule), not an incremental patch.

The decisive API finding: **ScreenCaptureKit on the project's macOS 15 floor covers all four success criteria natively.** `SCScreenshotManager.captureImage(contentFilter:configuration:)` gives single-frame window capture (macOS 14+) [VERIFIED: developer.apple.com/documentation/screencapturekit/scscreenshotmanager]; `SCContentFilter(desktopIndependentWindow:)` captures exactly the tracked Simulator window [VERIFIED: .../sccontentfilter/init(desktopindependentwindow:)]; `SCRecordingOutput` (macOS 15.0+ — exactly our minimum) writes the recording to disk via hardware encode with **no sample-buffer accumulation** [VERIFIED: .../screencapturekit/screcordingoutput — availability "macOS: 15.0.0 -"]; and 120 fps is a one-liner — `minimumFrameInterval` doc: "You specify the minimum frame interval as the reciprocal of the maximum frame rate" (default `0` = maximum supported rate) [VERIFIED: .../scstreamconfiguration/minimumframeinterval]. Touch indicators are **not an API we build** — Simulator.app renders them itself when the `com.apple.iphonesimulator` preference `ShowSingleTouches` is set, so they appear in any capture of the Simulator window [CITED: adamwulf.me/2024/01/removing-xcode-simulator-touch-indicators; amanhimself.dev; medium.com/@ant_one — three independent sources].

App Store Connect framing is fully specified by Apple: 1–10 screenshots, `.jpeg/.jpg/.png`, "Images can't include alpha channels or transparencies", with exact pixel targets — 6.9″ (required for iPhone): **1260×2736 / 1290×2796 / 1320×2868** portrait (landscape transposed); 6.5″ fallback: **1284×2778 / 1242×2688**; iPad 13″ (required for iPad): **2064×2752 / 2048×2732** [VERIFIED: developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/]. The framing engine is therefore pure, unit-testable geometry: scale content to fit a preset canvas, center, pad with a background (color/gradient/custom image), flatten alpha.

**Primary recommendation:** Rewrite CaptureService as four small units — `ScreenshotService` (SCScreenshotManager one-shot), `RecordingService` (SCStream + `SCRecordingOutput` → .mov at `1/120` interval, `queueDepth` 5), `CaptureCompositor` (pure CoreGraphics bezel/background/ASC-preset engine) and `CaptureExporter` (AVAssetReader → ImageIO GIF; AVAssetExportSession → MP4/MOV) — plus a `CaptureThumbnailPanel` (AXHighlightPanel-pattern borderless NSPanel, 3s auto-hide) and `defaults`-free touch-indicator handling via in-process `CFPreferences` on `com.apple.iphonefacesimulator`'s `ShowSingleTouches` (write → hint that Simulator must relaunch → restore after). No new packages; no iOS-framework (BoosterSimConnect) component — capture is Mac-side only.

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| REQ-roadmap-phase2-capture-tools | Screenshot and screen recording from side panel — SCK screenshot, device bezels, wallpaper/background padding, ASC framing, floating thumbnail, save Desktop/clipboard/custom path, SCK recording, 120 FPS, touch indicators, GIF export, MP4/MOV export | This research: API surface verified (SCScreenshotManager macOS 14+, SCRecordingOutput macOS 15+, minimumFrameInterval 1/120, desktopIndependentWindow filter); ASC pixel spec quoted from Apple; touch-indicator mechanism identified (Simulator pref, not our overlay); existing scaffold audited for rewrite scope; validation plan per criterion |
| REQ-fr-13 | Four tabs with Capture as first tab | Tab shell exists (`SideTab.capture` is the default tab [VERIFIED: SideWindowView.swift:19]); Phase 2 only fills the Capture tab body |
| REQ-fr-09 | Onboarding covers Screen Recording permission | Already shipped; capture flows must degrade gracefully when denied and guide through the restart-after-grant cycle (Apple: "After you grant permission, you need to restart the app to enable capture" [VERIFIED: capturing-screen-content-in-macos sample]) |
| REQ-nfr-01 / REQ-nfr-02 | macOS 15 min; Swift 6 strict concurrency | SCRecordingOutput requires exactly macOS 15.0+ — the floor aligns; concurrency pitfalls for non-MainActor SCStreamOutput callbacks covered in Pitfalls |
| REQ-nfr-03 | Apple frameworks only (exception: Pulse/PulseProxy) | Recommended stack is ScreenCaptureKit + AVFoundation + CoreGraphics + AppKit only; no ffmpeg, no GIF third-party library |
</phase_requirements>

## Project Constraints (from CLAUDE.md)

Extracted from repo `AGENTS.md`, `docs/code-standards.md` (via .planning/codebase/CONVENTIONS.md), and `.planning/PROJECT.md` constraints:

- **Concurrency:** Combine `@Published` + Timer for service state; **no async/await EXCEPT `CaptureService.swift` and `DeepLinkService.swift`** — "Exception: `CaptureService.swift` and `DeepLinkService.swift` use `async`/`await` because ScreenCaptureKit and `simctl openurl` APIs require it" [VERIFIED: .planning/codebase/CONVENTIONS.md:8]. Phase 2 may keep async internals inside the capture services only; public surface stays sync/Combine (Pattern 1 below). New general-purpose services must NOT adopt async/await.
- **Swift 6 strict concurrency** at compile time; no `@unchecked Sendable` without justification; `@MainActor` on UI-bound services.
- **Apple frameworks only** (REQ-nfr-03). No ffmpeg/GIF library/bezel-SDK.
- **Files < 200 LOC**, split by concern; PascalCase file = primary type; `// MARK:` order Properties/Lifecycle/Public/Private; header purpose comment.
- **Design tokens mandatory** — `Spacing`, `CornerRadius`, `SideWindowMetrics` from `Utilities/DesignTokens.swift`; SF Symbols only (`camera`, `video`, `film` already reserved for this tab in design-guidelines); amber accent for CTAs only; semantic colors; Reduce Motion respected (0.1s linear).
- **AppLogger redaction** — never log file paths, UDIDs, or screen contents; category enum lives in `Utilities/AppLogger.swift` (add a `capture` category following the existing pattern).
- **No direct subprocess spawning** — all `xcrun simctl` through `SimCtlService`. Note: the touch-indicator mechanism below uses in-process CFPreferences precisely to stay inside this rule (no `defaults` subprocess).
- **Permission degradation is mandatory** — "Features that touch Accessibility, Screen Recording, or `simctl` should document required permissions and degraded behavior when access is denied" [VERIFIED: AGENTS.md:31].
- **Swift Testing** unit tests (`import Testing`, `@Test`, `#expect`) under `BoosterSimAppTests/`; XCTest for UI tests.
- **Conventional Commits** (`feat(capture): ...` expected scope).
- **GitNexus:** executor must run impact analysis before editing existing symbols — `CaptureService` is live-wired in `AppDelegate` (line 27), `SideWindowController` init (line 56), and `SideWindowView` `#Preview` (lines 97–120), so signature changes have d=1 blast radius.
- **docs/ is the single source of truth** — update `docs/system-architecture.md` after the feature lands (Phase 5 pattern).

## Problem Domain

### What must be true (ROADMAP success criteria → acceptance detail from .planning/intel/requirements.md:167–175)

1. Screenshot via ScreenCaptureKit, with device bezels, wallpaper/background padding, App Store Connect framing optimization
2. Save to Desktop / clipboard / custom path + floating thumbnail preview after capture
3. Recording via ScreenCaptureKit incl. 120 FPS, touch indicators visible during recordings
4. Export a recording as GIF or MP4/MOV

### What exists today (scaffold audit — read this session)

[VERIFIED: BoosterSimApp/Services/CaptureService.swift this session; line ranges as cited]

| Area | Current state | Verdict |
|------|--------------|---------|
| Wiring | `lazy var captureService = CaptureService()` (AppDelegate.swift:27) → SideWindowController init → `.environmentObject` in preview; CaptureTabView binds all controls | Keep wiring; replace guts |
| Screenshot | **Does not exist** — no `SCScreenshotManager` anywhere | Build new |
| Recording stream | `SCContentFilter(display:excludingApplications: [], exceptingWindows: [])` (line 90) = captures the **whole desktop, including BoosterSimApp's own panel** | Rewrite filter |
| Output size | `config.width = display.width * 2` (lines 92–93) — display-based, not window-based | Rewrite (window.frame × scale, per Apple sample) |
| Frame rate | `CaptureQuality.fps` = 8/12/15 (lines 38–44); `config.minimumFrameInterval = CMTime(value: 1, timescale: quality.fps)` (line 94) | Rewrite for 120 |
| Frame storage | `capturedFrames.append(frame)` for every sample (lines 97–99), array never drained until stop | Remove entirely (SCRecordingOutput writes to disk) |
| Touch indicators | `TouchPoint` struct + `addTouchPoint` (lines 140–144) — data collected, never rendered | Replace with Simulator pref mechanism |
| Export MP4 | AVAssetWriter hand-rolled loop with 10ms sleep polling `isReadyForMoreMediaData` (lines 226–228) | Replace with SCRecordingOutput + AVAssetExportSession |
| Export GIF | ImageIO `CGImageDestination` (lines 249–267) but: new `CIContext` per frame (line 259), delay `1/fps` unquantized (line 254), source = live frame array | Keep ImageIO; source = recorded file; fix context + timing |
| Save UX | `NSSavePanel.runModal()` + copy from temp (lines 146–159) | Extend to Desktop/clipboard/custom |
| Quality/bezel enums | `CaptureQuality` (320/480/640px), `DeviceBezel` (none/iPhone 15/iPhone 15 Pro/iPad Pro — names only, no assets) | Redesign (presets are wrong for ASC; bezel enum has no backing renderer) |
| Persistence | All capture options are session-only `@Published`; `AppSettings` has exactly 4 keys (sideWindowPosition, showSideWindow, launchAtLogin, xcodePath) [VERIFIED: AppSettings.swift:34–37] | Add capture settings keys |
| Thumbnail | Does not exist | Build (AXHighlightPanel precedent) |

### Domain concepts

- **ScreenCaptureKit window capture** is desktop-pixel capture of what Simulator.app renders — device bezels included when the user has Simulator's bezels enabled; the raw device framebuffer is NOT what SCK sees (that is `xcrun simctl io screenshot`'s domain).
- **App Store Connect framing** = compositing the captured content onto a canvas of an exact ASC pixel size with padding/background, since ASC accepts only specific dimensions and rejects alpha.
- **GIF export** = decode recorded movie → sample frames at reduced fps/width → ImageIO `CGImageDestination` (`com.compuserve.gif`) with per-frame `kCGImagePropertyGIFDelayTime` and loop count 0.
- **Touch indicators** = Simulator's own rendered dots (`ShowSingleTouches` pref); anything we drew would have to be composited onto every frame post-hoc — unnecessary once the pref mechanism is used.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Screenshot acquisition (window one-shot) | macOS app (ScreenCaptureKit, ScreenshotService) | — | SCK is the mandated mechanism; window already tracked as `CGWindowID` [VERIFIED: WindowEnumerator.swift:31] |
| Bezel/background/ASC compositing | macOS app (pure CoreGraphics utility) | — | Pure math + CGContext drawing; fully unit-testable, no external service |
| Recording (stream → file) | macOS app (SCStream + SCRecordingOutput) | — | Same SCK pipeline; hardware encode; no Simulator-side component |
| Touch indicators during recording | Simulator.app rendering | macOS app (CFPreferences write + restore) | Simulator draws the dots inside its window; we only toggle its preference — captured frames then contain them for free |
| GIF / MP4 / MOV export | macOS app (AVFoundation + ImageIO) | — | Post-processing of the recorded file; offline, cancellable, unit-testable config |
| Save destinations + clipboard | macOS app (AppKit: NSSavePanel, NSPasteboard, NSWorkspace) | — | House AppKit patterns |
| Floating thumbnail | macOS app (NSPanel in `Windows/`) | — | AXHighlightPanel is the in-repo precedent for borderless auto-hiding floating panels |
| Any Simulator-app-side code | **None** | — | Capture is Mac-side only; BoosterSimConnect untouched (roadmap assigns nothing here to the framework) |

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| ScreenCaptureKit | macOS SDK 26.2 (Xcode 26.3) | `SCScreenshotManager` one-shot images; `SCStream` + `SCContentFilter(desktopIndependentWindow:)` window capture; `SCRecordingOutput` file recording; `SCStreamConfiguration` fps/queueDepth | Roadmap mandates SCK; APIs verified macOS 14+/15+ against project's macOS 15 floor [VERIFIED: Apple doc availability metadata this session] |
| AVFoundation | macOS SDK 26.2 | `AVAssetReader` (movie → frames for GIF), `AVAssetExportSession` (MOV → MP4/MOV transcode), `AVAsset` metadata (verify duration/dimensions in smoke) | Apple-only policy; the blessed post-processing layer |
| CoreGraphics / CoreImage / ImageIO | macOS SDK 26.2 | Compositing (CGContext, CGImageSource/Destination), GIF encode (`com.compuserve.gif`), rounded-rect masking, color-space flattening | Already used by the scaffold for GIF; ImageIO is Apple's GIF encoder |
| AppKit | macOS SDK 26.2 | Borderless NSPanel thumbnail, `NSPasteboard` clipboard, `NSSavePanel`, `NSWorkspace` reveal | House patterns (AXHighlightPanel, existing saveToFile) |
| Combine | macOS SDK 26.2 | Service state (`@Published`) → SwiftUI | House convention |
| CoreFoundation (CFPreferences) | macOS SDK 26.2 | In-process write/restore of `com.apple.iphonesimulator` `ShowSingleTouches` | Keeps the repo rule "no direct subprocess spawning" intact (no `/usr/bin/defaults` process) |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| SCScreenshotManager (window filter) | `xcrun simctl io booted screenshot` | Raw framebuffer at exact device pixels, **no TCC permission needed**, no titlebar/bezel contamination [VERIFIED: `simctl io --help` this session — screenshot/recordVideo operations exist with `--codec hevc|h264`, `--mask ignored|alpha|black`]. But roadmap criterion says "(ScreenCaptureKit)", and simctl output has no bezel/background/ASC framing story. Keep as **fallback** (e.g., pixel-exact source for custom-bezel mode) and as a diagnostic; primary stays SCK. Route through SimCtlService if used. |
| SCRecordingOutput (macOS 15+) | SCStreamOutput + AVAssetWriter (scaffold's approach) | AVAssetWriter gives frame-level control but forced the scaffold into unbounded memory + sleep-polling loops; SCRecordingOutput hardware-encodes to disk with zero accumulation and exposes `recordedDuration`/`recordedFileSize` [VERIFIED: SCRecordingOutput doc topics]. AVAssetWriter remains the fallback if a container/codec combination fails. |
| ImageIO GIF (existing) | ffmpeg / third-party MGIF ports | REQ-nfr-03 forbids non-Apple deps; AVAssetExportSession has no GIF output preset. ImageIO is the only Apple path. |
| CFPreferences write | `defaults write` subprocess | Subprocess violates "no direct subprocess spawning — use SimCtlService" (which only wraps xcrun simctl, not defaults). CFPreferences is in-process, synchronous, and testable. |
| Desktop-independent window filter | Display filter + `exceptingWindows: [simulator window]` | Display filter composites the window over whatever is behind it (desktop/other windows) into non-transparent pixels; desktop-independent keeps the window's own alpha shape — essential for bezel-shaped captures and correct padding. |
| Asset-based photoreal bezels | Simulator-native bezels (capture what Simulator renders) / drawn bezel (CoreGraphics silhouette) | Assets give marketing-grade frames but require licensed artwork (Open Question 1). Native and drawn modes ship license-clean on day one. |

**Installation:** none — no new packages. REQ-nfr-03 remains satisfied.

**Version verification:** No registry lookups needed (Apple-SDK only phase). Toolchain verified on this machine: Xcode 26.3 (17C529), macOS host 26.6.2, macOS SDK 26.2 [VERIFIED: `xcodebuild -version` / `sw_vers` / `xcodebuild -showsdks` this session].

## Package Legitimacy Audit

**Not applicable — this phase installs no external packages.** All recommended frameworks are Apple system frameworks. No SPM changes; `Package.resolved` untouched (Phase 5's pin-verification lesson does not apply here).

## Available Approaches (with tradeoffs)

### A. Screenshot acquisition

| Approach | How | Pros | Cons |
|----------|-----|------|------|
| **A1. SCScreenshotManager + desktop-independent window filter (recommended)** | `SCShareableContent` → match `SCWindow.windowID` to tracked `CGWindowID` → `SCContentFilter(desktopIndependentWindow:)` → `captureImage(contentFilter:configuration:)` | Single async call, no stream lifecycle; keeps window alpha shape (ideal for compositing); roadmap-compliant; same filter object reused by recording | Needs Screen Recording TCC; captures what Simulator renders (titlebar/bezel state) — content rect handling needed (Pitfall 4) |
| A2. SCStream single-frame (start, await first `.complete` frame, stop) | Stream lifecycle per screenshot | Same pixels as recording (uniform pipeline) | Heavy: stream start/stop per shot, ~100ms+ latency, delegate plumbing for one image |
| A3. `xcrun simctl io screenshot` (fallback) | SimCtlService call, PNG from stdout/file | Exact device pixels, no bezel/titlebar, **no TCC** | Not ScreenCaptureKit (roadmap mismatch as primary); no window-alpha; would need routing rules for which booted device matches the tracked window |

### B. Device bezels

| Approach | How | Pros | Cons |
|----------|-----|------|------|
| **B1. Simulator-native (recommended default)** | User leaves Simulator's bezels on; we capture the window; titlebar handled via `SCStreamFrameInfo.contentRect`/crop | Zero assets, zero licensing, always matches the running device | Requires Simulator bezel pref ON (detect + hint); chrome-crop must be verified at implementation (Pitfall 4) |
| **B2. Drawn bezel (recommended secondary)** | CoreGraphics rounded-rect + notch/dynamic-island silhouette around content, radii per device family | License-clean, asset-free, deterministic geometry (unit-testable), consistent background marketing look | Not photoreal; radius/shape values are per-device tuning [ASSUMED for exact radii] |
| B3. Asset-based photoreal (defer / Open Question 1) | PNG device-frame artwork with screen cutout composited at native scale | Marketing-grade output (what Simshot/RocketSim-class tools ship) | Needs licensed artwork — Meta's "Devices from Design at Meta" set is the standard source, but the license terms must be verified before bundling [ASSUMED: free-for-commercial-use — unverified this session] |

### C. Background / wallpaper padding

| Approach | Tradeoff |
|----------|----------|
| **Solid color / gradient (recommended v1)** | Pure CG draw; color pickers are trivial; deterministic tests |
| Custom imported image ("wallpaper") | NSOpenPanel + CGImage draw scaled to canvas; modest code; no licensing issue (user's own asset); v1-stretch, not required by criteria wording ("wallpaper/background padding" is satisfied by color/gradient + margins) |

### D. Recording pipeline

| Approach | Tradeoff |
|----------|----------|
| **D1. SCStream + SCRecordingOutput → .mov (recommended)** | One config object carries fps (`minimumFrameInterval = 1/120`), `queueDepth`, window filter; hardware encode; delegate gives completion callback; `recordedDuration`/`recordedFileSize` power live UI. Container/extension behavior for `.mp4` vs `.mov` unverified [ASSUMED: use `.mov`; transcode for MP4 via export] |
| D2. SCStreamOutput + AVAssetWriter (status quo scaffold) | Full control of timeline/muxing; but frame accumulation, ready-for-more-data polling, and manual session management — the exact defects in today's scaffold. Keep only as fallback if SCRecordingOutput blocks a requirement |

Frame-rate plan: `minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(120))`, `queueDepth = 5` (Apple sample: "Increase the depth of the frame queue to ensure high fps … default value is 3 and shouldn't exceed 8 frames" [VERIFIED: capturing-screen-content-in-macos]). Actual delivery is bounded by the display's refresh rate — ProMotion host display required for true 120 (Environment Availability).

### E. GIF export

| Approach | Tradeoff |
|----------|----------|
| **E1. AVAssetReader over the recorded .mov → downsampled CGImages → ImageIO GIF destination (recommended)** | Source of truth is the file (no live-frame coupling); reader loop runs on a background DispatchQueue (fits no-async/await for new code); output width + fps selectable (e.g., 480px @ 10 fps); delay quantized to whole centiseconds (Pitfall 8) |
| E2. Live-frame GIF accumulation (scaffold's exportAsGIF) | Couples GIF quality to recording session; unbounded memory; per-frame `CIContext` churn. Removed by cutover |

### F. Outputs + thumbnail

Desktop (fixed folder `~/Desktop/BoosterSim Captures/`), clipboard (`NSPasteboard` — `.png` type for images; file URL for videos), custom path (persisted directory + NSSavePanel per capture), and a borderless `NSPanel` thumbnail (NSImageView + click-to-reveal + 3s auto-hide timer) modeled directly on `AXHighlightPanel` [VERIFIED: AXHighlightPanel.swift:29–42, 63–67 — styleMask `[.borderless, .nonactivatingPanel]`, `.floating` level, Timer-based dismiss].

## Recommended Approach

One capture engine, four small files plus one panel, surfaced in the existing Capture tab:

```
User clicks Screenshot / Record in Capture tab (CaptureTabView)
        │ CaptureService facade (sync public API, @MainActor, Combine state)
        ▼
┌─ Screen path ──────────────────────┐   ┌─ Recording path ─────────────────────────┐
│ ScreenshotService                  │   │ RecordingService                          │
│  SCShareableContent → SCWindow     │   │  SCStream(desktopIndependentWindow)       │
│  (match tracked CGWindowID)        │   │  SCStreamConfiguration: interval 1/120,   │
│  SCScreenshotManager.captureImage  │   │  queueDepth 5, capturesAudio false        │
└──────────┬─────────────────────────┘   │  + SCRecordingOutput → temp .mov          │
           │ CGImage                     └──────────┬────────────────────────────────┘
           ▼                                        │ stop → finished delegate
┌─ CaptureCompositor (pure CG) ─┐                   ▼
│  bezel mode (native/drawn/    │        ┌─ CaptureExporter ──────────────────┐
│  none) + background (color/   │        │ GIF: AVAssetReader → ImageIO        │
│  gradient/custom) + ASC preset│        │ Video: AVAssetExportSession → MP4   │
│  canvas 1320×2868 etc.        │        └──────────────┬──────────────────────┘
└──────────┬────────────────────┘                       │
           ▼                                            ▼
   CaptureOutput (Desktop / Clipboard / Custom path) + CaptureThumbnailPanel (3s auto-hide)
```

Cross-cutting: TouchIndicatorController flips `ShowSingleTouches` via CFPreferences before recording when enabled, shows a hint if Simulator needs relaunch, restores the prior value after.

### Recommended Project Structure

```
BoosterSimApp/
├── Models/
│   ├── ASCFramePreset.swift          # enum: exact ASC pixel sizes + labels (discrete values from Apple spec)
│   ├── CaptureDestination.swift      # desktop / clipboard / custom(URL) / ask
│   └── BezelMode.swift               # none / simulatorNative / drawn
├── Services/
│   ├── CaptureService.swift          # slim facade: @MainActor ObservableObject, published state, routing (rewrite)
│   ├── ScreenshotService.swift       # SCScreenshotManager one-shot (new)
│   ├── RecordingService.swift        # SCStream + SCRecordingOutput lifecycle (new)
│   ├── CaptureExporter.swift         # GIF + MP4/MOV post-processing (new)
│   └── TouchIndicatorController.swift# CFPreferences write/restore state machine (new)
├── Utilities/
│   └── CaptureCompositor.swift       # pure geometry + CGContext compositing (new, fully unit-testable)
├── Windows/
│   └── CaptureThumbnailPanel.swift   # borderless NSPanel, 3s auto-hide (AXHighlightPanel pattern)
└── BoosterSimAppTests/
    ├── CaptureFramingTests.swift     # preset math, scale/center/pad, alpha flatten
    ├── CaptureExportConfigTests.swift# GIF timing quantization, codec/preset mappings
    └── CaptureSettingsTests.swift    # AppSettings round-trip, filename builder
```

AppSettings gains capture keys (destination, format, quality preset, bezel mode, background choice, showTouchIndicators) following the existing `@AppStorage` pattern [VERIFIED: AppSettings.swift:33–37]. CaptureService is split because the current file is already 312 LOC against the 200 limit [VERIFIED: CONVENTIONS.md:18 flags it as the overage precedent].

### Pattern 1: Async internals behind a sync Combine facade (house bridge)

**What:** Public methods stay synchronous and side-effect through `Task { await … }`; state flows back via `@Published`. This is the in-repo precedent — [VERIFIED: BoosterSimApp/Services/DeepLinkService.swift:50–52]:

```swift
func openInSimulator(udid: String?) {
    Task { await openInSimulatorAsync(udid: udid) }
}
```

**When to use:** Every CaptureService public API. ScreenCaptureKit's surface is async (`try await SCShareableContent.excludingDesktopWindows(...)`, `try await stream.startCapture()`); the documented CONVENTIONS exception keeps async legal *inside* these services only. Views never see async.

### Pattern 2: One-shot window screenshot

```swift
// Source: signatures verified — developer.apple.com/documentation/screencapturekit
// (SCScreenshotManager, SCContentFilter.init(desktopIndependentWindow:), SCStreamConfiguration)
let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
guard let scWindow = content.windows.first(where: { $0.windowID == trackedWindowID }) else {
    throw CaptureError.windowNotFound
}
let filter = SCContentFilter(desktopIndependentWindow: scWindow)
let config = SCStreamConfiguration()
config.width = Int(simWindow.frame.width) * 2      // Retina output (Apple sample uses ×2 for windows)
config.height = Int(simWindow.frame.height) * 2
config.scalesToFit = false
config.showsCursor = false
config.ignoreShadowsSingleWindow = true
config.captureResolution = .best
let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
```

`SCScreenshotManager` availability is macOS 14.0+ [VERIFIED: doc metadata]; the async Swift spelling is used across the community and Apple's sample ecosystem [CITED: medium.com/towardsdev SCK article; Apple sample uses the async `SCShareableContent` call directly].

### Pattern 3: Recording with SCRecordingOutput (no frame accumulation)

```swift
// Source: developer.apple.com/documentation/screencapturekit/{screcordingoutput,
// screcordingoutputconfiguration, capturing-screen-content-in-macos}
let recordingConfig = SCRecordingOutputConfiguration()
recordingConfig.outputURL = tempMovieURL            // .mov (see Assumptions A2 for .mp4)
recordingConfig.videoCodecType = .hevc              // or .h264

let recordingOutput = SCRecordingOutput(configuration: recordingConfig, delegate: recordingDelegate)
stream = SCStream(filter: filter, configuration: streamConfig, delegate: streamDelegate)
try stream.addStreamOutput(recordingOutput, type: .screen, sampleHandlerQueue: serialQueue)
try await stream.startCapture()
// … on stop: try await stream.stopCapture(); wait for delegate's finish callback before exporting
```

Stream config for the criterion: `minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(120))` — doc: "You specify the minimum frame interval as the reciprocal of the maximum frame rate" [VERIFIED: .../minimumframeinterval]; `queueDepth = 5` per the sample's high-fps guidance [VERIFIED: capturing-screen-content-in-macos]. Output attachment via `addStreamOutput(_:type:sampleHandlerQueue:)` mirrors the sample's output pattern [CITED: Apple sample + SCRecordingOutput class docs].

### Pattern 4: Pure compositing math (the testable core)

```swift
// CaptureCompositor — no I/O, no ScreenCaptureKit: deterministic and unit-testable
struct FramingResult: Equatable { let canvas: CGSize; let contentRect: CGRect; let scale: CGFloat }

static func frame(content: CGSize, preset: ASCFramePreset,
                  padding: CGFloat, mode: ScaleMode) -> FramingResult {
    let canvas = preset.pixelSize            // e.g. 1320×2868 — verbatim from Apple's spec table
    let avail = CGSize(width: canvas.width - padding * 2, height: canvas.height - padding * 2)
    let scale = min(avail.width / content.width, avail.height / content.height)
    let scaled = CGSize(width: (content.width * scale).rounded(.down),
                        height: (content.height * scale).rounded(.down))
    let origin = CGPoint(x: ((canvas.width - scaled.width) / 2).rounded(),
                         y: ((canvas.height - scaled.height) / 2).rounded())
    return FramingResult(canvas: canvas, contentRect: CGRect(origin: origin, size: scaled), scale: scale)
}
```

Drawing then: fill background → clip rounded rect → draw content (or bezel cutout) → flatten to sRGB **without alpha** (ASC rejects alpha [VERIFIED: screenshot-specifications: "Images can't include alpha channels or transparencies"]).

### Pattern 5: Borderless floating thumbnail panel

Copy the `AXHighlightPanel` shape [VERIFIED: AXHighlightPanel.swift:29–42]: `NSPanel` with `styleMask: [.borderless, .nonactivatingPanel]`, `level = .floating`, `isReleasedWhenClosed = false`, `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]`; content = `NSImageView` (proportionally scaled, `CornerRadius.large` mask, shadow); position anchored near the Simulator frame's trailing edge; `Timer` auto-hide at 3.0s (AXHighlightPanel uses 2.5s); click = `NSWorkspace.shared.activateFileViewerSelecting([url])`. Respect Reduce Motion (fade, no slide).

### Pattern 6: Touch indicators via Simulator's own preference

```swift
// In-process CFPreferences — no subprocess (repo rule). Key names from three corroborating sources.
let domain = "com.apple.iphonesimulator" as CFString
let key = "ShowSingleTouches" as CFString
let previous = CFPreferencesCopyAppValue(key, domain)          // snapshot for restore
CFPreferencesSetAppValue(key, true as CFNumber, domain)
CFPreferencesAppSynchronize(domain)
// … after recording: restore `previous` (or CFPreferencesSetAppValue(key, kCFNull, domain) if unset)
```

Simulator renders single-touch dots in its window when this pref is set and Simulator restarts [CITED: adamwulf.me/2024/01/removing-xcode-simulator-touch-indicators; amanhimself.dev/blog/show-touch-indicator-on-ios-simulator; medium.com/@ant_one/show-touch-highlights-on-ios-simulator]. Because the dots are *rendered by Simulator inside its window*, SCK captures them with zero extra work — this is why no overlay engine is needed.

### Anti-Patterns to Avoid

- **In-memory frame accumulation for recordings** (scaffold's `capturedFrames: [CMSampleBuffer]`): at 120 fps of a ~2× window this is a memory bomb. SCRecordingOutput streams to disk.
- **Capturing the display instead of the window**: the scaffold's empty `exceptingWindows` records the whole desktop — including BoosterSimApp's own panel (recursive self-capture in the recording).
- **Overlay-drawn touch indicators**: compositing our own dots onto frames post-hoc duplicates what Simulator already renders; it also can't match system rendering timing.
- **`NSSavePanel.runModal()` on the main thread for every save**: blocks the app; prefer `beginSheetModal`/`begin(completionHandler:)` for the custom-path flow (existing `saveToFile` is the thing being replaced, not a precedent to keep).
- **Per-frame `CIContext` creation** in the GIF loop (scaffold line 259): create one context per export.
- **New async/await services**: only the capture services inherit the documented exception; exporters should use DispatchQueue/Combine.
- **Hand-rolled bezel PNG hunting inside Xcode/Simulator bundles**: Apple's Simulator assets are compiled (`Assets.car`) and not licensed for redistribution — do not extract [VERIFIED: no loose bezel files under Simulator.app; only Assets.car — probed this session].

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Video encoding/muxing | AVAssetWriter append loops, sleep-polling `isReadyForMoreMediaData` | `SCRecordingOutput` | Hardware encode, correct timing, completion delegate; the hand-rolled version is today's memory/pacing bug source |
| Single-frame capture | SCStream start/await/stop choreography | `SCScreenshotManager.captureImage` | Purpose-built API; macOS 14+ |
| GIF encoding | Byte-level GIF89a writer / LZW encoder | ImageIO `CGImageDestination` + `kCGImagePropertyGIFDelayTime` / `kCGImageAnimationDelayTime` [CITED: developer.apple.com/documentation/imageio/kcgimageanimationdelaytime] | Apple's encoder handles LZW, palette, loop extensions |
| Video transcode (MOV→MP4) | Re-encode pipelines | `AVAssetExportSession` passthrough presets | Container swap without recompression quality loss |
| Image scaling / rounded masking | Manual resampling | CGContext interpolation + `CGPath` clip (or CIImage) | Correct color space + interpolation is easy to get wrong by hand |
| Screen-recording permission preflight | DIY TCC checks | `CGPreflightScreenCaptureAccess()` / `CGRequestScreenCaptureAccess()` — already wrapped in PermissionManager [VERIFIED: PermissionManager.swift:51–57] | Existing, tested by onboarding |
| Touch indicator rendering | AX-event-driven overlay drawing | Simulator's `ShowSingleTouches` pref | System-rendered; matches real recording conventions; zero compositing cost |

**Key insight:** Everything hard in this phase (encode, mux, GIF LZW, capture plumbing) has a first-party API on the project's macOS 15 floor. The only genuinely new code is *geometry and orchestration* — which is exactly the part that should be pure and unit-tested.

## Runtime State Inventory

Phase adds features (no rename/migration), but introduces new runtime state:

| Category | Items Found | Action Required |
|----------|-------------|-----------------|
| Stored data (app) | New `@AppStorage` keys: capture destination, ASC preset, bezel mode, background choice, export format, GIF size/fps, showTouchIndicators, custom-path bookmark | Code edit: extend AppSettings; custom path needs security-scoped-free (non-sandboxed) bookmark or plain path persistence — plain URL is fine given REQ-nfr-04 non-sandbox |
| Stored data (Simulator) | `com.apple.iphonesimulator` `ShowSingleTouches` (and possibly related toggles) mutated during recordings | Must snapshot before write and restore after (including "was unset"); app relaunch of Simulator required for effect [CITED: touch-indicator sources] |
| Live service config | None external — no launchd/agents/daemons introduced | None |
| OS-registered state | None — TCC Screen Recording already requested by onboarding (REQ-fr-09); no new permission types | None |
| Secrets/env vars | None | None |
| Build artifacts / temp files | Temp .mov/.gif/.png intermediates in `FileManager.temporaryDirectory` (scaffold already writes there) | Deterministic cleanup after export/save; never log paths (AppLogger rule) |

## Common Pitfalls

### Pitfall 1: Recursive self-capture with display filters
**What goes wrong:** A display-based filter captures the entire screen, including the BoosterSimApp panel that shows "REC 00:12" — the recording documents the recorder.
**Why:** Scaffold's filter is display-based with no exclusions.
**How to avoid:** Desktop-independent window filter for both screenshot and recording; assert in dev builds that the captured `SCWindow.bundleIdentifier` is Simulator's.
**Warning signs:** Panel chrome appears in output; file dimensions don't match the device aspect.

### Pitfall 2: Screen Recording TCC granted but capture still fails
**What goes wrong:** User flips the toggle in System Settings; `CGPreflightScreenCaptureAccess()` still returns false; developer concludes the API is broken.
**Why:** Apple's own sample states: "After you grant permission, you need to restart the app to enable capture" [VERIFIED: capturing-screen-content-in-macos].
**How to avoid:** Detection flow: preflight false → show setup UI (PermissionManager already polls [VERIFIED: PermissionManager.swift:64–76]) → when granted, prompt "Quit & Reopen"; on launch, re-preflight before enabling capture UI.
**Warning signs:** `SCShareableContent` throws/returns empty exclusively for our app.

### Pitfall 3: Unbounded frame memory / export on the hot path
**What goes wrong:** Recordings balloon RSS; stop-recording freezes the UI while hundreds of frames export.
**Why:** Scaffold accumulates every `CMSampleBuffer` and exports synchronously-ish on stop.
**How to avoid:** SCRecordingOutput writes to disk continuously; export runs after the finish callback on a background queue; progress published via Combine.
**Warning signs:** RSS grows ~linearly with recording length; spinner on Stop.

### Pitfall 4: Window chrome and title bar in captures
**What goes wrong:** ASC-framed output contains the Simulator title bar, or double-bezel (our drawn bezel around Simulator's native bezel).
**Why:** `SCWindow.frame` covers the full window; Simulator's bezel pref state varies per user.
**How to avoid:** Read `SCStreamFrameInfo.contentRect` + `.scaleFactor` attachments (Apple sample pattern) to get true content pixels; for native-bezel mode detect Simulator's bezel setting (document: user keeps bezels ON; hint otherwise); for drawn-bezel mode ask user to keep Simulator bezels OFF (hint + docs).
**Warning signs:** Strips of title-bar pixels at the top of exports; aspect mismatch >1%.

### Pitfall 5: 120 fps expectation vs display refresh
**What goes wrong:** Recording on a 60 Hz external display yields 60 fps; ticket says "120 FPS broken".
**Why:** `minimumFrameInterval` is a ceiling on inter-frame time, not a floor on delivery; WindowServer delivers at content/display cadence (queueDepth guidance in the sample exists precisely for high-fps).
**How to avoid:** Surface the *configured* rate in UI ("up to 120 fps"); measure actual delivered rate in smoke (frame count ÷ duration via AVAssetReader); document display dependency.
**Warning signs:** Delivered fps ≈ display refresh.

### Pitfall 6: GIF delay quantization churn
**What goes wrong:** GIF plays choppy in browsers even though the source was smooth.
**Why:** GIF frame delays are integer centiseconds; unquantized values like 1/15 s (6.67 cs) round to alternating 6/7 cs — visibly uneven cadence (same symptom class documented for video-editor exports [CITED: community.adobe.com GIF delay thread]).
**How to avoid:** Offer GIF fps choices that quantize exactly (10 fps → 10 cs, 5 fps → 20 cs); compute delay per frame in integer centiseconds in pure code (unit test).
**Warning signs:** Alternating delay values when parsing the produced GIF.

### Pitfall 7: Alpha channel in saved PNGs
**What goes wrong:** ASC upload rejects the screenshot.
**Why:** Desktop-independent captures carry alpha around the window shape; ASC: "Images can't include alpha channels or transparencies" [VERIFIED: screenshot-specifications].
**How to avoid:** The compositor always flattens onto an opaque background before save; final validation step asserts no alpha in output (CGImageSource check, unit-testable).
**Warning signs:** ASC upload error; Finder shows checkered background.

### Pitfall 8: Swift 6 isolation across SCStream callbacks
**What goes wrong:** Build errors or runtime isolation crashes: `SCStreamOutput`/`SCStreamDelegate` callbacks arrive on the sample-handler queue, not main; strict concurrency flags touching `@MainActor` state from them.
**Why:** ScreenCaptureKit is callback-based and not MainActor.
**How to avoid:** Follow the scaffold's existing shape — private non-isolated delegate/output wrappers hopping to main via `Task { @MainActor … }` [VERIFIED: CaptureService.swift:299–312]; sample-handler queue is a dedicated serial `DispatchQueue`, **not** `.main` (scaffold's `.main` queue at 120 fps would starve the UI).
**Warning signs:** UI hitches during recording; Swift 6 data-race diagnostics.

### Pitfall 9: Stop-recording race before export
**What goes wrong:** Export starts on a file that's still being finalized → truncated/invalid movie.
**Why:** `stopCapture()` returning ≠ recording finished writing.
**How to avoid:** Gate export on the `SCRecordingOutputDelegate` completion (and verify with `AVAsset.duration > 0` + `isPlayable` before transcode).
**Warning signs:** Zero-byte or unplayable .mov; "No frames captured"-class errors.

### Pitfall 10: Bezel/screenshot aspect mismatch
**What goes wrong:** Distorted device screens when compositing drawn bezels or ASC canvases.
**Why:** Scaling content non-uniformly to fit a cutout/canvas.
**How to avoid:** Never stretch: uniform `min(scaleX, scaleY)` (Pattern 4); assert |content.aspect − canvas-content-area.aspect| within epsilon in tests.
**Warning signs:** Elliptical home-indicator/corner curves.

### Pitfall 11: `simctl`-style fallback vs tracked window mismatch
**What goes wrong:** If A3 fallback is used, multiple booted devices make "the" screenshot ambiguous.
**Why:** simctl addresses devices by UDID; the panel tracks windows by CGWindowID.
**How to avoid:** Only use fallback with the UDID resolved from the tracked `SimulatorWindow.udid` [VERIFIED: SimulatorWindow.swift:30]; nil UDID → disable fallback with a hint (this mirrors the existing "UDID may be nil" rule).
**Warning signs:** Screenshot of the wrong device in multi-device setups.

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| CGWindowListCreateImage for window capture | ScreenCaptureKit (`SCScreenshotManager`, `SCStream`) | CGWindowListCreateImage deprecated (macOS 14 removal path) | Scaffold already on SCK — keep; never reach for CGWindowListCreateImage |
| SCStreamOutput + AVAssetWriter for recording | `SCRecordingOutput` direct-to-file | macOS 15.0 (WWDC24) | Project floor is exactly macOS 15 — record without custom muxing [VERIFIED: availability metadata] |
| Manual pixel-size handling via ×2 fudge | `SCStreamFrameInfo.contentRect` + `.scaleFactor` attachments | Documented in WWDC24 sample | Pixel-exact content rect instead of magic multipliers |
| Lifting Simulator touches via AX events + own overlay | Simulator-native `ShowSingleTouches` pref rendering | Long-standing Simulator capability (corroborated 2018→2024 sources) | Zero compositing code for the criterion |

**Deprecated/outdated:** `CGWindowListCreateImage`; `CIFilter` GIF pipelines; per-frame `CIContext` churn; AVAssetWriter-only recording for simple file output.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Meta "Devices from Design at Meta" device frames are free for commercial use and can be bundled | Available Approaches B3 | Licensing violation if bundled without verification — gated behind Open Question 1; v1 ships license-clean modes regardless |
| A2 | `SCRecordingOutputConfiguration.outputURL` infers container from file extension; `.mp4` output unverified, `.mov` is the community/Apple-sample default | Pattern 3, Pitfalls 9 | Wrong container fails at write time — mitigation: record .mov, produce MP4 via AVAssetExportSession (works regardless) |
| A3 | Host MacBook Pro (M3 Pro) internal display supports ProMotion 120 Hz and will be the test display | Pitfall 5, Environment Availability | 120 fps criterion unverifiable on 60 Hz panels — manual smoke must note display; criterion becomes "configured rate 120, delivered ≤ display" |
| A4 | Desktop-independent window capture includes titlebar pixels; `contentRect` attachment strips them cleanly | Pitfall 4 | Framed output contains chrome — verify at implementation; crop fallback is straightforward |
| A5 | Drawn-bezel corner radii (~per-device tuning) acceptable for v1 marketing use | Available Approaches B2 | Cosmetic only; user may insist on photoreal assets (→ Open Question 1) |
| A6 | Simulator relaunch is required for `ShowSingleTouches` to take effect | Pattern 6 | If stale-cfprefsd pickup works live, the relaunch hint is merely conservative — no functional harm |

## Open Questions

1. **Bezel asset strategy (needs user decision — discuss-phase)**
   - What we know: license-clean v1 = Simulator-native + drawn bezels; photoreal requires third-party artwork (Meta devices set is the industry standard source; license unverified [A1]).
   - Recommendation: ship B1+B2 in this phase; ask user whether to add photoreal assets (and which set) before planning asset tasks.
2. **Audio in recordings?**
   - What we know: criteria never mention audio; SCStream supports `capturesAudio` (+ `excludesCurrentProcessAudio`) [VERIFIED: SCStreamConfiguration doc].
   - Recommendation: v1 mute (`capturesAudio = false`), UI leaves room for a later toggle; confirm at discuss-phase.
3. **Landscape ASC presets?**
   - What we know: Apple accepts landscape transposes of every size [VERIFIED: spec table].
   - Recommendation: v1 portrait-only presets; add landscape once rotation support is wanted.
4. **"Wallpaper" scope**
   - What we know: criteria say "wallpaper/background padding".
   - Recommendation: v1 solid+gradient backgrounds; custom image import is a cheap stretch — confirm appetite at discuss-phase.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Xcode 26.3 + macOS SDK 26.2 | Build; SCK APIs | ✓ | 26.3 (17C529) [VERIFIED this session] | — |
| macOS host ≥ 15 (SCRecordingOutput) | Recording | ✓ | 26.6.2 [VERIFIED this session] | — |
| Screen Recording TCC grant | All capture | Per-run (onboarding requests; poll exists) | — | Degraded UI + setup flow (Pitfall 2) — no code fallback |
| Booted iOS Simulator | Manual smoke | ✗ at research time ("No devices are booted" [VERIFIED: simctl this session]) | — | `xcrun simctl boot` in smoke plan |
| Simulator.app (AX-visible, named "Simulator") | Window tracking | ✓ | `/Applications/Xcode.app/Contents/Developer/Applications/Simulator.app` [VERIFIED this session — note Xcode 26 location] | — |
| ProMotion display for 120 fps delivery | 120 fps criterion | Likely (M3 Pro MacBook Pro) [ASSUMED A3] | — | Verify delivered rate; document display dependency |
| ffmpeg / GIF third-party | — | ✗ and **forbidden** (REQ-nfr-03) | — | ImageIO (recommended path) |

**Missing dependencies with no fallback:** none — TCC grant is a user action, not a missing tool.
**Missing dependencies with fallback:** none — all probes passed.

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | Swift Testing (`import Testing`, `@Test`, `#expect`) — house standard [VERIFIED: TESTING.md] |
| Config file | none — Xcode default runner |
| Quick run command | `xcodebuild test -project BoosterSimApp.xcodeproj -scheme BoosterSimApp -destination 'platform=macOS' -only-testing:BoosterSimAppTests` |
| Full suite command | same + `-skip-testing:BoosterSimAppUITests` (phase-5 gate standard: unfiltered run exits 65 on pristine HEAD from pre-existing UI-test env failure [VERIFIED: STATE.md:87]) |

### Phase Requirements → Test Map

| Req ID (criterion) | Behavior | Test Type | Automated Command | File Exists? |
|--------------------|----------|-----------|-------------------|--------------|
| P2-1 screenshot + framing | ASC preset pixel sizes exact; scale/center/pad math; alpha flatten decision | unit (pure geometry) | `… -only-testing:BoosterSimAppTests/CaptureFramingTests` | ❌ Wave 0 (`CaptureFramingTests.swift`) |
| P2-1 bezels | Bezel inset/cutout geometry; uniform-scale invariant (no stretch) | unit | same file | ❌ Wave 0 |
| P2-2 save destinations | Destination enum mapping; filename builder (device + preset + timestamp, sanitization); AppSettings round-trip | unit | `… -only-testing:BoosterSimAppTests/CaptureSettingsTests` | ❌ Wave 0 |
| P2-3 recording 120 fps | fps↔CMTime mapping (`120 → CMTime(1,120)`); queueDepth within 3…8; codec enum mapping; container choice | unit | `… -only-testing:BoosterSimAppTests/CaptureExportConfigTests` | ❌ Wave 0 |
| P2-3 recording state machine | idle → recording → finishing → exported transitions (CertificateOperation style) | unit | same file | ❌ Wave 0 |
| P2-4 GIF export | fps→centisecond delay quantization (10fps→10cs exact); loop=0; output-width downsample mapping | unit | same file | ❌ Wave 0 |
| P2-3 touch indicators | Pref key/domain constants; restore-semantics state machine (set/unset/restore) | unit | `… -only-testing:BoosterSimAppTests/CaptureSettingsTests` | ❌ Wave 0 |
| Live screenshot via SCScreenshotManager | Real CGImage from booted Simulator window | manual-only | — | justification: needs TCC grant + booted device + WindowServer — not automatable in CI |
| Recording produces playable .mov | AVAsset duration>0, playable, dimensions match window | manual-only (scriptable smoke) | — | same justification; measure delivered fps here (Pitfall 5) |
| Touch dots visible in recording | Visual confirmation | manual-only | — | visual |
| Thumbnail panel appears/auto-hides | Visual + timing | manual-only | — | visual |
| Clipboard/Desktop/custom save | Paste into Preview; file exists at path | manual-only | — | needs real user-session clipboard/desktop |
| Permission-denied degradation | Setup UI shown; no crash; recovers after grant+relaunch | manual-only | — | TCC state machine not simulatable in tests |

### Sampling Rate (Nyquist)

- **Per task commit:** quick unit command above (<30s).
- **Per wave merge:** full unit suite + Debug build of the app scheme.
- **Phase gate:** full unit suite green + the manual smoke checklist (boot one Simulator; screenshot → verify dimensions vs preset + no alpha; 30s recording on internal display → verify playable + measure delivered fps; GIF export loop check; each destination once; thumbnail appears once) + `docs/system-architecture.md` updated (house docs rule).

### Wave 0 Gaps

- [ ] `BoosterSimAppTests/CaptureFramingTests.swift` — preset table, framing math, no-stretch invariant, alpha rule
- [ ] `BoosterSimAppTests/CaptureExportConfigTests.swift` — CMTime/queueDepth/codec mappings, GIF timing quantization, recording state machine
- [ ] `BoosterSimAppTests/CaptureSettingsTests.swift` — AppSettings capture keys round-trip, filename builder, touch-pref restore machine
- [ ] No framework install/config needed (Swift Testing runs via the existing scheme)

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | n/a — local single-user tool |
| V3 Session Management | no | n/a |
| V4 Access Control | no (OS-level) | macOS TCC Screen Recording is the access gate; app degrades when denied |
| V5 Input Validation | yes | Filename builder sanitizes device names; NSSavePanel governs write paths; no path concatenation from untrusted strings |
| V6 Cryptography | no | n/a |
| V7 Errors & Logging | yes | AppLogger with redaction: never log captured-file paths, UDIDs, or screen contents [VERIFIED: CONVENTIONS.md logging rule] |

### Known Threat Patterns for this stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Captures contain user's screen content (privacy) | Information Disclosure | TCC gate + auto-hiding thumbnail + deterministic temp cleanup + no disk caching beyond requested output + no path logging |
| Cross-app preference write (`com.apple.iphonesimulator`) | Tampering | Scope: single key (`ShowSingleTouches`), snapshot+restore semantics; document in code + docs (AGENTS.md permission-documentation rule) |
| Clipboard exfiltration of captures | Information Disclosure | User-initiated only; clipboard cleared by system policy — document behavior in UI copy |
| Temp files with screen content left behind | Information Disclosure | Cleanup in exporter `finally`-equivalent (defer) + app-launch sweep of stale `boostersim-capture-*` temp files |

## Sources

### Primary (HIGH confidence)
- developer.apple.com/documentation/screencapturekit/scscreenshotmanager — availability macOS 14+, captureImage/captureSampleBuffer signatures [fetched this session]
- developer.apple.com/documentation/screencapturekit/screcordingoutput + screcordingoutputconfiguration (+ outputURL, videoCodecType) — availability macOS 15.0+ [fetched]
- developer.apple.com/documentation/screencapturekit/scstreamconfiguration (+ minimumframeinterval) — full property list; "reciprocal of the maximum frame rate" quote [fetched]
- developer.apple.com/documentation/screencapturekit/sccontentfilter/init(desktopindependentwindow:) [fetched]
- developer.apple.com/documentation/screencapturekit/capturing-screen-content-in-macos — WWDC24 sample: filter/config/queueDepth/output-attachment patterns; TCC restart note [fetched]
- developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/ — sizes + formats + alpha rule [fetched; values quoted verbatim in this document]
- In-repo reads this session: CaptureService.swift, CaptureTabView.swift, AppDelegate.swift, SideWindowController.swift, SideWindowView.swift, WindowEnumerator.swift, SimulatorWindowTracker.swift, SimulatorWindow.swift, PermissionManager.swift, SimCtlService.swift, AppSettings.swift, DeepLinkService.swift, AXHighlightPanel.swift, DesignTokens.swift, AppLogger.swift, AGENTS.md, docs/design-guidelines.md, docs/system-architecture.md, docs/project-roadmap.md, .planning/{REQUIREMENTS,STATE,ROADMAP,PROJECT}.md, .planning/codebase/{STRUCTURE,CONVENTIONS,TESTING}.md, .planning/intel/requirements.md
- Local probes: `xcodebuild -version`, `sw_vers`, `xcodebuild -showsdks`, `xcrun simctl io --help`, Simulator.app asset probe, `git status`

### Secondary (MEDIUM confidence)
- adamwulf.me/2024/01/removing-xcode-simulator-touch-indicators — ShowSingleTouches + related pref family
- amanhimself.dev/blog/show-touch-indicator-on-ios-simulator; medium.com/@ant_one/show-touch-highlights-on-ios-simulator — same key, independent corroboration
- developer.apple.com/documentation/imageio/kcgimageanimationdelaytime — animated-image delay property
- nonstrict.eu/blog/2023/recording-to-disk-with-screencapturekit — pre-SCRecordingOutput AVAssetWriter pattern (context for the alternative)

### Tertiary (LOW confidence)
- community.adobe.com GIF delay-centisecond thread — quantization symptom context
- meta.com/design-at-meta/tools/devices — existence only; license text NOT verified (A1)

## Metadata

**Confidence breakdown:**
- Architecture/pipeline: HIGH — every API verified on Apple doc pages this session; scaffold defects read from source
- Framing spec: HIGH — Apple's table quoted verbatim
- Pitfalls: HIGH for in-repo-derived (1,3,8,9,10), MEDIUM for TCC/chrome/touch-relaunch (2,4,A4,A6)
- 120 fps delivery: MEDIUM — API verified, physical delivery display-dependent (A3)

**Research date:** 2026-08-30
**Valid until:** 2026-09-29 (Apple-SDK domain is stable; revisit if Xcode/SDK majors land or ASC spec changes)
