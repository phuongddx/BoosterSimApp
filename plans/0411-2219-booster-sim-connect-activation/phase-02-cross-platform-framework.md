---
title: "Phase 2: Cross-Platform Framework Build"
description: "Fix BoosterSimConnect to build for iOS Simulator SDK and embed in macOS app bundle"
status: pending
priority: P1
effort: 4h
depends_on: []
---

# Phase 2: Cross-Platform Framework Build

## Context Links

- BoosterSimConnect source: `BoosterSimConnect/BoosterSimConnect.swift`
- Xcode project: `BoosterSimApp.xcodeproj/project.pbxproj`
- RocketSim reference: `../RocketSimApp/dev-docs/` (framework embedding pattern)
- ConnectSetupView: `BoosterSimApp/Views/SideWindow/network/ConnectSetupView.swift`

## Overview

BoosterSimConnect framework currently builds for macOS (inherits `SDKROOT = macosx` from project). It must build for **iOS Simulator** so iOS apps can load it at runtime. The built framework must be embedded in `BoosterSimApp.app/Contents/Frameworks/` for the "Copy Code" snippet to work.

**Priority:** P1 — required for end-to-end testing
**Current status:** Not started

## Key Insights

### Current Problems
1. **Wrong SDK:** BoosterSimConnect target has no `SDKROOT` — inherits `macosx` from project level. Needs `iphoneos`.
2. **Wrong platform:** No `SUPPORTED_PLATFORMS` set. Needs `iphonesimulator`.
3. **Empty embed phase:** `PBXCopyFilesBuildPhase` "Embed Frameworks" exists (ID `883C4EF014A743C5B478B9AA`) but `files = ()` — framework never gets copied.
4. **Cross-compilation complexity:** A macOS app target and an iOS Simulator framework target in the same Xcode project requires careful build settings. Xcode can handle this but each target needs explicit SDK.

### RocketSim Pattern
1. macOS app embeds iOS Simulator framework in `Contents/Frameworks/`
2. User adds `Bundle(path: "...framework")?.load()` to their iOS app's `init()` or `AppDelegate`
3. Framework activates PulseProxy + RemoteLogger on `load()`
4. Framework name includes `.nocache` suffix to bypass dyld shared cache (RocketSim-specific optimization, not required for MVP)

### Cross-Compilation in Single Xcode Project
- Xcode supports mixed-platform targets in one project
- Each target's build settings override project-level defaults
- BoosterSimConnect needs: `SDKROOT = iphoneos`, `SUPPORTED_PLATFORMS = iphonesimulator`, `SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD = NO`
- BoosterSimApp stays: `SDKROOT = macosx` (already correct at project level)
- **Important:** iOS Simulator framework cannot be a dependency of macOS app target in the normal sense. Need a Run Script build phase to copy the built framework.

## Architecture

```
BoosterSimApp.xcodeproj
├── BoosterSimApp target (macOS app)
│   ├── SDKROOT = macosx (inherited)
│   ├── Embed Frameworks phase → runs Run Script
│   └── Run Script: "Build iOS Framework & Copy"
│       ├── xcodebuild -target BoosterSimConnect -sdk iphonesimulator
│       └── cp -R <built_framework> $BUILT_PRODUCTS_DIR/$FRAMEWORKS_FOLDER_PATH/
│
└── BoosterSimConnect target (iOS Simulator framework)
    ├── SDKROOT = iphoneos (target-level override)
    ├── SUPPORTED_PLATFORMS = iphonesimulator
    ├── ARCHS = x86_64 arm64
    ├── Links: Pulse, PulseProxy (SPM)
    └── Source: BoosterSimConnect.swift (#if DEBUG && targetEnvironment(simulator))
```

## Requirements

### Functional
- BoosterSimConnect builds for iOS Simulator (x86_64 + arm64)
- Built `.framework` is copied into `BoosterSimApp.app/Contents/Frameworks/`
- `BoosterSimConnect.swift` guard `#if DEBUG && targetEnvironment(simulator)` works correctly
- PulseProxy's `URLSessionProxyDelegate.enableAutomaticRegistration()` compiles for iOS
- RemoteLogger's `RemoteLogger.shared.start()` compiles for iOS

### Non-Functional
- No changes to BoosterSimApp target's macOS build
- Build works from both `xcodebuild` CLI and Xcode IDE
- Framework is stripped of unnecessary architectures for app store (future concern, skip for MVP)

## Related Code Files

