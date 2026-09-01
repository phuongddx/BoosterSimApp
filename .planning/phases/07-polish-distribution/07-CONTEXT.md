# Phase 7: Polish & Distribution - Context

**Gathered:** 2026-09-01
**Status:** Ready for planning
**Mode:** Autonomous (gsd-autonomous), grey areas resolved via targeted user questions

<domain>
## Phase Boundary

The app is distributable — signed, notarized, updatable, tested, and store-ready — per ROADMAP.md Phase 7 (5 success criteria, the 5th added 2026-09-01 to close the confirmed Phase 6 wiring gap):

1. App is code-signed and notarized (archive → notarytool → stapler → DMG); non-sandbox requirement documented
2. Auto-update works (Sparkle)
3. Unit tests cover PositionCalculator, WindowEnumerator, AppSettings; UI tests cover onboarding
4. Privacy manifest, app icon, README/marketing polish complete
5. User can reach Status Bar overrides, Build Stats, AX Tree Inspector, and Camera routing from the side panel (Phase 6 views instantiated but never wired into the tab switch)

**Depends on:** Phase 2, 3, 4, 5 — all complete as of 2026-09-01.

</domain>

<decisions>
## Implementation Decisions

### Locked by user (this session, 2026-09-01)

1. **Auto-update: Add Sparkle.** Mac App Store distribution is already Out of Scope (REQUIREMENTS.md: "Sandboxed (Mac App Store) distribution — Sandbox incompatible with AXIsProcessTrusted/CGWindowList/AXObserver/simctl usage"), so Sparkle is the only realistic auto-update path. This is a **new SPM dependency** and needs the same explicit Apple-frameworks-only policy exception Pulse/PulseProxy received in Phase 5 (PROJECT.md Constraints: "Apple frameworks only — exception: Pulse/PulseProxy via BoosterSimConnect"). Planner/executor must add Sparkle as a second named exception (not silently expand the policy), generate an EdDSA signing keypair, and choose appcast hosting (GitHub Releases/Pages is the natural fit given the repo already lives on GitHub — planner's call on exact mechanism).

2. **App icon: agent-generated draft was the intent, but the image-generation tool failed** (`Image generation failed for all credentialed providers: openrouter` — reproduced across 3 attempts with different providers/prompts, a backend/credential issue in this session, not a retryable prompt problem). **Known gap, not silently dropped**: `BoosterSimApp/Assets.xcassets/AppIcon.appiconset/` exists with only `Contents.json` (10 declared sizes, zero actual image files). Planner must either (a) retry image generation at plan/execute time if the tool has recovered, (b) surface this as a blocking-human checkpoint asking the user to supply icon art, or (c) ship a placeholder (e.g. a single SF Symbol composited onto the amber accent per docs/design-guidelines.md) explicitly labeled as a placeholder pending real design — never claim a real icon exists if it doesn't.

3. **Phase 6 wiring placement: NOT pre-decided — planner researches and proposes.** Critical constraint: **REQ-fr-13 is a locked, already-verified requirement — "Side panel exposes exactly four tabs (Capture, Design, Actions, Network) with icon-only tab bar."** A 5th tab is NOT an option; it would regress a shipped, verified requirement. StatusBarSectionView, BuildStatsSectionView, AXTreeView, CameraView (all built in Phase 6, confirmed zero call sites outside `#Preview` — see STATE.md `[Phase 6][resolved 2026-09-01]` and `.planning/phases/04-design-tools/04-VERIFICATION.md`'s sibling finding) must be integrated as sections/rows *within* one of the four existing tabs. Research should evaluate fit against each tab's existing section conventions (AppActionCatalog's section-table pattern in Actions tab is the most directly reusable precedent — see `.planning/phases/03-app-actions/03-*` for the pattern) before proposing a mapping in the PLAN for user review — do not silently pick one without surfacing the reasoning.

### Already locked by prior phases (do not re-litigate)

- Non-sandboxed runtime (ENABLE_APP_SANDBOX = NO) — required for Accessibility API, CGWindowList, simctl control (PROJECT.md Constraints). Signing/notarization must accommodate this — notarization does NOT require sandboxing, only Developer ID + hardened runtime + stapling.
- `DEVELOPMENT_TEAM = EQ8B89SPCX` with `CODE_SIGN_STYLE = Automatic` is already configured in `BoosterSimApp.xcodeproj/project.pbxproj` — a real Apple Developer Program membership exists. Signing/notarization is feasible without acquiring new credentials; confirm Developer ID Application certificate (not just automatic Development signing) is available for the archive → notarize → staple flow.
- 4pt spacing grid, CornerRadius enum, SF Pro/SF Symbols exclusively, amber accent (#E8720C light / #F59E0B dark) via named `AccentColor` asset — apply to any new UI (e.g. wired-in Phase 6 sections) per docs/design-guidelines.md.
- Files < 200 LOC; all `xcrun simctl` through SimCtlService with UDID; AppLogger with sensitive-data redaction; `try!`/`as!` on user data prohibited (docs/code-standards.md, .planning/intel/context.md).

</decisions>

<code_context>
## Existing Code Insights

- `BoosterSimApp/Models/AppSettings.swift`, `BoosterSimApp/Windows/PositionCalculator.swift`, `BoosterSimApp/Services/WindowEnumerator.swift` all exist on disk — the three types ROADMAP names for unit test coverage are real, not aspirational.
- `docs/system-architecture.md` carries full architecture sections for Capture Tools, App Actions, Network Tools (Phase 5), Design Tools (Phase 4) — Phase 7's docs work (README/marketing polish) can draw on these rather than re-discovering architecture.
- `BoosterSimAppUITests/` exists (per repo structure in the top-level AGENTS.md) — onboarding UI test coverage extends an existing target, not a new one.
- Package.resolved is untracked in git (known infra gap, STATE.md blocker) — adding Sparkle as a new dependency is a good forcing function to also track this file, closing the long-open "track the file" recommendation from Phase 2/3/4/5 gate closures.
- No `docs/privacy-manifest` or `PrivacyInfo.xcprivacy` file found in a preliminary check — privacy manifest is genuinely new work, not a refresh. Must enumerate actual "required reason" API usage: Accessibility API (AXIsProcessTrusted), ScreenCaptureKit, file timestamp APIs if used, UserDefaults (Actions tab defaults editor) — research should grep for Apple's required-reason API categories against the real codebase, not assume a generic template.

</code_context>

<specifics>
## Specific Ideas

- Sparkle appcast: given the repo is on GitHub, GitHub Releases + a static appcast.xml hosted via GitHub Pages or committed to the repo is the standard, zero-infra-cost pattern — planner should evaluate this as the default unless a reason emerges not to.
- Icon retry: attempt `generate_image` again at plan or execute time before falling back to a placeholder/checkpoint — the failure observed here may be transient.

</specifics>

<deferred>
## Deferred Ideas

None new this phase — prior deferred items (throttle pacing rescale, photoreal bezels, SimulatorWindowTracker seam migration, Pulse Code 8/PulseMetrics/e2e Connect test) remain tracked in STATE.md Deferred Items and are out of Phase 7 scope.

</deferred>
