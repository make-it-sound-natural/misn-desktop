import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:make_it_sound_natural/constants/app_defaults.dart';
import 'package:make_it_sound_natural/models/llm_model_entry.dart';
import 'package:make_it_sound_natural/services/model_catalog_migration.dart';
import 'package:make_it_sound_natural/services/model_catalog_service.dart';
import 'package:make_it_sound_natural/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const successors = {
    'gpt-5.4-nano': 'gpt-6-luna',
    'gpt-5.4-mini': 'gpt-6.1-terra',
    'gpt-5.4': 'gpt-6.1-sol',
    'gpt-5.5': 'gpt-6.1-sol',
  };

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  for (final pair in successors.entries) {
    test(
      'moves each replaced selected model to its successor: ${pair.key}',
      () async {
        SharedPreferences.setMockInitialValues({
          'api_provider': AppDefaults.openAiProvider,
          'openai_model': pair.key,
        });
        final settings = SettingsService();
        final catalog = ModelCatalogService();

        await ModelCatalogMigration(
          catalogService: catalog,
          settingsService: settings,
        ).run();

        expect(await settings.getModel(), pair.value);
        expect(await settings.getProvider(), AppDefaults.openAiProvider);
      },
    );
  }

  test('carries hidden state from a replaced model to its successor', () async {
    SharedPreferences.setMockInitialValues({
      'llm_hidden_models': ['openai::gpt-5.4-mini'],
    });

    await ModelCatalogMigration().run();

    expect(await ModelCatalogService().hiddenSlugs('openai'), {
      'gpt-6.1-terra',
    });
    expect(
      await ModelCatalogService().visibleModelSlugs('openai'),
      isNot(contains('gpt-6.1-terra')),
    );
  });

  test(
    'hides a shared successor only when all its replaced models were hidden',
    () async {
      for (final oldHidden in [
        ['gpt-5.4'],
        ['gpt-5.5'],
        ['gpt-5.4', 'gpt-5.5'],
      ]) {
        SharedPreferences.setMockInitialValues({
          'llm_hidden_models': [for (final slug in oldHidden) 'openai::$slug'],
        });

        await ModelCatalogMigration().run();

        expect(
          await ModelCatalogService().hiddenSlugs('openai'),
          oldHidden.length == 2 ? {'gpt-6.1-sol'} : isEmpty,
        );
      }
    },
  );

  test(
    'keeps the successor visible when hiding it would leave no visible model',
    () async {
      SharedPreferences.setMockInitialValues({
        'llm_hidden_models': [
          'openai::gpt-5.4-mini',
          'openai::gpt-6-luna',
          'openai::gpt-6.1-sol',
          'openai::gpt-6-astra',
        ],
      });

      await ModelCatalogMigration().run();

      expect(await ModelCatalogService().visibleModelSlugs('openai'), [
        'gpt-6.1-terra',
      ]);
      expect(
        await ModelCatalogService().hiddenSlugs('openai'),
        isNot(contains('gpt-5.4-mini')),
      );
    },
  );

  for (final hidden in [false, true]) {
    test(
      'removes custom entries that duplicate a built-in and keeps its '
      'hidden state: $hidden',
      () async {
        SharedPreferences.setMockInitialValues({
          'llm_custom_models': [
            jsonEncode(
              const LlmModelEntry(
                provider: 'openai',
                slug: 'gpt-6.1-sol',
              ).toJson(),
            ),
          ],
          'llm_hidden_models': [if (hidden) 'openai::gpt-6.1-sol'],
        });

        await ModelCatalogMigration().run();

        final entries = (await ModelCatalogService().allModels(
          'openai',
        )).where((model) => model.slug == 'gpt-6.1-sol');
        expect(entries, hasLength(1));
        expect(entries.single.isBuiltIn, isTrue);
        expect(entries.single.isHidden, hidden);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getStringList('llm_custom_models'), isEmpty);
      },
    );
  }

  test('leaves custom models with replaced slugs alone', () async {
    final custom = jsonEncode(
      const LlmModelEntry(provider: 'openai', slug: 'gpt-5.5').toJson(),
    );
    SharedPreferences.setMockInitialValues({
      'api_provider': 'openai',
      'openai_model': 'gpt-5.5',
      'llm_custom_models': [custom],
      'llm_hidden_models': ['openai::gpt-5.5'],
    });

    await ModelCatalogMigration().run();

    final prefs = await SharedPreferences.getInstance();
    expect(await SettingsService().getModel(), 'gpt-5.5');
    expect(prefs.getStringList('llm_custom_models'), [custom]);
    expect(await ModelCatalogService().hiddenSlugs('openai'), {'gpt-5.5'});
  });

  test('drops hidden ids of replaced models', () async {
    SharedPreferences.setMockInitialValues({
      'llm_hidden_models': [
        for (final slug in successors.keys) 'openai::$slug',
        'openai::unrelated-model',
        'openrouter::gpt-5.5',
      ],
    });

    await ModelCatalogMigration().run();

    expect(await ModelCatalogService().hiddenSlugs('openai'), {
      'gpt-6-luna',
      'gpt-6.1-terra',
      'gpt-6.1-sol',
      'unrelated-model',
    });
    expect(await ModelCatalogService().hiddenSlugs('openrouter'), {'gpt-5.5'});
  });

  test('second run changes nothing', () async {
    SharedPreferences.setMockInitialValues({
      'api_provider': 'openai',
      'openai_model': 'gpt-5.4-mini',
      'llm_custom_models': [
        jsonEncode(
          const LlmModelEntry(provider: 'openai', slug: 'gpt-6.1-sol').toJson(),
        ),
      ],
      'llm_hidden_models': ['openai::gpt-5.4-mini'],
    });
    final migration = ModelCatalogMigration();
    await migration.run();
    final prefs = await SharedPreferences.getInstance();
    final firstRun = {
      for (final key in prefs.getKeys()) key: prefs.get(key),
    };

    await migration.run();

    expect({for (final key in prefs.getKeys()) key: prefs.get(key)}, firstRun);
  });

  for (final provider in [
    AppDefaults.anthropicProvider,
    AppDefaults.openRouterProvider,
  ]) {
    test('leaves non-OpenAI providers untouched: $provider', () async {
      final custom = jsonEncode(
        LlmModelEntry(provider: provider, slug: 'gpt-5.5').toJson(),
      );
      SharedPreferences.setMockInitialValues({
        'api_provider': provider,
        'openai_model': 'gpt-5.5',
        'llm_custom_models': [custom],
        'llm_hidden_models': ['$provider::gpt-5.5'],
      });

      await ModelCatalogMigration().run();

      final prefs = await SharedPreferences.getInstance();
      expect(await SettingsService().getProvider(), provider);
      expect(await SettingsService().getModel(), 'gpt-5.5');
      expect(prefs.getStringList('llm_custom_models'), [custom]);
      expect(await ModelCatalogService().hiddenSlugs(provider), {'gpt-5.5'});
    });
  }
}
