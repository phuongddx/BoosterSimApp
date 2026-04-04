# Phase 2: EnvironmentOverridesView Expansion

**File:** `BoosterSimApp/Views/SideWindow/EnvironmentOverridesView.swift`
**Priority:** High
**Status:** Pending (depends on Phase 1)

## Context Links
- Plan: `plans/0325-1657-env-overrides-instant-toggles/plan.md`
- Phase 1: `plans/0325-1657-env-overrides-instant-toggles/phase-01-service-overhaul.md`
- Current view: `BoosterSimApp/Views/SideWindow/EnvironmentOverridesView.swift`

## Changes Required

### 1. Wire loadCurrentState on udid change

Currently `loadCurrentState` is never called when the simulator changes. Add `.onChange`:

```swift
.onAppear {
    if let udid { service.loadCurrentState(udid: udid) }
}
.onChange(of: udid) { _, newUdid in
    if let newUdid { service.loadCurrentState(udid: newUdid) }
}
```

### 2. Remove tier2Row helper + warning display

Remove `tier2Row` private method and the `if let warning = service.tier2Warning` block.

### 3. Add 6 new toggle rows

After existing rows, add (grouped visually):

```swift
// Reduce Transparency
overrideRow(label: "Reduce Transparency", icon: "rectangle.on.rectangle") {
    service.setReduceTransparency(!service.reduceTransparency, udid: udid ?? "booted")
} indicator: {
    if service.reduceTransparency { Image(systemName: "checkmark").imageScale(.small).foregroundStyle(.secondary) }
}

// Button Shapes
overrideRow(label: "Button Shapes", icon: "rectangle.and.hand.point.up.left") {
    service.setButtonShapes(!service.buttonShapes, udid: udid ?? "booted")
} indicator: {
    if service.buttonShapes { Image(systemName: "checkmark").imageScale(.small).foregroundStyle(.secondary) }
}

// On/Off Labels
overrideRow(label: "On/Off Labels", icon: "switch.2") {
    service.setOnOffLabels(!service.onOffLabels, udid: udid ?? "booted")
} indicator: {
    if service.onOffLabels { Image(systemName: "checkmark").imageScale(.small).foregroundStyle(.secondary) }
}

// Grayscale
overrideRow(label: "Grayscale", icon: "circle.lefthalf.strikethrough") {
    service.setGrayscale(!service.grayscale, udid: udid ?? "booted")
} indicator: {
    if service.grayscale { Image(systemName: "checkmark").imageScale(.small).foregroundStyle(.secondary) }
}

// Inverted Colors
overrideRow(label: "Invert Colors", icon: "circle.inset.filled") {
    service.setInvertColors(!service.invertColors, udid: udid ?? "booted")
} indicator: {
    if service.invertColors { Image(systemName: "checkmark").imageScale(.small).foregroundStyle(.secondary) }
}

// Differentiate without Color
overrideRow(label: "Differentiate w/o Color", icon: "circle.hexagongrid") {
    service.setDifferentiateWithoutColor(!service.differentiateWithoutColor, udid: udid ?? "booted")
} indicator: {
    if service.differentiateWithoutColor { Image(systemName: "checkmark").imageScale(.small).foregroundStyle(.secondary) }
}
```

### 4. Convert Reduce Motion + Bold Text rows

Replace `tier2Row(...)` calls with `overrideRow(...)` (same pattern as Increase Contrast). No warning triangle.

### 5. Row ordering (final)

```
Dark Mode          ← existing
Increase Contrast  ← existing (simctl ui, instant)
Dynamic Type       ← existing (simctl ui, instant)
─── divider ───
Reduce Motion      ← was tier2, now instant
Bold Text          ← was tier2, now instant
Reduce Transparency ← new
─── divider ───
Button Shapes      ← new
On/Off Labels      ← new
Grayscale          ← new
Invert Colors      ← new
Differentiate w/o Color ← new
```

Optionally add a subtle section separator between the two groups (using `Divider().padding(.horizontal, Spacing.md)`).

## File Size Check

Current view is ~130 LOC. Adding 6 rows + removing tier2Row/warning ≈ +40 LOC net.
Estimated final: ~170 LOC — within 200 LOC limit. No modularization needed.

## Implementation Steps

1. Remove `tier2Row` helper method
2. Remove `if let warning = service.tier2Warning` block
3. Convert Reduce Motion + Bold Text rows to `overrideRow`
4. Add 6 new `overrideRow` calls
5. Add `.onAppear` + `.onChange(of: udid)` to `controls` view
6. Add divider between existing and new rows
7. Build and verify no compile errors

## Success Criteria

- [ ] All 11 toggles visible in the side panel
- [ ] State loads correctly when panel appears or simulator changes
- [ ] No warning triangle on Reduce Motion / Bold Text
- [ ] File ≤ 200 LOC
- [ ] Visual grouping is clean (matches BoosterSimApp design tokens)
