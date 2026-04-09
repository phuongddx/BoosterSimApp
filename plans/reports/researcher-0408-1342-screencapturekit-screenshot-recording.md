# Research: ScreenCaptureKit Screenshot & Recording for BoosterSimApp

**Date:** 2026-04-08
**Scope:** Screenshot capture, video recording, bezel compositing, GIF export, floating thumbnail, save destinations for iOS Simulator window capture.

---

## 1. Screenshot Capture (SCScreenshotManager — macOS 15+)

### API

macOS 15 introduced `SCScreenshotManager` with two key methods:

- `captureImage(contentFilter:configuration:)` — returns `CGImage` directly (legacy, still available)
- `captureScreenshot(contentFilter:configuration:)` — returns `SCScreenshotOutput` with `sdrImage` (CGImage) and optional `fileURL` for auto-save

### How to Capture a Specific Simulator Window

We already have `CGWindowID` and `pid` from `WindowEnumerator`. The flow:

```swift
@preconcurrency import ScreenCaptureKit

// 1. Get shareable content
let content = try await SCShareableContent.current

// 2. Find the SCWindow matching our SimulatorWindow's CGWindowID
guard let scWindow = content.windows.first(where: { $0.windowID == simulatorWindow.id }) else { return }

// 3. Create content filter for that specific window
let filter = SCContentFilter(desktopIndependentWindow: scWindow)

// 4. Configure screenshot
let config = SCScreenshotConfiguration()
config.showsCursor = false
config.ignoreShadows = true  // no window shadow

// 5. Capture (macOS 15+ API)
let output = try await SCScreenshotManager.captureScreenshot(contentFilter: filter, configuration: config)
let cgImage = output.sdrImage  // CGImage of the window content only
```

**Key `SCContentFilter` initializer:** `SCContentFilter(desktopIndependentWindow:)` — captures a single window regardless of which display it's on. Perfect for our use case.

**Alternative (if targeting macOS 12.3+):** Use `SCScreenshotManager.captureImage(contentFilter:configuration:)` with `SCStreamConfiguration` instead of `SCScreenshotConfiguration`.

### Configuration Options (SCScreenshotConfiguration — macOS 15+)

| Property | Use |
|----------|-----|
| `showsCursor` | Hide mouse cursor in screenshot |
| `ignoreShadows` | Remove window shadow |
| `ignoreClipping` | Ignore clipping |
| `includeChildWindows` | Include child windows |
| `width` / `height` | Override output size in pixels |
| `sourceRect` | Crop to subset of window (points) |
| `contentType` | Output format: PNG, JPEG, HEIC (via UTTypeReference) |
| `fileURL` | **Folder** URL to auto-save (named like macOS native screenshots) |
| `dynamicRange` | SDR only, HDR only, or both |

### Legacy API (macOS 12.3+, pre-15)

```swift
let config = SCStreamConfiguration()
config.showsCursor = false
config.ignoreShadows = true
let cgImage = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
```

### Permissions Required

- **Screen Recording** permission (System Settings > Privacy & Security > Screen Recording). Already checked by `PermissionManager` in the app.
- First launch triggers system prompt. Must have proper code signing (Development cert, not "Sign to Run Locally") to avoid repeated prompts.

### Swift 6 Concurrency Notes

- Mark `import ScreenCaptureKit` with `@preconcurrency` to pass `SCContentFilter` / `SCWindow` across isolation boundaries.
- `SCScreenshotConfiguration` does NOT conform to `Observable` — cannot use as `@State` or `@Published` directly.

---

## 2. Video Recording (SCStream + SCRecordingOutput)

### Two Approaches

| Approach | API | File Output | Complexity |
|----------|-----|-------------|------------|
| **Native Recording (preferred)** | `SCRecordingOutput` + `SCRecordingOutputConfiguration` | Direct to MP4/MOV | Low |
| Manual AVAssetWriter | `SCStreamOutput` + `AVAssetWriter` | Manual frame writing | High |

### Native Recording API (macOS 14.4+, SCRecordingOutput)

