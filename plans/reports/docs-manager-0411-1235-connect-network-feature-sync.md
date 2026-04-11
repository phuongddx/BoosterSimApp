# Docs Sync: Connect/Network Feature

**Date:** 2026-04-11
**Trigger:** New ConnectService, BoosterSimConnect iOS framework source, network/ views, NetworkTabView rewrite

## Files Updated

### `docs/system-architecture.md` (307 -> 352 LOC)
- Layer diagram: added ConnectService to Feature Services, added iOS Framework Source layer with BoosterSimConnect
- Services section: added ConnectService description (NWBrowser, NWConnection, Bonjour discovery, published state, wiring path)
- Models section: added NetworkEvent, HTTPMethod, TrafficFilter, StatusRange, ConnectionState (removed duplicate AXNode entry)
- Views section: updated NetworkTabView description (live traffic viewer composition)
- Side Panel Components: added 7 new components (ConnectStatusBanner, ConnectSetupView, TrafficFilterBar, TrafficList, TrafficRowView, TrafficDetailView, CurlExporter)
- Data Flow: added Network Traffic Data Flow diagram (Simulator app -> BoosterSimConnect -> Bonjour -> ConnectService -> NetworkTabView)
- Key Design Decisions: added NWBrowser+Bonjour and BoosterSimConnect as loadable framework entries

### `docs/codebase-summary.md` (153 -> 170 LOC)
- Project Stats: updated file count (54->65), LOC (4,705->6,168), added Network framework, added BoosterSimConnect target, noted Pulse SPM dependency
- Directory Structure: added ConnectService.swift (178 LOC), network/ subdirectory (8 files), BoosterSimConnect/ directory
- Key Files by Role: added 3 rows (ConnectService, NetworkEventModel, BoosterSimConnect)
- Largest Files: added TrafficDetailView (300 LOC, #1), NetworkEventModel (208 LOC, #2)
- Feature Sections: replaced Network rows with Connect (Complete), Traffic Viewer (Complete), Certificates (Complete), Network Tools (Placeholder); updated wired sections

### `docs/project-roadmap.md` (132 -> 136 LOC)
- Current Status: added Connect traffic viewer and BoosterSimConnect notes
- Phase 5: added 5 checked items (ConnectService, BoosterSimConnect, Traffic viewer, Connection UI, Certificate trust) and parsing pending note; kept throttle/block/airplane as unchecked
- Milestones: updated Network Tools status description

## Verification

- All file paths confirmed to exist via Glob tool before documenting
- All LOC counts verified via `wc -l` on actual source files
- All class/struct/enum names verified against source code via Read tool
- Wiring chain (AppDelegate -> SideWindowController -> SideWindowView -> NetworkTabView) confirmed via Grep
- No doc exceeds 800 LOC limit (all under 352)
- Duplicate AXNode entry removed from system-architecture.md

## Known Caveats

- `ConnectService.parsePulseEvent()` returns nil (placeholder) -- documented as "parsing pending Pulse SPM" in roadmap
- BoosterSimConnect requires Pulse SPM as external dependency for full activation -- noted in codebase summary and roadmap
- TrafficDetailView at 300 LOC is the largest file -- flagged as candidate for split in Largest Files table
