import 'package:flutter_test/flutter_test.dart';
import 'package:make_it_sound_natural/constants/app_defaults.dart';
import 'package:make_it_sound_natural/constants/model_catalog_defaults.dart';
import 'package:make_it_sound_natural/models/llm_model_entry.dart';
import 'package:make_it_sound_natural/services/model_catalog_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('ModelCatalogDefaults', () {
    test('keeps current built-in provider model ordering', () {
      expect(ModelCatalogDefaults.modelsForProvider('openai'), [
        'gpt-5.4-nano',
        'gpt-5.4-mini',
        'gpt-5.4',
        'gpt-5.5',
      ]);

      expect(ModelCatalogDefaults.modelsForProvider('openrouter'), [
        'google/gemini-3-flash-preview',
      ]);
    });

    test('returns empty list for unknown provider', () {
      expect(ModelCatalogDefaults.modelsForProvider('unknown'), isEmpty);
    });
  });

  group('ModelCatalogService', () {
    const customOpenRouterSlug = 'openai/gpt-5-mini:nitro';

    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

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