```swift
@preconcurrency import ScreenCaptureKit

// -- Setup stream --
let content = try await SCShareableContent.current
guard let scWindow = content.windows.first(where: { $0.windowID == simulatorWindow.id }) else { return }
let filter = SCContentFilter(desktopIndependentWindow: scWindow)

let streamConfig = SCStreamConfiguration()
streamConfig.minimumFrameInterval = CMTime(value: 1, timescale: 60)  // 60fps
streamConfig.queueDepth = 5
streamConfig.showsCursor = false
streamConfig.ignoreShadows = true

let stream = SCStream(filter: filter, configuration: streamConfig, delegate: nil)

// -- Setup recording --
let recordingConfig = SCRecordingOutputConfiguration()
recordingConfig.outputURL = outputFileURL  // FILE URL, not folder
// outputFileType defaults to .mpeg4Movie (MP4)

let recordingOutput = SCRecordingOutput(configuration: recordingConfig, delegate: recordingDelegate)

// -- Start --
try stream.addRecordingOutput(recordingOutput)  // can add BEFORE startCapture
try await stream.startCapture()

// -- Stop --
try await stream.stopCapture()  // recording auto-finishes, no need to removeRecordingOutput first
```

### Recording Delegate

```swift
class RecordingDelegate: NSObject, SCRecordingOutputDelegate {
    func recordingOutputDidStartRecording(_ recordingOutput: SCRecordingOutput) { }
    func recordingOutputDidFinishRecording(_ recordingOutput: SCRecordingOutput) { }
    func recordingOutput(_ recordingOutput: SCRecordingOutput, didFailWithError error: Error) { }
}
```

### Key Constraints

