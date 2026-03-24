---
status: complete
created: 2026-03-24
completed: 2026-03-24
slug: animation-smoothness
---

# Animation Smoothness Plan

Fix lag and abrupt transitions across the side panel.

## Root Causes (from brainstorm)
1. AX observer registered on app element with wrong notification names — window moves fall through to 0.5s poll
2. Every AX event triggers a full `CGWindowListCopyWindowInfo` scan
3. SwiftUI section content has no `.transition()` — pops in/out
4. Panel collapse/expand swaps view trees with no SwiftUI transition

## Phases

| # | Phase | Priority | Status |
|---|---|---|---|
| 1 | [Fix AX window-element tracking](phase-01-ax-window-tracking.md) | High | done |
| 2 | [Fast position update path](phase-02-fast-position-updates.md) | High | done |
| 3 | [SwiftUI transitions + spring polish](phase-03-swiftui-transitions.md) | Medium | done |

## Files Modified
- `Services/WindowObserver.swift` (Phase 1 + 2)
- `Services/SimulatorWindowTracker.swift` (Phase 2)
- `Views/SideWindow/FeatureSectionView.swift` (Phase 3)
- `Views/SideWindow/SideWindowView.swift` (Phase 3)
- `Windows/SideWindowController.swift` (Phase 3)

## Success Criteria
- Panel follows Simulator in real-time during drag (no perceptible delay)
- Section open/close animates content smoothly (no pop)
- Panel collapse/expand transitions both SwiftUI content and NSPanel frame together

## Validation Log

### Session 1 — 2026-03-24
**Trigger:** Pre-implementation plan review
**Questions asked:** 4

#### Questions & Answers

1. **[Architecture]** Phase 1 proposes enumerating individual window AXUIElements and registering kAXWindowMovedNotification on each. The simpler fix: just swap kAXMovedNotification -> kAXWindowMovedNotification on the existing app element. Which approach?
   - Options: Simple swap on app element | Per-window registration | Both
   - **Answer:** Per-window registration (as planned)
   - **Rationale:** Gives direct element references needed for Phase 2's fast frame reads

2. **[Architecture]** Phase 2 proposes storing AXUIElement references. But the AX callback already receives the element param. Should we pass the element through instead of storing references?
   - Options: Pass element from callback | Store refs as planned | Hybrid
   - **Answer:** Pass element from callback
   - **Rationale:** Simpler, no stored refs, eliminates stale reference risk entirely

3. **[Tradeoff]** After Phase 1 fixes AX notifications, what should happen to the 0.5s pollTimer?
   - Options: Reduce to 2s | Keep 0.5s | Remove entirely
   - **Answer:** Reduce to 2s
   - **Rationale:** 4x less CPU. AX handles real-time updates. Still catches edge cases.

4. **[Scope]** Phase 3 adds .easeInOut transitions, Phase 4 replaces with .spring. Merge into single phase?
   - Options: Merge Phase 3+4 | Keep separate | Merge with optional spring
   - **Answer:** Merge Phase 3+4
   - **Rationale:** One pass over files. No wasted intermediate state.

#### Confirmed Decisions
- Phase 1: per-window AX registration stays as planned
- Phase 2: pass AXUIElement from callback, drop stored refs approach
- Phase 2: reduce poll timer 0.5s -> 2s
- Phase 3+4: merged into single Phase 3

#### Action Items
- [x] Update Phase 2 to use callback element passthrough
- [x] Add poll timer reduction to Phase 2
- [x] Merge Phase 3+4 into single Phase 3 file
- [x] Delete Phase 4 file

#### Impact on Phases
- Phase 2: simplified — no stored [AXUIElement], pass element from callback instead
- Phase 2: added poll timer reduction (0.5s -> 2s)
- Phase 3: now includes spring animations + reducedMotion checks
- Phase 4: deleted (merged into Phase 3)