### Modify
| File | Change |
|------|--------|
| `BoosterSimApp.xcodeproj/project.pbxproj` | Target build settings + embed phase fix + Run Script |
| `BoosterSimConnect/BoosterSimConnect.swift` | May need minor updates (verify Pulse API compatibility) |
| `BoosterSimApp/Views/SideWindow/network/ConnectSetupView.swift` | Dynamic bundle path in code snippet |

### Read-only (reference)
| File | Why |
|------|-----|
| `BoosterSimApp/App/AppDelegate.swift` | Verify no runtime loading of BoosterSimConnect |
| RocketSim `dev-docs/` | Reference implementation pattern |

## Implementation Steps

### Step 1: Fix BoosterSimConnect Target Build Settings

Edit `project.pbxproj` — add to BOTH Debug and Release configurations for BoosterSimConnect target (IDs `A0F0A14FAD9D44CD9431C21A` and `75B2BB653A6043DEB4F9DD70`):

```
SDKROOT = iphoneos;
SUPPORTED_PLATFORMS = iphonesimulator;
ARCHS = "$(ARCHS_STANDARD)";
VALID_ARCHS = x86_64 arm64;
SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD = NO;
```

Remove or keep `TARGETED_DEVICE_FAMILY = "1,2"` — this is fine (1=iPhone, 2=iPad).

**Why `iphoneos` SDKROOT + `iphonesimulator` SUPPORTED_PLATFORMS:** This is the standard Xcode pattern. `SDKROOT = iphoneos` provides iOS SDK headers/tools. `SUPPORTED_PLATFORMS = iphonesimulator` tells Xcode to build for the simulator variant.

### Step 2: Fix Embed Frameworks Build Phase

The `PBXCopyFilesBuildPhase` (ID `883C4EF014A743C5B478B9AA`) has `files = ()`. Two approaches:

**Option A: Run Script Phase (RECOMMENDED for cross-platform)**

Cross-target copying won't work with a normal Copy Files phase because Xcode won't resolve the iOS Simulator framework as a macOS target dependency. Use a Run Script phase instead:

1. Add a new `PBXShellScriptBuildPhase` to BoosterSimApp target's `buildPhases`
2. Script content:
   ```bash
   # Build BoosterSimConnect for iOS Simulator
   FRAMEWORK_NAME="BoosterSimConnect"
   IOS_BUILD_DIR="${DERIVED_SOURCES_DIR}/${FRAMEWORK_NAME}-ios"
   FRAMEWORKS_DIR="${BUILT_PRODUCTS_DIR}/${FRAMEWORKS_FOLDER_PATH}"

   # Build for iOS Simulator
   xcodebuild build \
     -project "${PROJECT_FILE_PATH}" \
     -target "${FRAMEWORK_NAME}" \
     -configuration "${CONFIGURATION}" \
     -sdk iphonesimulator \
     -derivedDataPath "${IOS_BUILD_DIR}" \
     ONLY_ACTIVE_ARCH=NO \
     QUIET=YES

   # Find and copy framework
   IOS_FRAMEWORK=$(find "${IOS_BUILD_DIR}" -name "${FRAMEWORK_NAME}.framework" -type d | head -1)
   if [ -n "${IOS_FRAMEWORK}" ]; then
     cp -R "${IOS_FRAMEWORK}" "${FRAMEWORKS_DIR}/"
     echo "Copied ${FRAMEWORK_NAME}.framework to ${FRAMEWORKS_DIR}"
   else
     echo "Warning: ${FRAMEWORK_NAME}.framework not found"
   fi
   ```
3. Place this phase AFTER "Embed Frameworks" phase in build order
4. Input files: `$(PROJECT_FILE_PATH)`
5. Output files: `$(BUILT_PRODUCTS_DIR)/$(FRAMEWORKS_FOLDER_PATH)/BoosterSimConnect.framework`

**Option B: Direct PBXCopyFilesBuildPhase fix (simpler but fragile)**

Add a PBXBuildFile entry linking BoosterSimConnect.framework to the Copy Files phase. This may fail because Xcode detects the cross-platform mismatch.

**Recommendation:** Use Option A. Cross-platform embedding via Run Script is the standard pattern (used by RocketSim and similar tools).

### Step 3: Update ConnectSetupView Dynamic Path

The current code snippet hardcodes `/Applications/BoosterSim.app/Contents/Frameworks/BoosterSimConnect.framework`. This won't work during development (app isn't in /Applications).

Update to compute path dynamically:

