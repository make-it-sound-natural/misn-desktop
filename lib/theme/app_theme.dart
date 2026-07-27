import 'package:flutter/material.dart';
import 'package:make_it_sound_natural/theme/app_design_tokens.dart';

/// App color palette derived from the "Wave Unity" logo.
class AppColors {
  AppColors._();

  // Light core tokens, mirroring the design mockups' `:root` palette.
  /// App scaffold background (`--bg`).
  static const Color background = Color(0xFFF8F9FD);

  /// Cards and panels (`--surface`).
  static const Color surface = Color(0xFFFFFFFF);

  /// Primary text (`--fg`).
  static const Color textPrimary = Color(0xFF1C1C1E);

  /// Muted text (`--muted`).
  ///
  /// Darkened from the mockup's `#667085`, which measured 4.46:1 on `hover`
  /// and 4.24:1 on `accentSoft` — both under the 4.5 body-text floor.
  static const Color textSecondary = Color(0xFF5B6478);

  /// Borders and dividers (`--border`).
  static const Color border = Color(0xFFE0E0E0);

  /// Editable field fill (`--field`).
  static const Color field = Color(0xFFFFFFFF);

  /// Hover and subtle container fill (`--hover`).
  static const Color hover = Color(0xFFF2F2F6);

  /// Single UI accent (`--accent`).
  static const Color primary = Color(0xFF8E24AA);

  /// Text and icons on solid accent (`--accent-fg`).
  static const Color onAccent = Color(0xFFFFFFFF);

  /// Faint accent tint for applied and active fills (`--accent-soft`).
  ///
  /// A true tint of [primary]; the mockup value `#F0EAFE` was a different
  /// hue family (258 deg vs 287 deg).
  static const Color accentSoft = Color(0xFFF8EDFB);

  /// Skeleton placeholder fill (`--skel`).
  static const Color skeleton = Color(0xFFECECF1);

  // Dark core tokens (`html[data-theme="dark"]`).
  /// Dark scaffold background.
  static const Color darkBackground = Color(0xFF111113);

  /// Dark surface.
  static const Color darkSurface = Color(0xFF1C1C1E);

  /// Dark primary text.
  static const Color darkTextPrimary = Color(0xFFF2F2F7);

  /// Dark muted text.
  static const Color darkTextSecondary = Color(0xFFC7C7CC);

  /// Dark border.
  static const Color darkBorder = Color(0xFF3A3A3C);

  /// Dark editable field fill.
  static const Color darkField = Color(0xFF242427);

  /// Dark hover and subtle container fill.
  static const Color darkHover = Color(0xFF26262B);

  /// Dark accent.
  static const Color darkPrimary = Color(0xFFDDA7F0);

  /// Text and icons on solid dark accent.
  static const Color darkOnAccent = Color(0xFF2A1236);

  /// Dark faint accent tint.
  static const Color darkAccentSoft = Color(0xFF34203F);

  /// Dark skeleton placeholder fill.
  static const Color darkSkeleton = Color(0xFF26262B);

  /// Toast surface in dark mode.
  static const Color darkToastSurface = Color(0xFFE8E8ED);

  /// Fill for the muted toast, which is always dark-on-light inverted.
  static const Color mutedToast = Color(0xFF3A3A3C);

  /// Dark-mode fill for the muted toast.
  static const Color darkMutedToast = Color(0xFF26262B);

  /// Text and icons on [mutedToast] and [darkMutedToast].
  static const Color onMutedToast = Color(0xFFFFFFFF);

  /// Shadow under the raised segment of the window header tab strip.
  static const Color segmentShadow = Color(0x14000000);

  /// Dark-mode counterpart of [segmentShadow].
  static const Color darkSegmentShadow = Color(0x3D000000);

  // Status Colors
  /// Success state color (e.g., for positive feedback).
  static const Color success = Color(0xFF1B5E20);

  /// Warning state color (e.g., for cautionary messages).
  static const Color warning = Color(0xFF8A4B00);

  /// Error state color (e.g., for error messages).
  static const Color error = Color(0xFFB00020);
}

/// Theme-aware status colors with accessible contrast.
@immutable
class AppStatusColors extends ThemeExtension<AppStatusColors> {
  /// Creates status colors.
  const AppStatusColors({
    required this.success,
    required this.warning,
    required this.error,
    required this.successContainer,
    required this.warningContainer,
    required this.errorContainer,
    required this.onStatus,
  });

