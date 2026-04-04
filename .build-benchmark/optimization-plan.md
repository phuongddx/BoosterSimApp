# BoosterSimApp Build Optimization Plan

Generated: 2026-04-03

---

## Baseline Measurements

| Build type | Wall-clock |
|---|---|
| Clean (cold — no CAS) | **36.2s** |
| Clean (warm CAS cache) | **12.9s** |
| Incremental (touch AppDelegate.swift) | **3.5s** |

**Benchmark variance:** Spread between cold/warm is 23.3s — expected because `COMPILATION_CACHE_CAS_PATH` is separate from DerivedData. Warm cache is the realistic daily-driver experience.

**Project context:**
- Scheme: `BoosterSimApp`, configuration: `Debug`, destination: `platform=macOS`
- 52 app Swift files + 3 BoosterHealth iOS files
- Zero SPM packages — pure Apple frameworks
- Two targets: macOS app (`BoosterSimApp`) + iOS Simulator helper app (`BoosterHealth`) with cross-platform dependency
- `SWIFT_ENABLE_EXPLICIT_MODULES = YES`, `COMPILATION_CACHE_CAS_PATH` — CAS already active

---

## Findings

### F1 — `ENABLE_PREVIEWS = YES` on BoosterHealth (iOS helper target)
- **Evidence:** Build log shows 3 extra CodeSign operations for BoosterHealth: `BoosterHealth.debug.dylib`, `__preview.dylib`, `BoosterHealth.app`. BoosterHealth is a 3-file iOS app bundled inside the macOS app via a copy script — it is never opened in Xcode's canvas.
- **Impact:** Preview dylib generation + 2 extra CodeSigns add ~4–6s to every cold clean build for BoosterHealth. Warm-cache incremental may also re-sign when BoosterHealth source changes.
- **Risk:** Low — BoosterHealth has no SwiftUI Previews in practice.

### F2 — `SWIFT_VERSION = 5.0` on all targets (mismatch with Swift 6 intent)
- **Evidence:** All four targets (`BoosterSimApp`, `BoosterHealth`, Tests) set `SWIFT_VERSION = 5.0`. CLAUDE.md states "Swift 6 strict concurrency". Swift 6 semantics are partially enabled via `SWIFT_APPROACHABLE_CONCURRENCY = YES` and `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` on BoosterSimApp.
- **Impact on build time:** Uncertain — but using Swift 5 mode with Swift-6-style annotations causes extra warnings at compile time (2 seen in build log), meaning the compiler is doing additional diagnostic work without the full Swift 6 enforcement. No measurable wall-clock difference expected.
- **Impact on correctness:** The concurrency model is incomplete. `SWIFT_APPROACHABLE_CONCURRENCY` is a Swift 5.10 feature; true Swift 6 strict concurrency requires `SWIFT_VERSION = 6.0`.
- **Risk:** Medium — may expose existing warnings as errors. Requires testing.

### F3 — Script phase input path uses non-Xcode variable syntax
- **Evidence:** `Copy BoosterHealth.app` script phase sets `inputPaths = ("$(BUILT_PRODUCTS_DIR%/*)/$(CONFIGURATION)-iphonesimulator/BoosterHealth.app")`. Xcode cannot resolve `BUILT_PRODUCTS_DIR%/*` as a build setting — it is bash parameter expansion syntax. Xcode will treat this as a literal unresolvable string, making the input tracking unreliable.
- **Impact:** Script phase may run more often than needed on incremental builds (Xcode falls back to always-run behavior when inputs are unresolvable). On this project, the copy is fast, so no measurable wall-clock impact currently.
- **Risk:** Low — fixing this improves correctness but does not affect current build times.

### F4 — `MTL_ENABLE_DEBUG_INFO = INCLUDE_SOURCE` at project Debug level
- **Evidence:** Project-level Debug config sets `MTL_ENABLE_DEBUG_INFO = INCLUDE_SOURCE`. This is the most expensive Metal debug option — it embeds shader source into build artifacts.
- **Impact:** No measurable impact — no Metal shaders are used in this project. Safe to change to `YES` (embed only line tables) to align with best practice.
- **Risk:** None — no Metal shader usage found.

