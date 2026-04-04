---
status: complete
created: 2026-03-25
---

# Logging: Simulator Drag Events

Add structured `os.Logger` logging to BoosterSimApp — shared logger utility + instrument simulator window move events.

## Phases

| # | Phase | Status |
|---|-------|--------|
| 1 | [Shared AppLogger utility](phase-01-shared-logger.md) | complete |
| 2 | [Instrument drag events](phase-02-instrument-drag-events.md) | complete |

## Key Decisions

- `os.Logger` (Unified Logging System) — native, zero deps, Console.app filterable
- Shared per-category loggers in `Utilities/AppLogger.swift`
- Drag move events logged at `.debug` level (not `.info` — high frequency)
- Replace existing `print()` calls with logger

## Files Changed

- `BoosterSimApp/Utilities/AppLogger.swift` — **new**
- `BoosterSimApp/Services/WindowObserver.swift` — add drag logging
- `BoosterSimApp/Services/SimulatorWindowTracker.swift` — log .info when AX observer set up per PID
- `BoosterSimApp/Models/AppSettings.swift` — replace `print()` with logger

## Validation Log

### Session 1 — 2026-03-25
**Trigger:** Pre-implementation validation
**Questions asked:** 3

#### Questions & Answers

1. **[Scope]** The plan marks SimulatorWindowTracker logging (setup observer, scan events) as "optional, low value". Should it be included?
   - Options: Skip it | Include setup log only | Include both
   - **Answer:** Include setup log only
   - **Rationale:** AX observer lifecycle logging at .info helps debug why panel doesn't attach; scan event logging is too noisy.

2. **[Privacy]** os.Logger redacts dynamic values by default in release builds. Should frame coordinates be logged as .public or .private?
   - Options: .public | .private (default)
   - **Answer:** .public
   - **Rationale:** Dev tool; frame coordinates are not sensitive. .public ensures values are visible in Console.app in all builds.

3. **[Scope]** Should resize events be logged at .debug too?
   - Options: Both move + resize | Move only
   - **Answer:** Move only
   - **Rationale:** Drag = move. Resize is a separate interaction; logging it separately would add noise with no benefit for the current goal.

#### Confirmed Decisions
- SimulatorWindowTracker: log `setupObserver(for:)` at `.info` — lifecycle visibility without scan noise
- Frame coords: `privacy: .public` — dev tool, coordinates not sensitive
- Resize events: skip logging — move-only scope for drag instrumentation

#### Action Items
- [ ] Update phase-02 to remove resize logging, add .public privacy annotation, add setupObserver .info log
