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

## Tokens

Use `lib/theme/app_design_tokens.dart` for:

- spacing: `AppSpacing`
- radius: `AppRadius`
- fixed sizes and max widths: `AppSizes`
- typography roles: `AppTextStyles`

New UI should use tokens instead of raw spacing, radius, row height, and page
width values.

Window and header sizing rules:

- fresh launches should use a default width that reaches the two-panel Rewrite
  layout;
- user-selected narrow windows remain valid and may use the compact stacked
  Rewrite layout;
- `AppSizes.headerTrafficLightInset` reserves leading space for macOS
  traffic-light controls in the full-size titlebar;
- `AppSizes.rewriteTwoPanelBreakpoint` controls the Rewrite layout switch and
  must not be reused as the native minimum window width.

## Shared Components

Use these primitives for app surfaces:

- `AppWindowHeader`: shared Rewrite/Settings header and segmented tabs.
- `AppSegmentedTabs`: top-level tab control.
- `AppPanel`: bordered white panel/card container.
- `AppSettingsSection`: grouped settings section.
- `AppSettingsRow`: compact settings row.
- `AppSettingsDivider`: row divider aligned to settings content.
- `AppSettingsIconTile`: standard row icon tile.

Keep one-off local widgets only for behavior unique to a screen.

## Screen Patterns

Use the Settings screen as the reference for general desktop chrome:

- section titles sit outside the `AppPanel`, with `AppSpacing.xs` left/bottom
  padding;
- panels use `AppPanel` before custom bordered containers;
- form controls use the same radius, fill, border, and focus treatment as
  Settings fields unless the control type requires a different native affordance;
- selected states use the shared primary color plus the same light selected
  wash (`#F0EAFE`) or the theme primary container in dark mode;
- passive status pills stay neutral. Reserve purple/gradient treatment for the
  primary action or the active selection;
- compact icon buttons are preferred for small utility actions such as clear,
  copy, close, reveal, and reset. When they sit beside a primary action, use a
  low-contrast filled tile with token radius so the control remains discoverable
  without competing with the primary button.

If a visual change needs a new reusable pattern, add the pattern here and then
implement it as a shared widget or token before using it in multiple screens.

## Density Defaults

- Header: `68 px`
- Segmented tab: `40 px`
- Compact row: `52 px`
- Settings row: `60 px`
- Icon tiles: `44 px`
- Page content max width: `980 px`
- Dialog max width: `720 px`
- Form controls: `420-490 px`

Outer page padding should usually be `24-48 px`. Inner panel padding should
usually be `20-24 px`. Related controls should usually be `8-16 px` apart.
