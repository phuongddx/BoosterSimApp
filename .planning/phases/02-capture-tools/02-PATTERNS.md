# Phase 2: Capture Tools - Pattern Map

**Mapped:** 2026-08-30
**Files analyzed:** 17
**Analogs found:** 16 / 17 (TouchIndicatorController's CFPreferences half has no in-repo precedent — RESEARCH.md Pattern 6 is the source)

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality | Drift Risk |
|-------------------|------|-----------|----------------|---------------|------------|
| `BoosterSimApp/Services/CaptureService.swift` (rewrite) | service (facade) | request-response + event-driven | `BoosterSimApp/Services/DeepLinkService.swift` + `BoosterSimApp/Services/NetworkConditionService.swift` | exact | Copying legacy DeepLinkService shape (not `@MainActor`) instead of the modern NetworkConditionService shape |
| `BoosterSimApp/Services/ScreenshotService.swift` | service | request-response (one-shot async) | `BoosterSimApp/Services/CaptureService.swift:82–116` (existing SCK setup) | role-match | Reintroducing the scaffold's display filter / `.main` queue / ×2 fudge |
| `BoosterSimApp/Services/RecordingService.swift` | service | event-driven (stream callbacks → file) | `BoosterSimApp/Services/CaptureService.swift:82–116, 276–312` | role-match | Frame accumulation array; delegate state touched off-main without the `Task { @MainActor }` hop |
| `BoosterSimApp/Services/CaptureExporter.swift` | service | batch/transform (file → file) | `BoosterSimApp/Services/CaptureService.swift:198–274` + `BoosterSimApp/Services/SimCtlService.swift:31–66` | role-match | Per-frame `CIContext`; async/await in a new service (violates the documented exception scope); sleep-polling |
| `BoosterSimApp/Services/TouchIndicatorController.swift` | service | request-response (pref write/restore machine) | `BoosterSimApp/Services/NetworkConditionService.swift` (state machine shape) | role-match | Shelling out to `defaults` (prohibited); losing the "was unset" restore case |
| `BoosterSimApp/Utilities/CaptureCompositor.swift` | utility | transform (pure geometry) | `BoosterSimApp/Windows/PositionCalculator.swift` | exact | Making it depend on AppKit windows/SCK — kills unit-testability |
| `BoosterSimApp/Windows/CaptureThumbnailPanel.swift` | window/panel | event-driven (auto-hide timer) | `BoosterSimApp/Windows/AXHighlightPanel.swift` | exact | Keeping `ignoresMouseEvents = true` (thumbnail must be clickable); non-token sizing |
| `BoosterSimApp/Models/ASCFramePreset.swift` | model | transform (discrete enum + computed) | `BoosterSimApp/Models/AppSettings.swift:9–32` (`SideWindowPosition`) | exact | Raw values treated as free to rename (they are persistence keys) |
| `BoosterSimApp/Models/CaptureDestination.swift` | model | transform (enum w/ associated value) | `BoosterSimApp/Services/CertificateModels.swift:1–30` | exact | Forgetting the associated-value case style (`custom(URL)`) and switching over all cases |
| `BoosterSimApp/Models/BezelMode.swift` | model | transform (enum) | `BoosterSimApp/Models/AppSettings.swift:9–32` (`SideWindowPosition`) | exact | Carrying over scaffold `DeviceBezel` names with no renderer backing |
| `BoosterSimApp/Models/AppSettings.swift` (modify) | config | CRUD (persistence) | self — existing `@AppStorage` block | self | Complex types (URL) forced into `@AppStorage` instead of the StorageKey/defaults pattern |
| `BoosterSimApp/Utilities/AppLogger.swift` (modify) | utility | — | self — category enum | self | Logging capture file paths (redaction rule) |
| `BoosterSimApp/Views/SideWindow/tabs/CaptureTabView.swift` (rewrite body) | component | request-response (UI) | `BoosterSimApp/Views/SideWindow/network/NetworkConditionsSectionView.swift` | exact | Repeating the current file's raw `12/8/6` values (flagged conventions deviation) |
| `BoosterSimApp/App/AppDelegate.swift` (modify) | app wiring | — | self — lazy var + controller injection | self | Wiring panels/services outside `AppDelegate` ownership |
| `BoosterSimAppTests/CaptureFramingTests.swift` | test | — | `BoosterSimAppTests/ConditionVerdictTests.swift` | exact | Testing through SCK instead of the pure compositor |
| `BoosterSimAppTests/CaptureExportConfigTests.swift` | test | — | `BoosterSimAppTests/NetworkConditionServiceTests.swift:14–24` + `CertificateServiceTests.swift` | exact | Asserting on live recording instead of config/state mappings |
| `BoosterSimAppTests/CaptureSettingsTests.swift` | test | — | `BoosterSimAppTests/NetworkConditionServiceTests.swift:26–51` | exact | Using `.standard` defaults instead of an isolated suite |

## Pattern Assignments

### `BoosterSimApp/Services/CaptureService.swift` (service facade, rewrite)

**Analog:** `BoosterSimApp/Services/DeepLinkService.swift` (async bridge — the documented CONVENTIONS exception) + `BoosterSimApp/Services/NetworkConditionService.swift` (modern `@MainActor` published-state shape)

**Sync facade over async internals** — DeepLinkService.swift lines 50–52:
```swift
func openInSimulator(udid: String?) {
    Task { await openInSimulatorAsync(udid: udid) }
}
```

**Modern service shell: `@MainActor` + `@Published private(set)` + injected deps** — NetworkConditionService.swift lines 51–62:
```swift
@MainActor
final class NetworkConditionService: ObservableObject {

    // MARK: - Properties

    @Published private(set) var state: NetworkConditionState = .idle
    @Published private(set) var airplane: Bool

    private let commandServer: any CommandBroadcasting
    private let defaults: UserDefaults
```

**Key adaptation:** Keep the class `@MainActor final class CaptureService: ObservableObject` (it already is). Slim it to a facade: public methods synchronous (`takeScreenshot()`, `startRecording()`, `stopRecording()`, `exportRecording(as:)`, `save(...)`) each bridging via `Task { await … }`; all state `@Published private(set)` and mutated only on main. **Do not** copy DeepLinkService's non-`@MainActor` class + `await MainActor.run` dance — that is the legacy shape; the modern NetworkConditionService shape already runs on main, so the hop is only needed at SCK callback boundaries (see RecordingService below). Inject `ScreenshotService`/`RecordingService`/`CaptureExporter` via init (NetworkConditionService lines 71–101 show the convenience-init + doc-comment house style).

---

### `BoosterSimApp/Services/ScreenshotService.swift` (service, one-shot async)

**Analog:** `BoosterSimApp/Services/CaptureService.swift:82–116` — the only in-repo ScreenCaptureKit code (the stream setup being rewritten, but its do/catch + `SCShareableContent` shape is the house SCK pattern)

**SCK acquisition shape** — CaptureService.swift lines 82–95:
```swift
func startRecording() async {
    do {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let display = content.displays.first else {
            lastError = "No display found"
            return
        }

        let filter = SCContentFilter(display: display, excludingApplications: [], exceptingWindows: [])
        let config = SCStreamConfiguration()
        config.width = display.width * 2
        config.height = display.height * 2
        config.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(quality.fps))
        config.capturesAudio = false
```

**Key adaptation:** Same `do/catch` + `SCShareableContent` + config flow, but: match `content.windows.first(where: { $0.windowID == trackedWindowID })` (the tracker already holds `CGWindowID` — `SimulatorWindowTracker`), build `SCContentFilter(desktopIndependentWindow: scWindow)`, and end with `try await SCScreenshotManager.captureImage(contentFilter:configuration:)` instead of a stream. **Drift guards (anti-patterns from RESEARCH):** never the display filter above (recursive self-capture), no `display.width * 2` fudge (use `window.frame × scale`), `showsCursor = false`, `ignoreShadowsSingleWindow = true`.

---

### `BoosterSimApp/Services/RecordingService.swift` (service, event-driven stream)

**Analog:** `BoosterSimApp/Services/CaptureService.swift:82–116` (stream lifecycle) + `:276–312` (non-isolated delegate wrappers)

**Delegate wrapper with the Swift 6 isolation hop** — CaptureService.swift bottom of file, lines 291–312 (hop verified at 299–312):
```swift
/// Wrapper to avoid NSObject inheritance on CaptureService.
private final class StreamDelegate: NSObject, SCStreamDelegate {
    weak var owner: CaptureService?

    init(owner: CaptureService) {
        self.owner = owner
    }

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        Task { @MainActor [weak self] in
            guard let owner = self?.owner else { return }
            owner.handleStreamError(error.localizedDescription)
        }
    }
}
```

**Stream wiring** — CaptureService.swift lines 97–107 (keep the shape, change the pieces marked):
```swift
streamOutput = CaptureStreamOutput(onFrame: { [weak self] frame in
    self?.capturedFrames.append(frame)          // REMOVE — SCRecordingOutput writes to disk
})

streamDelegate = StreamDelegate(owner: self)
stream = SCStream(filter: filter, configuration: config, delegate: streamDelegate)
try stream?.addStreamOutput(streamOutput!, type: .screen, sampleHandlerQueue: .main)  // NOT .main — dedicated serial queue
try await stream?.startCapture()
```

**Key adaptation:** Same wrapper-per-protocol pattern for `SCStreamOutput`, `SCStreamDelegate`, and `SCRecordingOutputDelegate` (private `final class NSObject` wrappers at file bottom, `weak var owner`, `Task { @MainActor [weak self] }` hop into published state). Replace `capturedFrames` with `SCRecordingOutput(configuration:delegate:)` attached via `addStreamOutput(_:type:sampleHandlerQueue:)`. Config: `minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(120))`, `queueDepth = 5`, `capturesAudio = false`. Gate export on the recording-output finish callback (Pitfall 9) — `stopCapture()` returning is not "file finalized".

---

### `BoosterSimApp/Services/CaptureExporter.swift` (service, batch transform)

**Analog:** `BoosterSimApp/Services/CaptureService.swift:247–274` (ImageIO GIF — keep the encoder, fix the defects) + `BoosterSimApp/Services/SimCtlService.swift:31–66` (background-queue pattern for CPU-bound work)

**GIF encode block to carry over** — CaptureService.swift lines 247–267 (defects marked):
```swift
guard let destination = CGImageDestinationCreateWithURL(tempURL as CFURL, "com.compuserve.gif" as CFString, capturedFrames.count, nil) else {
    lastError = "Failed to create GIF destination"
    return
}

let frameProperties = [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: 1.0 / Double(quality.fps)]] as CFDictionary  // FIX: integer centiseconds

for frame in capturedFrames {
    if let buffer = CMSampleBufferGetImageBuffer(frame) {
        let ciImage = CIImage(cvPixelBuffer: buffer)
        let context = CIContext()               // FIX: one context per EXPORT, not per frame
        if let cgImage = context.createCGImage(ciImage, from: ci.extent) {
            CGImageDestinationAddImage(destination, cgImage, frameProperties)
        }
    }
}
```

**Background-queue house pattern** — SimCtlService.swift line 37:
```swift
return Future { promise in
    DispatchQueue.global(qos: .userInitiated).async {
```

**Key adaptation:** Keep `CGImageDestinationCreateWithURL` + `com.compuserve.gif` + `kCGImagePropertyGIFLoopCount: 0`, but source frames from `AVAssetReader` over the recorded .mov (not a live frame array), hoist `CIContext` (or use CGContext) to one per export, and quantize delay to whole centiseconds in pure code (`10 fps → 10 cs`). MOV→MP4 via `AVAssetExportSession` (replaces the AVAssetWriter sleep-poll loop at lines 226–228 — do not port it). Run the reader loop on `DispatchQueue.global(qos: .userInitiated)` like SimCtlService; report progress via `@Published` + Combine. **No async/await** — CONVENTIONS reserves the exception for the capture services; the exporter is a new general-purpose unit.

---

### `BoosterSimApp/Services/TouchIndicatorController.swift` (service, pref write/restore machine)

**Analog:** `BoosterSimApp/Services/NetworkConditionService.swift` — state-machine + restore-semantics shape (enum lines 8–49, quartet ~lines 140–170)

**State machine shape to copy** — NetworkConditionService.swift lines 8–27 and 140–170 (quartet):
```swift
enum NetworkConditionState: Equatable {
    case idle
    case applying
    case applied
    case error(String)

    var isWorking: Bool {
        switch self {
        case .idle, .applied, .error:
            false
        case .applying:
            true
        }
    }

    func canTransition(to next: NetworkConditionState) -> Bool {
        switch self {
        case .idle:
            switch next {
            case .idle, .applying: return true
            case .applied, .error: return false
            }
        // ...
```
```swift
    private func begin() -> Bool {
        guard !state.isWorking else { return false }
        transition(to: .applying)
        return true
    }

    private func finish() {
        transition(to: .applied)
    }

    private func transition(to next: NetworkConditionState) {
        if state != next, !state.canTransition(to: next) {
            assertionFailure("Illegal network condition transition: \(state) -> \(next)")
        }
        state = next
    }
```

**Key adaptation:** Model recording as `idle → applying(pref write) → recording → restoring → idle` with the same `begin/finish/transition` + `assertionFailure` guards. The mechanism itself has **no in-repo precedent** — use RESEARCH.md Pattern 6 verbatim: `CFPreferencesCopyAppValue` (snapshot), `CFPreferencesSetAppValue` + `CFPreferencesAppSynchronize` on domain `com.apple.iphonesimulator`, key `ShowSingleTouches`, restore via snapshot or `kCFNull` when previously unset. **Never** spawn `/usr/bin/defaults` (CONVENTIONS prohibits direct subprocesses; SimCtlService wraps only `xcrun simctl`).

---

### `BoosterSimApp/Utilities/CaptureCompositor.swift` (utility, pure geometry)

**Analog:** `BoosterSimApp/Windows/PositionCalculator.swift` — the house pure-math utility (enum namespace, static funcs, no I/O, doc comments)

**Pure-geometry utility style** — PositionCalculator.swift lines 9–25, 44–48:
```swift
enum PositionCalculator {

    // MARK: - Public API

    /// Calculates the panel frame relative to the simulator window and screen.
    /// - Parameters:
    ///   - simulatorFrame: Simulator window frame in screen coordinates
    ///   - position: Requested side window position mode
    ///   - screenFrame: Visible frame of the screen containing the simulator
    static func panelFrame(
        simulatorFrame: CGRect,
        position: SideWindowPosition,
        screenFrame: CGRect,
        isCollapsed: Bool,
        contentHeight: CGFloat
    ) -> CGRect {
```
```swift
    private static func centeredY(sim: CGRect, height: CGFloat, screen: CGRect) -> CGFloat {
        let ideal = sim.midY - height / 2
        return max(screen.minY, min(ideal, screen.maxY - height))
    }
```

**Key adaptation:** Same shape — caseless `enum CaptureCompositor`, static pure functions returning value types (`struct FramingResult: Equatable`), `///` doc comments with parameter lists, MARK order, clamp math with `min`/`max`. Compositor adds CGContext drawing (fill background → rounded-rect clip → draw content → flatten sRGB no-alpha). Lives in `Utilities/` per RESEARCH structure; **no** SCK/AppKit-window dependencies so `CaptureFramingTests` can run it headless. The math itself (scale = `min(availW/cW, availH/cH)`, centered rounded origin) comes from RESEARCH.md Pattern 4.

---

### `BoosterSimApp/Windows/CaptureThumbnailPanel.swift` (NSPanel)

**Analog:** `BoosterSimApp/Windows/AXHighlightPanel.swift` — exact precedent for a borderless auto-hiding floating panel

**Panel configuration** — AXHighlightPanel.swift lines 29–42:
```swift
    init() {
        super.init(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isOpaque              = false
        backgroundColor       = .clear
        level                 = .floating
        ignoresMouseEvents    = true
        collectionBehavior    = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isReleasedWhenClosed  = false
        contentView           = highlightView
    }
```

**Timer auto-hide** — AXHighlightPanel.swift lines ~55–60:
```swift
    private func scheduleDismiss() {
        dismissTimer = Timer.scheduledTimer(withTimeInterval: 2.5, repeats: false) { [weak self] _ in
            self?.hide()
        }
    }
```

**Key adaptation:** Copy verbatim, then: 3.0s interval; content = `NSImageView` (proportionally scaled, `CornerRadius.large` mask, shadow) instead of the highlight view; `ignoresMouseEvents = false` + click action = `NSWorkspace.shared.activateFileViewerSelecting([url])` (thumbnail must be clickable — the one behavioral divergence); anchor near the Simulator frame's trailing edge; Reduce Motion = fade in/out, no slide. Keep `isReleasedWhenClosed = false` (house memory rule).

---

### `BoosterSimApp/Models/ASCFramePreset.swift`, `CaptureDestination.swift`, `BezelMode.swift` (models)

**Analog:** `BoosterSimApp/Models/AppSettings.swift:9–32` (`SideWindowPosition`) for discrete option enums; `BoosterSimApp/Services/CertificateModels.swift:1–30` for the associated-value enum style

**Discrete option enum with computed presentation** — AppSettings.swift lines 9–20:
```swift
enum SideWindowPosition: String, CaseIterable {
    case left, right, bottom, dynamic

    var label: String {
        switch self {
        case .left: return "Left"
        ...
        }
    }
```

**Associated-value enum style** — CertificateModels.swift lines 1–13:
```swift
enum CertificateStatus: Equatable {
    case notGenerated
    case generated(cn: String, expiry: Date, sha256: String)
    case installed(cn: String, expiry: Date, sha256: String, deviceName: String, udid: String)

    var certificateMetadata: CertificateMetadata? {
        switch self {
        case .notGenerated: nil
        ...
```

**Key adaptation:** `ASCFramePreset` = `String` raw + `CaseIterable` + computed `pixelSize: CGSize` (exact Apple ASC values: 1320×2868 etc.) + `displayName`. `BezelMode` = same shape (`none / simulatorNative / drawn`). `CaptureDestination` = `CertificateStatus`-style enum with an associated value (`case custom(URL)`) plus `desktop / clipboard / ask`; exhaustive switches, computed presentation. **Drift guard:** raw values are persistence keys — NetworkConditionService's init doc warns "renaming strands stored selections"; pick raw values once.

---

### `BoosterSimApp/Models/AppSettings.swift` (modify — capture keys)

**Analog:** self — existing `@AppStorage` block

**Current pattern** — AppSettings.swift lines 33–37:
```swift
final class AppSettings: ObservableObject {
    @AppStorage("sideWindowPosition") var position: SideWindowPosition = .dynamic
    @AppStorage("showSideWindow") var showSideWindow: Bool = true
    @AppStorage("launchAtLogin") var launchAtLogin: Bool = false
    @AppStorage("xcodePath") var xcodePath: String = ""
```

**Key adaptation:** Append capture keys (`captureDestination`, `captureASCFramePreset`, `captureBezelMode`, `captureBackground`, `captureExportFormat`, `captureGIFSize`, `captureGIFFps`, `captureShowTouchIndicators`) as `@AppStorage` with `RawRepresentable String` enums. For the custom-path URL (non-`@AppStorage`-friendly type), follow NetworkConditionService's `private enum StorageKey` + injected `UserDefaults` pattern instead of forcing the type.

---

### `BoosterSimApp/Utilities/AppLogger.swift` (modify — capture category)

**Analog:** self — category enum

**Current pattern** — AppLogger.swift lines 8–14:
```swift
enum AppLogger {
    private static let subsystem = "com.nextlabs.BoosterSimApp"

    static let windowTracking = Logger(subsystem: subsystem, category: "WindowTracking")
    static let permissions     = Logger(subsystem: subsystem, category: "Permissions")
    static let settings        = Logger(subsystem: subsystem, category: "Settings")
    static let certificates    = Logger(subsystem: subsystem, category: "Certificates")
    static let network         = Logger(subsystem: subsystem, category: "Network")
}
```

**Key adaptation:** Add `static let capture = Logger(subsystem: subsystem, category: "Capture")`. Message style follows `CertificateService.fail` (05-PATTERNS verified, CertificateService.swift lines 156–158): redact paths/UDIDs before logging, `AppLogger.capture.error("\(message, privacy: .public)")`.

---

### `BoosterSimApp/Views/SideWindow/tabs/CaptureTabView.swift` (component, rewrite body)

**Analog:** `BoosterSimApp/Views/SideWindow/network/NetworkConditionsSectionView.swift` (section composition) + self (existing mount point with `Task { await }` button pattern)

**Section composition style** — NetworkConditionsSectionView.swift lines 17–35:
```swift
    var body: some View {
        CollapsibleSection(title: "Network Conditions", icon: "network", isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                airplaneRow
                    .padding(.horizontal, Spacing.md)
                    .padding(.top, Spacing.sm)
                profilePillsRow
                    .padding(.horizontal, Spacing.md)
                ...
            }
            .padding(.bottom, Spacing.sm)
            .animation(animation, value: networkConditionService.state)
        }
    }
```

**Service-method button + Reduce Motion animation** — NetworkConditionsSectionView.swift lines 6–14, 40–46:
```swift
    @EnvironmentObject var networkConditionService: NetworkConditionService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isExpanded = false

    private var animation: Animation {
        reduceMotion ? .linear(duration: 0.1) : .easeInOut(duration: 0.2)
    }
```
```swift
    private var airplaneBinding: Binding<Bool> {
        Binding(
            get: { networkConditionService.airplane },
            set: { networkConditionService.setAirplane($0) }
        )
    }
```

**Existing async button shape to keep** — CaptureTabView.swift lines 17–31:
```swift
                    HStack(spacing: 12) {
                        Button {
                            Task {
                                if captureService.isRecording {
                                    await captureService.stopRecording()
                                } else {
                                    await captureService.startRecording()
                                }
                            }
                        } label: {
```

**Key adaptation:** Keep the tab as mount point + the `Task { await }` button shape, but with the facade's now-sync public API the `Task` wrapper becomes optional for control presses. Compose the tab from `CollapsibleSection`s with private computed sub-views (screenshot section, recording section, export section, destination section), status captions driven by service operation state, Reduce Motion 0.1s linear, pill-style pickers per `profilePill` (lines ~65–81) for the 260pt width. **Drift guard:** replace the flagged raw values at current lines 96/109/114 (`.padding(8)`, `.padding(12)`, `.cornerRadius(6)`) with `Spacing.sm`/`Spacing.md`/`CornerRadius.medium` — conventions.md names this file as the deviation to fix.

---

### `BoosterSimApp/App/AppDelegate.swift` (modify — wiring)

**Analog:** self — lazy var + controller injection

**Current wiring** — AppDelegate.swift lines 20–48:
```swift
    lazy var networkConditionService = NetworkConditionService()
    lazy var deepLinkService     = DeepLinkService()
    lazy var captureService         = CaptureService()
    lazy var axHighlightPanel    = AXHighlightPanel()

    // MARK: - Windows

    lazy var sideWindowController = SideWindowController(
        settings: settings,
        ...
        networkConditionService: networkConditionService,
        captureService: captureService
    )
```

**Key adaptation:** New services (`ScreenshotService`, `RecordingService`, `CaptureExporter`, `TouchIndicatorController`) become lazy vars injected into `CaptureService`'s init (or into `SideWindowController` like peers); `CaptureThumbnailPanel` follows the `axHighlightPanel` lazy-var precedent. Any new `@EnvironmentObject` registrations go in `SideWindowController.embedSwiftUIContent` alongside the existing ones (conventions: services reach views only via environment).

---

### `BoosterSimAppTests/CaptureFramingTests.swift` (test, pure logic)

**Analog:** `BoosterSimAppTests/ConditionVerdictTests.swift` — pure-function test style

**Pure-logic test structure** — ConditionVerdictTests.swift lines 1–23:
```swift
import Foundation
import Testing
@testable import BoosterSimApp

struct ConditionVerdictTests {

    private func makeRequest(_ urlString: String) -> URLRequest {
        URLRequest(url: URL(string: urlString)!)
    }

    // MARK: - Airplane

    @Test func airplaneFailsEveryRequestRegardlessOfRules() {
        let snapshot = BoosterCommand(
            airplane: true,
            blockRules: [BlockRule(id: UUID(), domain: "ads.example.net", pathPrefix: nil, isEnabled: true)]
        )

        let verdict = evaluate(
            request: makeRequest("https://api.example.com/v1/users"),
            snapshot: snapshot
        )

        #expect(verdict == .fail(.notConnectedToInternet))
    }
```

**Key adaptation:** Same `struct` (not class), private `makeX()` builders, MARK-grouped `@Test`s, `#expect` on pure outputs. Subject = `CaptureCompositor.frame(content:preset:padding:mode:)` + `ASCFramePreset.pixelSize` table + alpha-flatten decision. No SCK, no windows, no mocks needed — that is the point of the pure compositor.

---

### `BoosterSimAppTests/CaptureExportConfigTests.swift` (test, config/state mappings)

**Analog:** `BoosterSimAppTests/NetworkConditionServiceTests.swift:14–24` (state machine assertions) + `CertificateServiceTests.swift` (same shape, 05-PATTERNS verified lines 1–13)

**State-machine test pattern** — NetworkConditionServiceTests.swift lines 14–24:
```swift
    @Test func networkConditionStateAllowsExpectedTransitions() {
        #expect(NetworkConditionState.idle.canTransition(to: .applying))
        #expect(NetworkConditionState.applying.canTransition(to: .applied))
        #expect(NetworkConditionState.applying.canTransition(to: .error("failed")))
        #expect(NetworkConditionState.error("failed").canTransition(to: .applying))
        #expect(NetworkConditionState.applied.canTransition(to: .applying))
        #expect(NetworkConditionState.applying.isWorking)
        #expect(!NetworkConditionState.applied.isWorking)
    }
```
(Exact house form, verbatim from lines 14–19 + 21–24: assert each legal `canTransition` pair is true, each illegal pair false, and `isWorking` per case.)

**Key adaptation:** Cover: fps↔`CMTime` mapping (`120 → CMTime(value: 1, timescale: 120)`), `queueDepth` within 3…8, codec enum mapping, recording state machine transitions (`idle → recording → finishing → exported`, CertificateOperation-style), GIF delay quantization (`10 fps → 10 cs`, `5 fps → 20 cs`), loop count 0, output-width downsample mapping. All pure — no recording session.

---

### `BoosterSimAppTests/CaptureSettingsTests.swift` (test, settings round-trip)

**Analog:** `BoosterSimAppTests/NetworkConditionServiceTests.swift:26–51` — isolated defaults suite + re-init round-trip

**Isolated-suite round-trip pattern** — NetworkConditionServiceTests.swift lines 5–11 and 28–44:
```swift
    private func makeDefaults() throws -> (defaults: UserDefaults, suiteName: String) {
        let suiteName = "NetworkConditionServiceTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        return (defaults, suiteName)
    }
```
```swift
    @MainActor
    @Test func airplanePersistsAcrossServiceReInit() throws {
        let (defaults, suiteName) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let first = NetworkConditionService(defaults: defaults, commandServer: NoopCommandBroadcast())
        first.setAirplane(true)
        #expect(first.airplane == true)

        // Re-initialize from the same suite: persisted state must re-apply.
        let second = NetworkConditionService(defaults: defaults, commandServer: NoopCommandBroadcast())
        #expect(second.airplane == true)
    }
```

**Key adaptation:** Same `makeDefaults()` helper + `defer removePersistentDomain` + write-then-reinit round-trip for AppSettings capture keys and filename builder (device + preset + timestamp, sanitization cases). Touch-pref restore machine tested as a pure state machine (set/unset/restore transitions) — assert restore semantics without touching real `com.apple.iphonesimulator` prefs.

---

## Shared Patterns

### Async internals behind sync Combine facade
**Source:** `BoosterSimApp/Services/DeepLinkService.swift:50–52` (bridge), `BoosterSimApp/Services/NetworkConditionService.swift:51–62` (modern shell)
**Apply to:** `CaptureService` facade — every public method sync (`Task { await … }` inside), state via `@Published private(set)` on `@MainActor`. Views never see async.

### Non-isolated delegate wrappers + main hop
**Source:** `BoosterSimApp/Services/CaptureService.swift:276–312` (private `NSObject` wrappers, `Task { @MainActor [weak self] }` hop)
**Apply to:** `RecordingService` — `SCStreamOutput`, `SCStreamDelegate`, `SCRecordingOutputDelegate` callbacks arrive on the sample-handler queue (dedicated serial `DispatchQueue`, never `.main` at 120 fps).

### State machine quartet (`begin`/`finish`/`transition` + `assertionFailure`)
**Source:** `BoosterSimApp/Services/NetworkConditionService.swift:140–170`; enum with `isWorking`/`canTransition` at `:8–49`; original precedent `CertificateService.swift:144–170`
**Apply to:** `RecordingService` (idle/recording/finishing/exported) and `TouchIndicatorController` (set/recording/restore).

### CPU-bound work on background queue
**Source:** `BoosterSimApp/Services/SimCtlService.swift:37` — `DispatchQueue.global(qos: .userInitiated).async`
**Apply to:** `CaptureExporter` (AVAssetReader loop, GIF encode). No async/await in the exporter (CONVENTIONS exception covers capture services only).

### Logging + redaction
**Source:** `BoosterSimApp/Utilities/AppLogger.swift` (categories), `CertificateService.swift:156–158` (redact-before-log via `fail`)
**Apply to:** All capture units — never log file paths, UDIDs, or screen contents.

### Design tokens
**Source:** `BoosterSimApp/Utilities/DesignTokens.swift` — `Spacing.*` (4pt grid), `CornerRadius.*`, `SideWindowMetrics.*`
**Apply to:** `CaptureTabView`, `CaptureThumbnailPanel`, any new section views. `CaptureTabView.swift:96,109,114` raw values are the flagged debt to not reproduce.

### AppDelegate ownership + environment injection
**Source:** `BoosterSimApp/App/AppDelegate.swift:20–48` (lazy vars → `SideWindowController` init), conventions (`.environmentObject` in `embedSwiftUIContent`)
**Apply to:** All new services and the thumbnail panel.

### Persistence
**Source:** `BoosterSimApp/Models/AppSettings.swift:33–37` (`@AppStorage` for simple `RawRepresentable` keys); `NetworkConditionService.swift:56–99` (`private enum StorageKey` + injected `UserDefaults` for complex types and testability)
**Apply to:** Capture settings keys; custom-path storage; test doubles via isolated suites.

### Permission degradation
**Source:** `BoosterSimApp/Services/PermissionManager.swift:51–57` (`CGPreflightScreenCaptureAccess()` / `CGRequestScreenCaptureAccess()`), `:64–76` (1s grant polling)
**Apply to:** All capture UI — preflight before enabling controls; degraded state + setup flow when denied; "Quit & Reopen" prompt after grant (Pitfall 2).

### Swift Testing pure-logic style
**Source:** `BoosterSimAppTests/ConditionVerdictTests.swift`, `BoosterSimAppTests/NetworkConditionServiceTests.swift`
**Apply to:** All three Wave 0 test files — `struct` + `@Test` + `#expect`, private builders, MARK grouping, isolated suites over `.standard`.

## No Analog Found

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| `BoosterSimApp/Services/TouchIndicatorController.swift` (CFPreferences mechanism) | service | request-response | Zero `CFPreferences` usage in the repo (grep verified this session) — use RESEARCH.md Pattern 6 verbatim; the controller *shell* (state machine, published state) still copies NetworkConditionService |
| `BoosterSimApp/Services/ScreenshotService.swift` (SCScreenshotManager call) | service | request-response | No screenshot path exists anywhere in the repo (RESEARCH scaffold audit); acquisition shape copies the in-file SCK stream setup (`CaptureService.swift:82–116`), API usage from RESEARCH.md Pattern 2 |
| `BoosterSimApp/Services/RecordingService.swift` (SCRecordingOutput) | service | event-driven | `SCRecordingOutput` (macOS 15+) has no in-repo usage — scaffold uses the AVAssetWriter anti-pattern; delegate wrappers (`CaptureService.swift:276–312`) + RESEARCH.md Pattern 3 are the sources |

## Metadata

**Analog search scope:** `BoosterSimApp/Services/`, `BoosterSimApp/Windows/`, `BoosterSimApp/Views/SideWindow/` (incl. `network/`), `BoosterSimApp/Models/`, `BoosterSimApp/Utilities/`, `BoosterSimApp/App/`, `BoosterSimAppTests/`
**Files scanned:** 19 (CaptureService, DeepLinkService, NetworkConditionService, SimCtlService, PermissionManager, CertificateService†, CertificateModels†, AXHighlightPanel, PositionCalculator, AppSettings, AppLogger, DesignTokens, CaptureTabView, NetworkConditionsSectionView, AppDelegate, ConditionVerdictTests, NetworkConditionServiceTests, CertificateServiceTests†, CONVENTIONS/structure docs) — † line-verified via 05-PATTERNS.md excerpts (same repo, 2026-08-29)
**Pattern extraction date:** 2026-08-30
