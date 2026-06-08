import 'package:flutter/material.dart';
import 'package:make_it_sound_natural/theme/app_theme.dart';

/// Shared layout, radius, size, and typography tokens for desktop UI.
abstract final class AppSpacing {
  /// 4 px spacing token.
  static const double xxs = 4;

  /// 8 px spacing token.
  static const double xs = 8;

  /// 12 px spacing token.
  static const double sm = 12;

  /// 16 px spacing token.
  static const double md = 16;

  /// 20 px spacing token.
  static const double lg = 20;

  /// 24 px spacing token.
  static const double xl = 24;

  /// 32 px spacing token.
  static const double xxl = 32;

  /// 40 px spacing token.
  static const double xxxl = 40;

  /// 48 px spacing token.
  static const double huge = 48;
}

/// Shared corner radii.
abstract final class AppRadius {
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
  static const double headerHeight = 68;

  /// Segmented tab height.
  static const double tabHeight = 40;

  /// Segmented tab width.
  static const double tabWidth = 96;

  /// Rewrite width where Source and Variants switch to side-by-side.
  static const double rewriteTwoPanelBreakpoint = 1100;

  /// Header leading inset that clears macOS traffic-light controls.
  static const double headerTrafficLightInset = 136;

  /// Header leading inset for wide desktop windows.
  static const double headerWideLeadingInset = 152;

  /// Width where the header uses the wide leading inset.
  static const double headerWideBreakpoint = 1500;

  /// Width where the header uses wider trailing padding.
  static const double headerTrailingBreakpoint = 980;

  /// Compact desktop row height.
  static const double compactRowHeight = 52;

  /// Settings row height.
  static const double settingsRowHeight = 60;

  /// Small icon tile.
  static const double iconTileSmall = 44;

  /// Default settings icon tile.
  static const double iconTile = 44;

  /// Main content max width.
  static const double contentMaxWidth = 980;

  /// Dialog max width.
  static const double dialogMaxWidth = 720;

  /// Compact dialog max width.
  static const double dialogCompactMaxWidth = 560;

  /// Minimum form control width.
  static const double controlMinWidth = 420;

  /// Compact settings trailing control width.
  static const double settingsControlWidth = 280;

  /// Default form control width.
  static const double controlWidth = 464;

  /// Maximum form control width.
  static const double controlMaxWidth = 490;
}

/// Shared typography roles.
abstract final class AppTextStyles {
  /// Application title in the window header.
  static const TextStyle appTitle = TextStyle(
    color: Color(0xFF101828),
    fontSize: 22,
    fontWeight: FontWeight.w700,
  );

  /// Settings or page title.
  static const TextStyle pageTitle = TextStyle(
    color: Color(0xFF101828),
    fontSize: 24,
    fontWeight: FontWeight.w800,
  );

  /// Main content section title.
  static const TextStyle sectionTitle = TextStyle(
    color: AppColors.primary,
    fontSize: 14,
    fontWeight: FontWeight.w800,
  );

  /// Settings row title.
  static const TextStyle rowTitle = TextStyle(
    color: Color(0xFF101828),
    fontSize: 15,
    fontWeight: FontWeight.w700,
  );

  /// Settings row subtitle.
  static const TextStyle rowSubtitle = TextStyle(
    color: Color(0xFF667085),
    fontSize: 13,
  );

  /// Form and button control text.
  static const TextStyle control = TextStyle(
    color: Color(0xFF101828),
    fontSize: 15,
    fontWeight: FontWeight.w600,
  );

  /// Small helper or status text.
  static const TextStyle helper = TextStyle(
    color: Color(0xFF667085),
    fontSize: 13,
  );

  /// Application title adjusted by current theme text size.
  static TextStyle appTitleOf(BuildContext context) {
    return Theme.of(context).textTheme.titleLarge!.copyWith(
      fontWeight: FontWeight.w700,
    );
  }

  /// Page title adjusted by current theme text size.
  static TextStyle pageTitleOf(BuildContext context) {
    return Theme.of(context).textTheme.headlineMedium!.copyWith(
      fontWeight: FontWeight.w800,
    );
  }

  /// Section title adjusted by current theme text size.
  static TextStyle sectionTitleOf(BuildContext context) {
    return Theme.of(context).textTheme.bodyMedium!.copyWith(
      color: Theme.of(context).brightness == Brightness.dark
          ? Theme.of(context).colorScheme.primary
          : AppColors.primary,
      fontWeight: FontWeight.w800,
    );
  }

  /// Settings row title adjusted by current theme text size.
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

  /// Form and button control text adjusted by current theme text size.
  static TextStyle controlOf(BuildContext context) {
    return Theme.of(context).textTheme.bodyMedium!.copyWith(
      color: Theme.of(context).colorScheme.onSurface,
      fontWeight: FontWeight.w600,
    );
  }
}
