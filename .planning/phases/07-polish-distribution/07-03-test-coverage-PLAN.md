---
phase: 07-polish-distribution
plan: 03
type: execute
wave: 1
depends_on: []
files_modified:
  - BoosterSimApp/Services/WindowEnumerator.swift
  - BoosterSimApp/Views/Onboarding/OnboardingContainerView.swift
  - BoosterSimApp/Views/Onboarding/OnboardingStepView.swift
  - BoosterSimApp/App/AppDelegate.swift
  - BoosterSimAppTests/PositionCalculatorTests.swift
  - BoosterSimAppTests/WindowEnumeratorTests.swift
  - BoosterSimAppTests/AppSettingsTests.swift
  - BoosterSimAppUITests/OnboardingFlowUITests.swift
autonomous: true
requirements:
  - REQ-roadmap-phase7-polish-distribution
estimate:
  tokens: 25000
  raw_tokens: 25000
  tasks: 3
  confidence: low

must_haves:
  truths:
    - "ROADMAP C3 (unit half): PositionCalculatorTests, WindowEnumeratorTests, and AppSettingsTests exist and pass — Swift Testing convention only (import Testing / @Test / #expect, zero XCTest anywhere in BoosterSimAppTests, matching all 24 existing suites), covering the pure frame math, the CGWindowList parse contract, and the persisted-settings contract"
    - "ROADMAP C3 (UI half): OnboardingFlowUITests drives the real 4-step onboarding flow end-to-end in BoosterSimAppUITests — reset-seam launch, step-by-step skip navigation through all four steps, completion persistence verified across relaunch — against accessibilityIdentifier-backed XCUIElement queries (the app currently has zero identifiers; this plan adds the onboarding set)"
    - "The WindowEnumerator seam refactor is behavior-preserving: parseSimulatorWindow becomes internal (testable via @testable import) with enumerateSimulatorWindows() delegating to it unchanged — live window scanning is NOT unit-tested (needs a booted Simulator); the parse contract IS"
    - "No regressions: the full BoosterSimAppTests bundle stays green and no existing suite is modified"
  artifacts:
    - BoosterSimAppTests/PositionCalculatorTests.swift
    - BoosterSimAppTests/WindowEnumeratorTests.swift
    - BoosterSimAppTests/AppSettingsTests.swift
    - BoosterSimAppUITests/OnboardingFlowUITests.swift
  key_links:
    - "PositionCalculator.panelFrame / rightFrame / leftFrame / bottomFrame / dynamicFrame / centeredY clamps ↔ PositionCalculatorTests assertions — pure math, no AppKit windows needed"
    - "CGWindowList dictionary shape (kCGWindowOwnerName/Layer/Number/OwnerPID/Bounds/Name) ↔ WindowEnumeratorTests synthetic fixtures — the Quartz→AppKit Y flip, owner/layer/size filters"
    - "AppSettings init(defaults:) injectable suite ↔ AppSettingsTests round-trips — the capture-key persistence contract (keys are final persistence names)"
    - "'-uitest-reset-onboarding' launch argument → AppDelegate completedOnboarding reset → OnboardingFlowUITests deterministic first-launch state"
  prohibitions:
    - requirement_id: REQ-roadmap-phase7-polish-distribution
      category: regression
      status: unverified
      flagged: true
      verification: automated
      statement: "MUST NOT introduce XCTest into BoosterSimAppTests (Swift Testing only), MUST NOT weaken or delete any existing suite to make room, and MUST NOT leave test-host side effects — the UI test must not leave launch-at-login registered or pollute standard UserDefaults beyond its own reset key"
  flagged_assumptions:
    - "The pre-existing post-test 'Early unexpected exit' exit-65 flake (STATE.md, reproduced on pristine HEAD) may also hit the new onboarding UI test — acceptance judges the per-test summary (all tests passed), allows one re-run, and records the flake if it fires"
    - "NSScreen.main exists in the test host (it does on this Mac and on macos-26 CI runners) so the Quartz→AppKit flip expectation can be computed against the live primary height"
---

<objective>
Close ROADMAP C3's coverage gap for the three pre-.planning Phase-1 types that predate the test convention, and the 4-step onboarding flow — the exact surfaces the ROADMAP names.

Task 1: PositionCalculatorTests — the purest contract in the codebase (all four position modes, clamps, floors), green immediately. Task 2: WindowEnumeratorTests behind a minimal internal-seam refactor (parse function becomes internal; the enumerator delegates unchanged) plus AppSettingsTests over the already-injectable defaults suite. Task 3: onboarding UI tests — add the app's first accessibilityIdentifiers to the two onboarding views, a '-uitest-reset-onboarding' launch-argument reset seam in AppDelegate, and the XCUIApplication flow test.

