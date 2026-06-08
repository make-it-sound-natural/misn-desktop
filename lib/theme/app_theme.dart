import 'package:flutter/material.dart';

/// App color palette derived from the "Wave Unity" logo.
class AppColors {
  AppColors._();

  // Primary Palette
  /// Primary brand color (purple).
  static const Color primary = Color(0xFF8E24AA);

  /// Secondary brand color (blue).
  static const Color secondary = Color(0xFF1E88E5);

  // Accent Gradient Colors (Purple → Blue)
  /// Starting color for the accent gradient (purple).
  static const Color gradientStart = Color(0xFF8E24AA);

  /// Ending color for the accent gradient (blue).
  static const Color gradientEnd = Color(0xFF1E88E5);

  // Neutral Palette
  /// Background color for the app scaffold.
  static const Color background = Color(0xFFF8F9FD);

  /// Surface color for cards and containers.
  static const Color surface = Color(0xFFFFFFFF);

  /// Primary text color for main content.
  static const Color textPrimary = Color(0xFF1C1C1E);

  /// Secondary text color for less prominent content.
  static const Color textSecondary = Color(0xFF666666);

  /// Border color for dividers and container edges.
  static const Color border = Color(0xFFE0E0E0);

  /// Dark app scaffold background.
  static const Color darkBackground = Color(0xFF111113);

  /// Dark surface color.
  static const Color darkSurface = Color(0xFF1C1C1E);

  /// Dark form control surface color.
  static const Color darkControlSurface = Color(0xFF332D35);

  /// Dark primary brand color.
  static const Color darkPrimary = Color(0xFFDDA7F0);

  /// Dark secondary brand color.
  static const Color darkSecondary = Color(0xFF90CAF9);

  /// Dark secondary text color.
  static const Color darkTextSecondary = Color(0xFFC7C7CC);

  /// Dark border color.
  static const Color darkBorder = Color(0xFF3A3A3C);

  // Status Colors
  /// Success state color (e.g., for positive feedback).
  static const Color success = Color(0xFF1B5E20);

  /// Warning state color (e.g., for cautionary messages).
  static const Color warning = Color(0xFF8A4B00);

  /// Error state color (e.g., for error messages).
  static const Color error = Color(0xFFB00020);

  /// Professional accent gradient (Purple → Blue).
  static const LinearGradient accentGradient = LinearGradient(
    colors: [gradientStart, gradientEnd],
  );
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
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        surface: AppColors.surface,
        primary: AppColors.primary,
        secondary: AppColors.secondary,
      ),
      scaffoldBackgroundColor: AppColors.background,
      textColor: AppColors.textPrimary,
      mutedTextColor: AppColors.textSecondary,
      borderColor: AppColors.border,
      statusColors: AppStatusColors.light,
    );
  }

  /// Dark theme configuration for the application.
  static ThemeData dark({required double menuFontSize}) {
    return _buildTheme(
      brightness: Brightness.dark,
      menuFontSize: menuFontSize,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.dark,
        surface: AppColors.darkSurface,
        primary: AppColors.darkPrimary,
        secondary: AppColors.darkSecondary,
        error: const Color(0xFFEF9A9A),
      ),
      scaffoldBackgroundColor: AppColors.darkBackground,
      textColor: Colors.white,
      mutedTextColor: AppColors.darkTextSecondary,
      borderColor: AppColors.darkBorder,
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
    required AppStatusColors statusColors,
  }) {
    final isDark = brightness == Brightness.dark;
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      extensions: [statusColors],
      scaffoldBackgroundColor: scaffoldBackgroundColor,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: textColor,
          fontSize: menuFontSize + 3,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(color: textColor),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: borderColor),
        ),
        color: colorScheme.surface,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? AppColors.darkControlSurface : colorScheme.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        hintStyle: TextStyle(color: mutedTextColor),
      ),
      textTheme: TextTheme(
        headlineLarge: TextStyle(
          fontSize: menuFontSize + 14,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
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
        bodyLarge: TextStyle(
          fontSize: menuFontSize + 2,
          height: 1.5,
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
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: isDark
            ? AppColors.darkControlSurface
            : AppColors.textPrimary,
        contentTextStyle: const TextStyle(color: Colors.white),
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
