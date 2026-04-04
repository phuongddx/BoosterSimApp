---
phase: 01
title: Xcode Target Setup
status: completed
effort: 1h
---

# Phase 01 — Xcode Target Setup

## Overview

Create the `BoosterHealth` iOS target inside the existing `BoosterSimApp.xcodeproj`. This phase is done manually in Xcode UI — no code written yet.

## Steps

### 1. Add iOS App Target

In Xcode → File → New → Target:
- Template: **iOS → App**
- Product Name: `BoosterHealth`
- Bundle ID: `com.nextlabs.boosterhealth`
- Language: Swift
- Interface: SwiftUI
- Minimum Deployment: **iOS 17.0**

### 2. Configure Build Settings

Select `BoosterHealth` target → Build Settings:
- `SUPPORTED_PLATFORMS` = `iphonesimulator` only (not `iphoneos`) — Simulator-only build
- `ARCHS[sdk=iphonesimulator*]` = `arm64 x86_64`
- `EXCLUDED_ARCHS[sdk=iphoneos*]` = `arm64` (prevents accidental device builds)

### 3. Add HealthKit Capability

Select `BoosterHealth` target → Signing & Capabilities → + Capability → **HealthKit**

This auto-creates `BoosterHealth.entitlements` with:
```xml
<key>com.apple.developer.healthkit</key>
<true/>
<key>com.apple.developer.healthkit.access</key>
<array/>
```

### 4. Register URL Scheme

In `BoosterHealth/Info.plist`, add:
```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>boosterhealth</string>
        </array>
        <key>CFBundleURLName</key>
        <string>com.nextlabs.boosterhealth</string>
    </dict>
</array>
```

### 5. Add Copy Files Build Phase to macOS Target

Select `BoosterSimApp` target → Build Phases → + → New Copy Files Phase:
- Destination: **Resources**
- Subpath: (empty)
- Add `BoosterHealth.app` (select from build products)

This embeds the companion `.app` into `BoosterSimApp.app/Contents/Resources/`.

### 6. Add Scheme Dependency

`BoosterSimApp` scheme → Build → + → add `BoosterHealth` target.
Ensure `BoosterHealth` appears **before** `BoosterSimApp` in build order.

## Success Criteria

- [ ] `BoosterHealth` target appears in project navigator
- [ ] Building `BoosterSimApp` scheme also builds `BoosterHealth`
- [ ] `BoosterSimApp.app/Contents/Resources/BoosterHealth.app` exists after build
- [ ] `BoosterHealth.entitlements` contains HealthKit key
- [ ] `Info.plist` contains `boosterhealth` URL scheme

## Notes

- Do NOT enable `ENABLE_BITCODE` (deprecated in Xcode 14+)
- Do NOT add `BoosterHealth` to App Store submission — it's a developer tool target only
- Code signing for `BoosterHealth`: use same team as `BoosterSimApp`, or set to "Sign to Run Locally" for dev builds
