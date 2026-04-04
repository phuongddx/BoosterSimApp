# Design Guidelines

## Design Principles

- **Utility-first:** Panel is a tool, not a focal point — stay out of the developer's way
- **Native macOS feel:** Follow HIG conventions; use system materials, SF Symbols, SF Pro
- **Compact density:** Maximize information per pixel in the 260pt panel width
- **Adaptive:** Respect system Dark Mode, Reduce Motion, and Dynamic Type

## Color Palette

### Accent (Amber/Orange)

| Context | Value | Usage |
|---|---|---|
| Light mode | `#E8720C` | Primary CTA, active indicators |
| Dark mode | `#F59E0B` | Primary CTA, active indicators |

Never hardcode hex values. Reference via asset catalog named color `AccentColor`.

### Semantic Colors (system-adaptive)

| Token | SwiftUI | Usage |
|---|---|---|
| Background | `.windowBackgroundColor` | Panel and window backgrounds |
| Primary text | `.primary` | Labels, titles |
| Secondary text | `.secondary` | Subtitles, placeholders, status text |
| Separator | `.separator` | Dividers between sections |
| Selected | `.accentColor` | Active/selected states |

## Typography

All text uses **SF Pro** via system font APIs only.

| Role | SwiftUI | Size | Weight |
|---|---|---|---|
| Panel title | `.headline` | 13pt | Semibold |
| Section header | `.subheadline` | 12pt | Medium |
| Feature row label | `.body` | 13pt | Regular |
| Footer / caption | `.caption` | 11pt | Regular |
| Status badge | `.caption2` | 10pt | Regular |

## Icons

- **SF Symbols exclusively** — `Image(systemName:)` and `Label(_, systemImage:)`
- Use filled variants for active/selected states
- Use outlined variants for inactive states
- Symbol weight should match surrounding text weight

### Key Symbols Used

| Element | Symbol |
|---|---|
| Menu bar (connected) | `bolt.fill` |
| Menu bar (disconnected) | `bolt.slash` |
| Simulator device | `iphone` |
| Collapse panel | `chevron.left` / `chevron.right` |
| **Phase 1** |
| Screenshot | `camera` |
| Record screen | `video` |
| GIF | `film` |
| Reset app | `arrow.counterclockwise` |
| Clear keychain | `key` |
| Push notification | `bell` |
| Deep link | `link` |
| **Phase 4** |
| Grid overlay | `grid` |
| Safe area | `rectangle.dashed` |
| Ruler | `ruler` |
| Color picker | `eyedropper` |
| **Phase 5** |
| Network throttle | `tortoise` |
| Block requests | `xmark.shield` |
| View logs | `list.bullet.rectangle` |
| Certificates | `lock.shield` |
| **Phase 6** |
| Status bar | `iphone.gen3` or `clock` |
| Environment overrides | `paintbrush` |
| Build stats | `chart.bar` |
| Accessibility tree | `accessibility` |
| Camera | `video.camera` |
| Health data section | `heart.fill` |
| Health preset — active | `figure.run` |
| Health preset — rest | `moon.fill` |
| Health preset — sick | `cross.fill` |
| Health preset — history | `calendar` |
| Health clear | `trash` |
| Health generating | `arrow.triangle.2.circlepath` |

## Spacing System (4pt Grid)

All spacing values must come from `Spacing` enum in `DesignTokens.swift`:

| Token | Value | Usage |
|---|---|---|
| `xxs` | 2pt | Tight icon padding, dot indicators |
| `xs` | 4pt | Between icon and label, minor gaps |
| `sm` | 8pt | Row internal padding, section gaps |
| `md` | 12pt | Standard section padding |
| `lg` | 16pt | Between major sections |
| `xl` | 20pt | Onboarding content padding |
| `xxl` | 24pt | Large content blocks |

## Corner Radii

| Token | Value | Usage |
|---|---|---|
| `small` | 4pt | Badges, chips |
| `medium` | 6pt | Buttons, row highlights |
| `large` | 8pt | Cards, section backgrounds |
| `panel` | 10pt | Window panel corners |
| `onboarding` | 12pt | Onboarding card |

## Side Panel Dimensions

| Metric | Value |
|---|---|
| Expanded width | 260pt |
| Collapsed width | 28pt |
| Min height | 400pt |
| Row height | 32pt |
| Compact row height | 28pt |
| Header height | 36pt |
| Title bar height | 28pt |

## Component Patterns

### Feature Row

```
[icon 16pt]  [label]              [badge "Soon"]
← sm →       ← flex grow →       ← sm →
Row height: 32pt, horizontal padding: sm (8pt)
```

- Icon: SF Symbol, 16pt, `.secondary` color
- Label: `.body`, primary color
- Badge: `StatusBadge` with `.secondary` fill, "Soon" text

### Feature Section

- Disclosure group with `▶` chevron
- Section header: `.subheadline`, `.secondary`, uppercase
- Default expanded in MVP

### Collapsed Strip

- 28pt wide vertical strip
- Single `chevron.right` icon centered
- Tapping expands panel with 0.2s ease-in-out animation

### CollapsibleSection

Reusable atom (`Views/Shared/CollapsibleSection.swift`). Wraps any content with a tappable header:

```
[chevron 10pt]  [SECTION TITLE]        (uppercase, .caption, .secondary)
← xs →          ← flex →
Tap toggles @State isExpanded; animates with .animation(.easeInOut(0.2))
```

- Header padding: `sm` vertical, `md` horizontal
- Chevron rotates 90° when expanded (`rotationEffect(.degrees(isExpanded ? 90 : 0))`)
- Used by: `EnvironmentOverridesView`, `HealthDataSectionView`, `BuildStatsSectionView`

### Status Badge

- Colored dot (6pt circle) + label text
- Colors: `.green` (active), `.orange` (warning), `.secondary` (inactive/soon)

## Animation

| Interaction | Duration | Curve |
|---|---|---|
| Collapse/expand | 0.2s | ease-in-out |
| Collapse/expand (Reduce Motion) | 0.1s | ease-in-out |
| Position update (Simulator move) | None (instant) | — |

Use `NSAnimationContext.runAnimationGroup` for panel frame animations.
Always check `NSWorkspace.shared.accessibilityDisplayShouldReduceMotion`.

## Onboarding

- Window size: 480 × 520pt, centered on screen
- 4 steps: Welcome → Accessibility → Screen Recording → Ready
- Progress dots: 8pt circles, filled = current/completed, outlined = pending
- Navigation: "Continue" (AccentButton) primary, "Back" ghost secondary
- Completion persisted via `@AppStorage("completedOnboarding")`

## Preferences Window

- Size: 500 × 380pt
- Tab bar: General | About
- Row height: 36pt
- Uses native `Form` / `TabView` SwiftUI layout
