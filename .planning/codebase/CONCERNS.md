# Codebase Concerns

**Analysis Date:** 2025-03-25

## Tech Debt

**Security-Scoped Resource Access Imbalance:**
- Issue: `PermissionManager.checkDerivedData()` calls `startAccessingSecurityScopedResource()` but never balances it with `stopAccessingSecurityScopedResource()`
- Files: `Services/PermissionManager.swift` (line 120)
- Impact: The security-scoped resource for DerivedData directory remains "locked" for the app's lifetime. This is functional but violates the documented pattern—Apple's best practice is to bracket access with start/stop pairs. On app shutdown or permission loss, the resource may not properly release.
- Fix approach: Call `stopAccessingSecurityScopedResource()` in `PermissionManager` deinit or when DerivedData access is revoked/cleared. Store the returned boolean from `startAccessingSecurityScopedResource()` to validate success.

**Memory Imbalance in WindowObserver AXObserver Lifecycle:**
- Issue: `WindowObserver.startObserving()` stores `Unmanaged.passRetained(self)` as refcon (line 57), and `stopObserving()` releases it (line 82). This is intentionally balanced but fragile.
- Files: `Services/WindowObserver.swift` (lines 57, 82, 152)
- Impact: The C-style callback `axCallback()` holds a reference via `Unmanaged.fromOpaque().takeUnretainedValue()` (line 152). If `stopObserving()` is never called (e.g., crash before cleanup, premature object dealloc during callback), the retain count will be incorrect, causing a crash or memory leak on next access.
- Fix approach: Add a guard in `startObserving()` to ensure any prior observer is cleaned up first. Consider wrapping the callback in a weak wrapper to prevent use-after-free. Add assertions in tests to verify `stopObserving()` is called.

**Polling Timers Not Canceled on Background/Inactive:**
- Issue: `SimulatorWindowTracker`, `BuildStatsService`, and `PermissionManager` all maintain `Timer` instances that run continuously in background.
- Files:
  - `Services/SimulatorWindowTracker.swift` (line 149: 2s poll interval)
  - `Services/BuildStatsService.swift` (line 23: 5s poll interval)
  - `Services/PermissionManager.swift` (lines 66, 80: 1s poll intervals for Screen Recording and Accessibility)
- Impact: App is not sandboxed, so background timers wake the CPU even when app is backgrounded. This increases battery drain. The 2s window polling + 5s build polling is justified, but the 1s permission polling (especially two separate timers) is aggressive.
- Fix approach: Implement `NSApplication` lifecycle observers (activate/deactivate, hide/unhide) to pause timers when app is backgrounded. Consolidate permission polling into a single timer. Document why 2s/5s intervals were chosen (why not 1s for builds?).

## Known Bugs

**Feature Rows Display "Coming Soon" Indefinitely:**
- Symptoms: Clicking a placeholder feature (Captures, App Actions, Design Tools, Network) shows "Coming soon" label, but label dismisses after 1.5s. User expects clickable action or functionality.
- Files: `Views/SideWindow/FeatureRowView.swift` (lines 54–65)
- Trigger: Click any row in Captures, App Actions, Design Tools, or Network sections (`Views/SideWindow/SideWindowView.swift` lines 75–78)
- Workaround: None. Features are explicitly not implemented.
- Severity: Low (MVP feature placeholder; documented in roadmap as Phase 2–4)

**Accessibility Polling Timer Reuses Screen Recording Timer Variable:**
- Symptoms: Calling `startAccessibilityPolling()` overwrites `screenRecordingPollTimer`, potentially canceling active Screen Recording polling if called simultaneously.
- Files: `Services/PermissionManager.swift` (line 80: reuses `screenRecordingPollTimer` for accessibility polling)
- Trigger: Call `startAccessibilityPolling()` while `startScreenRecordingPolling()` is active
- Workaround: None; timing would have to be coincidental for this to occur
- Severity: Medium (edge case, but causes silent cancellation of permission polling)

