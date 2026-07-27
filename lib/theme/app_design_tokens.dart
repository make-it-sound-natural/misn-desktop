import 'package:flutter/material.dart';

/// Shared layout, radius, size, and typography tokens for desktop UI.
abstract final class AppSpacing {
  /// 4 px spacing token.
  static const double xxs = 4;

  /// 6 px spacing token.
  ///
  /// Half-step between [xxs] and [xs]. The compact desktop density needs 2 px
  /// granularity below 8 px: badge insets and tight vertical stacks land here.
  static const double xxsPlus = 6;

  /// 8 px spacing token.
  static const double xs = 8;

  /// 10 px spacing token — half-step between [xs] and [sm].
  static const double xsPlus = 10;

  /// 12 px spacing token.
  static const double sm = 12;

  /// 14 px spacing token — half-step between [sm] and [md].
  ///
  /// The shared vertical padding of fields, variant cards, and skeletons; the
  /// value is load-bearing, so it is named rather than snapped to 16.
  static const double smPlus = 14;

  /// 16 px spacing token.
  static const double md = 16;

  /// 20 px spacing token.
  static const double lg = 20;

  /// 24 px spacing token.
  static const double xl = 24;

  /// 32 px spacing token.
  static const double xxl = 32;
}

/// Shared corner radii.
abstract final class AppRadius {
  /// 5 px radius, for keycap chips and other small inline pills.
  static const double xs = 5;

  /// 8 px radius.
  static const double sm = 8;

  /// 10 px radius.
  static const double md = 10;

  /// 12 px radius.
  static const double lg = 12;

  /// 14 px radius.
  static const double xl = 14;

  /// 16 px radius.
  static const double xxl = 16;
}

/// Shared fixed dimensions and responsive width caps.
abstract final class AppSizes {
  /// Main macOS window header height.
  ///
  /// Matches AppKit's compact unified toolbar: this band carries one small
  /// control, not a full toolbar's worth.
  static const double headerHeight = 40;

  /// Segmented tab height.
  static const double tabHeight = 40;

  /// Segmented tab width.
  static const double tabWidth = 96;

  /// Widest the Rewrite content grows before it stops filling the window.
  ///
  /// Caps each column near 500pt, which keeps the rewrite text inside a
  /// readable measure on a large display.
  static const double rewriteMaxContentWidth = 1240;

  /// Header leading inset that clears macOS traffic-light controls.
  ///
  /// The cluster's right edge sits at 69pt; AppKit's own toolbars start their
  /// first item near 80pt. The lights do not move when the window widens, so
  /// this inset is fixed.
  static const double headerTrafficLightInset = 80;

  /// Compact desktop row height.
  static const double compactRowHeight = 52;

  /// Settings row height.
  static const double settingsRowHeight = 60;

  /// Small icon tile.
  static const double iconTileSmall = 44;

  /// Dialog max width.
  static const double dialogMaxWidth = 720;

  /// Compact dialog max width.
  static const double dialogCompactMaxWidth = 560;

  /// Minimum form control width.
  static const double controlMinWidth = 420;

  /// Compact settings trailing control width.
  static const double settingsControlWidth = 280;

  /// Trailing control width where the value is a model id or a URL.
  ///
  /// Wider than [settingsControlWidth] because a monospaced slug does not
  /// ellipsise gracefully; named so the two widths are a documented choice
  /// rather than one section quietly disagreeing with the others.
  static const double settingsWideControlWidth = 320;

  /// Settings row glyph size.
  static const double rowIconSize = 22;

  /// Inline glyph beside body text (badges, hints, notes).
  static const double iconSm = 14;

  /// Default glyph inside compact controls and menu rows.
  static const double iconMd = 16;

  /// Glyph inside row actions, toasts, and dialog affordances.
  static const double iconLg = 18;

  /// Segmented tab height in the window header.
  ///
  /// Deliberately shorter than [tabHeight]: the header band is 40pt tall and
  /// the raised segment has to sit inside it with breathing room.
  static const double segmentedTabHeight = 28;

  /// Standard form control height (selects, inputs, secondary buttons).
  static const double controlHeight = 36;

  /// Primary call-to-action height on the Rewrite screen.
  static const double ctaHeight = 40;