  /// Accessible status colors for light surfaces.
  static const AppStatusColors light = AppStatusColors(
    success: AppColors.success,
    warning: AppColors.warning,
    error: AppColors.error,
    successContainer: Color(0xFFEAF8EC),
    warningContainer: Color(0xFFFFF4E5),
    errorContainer: Color(0xFFFCE8E8),
    onStatus: Colors.white,
  );

  /// Accessible status colors for dark surfaces.
  static const AppStatusColors dark = AppStatusColors(
    success: Color(0xFF81C784),
    warning: Color(0xFFFFB74D),
    error: Color(0xFFEF9A9A),
    successContainer: Color(0xFF153B1D),
    warningContainer: Color(0xFF3A2A12),
    errorContainer: Color(0xFF3E1C1C),
    onStatus: AppColors.textPrimary,
  );

  /// Success foreground/background color.
  final Color success;

  /// Warning foreground/background color.
  final Color warning;

  /// Error foreground/background color.
  final Color error;

  /// Low-emphasis success background.
  final Color successContainer;

  /// Low-emphasis warning background.
  final Color warningContainer;

  /// Low-emphasis error background.
  final Color errorContainer;

  /// Text/icon color on solid status backgrounds.
  final Color onStatus;

  /// Returns status colors from the current theme.
  static AppStatusColors of(BuildContext context) {
    final theme = Theme.of(context);
    final statusColors = theme.extension<AppStatusColors>();
    if (statusColors != null) return statusColors;
    return theme.brightness == Brightness.dark ? dark : light;
  }

  @override
  AppStatusColors copyWith({
    Color? success,
    Color? warning,
    Color? error,
    Color? successContainer,
    Color? warningContainer,
    Color? errorContainer,
    Color? onStatus,
  }) {
    return AppStatusColors(
      success: success ?? this.success,
      warning: warning ?? this.warning,
      error: error ?? this.error,
      successContainer: successContainer ?? this.successContainer,
      warningContainer: warningContainer ?? this.warningContainer,
      errorContainer: errorContainer ?? this.errorContainer,
      onStatus: onStatus ?? this.onStatus,
    );
  }

  @override
  AppStatusColors lerp(ThemeExtension<AppStatusColors>? other, double t) {
    if (other is! AppStatusColors) return this;
    return AppStatusColors(
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      error: Color.lerp(error, other.error, t)!,
      successContainer: Color.lerp(
        successContainer,
        other.successContainer,
        t,
      )!,
      warningContainer: Color.lerp(
        warningContainer,
        other.warningContainer,
        t,
      )!,
      errorContainer: Color.lerp(errorContainer, other.errorContainer, t)!,
      onStatus: Color.lerp(onStatus, other.onStatus, t)!,
    );
  }
}

/// App theme configuration.
class AppTheme {
  AppTheme._();

