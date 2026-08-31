---
phase: "4"
slug: "design-tools"
# status lifecycle: draft (seeded by plan-phase) → validated (set by validate-phase §6)
# audit-milestone §5.5 distinguishes NOT-VALIDATED (draft) from PARTIAL (validated + nyquist_compliant: false) (#2117)
status: draft
nyquist_compliant: false
wave_0_complete: false
created: "2026-08-31"
---

# Phase 4 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Swift Testing (`import Testing`, `@Test`, `#expect`) unit bundle BoosterSimAppTests |
| **Config file** | none — existing Xcode project target |
| **Quick run command** | `xcodebuild -project BoosterSimApp.xcodeproj -scheme BoosterSimApp -destination 'platform=macOS' test -only-testing:BoosterSimAppTests -parallel-testing-enabled NO` |
| **Full suite command** | `xcodebuild -project BoosterSimApp.xcodeproj -scheme BoosterSimApp -destination 'platform=macOS' test -only-testing:BoosterSimAppTests -skip-testing:BoosterSimAppUITests -parallel-testing-enabled NO` |
| **Estimated runtime** | ~120 seconds |

---

## Sampling Rate

- **After every task commit:** Run quick run command scoped to the task's `-only-testing:` suites
- **After every plan wave:** Run full suite command
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 180 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 04-01-T1 (tracer: cut-over service + panel + controller + dual grid + Wave 0 math suites) | 04-01 | 1 | REQ-roadmap-phase4-design-tools | T-04-01, T-04-02 | Guide-only overlay rendering (no interactive chrome above foreign windows); tolerant decode of persisted payloads | unit + build | `xcodebuild -project BoosterSimApp.xcodeproj -scheme BoosterSimApp -destination 'platform=macOS' test -only-testing:BoosterSimAppTests/SafeAreaCatalogTests -only-testing:BoosterSimAppTests/GridGeometryTests -only-testing:BoosterSimAppTests/RulerMathTests -parallel-testing-enabled NO && xcodebuild -project BoosterSimApp.xcodeproj -scheme BoosterSimApp -configuration Debug build` | ✅ (created by task) | ⬜ pending |
| 04-01-T2 (persistence: toggle round-trips, versioned presets, one-shot legacy import) | 04-01 | 1 | REQ-roadmap-phase4-design-tools | T-04-02 | Corrupted defaults payloads degrade to empty, never trap; legacy presets never silently vanish | unit | `xcodebuild -project BoosterSimApp.xcodeproj -scheme BoosterSimApp -destination 'platform=macOS' test -only-testing:BoosterSimAppTests/OverlayPersistenceTests -parallel-testing-enabled NO` | ✅ (created by task) | ⬜ pending |
| 04-02-T1 (orientation-aware safe-area resolution + service state + import cap) | 04-02 | 2 | REQ-roadmap-phase4-design-tools | T-04-03 | 16384-px decompression-bomb cap before caching (unit-locked accept/reject) | unit | `xcodebuild -project BoosterSimApp.xcodeproj -scheme BoosterSimApp -destination 'platform=macOS' test -only-testing:BoosterSimAppTests/SafeAreaCatalogTests -only-testing:BoosterSimAppTests/OverlayPersistenceTests -parallel-testing-enabled NO` | ✅ (created by task) | ⬜ pending |
| 04-02-T2 (SafeAreaOverlayView at .safeArea layer + panel controls) | 04-02 | 2 | REQ-roadmap-phase4-design-tools | T-04-01 | No accent-amber in overlay rendering (source assertion); D-04 install order | build + unit | `xcodebuild -project BoosterSimApp.xcodeproj -scheme BoosterSimApp -configuration Debug build && xcodebuild -project BoosterSimApp.xcodeproj -scheme BoosterSimApp -destination 'platform=macOS' test -only-testing:BoosterSimAppTests/SafeAreaCatalogTests -only-testing:BoosterSimAppTests/GridGeometryTests -parallel-testing-enabled NO` | ✅ (created by task) | ⬜ pending |
| 04-02-T3 (ComparisonImageView + file/drag/paste import, opacity/split, bomb-guard) | 04-02 | 2 | REQ-roadmap-phase4-design-tools | T-04-03, T-04-04, T-04-05 | Typed pasteboard reads only; zero network-transfer symbols in design-overlay sources (source check) | build + unit | `xcodebuild -project BoosterSimApp.xcodeproj -scheme BoosterSimApp -configuration Debug build && xcodebuild -project BoosterSimApp.xcodeproj -scheme BoosterSimApp -destination 'platform=macOS' test -only-testing:BoosterSimAppTests/OverlayPersistenceTests -only-testing:BoosterSimAppTests/SafeAreaCatalogTests -parallel-testing-enabled NO` | ✅ (created by task) | ⬜ pending |
| 04-03-T1 (PixelSamplerService cached-capture sampler + PixelSamplerTests) | 04-03 | 3 | REQ-roadmap-phase4-design-tools | T-04-06, T-04-07 | Memory-only cache (zero file-write symbols); window-scoped capture; TCC preflight with denied caption | unit | `xcodebuild -project BoosterSimApp.xcodeproj -scheme BoosterSimApp -destination 'platform=macOS' test -only-testing:BoosterSimAppTests/PixelSamplerTests -only-testing:BoosterSimAppTests/RulerMathTests -parallel-testing-enabled NO` | ✅ (created by task) | ⬜ pending |
| 04-03-T2 (RulerOverlayView + capture-mode input, Esc cancel) | 04-03 | 3 | REQ-roadmap-phase4-design-tools | T-04-08 | Local Esc monitor removed on every disarm path + deinit (balanced add/remove); no focus steal | build + unit | `xcodebuild -project BoosterSimApp.xcodeproj -scheme BoosterSimApp -configuration Debug build && xcodebuild -project BoosterSimApp.xcodeproj -scheme BoosterSimApp -destination 'platform=macOS' test -only-testing:BoosterSimAppTests/RulerMathTests -only-testing:BoosterSimAppTests/PixelSamplerTests -parallel-testing-enabled NO` | ✅ (created by task) | ⬜ pending |
| 04-03-T3 (MagnifierView loupe + click-to-commit picker + panel section) | 04-03 | 3 | REQ-roadmap-phase4-design-tools | T-04-08 | Global mouseMoved monitor only while armed, removed on disarm + deinit; observe-only (no CGEvent tap) | build + unit | `xcodebuild -project BoosterSimApp.xcodeproj -scheme BoosterSimApp -configuration Debug build && xcodebuild -project BoosterSimApp.xcodeproj -scheme BoosterSimApp -destination 'platform=macOS' test -only-testing:BoosterSimAppTests/PixelSamplerTests -only-testing:BoosterSimAppTests/RulerMathTests -only-testing:BoosterSimAppTests/OverlayPersistenceTests -parallel-testing-enabled NO` | ✅ (created by task) | ⬜ pending |
| 04-04-T1 (docs truth pass: architecture section, file map, async-exemption wording) | 04-04 | 4 | REQ-roadmap-phase4-design-tools | — | Docs name the sanctioned bridge pattern truthfully (no stale single-type claim) | docs grep | `for f in DesignOverlayService DesignOverlayPanel DesignOverlayController PixelSamplerService SafeAreaCatalog OverlayGeometry GridOverlayView SafeAreaOverlayView RulerOverlayView MagnifierView ComparisonImageView DesignOverlayPresets; do grep -l "$f" docs/system-architecture.md docs/codebase-summary.md | wc -l | grep -q '^2$' || echo "MISSING: $f"; done` | ✅ (docs exist) | ⬜ pending |
| 04-04-T2 (phase gate: full bundle + pin + six-group blocking smoke) | 04-04 | 4 | REQ-roadmap-phase4-design-tools | T-04-09, T-04-10 (+ verifies T-04-06/07/08 live) | Close only on human-observed six-group smoke; pin proven by sha256 pair | unit bundle + manual (blocking-human) | `xcodebuild -project BoosterSimApp.xcodeproj -scheme BoosterSimApp -destination 'platform=macOS' test -only-testing:BoosterSimAppTests -skip-testing:BoosterSimAppUITests -parallel-testing-enabled NO && git diff --exit-code BoosterSimApp.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved` | ✅ (existing infra) | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

