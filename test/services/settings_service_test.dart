import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:make_it_sound_natural/constants/app_defaults.dart';
import 'package:make_it_sound_natural/constants/method_channel_methods.dart';
import 'package:make_it_sound_natural/models/accessibility_context_mode.dart';
import 'package:make_it_sound_natural/models/appearance_preferences.dart';
import 'package:make_it_sound_natural/models/reasoning_effort.dart';
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
        await service.getAccessibilityContextMode(),
        AppDefaults.accessibilityContextMode,
      );
      expect(
        await service.getAppearancePreferences(),
        const AppearancePreferences.defaults(),
      );
    });

    test(
      'reasoning defaults safely for absent and unknown saved values',
      () async {
        final service = SettingsService();
        expect(await service.getReasoningEffort(), AppDefaults.reasoningEffort);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('reasoning_effort', 'retired-level');
        expect(await service.getReasoningEffort(), AppDefaults.reasoningEffort);
      },
    );

    test('restores every reasoning level from persisted settings', () async {
      for (final effort in ReasoningEffort.values) {
        await SettingsService().setReasoningEffort(effort);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('reasoning_effort'), effort.name);
        expect(await SettingsService().getReasoningEffort(), effort);
      }
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

    test('persists accessibility context mode', () async {
      final service = SettingsService();

      await service.setAccessibilityContextMode(
        AccessibilityContextMode.fieldAndNearby,
      );

      expect(
        await service.getAccessibilityContextMode(),
        AccessibilityContextMode.fieldAndNearby,
      );
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('accessibility_context_mode'), 'fieldAndNearby');
    });

    test('falls back to off for unknown accessibility context mode', () async {
      SharedPreferences.setMockInitialValues({
        'accessibility_context_mode': 'futureMode',
      });
      final service = SettingsService();

      expect(
        await service.getAccessibilityContextMode(),
        AccessibilityContextMode.off,
      );
    });

    group('accessibility context migration (v1 -> v2)', () {
      Future<AccessibilityContextMode> migrate(
        Map<String, Object> stored,
      ) async {
        SharedPreferences.setMockInitialValues(stored);
        final service = SettingsService();
        await service.migrateIfNeeded();
        return service.getAccessibilityContextMode();
      }

      test('fresh install starts with field text only', () async {
        expect(await migrate({}), AccessibilityContextMode.field);

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getInt('settings_schema_version'), 2);
      });

      test('upgrade with screenshot off gets field', () async {
        final mode = await migrate({
          'settings_schema_version': 1,
          'screenshot_context_mode': 'off',
        });

        expect(mode, AccessibilityContextMode.field);
      });

      test('upgrade with screenshot on gets field and nearby', () async {
        for (final screenshotMode in ['activeApplication', 'fullScreen']) {
          final mode = await migrate({
            'settings_schema_version': 1,
            'screenshot_context_mode': screenshotMode,
          });

          expect(mode, AccessibilityContextMode.fieldAndNearby);
        }
      });

      test('upgrade with pending screenshot gets field and nearby', () async {
        final mode = await migrate({
          'settings_schema_version': 1,
          'screenshot_context_mode': 'off',
          'pending_screenshot_context_mode': 'fullScreen',
        });

        expect(mode, AccessibilityContextMode.fieldAndNearby);
      });

      test('unknown screenshot values count as off', () async {
        final mode = await migrate({
          'settings_schema_version': 1,
          'screenshot_context_mode': 'futureMode',
          'pending_screenshot_context_mode': 'futureMode',
        });

        expect(mode, AccessibilityContextMode.field);
      });

      test('keeps a mode that is already stored', () async {
        final mode = await migrate({
          'settings_schema_version': 1,
          'screenshot_context_mode': 'fullScreen',
          'accessibility_context_mode': 'off',
        });

        expect(mode, AccessibilityContextMode.off);
      });

      test('keeps an unknown stored mode as off at read time', () async {
        final mode = await migrate({
          'settings_schema_version': 1,
          'screenshot_context_mode': 'fullScreen',
          'accessibility_context_mode': 'futureMode',
        });

        expect(mode, AccessibilityContextMode.off);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('accessibility_context_mode'), 'futureMode');
      });

      test('does not run again once the schema is at v2', () async {
        final mode = await migrate({
          'settings_schema_version': 2,
          'screenshot_context_mode': 'fullScreen',
        });

        expect(mode, AccessibilityContextMode.off);
      });
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
      await service.setOpenRouterApiKey('  openrouter-key  ');

      expect(secureValues['openrouter'], 'openrouter-key');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('openrouter_api_key'), isNull);
    });

    test('stores custom provider API key outside shared preferences', () async {
      final secureValues = <String, String>{};
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            switch (call.method) {
              case MethodChannelMethods.storeCustomProviderApiKey:
                final args = Map<String, Object?>.from(call.arguments! as Map);
                secureValues[args['provider']! as String] =
                    args['apiKey']! as String;
                return null;
              case MethodChannelMethods.getStoredCustomProviderApiKey:
                final args = Map<String, Object?>.from(call.arguments! as Map);
                return secureValues[args['provider']! as String] ?? '';
            }
            throw MissingPluginException();
          });

      final service = SettingsService();
      await service.setCustomProviderApiKey('tokenguard', '  secret-key  ');

      expect(await service.getCustomProviderApiKey('tokenguard'), 'secret-key');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('custom_provider_api_key_tokenguard'), isNull);
    });

    test('trims OpenAI API key before secure storage', () async {
      final secureValues = <String, String>{};
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            switch (call.method) {
              case MethodChannelMethods.storeApiKey:
                secureValues['openai'] = call.arguments as String;
                return null;
              case MethodChannelMethods.getStoredApiKey:
                return secureValues['openai'];
            }
            throw MissingPluginException();
          });

      final service = SettingsService();
      await service.setApiKey('  openai-key  ');

      expect(secureValues['openai'], 'openai-key');
      expect(await service.getApiKey(), 'openai-key');
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

    test('checks custom key for active custom provider', () async {
      SharedPreferences.setMockInitialValues({
        'api_provider': 'tokenguard',
      });
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method ==
                MethodChannelMethods.getStoredCustomProviderApiKey) {
              return 'custom-key';
            }
            throw MissingPluginException();
          });
      final service = SettingsService();

      expect(await service.hasApiKeyForActiveProvider(), isTrue);
    });

    test(
      'requires visible model for active custom provider readiness',
      () async {
        SharedPreferences.setMockInitialValues({
          'api_provider': 'tokenguard',
          'llm_custom_providers': [
            jsonEncode({
              'id': 'tokenguard',
              'displayName': 'TokenGuard',
              'baseUrl': 'https://tokenguard.int.agrd.dev/api/v1',
              'isBuiltIn': false,
            }),
          ],
        });
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async {
              if (call.method ==
                  MethodChannelMethods.getStoredCustomProviderApiKey) {
                return 'custom-key';
              }
              throw MissingPluginException();
            });
        final service = SettingsService();

        expect(await service.hasReadyActiveProviderForRewrite(), isFalse);
      },
    );

    test(
      'accepts custom provider readiness with key and visible model',
      () async {
        SharedPreferences.setMockInitialValues({
          'api_provider': 'tokenguard',
          'llm_custom_models': [
            jsonEncode({
              'provider': 'tokenguard',
              'slug': 'kimi-k2.6',
              'isBuiltIn': false,
              'isHidden': false,
            }),
          ],
        });
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async {
              if (call.method ==
                  MethodChannelMethods.getStoredCustomProviderApiKey) {
                return 'custom-key';
              }
              throw MissingPluginException();
            });
        final service = SettingsService();

        expect(await service.hasReadyActiveProviderForRewrite(), isTrue);
      },
    );

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

    test('custom provider auth failure is provider scoped', () async {
      final secureValues = <String, String>{};
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            switch (call.method) {
              case MethodChannelMethods.storeCustomProviderApiKey:
                final args = Map<String, Object?>.from(call.arguments! as Map);
                secureValues[args['provider']! as String] =
                    args['apiKey']! as String;
                return null;
            }
            throw MissingPluginException();
          });
      final service = SettingsService();

      await service.recordProviderAuthFailure(
        provider: 'tokenguard',
        message: 'Invalid API key. Check settings.',
      );

      expect(
        (await service.getProviderAuthFailure('tokenguard'))?.message,
        'Invalid API key. Check settings.',
      );

      await service.setCustomProviderApiKey('tokenguard', 'new-key');

      expect(await service.getProviderAuthFailure('tokenguard'), isNull);
      expect(secureValues['tokenguard'], 'new-key');
    });
  });
}