  /// Light theme configuration for the application.
  static ThemeData light({required double menuFontSize}) {
    return _buildTheme(
      brightness: Brightness.light,
      menuFontSize: menuFontSize,
      // Roles omitted here (onPrimary, surface, error) already equal their
      // token by the ColorScheme.light default; app_theme_test asserts the
      // full mapping, so a token change cannot silently diverge.
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        primaryContainer: AppColors.accentSoft,
        onPrimaryContainer: AppColors.primary,
        secondary: AppColors.primary,
        onSecondary: AppColors.onAccent,
        secondaryContainer: AppColors.hover,
        onSecondaryContainer: AppColors.textPrimary,
        onSurface: AppColors.textPrimary,
        onSurfaceVariant: AppColors.textSecondary,
        surfaceContainerLowest: AppColors.field,
        surfaceContainerHighest: AppColors.hover,
        surfaceTint: Colors.transparent,
        outline: AppColors.border,
      ),
      scaffoldBackgroundColor: AppColors.background,
      textColor: AppColors.textPrimary,
      mutedTextColor: AppColors.textSecondary,
      borderColor: AppColors.border,
      fieldColor: AppColors.field,
      solidActionColor: AppColors.primary,
      onSolidActionColor: AppColors.onAccent,
      snackBarBackground: AppColors.textPrimary,
      snackBarForeground: AppColors.background,
      statusColors: AppStatusColors.light,
    );
  }

  /// Dark theme configuration for the application.
  static ThemeData dark({required double menuFontSize}) {
    return _buildTheme(
      brightness: Brightness.dark,
      menuFontSize: menuFontSize,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.darkPrimary,
        onPrimary: AppColors.darkOnAccent,
        // Solid controls keep the saturated brand violet with white text so
        // they do not read as disabled against the dark surface.
        primaryContainer: AppColors.darkAccentSoft,
        onPrimaryContainer: AppColors.darkPrimary,
        secondary: AppColors.darkPrimary,
        onSecondary: AppColors.darkOnAccent,
        secondaryContainer: AppColors.darkHover,
        onSecondaryContainer: AppColors.darkTextPrimary,
        surface: AppColors.darkSurface,
        onSurface: AppColors.darkTextPrimary,
        onSurfaceVariant: AppColors.darkTextSecondary,
        surfaceContainerLowest: AppColors.darkField,
        surfaceContainerHighest: AppColors.darkHover,
        surfaceTint: Colors.transparent,
        outline: AppColors.darkBorder,
        error: Color(0xFFEF9A9A),
      ),
      scaffoldBackgroundColor: AppColors.darkBackground,
      textColor: AppColors.darkTextPrimary,
      mutedTextColor: AppColors.darkTextSecondary,
      borderColor: AppColors.darkBorder,
      fieldColor: AppColors.darkField,
      solidActionColor: AppColors.primary,
      onSolidActionColor: AppColors.onAccent,
      snackBarBackground: AppColors.darkToastSurface,
      snackBarForeground: AppColors.textPrimary,
      statusColors: AppStatusColors.dark,
    );
  }

  static ThemeData _buildTheme({
    required Brightness brightness,
    required double menuFontSize,
    required ColorScheme colorScheme,
    required Color scaffoldBackgroundColor,
    required Color textColor,
    required Color mutedTextColor,
    required Color borderColor,
    required Color fieldColor,
    required Color solidActionColor,
    required Color onSolidActionColor,
    required Color snackBarBackground,
    required Color snackBarForeground,
    required AppStatusColors statusColors,
  }) {
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      extensions: [statusColors],
      scaffoldBackgroundColor: scaffoldBackgroundColor,
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          side: BorderSide(color: borderColor),
        ),
        color: colorScheme.surface,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: fieldColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        hintStyle: TextStyle(color: mutedTextColor),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: solidActionColor,
          foregroundColor: onSolidActionColor,
          // Without these, Material falls back to onSurface at 12%/38%, which
          // measured 2.4:1 in light and 2.9:1 in dark — the disabled CTA read
          // as a hole in the layout rather than a button waiting for input.
          disabledBackgroundColor: borderColor,
          disabledForegroundColor: mutedTextColor,
          minimumSize: const Size(0, AppSizes.controlHeight),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          textStyle: TextStyle(
            fontSize: menuFontSize - 1,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textColor,
          side: BorderSide(color: borderColor),
          minimumSize: const Size(0, AppSizes.controlHeight),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.smPlus),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          textStyle: TextStyle(
            fontSize: menuFontSize - 1,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colorScheme.primary,
          minimumSize: const Size(0, AppSizes.controlHeight),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          textStyle: TextStyle(
            fontSize: menuFontSize - 1,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textTheme: TextTheme(
        headlineMedium: TextStyle(
          fontSize: menuFontSize + 8,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
        titleLarge: TextStyle(
          fontSize: menuFontSize + 4,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
        titleMedium: TextStyle(
          fontSize: menuFontSize + 2,
          fontWeight: FontWeight.w500,
          color: textColor,
        ),
        bodyMedium: TextStyle(
          fontSize: menuFontSize,
          height: 1.5,
          color: textColor,
        ),
        bodySmall: TextStyle(
          fontSize: menuFontSize - 2,
          color: mutedTextColor,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: borderColor,
        thickness: 1,
        space: 1,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          side: BorderSide(color: borderColor),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? colorScheme.onPrimary
              : colorScheme.surface,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? solidActionColor
              : colorScheme.surfaceContainerHighest,
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colorScheme.primary,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: colorScheme.primary,
        selectionColor: colorScheme.primaryContainer,
        selectionHandleColor: colorScheme.primary,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        width: AppSizes.toastWidth,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        backgroundColor: snackBarBackground,
        contentTextStyle: TextStyle(
          color: snackBarForeground,
          fontSize: menuFontSize - 1,
          fontWeight: FontWeight.w600,
        ),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbVisibility: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.hovered)) return true;
          if (states.contains(WidgetState.dragged)) return true;
          return false;
        }),
        thickness: WidgetStateProperty.all(8),
        radius: const Radius.circular(4),
        thumbColor: WidgetStateProperty.all(
          mutedTextColor.withValues(alpha: 0.5),
        ),
        trackVisibility: WidgetStateProperty.all(false),
      ),
    );
  }
}
