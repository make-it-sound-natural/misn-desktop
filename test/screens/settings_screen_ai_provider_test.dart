import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:make_it_sound_natural/constants/app_defaults.dart';
import 'package:make_it_sound_natural/constants/method_channel_methods.dart';
import 'package:make_it_sound_natural/l10n/gen/app_localizations.dart';
import 'package:make_it_sound_natural/screens/settings_screen.dart';
import 'package:make_it_sound_natural/theme/app_theme.dart';
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

  String? textFieldError(WidgetTester tester, Key key) {
    return tester.widget<TextField>(find.byKey(key)).decoration?.errorText;
  }

  Future<void> pumpDarkSettings(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1536, 1024));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        theme: AppTheme.light(menuFontSize: AppDefaults.menuFontSize),
        darkTheme: AppTheme.dark(menuFontSize: AppDefaults.menuFontSize),
        themeMode: ThemeMode.dark,
        home: const SettingsScreen(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
  }

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel(MethodChannelMethods.channelName),
          null,
        );
  });

  testWidgets('renders screenshot AI Provider layout by default', (
    tester,
  ) async {
    setupSettings();
    await pumpSettings(tester);

    expect(find.text('Make It Sound Natural'), findsOneWidget);
    expect(find.text('Rewrite'), findsOneWidget);
    expect(find.text('Settings'), findsWidgets);
    expect(find.text('Shortcuts'), findsOneWidget);
    expect(find.text('Writing'), findsOneWidget);
    expect(find.text('Language'), findsOneWidget);
    expect(find.text('AI Provider'), findsWidgets);
    expect(find.text('Updates'), findsOneWidget);
    expect(find.text('Advanced'), findsOneWidget);
    expect(find.byKey(const Key('settingsNav-aiProvider')), findsOneWidget);
    expect(
      tester.getTopLeft(find.byKey(const Key('settingsNav-aiProvider'))).dy,
      lessThan(
        tester.getTopLeft(find.byKey(const Key('settingsNav-writing'))).dy,
      ),
    );
    final selectedContainers = tester.widgetList<Container>(
      find.descendant(
        of: find.byKey(const Key('settingsNav-aiProvider')),
        matching: find.byType(Container),
      ),
    );
    expect(
      selectedContainers.any((container) {
        final decoration = container.decoration;
        return decoration is BoxDecoration &&
            decoration.color == const Color(0xFFF0EAFE);
      }),
      isTrue,
    );
    expect(find.text('Choose your AI provider'), findsOneWidget);
    expect(find.text('Stored locally in Keychain'), findsOneWidget);
    expect(find.text('Used for rewrite generation'), findsOneWidget);
    expect(find.text('Test Connection'), findsNothing);
    expect(
      find.text(
        'Your API key is stored securely in macOS Keychain and is never sent '
        'by the app.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('defaults clean install to OpenRouter and Gemini flash', (
    tester,
  ) async {
    setupSettings(provider: null, model: null);
    await pumpSettings(tester);

    final providerField = tester.widget<DropdownButtonFormField<String>>(
      find.byKey(const Key('apiProvider-providerSelector')),
    );
    final modelField = tester.widget<DropdownButtonFormField<String>>(
      find.byKey(const Key('apiProvider-modelSelector')),
    );

    expect(providerField.initialValue, 'openrouter');
    expect(modelField.initialValue, 'google/gemini-3-flash-preview');

    await tester.tap(find.byKey(const Key('apiProvider-providerSelector')));
    await tester.pumpAndSettle();
    final openRouterTop = tester.getTopLeft(find.text('OpenRouter').last);
    final openAiTop = tester.getTopLeft(find.text('OpenAI').last);
    expect(openRouterTop.dy, lessThan(openAiTop.dy));
  });

  testWidgets('obscures and reveals the active provider API key', (
    tester,
  ) async {
    setupSettings(openRouterKey: 'sk-or-secret');
    await pumpSettings(tester);

    var field = tester.widget<TextField>(
      find.byKey(const Key('apiProvider-apiKeyField')),
    );
    expect(field.obscureText, isTrue);

    await tester.tap(find.byKey(const Key('apiProvider-toggleApiKey')));
    await tester.pump();

    field = tester.widget<TextField>(
      find.byKey(const Key('apiProvider-apiKeyField')),
    );
    expect(field.obscureText, isFalse);
    expect(find.text('sk-or-secret'), findsOneWidget);
  });

  testWidgets('shows auth failure near OpenRouter API key', (tester) async {
    setupSettings();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'provider_auth_failure_openrouter',
      jsonEncode({
        'provider': 'openrouter',
        'message': 'Invalid API key. Check settings.',
        'occurredAt': DateTime.utc(2026, 6, 8).toIso8601String(),
      }),
    );

    await pumpSettings(tester);

    expect(find.text('API key needs attention'), findsOneWidget);
    expect(find.text('Invalid API key. Check settings.'), findsOneWidget);
    expect(
      find.byKey(const Key('apiProvider-apiKeyAuthFailure')),
      findsOneWidget,
    );
  });

  testWidgets('editing API key clears auth failure message', (tester) async {
    setupSettings();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'provider_auth_failure_openrouter',
      jsonEncode({
        'provider': 'openrouter',
        'message': 'Invalid API key. Check settings.',
        'occurredAt': DateTime.utc(2026, 6, 8).toIso8601String(),
      }),
    );

    await pumpSettings(tester);
    await tester.enterText(
      find.byKey(const Key('apiProvider-apiKeyField')),
      'sk-or-new',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.text('API key needs attention'), findsNothing);
    expect(prefs.getString('provider_auth_failure_openrouter'), isNull);
  });

  testWidgets('switches provider and persists first model for provider', (
    tester,
  ) async {
    setupSettings();
    await pumpSettings(tester);

    await tester.tap(find.byKey(const Key('apiProvider-providerSelector')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OpenAI').last);
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('api_provider'), 'openai');
    expect(prefs.getString('openai_model'), 'gpt-5.4-nano');
    expect(
      methodCalls.where((call) => call.method == MethodChannelMethods.setModel),
      isNotEmpty,
    );
  });

  testWidgets('falls back when stored model is invalid for provider', (
    tester,
  ) async {
    setupSettings(model: 'removed/model');
    await pumpSettings(tester);

    final modelField = tester.widget<DropdownButtonFormField<String>>(
      find.byKey(const Key('apiProvider-modelSelector')),
    );
    expect(modelField.initialValue, 'google/gemini-3-flash-preview');
  });

  testWidgets('shows custom OpenRouter model in model selector', (
    tester,
  ) async {
    setupSettings(
      model: 'anthropic/claude-sonnet-4.6',
      customModels: [
        jsonEncode({
          'provider': 'openrouter',
          'slug': 'anthropic/claude-sonnet-4.6',
          'isBuiltIn': false,
          'isHidden': false,
        }),
      ],
    );
    await pumpSettings(tester);

    final modelField = tester.widget<DropdownButtonFormField<String>>(
      find.byKey(const Key('apiProvider-modelSelector')),
    );
    expect(modelField.initialValue, 'anthropic/claude-sonnet-4.6');
    expect(find.text('anthropic/claude-sonnet-4.6'), findsWidgets);
  });

  testWidgets('falls back when stored OpenRouter model is hidden', (
    tester,
  ) async {
    setupSettings(
      customModels: [
        jsonEncode({
          'provider': 'openrouter',
          'slug': 'anthropic/claude-sonnet-4.6',
          'isBuiltIn': false,
          'isHidden': false,
        }),
      ],
      hiddenModels: const [
        'openrouter::google/gemini-3-flash-preview',
      ],
    );
    await pumpSettings(tester);

    final modelField = tester.widget<DropdownButtonFormField<String>>(
      find.byKey(const Key('apiProvider-modelSelector')),
    );
    expect(modelField.initialValue, 'anthropic/claude-sonnet-4.6');
  });

  testWidgets('hides and shows OpenRouter models from management panel', (
    tester,
  ) async {
    setupSettings(
      customModels: [
        jsonEncode({
          'provider': 'openrouter',
          'slug': 'anthropic/claude-sonnet-4.6',
          'isBuiltIn': false,
          'isHidden': false,
        }),
      ],
    );
    await pumpSettings(tester);

    expect(
      find.byKey(const Key('apiProvider-modelManagementPanel')),
      findsOneWidget,
    );
    expect(find.text('google/gemini-3-flash-preview'), findsWidgets);

    await tester.tap(
      find.byKey(
        const Key(
          'apiProvider-hideModel-openrouter::google/gemini-3-flash-preview',
        ),
      ),
    );
    await tester.pumpAndSettle();

    var modelField = tester.widget<DropdownButtonFormField<String>>(
      find.byKey(const Key('apiProvider-modelSelector')),
    );
    expect(modelField.initialValue, 'anthropic/claude-sonnet-4.6');
    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getStringList('llm_hidden_models'),
      contains('openrouter::google/gemini-3-flash-preview'),
    );

    await tester.tap(
      find.byKey(
        const Key(
          'apiProvider-showModel-openrouter::google/gemini-3-flash-preview',
        ),
      ),
    );
    await tester.pumpAndSettle();

    modelField = tester.widget<DropdownButtonFormField<String>>(
      find.byKey(const Key('apiProvider-modelSelector')),
    );
    expect(modelField.initialValue, 'anthropic/claude-sonnet-4.6');
    expect(prefs.getStringList('llm_hidden_models') ?? [], isEmpty);
  });

  testWidgets('uses readable dark colors for OpenRouter model names', (
    tester,
  ) async {
    setupSettings();
    await pumpDarkSettings(tester);

    final modelText = tester
        .widgetList<Text>(
          find.text('google/gemini-3-flash-preview'),
        )
        .where((text) => text.style != null);
    final modelColors = modelText.map((text) => text.style!.color).nonNulls;

    expect(modelColors.any((color) => color.computeLuminance() > 0.6), isTrue);
    expect(
      modelColors.any((color) => color == const Color(0xFF101828)),
      isFalse,
    );
  });

  testWidgets('adds edits and deletes custom OpenRouter model', (
    tester,
  ) async {
    setupSettings();
    await pumpSettings(tester);

    await tester.tap(find.byKey(const Key('apiProvider-addOpenRouterModel')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('apiProvider-modelSlugField')),
      ' anthropic/claude-sonet-4.6 ',
    );
    await tester.tap(find.byKey(const Key('apiProvider-saveModelSlug')));
    await tester.pumpAndSettle();

    expect(find.text('anthropic/claude-sonet-4.6'), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(
        const Key(
          'apiProvider-editModel-openrouter::anthropic/claude-sonet-4.6',
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(
        const Key(
          'apiProvider-editModel-openrouter::anthropic/claude-sonet-4.6',
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('apiProvider-modelSlugField')),
      'anthropic/claude-sonnet-4.6',
    );
    await tester.tap(find.byKey(const Key('apiProvider-saveModelSlug')));
    await tester.pumpAndSettle();

    expect(find.text('anthropic/claude-sonnet-4.6'), findsOneWidget);
    expect(find.text('anthropic/claude-sonet-4.6'), findsNothing);

    await tester.ensureVisible(
      find.byKey(
        const Key(
          'apiProvider-deleteModel-openrouter::anthropic/claude-sonnet-4.6',
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(
        const Key(
          'apiProvider-deleteModel-openrouter::anthropic/claude-sonnet-4.6',
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('apiProvider-confirmDeleteModel')));
    await tester.pumpAndSettle();

    expect(find.text('anthropic/claude-sonnet-4.6'), findsNothing);
  });

  testWidgets('blocks duplicate custom OpenRouter model slug', (
    tester,
  ) async {
    setupSettings();
    await pumpSettings(tester);

    await tester.tap(find.byKey(const Key('apiProvider-addOpenRouterModel')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('apiProvider-modelSlugField')),
      'google/gemini-3-flash-preview',
    );
    await tester.tap(find.byKey(const Key('apiProvider-saveModelSlug')));
    await tester.pumpAndSettle();

    expect(find.text('A model with this slug already exists.'), findsOneWidget);
  });

  testWidgets('adds custom provider without requiring model', (tester) async {
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
    expect(prefs.getStringList('llm_custom_providers'), isNotNull);
    expect(
      prefs.getStringList('llm_custom_providers')!.single,
      contains('"id":"tokenguard"'),
    );
  });

  testWidgets('shows missing provider name error on provider name field', (
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

    expect(
      textFieldError(
        tester,
        const Key('apiProvider-providerNameField'),
      ),
      'Provider name is required.',
    );
    expect(
      textFieldError(
        tester,
        const Key('apiProvider-providerBaseUrlField'),
      ),
      isNull,
    );
  });

  testWidgets('shows missing provider URL error on base URL field', (
    tester,
  ) async {
    setupSettings();
    await pumpSettings(tester);

    await openAddProviderDialog(tester);
    await tester.enterText(
      find.byKey(const Key('apiProvider-providerNameField')),
      'TokenGuard',
    );
    await tester.tap(find.byKey(const Key('apiProvider-saveProvider')));
    await tester.pumpAndSettle();

    expect(
      textFieldError(
        tester,
        const Key('apiProvider-providerNameField'),
      ),
      isNull,
    );
    expect(
      textFieldError(
        tester,
        const Key('apiProvider-providerBaseUrlField'),
      ),
      'Base URL is required.',
    );
  });

  testWidgets('shows invalid provider URL error on base URL field', (
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
      'http://tokenguard.int.agrd.dev/api/v1',
    );
    await tester.tap(find.byKey(const Key('apiProvider-saveProvider')));
    await tester.pumpAndSettle();

    expect(
      textFieldError(
        tester,
        const Key('apiProvider-providerNameField'),
      ),
      isNull,
    );
    expect(
      textFieldError(
        tester,
        const Key('apiProvider-providerBaseUrlField'),
      ),
      'Base URL must be a valid HTTPS URL.',
    );
  });

  testWidgets('selecting custom provider with no models clears stale model', (
    tester,
  ) async {
    setupSettings(
      customProviders: [
        jsonEncode({
          'id': 'tokenguard',
          'displayName': 'TokenGuard',
          'baseUrl': 'https://tokenguard.int.agrd.dev/api/v1',
          'isBuiltIn': false,
        }),
      ],
    );
    await pumpSettings(tester);

    await tester.tap(find.byKey(const Key('apiProvider-providerSelector')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('TokenGuard').last);
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    final modelField = tester.widget<DropdownButtonFormField<String>>(
      find.byKey(const Key('apiProvider-modelSelector')),
    );
    expect(prefs.getString('api_provider'), 'tokenguard');
    expect(prefs.getString('openai_model'), '');
    expect(modelField.initialValue, isNull);
    expect(
      find.text('Add a model before using this provider.'),
      findsOneWidget,
    );
    expect(
      methodCalls.any(
        (call) =>
            call.method == MethodChannelMethods.setModel &&
            call.arguments == '',
      ),
      isTrue,
    );
  });

  testWidgets('selecting custom provider refreshes provider model catalog', (
    tester,
  ) async {
    setupSettings(
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
          'slug': 'kimi-k2.6',
          'isBuiltIn': false,
          'isHidden': false,
        }),
      ],
    );
    await pumpSettings(tester);

    await tester.tap(find.byKey(const Key('apiProvider-providerSelector')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('TokenGuard').last);
    await tester.pumpAndSettle();

    final modelField = tester.widget<DropdownButtonFormField<String>>(
      find.byKey(const Key('apiProvider-modelSelector')),
    );
    expect(modelField.initialValue, 'kimi-k2.6');
    expect(
      find.byKey(const Key('apiProvider-hideModel-tokenguard::kimi-k2.6')),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const Key(
          'apiProvider-hideModel-openrouter::google/gemini-3-flash-preview',
        ),
      ),
      findsNothing,
    );
  });

  testWidgets('trims custom provider API key before saving and syncing', (
    tester,
  ) async {
    setupSettings(
      provider: 'tokenguard',
      customProviderKey: 'old-key',
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
          'slug': 'kimi-k2.6',
          'isBuiltIn': false,
          'isHidden': false,
        }),
      ],
    );
    await pumpSettings(tester);

    await tester.enterText(
      find.byKey(const Key('apiProvider-apiKeyField')),
      '  new-key  ',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(secureValues['tokenguard'], 'new-key');
    expect(
      methodCalls.any((call) {
        return call.method == MethodChannelMethods.setCustomProviderConfig &&
            (call.arguments as Map<Object?, Object?>)['apiKey'] == 'new-key';
      }),
      isTrue,
    );
  });

  testWidgets('adds model for selected custom provider', (tester) async {
    setupSettings(
      provider: 'tokenguard',
      model: null,
      customProviders: [
        jsonEncode({
          'id': 'tokenguard',
          'displayName': 'TokenGuard',
          'baseUrl': 'https://tokenguard.int.agrd.dev/api/v1',
          'isBuiltIn': false,
        }),
      ],
    );
    await pumpSettings(tester);

    await tester.ensureVisible(
      find.byKey(const Key('apiProvider-addOpenRouterModel')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('apiProvider-addOpenRouterModel')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('apiProvider-modelSlugField')),
      'kimi-k2.6',
    );
    await tester.tap(find.byKey(const Key('apiProvider-saveModelSlug')));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    final modelField = tester.widget<DropdownButtonFormField<String>>(
      find.byKey(const Key('apiProvider-modelSelector')),
    );
    expect(find.text('kimi-k2.6'), findsWidgets);
    expect(modelField.initialValue, 'kimi-k2.6');
    expect(prefs.getString('openai_model'), 'kimi-k2.6');
    expect(
      prefs.getStringList('llm_custom_models')!.single,
      contains('"provider":"tokenguard"'),
    );
  });

  testWidgets('shows target language only in Language settings', (
    tester,
  ) async {
    setupSettings();
    await pumpSettings(tester);

    await tester.tap(find.byKey(const Key('settingsNav-writing')));
    await tester.pumpAndSettle();

    expect(find.text('Default Variant'), findsOneWidget);
    expect(find.text('Target Language'), findsNothing);

    await tester.tap(find.byKey(const Key('settingsNav-language')));
    await tester.pumpAndSettle();

    expect(find.text('Target Language'), findsOneWidget);
  });
}
