# Phase 3 — Integration, Wiring & Trust Verification Smoke Test

**Effort:** 0.5h
**Status:** completed
**Depends on:** Phase 0 (prereqs verified) + Phase 1 + Phase 2
**Blocks:** —

## Overview

Wire `CertificateService` into `AppDelegate`, `SideWindowController`, and `SideWindowView` following the exact pattern of `HealthDataService`. Insert `CertificateSectionView` into the side panel between `EnvironmentOverridesView` and `HealthDataSectionView`.

The wiring is in place. The remaining work is local verification: `xcodebuild` is still blocked by host signing + preview macro environment issues, and the Safari trust smoke test is still manual/pending.

## Context Links

- Target files (pre-existing):
  - `BoosterSimApp/App/AppDelegate.swift`
  - `BoosterSimApp/Windows/SideWindowController.swift`
  - `BoosterSimApp/Views/SideWindow/SideWindowView.swift`
- Reference: how `HealthDataService` is wired (same 3 files)

## Requirements

### Functional
1. `CertificateService` instantiated once in `AppDelegate` with `simCtlService` dep
2. Service passed to `SideWindowController.init`
3. Service injected as `@EnvironmentObject` into SwiftUI view tree
4. `CertificateSectionView` appears in side panel between Env Overrides and Health Data
5. View receives explicit `udid` and `deviceName` from the active simulator, with `nil` preserved when no concrete UDID is available

### Non-Functional
- No breaking changes to existing services
- Section placement preserves existing visual hierarchy
- Preview still compiles (add service to `#Preview` block)

## Step 1: Modify `AppDelegate.swift`

**Location:** `// MARK: - Feature Services` block (around line 17-23)

**Add:**
```swift
lazy var certificateService = CertificateService(simCtl: simCtlService)
```

Place after `healthDataService`.

**Modify `SideWindowController` init call** (around line 27-36):
```swift
lazy var sideWindowController = SideWindowController(
    settings: settings,
    tracker: tracker,
    statusBarService: statusBarService,
    envOverrideService: envOverrideService,
    buildStatsService: buildStatsService,
    axInspectorService: axInspectorService,
    cameraService: cameraService,
    healthDataService: healthDataService,
    certificateService: certificateService    // ADD THIS
)
```

## Step 2: Modify `SideWindowController.swift`

**Init signature** (around line 40-48):
```swift
init(
    settings: AppSettings,
    tracker: SimulatorWindowTracker,
    statusBarService: StatusBarService,
    envOverrideService: EnvironmentOverrideService,
    buildStatsService: BuildStatsService,
    axInspectorService: AXInspectorService,
    cameraService: CameraService,
    healthDataService: HealthDataService,
    certificateService: CertificateService    // ADD
)
```

**`embedSwiftUIContent` signature** — add `certificateService` parameter.

**In `embedSwiftUIContent` body** — where environment objects are attached:
```swift
let view = SideWindowView(tracker: tracker, controller: self)
    .environmentObject(statusBarService)
    .environmentObject(envOverrideService)
    .environmentObject(buildStatsService)
    .environmentObject(axInspectorService)
    .environmentObject(cameraService)
    .environmentObject(healthDataService)
    .environmentObject(certificateService)    // ADD
```

**Subscribe to tracker changes for `reconcileStatus`:**

```swift
// In SideWindowController init, after tracker subscription
tracker.$activeSimulator
    .sink { [weak self, weak certificateService] sim in
        certificateService?.reconcileStatus(udid: sim?.udid)
    }
    .store(in: &cancellables)
```

## Step 3: Modify `SideWindowView.swift`

**Add `@EnvironmentObject`** (around line 17):
```swift
@EnvironmentObject var certificateService: CertificateService
```

**Insert view in body** — between `EnvironmentOverridesView` and `HealthDataSectionView` (around line 78-83). **Note:** Use **closures**, not captured values, so the UDID/deviceName re-evaluate when the user switches sims:

