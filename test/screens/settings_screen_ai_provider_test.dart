import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:make_it_sound_natural/constants/app_defaults.dart';
import 'package:make_it_sound_natural/constants/method_channel_methods.dart';
import 'package:make_it_sound_natural/l10n/gen/app_localizations.dart';
import 'package:make_it_sound_natural/models/reasoning_effort.dart';
import 'package:make_it_sound_natural/screens/settings_screen.dart';
import 'package:make_it_sound_natural/services/live_model_catalog_service.dart';
import 'package:make_it_sound_natural/services/model_catalog_cache.dart';
import 'package:make_it_sound_natural/services/provider_models_client.dart';
import 'package:make_it_sound_natural/widgets/app_popup_select.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<MethodCall> methodCalls;
  late Map<String, String> secureValues;
  late LiveModelCatalogService originalCatalog;
  late List<http.Request> requests;
  late Future<http.Response> Function(http.Request) respond;

  const openAiFamilies = {
    'luna': 'gpt-6-luna',
    'terra': 'gpt-6.1-terra',
    'sol': 'gpt-6.1-sol',
    'astra': 'gpt-6-astra',
  };
  const anthropicFamilies = {
    'opus': 'claude-opus-5-5',
    'sonnet': 'claude-sonnet-5-5',
    'haiku': 'claude-haiku-5-5',
    'fable': 'claude-fable-5-1',
  };
  const migratedModel =
      '{"provider":"openrouter",'
      '"slug":"google/gemini-3-flash-preview"}';

  setUp(() {
    requests = [];
    respond = (request) async => http.Response(
      jsonEncode({
        'data': [
          for (final slug
              in (request.url.host == 'api.openai.com'
                      ? openAiFamilies
                      : anthropicFamilies)
                  .values)
            {'id': slug},
        ],
        'has_more': false,
      }),
      200,
    );
    originalCatalog = LiveModelCatalogService.shared;
    LiveModelCatalogService.shared = LiveModelCatalogService(
      client: ProviderModelsClient(
        client: MockClient((request) async {
          requests.add(request);
          return respond(request);
        }),
      ),
    );
  });

  void setupSettings({
    String? provider = 'openrouter',
    String? model = 'google/gemini-3-flash-preview',
    String openAiKey = 'openai-key',
    String openRouterKey = 'openrouter-key',
    String customProviderKey = 'custom-key',
    String anthropicKey = '',
    bool seedCatalog = true,
    bool seedOpenRouterModel = true,
    List<String> customProviders = const [],
    List<String> customModels = const [],
    List<String> hiddenModels = const [],
  }) {
    methodCalls = [];
    secureValues = {
      'openai': openAiKey,
      'openrouter': openRouterKey,
      'tokenguard': customProviderKey,
      AppDefaults.anthropicProvider: anthropicKey,
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
      if (seedOpenRouterModel || customModels.isNotEmpty)
        'llm_custom_models': [
          if (seedOpenRouterModel) migratedModel,
          ...customModels,
        ],
      if (seedCatalog)
        ModelCatalogCache.storageKey: jsonEncode({
          for (final entry in {
            AppDefaults.openAiProvider: openAiFamilies,
            AppDefaults.anthropicProvider: anthropicFamilies,
          }.entries)
            entry.key: {
              'fetchedAt': DateTime.now().toUtc().toIso8601String(),
              'families': entry.value,
            },
        }),
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
              case MethodChannelMethods.getStoredAnthropicApiKey:
                return secureValues[AppDefaults.anthropicProvider];
              case MethodChannelMethods.storeAnthropicApiKey:
                secureValues[AppDefaults.anthropicProvider] =
                    call.arguments as String;
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
    LiveModelCatalogService.shared.dispose();
    LiveModelCatalogService.shared = originalCatalog;
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

  testWidgets('reasoning picker persists all levels and restores selection', (
    tester,
  ) async {
    setupSettings();
    await pumpSettings(tester);
    final picker = find.byKey(const Key('apiProvider-reasoningPicker'));
    expect(
      tester.widget<AppPopupSelect<ReasoningEffort>>(picker).value,
      AppDefaults.reasoningEffort,
    );
    final labels = {
      ReasoningEffort.none: 'None',
      ReasoningEffort.low: 'Low (default)',
      ReasoningEffort.medium: 'Medium',
      ReasoningEffort.high: 'High',
    };
    for (final entry in labels.entries) {
      await tester.tap(picker);
      await tester.pumpAndSettle();
      await tester.tap(find.text(entry.value).last);
      await tester.pumpAndSettle();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('reasoning_effort'), entry.key.name);
      expect(
        methodCalls
            .lastWhere(
              (call) => call.method == MethodChannelMethods.setReasoningEffort,
            )
            .arguments,
        entry.key.name,
      );
    }
    await tester.pumpWidget(const SizedBox.shrink());
    await pumpSettings(tester);
    expect(
      tester.widget<AppPopupSelect<ReasoningEffort>>(picker).value,
      ReasoningEffort.high,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('reasoning change reports native failure without saving', (
    tester,
  ) async {
    setupSettings();
    await pumpSettings(tester);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel(MethodChannelMethods.channelName),
          (call) async => throw PlatformException(code: 'unavailable'),
        );
    await tester.tap(find.byKey(const Key('apiProvider-reasoningPicker')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('High').last);
    await tester.pumpAndSettle();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('reasoning_effort'), isNull);
    expect(
      find.text('Could not save reasoning effort. Try again.'),
      findsOneWidget,
    );
  });

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

  testWidgets(
    'a clean install shows Choose a model and the empty Models hint',
    (
      tester,
    ) async {
      setupSettings(
        provider: null,
        model: null,
        openAiKey: '',
        openRouterKey: '',
        seedCatalog: false,
        seedOpenRouterModel: false,
      );
      await pumpSettings(tester);

      final picker = tester.widget<AppPopupSelect<String>>(
        find.byKey(const Key('apiProvider-modelPicker')),
      );
      expect(picker.value, isNull);
      expect(find.text('Choose a model'), findsOneWidget);
      expect(find.text('No models yet'), findsOneWidget);
      expect(
        find.text(
          'Add an OpenAI or Anthropic API key to load models, '
          'or add a model manually.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('catalog rows are labelled From provider', (tester) async {
    setupSettings();
    await pumpSettings(tester);
    expect(find.text('OpenAI · From provider'), findsNWidgets(4));
    expect(find.text('Anthropic · From provider'), findsNWidgets(4));
  });

  testWidgets('opening AI provider settings loads a missing model list', (
    tester,
  ) async {
    setupSettings(
      seedCatalog: false,
      openAiKey: '',
      anthropicKey: 'anthropic-test-key',
    );
    await pumpSettings(tester);
    await tester.pumpAndSettle();

    expect(requests, hasLength(1));
    expect(requests.single.url.host, 'api.anthropic.com');
    expect(find.text('claude-opus-5-5'), findsOneWidget);
    expect(find.text('claude-fable-5-1'), findsOneWidget);
  });

  testWidgets('a delayed settings load keeps the refreshed catalog', (
    tester,
  ) async {
    setupSettings(provider: 'openai', model: 'gpt-6.1-sol');
    final firstKey = Completer<String>();
    var delayedFirstKey = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel(MethodChannelMethods.channelName),
          (call) async {
            methodCalls.add(call);
            switch (call.method) {
              case MethodChannelMethods.getStoredOpenRouterApiKey:
                if (!delayedFirstKey) {
                  delayedFirstKey = true;
                  return firstKey.future;
                }
                return secureValues['openrouter'];
              case MethodChannelMethods.getStoredApiKey:
                return secureValues['openai'];
              case MethodChannelMethods.getStoredAnthropicApiKey:
                return '';
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
    await pumpSettings(tester);
    expect(delayedFirstKey, isTrue);

    respond = (_) async => http.Response(
      jsonEncode({
        'data': [
          {'id': 'gpt-6.2-sol'},
        ],
      }),
      200,
    );
    await LiveModelCatalogService.shared.refresh(AppDefaults.openAiProvider);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    expect(requests, hasLength(1));
    final pickerFinder = find.byKey(const Key('apiProvider-modelPicker'));
    expect(
      tester.widget<AppPopupSelect<String>>(pickerFinder).value,
      'openai::gpt-6.2-sol',
    );

    firstKey.complete('openrouter-key');
    await tester.pumpAndSettle();

    final picker = tester.widget<AppPopupSelect<String>>(pickerFinder);
    expect(picker.value, 'openai::gpt-6.2-sol');
    expect(
      picker.options.whereType<AppPopupOption<String>>().map((o) => o.value),
      contains('openai::gpt-6.2-sol'),
    );
    expect(find.text('gpt-6.1-sol'), findsNothing);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('openai_model'), 'gpt-6.2-sol');
  });

  testWidgets('saving an Anthropic key loads its models', (tester) async {
    setupSettings(seedCatalog: false, openAiKey: '');
    await pumpSettings(tester);
    expect(find.text('claude-opus-5-5'), findsNothing);

    await tapRowAction(
      tester,
      const Key('apiProvider-keyButton-anthropic-messages'),
    );
    await tester.enterText(
      find.byKey(const Key('apiProvider-keyDialogField')),
      'anthropic-test-key',
    );
    await tester.tap(find.byKey(const Key('apiProvider-saveKey')));
    await tester.pumpAndSettle();

    expect(requests, hasLength(1));
    expect(find.text('claude-opus-5-5'), findsOneWidget);
    expect(find.text('claude-fable-5-1'), findsOneWidget);
  });

  testWidgets(
    'an existing Anthropic selection stays selected before the first fetch',
    (tester) async {
      setupSettings(
        provider: AppDefaults.anthropicProvider,
        model: 'claude-sonnet-5-5',
        seedCatalog: false,
        openAiKey: '',
        anthropicKey: 'anthropic-test-key',
      );
      respond = (_) async => throw http.ClientException('offline');
      await pumpSettings(tester);
      await tester.pumpAndSettle();

      final picker = tester.widget<AppPopupSelect<String>>(
        find.byKey(const Key('apiProvider-modelPicker')),
      );
      expect(picker.value, 'anthropic-messages::claude-sonnet-5-5');
      expect(find.text('claude-sonnet-5-5'), findsWidgets);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('api_provider'), AppDefaults.anthropicProvider);
      expect(prefs.getString('openai_model'), 'claude-sonnet-5-5');
    },
  );

  testWidgets('hiding the selected model clears the selection', (
    tester,
  ) async {
    setupSettings(provider: 'openai', model: 'gpt-6.1-sol');
    await pumpSettings(tester);
    await tapRowAction(
      tester,
      const Key('apiProvider-visibility-openai-gpt-6.1-sol'),
    );
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('api_provider'), 'openai');
    expect(prefs.getString('openai_model'), '');
    expect(
      methodCalls
          .lastWhere(
            (call) => call.method == MethodChannelMethods.setModel,
          )
          .arguments,
      '',
    );
  });

  testWidgets('deleting the selected custom model clears the selection', (
    tester,
  ) async {
    setupSettings(
      model: 'acme/writer',
      customModels: const ['{"provider":"openrouter","slug":"acme/writer"}'],
    );
    await pumpSettings(tester);
    await tapRowAction(
      tester,
      const Key('apiProvider-deleteModel-openrouter-acme/writer'),
    );
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('api_provider'), 'openrouter');
    expect(prefs.getString('openai_model'), '');
    expect(
      methodCalls
          .lastWhere(
            (call) => call.method == MethodChannelMethods.setModel,
          )
          .arguments,
      '',
    );
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
    await tester.tap(find.text('gpt-6.1-sol').last);
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('api_provider'), 'openai');
    expect(prefs.getString('openai_model'), 'gpt-6.1-sol');
  });

  testWidgets('picking a Claude model selects Anthropic and saves its key', (
    tester,
  ) async {
    setupSettings();
    await pumpSettings(tester);

    await tester.tap(find.byKey(const Key('apiProvider-modelPicker')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('claude-haiku-5-5').last);
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('api_provider'), AppDefaults.anthropicProvider);
    expect(prefs.getString('openai_model'), 'claude-haiku-5-5');
    expect(
      methodCalls
          .lastWhere((call) => call.method == MethodChannelMethods.setProvider)
          .arguments,
      AppDefaults.anthropicProvider,
    );

    await tapRowAction(
      tester,
      const Key('apiProvider-keyButton-anthropic-messages'),
    );
    await tester.enterText(
      find.byKey(const Key('apiProvider-keyDialogField')),
      'sk-ant-new',
    );
    await tester.tap(find.byKey(const Key('apiProvider-saveKey')));
    await tester.pumpAndSettle();

    final store = methodCalls.lastWhere(
      (call) => call.method == MethodChannelMethods.storeAnthropicApiKey,
    );
    expect(store.arguments, 'sk-ant-new');
    expect(secureValues[AppDefaults.anthropicProvider], 'sk-ant-new');
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
    expect(
      prefs.getStringList('llm_custom_models'),
      isNot(contains(contains('tokenguard'))),
    );
    expect(prefs.getString('api_provider'), AppDefaults.apiProvider);
    expect(prefs.getString('openai_model'), '');
    expect(
      methodCalls
          .lastWhere(
            (call) => call.method == MethodChannelMethods.setProvider,
          )
          .arguments,
      AppDefaults.apiProvider,
    );
    expect(
      methodCalls
          .lastWhere(
            (call) => call.method == MethodChannelMethods.setModel,
          )
          .arguments,
      '',
    );
  });

  testWidgets('adds a model through the shared dialog', (tester) async {
    setupSettings(seedOpenRouterModel: false);
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
      seedOpenRouterModel: false,
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

  testWidgets('hiding a catalog model stores its family id', (tester) async {
    setupSettings();
    await pumpSettings(tester);

    await tapRowAction(
      tester,
      const Key('apiProvider-visibility-openai-gpt-6.1-sol'),
    );

    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getStringList('llm_hidden_models'),
      contains('openai::family:sol'),
    );
  });

  testWidgets('keeps at least one model visible', (tester) async {
    // Every model is hidden except the migrated OpenRouter model.
    setupSettings(
      hiddenModels: const [
        'openai::family:luna',
        'openai::family:sol',
        'openai::family:terra',
        'openai::family:astra',
        'anthropic-messages::family:haiku',
        'anthropic-messages::family:sonnet',
        'anthropic-messages::family:opus',
        'anthropic-messages::family:fable',
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
    for (final scenario in ['gone', 'hidden', 'provider']) {
      final title = switch (scenario) {
        'gone' => 'shows Choose a model when the stored model is gone',
        'hidden' => 'shows Choose a model when the stored model is hidden',
        _ => 'shows Choose a model when the stored provider is gone',
      };
      testWidgets(title, (tester) async {
        final provider = scenario == 'provider' ? 'gone' : 'openrouter';
        final model = scenario == 'gone'
            ? 'removed/model'
            : 'google/gemini-3-flash-preview';
        setupSettings(
          provider: provider,
          model: model,
          hiddenModels: scenario == 'hidden'
              ? const ['openrouter::google/gemini-3-flash-preview']
              : const [],
        );
        await pumpSettings(tester);

        final picker = tester.widget<AppPopupSelect<String>>(
          find.byKey(const Key('apiProvider-modelPicker')),
        );
        expect(picker.value, isNull);
        expect(find.text('Choose a model'), findsOneWidget);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('api_provider'), provider);
        expect(prefs.getString('openai_model'), model);
      });
    }
  });

  testWidgets('loading settings never writes the selection', (tester) async {
    setupSettings(provider: 'openai', model: 'removed/model');
    await pumpSettings(tester);

    expect(
      methodCalls.where(
        (call) =>
            call.method == MethodChannelMethods.setProvider ||
            call.method == MethodChannelMethods.setModel,
      ),
      isEmpty,
    );
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('api_provider'), 'openai');
    expect(prefs.getString('openai_model'), 'removed/model');
  });

  testWidgets('picking a model pushes the pair to the native side', (
    tester,
  ) async {
    setupSettings();
    await pumpSettings(tester);

    await tester.tap(find.byKey(const Key('apiProvider-modelPicker')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('gpt-6.1-sol').last);
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
    expect(setModel.arguments, 'gpt-6.1-sol');
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

    testWidgets('editing the selected custom model keeps it selected', (
      tester,
    ) async {
      setupSettings(
        provider: 'tokenguard',
        model: 'acme/writer',
        seedOpenRouterModel: false,
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
      expect(
        methodCalls
            .lastWhere(
              (call) => call.method == MethodChannelMethods.setModel,
            )
            .arguments,
        'acme/writer-v2',
      );
      final picker = tester.widget<AppPopupSelect<String>>(
        find.byKey(const Key('apiProvider-modelPicker')),
      );
      expect(picker.value, 'tokenguard::acme/writer-v2');
    });
  });
}
