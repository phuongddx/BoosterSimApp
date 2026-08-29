# Ingested Constraints (from SPEC-classified docs)

Source: docs/design-guidelines.md (SPEC — visual and interaction design specification).
All entries typed `nfr` (design-system constraints); no api-contract / schema / protocol
constraints exist in this ingest set.

## Design Principles
- source: docs/design-guidelines.md
- type: nfr
- content: Utility-first (panel is a tool, not a focal point); native macOS feel (HIG
  conventions, system materials, SF Symbols, SF Pro); compact density (maximize information
  per pixel in the 260pt panel width); adaptive (respect system Dark Mode, Reduce Motion,
  Dynamic Type).

## Accent Color (Amber)
- source: docs/design-guidelines.md
- type: nfr
- content: Light mode `#E8720C`, dark mode `#F59E0B` — primary CTA and active indicators only.
  Never hardcode hex values; reference via asset catalog named color `AccentColor`.

## Semantic Colors
- source: docs/design-guidelines.md
- type: nfr
- content: System-adaptive tokens only: background `.windowBackgroundColor`; primary text
  `.primary`; secondary text `.secondary`; separator `.separator`; selected `.accentColor`.

## Typography
- source: docs/design-guidelines.md
- type: nfr
- content: SF Pro exclusively via system font APIs. Scale: panel title `.headline` 13pt
  Semibold; section header `.subheadline` 12pt Medium; feature row label `.body` 13pt Regular;
  footer/caption `.caption` 11pt Regular; status badge `.caption2` 10pt Regular.

## Icons
- source: docs/design-guidelines.md
- type: nfr
- content: SF Symbols exclusively (`Image(systemName:)`, `Label(_, systemImage:)`); filled
  variants for active/selected states, outlined for inactive; symbol weight matches surrounding
  text weight. Per-feature symbol assignments are specified in the source (Phase 1: camera,
  video, film, arrow.counterclockwise, key, bell, link; Phase 4: grid, rectangle.dashed,
  ruler, eyedropper; Phase 5: tortoise, xmark.shield, list.bullet.rectangle, lock.shield;
  Phase 6: iphone.gen3/clock, paintbrush, chart.bar, accessibility, video.camera; menu bar:
  bolt.fill / bolt.slash; collapse: chevron.left / chevron.right).

## Spacing System (4pt Grid)
- source: docs/design-guidelines.md
- type: nfr
- content: All spacing from `Spacing` enum in DesignTokens.swift: xxs=2pt, xs=4pt, sm=8pt,
  md=12pt, lg=16pt, xl=20pt, xxl=24pt.

## Corner Radii
- source: docs/design-guidelines.md
- type: nfr
- content: All radii from `CornerRadius` enum in DesignTokens.swift: small=4pt (badges, chips),
  medium=6pt (buttons, row highlights), large=8pt (cards, section backgrounds), panel=10pt
  (window panel corners), onboarding=12pt (onboarding card).

## Side Panel Dimensions
- source: docs/design-guidelines.md
- type: nfr
- content: From `SideWindowMetrics`: expanded width 260pt; collapsed width 28pt; min height
  400pt; row height 32pt; compact row height 28pt; header height 36pt; tab bar height 36pt
  (matches header height).

## Component Patterns
- source: docs/design-guidelines.md
- type: nfr
- content: FeatureRow (32pt height, 16pt secondary SF Symbol icon, `.body` label, sm padding,
  StatusBadge "Soon"); FeatureSection (disclosure group, uppercase `.subheadline` `.secondary`
  header, default expanded in MVP); CollapsedStrip (28pt vertical strip, single chevron.right,
  0.2s ease-in-out expand); CollapsibleSection (reusable atom, tappable uppercase `.caption`
  header with 10pt rotating chevron, header padding sm vertical / md horizontal, easeInOut 0.2);
  TabBarView (36pt height, `.bar` material with 8pt corner radius, 15% black shadow 2pt blur /
  1pt Y, 2pt amber underline on selected tab, right-aligned chevron.left collapse button, 1pt
  bottom divider, md horizontal padding per tab, spring response=0.25s dampingFraction=0.8,
  linear 0.1s under Reduce Motion, accessibility tooltip + label + isSelected trait);
  StatusBadge (6pt colored dot + label; green=active, orange=warning, secondary=inactive/soon).

## Animation Rules
- source: docs/design-guidelines.md
- type: nfr
- content: Collapse/expand 0.2s ease-in-out (0.1s ease-in-out under Reduce Motion); position
  updates on Simulator move are instant (no animation). Panel frame animations via
  `NSAnimationContext.runAnimationGroup`. Always check
  `NSWorkspace.shared.accessibilityDisplayShouldReduceMotion`.

## Onboarding Layout
- source: docs/design-guidelines.md
- type: nfr
- content: Window 480 × 520pt centered; 4 steps (Welcome → Accessibility → Screen Recording →
  Ready); progress dots 8pt circles (filled = current/completed, outlined = pending);
  "Continue" AccentButton primary, "Back" ghost secondary; completion persisted via
  `@AppStorage("completedOnboarding")`.

## Preferences Window Layout
- source: docs/design-guidelines.md
- type: nfr
- content: Size 500 × 380pt; tab bar General | About; row height 36pt; native SwiftUI
  `Form` / `TabView` layout.
