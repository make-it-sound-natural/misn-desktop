import 'package:make_it_sound_natural/constants/app_defaults.dart';
import 'package:make_it_sound_natural/services/model_catalog_service.dart';
import 'package:make_it_sound_natural/services/model_family_resolver.dart';
import 'package:make_it_sound_natural/services/onboarding_service.dart';
import 'package:make_it_sound_natural/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Preserves selections from installs that used bundled model lists.
class ModelCatalogMigration {
  /// Creates a migration using the local catalog and settings services.
  ModelCatalogMigration({
    ModelCatalogService? modelCatalog,
    SettingsService? settings,
    OnboardingService? onboarding,
  }) : _modelCatalog = modelCatalog ?? ModelCatalogService(),
       _settings = settings ?? SettingsService(),
       _onboarding = onboarding ?? OnboardingService(settingsService: settings);

  /// SharedPreferences flag recording successful catalog migration.
  static const String flagKey = 'llm_catalog_migration_v1';

  static const String _legacyDefaultModel = 'google/gemini-3-flash-preview';
  static const Map<String, List<String>> _formerBuiltIns = {
    AppDefaults.openAiProvider: [
      'gpt-5.4-nano',
      'gpt-5.4-mini',
      'gpt-5.4',
      'gpt-5.5',
    ],
    AppDefaults.openRouterProvider: [_legacyDefaultModel],
    AppDefaults.anthropicProvider: [
      'claude-haiku-5-5',
      'claude-sonnet-5-5',
      'claude-opus-5-5',
    ],
  };

  final ModelCatalogService _modelCatalog;
  final SettingsService _settings;
  final OnboardingService _onboarding;

  /// Preserves existing selections once, leaving fresh installs unselected.
  Future<void> runIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(flagKey) ?? false) return;

    final existingInstall =
        prefs.containsKey(OnboardingService.completedKey) ||
        await _onboarding.hasExistingSetup();
    if (existingInstall) {
      final provider =
          prefs.getString(SettingsService.providerKey) ??
          AppDefaults.openRouterProvider;
      final model =
          prefs.getString(SettingsService.modelKey) ??
          (provider == AppDefaults.openRouterProvider
              ? _legacyDefaultModel
              : '');
      await _settings.setProvider(provider);
      await _settings.setModel(model);

      if ((_formerBuiltIns[provider]?.contains(model) ?? false) &&
          familyForSlug(provider, model) == null &&
          !ModelCatalogService.customSlugsIn(prefs, provider).contains(model)) {
        await _modelCatalog.addCustomModel(provider: provider, slug: model);
      }

      final hidden = prefs.getStringList(ModelCatalogService.hiddenModelsKey);
      if (hidden != null) {
        final formerIds = {
          for (final entry in _formerBuiltIns.entries)
            for (final slug in entry.value) '${entry.key}::$slug',
        };
        await prefs.setStringList(
          ModelCatalogService.hiddenModelsKey,
          hidden.where((id) => !formerIds.contains(id)).toList(),
        );
      }
    }

    await prefs.setBool(flagKey, true);
  }
}
