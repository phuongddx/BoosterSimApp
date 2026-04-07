# Certificate Trust Management — UI Design Spec

**Target:** Side panel section for BoosterSimApp (#10)
**Pattern reference:** `HealthDataSectionView.swift`
**Width:** 260pt (SideWindowMetrics.expandedWidth)
**Framework:** SwiftUI macOS 15+

---

## Visual Mockup (260pt wide)

### State 1 — No CA cert generated yet

```
┌──────────────────────────────────┐
│ 🛡 Certificates            ›     │  ← CollapsibleSection header
├──────────────────────────────────┤
│                                  │
│  ⚪ No CA certificate            │  ← Status row
│                                  │
│  ┌────────────────────────────┐  │
│  │  ＋ Generate CA            │  │  ← Primary action
│  └────────────────────────────┘  │
│                                  │
│  ┌─ info ─────────────────  ✕ ─┐│
│  │ ⓘ Generate a CA then       ││  ← First-use hint
│  │   install it in Simulator  ││
│  │   to inspect HTTPS.        ││
│  └────────────────────────────┘│
└──────────────────────────────────┘
```

### State 2 — CA generated, not installed

```
┌──────────────────────────────────┐
│ 🛡 Certificates            ›     │
├──────────────────────────────────┤
│                                  │
│  🟡 Generated — not installed    │
│                                  │
│  BoosterSim CA                   │  ← Cert details
│  Expires 2027-04-07              │
│                                  │
│  ┌────────────────────────────┐  │
│  │  ⬇ Install to Simulator    │  │  ← Primary CTA (amber)
│  └────────────────────────────┘  │
│                                  │
│  ⟲ Regenerate     🗑 Reset       │  ← Secondary + destructive
│                                  │
└──────────────────────────────────┘
```

### State 3 — CA installed in Simulator

```
┌──────────────────────────────────┐
│ 🛡 Certificates            ›     │
├──────────────────────────────────┤
│                                  │
│  ✅ Installed in iPhone 15 Pro   │  ← Green checkmark + device
│                                  │
│  BoosterSim CA                   │
│  Expires 2027-04-07              │
│                                  │
│  ┌────────────────────────────┐  │
│  │  ⬇ Reinstall              │  │
│  └────────────────────────────┘  │
│                                  │
│  ⟲ Regenerate     🗑 Reset Kchn  │
│                                  │
└──────────────────────────────────┘
```

### State 4 — Working (progress)

```
┌──────────────────────────────────┐
│ 🛡 Certificates            ›     │
├──────────────────────────────────┤
│                                  │
│  ◐ Installing into Simulator…    │  ← Spinner + status text
│                                  │
└──────────────────────────────────┘
```

### State 5 — Error

```
┌──────────────────────────────────┐
│ 🛡 Certificates            ›     │
├──────────────────────────────────┤
│                                  │
│  ⚠ simctl install failed: no    │
│    booted device                 │
│                                  │
│  ┌────────────────────────────┐  │
│  │  ↻ Retry                   │  │
│  └────────────────────────────┘  │
│                                  │
└──────────────────────────────────┘
```

---

## Component Hierarchy

```
CertificateSectionView
├── CollapsibleSection(title: "Certificates", icon: "lock.shield")
│   └── VStack(alignment: .leading, spacing: Spacing.sm)
│       ├── statusRow               ← always visible
│       ├── certDetailsRow          ← when .generated or .installed
│       ├── primaryActionButton     ← Generate / Install / Reinstall / Retry
│       ├── HStack(secondary actions)
│       │   ├── Regenerate button
│       │   └── Reset Keychain button (red)
│       └── firstUseHint            ← dismissible, until first generate
```

---

## Design Tokens (from DesignTokens.swift)

| Element | Token |
|---------|-------|
| Horizontal padding | `Spacing.md` (12pt) |
| Vertical content padding | `Spacing.sm` (8pt) |
| Gap between rows | `Spacing.sm` (8pt) |
| Gap in status row | `Spacing.xs` (4pt) |
| Button corner radius | `CornerRadius.small` (4pt) |
| Info banner radius | `CornerRadius.small` (4pt) |
| Section header height | `SideWindowMetrics.compactRowHeight` (28pt) |

---

## State Model

```swift
enum CertStatus: Equatable {
    case notGenerated
    case generated(commonName: String, expiry: Date)
    case installed(commonName: String, expiry: Date, deviceName: String)
}

enum CertOperation: Equatable {
    case idle
    case generating
    case installing
    case resetting
    case done
    case error(String)
}
```

---

## Colors & Semantic Mapping

| Status | Icon | Color |
|--------|------|-------|
| Not generated | `circle` | `.secondary` (neutral) |
| Generated, not installed | `exclamationmark.circle.fill` | `.yellow` (warning) |
| Installed | `checkmark.seal.fill` | `.green` (success) |
| Error | `exclamationmark.triangle.fill` | `.orange` (caution) |
| In progress | `ProgressView` | (system) |
| Destructive (Reset) | `trash` | `.red` |
| Primary action | — | `.accent` (amber `#E8720C` / `#F59E0B`) |

All `.accent` colors come from the asset catalog — never hardcode.

---

## Interaction Rules

1. **Section starts expanded** (`@State isExpanded = true`) — matches Health/Env Overrides pattern
2. **Section animation** uses `spring(response: 0.35, dampingFraction: 0.85)` (reduceMotion aware)
3. **Buttons disabled during async operations** — opacity 0.5, no press action
4. **Status row animates on state change** — `.easeInOut(duration: 0.2)`
5. **Reset keychain requires confirmation** — `.confirmationDialog` with "This will clear all trusted certs in the Simulator."
6. **First-use hint dismisses permanently** — `@AppStorage("certFirstUseHintDismissed")`
7. **All buttons use `.buttonStyle(.plain)`** — no native chrome
8. **Primary action is a filled rounded rect** (amber background)
9. **Secondary actions are text-only with icon** (like Health's "Clear Health Data" row)

---

## Accessibility

- `accessibilityLabel` on icon-only buttons: "Regenerate CA", "Reset Keychain"
- `.accessibilityElement(children: .combine)` on status row so VoiceOver reads full status as one unit
- Status text uses `.foregroundStyle(.secondary)` which auto-adapts to dark mode
- All icon + text pairs for status (never color-only indication)
- Respects `reduceMotion` via `@Environment` (already handled by `CollapsibleSection`)

---

## Reference SwiftUI Skeleton

```swift
// CertificateSectionView.swift — CA cert generation + Simulator trust management
import SwiftUI

struct CertificateSectionView: View {

    let udid: String
    let deviceName: String
    @EnvironmentObject var certService: CertificateService

    @State private var isExpanded = true
    @State private var showResetConfirm = false

    @AppStorage("certFirstUseHintDismissed") private var hintDismissed = false

    var body: some View {
        CollapsibleSection(title: "Certificates", icon: "lock.shield", isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: Spacing.sm) {

                statusRow
                    .padding(.horizontal, Spacing.md)
                    .padding(.top, Spacing.sm)

                if case .generated = certService.status {
                    certDetailsRow
                } else if case .installed = certService.status {
                    certDetailsRow
                }

                primaryActionButton
                    .padding(.horizontal, Spacing.md)

                secondaryActions
                    .padding(.horizontal, Spacing.md)

                if !hintDismissed && certService.status == .notGenerated {
                    firstUseHint
                }
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
            Button("Reset", role: .destructive) {
                certService.resetKeychain(udid: udid)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This clears all trusted certificates in \(deviceName).")
        }
    }

    // MARK: - Status

    @ViewBuilder
    private var statusRow: some View {
        HStack(spacing: Spacing.xs) {
            switch certService.operation {
            case .generating:
                ProgressView().scaleEffect(0.7)
                Text("Generating CA…").font(.caption).foregroundStyle(.secondary)
            case .installing:
                ProgressView().scaleEffect(0.7)
                Text("Installing into Simulator…").font(.caption).foregroundStyle(.secondary)
            case .resetting:
                ProgressView().scaleEffect(0.7)
                Text("Resetting keychain…").font(.caption).foregroundStyle(.secondary)
            case .error(let msg):
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange).font(.caption)
                Text(msg).font(.caption).foregroundStyle(.secondary).lineLimit(2)
            case .idle, .done:
                statusIdleContent
            }
            Spacer()
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var statusIdleContent: some View {
        switch certService.status {
        case .notGenerated:
            Image(systemName: "circle").foregroundStyle(.secondary).font(.caption)
            Text("No CA certificate").font(.caption).foregroundStyle(.secondary)
        case .generated:
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(.yellow).font(.caption)
            Text("Generated — not installed").font(.caption).foregroundStyle(.secondary)
        case .installed(_, _, let device):
            Image(systemName: "checkmark.seal.fill")
                .foregroundStyle(.green).font(.caption)
            Text("Installed in \(device)").font(.caption).foregroundStyle(.secondary)
                .lineLimit(1).truncationMode(.tail)
        }
    }

    // MARK: - Cert details

    @ViewBuilder
    private var certDetailsRow: some View {
        if let (cn, expiry) = currentCertInfo {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(cn)
                    .font(.caption).fontWeight(.medium)
                Text("Expires \(expiry.formatted(date: .numeric, time: .omitted))")
                    .font(.caption2).foregroundStyle(.tertiary)
            }
            .padding(.horizontal, Spacing.md)
        }
    }

    private var currentCertInfo: (String, Date)? {
        switch certService.status {
        case .generated(let cn, let exp): return (cn, exp)
        case .installed(let cn, let exp, _): return (cn, exp)
        case .notGenerated: return nil
        }
    }

    // MARK: - Primary action

    @ViewBuilder
    private var primaryActionButton: some View {
        Button(action: primaryAction) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: primaryIcon).font(.system(size: 12, weight: .semibold))
                Text(primaryLabel).font(.caption).fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.sm)
            .background(Color.accentColor,
                        in: RoundedRectangle(cornerRadius: CornerRadius.small))
            .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
        .disabled(isWorking)
        .opacity(isWorking ? 0.5 : 1)
    }

    private var primaryIcon: String {
        if case .error = certService.operation { return "arrow.clockwise" }
        switch certService.status {
        case .notGenerated: return "plus"
        case .generated:    return "arrow.down.circle"
        case .installed:    return "arrow.down.circle"
        }
    }

    private var primaryLabel: String {
        if case .error = certService.operation { return "Retry" }
        switch certService.status {
        case .notGenerated: return "Generate CA"
        case .generated:    return "Install to Simulator"
        case .installed:    return "Reinstall"
        }
    }

    private func primaryAction() {
        if case .error = certService.operation {
            certService.retry(udid: udid); return
        }
        switch certService.status {
        case .notGenerated: certService.generateCA()
        case .generated, .installed: certService.install(udid: udid)
        }
    }

    // MARK: - Secondary actions

    @ViewBuilder
    private var secondaryActions: some View {
        if certService.status != .notGenerated {
            HStack {
                Button {
                    certService.generateCA()  // regenerate
                } label: {
                    Label("Regenerate", systemImage: "arrow.triangle.2.circlepath")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .disabled(isWorking)

                Spacer()

                Button {
                    showResetConfirm = true
                } label: {
                    Label("Reset Keychain", systemImage: "trash")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
                .disabled(isWorking)
            }
        }
    }

    // MARK: - First-use hint

    private var firstUseHint: some View {
        HStack(alignment: .top, spacing: Spacing.xs) {
            Image(systemName: "info.circle").foregroundStyle(.secondary).font(.caption)
            Text("Generate a CA then install it into Simulator to inspect HTTPS traffic.")
                .font(.caption2).foregroundStyle(.secondary)
            Spacer()
            Button {
                hintDismissed = true
            } label: {
                Image(systemName: "xmark").font(.caption2).foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.xs)
        .background(Color.yellow.opacity(0.1),
                    in: RoundedRectangle(cornerRadius: CornerRadius.small))
        .padding(.horizontal, Spacing.md)
    }

    // MARK: - Helpers

    private var isWorking: Bool {
        switch certService.operation {
        case .generating, .installing, .resetting: return true
        default: return false
        }
    }
}
```

---

## Wiring Into Existing Codebase

**1. `AppDelegate.swift`** — add service lifecycle:
```swift
let certService = CertificateService(simCtl: simCtlService)
```

**2. `SideWindowController`** — add to init + env injection:
```swift
let certService: CertificateService
// ...
.environmentObject(certService)
```

**3. `SideWindowView.swift`** — insert between Env Overrides and Health Data:
```swift
@EnvironmentObject var certService: CertificateService

// In body:
CertificateSectionView(
    udid: activeUDID ?? "booted",
    deviceName: selectedSim?.displayName ?? "Simulator"
)
.environmentObject(certService)
```

---

## Design Validation vs. Quick Reference

| Rule | Status |
|------|:------:|
| §1 Color contrast 4.5:1 — all text uses `.secondary` / `.primary` | ✅ |
| §1 Icon + text for status (no color-only meaning) | ✅ |
| §1 Respects `reduceMotion` via `CollapsibleSection` | ✅ |
| §1 Destructive action confirmation dialog | ✅ |
| §2 Touch targets — buttons use full width or natural hit area | ✅ |
| §4 SF Symbols only (no emojis) | ✅ |
| §4 Consistent with existing section views | ✅ |
| §4 One primary CTA per state | ✅ |
| §6 Semantic colors (not hardcoded hex) | ✅ |
| §7 State transitions animated 200ms | ✅ |
| §8 Error messages include recovery (Retry button) | ✅ |
| §8 Destructive action uses red + confirmation | ✅ |

---

## Unresolved Questions

1. **Section placement:** Insert above or below Health Data? (Recommendation: above — Network/Cert is more foundational than Health testing.)
2. **Multi-device UX:** If multiple Simulators booted, does "Install" apply to selected device or all? (Proposal: only the currently-selected device in `DeviceHeaderView`.)
3. **Cert expiry warning:** Show yellow warning when cert expires in <30 days? (Out of scope for MVP.)
4. **Show raw PEM / copy to clipboard:** Useful for manual install flows. (Defer to v2.)
