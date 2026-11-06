import 'package:flutter_test/flutter_test.dart';
import 'package:make_it_sound_natural/constants/app_defaults.dart';
import 'package:make_it_sound_natural/models/llm_model_entry.dart';
import 'package:make_it_sound_natural/services/model_catalog_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('ModelCatalogService', () {
    const customOpenRouterSlug = 'openai/gpt-5-mini:nitro';

    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('lists built-in OpenAI models from the catalog', () async {
      final models = await ModelCatalogService().allModels(
        AppDefaults.openAiProvider,
      );

      expect(models.map((model) => model.slug), [
        'gpt-6-luna',
        'gpt-6.1-terra',
        'gpt-6.1-sol',
        'gpt-6-astra',
      ]);
      expect(models.every((model) => model.isBuiltIn), isTrue);
    });

    test(
      'hiddenSlugs lists hidden slugs of one provider, including slugs '
      'with no model',
      () async {
        SharedPreferences.setMockInitialValues({
          'llm_hidden_models': [
            'openai::gpt-6-luna',
            'openai::gpt-5.4-nano',
            'openrouter::gpt-6-luna',
          ],
        });

        expect(await ModelCatalogService().hiddenSlugs('openai'), {
          'gpt-6-luna',
          'gpt-5.4-nano',
        });
      },
    );

    test('removeCustomEntries keeps hidden ids', () async {
      final service = ModelCatalogService();
      await service.addCustomModel(provider: 'openai', slug: 'custom-model');
      await service.addCustomModel(
        provider: 'openrouter',
        slug: 'custom-model',
      );
      await service.setModelHidden(
        provider: 'openai',
        slug: 'custom-model',
        hidden: true,
      );

      await service.removeCustomEntries(
        provider: 'openai',
        slugs: {'custom-model'},
      );

      expect(
        (await service.allModels('openai')).map((entry) => entry.slug),
        isNot(contains('custom-model')),
      );
      expect(await service.hiddenSlugs('openai'), {'custom-model'});
      expect(
        await service.visibleModelSlugs('openrouter'),
        contains('custom-model'),
      );
    });

    test(
      'forgetHiddenSlugs drops only the named ids of that provider',
      () async {
        SharedPreferences.setMockInitialValues({
          'llm_hidden_models': [
            'openai::gpt-5.4-nano',
            'openai::gpt-6-luna',
            'openrouter::gpt-5.4-nano',
          ],
        });
        final service = ModelCatalogService();

        await service.forgetHiddenSlugs(
          provider: 'openai',
          slugs: {'gpt-5.4-nano'},
        );

        expect(await service.hiddenSlugs('openai'), {'gpt-6-luna'});
        expect(await service.hiddenSlugs('openrouter'), {'gpt-5.4-nano'});
      },
    );

    test('adds trimmed custom OpenRouter model and persists it', () async {
      final service = ModelCatalogService();

      await service.addCustomModel(
        provider: 'openrouter',
        slug: '  anthropic/claude-sonnet-4.6  ',
      );

      expect(
        await service.visibleModelSlugs('openrouter'),
        contains('anthropic/claude-sonnet-4.6'),
      );

      final reloaded = ModelCatalogService();
      expect(
        await reloaded.visibleModelSlugs('openrouter'),
        contains('anthropic/claude-sonnet-4.6'),
      );
    });

    test('keeps custom OpenRouter slug scoped to OpenRouter', () async {
      final service = ModelCatalogService();

      await service.addCustomModel(
        provider: AppDefaults.openRouterProvider,
        slug: customOpenRouterSlug,
      );

      expect(
        await service.visibleModelSlugs(AppDefaults.openRouterProvider),
        contains(customOpenRouterSlug),
      );
      expect(
        await service.visibleModelSlugs(AppDefaults.openAiProvider),
        isNot(contains(customOpenRouterSlug)),
      );

      final reloaded = ModelCatalogService();
      final openRouterModels = await reloaded.allModels(
        AppDefaults.openRouterProvider,
      );
      expect(
        openRouterModels,
        contains(
          predicate<LlmModelEntry>((entry) {
            return entry.provider == AppDefaults.openRouterProvider &&
                entry.slug == customOpenRouterSlug &&
                !entry.isBuiltIn;
          }),
        ),
      );
    });

    test('keeps custom OpenRouter models with simplified built-ins', () async {
      final service = ModelCatalogService();

      await service.addCustomModel(
        provider: AppDefaults.openRouterProvider,
        slug: customOpenRouterSlug,
      );

      expect(await service.visibleModelSlugs(AppDefaults.openRouterProvider), [
        'google/gemini-3-flash-preview',
        customOpenRouterSlug,
      ]);
    });

    test('rejects empty and duplicate custom slugs', () async {
      final service = ModelCatalogService();

      await expectLater(
        service.addCustomModel(provider: 'openrouter', slug: ' '),
        throwsA(isA<ModelCatalogValidationException>()),
      );

      await expectLater(
        service.addCustomModel(
          provider: 'openrouter',
          slug: 'google/gemini-3-flash-preview',
        ),
        throwsA(isA<ModelCatalogValidationException>()),
      );
    });

    test('edits active custom slug without duplicating old slug', () async {
      final service = ModelCatalogService();
      await service.addCustomModel(
        provider: 'openrouter',
        slug: 'anthropic/claude-sonet-4.6',
      );

      await service.editCustomModel(
        provider: 'openrouter',
        oldSlug: 'anthropic/claude-sonet-4.6',
        newSlug: 'anthropic/claude-sonnet-4.6',
      );

      final visible = await service.visibleModelSlugs('openrouter');
      expect(visible, contains('anthropic/claude-sonnet-4.6'));
      expect(visible, isNot(contains('anthropic/claude-sonet-4.6')));
    });

    test('hides and shows built-in OpenRouter models', () async {
      final service = ModelCatalogService();
      await service.addCustomModel(
        provider: 'openrouter',
        slug: 'anthropic/claude-sonnet-4.6',
      );

      await service.setModelHidden(
        provider: 'openrouter',
        slug: 'google/gemini-3-flash-preview',
        hidden: true,
      );

      expect(
        await service.visibleModelSlugs('openrouter'),
        isNot(contains('google/gemini-3-flash-preview')),
      );
      expect(
        await service.allModels('openrouter'),
        contains(
          predicate<LlmModelEntry>((entry) {
            return entry.slug == 'google/gemini-3-flash-preview' &&
                entry.isHidden;
          }),
        ),
      );

      await service.setModelHidden(
        provider: 'openrouter',
        slug: 'google/gemini-3-flash-preview',
        hidden: false,
      );

      expect(
        await service.visibleModelSlugs('openrouter'),
        contains('google/gemini-3-flash-preview'),
      );
    });

    test('tracks hidden custom slugs with provider-scoped identity', () async {
      final service = ModelCatalogService();
      await service.addCustomModel(
        provider: AppDefaults.openRouterProvider,
        slug: customOpenRouterSlug,
      );

      await service.setModelHidden(
        provider: AppDefaults.openRouterProvider,
        slug: customOpenRouterSlug,
        hidden: true,
      );

      expect(
        await service.visibleModelSlugs(AppDefaults.openRouterProvider),
        isNot(contains(customOpenRouterSlug)),
      );
      expect(
        await service.visibleModelSlugs(AppDefaults.openAiProvider),
        isNot(contains(customOpenRouterSlug)),
      );

      final allModels = await service.allModels(
        AppDefaults.openRouterProvider,
      );
      expect(
        allModels,
        contains(
          predicate<LlmModelEntry>((entry) {
            return entry.provider == AppDefaults.openRouterProvider &&
                entry.slug == customOpenRouterSlug &&
                entry.isHidden;
          }),
        ),
      );
    });

    test('deletes custom model but not built-in model', () async {
      final service = ModelCatalogService();
      await service.addCustomModel(
        provider: 'openrouter',
        slug: 'anthropic/claude-sonnet-4.6',
      );

      await service.deleteCustomModel(
        provider: 'openrouter',
        slug: 'anthropic/claude-sonnet-4.6',
      );

      expect(
        await service.visibleModelSlugs('openrouter'),
        isNot(contains('anthropic/claude-sonnet-4.6')),
      );
      await expectLater(
        service.deleteCustomModel(
          provider: 'openrouter',
          slug: 'google/gemini-3-flash-preview',
        ),
        throwsA(isA<ModelCatalogValidationException>()),
      );
    });

    test(
      'resolves visible fallback for missing or hidden selected model',
      () async {
        final service = ModelCatalogService();

        expect(
          await service.resolveVisibleModel(
            provider: 'openrouter',
            selectedModel: 'missing/model',
          ),
          'google/gemini-3-flash-preview',
        );
      },
    );

    test('keeps at least one model visible per provider', () async {
      final service = ModelCatalogService();

      await expectLater(
        service.setModelHidden(
          provider: 'openrouter',
          slug: 'google/gemini-3-flash-preview',
          hidden: true,
        ),
        throwsA(isA<ModelCatalogValidationException>()),
      );
    });

    test('allows custom provider to have zero models', () async {
      final service = ModelCatalogService();

      expect(await service.allModels('tokenguard'), isEmpty);
      expect(await service.visibleModelSlugs('tokenguard'), isEmpty);
    });

    test('removes custom models and hidden ids for deleted provider', () async {
      final service = ModelCatalogService();
      await service.addCustomModel(provider: 'tokenguard', slug: 'kimi-k2.6');
      await service.addCustomModel(
        provider: 'tokenguard',
        slug: 'kimi-k2.6-fast',
      );
      await service.setModelHidden(
        provider: 'tokenguard',
        slug: 'kimi-k2.6',
        hidden: true,
      );

      await service.deleteProviderModels('tokenguard');

      expect(await service.allModels('tokenguard'), isEmpty);
      expect(await service.visibleModelSlugs('tokenguard'), isEmpty);
    });
  });
}