*Wave-0 note: the four geometry/persistence suites (SafeAreaCatalogTests, GridGeometryTests, RulerMathTests) are created by 04-01-T1 and PixelSamplerTests by 04-03-T1 — Swift Testing (`import Testing`, `@Test`, `#expect`), NOT XCTest (04-PATTERNS framework discrepancy flag). Manual-only rows below stay manual.*


---

## Wave 0 Requirements

- [x] Task rows of this map filled from finalized `04-*-PLAN.md` files (plan-phase planner output)
- [ ] Overlay geometry math unit suites (grid layout, safe-area inset resolution, ruler distance) stubbed per Wave 0

*Existing infrastructure (xcodebuild + Swift Testing bundle) covers the framework; no new framework install needed.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Overlay windows visually track the Simulator window (move/resize/minimize) | REQ-roadmap-phase4-design-tools | Requires live Simulator window + screen observation | Move/resize/minimize the Simulator with grid overlay on; overlay stays aligned, persists on focus loss |
| Magnifier loupe + color sampling against live Simulator pixels | REQ-roadmap-phase4-design-tools | Requires Screen Recording permission + live device content | Arm magnifier over known-color content; sampled hex matches the known value within rounding |
| Design comparison overlay visual alignment | REQ-roadmap-phase4-design-tools | Subjective visual fidelity | Import artboard PNG at correct scale, overlay on the app screen, verify alignment handles/opacity control |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 180s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
