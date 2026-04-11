---
title: "Phase 3: Testing & Polish"
description: "End-to-end testing with live iOS Simulator app, edge case handling, UI polish"
status: pending
priority: P1
effort: 4h
depends_on: [phase-01, phase-02]
---

# Phase 3: Testing & Polish

## Context Links

- Phase 1 output: `BoosterSimApp/Services/PulseServer.swift`, `PulseClientConnection.swift`, `PulsePacketDecoder.swift`
- Phase 2 output: Embedded `BoosterSimConnect.framework` in app bundle
- ConnectSetupView: `BoosterSimApp/Views/SideWindow/network/ConnectSetupView.swift`
- NetworkTabView: `BoosterSimApp/Views/SideWindow/tabs/NetworkTabView.swift`

## Overview

Validate the complete flow: macOS app starts server, iOS Simulator app connects via BoosterSimConnect, network traffic appears in real-time. Fix edge cases and polish the setup experience.

**Priority:** P1 — validates Phase 1 + Phase 2
**Current status:** Blocked by Phase 1 and Phase 2

## Key Insights

- No test infrastructure exists in this project (no XCTest target configured). Testing is manual + build verification.
- The project has zero external dependencies policy for macOS app — testing must use Apple frameworks only.
- End-to-end validation requires a running iOS Simulator with a test app.
- ConnectSetupView's "Copy Code" snippet is the user's entry point — must work correctly.

## Requirements

### Functional
- Verify full connection lifecycle: server start → client connect → handshake → events stream → disconnect → reconnect
- Test with real HTTP traffic (GET, POST, PUT, DELETE with various content types)
- Verify TrafficFilterBar filtering works with live events
- Verify TrafficDetailView displays correctly with live data
- Verify cURL export (CurlExporter) works with live events
- Handle multiple simultaneous iOS Simulator connections
- Handle large response bodies (images, JSON arrays) without OOM
- Handle connection drops gracefully (reconnect auto-detection)

### Polish
- ConnectSetupView shows correct framework path for both development and installed scenarios
- Connection state transitions are smooth in UI (no flicker)
- "Searching..." state shows while waiting for first connection
- Events appear in real-time with auto-scroll

## Related Code Files

### Modify
| File | Change |
|------|--------|
| `BoosterSimApp/Views/SideWindow/network/ConnectSetupView.swift` | Polish path, add dev-mode note |
| `BoosterSimApp/Services/ConnectService.swift` | Edge case fixes from testing |
| `BoosterSimApp/Services/PulseClientConnection.swift` | Bug fixes from testing |
| `BoosterSimApp/Services/PulseServer.swift` | Bug fixes from testing |

### Read-only (validation)
| File | Why |
|------|-----|
| All `BoosterSimApp/Views/SideWindow/network/*.swift` | Verify UI renders live data correctly |
| `BoosterSimApp/Views/SideWindow/tabs/NetworkTabView.swift` | Verify integration with ConnectService |

## Implementation Steps

### Step 1: Create Test iOS App (Manual)

Create a minimal iOS app in a separate Xcode project to test the flow:

1. New Xcode project → iOS App → SwiftUI
2. Add to `App.init()` or first view's `onAppear`:
   ```swift
   #if DEBUG && targetEnvironment(simulator)
   Bundle(path: "/Applications/BoosterSim.app/Contents/Frameworks/BoosterSimConnect.framework")?.load()
   #endif
   ```
3. Add buttons that make various HTTP requests:
   - GET request to `https://httpbin.org/get`
   - POST request to `https://httpbin.org/post` with JSON body
   - PUT request to `https://httpbin.org/put`
   - DELETE request to `https://httpbin.org/delete`
   - Request that returns 404
   - Request that returns 500
   - Request with large response body
4. Run in iOS Simulator alongside BoosterSimApp

**Alternative:** Use any existing iOS app project and add the BoosterSimConnect loader line.

### Step 2: Validate Connection Lifecycle

Test matrix:

| Test | Steps | Expected Result |
|------|-------|----------------|
| Auto-connect | Launch iOS app with BoosterSimConnect | ConnectStatusBanner shows "Connected to [device]" |
| Handshake | Connect one client | deviceName and appName populated from clientHello |
| Event streaming | Make HTTP request from iOS app | Event appears in TrafficList within 1s |
| Event fields | Make GET to httpbin.org | URL, method, status code, headers, body all populated |
| Request body | Make POST with JSON body | Request body visible in TrafficDetailView |
| Response body | Make GET to httpbin.org | Response body visible, JSON pretty-printed |
| Error display | Request 404/500 URL | Red status badge, error details in detail view |
| Duration | Any request | Duration displayed in ms |
| Auto-scroll | Make multiple requests | List scrolls to latest event |
| Filter by method | Use TrafficFilterBar | Only matching methods shown |
| Filter by status | Select "4xx" | Only client error responses shown |
| Search | Type "httpbin" | Only matching URLs shown |
| cURL export | Click event → copy cURL | Valid cURL command in pasteboard |
| Disconnect | Kill iOS app | Banner returns to "Searching..." |
| Reconnect | Relaunch iOS app | Banner shows "Connected" again |
| Multiple clients | Launch two simulator apps | Both stream events, interleaved |
| Large body | Request large JSON/image | Body displayed without crash |
| Ping/pong | Wait 5s with no activity | Connection stays alive (ping keeps it) |