1. **ONE** `SCRecordingOutput` per `SCStream` max.
2. `outputURL` is a **file** URL (not folder like screenshot's `fileURL`). Confusing naming.
3. Add recording output **before** `startCapture()` to guarantee first frame is captured.
4. `stopCapture()` auto-finishes recording — no need to call `removeRecordingOutput()` first.
5. Changing `SCStreamConfiguration` on a running stream **stops recording** and triggers `recordingOutputDidFinishRecording`. Changing only `SCContentFilter` does NOT.

### Frame Rate Control

```swift
// 60 fps (default recommended)
streamConfig.minimumFrameInterval = CMTime(value: 1, timescale: 60)

// 120 fps (high frame rate, increases memory)
streamConfig.minimumFrameInterval = CMTime(value: 1, timescale: 120)

// 30 fps
streamConfig.minimumFrameInterval = CMTime(value: 1, timescale: 30)

// Increase queue depth for high fps
streamConfig.queueDepth = 5  // default, increase to 8 for 120fps
```

### Output Format

```swift
recordingConfig.outputFileType  // defaults to MPEG-4 (.mp4)
// Can also be set to .mov or .m4v via UTType
```

### Known Bugs (as of macOS 15 / Xcode 26 beta)

- Recording sometimes doesn't start (`recordingOutputDidStartRecording` never called, no error). Fix: clean build folder.
- `recordingOutputDidFinishRecording` not fired on `stopCapture()` — only on config change. This is documented behavior, not a bug.
- `SCShareableContent.current` can hang forever if permission state is corrupted. Fix: reboot.

### Alternative: Manual AVAssetWriter (if SCRecordingOutput unavailable)

Uses `SCStreamOutput` protocol to receive `CMSampleBuffer` frames and writes them via `AVAssetWriter`. This is what nonstrict-hq's example uses. **Not recommended for our case** — native `SCRecordingOutput` is simpler and Apple-supported.

---

## 3. Screenshot with Device Bezels

### Approach: Post-Processing with CoreGraphics Compositing

All tools (RocketSim, frameit, mockuphone, Bezel.app) use the same approach:
1. Capture clean screenshot (window content only, no shadow)
2. Load a pre-made device frame PNG (transparent interior)
3. Composite screenshot into the device frame using `CGContext`

### CoreGraphics Compositing

```swift
func compositeWithBezel(screenshot: CGImage, bezelImage: CGImage, deviceType: SimulatorDeviceType) -> CGImage? {
    // Device frame PNG has known inset for the screen area
    let screenInset: CGFloat = bezelScreenInset(for: deviceType)
    let bezelWidth = bezelImage.width
    let bezelHeight = bezelImage.height
    let screenWidth = bezelWidth - screenInset * 2
    let screenHeight = bezelHeight - screenInset * 2

    // Create output context at bezel size
    let size = CGSize(width: bezelWidth, height: bezelHeight)
    guard let context = CGContext(
        nil, width: Int(size.width), height: Int(size.height),
        32, // bits per component
        4 * Int(size.width), // bytes per row
        CGColorSpaceCreateDeviceRGB(),
        CGImageAlphaInfo.premultipliedFirst.rawValue
    ) else { return nil }

    // 1. Draw screenshot scaled to screen area (centered in bezel)
    context.interpolationQuality = .high
    context.draw(screenshot, in: CGRect(x: screenInset, y: screenInset, width: screenWidth, height: screenHeight))

    // 2. Overlay bezel on top
    context.draw(bezelImage, in: CGRect(origin: .zero, size: size))

    return context.makeImage()
}
```

### Device Frame Assets

| Source | Format | License | Notes |
|--------|--------|---------|-------|
| **Apple Design Resources** | PSD/Sketch | Free for App Store marketing | Official, high quality. Download from developer.apple.com/design/resources/ |
| **Figma community bezels** | Figma/SVG | Varies | Community-made, many device types |
| **frameit (fastlane)** | PNG templates bundled | MIT | Automated selection by screenshot resolution |
| **Custom bundled** | PNG with transparency | N/A | Best for this project — ship device frame PNGs in app bundle |

### Recommended Approach for BoosterSimApp

1. **Bundle device frame PNGs** in the app (iPhone, iPad, Apple Watch frames at minimum)
2. Extract device type from `SimulatorWindow.deviceType` (already classified by `SimulatorWindowTracker`)
3. Map device resolution to correct bezel frame
4. Use CoreGraphics compositing as shown above
5. Maintain a dictionary of `SimulatorDeviceType` -> bezel PNG name + screen inset values

### Key Insight: Inset Values Per Device

Each device bezel has different screen inset (the distance from frame edge to screen area). Store this as metadata alongside the PNG:

```swift
struct DeviceBezelSpec {
    let image: String        // asset name
    let screenInset: CGFloat // padding from frame edge to screen
    let screenScale: CGFloat // aspect ratio adjustment
}
```

---

## 4. GIF Export

### Recommended: AVAssetImageGenerator + CGImageDestination

**Zero external dependencies.** Two-step process:

1. Extract frames from recorded video using `AVAssetImageGenerator`
2. Combine frames into animated GIF using `CGImageDestination` with `kUTTypeGIF`

### Frame Extraction

```swift
import AVFoundation
import ImageIO
import UniformTypeIdentifiers

func extractFrames(from videoURL: URL, fps: Double = 15.0, maxWidth: Int = 600) async throws -> [CGImage] {
    let asset = AVAsset(url: videoURL)
    let duration = try await asset.load(.duration)
    let totalSeconds = CMTimeGetSeconds(duration)

    let generator = AVAssetImageGenerator(asset: asset)
    generator.maximumSize = CGSize(width: maxWidth, height: maxWidth * 2)  // limit for GIF size
    generator.appliesPreferredTrackTransform = true

    var frames: [CGImage] = []
    let frameInterval = 1.0 / fps
    var time: Double = 0

    while time < totalSeconds {
        let cmTime = CMTime(seconds: time, preferredTimescale: 600)
        let image = try generator.copyCGImage(at: cmTime, actualTime: nil)
        frames.append(image)
        time += frameInterval
    }
    return frames
}
```

### GIF Creation

```swift
func createGIF(from frames: [CGImage], frameDelay: Double = 0.066, outputURL: URL) -> Bool {
    guard let destination = CGImageDestinationCreateWithURL(
        outputURL as CFURL,
        UTType.gif.identifier as CFString,
        frames.count,
        nil
    ) else { return false }

    // GIF properties: loop forever
    let gifProperties = [kCGImagePropertyGIFDictionary as String: [
        kCGImagePropertyGIFLoopCount as String: 0
    ]] as CFDictionary

    // Per-frame properties: delay time
    let frameProperties = [kCGImagePropertyGIFDictionary as String: [
        kCGImagePropertyGIFDelayTime as String: frameDelay
    ]] as CFDictionary

    CGImageDestinationSetProperties(destination, gifProperties)
    for frame in frames {
        CGImageDestinationAddImage(destination, frame, frameProperties)
    }

    return CGImageDestinationFinalize(destination)
}
```

### Trade-offs

| Parameter | Recommended | Impact |
|-----------|-------------|--------|
| GIF FPS | 10-15 | Higher = larger file, smoother |
| Max width | 400-600px | Larger = better quality, bigger file |
| Frame delay | 0.066s (15fps) | Controls playback speed |
| Color palette | GIF default (256 colors) | Consider quantization for UI screenshots |

### Optimization Tips

- Reduce FPS to 10 for UI screenshots (not much motion)
- Resize frames to ~400px width for sharing
- UI screenshots compress well in GIF (flat colors, limited palette)
- For longer recordings (>30s), consider MP4 instead of GIF

---

## 5. Floating Thumbnail Preview

### Implementation: NSPanel with Auto-Dismiss

Exactly the right approach for our existing architecture (already uses NSPanel for `SideWindowPanel`).

```swift
final class ScreenshotThumbnailPanel: NSPanel {
    private var dismissTimer: Timer?

    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 240, height: 160),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        level = .floating
        isFloatingPanel = true
        hidesOnDeactivate = false
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        isMovableByWindowBackground = true
    }

    func show(thumbnail: CGImage, at screenPoint: NSPoint) {
        // Create SwiftUI hosting view
        let hosting = NSHostingView(rootView: ThumbnailView(image: thumbnail))
        contentView = hosting
        frame.size = hosting.fittingSize

        // Position near bottom-right of screen (like macOS native)
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let origin = NSPoint(
                x: screenFrame.maxX - frame.width - 20,
                y: screenFrame.minY + 20
            )
            setFrameOrigin(origin)
        }

        orderFrontRegardless()
        startDismissTimer()
    }

    private func startDismissTimer() {
        dismissTimer?.invalidate()
        dismissTimer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: false) { [weak self] _ in
            self?.animateOut()
        }
    }

    private func animateOut() {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            self.animator().alphaValue = 0
        } completionHandler: { [weak self] in
            self?.orderOut(nil)
            self?.alphaValue = 1.0
        }
    }
}
```

### Interaction

- Click: open in Preview / copy to clipboard / drag to save
- Right-click: context menu (Copy, Save to Desktop, Share)
- Drag: user can drag the thumbnail to Finder to save
- Auto-dismiss after ~4 seconds with fade-out animation

### Positioning

Like macOS native screenshot thumbnail: bottom-right corner of screen, offset from dock.

---

## 6. Save Destinations

### Desktop

```swift
func saveToDesktop(image: CGImage, filename: String) -> URL? {
    let desktop = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!
    let fileURL = desktop.appendingPathComponent(filename)
    let dest = CGImageDestinationCreateWithURL(fileURL as CFURL, UTType.png.identifier as CFString, 1, nil)
    CGImageDestinationAddImage(dest!, image, nil)
    CGImageDestinationFinalize(dest!)
    return fileURL
}
```

### Clipboard (NSPasteboard)

```swift
func copyToClipboard(image: CGImage) {
    let pb = NSPasteboard.general
    pb.clearContents()
    let nsImage = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
    pb.writeObjects([nsImage])
}
```

### Custom Path (NSSavePanel)

```swift
func saveAs(image: CGImage) {
    let panel = NSSavePanel()
    panel.allowedContentTypes = [.png, .jpeg, .heic]
    panel.nameFieldStringValue = "Screenshot \(dateString()).png"
    panel.directoryURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first

    panel.begin { response in
        guard response == .OK, let url = panel.url else { return }
        let utType = UTType(filenameExtension: url.pathExtension) ?? .png
        guard let dest = CGImageDestinationCreateWithURL(url as CFURL, utType.identifier as CFString, 1, nil) else { return }
        CGImageDestinationAddImage(dest, image, nil)
        CGImageDestinationFinalize(dest)
    }
}
```

### ScreenCaptureKit Native Auto-Save (macOS 15+)

```swift
// Set folder URL on SCScreenshotConfiguration — auto-saves with macOS naming convention
let config = SCScreenshotConfiguration()
config.fileURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first
// File saved as: "Screenshot 2026-04-08 at 13.42.00.png"
```

---

## Architecture Recommendation for BoosterSimApp

### Service Layer

```
CaptureService (@MainActor)
├── screenshot() -> CGImage           // uses SCScreenshotManager
├── screenshotWithBezel() -> CGImage  // CGImage + bezel compositing
├── startRecording()                  // SCStream + SCRecordingOutput
├── stopRecording() -> URL            // returns recording file URL
├── exportGIF(from: URL) -> URL       // AVAssetImageGenerator + CGImageDestination
├── saveToDesktop(image:)
├── copyToClipboard(image:)
├── saveAs(image:)                    // NSSavePanel
└── showThumbnail(image:)             // ScreenshotThumbnailPanel
```

### Integration Points

- `CaptureService` reads `activeSimulator` from `SimulatorWindowTracker` (already has CGWindowID)
- Uses `SCShareableContent.current` to find matching `SCWindow` by `windowID`
- `SCContentFilter(desktopIndependentWindow: scWindow)` — no display dependency
- Reuses existing Screen Recording permission (already checked by `PermissionManager`)

### Dependencies

- `ScreenCaptureKit` framework (system, macOS 12.3+)
- `AVFoundation` (for frame extraction in GIF export)
- `ImageIO` (for CGImageDestination GIF creation)
- `CoreGraphics` (for bezel compositing)
- **Zero external dependencies** — all Apple frameworks

---

## Trade-off Matrix

| Feature | Recommended API | macOS Min | Complexity | Risk |
|---------|----------------|-----------|------------|------|
| Screenshot | `SCScreenshotManager.captureScreenshot` (macOS 15+) | 15.0 | Low | Low — well-documented, Apple sample code |
| Screenshot (fallback) | `SCScreenshotManager.captureImage` | 12.3 | Low | Low |
| Recording | `SCRecordingOutput` native | 14.4 | Low | Medium — known bugs with start sometimes failing |
| Recording (fallback) | `SCStreamOutput` + `AVAssetWriter` | 12.3 | High | Medium — manual frame management |
| Bezel compositing | CoreGraphics `CGContext.draw` | 10.0 | Low | Low — standard compositing |
| GIF export | `AVAssetImageGenerator` + `CGImageDestination` | 10.0 | Medium | Low — well-tested APIs |
| Floating thumbnail | NSPanel subclass | 10.0 | Low | Low — same pattern as existing SideWindowPanel |
| Save destinations | NSPasteboard + NSSavePanel + CGImageDestination | 10.0 | Low | Low |

---

## Source Credibility

| Source | Type | Credibility |
|--------|------|-------------|
| Apple Developer Documentation (SCScreenshotManager, SCRecordingOutput, SCStream) | Official docs | **Highest** |
| Apple Sample Code "Capturing screen content in macOS" | Official sample | **Highest** |
| Itsuki (Level Up Coding) — Screenshot + Streaming articles | Community, tested on macOS 15/Xcode 26 | **High** — detailed, code-verified, covers Swift 6 pitfalls |
| nonstrict-hq/ScreenCaptureKit-Recording-example | GitHub, MIT | **Medium** — AVAssetWriter approach, older API |
| Apple Design Resources | Official | **Highest** — for bezel templates |
| frameit (fastlane) | Open source | **Medium** — reference for bezel selection logic |

---

## Unresolved Questions

1. **Device bezel asset sourcing** — Apple Design Resources provides PSDs; need to decide whether to extract PNGs from those or create simplified vector bezels. Apple's license permits use for "screenshots of your own apps" but may have restrictions for embedding in a tool.
2. **SCRecordingOutput reliability** — Multiple reports of recording silently failing to start (no error thrown, no delegate callback). May need retry logic or fallback to AVAssetWriter approach.
3. **HDR capture** — `SCScreenshotConfiguration.dynamicRange` exists but `hdrImage` always returns nil in testing (possible macOS 15 bug). Not blocking since Simulator content is SDR.
4. **Memory pressure for GIF export** — Long recordings (>60s) at high frame rates could use significant memory during frame extraction. May need streaming frame extraction (process and discard each frame immediately).
5. **Recording file size** — No control over bitrate in `SCRecordingOutputConfiguration`. For GIF conversion, MP4 size doesn't matter much, but for direct sharing, users may want smaller files.
6. **Multi-window recording** — If user has multiple Simulator windows, should we allow recording a specific one? Current API supports this via `SCContentFilter(desktopIndependentWindow:)`.

---

**Status:** DONE
**Summary:** ScreenCaptureKit provides native screenshot (macOS 15+) and recording (macOS 14.4+) APIs that work with our existing CGWindowID-based window detection. SCScreenshotManager for screenshots, SCRecordingOutput for recording, CoreGraphics for bezel compositing, AVAssetImageGenerator + CGImageDestination for GIF export, NSPanel for floating thumbnail. All zero external dependency, all Apple frameworks.
