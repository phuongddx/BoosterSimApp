# Plan: Fix Bold Text Toggle

**Dir:** `plans/0327-1149-bold-text-fix/`
**Branch:** main
**Status:** Ready
**blockedBy:** []
**blocks:** []

## Problem

Bold Text toggle in EnvironmentOverrideService doesn't work correctly. Two bugs:

1. **Missing `BoldTextEnabled` key** — `setBoldText` writes `EnhancedTextLegibilityEnabled` + `UIAccessibilityBoldTextEnabled` but skips `BoldTextEnabled` (the canonical key Settings.app reads). Causes plist desync where Settings.app shows stale toggle state.
2. **Excessive delay** — Uses 1-second delay for Settings.app workaround; 500ms is sufficient per research.

## Root Cause

Per researcher report (`plans/reports/researcher-0326-2320-bold-text-override.md`):

Bold Text requires writing **3 plist keys in sync**:

| Domain | Key | Read by |
|--------|-----|---------|
| `com.apple.Accessibility` | `BoldTextEnabled` | Settings.app (toggle state) |
| `com.apple.Accessibility` | `EnhancedTextLegibilityEnabled` | iOS internal (supplementary) |
| `.GlobalPreferences` | `UIAccessibilityBoldTextEnabled` | `UIAccessibilityIsBoldTextEnabled()` + `UITraitCollection.legibilityWeight` |

Current code writes keys 2 and 3 but **omits key 1**.

## Phases

| Phase | File | Status |
|---|---|---|
| 1 | phase-01-fix-bold-text-set.md | Pending |

## Files to Modify

- `BoosterSimApp/Services/EnvironmentOverrideService.swift` — `setBoldText(_:udid:)` method (lines 153–182)

## Success Criteria

- [ ] All 3 plist keys written when toggling Bold Text
- [ ] Settings.app shows correct toggle state after BoosterSimApp toggle
- [ ] Delay reduced to 500ms
- [ ] Build compiles without errors

## Validation Log

### Session 1 — 2026-03-27
**Trigger:** Pre-implementation validation
**Questions asked:** 3

#### Questions & Answers

1. **[Architecture]** The Settings.app workaround (open → 500ms delay → terminate) steals simulator focus briefly. Should we keep it?
   - Options: Keep it (Recommended) | Remove it | Make it optional
   - **Answer:** Keep it
   - **Rationale:** Same technique RocketSim uses. Without it, Bold Text doesn't reliably update all UIKit subsystems.

2. **[Tradeoffs]** The delay before terminating Settings.app — current code uses 1s, researcher says 500ms is sufficient. What delay?
   - Options: 500ms (Recommended) | Keep 1s | 750ms
   - **Answer:** 500ms
   - **Rationale:** Researcher-confirmed minimum. Reduces disruption window.

3. **[Scope]** The setBoldText method is a 30-line Combine flatMap chain (6 steps). Should we simplify during the fix?
   - Options: Fix only (Recommended) | Extract helper
   - **Answer:** Fix only
   - **Rationale:** Minimal change, minimal risk. Don't touch what works.

#### Confirmed Decisions
- Settings workaround: Keep — required for reliable UIKit propagation
- Delay: 500ms — researcher-confirmed, reduces disruption
- Scope: Fix only — no refactoring, just add missing key + adjust delay

#### Action Items
- [ ] Add `BoldTextEnabled` key write as first step in chain
- [ ] Change `.seconds(1)` to `.milliseconds(500)`

#### Impact on Phases
- Phase 1: No changes needed — plan already aligned with validated decisions
