---
title: "Phase 2: Create Tab Content Views"
description: "Build 4 tab content views using existing FeatureSectionView + live components"
phase: 2
status: pending
effort: 45m
depends_on: [1]
---

# Phase 2: Create Tab Content Views

## Context

- Plan: `plans/0408-2203-side-window-tab-header/plan.md`
- Phase 1 provides: `SideTab` enum
- Existing components: `FeatureSectionView`, `FeatureRowView`, `EnvironmentOverridesView`, `CertificateSectionView`

## Overview

Create 4 tab content views under `tabs/` subdirectory. Each view is a ScrollView wrapping its content. Use existing `FeatureSectionView` for "Coming soon" items.

## Requirements

### CaptureTabView (~30 lines)

**File:** `BoosterSimApp/Views/SideWindow/tabs/CaptureTabView.swift`

```swift
struct CaptureTabView: View {
    let udid: String?
    // Feature items passed in from SideWindowView
}
```

Content: `FeatureSectionView(title: "Captures", icon: "camera", items: captureItems)`

### DesignTabView (~30 lines)

**File:** `BoosterSimApp/Views/SideWindow/tabs/DesignTabView.swift`

Content: `FeatureSectionView(title: "Design Tools", icon: "paintbrush", items: designItems)`

### ActionsTabView (~40 lines)

**File:** `BoosterSimApp/Views/SideWindow/tabs/ActionsTabView.swift`

Content:
1. `EnvironmentOverridesView(udid:)` — live component, needs `.environmentObject(envOverrideService)`
2. `FeatureSectionView(title: "App Actions", icon: "bolt", items: actionItems)` — coming soon

Need `@EnvironmentObject var envOverrideService: EnvironmentOverrideService` to pass through.

### NetworkTabView (~40 lines)

**File:** `BoosterSimApp/Views/SideWindow/tabs/NetworkTabView.swift`

Content:
1. `CertificateSectionView(udidProvider:deviceNameProvider:)` — live component, needs `.environmentObject(certificateService)`
2. `FeatureSectionView(title: "Network Tools", icon: "globe", items: networkItems)` — coming soon

Need `@EnvironmentObject var certificateService: CertificateService` to pass through.

## Data Flow

```
SideWindowView owns feature item arrays (captureItems, designItems, actionItems, networkItems)
    ↓ passed as props
Tab content views receive items + udid + closures
    ↓
FeatureSectionView renders rows
```

The feature item arrays and computed helpers (`activeUDID`, `selectedSim`) stay in `SideWindowView`. Tab views receive only what they need via init params.

## Files to CREATE

| File | LOC | Receives |
|------|-----|----------|
| `BoosterSimApp/Views/SideWindow/tabs/CaptureTabView.swift` | ~30 | `captureItems` |
| `BoosterSimApp/Views/SideWindow/tabs/DesignTabView.swift` | ~30 | `designItems` |
| `BoosterSimApp/Views/SideWindow/tabs/ActionsTabView.swift` | ~40 | `actionItems`, `udid` |
| `BoosterSimApp/Views/SideWindow/tabs/NetworkTabView.swift` | ~40 | `networkItems`, `udidProvider`, `deviceNameProvider` |

## Files to READ for context

- `BoosterSimApp/Views/SideWindow/FeatureSectionView.swift` — API: title, icon, items
- `BoosterSimApp/Views/SideWindow/EnvironmentOverridesView.swift` — init: `udid: String?`
- `BoosterSimApp/Views/SideWindow/CertificateSectionView.swift` — init: `udidProvider: () -> String?`, `deviceNameProvider: () -> String`

## Implementation Steps

1. Create `tabs/` directory
2. Create `CaptureTabView.swift` — ScrollView + FeatureSectionView
3. Create `DesignTabView.swift` — ScrollView + FeatureSectionView
4. Create `ActionsTabView.swift` — ScrollView + EnvironmentOverridesView + FeatureSectionView, pass through envOverrideService
5. Create `NetworkTabView.swift` — ScrollView + CertificateSectionView + FeatureSectionView, pass through certificateService
6. Add `#Preview` to each

## Todo

- [ ] Create `tabs/` directory
- [ ] Create `CaptureTabView.swift`
- [ ] Create `DesignTabView.swift`
- [ ] Create `ActionsTabView.swift`
- [ ] Create `NetworkTabView.swift`
- [ ] Verify builds

## Success Criteria

- All 4 views render without missing EnvironmentObject crashes
- FeatureSectionView displays correct items per tab
- Actions tab shows EnvironmentOverridesView
- Network tab shows CertificateSectionView
- All wrapped in ScrollView for overflow
- Builds with zero errors
