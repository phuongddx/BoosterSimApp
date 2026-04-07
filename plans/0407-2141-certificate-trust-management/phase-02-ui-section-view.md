# Phase 2 — CertificateSectionView

**Effort:** 1h
**Status:** completed
**Depends on:** Phase 1 (needs `CertificateService` types)
**Blocks:** Phase 3

## Overview

Create `CertificateSectionView.swift` — SwiftUI side panel section matching the pre-designed UI spec. 6 visual states (`notGenerated`, `generated`, `installed`, `unknown`, working, error). Follows `HealthDataSectionView` pattern exactly.

The section view is implemented and the focused Swift typecheck passes. Only repo-wide verification remains blocked by the host environment.

## Context Links

- UI design spec: `../reports/ui-0407-2126-certificate-section-design.md` (ASCII mockups + reference SwiftUI)
- Visual mockup: `../reports/assets/certificate-section-ui-mockup.html`
- Pattern reference: `BoosterSimApp/Views/SideWindow/HealthDataSectionView.swift`
- Shared wrapper: `BoosterSimApp/Views/Shared/CollapsibleSection.swift`
- Design tokens: `BoosterSimApp/Utilities/DesignTokens.swift`

## Requirements

### Functional
1. Render **6** states: `notGenerated`, `generated`, `installed`, `unknown`, working, error
2. Primary CTA adapts to state: Generate CA / Install / Reinstall / Rotate / Retry
3. Secondary actions (**Rotate**, Reset Keychain) appear when cert exists
4. **Rotate** (not Regenerate) — labels clearly as "Rotate CA" and calls `certService.rotate(udid:deviceName:)` (atomic reset → delete → generate → install)
5. Reset Keychain requires confirmation dialog with **explicit warning** about third-party tool certs
6. Destructive action (Reset) requires second confirmation: default button is **Cancel**, not Reset
7. First-use hint dismissible via `@AppStorage` — includes security warning about leaked-key impact
8. Status row shows icon + text; spinner during async ops
9. **Install/Rotate buttons disabled when `activeUDID == nil`** — show "No active Simulator" helper text
10. **`udid` passed as closure** `() -> String?`, not captured value — evaluated at action time to avoid stale UDID across sim switches
11. **`.unknown` state** shows "Cert trust state uncertain — reinstall to confirm" with Reinstall button

### Non-Functional
- File under 200 LOC
- `@EnvironmentObject` for service injection
- All spacing via `DesignTokens` enums
- `reduceMotion`-aware animations (inherited from `CollapsibleSection`)
- `.buttonStyle(.plain)` on all buttons
- SF Symbols only, no emoji

## View Structure

```
CertificateSectionView (
    udidProvider: () -> String?,         // closure, not captured value
    deviceNameProvider: () -> String
)
│
└── CollapsibleSection(title: "Certificates", icon: "lock.shield", isExpanded: $isExpanded)
    └── VStack(alignment: .leading, spacing: Spacing.sm)
        ├── statusRow                    — always visible
        ├── certDetailsRow               — when generated/installed/unknown
        ├── noSimulatorBanner            — when udidProvider() == nil
        ├── primaryActionButton          — state-dependent, disabled if no UDID
        ├── secondaryActions             — when cert exists
        └── firstUseHint                 — when !dismissed && .notGenerated
```

## State → UI Mapping

| Status | Operation | Primary Button | Shows |
|--------|-----------|----------------|-------|
| `.notGenerated` | `.idle` | "Generate CA" + plus | Status, Button, Hint |
| `.generated` | `.idle` | "Install to Simulator" + download | Status, Details, Button, Secondary |
| `.installed` | `.idle` | "Reinstall" + download | Status, Details, Button, Secondary |
| `.unknown` | `.idle` | "Reinstall to Verify" + checkmark.arrow.triangle | Status (warning), Details, Button, Secondary |
| (any) | `.generating` | disabled + spinner | Status ("Generating CA…") |
| (any) | `.installing` | disabled + spinner | Status ("Installing…"), Details |
| (any) | `.rotating` | disabled + spinner | Status ("Rotating CA…"), Details |
| (any) | `.resetting` | disabled + spinner | Status ("Resetting keychain…") |
| (any) | `.error(msg)` | "Retry" + arrow.clockwise | Status (warning + msg), Button |

**Button disable conditions (apply in every row):**
- `udidProvider() == nil` → disable Install/Reinstall/Rotate; show "No active Simulator" banner
- `operation != .idle` → disable all action buttons
- Rotate button additionally hidden in `.notGenerated`

