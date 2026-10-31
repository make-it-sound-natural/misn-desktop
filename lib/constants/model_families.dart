import 'package:make_it_sound_natural/constants/app_defaults.dart';
import 'package:make_it_sound_natural/models/model_family.dart';

/// Supported model families, ordered as they appear in the catalog.
class ModelFamilies {
  ModelFamilies._();

  /// All model families; new versions are resolved from provider model lists.
  static final List<ModelFamily> all = List.unmodifiable([
    for (final tier in ['luna', 'terra', 'sol', 'astra'])
      ModelFamily(
        provider: AppDefaults.openAiProvider,
        id: tier,
        pattern: RegExp(
          r'^gpt-(\d+(?:\.\d+)*)-'
          '$tier\$',
        ),
        supportsFast: false,
      ),
    for (final family in ['opus', 'sonnet', 'haiku', 'fable'])
      ModelFamily(
        provider: AppDefaults.anthropicProvider,
        id: family,
        pattern: RegExp(
          '^claude-$family-'
          r'(\d+)(?:-(\d{1,2}))?$',
        ),
        supportsFast: family == 'opus',
      ),
  ]);

  /// Returns a provider's families in display order.
  static List<ModelFamily> forProvider(String provider) => [
    for (final family in all)
      if (family.provider == provider) family,
  ];

  /// Whether the provider offers a live model catalog.
  static bool hasProvider(String provider) =>
      all.any((family) => family.provider == provider);
}