**AXTreeView Placeholder Children Not Loaded:**
- Symptoms: Expanding an accessibility element in AXTreeView shows only a vertical line (no child elements listed)
- Files: `Views/SideWindow/AXTreeView.swift` (line 122: comment says "currently shows placeholder")
- Trigger: Open AX tree view, expand any node with children
- Workaround: Manual AX inspection via system tools (Script Editor, Accessibility Inspector)
- Severity: Low (feature explicitly marked as placeholder in code comment)

## Security Considerations

**Non-Sandboxed App with Unmanaged Memory:**
- Risk: The app is not sandboxed (required for `AXIsProcessTrusted()` and `CGWindowListCopyWindowInfo`). This combined with `Unmanaged` pointer manipulation in `WindowObserver` creates a potential vector for memory corruption if the C callback is invoked after `WindowObserver` is deallocated.
- Files: `Services/WindowObserver.swift` (lines 50–72, 145–154), `CLAUDE.md` line "Non-sandboxed"
- Current mitigation: Swift deinit calls `stopObserving()`, which releases the Unmanaged pointer. Callbacks from AXObserver should not fire after deallocation.
- Recommendations:
  1. Add strict verification in tests that WindowObserver is only created/destroyed during Simulator lifecycle (not on hot paths).
  2. Document the AXObserver callback ownership model in a code comment.
  3. Consider wrapping `axCallback` in a safer wrapper that checks observer validity before calling methods.

**DerivedData Path Hardcoded; No Validation:**
- Risk: `BuildStatsService.scanDerivedData()` assumes DerivedData is always at `~/Library/Developer/Xcode/DerivedData`. If the user moves DerivedData (possible in Xcode settings), the scan silently returns nothing. No error feedback to user.
- Files: `Services/BuildStatsService.swift` (line 36–37)
- Current mitigation: None. Falls back to empty build list.
- Recommendations:
  1. Read DerivedData path from Xcode prefs or `xcode-select -p` output.
  2. Show a warning in UI if no builds found for >30 seconds (indicates path issue).

**Permission Check Results Not Cached; Race Condition Possible:**
- Risk: `PermissionManager.checkAccessibility()` calls `AXIsProcessTrusted()` synchronously on every poll. If accessibility status is revoked mid-check, a race could occur where the UI shows granted but next operation fails.
- Files: `Services/PermissionManager.swift` (lines 34–41, 77–88)
- Current mitigation: The polling interval (1s) means revocation is detected quickly; UI recovery is fast.
- Recommendations: Document that permission loss is detected reactively (not proactively), and gracefully handle permission denial in feature services (currently just silently fails).

## Performance Bottlenecks

**WindowEnumerator CGWindowList Scan (2s Interval):**
- Problem: `SimulatorWindowTracker.startPolling()` calls `WindowEnumerator.enumerateSimulatorWindows()` every 2 seconds, which calls `CGWindowListCopyWindowInfo()` (scans all windows on screen). For multi-monitor setups with many windows, this is expensive.
- Files: `Services/SimulatorWindowTracker.swift` (line 149), `Services/WindowEnumerator.swift` (line 11)
- Cause: Polling is a fallback for AXObserver edge cases. When a Simulator appears/disappears, AXObserver may miss the event (desktop switch, workspace change, Simulator crash during AX registration).
- Improvement path:
  1. Reduce polling to 5s (accept up to 5s latency for detecting new Simulator).
  2. Trigger full scan only on explicit events (workspace notification, app launch/terminate).
  3. Cache window list results; only diff against prior scan if no events occurred.
  4. Add metric logging: track scan count/frame rate; alert if > 1 scan/sec.

**BuildStatsService Reads All Manifests Every 5s:**
- Problem: `scanDerivedData()` enumerates all projects in DerivedData, reads metadata for last 20 modified, then parses their `LogStoreManifest.plist` files (every 5s).
- Files: `Services/BuildStatsService.swift` (lines 35–67)
- Cause: No incremental scan; full filesystem traversal on every tick.
- Improvement path:
  1. Leverage mtime caching (already present: `mtimeCache`). Only re-parse if manifest mtime changed.
  2. Reduce polling to 10s (build completion is rare; user can manually refresh).
  3. Parse on background queue; don't block main thread.
  4. Limit to 10 manifests instead of 20 (diminishing returns for older projects).

