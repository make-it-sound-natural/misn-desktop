# MISN Design System

This app uses a compact desktop utility layout. It should feel like one macOS
tool, not separate pages made with unrelated spacing rules.

## Layout Laws

- **Proximity**: related label, helper text, and control stay close together.
  Separate unrelated groups with a larger gap.
- **Alignment**: repeated controls share the same left edge, right edge, row
  height, and baseline where possible.
- **8 px rhythm**: use spacing tokens from `AppSpacing`
  (`4/8/12/16/20/24/32/40/48`). Do not add one-off gaps such as `22`, `28`,
  `34`, or `72` unless a visual asset forces it.
- **Hierarchy**: one page title per page, smaller section titles, compact row
  titles, and subdued helper text.
- **Consistency**: one interaction pattern gets one component. Use shared
  primitives before creating local containers.
- **Screen unity**: Rewrite, Settings, dialogs, and popovers must look like one
  product. When changing one surface, compare it with the nearest existing
  surface before adding a new local visual pattern.
- **Truthful UI**: do not show telemetry, scores, or status pills unless they
  are wired to real app state. Prefer removing placeholders over decorative
  fake feedback.
- **Fitts + desktop density**: clickable targets should be at least
  `36-40 px`, but avoid mobile-sized whitespace in desktop rows.
- **Accessibility**: keep normal text near `4.5:1` contrast, preserve focus
  states, ellipsize long labels, and verify responsive layouts do not overlap.

## Color Tokens

Every chrome color comes from `AppColors` (`lib/theme/app_theme.dart`) or from
`AppStatusColors`. No literal hex values in widgets.

