import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:make_it_sound_natural/constants/app_defaults.dart';
import 'package:make_it_sound_natural/constants/method_channel_methods.dart';
import 'package:make_it_sound_natural/services/model_catalog_migration.dart';
import 'package:make_it_sound_natural/services/model_catalog_service.dart';
import 'package:make_it_sound_natural/services/onboarding_service.dart';
import 'package:make_it_sound_natural/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel(MethodChannelMethods.channelName);
  const legacyOpenRouterModel = 'google/gemini-3-flash-preview';
  final catalog = ModelCatalogService();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => '');
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('fresh install only sets the flag', () async {
    await ModelCatalogMigration().runIfNeeded();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getKeys(), {ModelCatalogMigration.flagKey});
    expect(prefs.getBool(ModelCatalogMigration.flagKey), isTrue);
    expect(await catalog.allModels(AppDefaults.openRouterProvider), isEmpty);
  });

  test('treats an install that predates onboarding as existing', () async {
    SharedPreferences.setMockInitialValues({
      SettingsService.providerKey: AppDefaults.openAiProvider,
      SettingsService.modelKey: 'gpt-5.4-mini',
    });

    await ModelCatalogMigration().runIfNeeded();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey(OnboardingService.completedKey), isFalse);
    expect(
      prefs.getString(SettingsService.providerKey),
      AppDefaults.openAiProvider,
    );
    expect(prefs.getString(SettingsService.modelKey), 'gpt-5.4-mini');
    final model = (await catalog.allModels(AppDefaults.openAiProvider)).single;
    expect(model.slug, 'gpt-5.4-mini');
    expect(model.isBuiltIn, isFalse);
  });

  test('keeps an implicit OpenRouter default as a custom model', () async {
    SharedPreferences.setMockInitialValues({
      OnboardingService.completedKey: true,
    });

    await ModelCatalogMigration().runIfNeeded();

    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getString(SettingsService.providerKey),
      AppDefaults.openRouterProvider,
    );
    expect(prefs.getString(SettingsService.modelKey), legacyOpenRouterModel);
    final model = (await catalog.allModels(
      AppDefaults.openRouterProvider,
    )).single;
    expect(model.slug, legacyOpenRouterModel);
    expect(model.isBuiltIn, isFalse);
    expect(
      await catalog.resolveVisibleModel(
        provider: AppDefaults.openRouterProvider,
        selectedModel: legacyOpenRouterModel,
      ),
      legacyOpenRouterModel,
    );
  });

  test('keeps a saved OpenAI former built-in as a custom model', () async {
    SharedPreferences.setMockInitialValues({
      OnboardingService.completedKey: true,
      SettingsService.providerKey: AppDefaults.openAiProvider,
      SettingsService.modelKey: 'gpt-5.4-mini',
    });

    await ModelCatalogMigration().runIfNeeded();

    final model = (await catalog.allModels(AppDefaults.openAiProvider)).single;
    expect(model.slug, 'gpt-5.4-mini');
    expect(model.isBuiltIn, isFalse);
    expect(await SettingsService().getModel(), 'gpt-5.4-mini');
  });

  test('does not duplicate an existing custom model', () async {
    SharedPreferences.setMockInitialValues({
      OnboardingService.completedKey: true,
      SettingsService.providerKey: AppDefaults.openAiProvider,
      SettingsService.modelKey: 'gpt-5.4-mini',
      'llm_custom_models': [
        jsonEncode({
          'provider': AppDefaults.openAiProvider,
          'slug': 'gpt-5.4-mini',
        }),
      ],
    });

    await ModelCatalogMigration().runIfNeeded();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('llm_custom_models'), hasLength(1));
    expect(await catalog.visibleModelSlugs(AppDefaults.openAiProvider), [
      'gpt-5.4-mini',
    ]);
  });

  test('leaves an Anthropic family slug for the catalog', () async {
    SharedPreferences.setMockInitialValues({
      OnboardingService.completedKey: true,
      SettingsService.providerKey: AppDefaults.anthropicProvider,
      SettingsService.modelKey: 'claude-sonnet-5-5',
    });

    await ModelCatalogMigration().runIfNeeded();

    final prefs = await SharedPreferences.getInstance();
    expect(
      ModelCatalogService.customSlugsIn(prefs, AppDefaults.anthropicProvider),
      isEmpty,
    );
    final model = (await catalog.allModels(
      AppDefaults.anthropicProvider,
    )).single;
    expect(model.slug, 'claude-sonnet-5-5');
    expect(model.familyId, 'sonnet');
    expect(model.isBuiltIn, isTrue);
    expect(
      await catalog.resolveVisibleModel(
        provider: AppDefaults.anthropicProvider,
        selectedModel: 'claude-sonnet-5-5',
      ),
      'claude-sonnet-5-5',
    );
  });

  test('keeps a saved provider without a model unselected', () async {
    SharedPreferences.setMockInitialValues({
      OnboardingService.completedKey: true,
      SettingsService.providerKey: AppDefaults.openAiProvider,
    });

    await ModelCatalogMigration().runIfNeeded();

    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getString(SettingsService.providerKey),
      AppDefaults.openAiProvider,
    );
    expect(prefs.getString(SettingsService.modelKey), '');
    expect(
      ModelCatalogService.customSlugsIn(prefs, AppDefaults.openAiProvider),
      isEmpty,
    );
  });

  test('removes hidden ids of former built-ins only', () async {
    const retained = [
      'openai::custom-model',
      'openai::family:sol',
      'other::gpt-5.4-mini',
    ];
    SharedPreferences.setMockInitialValues({
      OnboardingService.completedKey: false,
      'llm_hidden_models': [
        'openai::gpt-5.4-nano',
        'openai::gpt-5.4-mini',
        'openai::gpt-5.4',
        'openai::gpt-5.5',
        'openrouter::$legacyOpenRouterModel',
        'anthropic-messages::claude-haiku-5-5',
        'anthropic-messages::claude-sonnet-5-5',
        'anthropic-messages::claude-opus-5-5',
        ...retained,
      ],
    });

    await ModelCatalogMigration().runIfNeeded();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('llm_hidden_models'), retained);
    expect(prefs.getBool(OnboardingService.completedKey), isFalse);
  });

  test('runs only once', () async {
    SharedPreferences.setMockInitialValues({
      OnboardingService.completedKey: true,
    });
    final migration = ModelCatalogMigration();
    await migration.runIfNeeded();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      SettingsService.providerKey,
      AppDefaults.openAiProvider,
    );
    await prefs.setString(SettingsService.modelKey, 'gpt-5.4-mini');
    await prefs.setStringList('llm_hidden_models', ['openai::gpt-5.4-mini']);
    final before = {for (final key in prefs.getKeys()) key: prefs.get(key)};

    await migration.runIfNeeded();

    expect({for (final key in prefs.getKeys()) key: prefs.get(key)}, before);
    expect(await catalog.allModels(AppDefaults.openAiProvider), isEmpty);
  });
}
