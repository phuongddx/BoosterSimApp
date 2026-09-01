---
phase: 07-polish-distribution
plan: 04
type: execute
wave: 1
depends_on: []
files_modified:
  - BoosterSimApp/PrivacyInfo.xcprivacy
  - BoosterSimApp/Assets.xcassets/AppIcon.appiconset/Contents.json
  - scripts/generate-placeholder-icon.swift
autonomous: true
requirements:
  - REQ-roadmap-phase7-polish-distribution
estimate:
  tokens: 18000
  raw_tokens: 18000
  tasks: 2
  confidence: low

must_haves:
  truths:
    - "ROADMAP C4 (manifest half): BoosterSimApp/PrivacyInfo.xcprivacy exists with exactly one required-reason declaration — NSPrivacyAccessedAPICategoryUserDefaults, reason 1C8F.1 (the grep-verified correct code: this app has no App Group and no CMS, 07-RESEARCH §3) — and the file lands in the built app bundle's Resources via the project's synchronized file groups"
    - "ROADMAP C4 (icon half): all 10 declared AppIcon sizes exist as real PNGs at exact pixel dimensions (16/32/64/128/256/512/1024) with Contents.json filename entries — EITHER freshly generated artwork (if the image tool recovered) OR the explicit placeholder (SF Symbol bolt composited on the amber accent, rendered by a committed script), and the SUMMARY + phase docs state plainly which one shipped"
    - "ROADMAP C4 (scope honesty): the privacy manifest is shipped as a transparency/best-practice artifact per 07-CONTEXT decision 5 (D-5) — the acceptance bar is 'file exists and is accurate' (its single entry matches the code's actual required-reason usage, re-grepped at execution time), never 'passed an App Store review' that this distribution path never triggers"
  artifacts:
    - BoosterSimApp/PrivacyInfo.xcprivacy
    - BoosterSimApp/Assets.xcassets/AppIcon.appiconset/ (10 PNGs + updated Contents.json)
    - scripts/generate-placeholder-icon.swift
  key_links:
    - "PrivacyInfo.xcprivacy (repo root of the app folder) → synchronized file group → built app bundle Resources/PrivacyInfo.xcprivacy — the placement Xcode's manifest tooling reads"
    - "AppIcon.appiconset Contents.json filename entries ↔ 10 real PNG files at matching pixel sizes — the asset catalog link that makes the app show ANY icon at all (today it has zero images)"
  prohibitions:
    - requirement_id: REQ-roadmap-phase7-polish-distribution
      category: transparency
      status: unverified
      flagged: true
      verification: judgment
      statement: "MUST NOT claim a finished app icon when only a placeholder shipped — the SUMMARY and the README (updated at the phase gate) must label placeholder art as pending real design; and MUST NOT invent privacy-manifest categories beyond the grep-evidenced one (no file-timestamp/boot-time/disk-space entries — research found zero usage)"
  flagged_assumptions:
    - "The image-generation tool may still be down (failed 3× during context gathering, backend/credential issue — 07-CONTEXT decision 2, D-2); the plan treats generated art as opportunistic upside and the scripted placeholder as the deterministic deliverable"
    - "NSImage(systemSymbolName:) renders bolt.fill headlessly under swift scripts on this Mac (no AppKit session needed for offscreen NSImage/NSBitmapImageRep work)"
---

<objective>
Deliver the two asset-level ROADMAP C4 items: the privacy manifest (scoped honestly as best practice, per 07-CONTEXT decision 5) and a real app icon where none exists today (10 declared sizes, zero image files).

