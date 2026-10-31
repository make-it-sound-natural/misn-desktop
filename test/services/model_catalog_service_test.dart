import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:make_it_sound_natural/constants/app_defaults.dart';
import 'package:make_it_sound_natural/services/model_catalog_cache.dart';
import 'package:make_it_sound_natural/services/model_catalog_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const openAi = AppDefaults.openAiProvider;
  const anthropic = AppDefaults.anthropicProvider;
  const openRouter = AppDefaults.openRouterProvider;
  late ModelCatalogService service;
  late SharedPreferences prefs;

  Future<void> seedFamilies(String provider, Map<String, String> families) =>
      ModelCatalogCache().writeTo(
        prefs,
        provider,
        families: families,
        fetchedAt: DateTime.utc(2026, 10, 31),
      );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    service = ModelCatalogService();
  });

  test('lists cached families in family order before custom models', () async {
    await seedFamilies(openAi, {
      'astra': 'gpt-6-astra',
      'sol': 'gpt-6.1-sol',
      'terra': 'gpt-6.1-terra',
      'luna': 'gpt-6-luna',
    });
    await service.addCustomModel(provider: openAi, slug: 'pinned-model');

    expect((await service.allModels(openAi)).map((entry) => entry.slug), [
      'gpt-6-luna',
      'gpt-6.1-terra',
      'gpt-6.1-sol',
      'gpt-6-astra',
      'pinned-model',
    ]);
  });

  test('lists no OpenAI or Anthropic models before the first fetch', () async {
    expect(await service.allModels(openAi), isEmpty);
    expect(await service.allModels(anthropic), isEmpty);
    expect(await service.allModels(openRouter), isEmpty);
  });

  test(
    'lists the saved family slug as a provisional entry before the first fetch',
    () async {
      await prefs.setString('api_provider', anthropic);
      await prefs.setString('openai_model', 'claude-sonnet-5-5');

      final entries = await service.allModels(anthropic);
      expect(entries, hasLength(1));
      expect(entries.single.slug, 'claude-sonnet-5-5');
      expect(entries.single.familyId, 'sonnet');
      expect(entries.single.isBuiltIn, isTrue);
      expect(entries.single.isHidden, isFalse);
    },
  );

  test(
    "adds no provisional entry for another provider's selection or a slug "
    'without a family',
    () async {
      await prefs.setString('api_provider', openAi);
      await prefs.setString('openai_model', 'gpt-6-sol');
      expect(await service.allModels(anthropic), isEmpty);
      await prefs.setString('openai_model', 'gpt-5.4-mini');
      expect(await service.allModels(openAi), isEmpty);
    },
  );

  test('drops the provisional entry once the provider is fetched', () async {
    await prefs.setString('api_provider', anthropic);
    await prefs.setString('openai_model', 'claude-sonnet-5-5');
    await seedFamilies(anthropic, {});

    expect(await service.allModels(anthropic), isEmpty);
  });

  test('marks catalog entries with their family id', () async {
    await seedFamilies(openAi, {'sol': 'gpt-6.1-sol'});
    final model = (await service.allModels(openAi)).single;

    expect(model.familyId, 'sol');
    expect(model.isBuiltIn, isTrue);
  });

  test(
    'hides a catalog model by family so a new version stays hidden',
    () async {
      await seedFamilies(openAi, {
        'sol': 'gpt-6.1-sol',
        'terra': 'gpt-6.1-terra',
      });
      await service.setModelHidden(
        provider: openAi,
        slug: 'gpt-6.1-sol',
        hidden: true,
      );
      expect(prefs.getStringList('llm_hidden_models'), ['openai::family:sol']);
      await seedFamilies(openAi, {
        'sol': 'gpt-6.2-sol',
        'terra': 'gpt-6.1-terra',
      });

      final models = await service.allModels(openAi);
      expect(models.last.slug, 'gpt-6.2-sol');
      expect(models.last.isHidden, isTrue);
      expect(await service.visibleModelSlugs(openAi), ['gpt-6.1-terra']);
      await service.setModelHidden(
        provider: openAi,
        slug: 'gpt-6.2-sol',
        hidden: false,
      );
      expect(await service.visibleModelSlugs(openAi), contains('gpt-6.2-sol'));
    },
  );

  test('omits a catalog entry whose slug is also a custom model', () async {
    await service.addCustomModel(provider: openAi, slug: 'gpt-6.1-sol');
    await seedFamilies(openAi, {'sol': 'gpt-6.1-sol'});

    final entries = await service.allModels(openAi);
    expect(entries, hasLength(1));
    expect(entries.single.isBuiltIn, isFalse);
    expect(entries.single.familyId, isNull);
  });

  test('allows a custom older version of a catalog family', () async {
    await seedFamilies(openAi, {'sol': 'gpt-6.2-sol'});
    await service.addCustomModel(provider: openAi, slug: 'gpt-6.1-sol');

    expect(await service.visibleModelSlugs(openAi), [
      'gpt-6.2-sol',
      'gpt-6.1-sol',
    ]);
  });

  test('rejects a custom slug equal to the current catalog slug', () async {
    await seedFamilies(openAi, {'sol': 'gpt-6.1-sol'});

    await expectLater(
      service.addCustomModel(provider: openAi, slug: 'gpt-6.1-sol'),
      throwsA(isA<ModelCatalogValidationException>()),
    );
  });

  test('treats an unfetched family slug as a valid selection', () async {
    await prefs.setString('api_provider', anthropic);
    await prefs.setString('openai_model', 'claude-sonnet-5-5');

    expect(
      await service.resolveVisibleModel(
        provider: anthropic,
        selectedModel: 'claude-sonnet-5-5',
      ),
      'claude-sonnet-5-5',
    );
    await prefs.setStringList('llm_hidden_models', [
      'anthropic-messages::family:sonnet',
    ]);
    expect(
      await service.resolveVisibleModel(
        provider: anthropic,
        selectedModel: 'claude-sonnet-5-5',
      ),
      isNull,
    );
  });

  test('returns null for an empty selection', () async {
    await seedFamilies(openAi, {'sol': 'gpt-6.1-sol'});

    expect(
      await service.resolveVisibleModel(provider: openAi, selectedModel: ''),
      isNull,
    );
  });

  test('returns null for a missing or hidden selection', () async {
    await seedFamilies(openAi, {
      'sol': 'gpt-6.1-sol',
      'terra': 'gpt-6.1-terra',
    });
    await service.setModelHidden(
      provider: openAi,
      slug: 'gpt-6.1-sol',
      hidden: true,
    );
    for (final slug in ['gpt-6.1-sol', 'gone-model']) {
      expect(
        await service.resolveVisibleModel(
          provider: openAi,
          selectedModel: slug,
        ),
        isNull,
      );
    }
    expect(
      await service.resolveVisibleModel(
        provider: openAi,
        selectedModel: 'gpt-6.1-terra',
      ),
      'gpt-6.1-terra',
    );
  });

  test('customSlugsIn returns only user-added slugs of the provider', () async {
    await seedFamilies(openAi, {'sol': 'gpt-6.1-sol'});
    await service.addCustomModel(provider: openAi, slug: 'pinned-model');
    await service.addCustomModel(provider: openRouter, slug: 'remote-model');

    expect(ModelCatalogService.customSlugsIn(prefs, openAi), {'pinned-model'});
    expect(ModelCatalogService.customSlugsIn(prefs, anthropic), isEmpty);
  });

  test('adds trimmed custom OpenRouter model and persists it', () async {
    await service.addCustomModel(
      provider: openRouter,
      slug: '  custom/model  ',
    );

    expect(await service.visibleModelSlugs(openRouter), ['custom/model']);
    expect(
      await ModelCatalogService().visibleModelSlugs(openRouter),
      ['custom/model'],
    );
  });

  test('keeps custom models scoped to their provider', () async {
    await service.addCustomModel(provider: openRouter, slug: 'custom/model');

    expect(await service.visibleModelSlugs(openRouter), ['custom/model']);
    expect(await service.visibleModelSlugs(openAi), isEmpty);
    final model = (await ModelCatalogService().allModels(openRouter)).single;
    expect(model.provider, openRouter);
    expect(model.isBuiltIn, isFalse);
  });

  test('rejects empty and duplicate custom slugs', () async {
    await service.addCustomModel(provider: openRouter, slug: 'custom/model');
    for (final slug in [' ', 'custom/model']) {
      await expectLater(
        service.addCustomModel(provider: openRouter, slug: slug),
        throwsA(isA<ModelCatalogValidationException>()),
      );
    }
  });

  test('edits custom slug without duplicating old slug', () async {
    await service.addCustomModel(provider: openRouter, slug: 'custom/old');
    await service.editCustomModel(
      provider: openRouter,
      oldSlug: 'custom/old',
      newSlug: 'custom/new',
    );

    expect(await service.visibleModelSlugs(openRouter), ['custom/new']);
  });

  test('tracks hidden custom slugs with provider-scoped identity', () async {
    await service.addCustomModel(provider: openRouter, slug: 'custom/model');
    await service.addCustomModel(provider: openRouter, slug: 'custom/other');
    await service.addCustomModel(provider: openAi, slug: 'custom/model');
    await service.setModelHidden(
      provider: openRouter,
      slug: 'custom/model',
      hidden: true,
    );

    expect(prefs.getStringList('llm_hidden_models'), [
      'openrouter::custom/model',
    ]);
    expect(await service.visibleModelSlugs(openRouter), ['custom/other']);
    expect(await service.visibleModelSlugs(openAi), ['custom/model']);
    final hidden = (await service.allModels(openRouter)).first;
    expect(hidden.isHidden, isTrue);
    await service.editCustomModel(
      provider: openRouter,
      oldSlug: 'custom/model',
      newSlug: 'custom/renamed',
    );
    expect(prefs.getStringList('llm_hidden_models'), [
      'openrouter::custom/renamed',
    ]);
    await service.deleteCustomModel(
      provider: openRouter,
      slug: 'custom/renamed',
    );
    expect(prefs.getStringList('llm_hidden_models'), isEmpty);
  });

  test('deletes custom model but not catalog model', () async {
    await seedFamilies(openAi, {'sol': 'gpt-6.1-sol'});
    await service.addCustomModel(provider: openAi, slug: 'custom/model');
    await service.deleteCustomModel(provider: openAi, slug: 'custom/model');

    expect(await service.visibleModelSlugs(openAi), ['gpt-6.1-sol']);
    await expectLater(
      service.deleteCustomModel(provider: openAi, slug: 'gpt-6.1-sol'),
      throwsA(isA<ModelCatalogValidationException>()),
    );
  });

  test('keeps at least one model visible per provider', () async {
    await service.addCustomModel(provider: openRouter, slug: 'custom/model');
    await expectLater(
      service.setModelHidden(
        provider: openRouter,
        slug: 'custom/model',
        hidden: true,
      ),
      throwsA(isA<ModelCatalogValidationException>()),
    );
  });

  test('allows custom provider to have zero models', () async {
    expect(await service.allModels('tokenguard'), isEmpty);
    expect(await service.visibleModelSlugs('tokenguard'), isEmpty);
  });

  test('removes custom models and hidden ids for deleted provider', () async {
    await service.addCustomModel(provider: 'tokenguard', slug: 'custom/model');
    await service.addCustomModel(provider: 'tokenguard', slug: 'custom/other');
    await service.setModelHidden(
      provider: 'tokenguard',
      slug: 'custom/model',
      hidden: true,
    );
    await service.deleteProviderModels('tokenguard');

    expect(await service.allModels('tokenguard'), isEmpty);
    expect(prefs.getStringList('llm_hidden_models'), isEmpty);
    expect(
      (prefs.getStringList('llm_custom_models') ?? []).map(jsonDecode),
      isEmpty,
    );
  });
}
