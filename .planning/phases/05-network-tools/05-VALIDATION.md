---
phase: 5
slug: network-tools
# status lifecycle: draft (seeded by plan-phase) → validated (set by validate-phase §6)
# audit-milestone §5.5 distinguishes NOT-VALIDATED (draft) from PARTIAL (validated + nyquist_compliant: false) (#2117)
status: draft
nyquist_compliant: true
wave_0_complete: false
created: 2026-08-29
---

# Phase 5 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Sources: 05-RESEARCH.md Validation Architecture + the `<verify><automated>` blocks of plans 05-01…05-04 (commands copied from the plans).

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Swift Testing (`import Testing`, `@Test`, `#expect`) under the existing `BoosterSimAppTests` target — in-repo convention (AGENTS.md; `CertificateServiceTests.swift` precedent). Framework-side BoosterSimConnect code is a separate iOS target and not importable here; decision logic therefore lives Mac-side (RESEARCH.md Validation note). |
| **Config file** | none — tests live in `BoosterSimAppTests/` and are discovered by the Xcode target; no framework install needed (Swift Testing ships with the Xcode 26.3 toolchain) |
| **Quick run command** | `$XCT test -only-testing:BoosterSimAppTests/<Suite>` — where `XCT="xcodebuild -project BoosterSimApp.xcodeproj -scheme BoosterSimApp -destination 'platform=macOS'"` |
| **Full suite command** | `$XCT test -only-testing:BoosterSimAppTests` |
| **Estimated runtime** | quick ~60–120 s (incremental build dominates; suites are pure unit tests); full ~120–240 s cold build, ~90 s incremental |

> `$XCT` shorthand (defined above) is used throughout this document; the PLAN.md tasks carry the same commands fully expanded.

---

## Sampling Rate

- **After every task commit:** Run `$XCT test -only-testing:BoosterSimAppTests/<task's suite(s)>` — exactly the suite(s) named in that task's `<verify><automated>` block
- **After every plan wave:** Run `$XCT test -only-testing:BoosterSimAppTests` (all Phase 5 suites plus pre-existing `CertificateServiceTests`)
- **Before `/gsd-verify-work`:** Full suite green + plan 04 Task 3 manual phase-gate smoke recorded per-group in `05-04-SUMMARY.md`
- **Max feedback latency:** ~120 s per task commit (quick run), ~240 s per wave (full suite, cold-build worst case)

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 05-01-01 | 01 | 1 | REQ-roadmap-phase5-network-tools, REQ-nfr-03 | T-05-01, T-05-02, T-05-03, T-05-04, T-05-SC | Command payloads carry hosts/paths only (no URLs/query strings/headers); matcher is string-ops only (no regex); CommandServer loopback-bound; swizzle skips unsafe delegate configs; Package.resolved byte-identical | unit + build + git-diff | `$XCT test -only-testing:BoosterSimAppTests/CommandPayloadTests -only-testing:BoosterSimAppTests/ConditionVerdictTests && $XCT build && git diff --exit-code BoosterSimApp.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved` | ❌ W0 (CommandPayloadTests + ConditionVerdictTests created tests-first in this task) | ⬜ pending |
| 05-01-02 | 01 | 1 | REQ-roadmap-phase5-network-tools | T-05-01, T-05-03 | Framing decoder drops over-cap (10 MB) and malformed frames; persisted keys carry no sensitive data; logging via AppLogger.network | unit | `$XCT test -only-testing:BoosterSimAppTests/NetworkConditionServiceTests -only-testing:BoosterSimAppTests/CommandPayloadTests` | ❌ W0 (NetworkConditionServiceTests created tests-first in this task) | ⬜ pending |
| 05-01-03 | 01 | 1 | REQ-roadmap-phase5-network-tools | T-05-04, T-05-05 | Chained swizzle verified not to break Pulse traffic capture; telemetry stays connected while airplane ON; Mac connectivity untouched | manual (blocking-human, 7 steps) | — (human-check; see Manual-Only Verifications) | n/a | ⬜ pending |
| 05-02-01 | 02 | 2 | REQ-roadmap-phase5-network-tools | T-05-07 | Pacing constructor rejects zero/negative kbps/latency inputs | unit | `$XCT test -only-testing:BoosterSimAppTests/NetworkConditionProfileTests` | ❌ W0 (NetworkConditionProfileTests created tests-first in this task) | ⬜ pending |
| 05-02-02 | 02 | 2 | REQ-roadmap-phase5-network-tools | T-05-06, T-05-07 | Pacing queues bounded by response body size and cancellable from stopLoading; throttle spec rides the version-gated snapshot | unit + build | `$XCT test -only-testing:BoosterSimAppTests/ConditionVerdictTests && $XCT build` | ✅ (extends plan-01 suite) | ⬜ pending |
| 05-02-03 | 02 | 2 | REQ-roadmap-phase5-network-tools | — | Scope caption discloses URLSession HTTP(S)-only applicability (PRO-01, no overclaiming) | build + unit (existing suites) | `$XCT build && $XCT test -only-testing:BoosterSimAppTests/NetworkConditionServiceTests -only-testing:BoosterSimAppTests/NetworkConditionProfileTests` | ✅ | ⬜ pending |
| 05-03-01 | 03 | 2 | REQ-roadmap-phase5-network-tools | T-05-02, T-05-08 | No regex compilation (ReDoS impossible by construction); empty/whitespace domain never matches (no accidental match-all); dot-boundary suffix enforced | unit | `$XCT test -only-testing:BoosterSimAppTests/BlockRuleTests` | ❌ W0 (BlockRuleTests created tests-first in this task) | ⬜ pending |
| 05-03-02 | 03 | 2 | REQ-roadmap-phase5-network-tools | T-05-02, T-05-08 | Rule count capped at 50 with explanatory caption; add requires non-empty domain; all mutations go through the service (never direct UserDefaults) | build + unit | `$XCT build && $XCT test -only-testing:BoosterSimAppTests/BlockRuleTests -only-testing:BoosterSimAppTests/NetworkConditionServiceTests` | ✅ | ⬜ pending |
| 05-04-01 | 04 | 3 | REQ-roadmap-phase5-network-tools, REQ-fr-16 | T-05-09 | Docs describe the loopback design and limitations without credential/machine-specific detail; every documented symbol exists in the source tree | grep assertion | `for f in CommandServer NetworkConditionService BoosterCommandClient NetworkConditionController BoosterNetworkProtocol ThrottlePacing; do grep -l "$f" docs/system-architecture.md docs/codebase-summary.md \| wc -l \| grep -q '^2$' \|\| echo "MISSING: $f"; done` (output must contain no `MISSING:` lines) | n/a | ⬜ pending |
| 05-04-02 | 04 | 3 | REQ-nfr-03, REQ-roadmap-phase5-network-tools | T-05-SC, T-05-03 | Package.resolved byte-identical across the phase (no SPM drift — Pulse 5.2.2 sole exception); scope captions present; no query-string logging | full suite + git-diff + grep | `$XCT test -only-testing:BoosterSimAppTests && git diff --exit-code BoosterSimApp.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved && grep -c "URLSession" BoosterSimApp/Views/SideWindow/network/NetworkConditionsSectionView.swift` | ✅ (all six suites exist post-Wave-2) | ⬜ pending |
| 05-04-03 | 04 | 3 | REQ-roadmap-phase5-network-tools, REQ-fr-16 | T-05-05 | Airplane three-way proof (app fails / viewer live / Mac unaffected); visible 3G slowdown; block-rule error row; relaunch reconcile; certificate regression check | manual (blocking-human, 6 groups) | — (human-check; see Manual-Only Verifications) | n/a | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

