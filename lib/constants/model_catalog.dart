import 'package:make_it_sound_natural/constants/app_defaults.dart';
import 'package:make_it_sound_natural/models/reasoning_effort.dart';
import 'package:make_it_sound_natural/models/request_speed.dart';

/// Capabilities and replacement history of a shipped model.
class BuiltInModel {
  /// Creates an immutable built-in model record.
  const BuiltInModel({
    required this.provider,
    required this.slug,
    required this.speeds,
    required this.supportsNoReasoning,
    this.replaces = const [],
  });

  /// Provider that owns this model.
  final String provider;

  /// Model identifier sent to the provider.
  final String slug;

  /// Available processing tiers.
  final Set<RequestSpeed> speeds;

  /// Whether this model accepts the `none` reasoning effort.
  final bool supportsNoReasoning;

  /// Previously shipped model identifiers superseded by this model.
  final List<String> replaces;
}

/// Built-in model facts and effective request settings.
abstract final class ModelCatalog {
  /// Shipped models in display order within each provider.
  static const List<BuiltInModel> models = [
    BuiltInModel(
      provider: AppDefaults.openAiProvider,
      slug: 'gpt-6-luna',
      speeds: {RequestSpeed.standard, RequestSpeed.fast},
      supportsNoReasoning: true,
      replaces: ['gpt-5.4-nano'],
    ),
    BuiltInModel(
      provider: AppDefaults.openAiProvider,
      slug: 'gpt-6.1-terra',
      speeds: {RequestSpeed.standard, RequestSpeed.fast},
      supportsNoReasoning: true,
      replaces: ['gpt-5.4-mini'],
    ),
    BuiltInModel(
      provider: AppDefaults.openAiProvider,
      slug: 'gpt-6.1-sol',
      speeds: {
        RequestSpeed.standard,
        RequestSpeed.fast,
        RequestSpeed.ultrafast,
      },
      supportsNoReasoning: false,
      replaces: ['gpt-5.4', 'gpt-5.5'],
    ),
    BuiltInModel(
      provider: AppDefaults.openAiProvider,
      slug: 'gpt-6-astra',
      speeds: {
        RequestSpeed.standard,
        RequestSpeed.fast,
        RequestSpeed.ultrafast,
      },
      supportsNoReasoning: false,
    ),
    BuiltInModel(
      provider: AppDefaults.openRouterProvider,
      slug: 'google/gemini-3-flash-preview',
      speeds: {RequestSpeed.standard},
      supportsNoReasoning: true,
    ),
    BuiltInModel(
      provider: AppDefaults.anthropicProvider,
      slug: 'claude-haiku-5-5',
      speeds: {RequestSpeed.standard},
      supportsNoReasoning: false,
    ),
    BuiltInModel(
      provider: AppDefaults.anthropicProvider,
      slug: 'claude-sonnet-5-5',
      speeds: {RequestSpeed.standard},
      supportsNoReasoning: false,
    ),
    BuiltInModel(
      provider: AppDefaults.anthropicProvider,
      slug: 'claude-opus-5-5',
      speeds: {RequestSpeed.standard, RequestSpeed.fast},
      supportsNoReasoning: false,
    ),
  ];

  /// Returns a provider's shipped models in display order.
  static List<BuiltInModel> builtInModels(String provider) =>
      List.unmodifiable(models.where((model) => model.provider == provider));

  /// Returns the shipped record for a provider and slug, if present.
  static BuiltInModel? find(String provider, String slug) {
    for (final model in models) {
      if (model.provider == provider && model.slug == slug) {
        return model;
      }
    }
    return null;
  }

  /// Whether the provider supports choosing a processing tier.
  static bool offersSpeed(String provider) =>
      provider == AppDefaults.openAiProvider ||
      provider == AppDefaults.anthropicProvider;

  /// Resolves the requested tier against provider and model capabilities.
  static RequestSpeed effectiveSpeed({
    required String provider,
    required String model,
    required RequestSpeed requested,
    required bool isBuiltIn,
  }) {
    if (!offersSpeed(provider)) return RequestSpeed.standard;
    final builtIn = isBuiltIn ? find(provider, model) : null;
    if (builtIn == null) {
      return provider == AppDefaults.anthropicProvider &&
              requested == RequestSpeed.ultrafast
          ? RequestSpeed.fast
          : requested;
    }
    return RequestSpeed.values.lastWhere(
      (speed) =>
          speed.index <= requested.index && builtIn.speeds.contains(speed),
    );
  }

  /// Resolves reasoning effort against a shipped model's capabilities.
  static ReasoningEffort effectiveReasoning({
    required String provider,
    required String model,
    required ReasoningEffort requested,
  }) =>
      requested == ReasoningEffort.none &&
          find(provider, model)?.supportsNoReasoning == false
      ? ReasoningEffort.low
      : requested;

  /// Returns the shipped successor for a previously shipped model slug.
  static String? successorOf(String provider, String slug) {
    for (final model in builtInModels(provider)) {
      if (model.replaces.contains(slug)) return model.slug;
    }
    return null;
  }
}
