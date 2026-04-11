---
title: "BoosterSimConnect: Network Traffic Inspection"
description: "Implement Pulse-compatible NWListener server to receive network traffic from iOS Simulator apps"
status: pending
priority: P1
effort: 14h
branch: main
tags: [network, pulse-protocol, nwlistener, ios-framework, bonjour]
created: 2026-04-11
---

# BoosterSimConnect — Network Traffic Inspection

## Problem

BoosterSimApp's Network tab UI is complete but non-functional. ConnectService uses NWBrowser (client mode) but should be an NWListener (server mode). iOS Simulator apps running Pulse's RemoteLogger connect TO BoosterSimApp, not the other way around.

## Architecture Change

```
CURRENT (broken):
  ConnectService → NWBrowser → discovers Pulse servers → NO SERVERS EXIST

CORRECT:
  ConnectService → PulseServer (NWListener, _pulse._tcp.)
                     ↑ accepts TCP connections from iOS Simulator apps
                     ↑ PulseClientConnection per client
                     ↑ PulsePacketDecoder parses binary protocol
                     ↑ converts to NetworkEvent → publishes via Combine
```

## Phases

| # | Phase | Est | Status | File |
|---|-------|-----|--------|------|
| 1 | Pulse Protocol Server | 6h | `[ ]` | [phase-01-pulse-protocol-server.md](phase-01-pulse-protocol-server.md) |
| 2 | Cross-Platform Framework Build | 4h | `[ ]` | [phase-02-cross-platform-framework.md](phase-02-cross-platform-framework.md) |
| 3 | Testing & Polish | 4h | `[ ]` | [phase-03-testing-and-polish.md](phase-03-testing-and-polish.md) |

## Dependency Graph

```
Phase 1 (PulseServer) ← no blockers, start first
Phase 2 (Framework)   ← independent of Phase 1, can parallel
Phase 3 (Testing)     ← blocked by Phase 1 AND Phase 2
```

## Files Changed

### Create
- `BoosterSimApp/Services/PulseServer.swift` — NWListener server (~120 LOC)
- `BoosterSimApp/Services/PulseClientConnection.swift` — per-client handler (~150 LOC)
- `BoosterSimApp/Services/PulsePacketDecoder.swift` — binary protocol parser (~80 LOC)

### Modify
- `BoosterSimApp/Services/ConnectService.swift` — replace NWBrowser with PulseServer
- `BoosterSimConnect/BoosterSimConnect.swift` — fix for server-mode compatibility
- `BoosterSimApp/Views/SideWindow/network/ConnectSetupView.swift` — dynamic bundle path
- `BoosterSimApp.xcodeproj/project.pbxproj` — fix framework SDK + embed phase

### No changes
- All UI files (TrafficList, TrafficFilterBar, TrafficDetailView, ConnectStatusBanner, CurlExporter) — already complete
- NetworkEventModel.swift — already complete, mapping from Pulse events is straightforward

## Key Risks

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Pulse protocol changes in future version | LOW | HIGH | Graceful unknown-packet skip; version check in handshake |
| BoosterSimConnect fails to build for iOS Simulator | MEDIUM | HIGH | Phase 2 has Xcode build validation step; fallback: separate Xcode project |
| Bonjour collision with Pulse Pro | LOW | MEDIUM | Unique service name "BoosterSimApp"; client connects to first responder |
| Large response bodies OOM | LOW | MEDIUM | Cap body size at 5MB per event; truncate with marker |
| Multiple simultaneous clients | MEDIUM | LOW | Accept all; prefix events with device/app name from handshake |

## Success Criteria

1. BoosterSimApp starts NWListener advertising `_pulse._tcp.` on launch
2. iOS Simulator app with BoosterSimConnect connects automatically
3. Network events appear in real-time in the Network tab
4. Traffic filtering, cURL export, detail view all work with live data
5. BoosterSimConnect.framework is embedded in `Contents/Frameworks/`
6. "Copy Code" snippet uses correct dynamic bundle path
