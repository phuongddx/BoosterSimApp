# Deployment Guide

## Development Build

### Requirements

- macOS 26.2 or later (`MACOSX_DEPLOYMENT_TARGET = 26.2`)
- Xcode 26.3+ (macOS 26.2 SDK)
- iOS Simulator (installed via Xcode) for live testing

### Build & Run

```bash
# From project root (repo root — the .xcodeproj lives here)

# Build BoosterSimApp (Debug)
xcodebuild -project BoosterSimApp.xcodeproj \
           -scheme BoosterSimApp \
           -configuration Debug \
           build

# Or open in Xcode and press Cmd+R
open BoosterSimApp.xcodeproj
```

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

## Distribution

Shipped as of Phase 7. The release pipeline is **`scripts/build-release.sh`** — one command from the repo root covering archive → Developer-ID export → zip → notarize → staple → DMG.

### One-command release path

```bash
# Credential-free dry run (skips notarization/stapling — CI dry runs, local sanity):
scripts/build-release.sh --skip-notarization

# Full release (notarize + staple; requires the stored keychain profile, see below):
scripts/build-release.sh
```

Configuration is env-overridable with defaults: `PROJECT=BoosterSimApp.xcodeproj`, `SCHEME=BoosterSimApp`, `CONFIGURATION=Release`, `BUILD_DIR=build`, `NOTARY_PROFILE=booster-notary`.

Stages, in order:

| # | Stage | What runs | Produces |
|---|---|---|---|
| 0 | Pre-build Connect | `xcodebuild -scheme BoosterSimConnect -sdk iphonesimulator build` | `BoosterSimConnect.framework` in the shared products dir, so the app target's "Build iOS Framework & Copy" phase takes its copy branch (a nested build inside the archive fails with a Clang module-map collision) |
| 1 | Archive | `xcodebuild archive` | `build/BoosterSimApp.xcarchive` |
| 2 | Export | `xcodebuild -exportArchive -exportOptionsPlist ExportOptions.plist` | `build/export/BoosterSimApp.app`, re-signed **Developer ID Application** (team `K2TYLYAWMK`) |
| 3 | Zip | `ditto -c -k --keepParent` | `build/BoosterSimApp.zip` — notarytool's submission format |
| 4 | Notarize + staple | `xcrun notarytool submit --keychain-profile booster-notary --wait`, then `xcrun stapler staple` + `xcrun stapler validate` | Apple's accepted ticket stapled to the .app (skipped entirely by `--skip-notarization`) |
| 5 | DMG | `hdiutil create` | `build/BoosterSim.dmg` |

The script ends by printing every artifact path. If the keychain profile is missing on a full run, the script exits non-zero **before submitting** and prints the exact `xcrun notarytool store-credentials` command to run — it never prompts for credentials and contains none.

`ExportOptions.plist` (repo root) encodes the export contract: `method = developer-id`, `teamID = K2TYLYAWMK`, `signingStyle = automatic` (direct distribution — no provisioning-profile keys). Project signing is otherwise unchanged: `CODE_SIGN_STYLE = Automatic`, hardened runtime on (`ENABLE_HARDENED_RUNTIME = YES`), no entitlements file.

