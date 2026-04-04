# Phase 1: Environment Overrides UI Redesign

**Files:** `EnvironmentOverridesView.swift`, `EnvironmentOverrideService.swift`
**Priority:** High
**Status:** Pending

## Context Links
- Plan: `plans/0325-2110-env-overrides-ui-redesign/plan.md`
- Reference: `accessibility-tab.png` (RocketSim accessibility tab)
- Prior plan: `plans/0325-1657-env-overrides-instant-toggles/` (service layer complete)
- Current view: `BoosterSimApp/Views/SideWindow/EnvironmentOverridesView.swift`
- Service: `BoosterSimApp/Services/EnvironmentOverrideService.swift`
- Design tokens: `BoosterSimApp/Utilities/DesignTokens.swift`

## Changes Required

### 1. Add `setContentSizeIndex` to service

`EnvironmentOverrideService.swift` — add one public setter so the slider binding can set an
arbitrary index directly (current API only has `increment`/`decrement`):

```swift
func setContentSizeIndex(_ index: Int, udid: String) {
    guard index >= 0 && index < Self.contentSizes.count else { return }
    contentSizeIndex = index
    simCtl.runVoid(["ui", udid, "content_size", currentSizeName])
        .sink(receiveCompletion: { _ in }, receiveValue: { _ in })
        .store(in: &cancellables)
}
```

Insert after `decrementContentSize` (~line 123).

### 2. Redesign `EnvironmentOverridesView.swift`

#### 2a. Replace `overrideRow<I:View>` with `toggleRow`

Remove the generic `overrideRow<I: View>(label:icon:action:indicator:)` helper.
Add a focused `toggleRow` that takes a `Binding<Bool>`:

```swift
private func toggleRow(_ label: String, icon: String, isOn: Binding<Bool>) -> some View {
    Toggle(isOn: isOn) {
        HStack(spacing: Spacing.sm) {
            Image(systemName: icon).imageScale(.small).frame(width: 16)
            Text(label).font(.body)
        }
    }
    .toggleStyle(.switch)
    .controlSize(.small)
    .padding(.horizontal, Spacing.md)
    .frame(height: SideWindowMetrics.rowHeight)
    .disabled(isDisabled)
}
```

#### 2b. Add `subsectionHeader` helper

```swift
private func subsectionHeader(_ title: String) -> some View {
    Text(title)
        .font(.subheadline).fontWeight(.medium)
        .foregroundStyle(.secondary)
        .padding(.horizontal, Spacing.md)
        .padding(.top, Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
}
```

#### 2c. Custom Bindings

For each toggle, create a `Binding<Bool>` inline:

```swift
// Pattern:
Binding(get: { service.reduceMotion },
        set: { service.setReduceMotion($0, udid: udid ?? "booted") })
```

#### 2d. Reorganize `controls` body

Replace the current flat list with three labeled groups:

```
subsectionHeader("Accessibility")
  toggleRow("Increase Contrast",         icon: "circle.lefthalf.filled",             isOn: increaseContrastBinding)
  toggleRow("Reduce Transparency",        icon: "rectangle.on.rectangle",             isOn: reduceTransparencyBinding)
  toggleRow("Bold Text",                  icon: "bold",                               isOn: boldTextBinding)
  toggleRow("Reduce Motion",              icon: "waveform.path",                      isOn: reduceMotionBinding)
  toggleRow("On/Off Labels",              icon: "switch.2",                           isOn: onOffLabelsBinding)
  toggleRow("Button Shapes",              icon: "rectangle.and.hand.point.up.left",   isOn: buttonShapesBinding)
  toggleRow("Grayscale",                  icon: "circle.lefthalf.strikethrough",      isOn: grayscaleBinding)
  toggleRow("Invert Colors",              icon: "circle.inset.filled",                isOn: invertColorsBinding)
  toggleRow("Differentiate w/o Color",    icon: "circle.hexagongrid",                 isOn: differentiateBinding)

Divider().padding(.horizontal, Spacing.md)

subsectionHeader("Appearance")
  toggleRow("Dark Mode", icon: "moon", isOn: darkModeBinding)

Divider().padding(.horizontal, Spacing.md)

subsectionHeader("Dynamic Type")
  dynamicTypeSlider  // see 2e
```