**AXInspectorService Synchronous Tree Walk on Main Thread:**
- Problem: `AXInspectorService.loadRoot()` recursively walks the accessibility tree synchronously when a Simulator becomes active, potentially freezing the UI if the tree is large.
- Files: `Services/AXInspectorService.swift` (lines 38–51)
- Cause: No async/await (codebase uses Combine only); tree walk is naive recursion.
- Improvement path:
  1. Move tree walk to background queue.
  2. Cap depth (e.g., max 3 levels) or breadth (first 50 children per node) to prevent runaway traversal.
  3. Implement incremental loading (expand on demand in UI).

## Fragile Areas

**SimulatorWindowTracker Multi-Simulator Handling Untested:**
- Files: `Services/SimulatorWindowTracker.swift` (lines 114–123)
- Why fragile: Code assumes multiple Simulators can be tracked simultaneously, but:
  - `@Published var activeSimulator` is a single window (not array)
  - SideWindowController attaches to only one Simulator at a time
  - Multi-Simulator testing never performed (no tests)
  - If two Simulators are side-by-side, side panel flips between them based on which has focus
- Safe modification: Add comprehensive multi-Simulator tests before adding features that rely on tracking multiple at once. Document the "active-only" constraint.

**AXObserver Registration on New Windows (Race Condition Potential):**
- Files: `Services/WindowObserver.swift` (lines 101–105)
- Why fragile: When a new window is created, the code immediately re-enumerates and registers notifications on all windows. But:
  - AX tree is read asynchronously; element refs may become stale
  - Duplicate registration is idempotent (safe), but calling `registerWindowNotifications()` during a callback is re-entrant
  - If Simulator crashes/restarts mid-registration, observer may not exist
- Safe modification: Add guard to prevent re-entrant registration. Serialize all observer mutations through a queue.

**SpringAnimator Display Link Never Invalidated on Crash:**
- Files: `Utilities/SpringAnimator.swift` (lines 22, 53–74)
- Why fragile: `CADisplayLink` callbacks can fire after `SpringAnimator` is deallocated if the display link isn't invalidated in time. The deinit does invalidate (line 54), but:
  - If a crash occurs during a callback, deinit may not run
  - Display link holds a reference to the target (self); circular ref if not carefully managed
- Safe modification: Test that display link is invalidated after stop() is called. Use weak self in the display link callback.

**PermissionManager Initialization Order Sensitive:**
- Files: `Services/PermissionManager.swift`
- Why fragile: `checkDerivedData()` (line 115) resolves a security-scoped bookmark from UserDefaults. If the bookmark is stale or invalid, the method silently returns without setting `derivedDataAccessGranted`. AppDelegate assumes this flag reflects true state but it may be false due to stale bookmark, not actual denial.
- Safe modification: Distinguish between "never granted" and "granted but stale" states. Show different UI messages.

## Scaling Limits

**Polling Timer Accumulation:**
- Current capacity: SimulatorWindowTracker (2s) + BuildStatsService (5s) + PermissionManager (1s × 2) = 4 independent timers running
- Limit: Each timer wakes main thread; 4+ timers = noticeable CPU wake cycles, especially in low-power scenarios
- Scaling path: Consolidate into a single "mainloop" timer (e.g., 0.5s) that dispatches all poll duties, or use block-based dispatch sources (GCD timers) which are less wasteful.

**AX Tree Size Unbounded:**
- Current capacity: `AXInspectorService` loads entire Simulator app AX tree into `@Published var nodes`
- Limit: Large, complex apps (e.g., Maps, Safari) can have 1000+ AX elements. Storing all in memory + rendering in SwiftUI list causes lag.
- Scaling path: Implement windowed/virtual list in `AXTreeView`. Load children on expand. Cap depth at 5 levels.

**DerivedData Scan Limited to 20 Manifests:**
- Current capacity: `BuildStatsService` scans 20 most-recent projects
- Limit: If user has >20 active Xcode projects, older ones' builds are not tracked
- Scaling path: Index by manifest mtime; keep only last 100 builds globally (not per-project). Implement pagination/search in UI.