```swift
private var codeSnippet: String {
    #if DEBUG
    // In development, use the derived data path
    """
    #if DEBUG && targetEnvironment(simulator)
    Bundle(path: "\(Bundle.main.bundlePath)/../Frameworks/BoosterSimConnect.framework")?.load()
    #endif
    """
    #else
    """
    #if DEBUG && targetEnvironment(simulator)
    Bundle(path: "/Applications/BoosterSim.app/Contents/Frameworks/BoosterSimConnect.framework")?.load()
    #endif
    """
    #endif
}
```

**Better approach:** Use `Bundle.main.bundleURL` to compute path at runtime and display it in the setup view. The snippet shown to the user should always reference `/Applications/BoosterSim.app/...` since that's the installed location. During development, the user can manually adjust.

Actually, the simplest correct approach: the setup view should always show the installed path `/Applications/BoosterSim.app/Contents/Frameworks/BoosterSimConnect.framework` because:
1. The code snippet goes in the USER's iOS app code
2. The user has BoosterSim installed in /Applications
3. The framework is only available after installation, not during development

Keep the hardcoded path but add a note for development builds.

### Step 4: Verify BoosterSimConnect.swift Compatibility

Review `BoosterSimConnect.swift` for any macOS-specific APIs that won't compile for iOS Simulator:
- `URLSessionProxyDelegate.enableAutomaticRegistration()` — Pulse API, should be cross-platform
- `RemoteLogger.shared.start()` — Pulse API, should be cross-platform
- `NetworkLogger.Configuration()` / `NetworkLogger.shared` — Pulse API, cross-platform
- `#if DEBUG && targetEnvironment(simulator)` — correct guard

No changes expected but verify during build.

### Step 5: Remove Target Dependency

The current `PBXTargetDependency` (ID `4D8F80BEC56B4C528138E395`) makes BoosterSimApp depend on BoosterSimConnect as a normal build dependency. With cross-platform targets, this causes Xcode to try linking an iOS framework into a macOS app — which will fail.

**Action:** Remove the target dependency from BoosterSimApp. The Run Script phase handles building the iOS framework independently.

In `project.pbxproj`:
1. Remove `4D8F80BEC56B4C528138E395 /* PBXTargetDependency */` entry from BoosterSimApp's `dependencies` array
2. Keep the entry in BoosterSimConnect target (self-referential is fine, or remove entirely)

## Todo List

- [ ] Add iOS Simulator build settings to BoosterSimConnect target (Debug + Release)
- [ ] Add Run Script build phase to BoosterSimApp for iOS framework embedding
- [ ] Remove cross-platform target dependency from BoosterSimApp
- [ ] Update ConnectSetupView code snippet path if needed
- [ ] Build project — verify BoosterSimConnect compiles for iOS Simulator
- [ ] Verify `BoosterSimConnect.framework` appears in `BoosterSimApp.app/Contents/Frameworks/`
- [ ] Build from Xcode IDE — verify both targets build successfully

## Success Criteria

1. `xcodebuild -project BoosterSimApp.xcodeproj -scheme BoosterSimApp -configuration Debug build` succeeds
2. BoosterSimConnect builds for `iphonesimulator` SDK (check build log)
3. `BoosterSimConnect.framework` exists in built app's `Contents/Frameworks/` directory
4. BoosterSimApp (macOS) builds and runs normally — no regressions
5. Framework contains `BoosterSimConnect.swift` compiled for arm64 + x86_64 iOS Simulator

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Xcode refuses cross-platform target in same project | LOW | HIGH | Fallback: create separate Xcode project for BoosterSimConnect, use workspace |
| Pulse SPM package doesn't resolve for iOS Simulator | LOW | HIGH | Verify Pulse Package.swift supports iOS platform; it does (confirmed v5.1.4) |
| Run Script phase slows build | MEDIUM | LOW | Cache derived data; script only rebuilds when BoosterSimConnect sources change |
| Code signing issues with embedded iOS framework | MEDIUM | MEDIUM | Skip code signing for iOS framework (it runs in simulator, not on device) |
| `#if targetEnvironment(simulator)` fails at compile vs runtime | LOW | MEDIUM | Verify Swift compiler handles this correctly — it does (compile-time guard) |

## Rollback Plan

If cross-platform build fails:
1. Revert project.pbxproj changes (git checkout)
2. Create separate `BoosterSimConnect.xcodeproj` for iOS framework
3. Use Xcode workspace to build both projects
4. Pre-build framework and commit binary (last resort)

## Next Steps

- Phase 3 (Testing) uses the built framework to test end-to-end flow
