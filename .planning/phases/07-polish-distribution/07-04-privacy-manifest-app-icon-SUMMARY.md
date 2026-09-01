---
phase: 07-polish-distribution
plan: 04
subsystem: distribution
tags: [privacy-manifest, xcprivacy, app-icon, sf-symbols, appkit, asset-catalog, required-reason-api]

requires:
  - phase: 05-network-manipulation
    provides: synchronized file group (new app-folder files auto-include as resources, no project edits)
provides:
  - PrivacyInfo.xcprivacy shipped inside the built app bundle (evidence-accurate required-reason declarations)
  - Complete 10-size AppIcon set (amber #E8720C + white bolt.fill PLACEHOLDER pending real design)
  - Committed reproducible icon generator scripts/generate-placeholder-icon.swift
affects: [07-05-signing-notarization, 07-06-readme-phase-gate]

actuals:
  tokens: 4000   # chars/4 over text files actually changed (manifest + script + Contents.json + planning docs); binaries excluded
  tasks: 2
  commits: 3

tech-stack:
  added: []
  patterns:
    - "Evidence-first privacy manifest: re-grep required-reason API usage at write time, verify reason codes against Apple's live docs, never template-copy"

key-files:
  created:
    - BoosterSimApp/PrivacyInfo.xcprivacy
    - scripts/generate-placeholder-icon.swift
  modified:
    - BoosterSimApp/Assets.xcassets/AppIcon.appiconset/Contents.json

key-decisions:
  - "UserDefaults reason corrected to CA92.1 — Apple's live docs show 1C8F.1 is the App-Group code; 07-RESEARCH §3 had CA92.1/1C8F.1 inverted"
  - "FileTimestamp category added with C617.1 + 3B52.1 — re-grep found 3 real contentModificationDate/modificationDate call sites research missed"
  - "Icon shipped via Path B (scripted PLACEHOLDER): generate_image device not mounted; Path A attempted and unavailable, no retry loops"
  - "Full-bleed opaque icon art instead of bezier pre-rounding — system squircle mask delivers the true continuous-look radius the plan described"

patterns-established:
  - "Headless SF Symbol compositing: template symbols ignore context fill color; recolor via transparent layer + .sourceIn fill, then composite"

requirements-completed:
  - REQ-roadmap-phase7-polish-distribution

coverage:
  - id: D1
    description: "PrivacyInfo.xcprivacy with evidence-accurate required-reason declarations, shipped in the built app bundle's Resources"
    requirement: REQ-roadmap-phase7-polish-distribution
    verification:
      - kind: other
        ref: "plutil -lint + plistlib structural assert + xcodebuild Debug build + bundle Resources presence check (all run, all pass)"
        status: pass
    human_judgment: false
  - id: D2
    description: "10-size AppIcon set (amber + white bolt) — PLACEHOLDER pending real design, never to be claimed as finished art"
    requirement: REQ-roadmap-phase7-polish-distribution
    verification:
      - kind: other
        ref: "sips pixel-width loop over 10 declared sizes + Contents.json 10-filename assert + Debug build green, no actool warnings (all run, all pass)"
        status: pass
    human_judgment: false

duration: 12min
completed: 2026-09-01
status: complete
---

# Phase 7 Plan 4: Privacy Manifest & App Icon Summary

**PrivacyInfo.xcprivacy shipped in-bundle with two grep-evidenced required-reason categories (UserDefaults/CA92.1 + FileTimestamp/C617.1+3B52.1), plus a complete 10-size AppIcon set rendered by a committed script as an explicitly labeled PLACEHOLDER (amber #E8720C + white bolt.fill) after image generation was unavailable.**

## Performance

- **Duration:** ~12 min
- **Started:** 2026-09-01T04:39:00Z
- **Completed:** 2026-09-01T04:51:00Z
- **Tasks:** 2
- **Files modified:** 13 (1 manifest, 1 script, 1 Contents.json, 10 PNGs)

## Which Icon Path Shipped: PATH B — PLACEHOLDER

**The shipped icon is a PLACEHOLDER pending real design — not finished art.** Path A (session image generation) was attempted once and was **unavailable**: the `generate_image` device is not mounted in this executor session, consistent with the 3 prior backend/credential failures recorded in 07-CONTEXT decision 2. Per the plan, no retry loops — fell straight through to Path B. The README note for the placeholder happens at the phase gate (07-06).

## Accomplishments

- `BoosterSimApp/PrivacyInfo.xcprivacy` — lint-clean, ships in the built bundle's Resources via the synchronized file group, with `NSPrivacyTracking=false`, empty tracking domains and collected-data types
- Complete 10-size AppIcon set: all 10 declared pixel sizes (16→1024) exist at exact dimensions with Contents.json filename entries — the app previously shipped zero icon images
- `scripts/generate-placeholder-icon.swift` — committed, deterministic, offline generator (headless AppKit `NSBitmapImageRep`/`NSGraphicsContext`, no window server)

## Task Commits

1. **Task 1: PrivacyInfo.xcprivacy — evidence-accurate required-reason entries, verified into the bundle** — `3bfed8f` (feat)
2. **Task 2: App icon — Path B scripted placeholder at all 10 sizes** — `2c42532` (feat)

**Plan metadata:** see final commit below.

## Files Created/Modified

- `BoosterSimApp/PrivacyInfo.xcprivacy` — created. Privacy manifest: no tracking, no collected data, two accessed-API declarations (see Deviations for the evidence)
- `scripts/generate-placeholder-icon.swift` — created. Offscreen renderer: full-bleed amber canvas, centered white `bolt.fill` at 55% layout-box scale, per-size renders with an amber+white pixel self-check that fails loudly
- `BoosterSimApp/Assets.xcassets/AppIcon.appiconset/Contents.json` — modified. 10 filename entries wired
- `BoosterSimApp/Assets.xcassets/AppIcon.appiconset/icon-{16,32,64,128,256,512,1024}*.png` — created. 10 PNGs, exact pixel dimensions

## Decisions Made

- **UserDefaults reason `CA92.1`, not the plan's `1C8F.1`.** Apple's live documentation (fetched 2026-09-01) defines `1C8F.1` as "information that is only accessible to the apps … that are **members of the same App Group**" and `CA92.1` as "information that is only accessible to **the app itself**". 07-RESEARCH §3 inverted these two codes. This app has no App Group (non-sandboxed, no entitlements file) → `CA92.1` is the accurate code; shipping `1C8F.1` would falsely assert App Group membership.
- **FileTimestamp category added (not in the plan).** The plan's mandated re-grep ("expect zero app-code hits") instead found three real API call sites on Apple's required-reason FileTimestamp list: `CaptureExporter.swift:299` (`.contentModificationDateKey` on the app's own temp capture files → `C617.1`), `BuildStatsService.swift:52` (`.contentModificationDateKey` on DerivedData build manifests, cache-invalidation only → `3B52.1` closest approved code), `DerivedDataAppScanner.swift:75` (`attributesOfItem()[.modificationDate]` on DerivedData app bundles, newest-first ordering, never displayed → `3B52.1`). Research's "zero matches" claim only held for its narrower literal pattern (`creationDate|contentModificationDate|getattrlist|systemUptime|statfs` — which itself did hit, twice). Following the plan's own rule — "adjust the entry to match reality — never ship a stale declaration."
- **Icon geometry: full-bleed opaque art, not pre-rounded.** The plan pairs "rounded-square … continuous-look corner radius ≈ 22.5%" with "opaque … PNG" — bezier pre-rounding can't deliver either (circular arcs ≠ continuous curvature, and rounded corners force non-opaque alpha). macOS applies its own continuous-curvature squircle mask (~22.5% effective) to full-bleed AppIcon art at display time, which satisfies both phrases; this is also Apple's current macOS icon guidance.
- **Template-symbol tinting via `.sourceIn` layer.** `NSImage(systemSymbolName:)` renders black ink regardless of context fill color in bitmap contexts; the script draws the symbol into a transparent layer, recolors with a white `.sourceIn` fill (alpha survives), then composites onto the amber canvas. Verified empirically (diagnostic render showed `r=0,g=0,b=0` bolt pixels before the fix).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] UserDefaults reason code was inverted in plan/research**
- **Found during:** Task 1 (evidence re-grep + doc verification)
- **Issue:** Plan pinned `1C8F.1` citing "no App Group" — but Apple's live docs define `1C8F.1` as the App-Group reason; `CA92.1` is the app-only reason. Shipping the plan's code would be a false declaration.
- **Fix:** Declared `CA92.1`. Verified against `developer.apple.com` (fetched at execution time via sosumi + direct URL read).
- **Files modified:** BoosterSimApp/PrivacyInfo.xcprivacy
- **Verification:** plistlib structural assert (`== ['CA92.1']`) passed; plutil lint OK
- **Committed in:** 3bfed8f

**2. [Rule 1 - Bug] FileTimestamp category omitted despite real API usage**
- **Found during:** Task 1 (plan-mandated evidence re-grep: "expect zero app-code hits" — got 3 real hits)
- **Issue:** `contentModificationDateKey` (CaptureExporter:299, BuildStatsService:52) and `FileAttributeKey.modificationDate` (DerivedDataAppScanner:75) are all on Apple's required-reason FileTimestamp API list. A manifest declaring only UserDefaults would not "match the code's actual required-reason usage" (the plan's own truth bar, T-07-11).
- **Fix:** Added `NSPrivacyAccessedAPICategoryFileTimestamp` with `C617.1` (app's own temp files) + `3B52.1` (user's DerivedData trees). Note: Apple's two-code vocabulary has no exact code for a non-sandboxed developer tool reading the user's own developer directories — `3B52.1` ("files … the user … granted access to") is the closest approved code; choice documented here.
- **Files modified:** BoosterSimApp/PrivacyInfo.xcprivacy
- **Verification:** structural assert (2 categories, exact codes) passed; build green; manifest present in bundle
- **Committed in:** 3bfed8f

**3. [Rule 1 - Bug] Script API friction on this SDK (Task 2, Path B)**
- **Found during:** Task 2 (script bring-up)
- **Issue:** `NSBitmapImageRep` init has no `colorSpace:` label / `NSColorSpaceName.sRGB` / settable `colorSpace` on this SDK; template SF Symbols ignore `NSColor.set()` tinting in bitmap contexts (rendered black).
- **Fix:** `NSColorSpaceName.deviceRGB` rep with sRGB-authored colors (`NSColor(srgbRed:)` — stored components are the exact sRGB values; PNG carries no ICC tag, noted in-script); two-layer `.sourceIn` white recolor for the symbol. In-script pixel self-check (amber + white must both be present at every size, else non-zero exit) guards against silent render failure.
- **Files modified:** scripts/generate-placeholder-icon.swift
- **Verification:** script exits 0 with all 10 self-checked renders; ASCII pixel-map at 16px shows a centered bolt; bbox analysis at 1024/256px shows dead-center bolt at ≈47% canvas ink height (55% layout box × ~85% glyph ink)
- **Committed in:** 2c42532

---

**Total deviations:** 3 auto-fixed (3 × Rule 1 bug)
**Impact on plan:** All three are accuracy corrections squarely inside the plan's own truth-over-template mandate ("never ship a stale declaration"; T-07-11). No scope creep — no categories beyond grep evidence, no extra icon sizes.

## Verification Results (plan-level, re-run)

- Task 1: `plutil -lint` OK · structural assert exact (2 categories: UserDefaults/CA92.1, FileTimestamp/C617.1+3B52.1) · Debug build SUCCEEDED · `build/privacy-check/.../BoosterSimApp.app/Contents/Resources/PrivacyInfo.xcprivacy` present
- Task 2: 10/10 PNGs exist at exact pixel widths (16,32,32,64,128,256,256,512,512,1024) · Contents.json carries 10 filename entries · Debug build SUCCEEDED · no actool/asset-catalog warnings
- Icon geometry spot-checks: bolt centered (0.499, 0.500 at 1024px), amber exact (232,114,12) covering 97%+ of canvas, white bolt ink present at every size

## Known Stubs

- **The AppIcon set is a PLACEHOLDER pending real design** — `BoosterSimApp/Assets.xcassets/AppIcon.appiconset/icon-*.png` (all 10), rendered by `scripts/generate-placeholder-icon.swift`. Intentional per 07-CONTEXT decision 2(c): image generation was unavailable (device not mounted; 3 prior session failures with the same backend error). The icon language (amber #E8720C + bolt.fill) matches docs/design-guidelines.md's menu-bar identity, but this is NOT finished art. The phase-gate README update (07-06) must carry the same label.

## Issues Encountered

- `generate_image` unavailable in this executor session (device not mounted) — treated as the plan's Path-A failure mode; Path B executed per plan. Not an error condition.

## Scope Honesty (07-CONTEXT decision 5)

The privacy manifest is a transparency/best-practice artifact. The acceptance bar met here is "file exists and is accurate" — its entries match the code's actual required-reason usage re-grepped at execution time. This distribution path (Developer ID + notarization; MAS out of scope) never triggers App Store Connect's privacy review.

## User Setup Required

None.

## Next Phase Readiness

- Manifest and icon (the asset half of ROADMAP C4) are done; signing/notarization (07-05's domain) and README/marketing polish (07-06) can proceed. The icon's placeholder status must be reflected in the README at the phase gate, and replaced with real art when design resources exist.

## Self-Check: PASSED

- BoosterSimApp/PrivacyInfo.xcprivacy — FOUND
- scripts/generate-placeholder-icon.swift — FOUND
- BoosterSimApp/Assets.xcassets/AppIcon.appiconset/Contents.json — FOUND
- 10 icon PNGs — FOUND (all)
- Commits 3bfed8f, 2c42532 — FOUND in git log

---
*Phase: 07-polish-distribution*
*Completed: 2026-09-01*