### F5 — `ENABLE_PREVIEWS = YES` on BoosterSimApp (macOS target)
- **Evidence:** BoosterSimApp Debug + Release both have `ENABLE_PREVIEWS = YES`. Build log shows `BoosterSimApp.debug.dylib` and `__preview.dylib` generated + 2 CodeSign operations.
- **Impact:** If you actively use SwiftUI Previews during development, keep enabled — the preview dylib is the mechanism that makes canvas previews work. If not, disabling saves ~2–3s per clean build.
- **Risk:** Low if disabled — only disables Xcode canvas previews for the macOS target.

---

## Prioritized Recommendations

### REC-1 — Disable `ENABLE_PREVIEWS` on `BoosterHealth` target
**Expected impact:** Reduce your clean build by approximately **4–6s** (removes 2 dylib compilations + 2 CodeSigns).
- Affects: `BoosterSimApp.xcodeproj/project.pbxproj` — BoosterHealth Debug and Release configs
- Change: `ENABLE_PREVIEWS = YES` → `ENABLE_PREVIEWS = NO` (or remove the key)
- Risk: **Low**
- Approval: [ ]

### REC-2 — Fix script phase `inputPaths` to use valid Xcode variable
**Expected impact:** No wait-time improvement expected. The benefit is correct incremental dependency tracking — prevents unnecessary copy on future incremental builds if the tracking improves.
- Affects: `Copy BoosterHealth.app` script phase `inputPaths`
- Change: Replace `$(BUILT_PRODUCTS_DIR%/*)/$(CONFIGURATION)-iphonesimulator/BoosterHealth.app` with a resolvable path. Since `BUILT_PRODUCTS_DIR` for macOS is `.../Debug/` and the iOS output is `.../Debug-iphonesimulator/`, a valid approach is to clear the inputPaths (let Xcode always-run) or set it to the output of the BoosterHealth target using the correct variable: `$(BUILD_DIR)/$(CONFIGURATION)-iphonesimulator/BoosterHealth.app`
- Risk: **Low**
- Approval: [ ]

### REC-3 — Set `SWIFT_VERSION = 6.0` on BoosterSimApp and test targets
**Expected impact:** Impact on wait time is uncertain — re-benchmark after applying to confirm. Benefit: removes Swift 5/6 concurrency annotation mismatch, enables true Swift 6 enforcement, cleans up build warnings.
- Affects: BoosterSimApp Debug/Release, BoosterSimAppTests, BoosterSimAppUITests configs
- Change: `SWIFT_VERSION = 5.0` → `SWIFT_VERSION = 6.0`
- Note: Leave BoosterHealth at 5.0 (it's a minimal iOS helper with no concurrency usage)
- Risk: **Medium** — may expose new compile errors. Run a full build and fix any resulting errors before committing.
- Approval: [ ]

### REC-4 — Change `MTL_ENABLE_DEBUG_INFO` to `YES` (project Debug level)
**Expected impact:** No wait-time improvement expected. The benefit is reduced build artifact size and alignment with standard practice.
- Affects: Project-level Debug XCBuildConfiguration
- Change: `MTL_ENABLE_DEBUG_INFO = INCLUDE_SOURCE` → `MTL_ENABLE_DEBUG_INFO = YES`
- Risk: **None** — no Metal shaders in project
- Approval: [ ]

---

## Approval Checklist

Check the items you want implemented, then reply to proceed to Phase 2.

- [ ] **REC-1** — Disable `ENABLE_PREVIEWS` on BoosterHealth (~4–6s faster clean build) — Low risk
- [ ] **REC-2** — Fix script phase inputPaths syntax — Low risk
- [ ] **REC-3** — Set `SWIFT_VERSION = 6.0` on app/test targets — Medium risk
- [ ] **REC-4** — `MTL_ENABLE_DEBUG_INFO = YES` — No risk

---

## What Was Intentionally Left Unchanged

- `ENABLE_PREVIEWS` on BoosterSimApp macOS target — kept enabled as it's useful for SwiftUI canvas development
- `ONLY_ACTIVE_ARCH = YES` — already correct at project Debug level
- `SWIFT_OPTIMIZATION_LEVEL = -Onone` — correct for Debug
- `DEBUG_INFORMATION_FORMAT = dwarf` — correct for Debug (no dSYM overhead)
- `SWIFT_ENABLE_EXPLICIT_MODULES = YES` + CAS — already optimally configured
- `ENABLE_TESTABILITY = YES` — expected for Debug