  /// Widest the Settings content pane grows before it stops filling the pane.
  ///
  /// Without it the pane stretched to the window: on a wide display a row's
  /// title sat at one edge and its control at the other, while the Rewrite
  /// tab stayed capped — switching tabs read as switching apps.
  static const double settingsMaxContentWidth = 980;

  /// Settings sidebar row height.
  ///
  /// Its own token rather than borrowing [tabHeight], which documents itself
  /// as the segmented tab height — the sidebar's density was coupled to an
  /// unrelated control by accident.
  static const double sidebarRowHeight = 40;

  /// Settings sidebar width.
  static const double settingsSidebarWidth = 236;

  /// Floating toast width.
  static const double toastWidth = 420;
}

/// Shared typography roles.
abstract final class AppTextStyles {
  /// Page title adjusted by current theme text size.
  static TextStyle pageTitleOf(BuildContext context) {
    return Theme.of(context).textTheme.headlineMedium!.copyWith(
      fontWeight: FontWeight.w700,
      // Display type needs more optical tightening than the smaller headers,
      // not less; without it the sidebar title read loose against them.
      letterSpacing: -0.4,
    );
  }

  /// Uppercase muted eyebrow above a Rewrite panel.
  static TextStyle eyebrowOf(BuildContext context) {
    final base = Theme.of(context).textTheme.bodySmall!;
    return base.copyWith(
      fontSize: base.fontSize! - 1,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w700,
      letterSpacing: 1,
    );
  }

  /// Settings section header.
  static TextStyle settingsHeaderOf(BuildContext context) {
    return Theme.of(context).textTheme.titleLarge!.copyWith(
      color: Theme.of(context).colorScheme.onSurface,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.2,
    );
  }

  /// Group title inside a settings section, and field labels inside a panel.
  ///
  /// The two ranks are deliberately identical: the mockups spell `.group-title`
  /// and `.field-label` the same. Based on `bodyMedium` rather than `bodySmall`
  /// so a heading is never smaller than the rows it heads — at the default
  /// text size the old value put a 12px title over 14px row titles.
  static TextStyle groupTitleOf(BuildContext context) {
    final base = Theme.of(context).textTheme.bodyMedium!;
    return base.copyWith(
      fontSize: base.fontSize! - 1,
      color: Theme.of(context).colorScheme.onSurface,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.1,
    );
  }

  /// Monospaced face, reserved for model ids, base URLs, and latency numbers.
  ///
  /// One declaration so the rule stays enforceable: the face used to be
  /// spelled out as the literal `'Menlo'` in four places.
  static const String monoFontFamily = 'Menlo';

  /// Model ids and base URLs shown inline.
  static TextStyle monoOf(BuildContext context) {
    final base = Theme.of(context).textTheme.bodyMedium!;
    return base.copyWith(
      fontFamily: monoFontFamily,
      fontSize: base.fontSize! - 1,
    );
  }

  /// Secondary monospaced detail (latency, slugs inside a row subtitle).
  static TextStyle monoDetailOf(BuildContext context) {
    final base = Theme.of(context).textTheme.bodySmall!;
    return base.copyWith(
      fontFamily: monoFontFamily,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
  }

  /// Settings row title adjusted by current theme text size.
  ///
  /// w700 to match the mockups and the variant card, which were already at
  /// 700 — the same structural element used to read bolder on Rewrite than in
  /// Settings. Weight and tracking separate this from [groupTitleOf], not an
  /// inverted size step.
  static TextStyle rowTitleOf(BuildContext context) {
    return Theme.of(context).textTheme.bodyMedium!.copyWith(
      color: Theme.of(context).colorScheme.onSurface,
      fontWeight: FontWeight.w700,
    );
  }

  /// Settings row subtitle adjusted by current theme text size.
  static TextStyle rowSubtitleOf(BuildContext context) {
    return Theme.of(context).textTheme.bodySmall!.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
  }

  /// Form and button control text.
  ///
  /// Identical to [rowTitleOf] by design: a control's label and the row that
  /// holds it sit at the same rank.
  static TextStyle controlOf(BuildContext context) => rowTitleOf(context);
}