`darkModeBinding` must toggle between `.dark` / `.light` (current state).

#### 2e. Dynamic Type Slider

Replace the HStack +/- stepper with a slider section:

```swift
private var dynamicTypeSlider: some View {
    VStack(alignment: .leading, spacing: Spacing.xs) {
        HStack(spacing: Spacing.sm) {
            Text("A").font(.caption).foregroundStyle(.secondary)
            Slider(
                value: Binding(
                    get: { Double(service.contentSizeIndex) },
                    set: { service.setContentSizeIndex(Int($0.rounded()), udid: udid ?? "booted") }
                ),
                in: 0...Double(EnvironmentOverrideService.contentSizes.count - 1),
                step: 1
            )
            .disabled(isDisabled)
            Text("A").font(.title3).foregroundStyle(.secondary)
        }
        Text(service.currentSizeName)
            .font(.caption2).foregroundStyle(.secondary)
    }
    .padding(.horizontal, Spacing.md)
    .padding(.vertical, Spacing.xs)
}
```

#### 2f. `.onAppear` / `.onChange` placement

Keep existing lifecycle hooks on `controls`. No change needed — already in the view.

### File Size Estimate

| Change | Delta |
|---|---|
| Remove `overrideRow` generic helper | −20 |
| Add `toggleRow` helper | +14 |
| Add `subsectionHeader` helper | +8 |
| Add `dynamicTypeSlider` sub-view | +16 |
| 10 toggle rows × ~4 LOC (was ~8 LOC each) | −40 |
| Dynamic Type slider block (was stepper ~10 LOC) | +16 vs −10 = +6 |
| 2 Dividers + 3 subsection headers inline | +6 |
| **Net** | **~−26** |

Current: 205 LOC → Estimated: ~179 LOC ✓ (under 200)

## Implementation Steps

1. **Read** both files before touching anything
2. **Service**: add `setContentSizeIndex` after `decrementContentSize` in `EnvironmentOverrideService.swift`
3. **View — helpers**: replace `overrideRow` with `toggleRow` + add `subsectionHeader` + add `dynamicTypeSlider`
4. **View — controls body**: reorganize rows into 3 groups with headers, dividers, bindings
5. **Build**: `xcodebuild -project BoosterSimApp.xcodeproj -scheme BoosterSimApp -configuration Debug build` — fix any errors
6. **Verify** file LOC ≤ 200

## Binding Reference

| Label | Service getter | Service setter |
|---|---|---|
| Dark Mode | `service.appearance == .dark` | `service.setAppearance(on ? .dark : .light, udid:)` |
| Increase Contrast | `service.increaseContrast` | `service.setIncreaseContrast($0, udid:)` |
| Reduce Transparency | `service.reduceTransparency` | `service.setReduceTransparency($0, udid:)` |
| Bold Text | `service.boldText` | `service.setBoldText($0, udid:)` |
| Reduce Motion | `service.reduceMotion` | `service.setReduceMotion($0, udid:)` |
| On/Off Labels | `service.onOffLabels` | `service.setOnOffLabels($0, udid:)` |
| Button Shapes | `service.buttonShapes` | `service.setButtonShapes($0, udid:)` |
| Grayscale | `service.grayscale` | `service.setGrayscale($0, udid:)` |
| Invert Colors | `service.invertColors` | `service.setInvertColors($0, udid:)` |
| Differentiate w/o Color | `service.differentiateWithoutColor` | `service.setDifferentiateWithoutColor($0, udid:)` |

## Success Criteria

- [ ] All 10 toggles visible as Toggle switches (not checkmark buttons)
- [ ] Three section headers: Accessibility, Appearance, Dynamic Type
- [ ] Dynamic Type slider with small/large A labels and current size name below
- [ ] Toggling each switch calls the correct service setter
- [ ] Disabled state respected when `udid == nil`
- [ ] File ≤ 200 LOC
- [ ] Builds without errors