Task 1: PrivacyInfo.xcprivacy — one declared category, reason 1C8F.1, verified into the built bundle. Task 2: the icon — first re-attempt image generation (the tool may have recovered); if it fails again, run the committed placeholder script (SF Symbol bolt on the amber accent, per docs/design-guidelines.md's icon language) and label the result as a placeholder everywhere it is described.

Purpose: both artifacts are auto-executable; neither needs a human gate, but the icon needs honesty about which path shipped.
Output: a linting privacy manifest inside the built app, a complete 10-size icon set, a committed reproducible generator script.
</objective>

<execution_context>
@~/.claude/gsd-core/workflows/execute-plan.md
@~/.claude/gsd-core/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/ROADMAP.md
@.planning/phases/07-polish-distribution/07-CONTEXT.md
@.planning/phases/07-polish-distribution/07-RESEARCH.md
@docs/design-guidelines.md
@BoosterSimApp/Assets.xcassets/AppIcon.appiconset/Contents.json
</context>

<tasks>

<task type="auto">
  <name>Task 1: PrivacyInfo.xcprivacy — single grep-evidenced required-reason entry, verified into the bundle</name>
  <files>BoosterSimApp/PrivacyInfo.xcprivacy</files>
  <read_first>
    - .planning/phases/07-polish-distribution/07-RESEARCH.md §3 — the category table: UserDefaults IS a required-reason category (reason 1C8F.1 correct for this app: no App Group, no CMS); file-timestamp/system-boot/disk-space greps returned zero; Accessibility + ScreenCaptureKit are governed by usage-description strings, not this manifest
    - BoosterSimApp/Assets.xcassets structure — the app folder IS a synchronized file group (Phase 5 STATE decision: new files need no project edits), so the manifest auto-includes as a resource
  </read_first>
  <action>
    Re-run the evidence greps first (truth over template): confirm UserDefaults/@AppStorage usage still exists under BoosterSimApp/ (grep -rl '@AppStorage\|UserDefaults' BoosterSimApp --include='*.swift' | wc -l — expect ~17 files) and that the three non-applicable categories remain absent (grep for 'creationDate\|contentModificationDate\|getattrlist\|systemUptime\|statfs' under BoosterSimApp/ — expect zero app-code hits; incidental strings in comments don't count). If the evidence changed since research, adjust the entry to match reality — never ship a stale declaration.
    Then create BoosterSimApp/PrivacyInfo.xcprivacy (XML property list): NSPrivacyTracking = false, NSPrivacyTrackingDomains = empty array, NSPrivacyCollectedDataTypes = empty array, NSPrivacyAccessedAPITypes = exactly one entry — NSPrivacyAccessedAPIType NSPrivacyAccessedAPICategoryUserDefaults with NSPrivacyAccessedAPITypeReasons = ["1C8F.1"]. Nothing else: Sparkle ships its own manifest that Xcode aggregates (07-RESEARCH §3), and the prohibition bars invented categories.
  </action>
  <verify>
    <automated>plutil -lint BoosterSimApp/PrivacyInfo.xcprivacy && python3 -c "import plistlib;d=plistlib.load(open('BoosterSimApp/PrivacyInfo.xcprivacy','rb'));t=d['NSPrivacyAccessedAPITypes'];assert len(t)==1 and t[0]['NSPrivacyAccessedAPIType']=='NSPrivacyAccessedAPICategoryUserDefaults' and t[0]['NSPrivacyAccessedAPITypeReasons']==['1C8F.1'],t" && xcodebuild -project BoosterSimApp.xcodeproj -scheme BoosterSimApp -destination 'platform=macOS' -configuration Debug -derivedDataPath build/privacy-check build && test -f build/privacy-check/Build/Products/Debug/BoosterSimApp.app/Contents/Resources/PrivacyInfo.xcprivacy</automated>
    <fails_when>lint fails, the manifest structure isn't exactly the one entry, the build fails, or the file doesn't land in the built bundle's Resources</fails_when>
  </verify>
  <done>A lint-clean, evidence-accurate PrivacyInfo.xcprivacy ships inside the built app bundle; scope recorded as transparency best practice (not an App Store gate) per 07-CONTEXT decision 5.</done>
</task>

<task type="auto">
  <name>Task 2: App icon — attempt real generation, else scripted amber SF-Symbol placeholder at all 10 sizes</name>
  <files>
    BoosterSimApp/Assets.xcassets/AppIcon.appiconset/Contents.json,
    scripts/generate-placeholder-icon.swift
  </files>
  <read_first>
    - BoosterSimApp/Assets.xcassets/AppIcon.appiconset/Contents.json — the 10 entries (16/32/128/256/512 at 1x+2x → pixel sizes 16, 32, 32, 64, 128, 256, 256, 512, 512, 1024), currently zero filename entries
    - docs/design-guidelines.md Color Palette + Key Symbols — amber accent #E8720C light / #F59E0B dark; the menu-bar identity is bolt/bolt.fill — the placeholder composites exactly this language
    - .planning/phases/07-polish-distribution/07-CONTEXT.md decision 2 — the (a) retry-generation / (c) labeled-placeholder decision space
  </read_first>
  <action>
    Path A (attempt first, once): try the session's image-generation tooling for a macOS app icon — a stylized bolt/panel motif in the app's amber (#E8720C) on a clean rounded-square, 1024×1024 master. If it succeeds: save the master, downscale to the 10 pixel sizes (sips -z), write the filenames into Contents.json, and record "generated artwork" in the SUMMARY. If the tool errors or is unavailable (the 3× prior failure mode), fall through to Path B without retry loops.

    Path B (deterministic deliverable): write scripts/generate-placeholder-icon.swift — an AppKit offscreen renderer (NSImage/NSBitmapImageRep; no window server session needed) that composes, at each of the 10 exact pixel sizes: a rounded-square (macOS-style continuous-look corner radius ≈ 22.5% of the canvas) filled amber #E8720C (the light-mode accent; the hex lives in this seeding script the same way it lives in the AccentColor asset — app-code token rules don't apply to the asset generator), a centered white bolt.fill SF Symbol (NSImage(systemSymbolName:)) scaled ≈ 55% of the canvas, opaque sRGB PNG. Run it with `swift scripts/generate-placeholder-icon.swift` writing icon-16.png, icon-16@2x.png, icon-32.png, icon-32@2x.png, icon-128.png, icon-128@2x.png, icon-256.png, icon-256@2x.png, icon-512.png, icon-512@2x.png into the appiconset. Update Contents.json with the matching filename per entry (the mapping is size@scale → pixel size above).

    Either path: state in the SUMMARY which path shipped — if Path B, the icon is a PLACEHOLDER pending real design, and that word appears in the SUMMARY (the README note happens at the phase gate, 07-06). Never present Path B output as finished art.
  </action>
  <verify>
    <automated>set -o pipefail; cd BoosterSimApp/Assets.xcassets/AppIcon.appiconset && for spec in icon-16:16 icon-16@2x:32 icon-32:32 icon-32@2x:64 icon-128:128 icon-128@2x:256 icon-256:256 icon-256@2x:512 icon-512:512 icon-512@2x:1024; do f="${spec%%:*}"; w="${spec##*:}"; test -f "$f.png" || exit 1; [ "$(sips -g pixelWidth "$f.png" | awk '/pixelWidth/{print $2}')" = "$w" ] || exit 1; done && python3 -c "import json;d=json.load(open('Contents.json'));imgs=[i for i in d['images'] if i.get('filename')];assert len(imgs)==10, len(imgs)" && cd ../../.. && xcodebuild -project BoosterSimApp.xcodeproj -scheme BoosterSimApp -destination 'platform=macOS' -configuration Debug build 2>&1 | tail -3</automated>
    <fails_when>any of the 10 PNGs is missing, any pixel width mismatches its declared size, Contents.json doesn't carry 10 filename entries, or the build fails (asset compilation error)</fails_when>
  </verify>
  <done>All 10 declared sizes exist at exact dimensions with a valid catalog; the SUMMARY names the path (generated vs placeholder) — a placeholder is explicitly labeled as pending real design, never claimed finished.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| Privacy declarations ↔ actual API usage | The manifest asserts what the binary does; a wrong assertion is a false statement about the product |
| Generated art ↔ licensing | Path A output must come from the session's sanctioned generation tooling; Path B uses only Apple's SF Symbols + the app's own palette |

## STRIDE Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation Plan |
|-----------|----------|-----------|----------|-------------|-----------------|
| T-07-11 | Repudiation | PrivacyInfo.xcprivacy accuracy | medium | mitigate | Evidence re-grepped at execution time before writing; exactly one entry matching the verified usage; prohibition bars invented categories |
| T-07-12 | Repudiation (transparency) | icon provenance | medium | mitigate | SUMMARY names the shipped path; placeholder labeling requirement; phase-gate README carries the same honesty |
| T-07-13 | Tampering | asset generation script | low | accept | Committed, reviewed, deterministic script rendering Apple-provided symbols and the documented palette only — no network, no external art |
</threat_model>

<verification>
- Task 1: plutil lint + structural assert (exactly one UserDefaults/1C8F.1 entry) + Debug build + bundle-presence check
- Task 2: 10-file existence + exact pixel-width loop + Contents.json 10 filename entries + build green
</verification>

<success_criteria>
- ROADMAP C4's manifest and icon items TRUE within their honest scope: manifest accurate and shipped in-bundle; icon set complete with provenance stated
- Both deliverables fully auto-executable — no human gate
</success_criteria>

<output>
Create `.planning/phases/07-polish-distribution/07-04-privacy-manifest-app-icon-SUMMARY.md` when done
</output>
