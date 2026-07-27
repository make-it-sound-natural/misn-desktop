import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:make_it_sound_natural/constants/app_defaults.dart';
import 'package:make_it_sound_natural/constants/method_channel_methods.dart';
import 'package:make_it_sound_natural/l10n/gen/app_localizations.dart';
import 'package:make_it_sound_natural/screens/settings_screen.dart';
import 'package:make_it_sound_natural/widgets/app_popup_select.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<MethodCall> methodCalls;
  late Map<String, String> secureValues;

  void setupSettings({
    String? provider = 'openrouter',
    String? model = 'google/gemini-3-flash-preview',
    String openAiKey = 'openai-key',
    String openRouterKey = 'openrouter-key',
    String customProviderKey = 'custom-key',
    List<String> customProviders = const [],
    List<String> customModels = const [],
    List<String> hiddenModels = const [],
  }) {
    methodCalls = [];
    secureValues = {
      'openai': openAiKey,
      'openrouter': openRouterKey,
      'tokenguard': customProviderKey,
    };
    final initialValues = <String, Object>{
      'app_shortcut': AppDefaults.correctionShortcut,
      'app_shortcut_replace': AppDefaults.replaceShortcut,
      'app_shortcut_append': AppDefaults.appendShortcut,
      'default_variant': AppDefaults.variant,
      'custom_prompt': '',
      'target_profile_selection_confirmed': true,
      'target_profile_selected_id': 'americanEnglish',
      if (customProviders.isNotEmpty) 'llm_custom_providers': customProviders,
      if (customModels.isNotEmpty) 'llm_custom_models': customModels,
      if (hiddenModels.isNotEmpty) 'llm_hidden_models': hiddenModels,
    };
    if (provider != null) {
      initialValues['api_provider'] = provider;
    }
    if (model != null) {
      initialValues['openai_model'] = model;
    }
    SharedPreferences.setMockInitialValues(initialValues);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel(MethodChannelMethods.channelName),
          (call) async {
            methodCalls.add(call);
            switch (call.method) {
              case MethodChannelMethods.getStoredApiKey:
                return secureValues['openai'];
              case MethodChannelMethods.getStoredOpenRouterApiKey:
                return secureValues['openrouter'];
              case MethodChannelMethods.storeApiKey:
                secureValues['openai'] = call.arguments as String;
                return null;
              case MethodChannelMethods.storeOpenRouterApiKey:
                secureValues['openrouter'] = call.arguments as String;
                return null;
              case MethodChannelMethods.getStoredCustomProviderApiKey:
                final args = Map<String, Object?>.from(call.arguments! as Map);
                return secureValues[args['provider']! as String] ?? '';
              case MethodChannelMethods.storeCustomProviderApiKey:
                final args = Map<String, Object?>.from(call.arguments! as Map);
                secureValues[args['provider']! as String] =
                    args['apiKey']! as String;
                return null;
              case MethodChannelMethods.deleteStoredCustomProviderApiKey:
                final args = Map<String, Object?>.from(call.arguments! as Map);
                secureValues.remove(args['provider']! as String);
                return null;
              case MethodChannelMethods.checkAccessibilityPermissions:
                return true;
              case MethodChannelMethods.getDefaultPrompt:
                return 'Default prompt';
              case 'getAppVersion':
                return {'version': '1.0.0', 'build': '1'};
              default:
                return null;
            }
          },
        );
  }

  Future<void> pumpSettings(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1536, 1024));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        locale: Locale('en'),
        home: SettingsScreen(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> openAddProviderDialog(WidgetTester tester) async {
    await tester.ensureVisible(
      find.byKey(const Key('apiProvider-addProvider')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('apiProvider-addProvider')));
    await tester.pumpAndSettle();
  }

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel(MethodChannelMethods.channelName),
          null,
        );
  });

  Future<void> openAddModelDialog(WidgetTester tester) async {
    await tester.ensureVisible(find.byKey(const Key('apiProvider-addModel')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('apiProvider-addModel')));
    await tester.pumpAndSettle();
  }

  Future<void> tapRowAction(WidgetTester tester, Key key) async {
    await tester.ensureVisible(find.byKey(key));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(key));
    await tester.pumpAndSettle();
  }

  testWidgets('renders the restructured AI Provider layout', (tester) async {
    setupSettings();
    await pumpSettings(tester);

    expect(find.byKey(const Key('apiProvider-modelPicker')), findsOneWidget);
    expect(find.text('Providers'), findsOneWidget);
    expect(find.text('Models'), findsOneWidget);
    expect(find.text('OpenRouter'), findsWidgets);
    expect(find.text('OpenAI'), findsWidgets);
    // The provider dropdown is gone: the model picker selects the provider.
    expect(find.byKey(const Key('apiProvider-providerSelector')), findsNothing);
  });

  testWidgets('defaults a clean install to OpenRouter and Gemini flash', (
    tester,
  ) async {
    setupSettings(provider: null, model: null);
    await pumpSettings(tester);

    final picker = tester.widget<AppPopupSelect<String>>(
      find.byKey(const Key('apiProvider-modelPicker')),
    );
    expect(picker.value, '${AppDefaults.apiProvider}::${AppDefaults.model}');
  });

  testWidgets('provider rows show key status inline', (tester) async {
    setupSettings(openAiKey: '');
    await pumpSettings(tester);

    expect(find.textContaining('API key set'), findsWidgets);
    expect(find.textContaining('No API key'), findsWidgets);
  });

  testWidgets('key button opens the per-provider Keychain modal', (
    tester,
  ) async {
    setupSettings();
    await pumpSettings(tester);

    await tapRowAction(tester, const Key('apiProvider-keyButton-openrouter'));

    expect(find.byKey(const Key('apiProvider-keyDialogField')), findsOneWidget);
    expect(
      find.textContaining('stored locally in the macOS Keychain'),
      findsOneWidget,
    );
    // A saved key is never shown again: the field starts empty.
    expect(
      tester.widget<TextField>(find.byType(TextField).last).controller?.text,
      isEmpty,
    );
  });

  testWidgets('saving a key from the modal persists it', (tester) async {
    setupSettings(openRouterKey: '');
    await pumpSettings(tester);

    await tapRowAction(tester, const Key('apiProvider-keyButton-openrouter'));
    await tester.enterText(
      find.byKey(const Key('apiProvider-keyDialogField')),
      'sk-or-new-key',
    );
    await tester.tap(find.byKey(const Key('apiProvider-saveKey')));
    await tester.pumpAndSettle();

    expect(secureValues['openrouter'], 'sk-or-new-key');
  });

  testWidgets('shows the auth failure note for the selected provider', (
    tester,
  ) async {
    setupSettings();
    SharedPreferences.setMockInitialValues({
      'api_provider': 'openrouter',
      'openai_model': 'google/gemini-3-flash-preview',
      'target_profile_selection_confirmed': true,
      'target_profile_selected_id': 'americanEnglish',
      'provider_auth_failure_openrouter': jsonEncode({
        'provider': 'openrouter',
        'message': 'invalid_api_key',
        'occurredAt': DateTime.utc(2026).toIso8601String(),
      }),
    });
    await pumpSettings(tester);

    expect(find.textContaining('invalid_api_key'), findsOneWidget);

    // Fixing the key must clear the note; a stale banner would tell the user
    // their working key is still rejected.
    await tapRowAction(tester, const Key('apiProvider-keyButton-openrouter'));
    await tester.enterText(
      find.byKey(const Key('apiProvider-keyDialogField')),
      'sk-or-fixed',
    );
    await tester.tap(find.byKey(const Key('apiProvider-saveKey')));
    await tester.pumpAndSettle();

    expect(find.textContaining('invalid_api_key'), findsNothing);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('provider_auth_failure_openrouter'), isNull);
  });

  testWidgets('picking a model selects its provider and persists both', (
    tester,
  ) async {
    setupSettings();
    await pumpSettings(tester);

    await tester.tap(find.byKey(const Key('apiProvider-modelPicker')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('gpt-5.4-mini').last);
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('api_provider'), 'openai');
    expect(prefs.getString('openai_model'), 'gpt-5.4-mini');
  });

  testWidgets('adds a custom provider without requiring a model', (
    tester,
  ) async {
    setupSettings();
    await pumpSettings(tester);

    await openAddProviderDialog(tester);
    await tester.enterText(
      find.byKey(const Key('apiProvider-providerNameField')),
      'TokenGuard',
    );
    await tester.enterText(
      find.byKey(const Key('apiProvider-providerBaseUrlField')),
      'https://tokenguard.int.agrd.dev/api/v1',
    );
    await tester.tap(find.byKey(const Key('apiProvider-saveProvider')));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(find.text('TokenGuard'), findsWidgets);
    expect(
      prefs.getStringList('llm_custom_providers')!.single,
      contains('"id":"tokenguard"'),
    );
  });

  testWidgets('provider validation errors surface inline in the dialog', (
    tester,
  ) async {
    setupSettings();
    await pumpSettings(tester);

    await openAddProviderDialog(tester);
    await tester.enterText(
      find.byKey(const Key('apiProvider-providerBaseUrlField')),
      'https://tokenguard.int.agrd.dev/api/v1',
    );
    await tester.tap(find.byKey(const Key('apiProvider-saveProvider')));
    await tester.pumpAndSettle();

    expect(find.text('Provider name is required.'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('apiProvider-providerNameField')),
      'TokenGuard',
    );
    await tester.enterText(
      find.byKey(const Key('apiProvider-providerBaseUrlField')),
      'not-a-url',
    );
    await tester.tap(find.byKey(const Key('apiProvider-saveProvider')));
    await tester.pumpAndSettle();

    expect(find.text('Base URL must be a valid HTTPS URL.'), findsOneWidget);
  });

  testWidgets('deleting a provider cascades to its models and the picker', (
    tester,
  ) async {
    setupSettings(
      provider: 'tokenguard',
      model: 'acme/custom-writer-1',
      customProviders: [
        jsonEncode({
          'id': 'tokenguard',
          'displayName': 'TokenGuard',
          'baseUrl': 'https://tokenguard.int.agrd.dev/api/v1',
          'isBuiltIn': false,
        }),
      ],
      customModels: [
        jsonEncode({
          'provider': 'tokenguard',
          'slug': 'acme/custom-writer-1',
          'isBuiltIn': false,
          'isHidden': false,
        }),
      ],
    );
    await pumpSettings(tester);

    await tapRowAction(
      tester,
      const Key('apiProvider-deleteProvider-tokenguard'),
    );
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(find.text('TokenGuard'), findsNothing);
    expect(prefs.getStringList('llm_custom_models') ?? const [], isEmpty);
    // The picker re-points at a model that still exists.
    expect(prefs.getString('openai_model'), isNot('acme/custom-writer-1'));
    expect(prefs.getString('openai_model'), isNotEmpty);
  });

  testWidgets('adds a model through the shared dialog', (tester) async {
    setupSettings();
    await pumpSettings(tester);

    await openAddModelDialog(tester);
    await tester.enterText(
      find.byKey(const Key('apiProvider-modelDialogSlug')),
      'openai/gpt-test',
    );
    await tester.tap(find.byKey(const Key('apiProvider-saveModel')));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getStringList('llm_custom_models')!.single,
      contains('"slug":"openai/gpt-test"'),
    );
  });

  testWidgets('blocks a duplicate slug within the same provider', (
    tester,
  ) async {
    setupSettings(
      customModels: [
        jsonEncode({
          'provider': 'openrouter',
          'slug': 'acme/writer',
          'isBuiltIn': false,
          'isHidden': false,
        }),
      ],
    );
    await pumpSettings(tester);

    await openAddModelDialog(tester);
    await tester.enterText(
      find.byKey(const Key('apiProvider-modelDialogSlug')),
      'acme/writer',
    );
    await tester.tap(find.byKey(const Key('apiProvider-saveModel')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('apiProvider-modelDialogError')),
      findsOneWidget,
    );
  });

  testWidgets('deletes a custom model after confirmation', (tester) async {
    setupSettings(
      customModels: [
        jsonEncode({
          'provider': 'openrouter',
          'slug': 'acme/writer',
          'isBuiltIn': false,
          'isHidden': false,
        }),
      ],
    );
    await pumpSettings(tester);

    await tapRowAction(
      tester,
      const Key('apiProvider-deleteModel-openrouter-acme/writer'),
    );
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('llm_custom_models') ?? const [], isEmpty);
  });

  testWidgets('eye toggles picker visibility for a model', (tester) async {
    setupSettings();
    await pumpSettings(tester);

    await tapRowAction(
      tester,
      const Key('apiProvider-visibility-openai-gpt-5.4-mini'),
    );

    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getStringList('llm_hidden_models'),
      contains('openai::gpt-5.4-mini'),
    );
  });

  testWidgets('keeps at least one model visible', (tester) async {
    // Every model hidden except the single remaining OpenRouter built-in.
    setupSettings(
      hiddenModels: const [
        'openai::gpt-5.4-nano',
        'openai::gpt-5.4-mini',
        'openai::gpt-5.4',
        'openai::gpt-5.5',
      ],
    );
    await pumpSettings(tester);

    // The control refuses up front rather than accepting the press and then
    // showing a toast: a disabled button is the discoverable form of "no".
    const eye = Key(
      'apiProvider-visibility-openrouter-google/gemini-3-flash-preview',
    );
    await tester.ensureVisible(find.byKey(eye));
    await tester.pumpAndSettle();
    expect(tester.widget<IconButton>(find.byKey(eye)).onPressed, isNull);
    expect(
      tester.widget<IconButton>(find.byKey(eye)).tooltip,
      'At least one model must remain visible.',
    );

    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getStringList('llm_hidden_models') ?? const [],
      isNot(contains('openrouter::google/gemini-3-flash-preview')),
    );
  });

  testWidgets('shows target language only in Language settings', (
    tester,
  ) async {
    setupSettings();
    await pumpSettings(tester);

    expect(find.text('Target Language'), findsNothing);

    await tester.tap(find.byKey(const Key('settingsNav-language')));
    await tester.pumpAndSettle();

    expect(find.text('Target Language'), findsOneWidget);
  });

  group('stale persisted selection', () {
    // Regression: these three fallbacks ship in `_resolveSelection`, and the
    // suite lost their coverage when this screen was restructured. A stale
    // save must repair itself rather than leave the picker blank.
    testWidgets('falls back when the stored model is gone', (tester) async {
      setupSettings(model: 'removed/model');
      await pumpSettings(tester);

      final picker = tester.widget<AppPopupSelect<String>>(
        find.byKey(const Key('apiProvider-modelPicker')),
      );
      expect(picker.value, 'openrouter::google/gemini-3-flash-preview');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('openai_model'), 'google/gemini-3-flash-preview');
    });

    testWidgets('falls back when the stored model is hidden', (tester) async {
      // OpenRouter ships exactly one built-in model, so hiding it leaves that
      // provider with nothing visible and the fallback has to cross providers.
      setupSettings(
        hiddenModels: const ['openrouter::google/gemini-3-flash-preview'],
      );
      await pumpSettings(tester);

      final picker = tester.widget<AppPopupSelect<String>>(
        find.byKey(const Key('apiProvider-modelPicker')),
      );
      expect(picker.value, 'openai::gpt-5.4-nano');

      // The provider must travel with the model it fell back to.
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('api_provider'), 'openai');
      expect(prefs.getString('openai_model'), 'gpt-5.4-nano');
    });

    testWidgets('keeps the provider when the same provider still has one', (
      tester,
    ) async {
      setupSettings(
        provider: 'openai',
        model: 'gpt-5.4-mini',
        hiddenModels: const ['openai::gpt-5.4-mini'],
      );
      await pumpSettings(tester);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('api_provider'), 'openai');
      expect(prefs.getString('openai_model'), 'gpt-5.4-nano');
    });

    testWidgets('falls back when the stored provider is gone', (tester) async {
      setupSettings(provider: 'gone');
      await pumpSettings(tester);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('api_provider'), AppDefaults.apiProvider);
    });

    testWidgets('never persists a model from another provider', (
      tester,
    ) async {
      // `_resolveSelection` may cross providers to find a visible model; when
      // it does, the provider it writes must be that model's owner.
      setupSettings(provider: 'openai', model: 'removed/model');
      await pumpSettings(tester);

      final prefs = await SharedPreferences.getInstance();
      final provider = prefs.getString('api_provider')!;
      final model = prefs.getString('openai_model')!;
      final picker = tester.widget<AppPopupSelect<String>>(
        find.byKey(const Key('apiProvider-modelPicker')),
      );
      expect(picker.value, '$provider::$model');
    });
  });

  testWidgets('picking a model pushes the pair to the native side', (
    tester,
  ) async {
    setupSettings();
    await pumpSettings(tester);

    await tester.tap(find.byKey(const Key('apiProvider-modelPicker')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('gpt-5.4-mini').last);
    await tester.pumpAndSettle();

    // Dropping either call leaves the native LLM path on the old provider
    // while prefs and the UI both look correct.
    final setProvider = methodCalls.lastWhere(
      (call) => call.method == MethodChannelMethods.setProvider,
    );
    final setModel = methodCalls.lastWhere(
      (call) => call.method == MethodChannelMethods.setModel,
    );
    expect(setProvider.arguments, 'openai');
    expect(setModel.arguments, 'gpt-5.4-mini');
  });

  group('edit paths', () {
    const tokenGuard =
        '{"id":"tokenguard","displayName":"TokenGuard",'
        '"baseUrl":"https://tokenguard.int.agrd.dev/api/v1"}';

    testWidgets('editing a provider pre-fills and saves the new name', (
      tester,
    ) async {
      setupSettings(customProviders: const [tokenGuard]);
      await pumpSettings(tester);

      await tapRowAction(
        tester,
        const Key('apiProvider-editProvider-tokenguard'),
      );

      final nameField = tester.widget<TextField>(
        find.descendant(
          of: find.byKey(const Key('apiProvider-providerNameField')),
          matching: find.byType(TextField),
        ),
      );
      expect(nameField.controller?.text, 'TokenGuard');

      await tester.enterText(
        find.byKey(const Key('apiProvider-providerNameField')),
        'TokenGuard EU',
      );
      await tester.tap(find.byKey(const Key('apiProvider-saveProvider')));
      await tester.pumpAndSettle();

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getStringList('llm_custom_providers')!.single,
        contains('TokenGuard EU'),
      );
    });

    testWidgets('renaming the selected model keeps the picker valid', (
      tester,
    ) async {
      setupSettings(
        provider: 'tokenguard',
        model: 'acme/writer',
        customProviders: const [tokenGuard],
        customModels: const [
          '{"provider":"tokenguard","slug":"acme/writer"}',
        ],
      );
      await pumpSettings(tester);

      await tapRowAction(
        tester,
        const Key('apiProvider-editModel-tokenguard-acme/writer'),
      );
      await tester.enterText(
        find.byKey(const Key('apiProvider-modelDialogSlug')),
        'acme/writer-v2',
      );
      await tester.tap(find.byKey(const Key('apiProvider-saveModel')));
      await tester.pumpAndSettle();

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getStringList('llm_custom_models')!.single,
        contains('"slug":"acme/writer-v2"'),
      );
      // The picker must still point at something that exists.
      expect(prefs.getString('openai_model'), 'acme/writer-v2');
      final picker = tester.widget<AppPopupSelect<String>>(
        find.byKey(const Key('apiProvider-modelPicker')),
      );
      expect(picker.value, 'tokenguard::acme/writer-v2');
    });
  });
}