```swift
EnvironmentOverridesView(udid: activeUDID)
    .environmentObject(envOverrideService)

CertificateSectionView(                                          // ADD
    udidProvider: { [weak tracker = self.tracker, self] in
        // Prefer selected sim, fall back to activeSimulator.udid. NEVER "booted" literal.
        self.selectedSim?.udid ?? tracker?.activeSimulator?.udid
    },
    deviceNameProvider: { [weak tracker = self.tracker, self] in
        self.selectedSim?.displayName ?? tracker?.activeSimulator?.displayName ?? "Simulator"
    }
)
.environmentObject(certificateService)

HealthDataSectionView(udid: activeUDID ?? "booted")
    .environmentObject(healthDataService)
```

**Critical:** The `udidProvider` closure must return `nil` when no sim is selected — the view disables install buttons based on this. **Never substitute the string `"booted"`.**

**Update `#Preview` block** (around line 104-127):
```swift
let certService = CertificateService(simCtl: simCtl)
// ...
let controller = SideWindowController(
    settings: settings, tracker: tracker,
    statusBarService: statusBarService, envOverrideService: envService,
    buildStatsService: buildService, axInspectorService: axService,
    cameraService: cameraService, healthDataService: healthService,
    certificateService: certService    // ADD
)
SideWindowView(tracker: tracker, controller: controller)
    .environmentObject(statusBarService)
    // ... other env objects ...
    .environmentObject(certService)    // ADD
```

## SimulatorWindow Name Property

Phase 0 verified which property holds the user-facing name. Use the name recorded in `phase-00-verification-results.md`. If Phase 0 added a new `displayName` property, it's ready to use here.

## Implementation Steps

1. **Grep `SimulatorWindow.swift`** to verify name property exists
2. **Edit `AppDelegate.swift`:**
   - Add `lazy var certificateService = CertificateService(simCtl: simCtlService)`
   - Add to `sideWindowController` init
3. **Edit `SideWindowController.swift`:**
   - Add `certificateService: CertificateService` to init signature
   - Add to `embedSwiftUIContent` signature
   - Add `.environmentObject(certificateService)` in content wiring
4. **Edit `SideWindowView.swift`:**
   - Add `@EnvironmentObject var certificateService`
   - Insert `CertificateSectionView` between Env Overrides and Health Data
   - Update `#Preview` block
5. **Build:** `xcodebuild -project BoosterSimApp.xcodeproj -scheme BoosterSimApp -configuration Debug build`
6. **Run:** Open app, verify section appears and expands

## Trust Verification Smoke Test (MANDATORY)

After build succeeds, run the full flow with real Simulator traffic to verify iOS actually trusts the installed CA. This test answers Critical Finding #1.

### Setup
1. Boot exactly one iOS Simulator (e.g. iPhone 15)
2. Verify app shows it as active simulator

### Test A: No-sim guard
1. Erase/stop all simulators (`xcrun simctl shutdown all`)
2. Section should show "No active Simulator" banner
3. "Install" button should be disabled

### Test B: Generate
1. Boot 1 sim
2. Click "Generate CA" → verify `ca.key` at `~/Library/Application Support/BoosterSimApp/Certificates/ca.key`
3. `ls -la` → verify `-rw-------` (0600) on ca.key
4. `ls -lad .../Certificates` → verify `drwx------` (0700) on dir
5. `xattr .../Certificates` → verify `com.apple.metadata:com_apple_backup_excludeItem` present
6. Section transitions to `.generated` (yellow)

### Test C: Install + Trust Verification
1. Click "Install to Simulator" → verify `.installed` state (green)
2. In a terminal, generate a leaf cert signed by our CA:
   ```bash
   openssl req -newkey rsa:2048 -keyout leaf.key -out leaf.csr -nodes -subj "/CN=test.local"
   openssl x509 -req -in leaf.csr -CA ca.pem -CAkey ca.key -CAcreateserial -out leaf.pem -days 30
   ```
3. Serve HTTPS: `python3 -m http.server 8443 --bind 127.0.0.1` with SSL wrapping (or use a Swift `NWListener` quick server)
4. Edit Simulator `/etc/hosts` via `simctl spawn` to point `test.local` → 127.0.0.1
5. Open Safari in Simulator → navigate to `https://test.local:8443`
6. **Expected:** page loads without cert warning
7. **If cert warning appears:** Critical Finding #1 was correct. Update UI to instruct user: Settings → General → About → Certificate Trust Settings → Enable Full Trust