## Dependencies at Risk

**Hardcoded `/usr/bin/xcrun` Path:**
- Risk: `SimulatorWindowTracker` (line 58) and `SimCtlService` (line 35) hardcode path to `xcrun`. If Xcode is moved or `xcrun` not in PATH, silent failure.
- Impact: Device type detection fails; all simulators appear as iOS.
- Migration plan: Use `xcode-select -p` to find Xcode root, construct `<root>/Contents/Developer/usr/bin/xcrun`. Fall back to PATH lookup.

**No Async/Await (Combine-Only):**
- Risk: Codebase uses only Combine `@Published` + Timers. If Apple deprecates Combine or standard library async/await becomes dominant, refactor required.
- Impact: Code reviewers and maintainers expect async/await; Combine-heavy code is harder to onboard.
- Migration plan: Not urgent (Combine is stable). Plan gradual migration to async/await in Phase 7 once feature work is complete.

## Missing Critical Features

**No Error Messaging for Permission Denials:**
- Problem: If Accessibility or Screen Recording permission is revoked, app continues running but features silently fail (e.g., AX tree won't load, build stats disappear).
- Blocks: User has no indication why features stopped working; assumes app is broken.
- Missing: UI alert when permission is lost; prompt to re-grant.

**No Crash Recovery for AXObserver:**
- Problem: If Simulator crashes while AXObserver is active, the observer may fail to unregister, leaking refcon memory.
- Blocks: Long-running sessions with frequent Simulator restarts accumulate leaks.
- Missing: Detect observer callback failures; auto-cleanup on error.

**No Build History Persistence Across Restarts:**
- Problem: `BuildStatsService` scans DerivedData on every launch; no caching. If DerivedData is cleared, build history is lost.
- Blocks: User can't see historical build trends across app restarts.
- Missing: Persist build records to local database (lightweight SQLite or JSON file).

## Test Coverage Gaps

**WindowObserver Unmanaged Lifecycle Not Tested:**
- What's not tested: Creating/destroying multiple WindowObserver instances; verifying refcon is released; validating callback doesn't fire after stop()
- Files: `Services/WindowObserver.swift`
- Risk: Memory leak or use-after-free goes undetected until deployed
- Priority: High (core safety issue)

**Multi-Simulator Tracking Not Tested:**
- What's not tested: Launching 2+ Simulators simultaneously; panel switching between them; observer creation/teardown for each PID
- Files: `Services/SimulatorWindowTracker.swift`
- Risk: Crashes or data loss in multi-Simulator workflows
- Priority: Medium (edge case, but increasingly common with iOS/watchOS/tvOS combos)

**Permission Loss Not Tested:**
- What's not tested: Revoking Accessibility or Screen Recording mid-session; verifying UI recovers; permission re-grant flow
- Files: `Services/PermissionManager.swift`, Views using `@EnvironmentObject`
- Risk: App becomes unusable if user denies permission after granting; no recovery path
- Priority: Medium (common user action: deny, then change mind and grant again)

**AXObserver Edge Cases Not Tested:**
- What's not tested: Simulator crash during callback; workspace switch; PID reuse; fast Simulator launch/terminate cycles
- Files: `Services/WindowObserver.swift`, `Services/SimulatorWindowTracker.swift`
- Risk: Crashes or stale observer references
- Priority: High (system integration sensitive to timing)

**BuildStatsService Manifest Parsing Not Tested:**
- What's not tested: Malformed plists; missing keys; corrupted LogStoreManifest files; concurrent file access
- Files: `Services/BuildStatsService.swift` (lines 71–96)
- Risk: Crash if manifest is invalid; build history display breaks silently
- Priority: Medium (filesystem is unpredictable)

**Spring Physics Numerical Stability Not Tested:**
- What's not tested: Large frame offsets; extreme stiffness/damping values; rapid setTarget() calls; at-rest detection boundary conditions
- Files: `Utilities/SpringAnimator.swift`
- Risk: Animation jitter, infinite loops, or missed at-rest detection
- Priority: Low (tuned values work well empirically; low numerical risk)

---

*Concerns audit: 2025-03-25*
