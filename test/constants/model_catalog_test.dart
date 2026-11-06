import 'package:flutter_test/flutter_test.dart';
import 'package:make_it_sound_natural/constants/app_defaults.dart';
import 'package:make_it_sound_natural/constants/model_catalog.dart';
import 'package:make_it_sound_natural/models/reasoning_effort.dart';
import 'package:make_it_sound_natural/models/request_speed.dart';

void main() {
  const expectedSlugs = {
    AppDefaults.openAiProvider: [
      'gpt-6-luna',
      'gpt-6.1-terra',
      'gpt-6.1-sol',
      'gpt-6-astra',
    ],
    AppDefaults.openRouterProvider: ['google/gemini-3-flash-preview'],
    AppDefaults.anthropicProvider: [
      'claude-haiku-5-5',
      'claude-sonnet-5-5',
      'claude-opus-5-5',
    ],
  };

  test('every model offers standard', () {
    for (final model in ModelCatalog.models) {
      expect(model.speeds, contains(RequestSpeed.standard));
    }
  });

  test('provider and slug pairs are unique', () {
    final identities = ModelCatalog.models.map(
      (model) => '${model.provider}::${model.slug}',
    );
    expect(identities.toSet().length, identities.length);
  });

  test('no replaced slug names a catalog model', () {
    for (final model in ModelCatalog.models) {
      for (final slug in model.replaces) {
        expect(ModelCatalog.find(model.provider, slug), isNull);
      }
    }
  });

  test('lists built-in models per provider in display order', () {
    for (final provider in expectedSlugs.entries) {
      expect(
        ModelCatalog.builtInModels(provider.key).map((model) => model.slug),
        provider.value,
      );
    }
    expect(ModelCatalog.models, hasLength(8));
    expect(
      () => ModelCatalog.builtInModels(AppDefaults.openAiProvider).clear(),
      throwsUnsupportedError,
    );
  });

  test('returns no models for an unknown provider', () {
    expect(ModelCatalog.builtInModels('unknown'), isEmpty);
    expect(ModelCatalog.find('unknown', 'gpt-6-luna'), isNull);
  });

  test('offers speed only for OpenAI and Anthropic', () {
    expect(ModelCatalog.offersSpeed(AppDefaults.openAiProvider), isTrue);
    expect(ModelCatalog.offersSpeed(AppDefaults.anthropicProvider), isTrue);
    expect(ModelCatalog.offersSpeed(AppDefaults.openRouterProvider), isFalse);
    expect(ModelCatalog.offersSpeed('custom'), isFalse);
  });

  test('effectiveSpeed caps the request at the highest supported level', () {
    const levels = {
      'gpt-6-luna': [
        RequestSpeed.standard,
        RequestSpeed.fast,
        RequestSpeed.fast,
      ],
      'gpt-6.1-terra': [
        RequestSpeed.standard,
        RequestSpeed.fast,
        RequestSpeed.fast,
      ],
      'gpt-6.1-sol': RequestSpeed.values,
      'gpt-6-astra': RequestSpeed.values,
      'google/gemini-3-flash-preview': [
        RequestSpeed.standard,
        RequestSpeed.standard,
        RequestSpeed.standard,
      ],
      'claude-haiku-5-5': [
        RequestSpeed.standard,
        RequestSpeed.standard,
        RequestSpeed.standard,
      ],
      'claude-sonnet-5-5': [
        RequestSpeed.standard,
        RequestSpeed.standard,
        RequestSpeed.standard,
      ],
      'claude-opus-5-5': [
        RequestSpeed.standard,
        RequestSpeed.fast,
        RequestSpeed.fast,
      ],
    };
    for (final model in ModelCatalog.models) {
      for (final requested in RequestSpeed.values) {
        expect(
          ModelCatalog.effectiveSpeed(
            provider: model.provider,
            model: model.slug,
            requested: requested,
            isBuiltIn: true,
          ),
          levels[model.slug]![requested.index],
          reason: '${model.slug} at ${requested.name}',
        );
      }
    }
  });

  test(
    'effectiveSpeed passes the request through for custom OpenAI models',
    () {
      for (final requested in RequestSpeed.values) {
        expect(
          ModelCatalog.effectiveSpeed(
            provider: AppDefaults.openAiProvider,
            model: 'custom-model',
            requested: requested,
            isBuiltIn: false,
          ),
          requested,
        );
      }
    },
  );

  test('effectiveSpeed caps custom Anthropic models at fast', () {
    for (final requested in RequestSpeed.values) {
      expect(
        ModelCatalog.effectiveSpeed(
          provider: AppDefaults.anthropicProvider,
          model: 'custom-model',
          requested: requested,
          isBuiltIn: false,
        ),
        requested == RequestSpeed.ultrafast ? RequestSpeed.fast : requested,
      );
    }
  });

  test('effectiveSpeed is standard for OpenRouter and custom providers', () {
    for (final provider in [AppDefaults.openRouterProvider, 'custom']) {
      for (final isBuiltIn in [true, false]) {
        for (final requested in RequestSpeed.values) {
          expect(
            ModelCatalog.effectiveSpeed(
              provider: provider,
              model: 'google/gemini-3-flash-preview',
              requested: requested,
              isBuiltIn: isBuiltIn,
            ),
            RequestSpeed.standard,
          );
        }
      }
    }
  });

  test(
    'effectiveSpeed treats a built-in flag without a catalog record as custom',
    () {
      for (final provider in [
        AppDefaults.openAiProvider,
        AppDefaults.anthropicProvider,
      ]) {
        expect(
          ModelCatalog.effectiveSpeed(
            provider: provider,
            model: 'unknown-model',
            requested: RequestSpeed.ultrafast,
            isBuiltIn: true,
          ),
          provider == AppDefaults.openAiProvider
              ? RequestSpeed.ultrafast
              : RequestSpeed.fast,
        );
      }
    },
  );

  test(
    'effectiveReasoning sends low instead of none where none is unsupported',
    () {
      const noNone = {
        'gpt-6.1-sol',
        'gpt-6-astra',
        'claude-haiku-5-5',
        'claude-sonnet-5-5',
        'claude-opus-5-5',
      };
      for (final model in ModelCatalog.models) {
        for (final requested in ReasoningEffort.values) {
          expect(
            ModelCatalog.effectiveReasoning(
              provider: model.provider,
              model: model.slug,
              requested: requested,
            ),
            requested == ReasoningEffort.none && noNone.contains(model.slug)
                ? ReasoningEffort.low
                : requested,
            reason: '${model.slug} at ${requested.name}',
          );
        }
      }
      for (final provider in [
        AppDefaults.openAiProvider,
        AppDefaults.anthropicProvider,
        'custom',
      ]) {
        for (final requested in ReasoningEffort.values) {
          expect(
            ModelCatalog.effectiveReasoning(
              provider: provider,
              model: 'custom-model',
              requested: requested,
            ),
            requested,
          );
        }
      }
    },
  );

  test('successorOf maps each replaced slug', () {
    const successors = {
      'gpt-5.4-nano': 'gpt-6-luna',
      'gpt-5.4-mini': 'gpt-6.1-terra',
      'gpt-5.4': 'gpt-6.1-sol',
      'gpt-5.5': 'gpt-6.1-sol',
    };
    for (final entry in successors.entries) {
      expect(
        ModelCatalog.successorOf(AppDefaults.openAiProvider, entry.key),
        entry.value,
      );
      expect(
        ModelCatalog.successorOf(AppDefaults.openRouterProvider, entry.key),
        isNull,
      );
    }
    expect(
      ModelCatalog.successorOf(AppDefaults.openAiProvider, 'unknown-model'),
      isNull,
    );
  });
}