Purpose: the three unit suites are straightforwardly auto-executable; the UI suite is deterministic because every step is skippable without granting permissions.
Output: three new unit suites + one UI suite, all green, zero existing-suite churn.
</objective>

<execution_context>
@~/.claude/gsd-core/workflows/execute-plan.md
@~/.claude/gsd-core/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/ROADMAP.md
@.planning/STATE.md
@.planning/phases/07-polish-distribution/07-CONTEXT.md
@.planning/phases/07-polish-distribution/07-RESEARCH.md
@.planning/phases/07-polish-distribution/07-PATTERNS.md
@BoosterSimApp/Windows/PositionCalculator.swift
@BoosterSimApp/Services/WindowEnumerator.swift
@BoosterSimApp/Models/AppSettings.swift
@BoosterSimApp/Views/Onboarding/OnboardingContainerView.swift
@BoosterSimApp/Views/Onboarding/OnboardingStepView.swift
@BoosterSimApp/App/AppDelegate.swift
@BoosterSimAppTests/AppActionCatalogTests.swift
</context>

<tasks>

<task type="auto">
  <name>Task 1: PositionCalculatorTests — the pure frame-math contract</name>
  <files>BoosterSimAppTests/PositionCalculatorTests.swift</files>
  <read_first>
    - BoosterSimApp/Windows/PositionCalculator.swift in full (90 LOC) — panelFrame's parameter contract, the four position helpers, centeredY clamping, bottomFrame's fixed 200pt, dynamicFrame's right→left→right preference
    - BoosterSimAppTests/AppActionCatalogTests.swift:1-30 — the Swift Testing house convention to match exactly (import Testing, struct, @Test func, #expect)
    - BoosterSimApp/Utilities/DesignTokens.swift — SideWindowMetrics constants the assertions should reference (collapsedWidth 28 / expandedWidth 260 / minHeight 400), not hardcode
  </read_first>
  <action>
    New suite (import Testing, @testable import BoosterSimApp) asserting panelFrame behavior with synthetic CGRects — a fixed screen (e.g. 0,0,1920,1080) and simulator frames placed mid-screen / at each screen edge:
    - right: panel's minX == sim.maxX when it fits; width collapses to SideWindowMetrics.collapsedWidth when isCollapsed; height floors at minHeight when contentHeight is smaller, and follows contentHeight above it;
    - left: minX == sim.minX - width; clamped to screen.minX when the simulator hugs the left edge;
    - right-edge clamp: when sim.maxX + width would overflow the screen, x clamps to screen.maxX - width;
    - bottom: fixed 200pt height, width == sim.width, y == sim.minY - 200 clamped to screen.minY;
    - dynamic: prefers right when rightSpace >= width; falls back left when only left fits; falls back right (possibly overlapping) when neither fits;
    - centeredY: vertical centering on sim.midY, clamped top and bottom to the screen;
    - exactCGRect equality on representative cases (not just field spot-checks) plus boundary cases (sim exactly filling the space).
    Do NOT test screen(containing:) — it reads live NSScreen state; note the exclusion in a comment.
  </action>
  <verify>
    <automated>xcodebuild -project BoosterSimApp.xcodeproj -scheme BoosterSimApp -destination 'platform=macOS' test -only-testing:BoosterSimAppTests/PositionCalculatorTests -parallel-testing-enabled NO 2>&1 | tail -5</automated>
    <fails_when>the targeted run reports any failed test or a non-passing suite summary</fails_when>
  </verify>
  <behavior>
    - panelFrame(.right) on a mid-screen sim returns x == sim.maxX, expanded width 260
    - isCollapsed switches width to 28 across all side positions
    - height = max(contentHeight, 400) both below and above the floor
    - left/right screen-edge clamps engage exactly at the boundary
    - .bottom ignores isCollapsed (fixed 200 × sim.width, y-clamped)
    - .dynamic resolves right → left → right in the three space regimes
  </behavior>
  <done>PositionCalculatorTests green on first run; all assertions reference DesignTokens constants; zero XCTest tokens in the file.</done>
</task>

<task type="auto">
  <name>Task 2: WindowEnumeratorTests (internal seam) + AppSettingsTests (injected suite)</name>
  <files>
    BoosterSimApp/Services/WindowEnumerator.swift,
    BoosterSimAppTests/WindowEnumeratorTests.swift,
    BoosterSimAppTests/AppSettingsTests.swift
  </files>
  <read_first>
    - BoosterSimApp/Services/WindowEnumerator.swift in full (65 LOC) — parseSimulatorWindow's filter chain (owner name == "Simulator", layer == 0, required windowID+pid, bounds dictionary, >50pt size gate) and the Quartz→AppKit Y flip against NSScreen.main height
    - BoosterSimApp/Models/AppSettings.swift — init(defaults:) wraps EVERY capture @AppStorage in the injected store (:88-103) but position/showSideWindow/launchAtLogin/xcodePath bind .standard; CaptureStorageKey.customFolderPath; customCaptureFolder's set/nil semantics; setLaunchAtLogin's SMAppService side effect
  </read_first>
  <action>
    WindowEnumerator seam (behavior-preserving): drop `private` from parseSimulatorWindow(from:) — internal is enough for @testable import; enumerateSimulatorWindows() body unchanged (still the sole caller after the CGWindowList fetch). No signature, logic, or call-site changes.

    WindowEnumeratorTests — synthetic CGWindowList-shaped dictionaries through parseSimulatorWindow:
    - accept path: owner "Simulator", layer 0, valid id/pid, 800×600 bounds at (100, 50) → SimulatorWindow with frame.y == (NSScreen.main?.frame.height ?? 0) - 50 - 600 (the flip, computed against the same live primary height — deterministic on this Mac and CI);
    - rejects: owner ≠ "Simulator"; layer ≠ 0; missing kCGWindowNumber; missing kCGWindowOwnerPID; missing bounds dict;
    - size gate: exactly 50×50 rejected (strictly-greater contract), 51×51 accepted;
    - deviceName: nil without kCGWindowName (the no-Screen-Recording degradation) passes through as nil.
    AppSettingsTests — UserDefaults(suiteName:) isolated suite, removed in teardown (addSuite discipline; no .standard pollution):
    - fresh-suite defaults: captureDestination == .desktop, captureExportFormat == .mp4, captureGIFSize == 480, captureGIFFps == 10, captureShowTouchIndicators == false;
    - write-then-read round-trips through the injected suite for each capture key;
    - customCaptureFolder: nil on fresh suite, set(path) → getter returns URL(fileURLWithPath:), set(nil) → nil again (the removeObject branch);
    - pure data contracts: SideWindowPosition / CaptureExportFormat / CaptureDestinationKind — allCases non-empty, raw values stable strings, label/icon non-empty (raw values are final persistence keys).
    Do NOT call setLaunchAtLogin — it mutates .standard AND drives SMAppService.mainApp on the test host (would register a real login item); note the exclusion in a comment.
  </action>
  <verify>
    <automated>xcodebuild -project BoosterSimApp.xcodeproj -scheme BoosterSimApp -destination 'platform=macOS' test -only-testing:BoosterSimAppTests/WindowEnumeratorTests -only-testing:BoosterSimAppTests/AppSettingsTests -parallel-testing-enabled NO 2>&1 | tail -5 && ! grep -rl 'import XCTest' BoosterSimAppTests/ | grep -v .build</automated>
    <fails_when>either suite reports a failure, or any file under BoosterSimAppTests/ now imports XCTest</fails_when>
  </verify>
  <behavior>
    - parseSimulatorWindow: valid dict → SimulatorWindow with flipped Y; each rejection rule returns nil individually
    - 50×50 boundary rejected, 51×51 accepted
    - AppSettings fresh-suite defaults exact; round-trips per key; customCaptureFolder set/get/nil cycle
    - Enum raw values/labels stable
  </behavior>
  <done>Both suites green; the seam diff touches only the `private` keyword; no XCTest anywhere under BoosterSimAppTests/.</done>
</task>

<task type="auto">
  <name>Task 3: Onboarding accessibilityIdentifiers + reset seam + OnboardingFlowUITests</name>
  <files>
    BoosterSimApp/Views/Onboarding/OnboardingContainerView.swift,
    BoosterSimApp/Views/Onboarding/OnboardingStepView.swift,
    BoosterSimApp/App/AppDelegate.swift,
    BoosterSimAppUITests/OnboardingFlowUITests.swift
  </files>
  <read_first>
    - BoosterSimApp/Views/Onboarding/OnboardingContainerView.swift in full — the 4 TabView steps (Accessibility → Select Xcode → Screen Recording → DerivedData), advance()/finishOnboarding(), the "Step N of 4" caption, @AppStorage("completedOnboarding")
    - BoosterSimApp/Views/Onboarding/OnboardingStepView.swift — the per-step template: AccentButton CTA (ctaTitle) and "Skip for now" button (:63) — the two controls the test drives
    - BoosterSimApp/App/AppDelegate.swift:69-110 — applicationDidFinishLaunching's completedOnboarding branch and openOnboardingWindow() — where the reset seam goes
    - BoosterSimAppUITests/ScreenshotTests.swift — the existing XCUIApplication precedent in this target
    - .planning/STATE.md Blockers — the documented post-test exit-65 flake and the -parallel-testing-enabled NO discipline
  </read_first>
  <action>
    Identifiers (the app's first — additive modifiers only, zero visual/behavior change):
    - OnboardingContainerView: .accessibilityIdentifier("onboarding.root") on the outer VStack, "onboarding.stepIndicator" on the "Step N of 4" Text;
    - OnboardingStepView: "onboarding.stepTitle" on the title Text, "onboarding.cta" on the AccentButton, "onboarding.skip" on the Skip button.
    Reset seam in AppDelegate.applicationDidFinishLaunching, placed BEFORE the completedOnboarding branch: if ProcessInfo.processInfo.arguments.contains("-uitest-reset-onboarding") { UserDefaults.standard.set(false, forKey: "completedOnboarding") } — one line of test scaffolding, commented as such (matches the app's existing @AppStorage key; XCUIApplication passes it via launchArguments).
    OnboardingFlowUITests (Swift Testing if the UI-test target's existing files use it — read BoosterSimAppUITests.swift first and match its framework; the unit-target convention is Testing, but follow what THIS target actually uses):
    - launch with ["-uitest-reset-onboarding"]; assert the onboarding window appears and "onboarding.stepTitle" shows "Accessibility Access" with indicator "Step 1 of 4";
    - tap "onboarding.skip" → title becomes "Select Xcode", indicator "Step 2 of 4"; skip → "Screen Recording" / "Step 3 of 4"; skip → "DerivedData Access" / "Step 4 of 4"; final skip → finishOnboarding (window closes);
    - relaunch WITHOUT the reset argument → onboarding does NOT appear (completion persisted).
    Keep queries identifier-based (never label-string-based except the title assertions, which read displayed text intentionally).
  </action>
  <verify>
    <automated>grep -q 'onboarding.root' BoosterSimApp/Views/Onboarding/OnboardingContainerView.swift && grep -q 'onboarding.skip' BoosterSimApp/Views/Onboarding/OnboardingStepView.swift && grep -q 'uitest-reset-onboarding' BoosterSimApp/App/AppDelegate.swift && xcodebuild -project BoosterSimApp.xcodeproj -scheme BoosterSimApp -destination 'platform=macOS' test -only-testing:BoosterSimAppUITests/OnboardingFlowUITests -parallel-testing-enabled NO 2>&1 | tail -8</automated>
    <fails_when>identifier/seam greps fail, or the UI run's per-test summary shows a failed test — the documented post-test exit-65 relaunch flake is NOT a failure if the test summary itself is all-pass (re-run once and record per the flagged assumption)</fails_when>
  </verify>
  <behavior>
    - Reset launch: onboarding always appears regardless of prior state
    - Four skips walk Step 1→4 with correct titles/indicators; final skip completes and closes the window
    - Relaunch without reset: no onboarding
    - Zero side effects beyond completedOnboarding
  </behavior>
  <done>All three ROADMAP-named unit suites plus the onboarding UI suite exist and pass; the app gained its first accessibilityIdentifiers and a documented reset seam; no existing suite touched.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| Test host ↔ user session | Unit/UI tests run inside the real app process on this Mac — they must not leave session state behind (login items, standard defaults) |
| Synthetic fixtures ↔ live system | WindowEnumerator tests feed synthetic dictionaries, never the live window list (no Screen Recording dependency, deterministic) |

## STRIDE Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation Plan |
|-----------|----------|-----------|----------|-------------|-----------------|
| T-07-08 | Tampering (side effect) | setLaunchAtLogin via tests | medium | mitigate | Explicitly excluded from AppSettingsTests (SMAppService would register a real login item); prohibition names it |
| T-07-09 | Denial of service | UI-test runner flake (exit 65) | low | accept | Pre-existing, documented on pristine HEAD (STATE.md); acceptance judges the per-test summary, allows one re-run, records occurrences |
| T-07-10 | Tampering (coverage illusion) | seam refactor | low | mitigate | parseSimulatorWindow diff limited to dropping `private`; enumerateSimulatorWindows behavior unchanged and both callers unchanged — verified by grep-diff discipline in review |
</threat_model>

<verification>
- Task 1: PositionCalculatorTests targeted run green
- Task 2: WindowEnumeratorTests + AppSettingsTests green; no XCTest imports under BoosterSimAppTests/
- Task 3: identifier/seam greps + OnboardingFlowUITests green (flake allowance per flagged assumption)
- Bundle health: full BoosterSimAppTests bundle still green at plan end (run once after Task 3)
</verification>

<success_criteria>
- ROADMAP C3 TRUE: unit coverage for PositionCalculator / WindowEnumerator / AppSettings + UI coverage of the 4-step onboarding flow, all in the house Swift Testing convention
- Zero existing-suite modifications; zero test-host side effects
</success_criteria>

<output>
Create `.planning/phases/07-polish-distribution/07-03-test-coverage-SUMMARY.md` when done
</output>
