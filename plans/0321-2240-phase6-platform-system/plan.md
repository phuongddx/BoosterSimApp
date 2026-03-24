---
title: "Phase 6 — Platform & System"
description: "Implement 6 platform/system features: status bar config, env overrides, Watch Simulator, build stats, VoiceOver navigator, live camera feed."
status: complete
priority: P1
effort: 18h
branch: main
tags: [feature, ios-simulator, platform]
created: 2026-03-21
---

# Phase 6 — Platform & System

## Overview

Implements all 6 Phase 6 features in BoosterSimApp. Built on a shared `SimCtlService` foundation. All features follow existing Swift 6 + Combine patterns. Zero external dependencies.

**Research:** [Brainstorm Report](../reports/brainstorm-0321-2230-phase6-platform-system.md)

---

## Phases

| # | Phase | Status | Effort | Link |
|---|-------|--------|--------|------|
| 1 | SimCtlService Foundation | Complete | 1h | [phase-01](./phase-01-simctl-service-foundation.md) |
| 2 | Status Bar Config | Complete | 2h | [phase-02](./phase-02-status-bar-config.md) |
| 3 | Environment Overrides | Complete | 2h | [phase-03](./phase-03-environment-overrides.md) |
| 4 | Watch Simulator Support | Complete | 3h | [phase-04](./phase-04-watch-simulator-support.md) |
| 5 | Xcode Build Statistics | Complete | 3h | [phase-05](./phase-05-xcode-build-statistics.md) |
| 6 | VoiceOver Navigator | Complete | 4h | [phase-06](./phase-06-voiceover-navigator.md) |
| 7 | Simulator Camera | Complete | 3h | [phase-07](./phase-07-simulator-camera.md) |

## Dependencies

- Phases are sequential: each phase depends on the previous
- Phase 1 (`SimCtlService`) is required by phases 2, 3, 4
- Phase 4 (Watch) requires model changes that affect all subsequent phases
- Phase 7 (Camera) must come last — requires AX menu path research before coding

## New Files

```
Services/SimCtlService.swift
Services/StatusBarService.swift
Services/EnvironmentOverrideService.swift
Services/BuildStatsService.swift
Services/AXInspectorService.swift
Services/CameraService.swift
Models/BuildRecord.swift
Models/AXNode.swift
Views/SideWindow/StatusBarSectionView.swift
Views/SideWindow/EnvironmentOverridesView.swift
Views/SideWindow/BuildStatsSectionView.swift
Views/SideWindow/BuildChartView.swift
Views/SideWindow/AXTreeView.swift
Views/SideWindow/CameraView.swift
Windows/AXHighlightPanel.swift
```

## Modified Files

```
Models/SimulatorWindow.swift        — add deviceType: SimulatorDeviceType
Services/SimulatorWindowTracker.swift — classify devices via simctl list
App/AppDelegate.swift               — own new services
```
