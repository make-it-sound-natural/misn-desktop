import 'package:flutter_test/flutter_test.dart';
import 'package:make_it_sound_natural/constants/app_defaults.dart';
import 'package:make_it_sound_natural/models/appearance_preferences.dart';

void main() {
  group('AppearancePreferences', () {
    test('uses version one defaults', () {
      const prefs = AppearancePreferences.defaults();

      expect(prefs.schemaVersion, AppDefaults.appearanceSchemaVersion);
      expect(prefs.themeMode, AppearanceThemeMode.system);
      expect(prefs.menuFontSize, AppDefaults.menuFontSize);
      expect(prefs.editorFontSize, AppDefaults.editorFontSize);
    });

    test('round trips json', () {
      const prefs = AppearancePreferences(
        schemaVersion: 1,
        themeMode: AppearanceThemeMode.dark,
        menuFontSize: 17,
        editorFontSize: 19,
      );

      expect(AppearancePreferences.fromJson(prefs.toJson()), prefs);
    });

    test('falls back for unknown theme and schema', () {
      final prefs = AppearancePreferences.fromJson(const {
        AppearancePreferences.schemaVersionField: 99,
        AppearancePreferences.themeModeField: 'future',
        AppearancePreferences.menuFontSizeField: 17,
        AppearancePreferences.editorFontSizeField: 18,
      });

      expect(prefs, const AppearancePreferences.defaults());
    });

    test('clamps out of range font sizes', () {
      final prefs = AppearancePreferences.fromJson(const {
        AppearancePreferences.schemaVersionField: 1,
        AppearancePreferences.themeModeField: 'light',
        AppearancePreferences.menuFontSizeField: 2,
        AppearancePreferences.editorFontSizeField: 99,
      });

      expect(prefs.menuFontSize, AppDefaults.menuFontSizeMin);
      expect(prefs.editorFontSize, AppDefaults.editorFontSizeMax);
    });
  });
}