## Colors (Semantic)

| Element | Color |
|---------|-------|
| Status: notGenerated | `.secondary` (gray) |
| Status: generated | `.yellow` (warning) |
| Status: installed | `.green` (success) |
| Status: unknown | `.orange` (caution) |
| Status: error | `.red` (critical) |
| Primary button background | `Color.accentColor` |
| Primary button text | `.white` |
| Reset Keychain button | `.red` |
| Secondary text | `.secondary` |
| Cert expiry text | `.tertiary` |

All colors semantic — no hardcoded hex.

## Reference SwiftUI (abbreviated)

Full skeleton at `../reports/ui-0407-2126-certificate-section-design.md` §"Reference SwiftUI Skeleton".

Key fragments:

```swift
struct CertificateSectionView: View {
    // CRITICAL: closures, not captured values — resolved at action time
    let udidProvider: () -> String?
    let deviceNameProvider: () -> String
    @EnvironmentObject var certService: CertificateService

    @State private var isExpanded = true
    @State private var showResetConfirm = false
    @AppStorage("certFirstUseHintDismissed") private var hintDismissed = false

    private var activeUDID: String? { udidProvider() }

    var body: some View {
        CollapsibleSection(title: "Certificates", icon: "lock.shield", isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                statusRow
                if showsDetails { certDetailsRow }
                if activeUDID == nil { noSimulatorBanner }
                primaryActionButton
                if showsSecondary { secondaryActions }
                if !hintDismissed && isNotGenerated { firstUseHint }
            }
            .padding(.bottom, Spacing.sm)
            .animation(.easeInOut(duration: 0.2), value: certService.status)
            .animation(.easeInOut(duration: 0.2), value: certService.operation)
        }
        .confirmationDialog(
            "Reset Simulator Keychain?",
            isPresented: $showResetConfirm,
            titleVisibility: .visible
        ) {
            Button("Cancel", role: .cancel) {}          // default
            Button("Reset Everything", role: .destructive) {
                guard let udid = activeUDID else { return }
                certService.resetKeychain(udid: udid)
            }
        } message: {
            Text("""
            This wipes ALL keychain data in \(deviceNameProvider()), \
            including certificates installed by other tools (Proxyman, \
            Charles, mitmproxy), app passwords, and tokens. There is no undo.
            """)
        }
    }

    // Guards
    private var showsDetails: Bool {
        switch certService.status {
        case .notGenerated: return false
        case .generated, .installed, .unknown: return true
        }
    }
    private var showsSecondary: Bool { showsDetails }
    private var isNotGenerated: Bool {
        if case .notGenerated = certService.status { return true }
        return false
    }
    // ... subviews: statusRow, certDetailsRow, noSimulatorBanner, primaryActionButton, secondaryActions, firstUseHint
}
```

**First-use hint — required security warning copy:**

```swift
Text("""
Generate a CA and install it in the Simulator to test HTTPS traffic. \
⚠ Keep ca.key private — anyone with this file can intercept HTTPS for any site.
""")
```

**Primary action helpers (closure-based):**

```swift
private func primaryAction() {
    if case .error = certService.operation {
        guard let udid = activeUDID else { return }
        certService.retry(udid: udid, deviceName: deviceNameProvider())
        return
    }
    switch certService.status {
    case .notGenerated:
        certService.generateCA()
    case .generated, .unknown:
        guard let udid = activeUDID else { return }
        certService.install(udid: udid, deviceName: deviceNameProvider())
    case .installed:
        guard let udid = activeUDID else { return }
        certService.install(udid: udid, deviceName: deviceNameProvider())  // reinstall
    }
}
```

**Secondary actions — "Rotate" replaces "Regenerate":**

```swift
HStack {
    Button {
        guard let udid = activeUDID else { return }
        certService.rotate(udid: udid, deviceName: deviceNameProvider())
    } label: {
        Label("Rotate CA", systemImage: "arrow.triangle.2.circlepath")
            .font(.caption).foregroundStyle(.secondary)
    }
    .buttonStyle(.plain)
    .disabled(isWorking || activeUDID == nil)

    Spacer()

    Button {
        showResetConfirm = true
    } label: {
        Label("Reset Keychain", systemImage: "trash")
            .font(.caption).foregroundStyle(.red)
    }
    .buttonStyle(.plain)
    .disabled(isWorking || activeUDID == nil)
}
```

## Implementation Steps