| Token | Light | Dark | Role |
| --- | --- | --- | --- |
| `background` / `darkBackground` | `#F8F9FD` | `#111113` | Scaffold |
| `surface` / `darkSurface` | `#FFFFFF` | `#1C1C1E` | Panels, cards, dialogs |
| `textPrimary` / `darkTextPrimary` | `#1C1C1E` | `#F2F2F7` | Body text |
| `textSecondary` / `darkTextSecondary` | `#5B6478` | `#C7C7CC` | Muted text, glyphs (darkened from the mockup's `#667085`, which measured 4.24:1 on `accentSoft`) |
| `border` / `darkBorder` | `#E0E0E0` | `#3A3A3C` | Borders, dividers |
| `field` / `darkField` | `#FFFFFF` | `#242427` | Editable field fill |
| `hover` / `darkHover` | `#F2F2F6` | `#26262B` | Hover, subtle containers |
| `primary` / `darkPrimary` | `#8E24AA` | `#DDA7F0` | The single accent |
| `onAccent` / `darkOnAccent` | `#FFFFFF` | `#2A1236` | Text on solid accent |
| `accentSoft` / `darkAccentSoft` | `#F8EDFB` | `#34203F` | Applied and active fills (a true tint of `primary`; the mockup's `#F0EAFE` was a different hue family) |
| `skeleton` / `darkSkeleton` | `#ECECF1` | `#26262B` | Loading placeholders |
| `mutedToast` / `darkMutedToast` | `#3A3A3C` | `#26262B` | Muted toast fill |
| `segmentShadow` / `darkSegmentShadow` | `#14000000` | `#3D000000` | Raised header segment |

Status colors (success, warning, error and their containers) stay in
`AppStatusColors`. They double as solid snackbar backgrounds, so any change
must keep `onStatus` at `4.5:1` against them —
`test/theme/app_theme_test.dart` enforces this.

Widgets read these through an explicit `ColorScheme`, never through
`ColorScheme.fromSeed`: the seed algorithm reintroduces the Material surface
tints this system removes. `surfaceContainerLowest` maps to the field fill,
`surfaceContainerHighest` to hover, `primaryContainer` to the accent wash, and
`surfaceTint` is transparent.

## Accent Rules

1. **One accent, at most two roles per screen**: the primary action, and the
   active or applied state. Section titles, eyebrows, links, and passive
   badges are neutral.
2. **No gradients in chrome.** The logo artwork is the only multicolor
   element. The one remaining `LinearGradient` in `lib/` is the skeleton
   shimmer, which is a loading animation rather than decoration.
3. **No pastel container chips.** Row glyphs are single-tone
   `AppSettingsRowIcon` at `22 px`, muted unless they carry a real status.
4. **Applied state is the accent**, not success green, and shows exactly one
   signal: an accent check on an `accentSoft` fill.
5. **One bordered container level.** Group inside a panel with
   `AppSettingsDivider` and whitespace, never with nested bordered cards.
6. **Panels size to their content.** Nothing reserves fixed vertical space.

## Typography

- Body and UI text use the system stack and scale with the user's text-size
  setting; every role in `AppTextStyles` derives from the theme's `textTheme`.
- Roles: `pageTitleOf`, `settingsHeaderOf` (section header), `groupTitleOf`
  (group inside a section), `eyebrowOf` (uppercase muted panel label),
  `rowTitleOf`, `rowSubtitleOf`, `controlOf`.
- **Mono (`Menlo`) is only for model ids, base URLs, and latency numbers.**
  Shortcut combos never use mono: SF Mono draws ⌘⇧⌃⌥ below cap height, so
  combos look broken. Render them with `AppKbdChip`, which uses the UI font.

## Shared Components

- `AppWindowHeader` / `AppSegmentedTabs`: window chrome and top-level tabs.
  The active tab is a raised neutral segment, not an accent fill.
- `AppPanel`: the single bordered container.
- `AppSettingsSection`: header, optional one-line description, and a panel.
- `AppSettingsRow`: `60 px` row; `title`/`subtitle` for plain text, or
  `titleWidget`/`subtitleWidget` when a line mixes fonts.
- `AppSettingsDivider`: full-width row separator inset to the panel padding.
- `AppSettingsRowIcon`: single-tone row glyph.
- `AppDialogShell`: the shell for every dialog — 560 compact / 720 default,
  radius 16, title, optional subtitle, scrollable content, right-aligned
  actions. `showAppConfirmDialog` builds destructive confirmations on it.
- `AppToast` (`showAppToast`): floating single-line feedback with `neutral`,
  `warning`, and `muted` kinds.
- `AppKbdChip`: keyboard hint chip.
- `AppSkeletonCard`: loading placeholder shaped like a variant card.
- `VariantCard`: one rewrite variant with its applied and copy affordances.

Keep one-off local widgets only for behavior unique to a screen.

- `AppPopupSelect` — the macOS pop-up button. Deliberately replaces both the
  mockup's `<select>` and Material's `DropdownButton`: 26 px rows, a checkmark
  on the current value, anchored under its own control, and its own hover,
  focus and disabled states. This is what makes Settings read native.
- `AppInlineBanner` — the one status strip. `title` selects the tall variant
  (heading over message, actions on their own row); without it the banner is a
  single compact row. Both Rewrite banners and the Settings auth-failure note
  are built on it, so a status cannot look loud on one screen and quiet on
  another.

## Dialogs

- Always build on `AppDialogShell`.
- `dismissible` governs the shell's own Escape handler. A dialog that must not
  be dismissed by clicking outside also needs
  `showDialog(barrierDismissible: false)` at the call site — the modal route
  ignores the shell otherwise.
- Escape closes every dialog, including the shortcut recorder (where it
  cancels recording rather than being captured as the new combo). The forced
  target-profile picker is the sole exception: it has no Cancel and ignores
  Escape until a profile is chosen.
- Action order is least to most prominent: text button, `OutlinedButton`,
  then one `FilledButton`. Destructive actions use the error token on an
  outlined button, never the accent.

## Buttons

- At most one primary (`FilledButton`, solid accent) per view.
- Secondary is `OutlinedButton`; tertiary is `TextButton` in the accent.
- Heights come from `AppSizes.controlHeight` (36) and `AppSizes.ctaHeight`
  (40, the Rewrite primary action).

## Empty States

Every list that can be empty shows a muted one-liner and, where an action
makes sense, an inline text button. Do not render placeholder rows that look
like results: the Variants column used to pre-shape itself with four bordered
ghost rows, which read as four collapsed results and were announced as
content by a screen reader. The Rewrite empty state is the one primer that
earns more than a line, because the global shortcut is the product.

## Motion

State transitions are functional only: `≤200 ms` ease-out, nothing decorative.
Two exceptions are named rather than implied — a looping loading indicator may
run near `1 s` (the skeleton shimmer is `1200 ms`), and a one-shot confirmation
may run to `400 ms` (the applied-variant ring is `350 ms` plus a `400 ms` hold).
The shortcut recorder border at `150 ms` is an ordinary state transition.

Every animation must check `MediaQuery.disableAnimations` and degrade to an
instant state change; all three above do.

### Section labels

Two systems, deliberately: `eyebrowOf` (uppercase, letterspaced, muted) labels
a Rewrite **column**; `groupTitleOf` labels a **group of rows** inside a
Settings section and a **field label** inside a panel. Both are specified by
the mockups. Never mix the two on one surface, and do not "unify" them — the
first labels a workspace, the second labels a form.

## Screen Patterns

Use the Settings screen as the reference for general desktop chrome:

- section titles sit outside the `AppPanel`;
- form controls inherit radius, fill, border, and focus treatment from
  `inputDecorationTheme` — do not restyle fields locally;
- the settings sidebar is a fixed `AppSizes.settingsSidebarWidth` rail; the
  native minimum window width keeps every destination reachable, so there is
  no collapsed state;
- passive status pills stay neutral.

If a visual change needs a new reusable pattern, add the pattern here and then
implement it as a shared widget or token before using it in multiple screens.

## Density Defaults

- Header band: `40 px` (`AppSizes.headerHeight`)
- Sidebar nav item: `40 px`; segmented tab inside the header: `28 px`
- Compact row: `52 px`
- Settings row: `60 px`
- Row glyph: `22 px`; inline glyphs: `14 / 16 / 18 px`
- Form control: `36 px`; primary CTA: `40 px`
- Rewrite content max width: `1240 px` (`AppSizes.rewriteMaxContentWidth`)
- Settings content max width: `980 px` (`AppSizes.settingsMaxContentWidth`)
- Dialog max width: `720 px` (`560 px` compact)
- Settings sidebar: `236 px`
- Settings trailing control: `280 px`, or `320 px` where the value is a model
  id or URL (`AppSizes.settingsWideControlWidth`)
- Sidebar row: `40 px` (`AppSizes.sidebarRowHeight`)

Outer page padding should usually be `24-48 px`. Inner panel padding should
usually be `20-24 px`. Related controls should usually be `8-16 px` apart.

## Window and Header Sizing

- Rewrite is always two columns; the native minimum window width guarantees
  they fit, so there is no breakpoint and no stacked fallback;
- `AppSizes.rewriteMaxContentWidth` caps how wide the two columns grow before
  they stop filling the window, keeping the text in a readable measure;
- `AppSizes.headerTrafficLightInset` reserves leading space for macOS
  traffic-light controls in the full-size titlebar.