Coverage note: framework-side enforcement (`BoosterNetworkProtocol`, `ThrottlePacing`, `NetworkConditionController` mirrors) lives in the BoosterSimConnect iOS target and is not importable by `BoosterSimAppTests` — it is covered by the schema-synced Mac-side decision layer (unit-tested) plus the two manual smokes (05-01-03, 05-04-03), per RESEARCH.md Validation Architecture.

---

## Wave 0 Requirements

- [ ] `BoosterSimAppTests/CommandPayloadTests.swift` — REQ-roadmap-phase5-network-tools wire contract (Codable round-trip, unknown-version tolerance, length-prefix framing incl. partial reads) — created red-first in plan 01 Task 1
- [ ] `BoosterSimAppTests/ConditionVerdictTests.swift` — verdict semantics (airplane fail, rule fail, guard-header pass-through) — created red-first in plan 01 Task 1
- [ ] `BoosterSimAppTests/NetworkConditionServiceTests.swift` — state-machine transitions, persistence re-init, snapshot totality — created red-first in plan 01 Task 2
- [ ] `BoosterSimAppTests/NetworkConditionProfileTests.swift` — preset specs + deterministic pacing math + Codable round-trip — created red-first in plan 02 Task 1
- [ ] `BoosterSimAppTests/BlockRuleTests.swift` — ten matcher edge cases (dot boundary, case, prefix, disabled, nil-host, trim, empty) — created red-first in plan 03 Task 1

No separate Wave-0 plan: each file is the tests-first (RED) opening move of its own TDD task within plans 01–03. No framework install and no shared fixtures file are needed — Swift Testing is already the in-repo convention, the `BoosterSimAppTests` target exists (CertificateServiceTests precedent), and each suite is self-contained in that style.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Airplane Mode end-to-end on a live Simulator: app request fails `NSURLErrorNotConnectedToInternet` + error row in viewer; viewer/banner stays connected; Mac browser loads; OFF recovers; relaunch re-applies within ~1 s (7 steps) | REQ-roadmap-phase5-network-tools (criterion 4) | Needs a booted iOS Simulator running a DEBUG app embedding BoosterSimConnect; no automated host/device harness exists (RESEARCH marks e2e Connect verification manual; NET-04 is a deferred v2 item) | Follow plan 05-01 Task 3 `<how-to-verify>` steps 1–7; record pass/fail per step in `05-01-SUMMARY.md` |
| Phase-gate smoke, all three tools: airplane three-way proof; 3G visibly slow load; block-rule failure row; relaunch reconcile; certificate generate/install regression; clean state (6 groups) | REQ-roadmap-phase5-network-tools (criteria 3/4/5), REQ-fr-16 (regression) | Same Simulator dependency; also asserts visible wall-clock slowdown and Simulator-keychain certificate install, neither assertable headlessly | Follow plan 05-04 Task 3 `<how-to-verify>` groups 1–6; record pass/fail per group in `05-04-SUMMARY.md` |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies (the two `checkpoint:human-verify` tasks are manual by design and listed in Manual-Only Verifications)
- [x] Sampling continuity: no 3 consecutive tasks without automated verify (longest manual stretch is a single checkpoint task)
- [x] Wave 0 covers all MISSING references (all five ❌ W0 suites are placed in the map with their creating task)
- [x] No watch-mode flags (one-shot `xcodebuild test` invocations only)
- [x] Feedback latency < 240 s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** pending (set by `/gsd-validate-phase`)
