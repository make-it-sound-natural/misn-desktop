import 'package:make_it_sound_natural/constants/app_defaults.dart';

/// Built-in LLM model catalog shipped with the app.
class ModelCatalogDefaults {
  ModelCatalogDefaults._();

  static const Map<String, List<String>> _modelsByProvider = {
    AppDefaults.openAiProvider: [
      'gpt-5.4-nano',
      'gpt-5.4-mini',
      'gpt-5.4',
      'gpt-5.5',
    ],
    AppDefaults.openRouterProvider: [
      'google/gemini-3-flash-preview',
    ],
    AppDefaults.anthropicProvider: [
      'claude-haiku-5-5',
      'claude-sonnet-5-5',
      'claude-opus-5-5',
    ],
  };

  /// Returns built-in model slugs for a provider.
  static List<String> modelsForProvider(String provider) {
    return List.unmodifiable(_modelsByProvider[provider] ?? const []);
  }

  /// Returns whether a provider has a built-in catalog.
  static bool hasProvider(String provider) {
    return _modelsByProvider.containsKey(provider);
  }
}
