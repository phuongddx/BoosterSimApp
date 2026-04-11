---
title: "BoosterSimConnect Implementation Plan"
description: "Plan for building Pulse-compatible NWListener server, cross-platform iOS framework build, and end-to-end testing"
date: 2026-04-11
type: planner
status: completed
---

# BoosterSimConnect Implementation Plan

## Summary

Complete implementation plan for network traffic inspection feature. 3 phases, 14h estimated effort. Phases 1 and 2 are independent and can run in parallel. Phase 3 is blocked by both.

## Key Decision: Architecture Flip

**Current (broken):** ConnectService = NWBrowser client discovering Pulse servers
**Correct:** ConnectService = NWListener server that iOS Simulator apps connect to

Pulse SDK is client-only (sender). No server API exists. Must implement custom NWListener server speaking the Pulse binary protocol (fully documented from open-source client).

## Phase Summary

| Phase | Est | Files Created | Files Modified | Key Risk |
|-------|-----|--------------|----------------|----------|
| 1. Pulse Server | 6h | 3 new (~370 LOC) | ConnectService.swift, AppDelegate.swift | Zlib decompression edge cases |
| 2. iOS Framework | 4h | 0 | project.pbxproj, ConnectSetupView.swift | Cross-platform build in single Xcode project |
| 3. Testing | 4h | 0 | Edge case fixes from testing | iOS Simulator filesystem access to framework |

## Dependency Graph

```
Phase 1 (PulseServer)  ──┐
                          ├──→ Phase 3 (Testing)
Phase 2 (Framework)    ──┘
```

## Files Created

- `plans/0411-2219-booster-sim-connect-activation/plan.md`
- `plans/0411-2219-booster-sim-connect-activation/phase-01-pulse-protocol-server.md`
- `plans/0411-2219-booster-sim-connect-activation/phase-02-cross-platform-framework.md`
- `plans/0411-2219-booster-sim-connect-activation/phase-03-testing-and-polish.md`

## Unresolved Questions

1. Can iOS Simulator apps access `/Applications/BoosterSim.app/Contents/Frameworks/` via Bundle(path:)? macOS allows filesystem access from Simulator but need runtime verification.
2. Should NetworkTaskCreated (code 8) show "pending" requests or wait for code 10 only? Recommendation: code 10 only for MVP.
3. Bonjour collision with Pulse Pro — document that user should close Pulse Pro before using BoosterSimApp's network feature.
