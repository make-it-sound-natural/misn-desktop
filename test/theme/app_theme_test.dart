import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:make_it_sound_natural/models/appearance_preferences.dart';
import 'package:make_it_sound_natural/theme/app_design_tokens.dart';
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

    test('snackbar text stays readable in both themes', () {
      for (final theme in [
        AppTheme.light(menuFontSize: 14),
        AppTheme.dark(menuFontSize: 14),
      ]) {
        final background = theme.snackBarTheme.backgroundColor!;
        final textColor = theme.snackBarTheme.contentTextStyle!.color!;

        expect(
          _contrastRatio(textColor, background),
          greaterThanOrEqualTo(4.5),
        );
      }
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

  group('redesign tokens', () {
    test('core light tokens match the design token table', () {
      expect(AppColors.background, const Color(0xFFF8F9FD));
      expect(AppColors.surface, const Color(0xFFFFFFFF));
      expect(AppColors.textPrimary, const Color(0xFF1C1C1E));
      expect(AppColors.textSecondary, const Color(0xFF5B6478));
      expect(AppColors.border, const Color(0xFFE0E0E0));
      expect(AppColors.field, const Color(0xFFFFFFFF));
      expect(AppColors.hover, const Color(0xFFF2F2F6));
      expect(AppColors.primary, const Color(0xFF8E24AA));
      expect(AppColors.onAccent, const Color(0xFFFFFFFF));
      expect(AppColors.accentSoft, const Color(0xFFF8EDFB));
      expect(AppColors.skeleton, const Color(0xFFECECF1));
    });

    test('core dark tokens match the design token table', () {
      expect(AppColors.darkBackground, const Color(0xFF111113));
      expect(AppColors.darkSurface, const Color(0xFF1C1C1E));
      expect(AppColors.darkTextPrimary, const Color(0xFFF2F2F7));
      expect(AppColors.darkTextSecondary, const Color(0xFFC7C7CC));
      expect(AppColors.darkBorder, const Color(0xFF3A3A3C));
      expect(AppColors.darkField, const Color(0xFF242427));
      expect(AppColors.darkHover, const Color(0xFF26262B));
      expect(AppColors.darkPrimary, const Color(0xFFDDA7F0));
      expect(AppColors.darkOnAccent, const Color(0xFF2A1236));
      expect(AppColors.darkAccentSoft, const Color(0xFF34203F));
      expect(AppColors.darkSkeleton, const Color(0xFF26262B));
    });

    test('status colors are unchanged (accessibility law wins)', () {
      expect(AppStatusColors.light.warning, const Color(0xFF8A4B00));
      expect(AppStatusColors.dark.warning, const Color(0xFFFFB74D));
    });

    test('light theme uses an explicit neutral scheme, no seed tints', () {
      final theme = AppTheme.light(menuFontSize: 14);
      final scheme = theme.colorScheme;

      expect(scheme.primary, AppColors.primary);
      expect(scheme.onPrimary, AppColors.onAccent);
      expect(scheme.primaryContainer, AppColors.accentSoft);
      expect(scheme.surfaceContainerHighest, AppColors.hover);
      expect(scheme.surfaceContainerLowest, AppColors.field);
      expect(scheme.secondaryContainer, AppColors.hover);
      expect(scheme.onSurfaceVariant, AppColors.textSecondary);
      expect(scheme.surfaceTint, Colors.transparent);
      expect(theme.snackBarTheme.width, AppSizes.toastWidth);
      expect(theme.snackBarTheme.backgroundColor, AppColors.textPrimary);
    });

    test('dark theme mirrors the dark token column', () {
      final theme = AppTheme.dark(menuFontSize: 14);
      final scheme = theme.colorScheme;

      expect(scheme.primary, AppColors.darkPrimary);
      expect(scheme.onPrimary, AppColors.darkOnAccent);
      expect(scheme.primaryContainer, AppColors.darkAccentSoft);
      expect(scheme.surfaceContainerHighest, AppColors.darkHover);
      expect(scheme.surfaceContainerLowest, AppColors.darkField);
      expect(scheme.onSurface, AppColors.darkTextPrimary);
      expect(scheme.surfaceTint, Colors.transparent);
      expect(theme.snackBarTheme.backgroundColor, const Color(0xFFE8E8ED));
    });

    test('muted text keeps 4.5:1 on every surface it lands on', () {
      // `textSecondary` was darkened off the mockup's #667085 because that
      // value measured 4.46:1 on `hover` and 4.24:1 on `accentSoft` — the two
      // surfaces this test used not to cover, so the rationale in the token's
      // dartdoc was unenforced.
      for (final background in [
        AppColors.surface,
        AppColors.background,
        AppColors.hover,
        AppColors.accentSoft,
      ]) {
        expect(
          _contrastRatio(AppColors.textSecondary, background),
          greaterThanOrEqualTo(4.5),
          reason: 'muted text on $background',
        );
      }

      for (final background in [
        AppColors.darkSurface,
        AppColors.darkBackground,
        AppColors.darkHover,
        AppColors.darkAccentSoft,
      ]) {
        expect(
          _contrastRatio(AppColors.darkTextSecondary, background),
          greaterThanOrEqualTo(4.5),
          reason: 'dark muted text on $background',
        );
      }
    });

    test('status text keeps 4.5:1 on its own container', () {
      // Banners tint their text with the status colour and sit on the
      // matching container, a pairing nothing used to check.
      for (final theme in [
        AppTheme.light(menuFontSize: 14),
        AppTheme.dark(menuFontSize: 14),
      ]) {
        final status = theme.extension<AppStatusColors>()!;
        final pairs = [
          (status.success, status.successContainer),
          (status.warning, status.warningContainer),
          (status.error, status.errorContainer),
        ];
        for (final (foreground, background) in pairs) {
          expect(
            _contrastRatio(foreground, background),
            greaterThanOrEqualTo(4.5),
            reason: 'status $foreground on $background',
          );
        }
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
