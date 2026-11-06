import 'package:make_it_sound_natural/constants/model_catalog.dart';
import 'package:make_it_sound_natural/models/catalog_validation_reason.dart';
import 'package:make_it_sound_natural/services/model_catalog_service.dart';
import 'package:make_it_sound_natural/services/settings_service.dart';

/// Migrates saved model selections and visibility to shipped successors.
class ModelCatalogMigration {
  /// Creates a migration with optional settings and catalog dependencies.
  ModelCatalogMigration({
    ModelCatalogService? catalogService,
    SettingsService? settingsService,
  }) : _catalog = catalogService ?? ModelCatalogService(),
       _settings = settingsService ?? SettingsService();

  final ModelCatalogService _catalog;
  final SettingsService _settings;

  /// Migrates replaced built-ins while preserving user-managed model slugs.
  Future<void> run() async {
    final providers = ModelCatalog.models
        .where((model) => model.replaces.isNotEmpty)
        .map((model) => model.provider)
        .toSet();
    for (final provider in providers) {
      final builtIns = ModelCatalog.builtInModels(provider);
      final customSlugs = (await _catalog.allModels(
        provider,
      )).where((entry) => !entry.isBuiltIn).map((entry) => entry.slug).toSet();
      await _catalog.removeCustomEntries(
        provider: provider,
        slugs: builtIns.map((model) => model.slug).toSet(),
      );

      final hidden = await _catalog.hiddenSlugs(provider);
      final eligibleOldSlugs = <String>{};
      for (final model in builtIns) {
        final eligible = model.replaces
            .where((slug) => !customSlugs.contains(slug))
            .toSet();
        eligibleOldSlugs.addAll(eligible);
        final hiddenOldSlugs = eligible.intersection(hidden);
        if (hiddenOldSlugs.isNotEmpty &&
            hiddenOldSlugs.length == eligible.length) {
          try {
            await _catalog.setModelHidden(
              provider: provider,
              slug: model.slug,
              hidden: true,
            );
          } on ModelCatalogValidationException catch (error) {
            if (error.reason !=
                CatalogValidationReason.modelVisibilityRequired) {
              rethrow;
            }
          }
        }
        await _catalog.forgetHiddenSlugs(
          provider: provider,
          slugs: hiddenOldSlugs,
        );
      }

      final selectedModel = await _settings.getModel();
      if (await _settings.getProvider() == provider &&
          eligibleOldSlugs.contains(selectedModel)) {
        final successor = ModelCatalog.successorOf(provider, selectedModel);
        if (successor != null) {
          await _settings.setModel(successor);
        }
      }
    }
  }
}