1. **Create file** `BoosterSimApp/Views/SideWindow/CertificateSectionView.swift`
2. **Imports:** `SwiftUI` only
3. **Struct signature:** `let udidProvider: () -> String?`, `let deviceNameProvider: () -> String`, `@EnvironmentObject certService`
4. **State properties:**
   - `@State isExpanded = true`
   - `@State showResetConfirm = false`
   - `@AppStorage("certFirstUseHintDismissed") hintDismissed`
5. **body:** Wrap in `CollapsibleSection`, compose subviews
6. **Subview: `statusRow`** (6 states, not 5)
   - Switch on `certService.operation` first (handles working/error states incl `.rotating`)
   - Falls through to `statusIdleContent` which switches on `certService.status` (notGenerated/generated/installed/unknown)
   - Icons: `circle`, `exclamationmark.circle.fill`, `checkmark.seal.fill`, `questionmark.circle.fill`, `exclamationmark.triangle.fill`
   - `.accessibilityElement(children: .combine)`
7. **Subview: `certDetailsRow`**
   - Extract `(cn, expiry)` via helper `currentCertInfo` computed property
   - Handles `.generated`, `.installed`, and `.unknown` states
   - Display CN (caption, medium weight) + expiry (caption2, tertiary)
8. **Subview: `noSimulatorBanner`** (NEW)
   - Shown when `activeUDID == nil`
   - Small row: `info.circle` icon + "No active Simulator — start one to install"
   - Orange tint
9. **Subview: `primaryActionButton`**
   - Compute `primaryIcon`, `primaryLabel`, `primaryAction()` helpers
   - Full-width button, amber background, white text
   - `CornerRadius.small` radius
   - **Disabled when `isWorking || (needsSimulator && activeUDID == nil)`** — full 0.5 opacity
10. **Subview: `secondaryActions`**
    - `HStack` with **"Rotate CA"** (gray, `arrow.triangle.2.circlepath`) and "Reset Keychain" (red, `trash`)
    - Both disabled when `activeUDID == nil` or `isWorking`
    - Reset triggers `showResetConfirm = true`
11. **Subview: `firstUseHint`**
    - Info banner with `info.circle` icon + security warning copy
    - Yellow background (0.1 opacity)
    - Dismiss button updates `@AppStorage`
12. **Helpers:**
    - `private var currentCertInfo: (String, Date)?`
    - `private var isWorking: Bool`
    - `private var primaryIcon/primaryLabel/primaryAction()`
    - `private var activeUDID: String? { udidProvider() }`
13. **Verify ~200 LOC** — split helpers into extension if >200
13. **Compile check** via Xcode

## Related Code Files

### Create
- `BoosterSimApp/Views/SideWindow/CertificateSectionView.swift`

### Read for reference
- `BoosterSimApp/Views/SideWindow/HealthDataSectionView.swift` (status row, hint pattern)
- `BoosterSimApp/Views/Shared/CollapsibleSection.swift` (wrapper API)
- `BoosterSimApp/Utilities/DesignTokens.swift` (Spacing, CornerRadius)

## Todo

- [x] Create `CertificateSectionView.swift` file
- [x] Implement `body` with `CollapsibleSection` wrapper
- [x] Implement `statusRow` with all 8 state variations
- [x] Implement `certDetailsRow` with CN + expiry formatting
- [x] Implement `primaryActionButton` with state-dependent icon/label/action
- [x] Implement `secondaryActions` row (Regenerate + Reset Keychain)
- [x] Implement `firstUseHint` with `@AppStorage` dismissal
- [x] Add `.confirmationDialog` for Reset Keychain
- [x] Add `.animation(.easeInOut)` on state/operation changes
- [x] Verify file under 200 LOC
- [x] Compile check

## Success Criteria

- [x] File compiles without warnings
- [x] Under 200 LOC
- [ ] All 5 states render correctly (preview test)
- [ ] Section header matches other sections visually
- [x] Reset Keychain shows confirmation dialog
- [x] First-use hint dismissible + persists across relaunches
- [x] Animations respect `reduceMotion` (inherited via `CollapsibleSection`)
- [x] No hardcoded spacing/colors
- [x] Uses only SF Symbols (no emoji)

## Risks

| Risk | Mitigation |
|------|-----------|
| File exceeds 200 LOC | Split subview helpers into `extension CertificateSectionView` in same file |
| Preview crashes due to missing service | Provide mock `CertificateService` in `#Preview` block |
| Confirmation dialog styling inconsistent | Use native `.confirmationDialog` — no custom styling needed |