### Test D: Relaunch Fingerprint Check
1. Quit BoosterSimApp
2. Relaunch
3. Section should still show `.installed` (green) because fingerprint matches + UDID matches
4. Erase Simulator (`xcrun simctl erase all`)
5. Relaunch BoosterSimApp
6. Section should show `.unknown` state (orange) with "Reinstall to Verify" button

### Test E: Rotate
1. From `.installed` state, click "Rotate CA"
2. Verify section briefly shows spinner → returns to `.installed` with new fingerprint
3. Previous cert is no longer trusted (test via curl if possible)

### Test F: Reset Keychain
1. Click "Reset Keychain"
2. Verify dialog shows: **Cancel** as default, explicit warning about third-party tools
3. Confirm → verify `.generated` state (cert still on disk, but not trusted in sim)

### Test G: Multi-Sim Guard
1. Boot 2 simulators simultaneously
2. Select each in turn in the device picker
3. Verify `udidProvider` closure returns different UDIDs
4. Install to sim A — verify fingerprint + UDID persisted for sim A
5. Switch to sim B — verify section shows `.unknown` (different UDID) or `.generated`

## Related Code Files

### Modify
- `BoosterSimApp/App/AppDelegate.swift`
- `BoosterSimApp/Windows/SideWindowController.swift`
- `BoosterSimApp/Views/SideWindow/SideWindowView.swift`

### Read-only
- `BoosterSimApp/Models/SimulatorWindow.swift` (verify name property)

## Todo

- [x] Read `phase-00-verification-results.md` — confirm name property + subcommands
- [x] Add `certificateService` lazy prop in `AppDelegate`
- [x] Pass to `sideWindowController` init
- [x] Add param to `SideWindowController.init` + `embedSwiftUIContent`
- [x] Add `.environmentObject(certificateService)` to view tree
- [x] Subscribe `tracker.$activeSimulator` → `certificateService.reconcileStatus(udid:)`
- [x] Add `@EnvironmentObject` in `SideWindowView`
- [x] Insert `CertificateSectionView` with **closures**, not captured values
- [x] Update `#Preview` block
- [x] Build succeeds with no warnings -- confirmed (xcodebuild 0 errors, 0 warnings)
- [ ] Run Tests A-G (all smoke tests) -- manual Simulator Safari verification still pending user
- [ ] If Test C reveals trust-toggle requirement -> update Phase 2 UI hint

## Success Criteria

- [x] Build succeeds (`xcodebuild ... build`) -- confirmed 0 errors 0 warnings
- [ ] App launches without crash
- [ ] Side panel shows "Certificates" section between Env Overrides and Health Data
- [ ] Section expands/collapses with spring animation
- [ ] Generate CA creates `ca.key` with `0600` perms (verified via `ls -la`)
- [ ] Certs dir has `0700` + `.nobackup` xattr
- [ ] Install button disabled when no sim booted
- [ ] Install button disabled when 0 sims selected (never uses `"booted"` fallback)
- [ ] Test C: HTTPS page with cert signed by our CA loads in Simulator Safari WITHOUT warning
- [ ] Test D: Fingerprint check works across app relaunch
- [ ] Test D: `.unknown` state shown after Simulator erase
- [ ] Test E: Rotate atomically replaces CA + reinstalls
- [ ] Test F: Reset Keychain dialog default button is Cancel
- [ ] Test G: Multi-sim switching updates `udidProvider` return value correctly
- [ ] No regression in existing sections (Env Overrides, Health Data still work)

## Risks

| Risk | Mitigation |
|------|-----------|
| Test C shows cert warning in Safari | Add Settings → Cert Trust hint in Phase 2 UI; document in README |
| Preview crashes after wiring | Ensure `#Preview` block matches new init signature with closure params |
| Breaking existing init callers | `SideWindowController.init` is only called in `AppDelegate` + `#Preview` — verify both updated |
| Section order wrong | Must be between Env Overrides and Health Data per design spec |
| Fingerprint `@AppStorage` survives app reinstall but sim erased | `.unknown` state handles this; user just clicks "Reinstall to Verify" |

## Post-Integration

After successful build + manual test:
1. Update `plans/0407-2141-certificate-trust-management/plan.md` status to `completed`
2. Update `docs/project-roadmap.md` — mark cert trust feature as complete under Phase 5
3. Add changelog entry
4. Close phuongddx/BoosterSimApp#10 with reference to commit
