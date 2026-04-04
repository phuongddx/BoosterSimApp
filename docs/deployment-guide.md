# Deployment Guide

## Development Build

### Requirements

- macOS 15 Sequoia or later
- Xcode 16.3+
- iOS Simulator (installed via Xcode) for live testing

### Build & Run

```bash
# From project root
cd BoosterSimApp

# Build BoosterSimApp (Debug) — also builds BoosterHealth iOS companion
xcodebuild -project BoosterSimApp.xcodeproj \
           -scheme BoosterSimApp \
           -configuration Debug \
           build

# Or open in Xcode and press Cmd+R
open BoosterSimApp.xcodeproj
```

> **BoosterHealth companion:** The `BoosterHealth` target (iOS) is built automatically as a dependency of `BoosterSimApp`. The compiled `.app` is embedded in the macOS bundle and installed into the Simulator at runtime via `simctl install`.

### First Run Setup

1. Launch app — bolt icon appears in menu bar
2. Onboarding window opens automatically
3. Grant **Accessibility** permission (System Settings → Privacy & Security → Accessibility)
4. Grant **Screen Recording** permission (System Settings → Privacy & Security → Screen Recording)
5. Open an iOS Simulator — side panel attaches automatically

### Permissions Required at Runtime

| Permission | How to Grant |
|---|---|
| Accessibility | System Settings → Privacy & Security → Accessibility → add BoosterSim |
| Screen Recording | System Settings → Privacy & Security → Screen Recording → add BoosterSim |
| DerivedData (optional) | Preferences → General → select DerivedData folder |

> **Note:** Without Accessibility, the app falls back to 0.5s polling (still functional, less responsive).
> Without Screen Recording, device names show as "Simulator (ID: XXXX)" instead of device name.

---

## Distribution (Future)

> Distribution is not configured for MVP. Steps below are planned for Phase 7.

### Code Signing

```bash
# Set team ID in Xcode project settings
# Signing & Capabilities → Team → select Apple Developer team
```

### Notarization

```bash
# Archive
xcodebuild archive \
  -project BoosterSimApp.xcodeproj \
  -scheme BoosterSimApp \
  -archivePath build/BoosterSimApp.xcarchive

# Export signed app
xcodebuild -exportArchive \
  -archivePath build/BoosterSimApp.xcarchive \
  -exportPath build/export \
  -exportOptionsPlist ExportOptions.plist

# Notarize
xcrun notarytool submit build/export/BoosterSimApp.zip \
  --keychain-profile "AC_PASSWORD" \
  --wait

# Staple
xcrun stapler staple build/export/BoosterSimApp.app
```

### Sandboxing Considerations

BoosterSimApp is **non-sandboxed** (ENABLE_APP_SANDBOX = NO). Required for:
- `AXIsProcessTrusted()` — Accessibility API
- `CGWindowListCopyWindowInfo` — window enumeration
- `AXObserverCreate` — per-process AX observation
- `xcrun simctl spawn` — environment override commands
- `xcrun simctl install` / `simctl openurl` — BoosterHealth companion delivery

For Mac App Store distribution, a redesigned sandboxed version would require entitlements review or alternative APIs (ScreenCaptureKit, accessibility frameworks with reduced capabilities).

### Direct Distribution (DMG)

```bash
# Create DMG with create-dmg or hdiutil
hdiutil create -volname "BoosterSim" \
  -srcfolder build/export/BoosterSimApp.app \
  -ov -format UDZO \
  BoosterSim.dmg
```

---

## Version Scheme

`MAJOR.MINOR.PATCH` following semantic versioning.

- MAJOR: breaking architecture change
- MINOR: new feature phase complete
- PATCH: bug fix or polish release

Current: **0.1.0** (MVP)