### Step 3: Edge Case Hardening

Fix issues discovered during testing. Expected edge cases:

1. **Malformed packet:** Client sends incomplete/corrupt data
   - Fix: PulsePacketDecoder returns nil, PulseClientConnection logs + skips
2. **Connection drop mid-packet:** Client crashes during send
   - Fix: NWConnection error handler triggers cleanup
3. **Very large body (>5MB):** Response body exceeds reasonable memory
   - Fix: Cap at 5MB, truncate with `[truncated]` marker
4. **Rapid event burst:** 100+ events in 1 second
   - Fix: Batch UI updates via Combine debounce or throttle
5. **Duplicate task IDs:** NetworkTaskCreated + NetworkTaskCompleted for same task
   - Fix: Track task IDs, update existing event when completed arrives
6. **Client hello missing fields:** Malformed handshake JSON
   - Fix: Use optional properties in PulseClientHello struct

### Step 4: ConnectSetupView Polish

1. **Dynamic path detection:** Show the correct framework path based on where BoosterSimApp is running:
   ```swift
   private var frameworkPath: String {
       // When installed: /Applications/BoosterSim.app/Contents/Frameworks/BoosterSimConnect.framework
       // When running from Xcode: derived data path (not useful for users)
       // Always show the installed path in the code snippet
       return "/Applications/BoosterSim.app/Contents/Frameworks/BoosterSimConnect.framework"
   }
   ```
2. **Add note:** "Make sure BoosterSim is installed in /Applications before using this code"
3. **Verify "Copy Code" button** copies correct, pasteable snippet
4. **Verify code block is selectable** for manual copy

### Step 5: Build Verification

1. Clean build: `xcodebuild clean build -project BoosterSimApp.xcodeproj -scheme BoosterSimApp -configuration Debug`
2. Verify no warnings related to BoosterSimConnect target
3. Verify `Contents/Frameworks/BoosterSimConnect.framework` exists in built app
4. Verify framework architecture: `lipo -info BoosterSimConnect.framework/BoosterSimConnect` should show `x86_64 arm64`

## Todo List

- [ ] Create test iOS app with BoosterSimConnect loader
- [ ] Validate auto-connect and handshake
- [ ] Validate event streaming for GET/POST/PUT/DELETE
- [ ] Validate request/response body display
- [ ] Validate error handling (404, 500)
- [ ] Validate TrafficFilterBar filtering with live data
- [ ] Validate cURL export with live events
- [ ] Validate disconnect/reconnect cycle
- [ ] Validate multiple simultaneous clients
- [ ] Validate large body handling
- [ ] Fix edge cases discovered during testing
- [ ] Polish ConnectSetupView
- [ ] Clean build verification
- [ ] Final smoke test

## Success Criteria

1. iOS Simulator app connects to BoosterSimApp automatically
2. Network events appear in real-time (< 1s latency)
3. All HTTP methods (GET/POST/PUT/DELETE/PATCH) display correctly
4. Request and response bodies display correctly (JSON pretty-printed)
5. Status code colors and badges are accurate
6. Traffic filtering works with live data
7. cURL export produces valid, runnable commands
8. Connection drops and reconnects handled gracefully
9. No crashes or memory leaks under normal operation
10. Clean build with zero errors

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Pulse protocol version mismatch | LOW | HIGH | Version check in serverHello; log warning |
| iOS Simulator can't load framework from macOS app bundle | MEDIUM | HIGH | Verify path is accessible from simulator; use symlink if needed |
| RemoteLogger connects to wrong server (Pulse Pro also running) | LOW | LOW | Document: close Pulse Pro before testing |
| Memory growth from event accumulation | MEDIUM | MEDIUM | 500-event cap already in place; verify it works |

## Unresolved Questions

1. **Framework path in Simulator:** Can an iOS Simulator app access `/Applications/BoosterSim.app/Contents/Frameworks/`? macOS allows filesystem access from Simulator. Verify this works — if not, may need to copy framework to a shared location or use a different loading mechanism.
2. **NetworkTaskCreated (code 8) handling:** Should we show "pending" requests (code 8) before the response arrives, or wait for code 10 only? Showing pending gives faster feedback but complicates the model (need to update existing events when code 10 arrives). Recommendation: start with code 10 only, add code 8 later as enhancement.
3. **TLS/PSK support:** Pulse supports optional passcode-based TLS. Skip for MVP — local simulator communication doesn't need encryption. Add if remote device support is needed later.

## Next Steps

- After Phase 3 completion: update `docs/system-architecture.md`, `docs/codebase-summary.md`, `docs/project-roadmap.md`
- Consider adding Phase 4: persistent event storage (CoreData/SQLite) for history across restarts
- Consider adding Phase 5: remote device support (TLS/PSK, non-simulator connections)
