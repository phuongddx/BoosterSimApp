---
title: "Health Data Generator"
description: "Seed iOS Simulator Health app with test data via a bundled iOS companion app (BoosterHealth) triggered from BoosterSimApp's side panel."
status: completed
priority: P2
effort: 12h
branch: main
tags: [feature, healthkit, ios-companion, side-panel]
created: 2026-03-28
completed: 2026-03-28
blockedBy: []
blocks: []
---

# Health Data Generator

## Overview

Adds a "Health Data" section to the BoosterSimApp side panel. Since `xcrun simctl` has no health CLI, a minimal iOS companion app (`BoosterHealth`) is bundled inside `BoosterSimApp.app`, installed onto the booted Simulator via `simctl`, and triggered via URL scheme to write HealthKit samples.

**Brainstorm:** [brainstorm-0328-1642-health-data-generator.md](../reports/brainstorm-0328-1642-health-data-generator.md)

---

## Architecture

```
BoosterSimApp.app/Contents/Resources/BoosterHealth.app
      ↑ bundled at build time (Xcode copy files build phase)

Flow:
  simctl install <udid> BoosterHealth.app
  simctl openurl <udid> boosterhealth://generate?preset=active_day&date=2026-03-28
      → BoosterHealth.app handles URL → HKHealthStore.save()
```

---

## Phases

| # | Phase | Status | Effort |
|---|-------|--------|--------|
| 01 | [Xcode Target Setup](phase-01-xcode-target-setup.md) | completed | 1h |
| 02 | [iOS Companion App](phase-02-ios-companion-app.md) | completed | 4h |
| 03 | [macOS HealthDataService](phase-03-macos-health-data-service.md) | completed | 2h |
| 04 | [HealthDataSectionView](phase-04-health-data-section-view.md) | completed | 3h |
| 05 | [Integration](phase-05-integration.md) | completed | 2h |

---

## Key Decisions

- Presets are fixed (not user-configurable) — KISS; user can use manual mode for custom values
- URL payload = query params only (preset name + date) — companion owns generation logic
- No feedback channel from companion → macOS; show estimated progress (time-based)
- HealthKit auth: companion shows minimal auth UI on first launch, headless thereafter
- Companion stays running in Simulator after generating (no terminate needed)
- Duplicate `HealthPreset` enum across targets is acceptable (KISS over DRY for ~20 lines)
- Clear All Health Data button in scope — `boosterhealth://clear` URL handler
- Companion is Simulator-only build (no device slice) — avoids distribution issues

---

## Files Created

**iOS target (BoosterHealth):**
- `BoosterHealth/BoosterHealthApp.swift`
- `BoosterHealth/URLHandler.swift`
- `BoosterHealth/HealthDataGenerator.swift`
- `BoosterHealth/HealthPayload.swift`
- `BoosterHealth/BoosterHealth.entitlements`
- `BoosterHealth/Info.plist`

**macOS (BoosterSimApp target):**
- `BoosterSimApp/Services/HealthDataService.swift`
- `BoosterSimApp/Views/SideWindow/HealthDataSectionView.swift`

**Modified:**
- `BoosterSimApp.xcodeproj/project.pbxproj` (new target + copy phase)
- `BoosterSimApp/App/AppDelegate.swift` (add healthDataService)
- `BoosterSimApp/Windows/SideWindowController.swift` (pass healthDataService)
- `BoosterSimApp/Views/SideWindow/SideWindowView.swift` (add HealthDataSectionView)

---

## Validation Log

### Session 1 — 2026-03-28
**Trigger:** Pre-implementation validation
**Questions asked:** 4

#### Questions & Answers

1. **[Risk]** HKHealthStore.requestAuthorization may require a visible window context. How should the companion handle HealthKit authorization?
   - Options: Minimal auth screen | Stay headless | Force-grant via simctl privacy
   - **Answer:** Minimal auth screen
   - **Rationale:** Silent auth failure would make feature appear broken with no feedback. Small SwiftUI view on first launch is low-cost insurance.

2. **[Architecture]** HealthPreset enum duplicated in iOS and macOS targets. How to handle?
   - Options: Accept duplication | Shared Swift Package | Shared framework
   - **Answer:** Accept duplication
   - **Rationale:** ~20 lines each, different purposes (generation vs URL building). Shared target adds build complexity for minimal gain.

3. **[Risk]** Companion stays running after URL trigger. Lifecycle strategy?
   - Options: Terminate after trigger | Let it stay running | Uninstall after trigger
   - **Answer:** Let it stay running
   - **Rationale:** iOS handles multiple onOpenURL calls sequentially. Simpler, no terminate delay.

4. **[Scope]** Should "Clear all health data" be in scope?
   - Options: Out of scope | Add Clear button now | Targeted delete
   - **Answer:** Add Clear button now
   - **Rationale:** ~1h extra effort, high utility — avoids needing to erase entire Simulator.

#### Confirmed Decisions
- Auth UI: minimal SwiftUI view on first launch — CONFIRMED
- Duplication: acceptable for HealthPreset across targets — CONFIRMED
- Lifecycle: companion stays running — CONFIRMED
- Scope expanded: Clear button + `boosterhealth://clear` URL handler — CONFIRMED

#### Impact on Phases
- Phase 02: Add minimal auth UI to BoosterHealthApp.swift + add `boosterhealth://clear` handler
- Phase 03: Add `clearAllData(udid:)` method to HealthDataService
- Phase 04: Add "Clear" button to HealthDataSectionView