The exported app embeds `BoosterSimConnect.framework` in `Contents/Resources` (stage 0's product); it is loaded at runtime only in DEBUG builds via `Bundle.load`.

### Manual equivalents (per stage)

```bash
# Stage 1 — Archive
xcodebuild archive \
  -project BoosterSimApp.xcodeproj \
  -scheme BoosterSimApp \
  -configuration Release \
  -archivePath build/BoosterSimApp.xcarchive

# Stage 2 — Export (re-signs Developer ID)
xcodebuild -exportArchive \
  -archivePath build/BoosterSimApp.xcarchive \
  -exportPath build/export \
  -exportOptionsPlist ExportOptions.plist

# Stage 3 — Zip for notarization
ditto -c -k --keepParent build/export/BoosterSimApp.app build/BoosterSimApp.zip

# Stage 4 — Notarize + staple
xcrun notarytool submit build/BoosterSimApp.zip \
  --keychain-profile booster-notary \
  --wait
xcrun stapler staple build/export/BoosterSimApp.app
xcrun stapler validate build/export/BoosterSimApp.app

# Stage 5 — DMG
hdiutil create -volname "BoosterSim" \
  -srcfolder build/export/BoosterSimApp.app \
  -ov -format UDZO \
  build/BoosterSim.dmg
```

### One-time credential setup (interactive — human-only)

Notarization authenticates to Apple's notary service with an Apple ID that is a member of team `K2TYLYAWMK`. The credentials live **only** in a keychain profile referenced by name — never in the script, the repo, or this doc.

1. Create an app-specific password at [appleid.apple.com](https://appleid.apple.com) → Sign-In and Security → App-Specific Passwords.
2. Store it once, interactively (this step is deliberately never scripted):

```bash
xcrun notarytool store-credentials booster-notary \
  --apple-id <Apple ID> \
  --team-id K2TYLYAWMK \
  --password <app-specific password>
```

After this one-time step, `scripts/build-release.sh` submits, waits, staples, and validates unattended. Past submissions can be read back with:

```bash
xcrun notarytool history --keychain-profile booster-notary
```

### CI release secrets (GitHub Actions)

Pushing a tag matching `v*` triggers `.github/workflows/release.yml`: resolve SPM → import the Developer ID certificate into a temporary keychain → store notarytool credentials (App Store Connect API-key form) → `scripts/build-release.sh` (archive → Developer-ID export → notarize → staple → DMG) → Sparkle `generate_appcast` → GitHub Release carrying `BoosterSim.dmg` + `appcast.xml`. The appcast is reachable at the stable URL `https://github.com/phuongddx/BoosterSimApp/releases/latest/download/appcast.xml` — the app's `SUFeedURL`.

Every credential is a named repository secret (**Settings → Secrets and variables → Actions**); no value lives in the workflow file, the script, or this doc:

| Secret | Where the value comes from |
|---|---|
| `APPLE_CERTIFICATE_P12` | Keychain Access → My Certificates → **Developer ID Application: Doan Duy Phuong (K2TYLYAWMK)** → *Export…* as `.p12` (choose an export passphrase), then `base64 -i DeveloperID.p12 \| pbcopy` |
| `APPLE_CERTIFICATE_P12_PASSPHRASE` | the `.p12` export passphrase chosen above |
| `ASC_KEY_ID` | App Store Connect → Users and Access → Integrations → create an API key (Developer role is sufficient for notarytool); copy the **Key ID** |
| `ASC_ISSUER_ID` | same page — the **Issuer ID** shown above the key list |
| `ASC_KEY_P8` | the one-time `.p8` key download (`AuthKey_<KeyID>.p8`) — `base64 -i AuthKey_<KeyID>.p8 \| pbcopy` |
| `SPARKLE_PRIVATE_KEY` | Sparkle's EdDSA private key exported from the release machine's keychain: `<generate_keys path> -x /path/to/eddsa-private-key.pem`, then `base64 -i /path/to/eddsa-private-key.pem \| pbcopy` — must be the **same keypair** whose public key is pasted into `INFOPLIST_KEY_SUPublicEDKey`, or released appcasts will not validate against shipped apps |

> The Sparkle keypair is generated once on the release machine (the machine that owns the notary profile) via Sparkle's `generate_keys`: the private key is stored in the login keychain, and the printed **public key** is what `INFOPLIST_KEY_SUPublicEDKey` in `BoosterSimApp.xcodeproj/project.pbxproj` must carry. Without that key the app checks the feed but cannot verify updates.

### Sandboxing Considerations

BoosterSimApp is **non-sandboxed** (`ENABLE_APP_SANDBOX = NO`). Required for:
- `AXIsProcessTrusted()` — Accessibility API
- `CGWindowListCopyWindowInfo` — window enumeration
- `AXObserverCreate` — per-process AX observation
- `xcrun simctl spawn` — environment override and certificate trust commands

This is **fully compatible with direct distribution**: Developer ID signing + hardened runtime + notarization + stapling place no sandbox requirement on the app. The permissions the tools need (Accessibility, Screen Recording) are runtime TCC grants requested during onboarding — orthogonal to code signing.

Mac App Store distribution remains **Out of Scope** for this product; a sandboxed redesign would require entitlements review or alternative APIs (ScreenCaptureKit, accessibility frameworks with reduced capabilities).

### Direct Distribution (DMG)

The DMG is created by `hdiutil` (stage 5) — `create-dmg` was evaluated and rejected during Phase 7 research (an extra dependency for zero gain; `hdiutil` ships with macOS):

```bash
hdiutil create -volname "BoosterSim" \
  -srcfolder build/export/BoosterSimApp.app \
  -ov -format UDZO \
  build/BoosterSim.dmg
```

Distribute `build/BoosterSim.dmg`. Once the ticket is stapled, Gatekeeper verifies the app **offline** at first launch — no network check required.

---

## Version Scheme

`MAJOR.MINOR.PATCH` following semantic versioning.

- MAJOR: breaking architecture change
- MINOR: new feature phase complete
- PATCH: bug fix or polish release

Current: **1.0** (`MARKETING_VERSION = 1.0` in `BoosterSimApp.xcodeproj/project.pbxproj`)
