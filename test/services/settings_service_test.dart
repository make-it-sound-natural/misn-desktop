import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:make_it_sound_natural/constants/app_defaults.dart';
import 'package:make_it_sound_natural/constants/method_channel_methods.dart';
import 'package:make_it_sound_natural/models/appearance_preferences.dart';
import 'package:make_it_sound_natural/models/screenshot_context_mode.dart';
import 'package:make_it_sound_natural/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SettingsService', () {
    const channel = MethodChannel(MethodChannelMethods.channelName);

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('uses centralized default settings when values are absent', () async {
      final service = SettingsService();

      expect(AppDefaults.apiProvider, AppDefaults.openRouterProvider);
      expect(AppDefaults.model, 'google/gemini-3-flash-preview');
      expect(await service.getProvider(), AppDefaults.apiProvider);
      expect(await service.getModel(), AppDefaults.model);
      expect(await service.getDefaultVariant(), AppDefaults.variant);
      expect(await service.getShortcut(), AppDefaults.correctionShortcut);
      expect(await service.getReplaceShortcut(), AppDefaults.replaceShortcut);
      expect(await service.getAppendShortcut(), AppDefaults.appendShortcut);
      expect(
        await service.getScreenshotContextMode(),
        AppDefaults.screenshotContextMode,
      );
      expect(
        await service.getAppearancePreferences(),
        const AppearancePreferences.defaults(),
      );
    });

    test('persists appearance preferences in one versioned object', () async {
      final service = SettingsService();
      const preferences = AppearancePreferences(
        schemaVersion: AppDefaults.appearanceSchemaVersion,
        themeMode: AppearanceThemeMode.dark,
        menuFontSize: 16,
        editorFontSize: 18,
      );

      await service.setAppearancePreferences(preferences);

      final prefs = await SharedPreferences.getInstance();
      final rawValue = prefs.getString(AppDefaults.appearancePreferencesKey);
      expect(rawValue, isNotNull);
      expect(
        jsonDecode(rawValue!) as Map<String, Object?>,
        preferences.toJson(),
      );
      expect(await service.getAppearancePreferences(), preferences);
    });

    test('falls back for invalid appearance json', () async {
      SharedPreferences.setMockInitialValues({
        AppDefaults.appearancePreferencesKey: jsonEncode({
          AppearancePreferences.schemaVersionField:
              AppDefaults.appearanceSchemaVersion,
          AppearancePreferences.themeModeField: 'future',
        }),
      });
      final service = SettingsService();

      expect(
        await service.getAppearancePreferences(),
        const AppearancePreferences.defaults(),
      );
    });

    test('resets shortcuts to defaults', () async {
      SharedPreferences.setMockInitialValues({
        'app_shortcut': 'cmd+shift+a',
        'app_shortcut_replace': 'cmd+shift+b',
        'app_shortcut_append': 'cmd+shift+c',
      });
      final service = SettingsService();

      await service.resetShortcutsToDefaults();

      expect(await service.getShortcut(), AppDefaults.correctionShortcut);
      expect(
        await service.getReplaceShortcut(),
        AppDefaults.replaceShortcut,
      );
      expect(await service.getAppendShortcut(), AppDefaults.appendShortcut);
    });

    test('resets appearance preferences', () async {
      final service = SettingsService();
      await service.setAppearancePreferences(
        const AppearancePreferences(
          schemaVersion: AppDefaults.appearanceSchemaVersion,
          themeMode: AppearanceThemeMode.dark,
          menuFontSize: 17,
          editorFontSize: 19,
        ),
      );

      await service.resetAppearancePreferences();

      expect(
        await service.getAppearancePreferences(),
        const AppearancePreferences.defaults(),
      );
    });

    test('falls back to off for unknown screenshot context mode', () async {
      SharedPreferences.setMockInitialValues({
        'screenshot_context_mode': 'futureMode',
      });
      final service = SettingsService();

      expect(
        await service.getScreenshotContextMode(),
        AppDefaults.screenshotContextMode,
      );
    });

    test('persists screenshot context mode', () async {
      final service = SettingsService();

      await service.setScreenshotContextMode(
        ScreenshotContextMode.activeApplication,
      );

      expect(
        await service.getScreenshotContextMode(),
        ScreenshotContextMode.activeApplication,
      );
    });

    test(
      'returns null when pending screenshot context is absent or off',
      () async {
        final service = SettingsService();

        expect(await service.getPendingScreenshotContextMode(), isNull);

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('pending_screenshot_context_mode', 'off');

        expect(await service.getPendingScreenshotContextMode(), isNull);
      },
    );

    test('persists and clears pending screenshot context mode', () async {
      final service = SettingsService();

      await service.setPendingScreenshotContextMode(
        ScreenshotContextMode.fullScreen,
      );

      expect(
        await service.getPendingScreenshotContextMode(),
        ScreenshotContextMode.fullScreen,
      );

      await service.clearPendingScreenshotContextMode();

      expect(await service.getPendingScreenshotContextMode(), isNull);
    });

    test('ignores unknown pending screenshot context mode', () async {
      SharedPreferences.setMockInitialValues({
        'pending_screenshot_context_mode': 'futureMode',
      });
      final service = SettingsService();

      expect(await service.getPendingScreenshotContextMode(), isNull);
    });

    test('migrates legacy OpenAI API key to secure storage', () async {
      SharedPreferences.setMockInitialValues({
        'openai_api_key': 'legacy-openai-key',
      });
      final secureValues = <String, String>{};
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            switch (call.method) {
              case MethodChannelMethods.getStoredApiKey:
                return secureValues['openai'];
              case MethodChannelMethods.storeApiKey:
                secureValues['openai'] = call.arguments as String;
                return null;
            }
            throw MissingPluginException();
          });

      final service = SettingsService();

      expect(await service.getApiKey(), 'legacy-openai-key');
      expect(secureValues['openai'], 'legacy-openai-key');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('openai_api_key'), isNull);
    });

    test('stores OpenRouter API key outside shared preferences', () async {
      final secureValues = <String, String>{};
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            switch (call.method) {
              case MethodChannelMethods.storeOpenRouterApiKey:
                secureValues['openrouter'] = call.arguments as String;
                return null;
            }
            throw MissingPluginException();
          });

      final service = SettingsService();
      await service.setOpenRouterApiKey('openrouter-key');

      expect(secureValues['openrouter'], 'openrouter-key');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('openrouter_api_key'), isNull);
    });

    test('checks OpenAI key for active OpenAI provider', () async {
      SharedPreferences.setMockInitialValues({
        'api_provider': 'openai',
        'openai_api_key': 'openai-key',
        'openrouter_api_key': '',
      });
      final service = SettingsService();

      expect(await service.hasApiKeyForActiveProvider(), isTrue);
    });

    test('checks OpenRouter key for active OpenRouter provider', () async {
      SharedPreferences.setMockInitialValues({
        'api_provider': 'openrouter',
        'openai_api_key': '',
        'openrouter_api_key': 'openrouter-key',
      });
      final service = SettingsService();

      expect(await service.hasApiKeyForActiveProvider(), isTrue);
    });

    test('treats whitespace-only active provider key as missing', () async {
      SharedPreferences.setMockInitialValues({
        'api_provider': 'openrouter',
        'openai_api_key': 'openai-key',
        'openrouter_api_key': '   ',
      });
      final service = SettingsService();

      expect(await service.hasApiKeyForActiveProvider(), isFalse);
    });

    test('records provider auth failure without storing the API key', () async {
      final service = SettingsService();

      await service.recordProviderAuthFailure(
        provider: AppDefaults.openRouterProvider,
        message: 'Invalid API key. Check settings.',
      );

      final failure = await service.getProviderAuthFailure(
        AppDefaults.openRouterProvider,
      );
      expect(failure?.provider, AppDefaults.openRouterProvider);
      expect(failure?.message, 'Invalid API key. Check settings.');
      expect(await service.getProviderAuthFailure('openai'), isNull);
    });

    test('changing provider key clears matching auth failure', () async {
      final service = SettingsService();
      await service.recordProviderAuthFailure(
        provider: AppDefaults.openRouterProvider,
        message: 'Invalid API key. Check settings.',
      );

      await service.setOpenRouterApiKey('new-openrouter-key');

      expect(
        await service.getProviderAuthFailure(AppDefaults.openRouterProvider),
        isNull,
      );
    });
  });
}
