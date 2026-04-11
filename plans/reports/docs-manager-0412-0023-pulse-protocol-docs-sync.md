# Docs Sync: Pulse Protocol Server Implementation

**Date:** 2026-04-12
**Trigger:** BoosterSimConnect rewritten from NWBrowser client to PulseServer (host mode)

## Changes Made

### `docs/system-architecture.md` (379 LOC, was 353)
- Layer diagram: replaced `ConnectService — Bonjour discovery, NWBrowser` with `ConnectService — Pulse server, event pipeline`; added `PulseServer`, `PulseClientConnection`, `PulsePacketDecoder` rows
- ConnectService section: rewrote from client-mode (NWBrowser discovers Simulator) to server-mode (NWListener accepts connections from Simulator)
- Added 3 new service sections: PulseServer, PulseClientConnection, PulsePacketDecoder with full descriptions
- Network Traffic Data Flow diagram: replaced 9-line client flow with 11-line server flow (Simulator connects inbound to NWListener)
- Key Design Decisions table: changed `NWBrowser + Bonjour for Connect` to `NWListener + Bonjour for Connect` with updated rationale

### `docs/codebase-summary.md` (178 LOC, was 171)
- Project stats: 73 files (was 65), ~6,556 LOC (was ~6,168)
- External dependencies: `Pulse/PulseProxy SPM (BoosterSimConnect framework only)` (was "none, Pulse SPM required for activation")
- Directory tree: added PulseServer.swift (104 LOC), PulseClientConnection.swift (183 LOC), PulsePacketDecoder.swift (174 LOC); updated ConnectService.swift (118 LOC, was 178)
- BoosterSimConnect: 65 LOC (was 75)
- Key Files table: replaced single `ConnectService` row with 4 rows (ConnectService, PulseServer, PulseClientConnection, PulsePacketDecoder)
- Largest Files: updated to reflect current top 9; added PulseClientConnection (183) and PulsePacketDecoder (174)
- Feature Sections: Connect row now "Complete" (was "parsing pending Pulse SPM"); Traffic Viewer row now "Complete" (was "requires BoosterSimConnect")
- Wired sections: added PulseServer alongside ConnectService

### `docs/project-roadmap.md` (138 LOC, was 137)
- Status header: updated to mention Pulse protocol server and full Pulse SPM integration
- Phase 5 checklist: 8 items complete (was 5); replaced old ConnectService/BoosterSimConnect descriptions with Pulse server details; marked network event parsing as complete
- Milestones table: Network Tools status updated to include "Protocol Parsing complete"

## Verification
- No stale references to `NWBrowser`, `Bonjour discovery`, `client mode`, `startDiscovering`, `stopDiscovering` in any doc
- All LOC counts verified via `wc -l` against source files
- All three files under 500 LOC limit
- Framework path in ConnectSetupView confirmed: `/Applications/BoosterSim.app/Contents/Resources/BoosterSimConnect.framework`

## Unresolved Questions
- None
