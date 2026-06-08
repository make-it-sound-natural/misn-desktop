import 'package:flutter/material.dart';
import 'package:make_it_sound_natural/constants/app_defaults.dart';

/// Theme modes available in Appearance settings.
enum AppearanceThemeMode {
  /// Follow the current macOS appearance.
  system('system'),

  /// Always use light appearance.
  light('light'),

  /// Always use dark appearance.
  dark('dark');

  const AppearanceThemeMode(this.value);

  /// Persisted value.
  final String value;

  /// Returns a known theme mode, falling back to system.
  static AppearanceThemeMode fromValue(Object? value) {
    for (final mode in values) {
      if (mode.value == value) return mode;
    }
    return system;
  }

  /// Converts to Flutter's theme mode.
  ThemeMode get materialThemeMode {
    return switch (this) {
      AppearanceThemeMode.system => ThemeMode.system,
      AppearanceThemeMode.light => ThemeMode.light,
      AppearanceThemeMode.dark => ThemeMode.dark,
    };
  }
}

/// Versioned local appearance settings.
@immutable
class AppearancePreferences {
  /// Creates appearance preferences.
  const AppearancePreferences({
    required this.schemaVersion,
    required this.themeMode,
    required this.menuFontSize,
    required this.editorFontSize,
  });

  /// Creates default appearance preferences.
  const AppearancePreferences.defaults()
    : schemaVersion = AppDefaults.appearanceSchemaVersion,
      themeMode = AppearanceThemeMode.system,
      menuFontSize = AppDefaults.menuFontSize,
      editorFontSize = AppDefaults.editorFontSize;

  /// Decodes and validates persisted preferences.
  factory AppearancePreferences.fromJson(Map<String, Object?> json) {
    final schemaVersion = json[schemaVersionField];
    if (schemaVersion != AppDefaults.appearanceSchemaVersion) {
      return const AppearancePreferences.defaults();
    }

    return AppearancePreferences(
      schemaVersion: AppDefaults.appearanceSchemaVersion,
      themeMode: AppearanceThemeMode.fromValue(json[themeModeField]),
      menuFontSize: _clampDouble(
        json[menuFontSizeField],
        AppDefaults.menuFontSizeMin,
        AppDefaults.menuFontSizeMax,
        AppDefaults.menuFontSize,
      ),
      editorFontSize: _clampDouble(
        json[editorFontSizeField],
        AppDefaults.editorFontSizeMin,
        AppDefaults.editorFontSizeMax,
        AppDefaults.editorFontSize,
      ),
    );
  }

  /// JSON field for schema version.
  static const String schemaVersionField = 'schemaVersion';

  /// JSON field for theme mode.
  static const String themeModeField = 'themeMode';

  /// JSON field for menu/UI font size.
  static const String menuFontSizeField = 'menuFontSize';

  /// JSON field for editor/context text font size.
  static const String editorFontSizeField = 'editorFontSize';

  /// Local schema version for future migrations.
  final int schemaVersion;

  /// Selected app theme mode.
  final AppearanceThemeMode themeMode;

  /// Base size for navigation, settings, buttons, and labels.
  final double menuFontSize;

  /// Base size for rewrite editor and context input text.
  final double editorFontSize;

  /// Encodes preferences for SharedPreferences.
  Map<String, Object?> toJson() {
    return {
      schemaVersionField: schemaVersion,
      themeModeField: themeMode.value,
      menuFontSizeField: menuFontSize,
      editorFontSizeField: editorFontSize,
    };
  }

  /// Returns updated preferences.
  AppearancePreferences copyWith({
    AppearanceThemeMode? themeMode,
    double? menuFontSize,
    double? editorFontSize,
  }) {
    return AppearancePreferences(
      schemaVersion: schemaVersion,
      themeMode: themeMode ?? this.themeMode,
      menuFontSize: _clampDouble(
        menuFontSize ?? this.menuFontSize,
        AppDefaults.menuFontSizeMin,
        AppDefaults.menuFontSizeMax,
        AppDefaults.menuFontSize,
      ),
      editorFontSize: _clampDouble(
        editorFontSize ?? this.editorFontSize,
        AppDefaults.editorFontSizeMin,
        AppDefaults.editorFontSizeMax,
        AppDefaults.editorFontSize,
      ),
    );
  }

  static double _clampDouble(
    Object? value,
    double min,
    double max,
    double fallback,
  ) {
    final parsed = switch (value) {
      final num number => number.toDouble(),
      final String text => double.tryParse(text) ?? fallback,
      _ => fallback,
    };
    if (parsed.isNaN || parsed.isInfinite) return fallback;
    if (parsed < min) return min;
    if (parsed > max) return max;
    return parsed;
  }

  @override
  bool operator ==(Object other) {
    return other is AppearancePreferences &&
        other.schemaVersion == schemaVersion &&
        other.themeMode == themeMode &&
        other.menuFontSize == menuFontSize &&
        other.editorFontSize == editorFontSize;
  }

  @override
  int get hashCode {
    return Object.hash(
      schemaVersion,
      themeMode,
      menuFontSize,
      editorFontSize,
    );
  }
}
