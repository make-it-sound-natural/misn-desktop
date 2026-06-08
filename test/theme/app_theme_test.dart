import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:make_it_sound_natural/models/appearance_preferences.dart';
import 'package:make_it_sound_natural/theme/app_theme.dart';

void main() {
  group('AppTheme', () {
    test('maps appearance theme mode to Material ThemeMode', () {
      expect(
        AppearanceThemeMode.system.materialThemeMode,
        ThemeMode.system,
      );
      expect(AppearanceThemeMode.light.materialThemeMode, ThemeMode.light);
      expect(AppearanceThemeMode.dark.materialThemeMode, ThemeMode.dark);
    });

    test('uses menu font size in light and dark text themes', () {
      final light = AppTheme.light(menuFontSize: 18);
      final dark = AppTheme.dark(menuFontSize: 18);

      expect(light.textTheme.bodyMedium?.fontSize, 18);
      expect(dark.textTheme.bodyMedium?.fontSize, 18);
      expect(dark.brightness, Brightness.dark);
    });

    test('uses dark snackbar surface in dark mode', () {
      final dark = AppTheme.dark(menuFontSize: 14);
      final background = dark.snackBarTheme.backgroundColor!;
      final textColor = dark.snackBarTheme.contentTextStyle!.color!;

      expect(background, AppColors.darkControlSurface);
      expect(_contrastRatio(textColor, background), greaterThanOrEqualTo(4.5));
    });

    test('status colors keep normal text readable', () {
      final light = AppTheme.light(menuFontSize: 14);
      final dark = AppTheme.dark(menuFontSize: 14);
      final lightStatus = light.extension<AppStatusColors>()!;
      final darkStatus = dark.extension<AppStatusColors>()!;

      for (final color in [
        lightStatus.success,
        lightStatus.warning,
        lightStatus.error,
      ]) {
        expect(
          _contrastRatio(color, light.colorScheme.surface),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          _contrastRatio(lightStatus.onStatus, color),
          greaterThanOrEqualTo(4.5),
        );
      }

      for (final color in [
        darkStatus.success,
        darkStatus.warning,
        darkStatus.error,
      ]) {
        expect(
          _contrastRatio(color, dark.colorScheme.surface),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          _contrastRatio(darkStatus.onStatus, color),
          greaterThanOrEqualTo(4.5),
        );
      }
    });
  });
}

double _contrastRatio(Color foreground, Color background) {
  final foregroundLuminance = foreground.computeLuminance();
  final backgroundLuminance = background.computeLuminance();
  final light = foregroundLuminance > backgroundLuminance
      ? foregroundLuminance
      : backgroundLuminance;
  final dark = foregroundLuminance > backgroundLuminance
      ? backgroundLuminance
      : foregroundLuminance;
  return (light + 0.05) / (dark + 0.05);
}
