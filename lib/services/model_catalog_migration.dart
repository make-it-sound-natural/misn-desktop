import 'package:logging/logging.dart';
import 'package:make_it_sound_natural/constants/model_catalog.dart';
import 'package:make_it_sound_natural/models/catalog_validation_reason.dart';
import 'package:make_it_sound_natural/services/model_catalog_service.dart';
import 'package:make_it_sound_natural/services/settings_service.dart';
import 'package:make_it_sound_natural/utils/logger.dart';

/// Changes that move one provider's saved models to shipped successors.
class ModelCatalogMigrationPlan {
  /// Creates a plan; empty collections and a null model mean no change.
  const ModelCatalogMigrationPlan({
    this.removedDuplicates = const {},
    this.hiddenSuccessors = const {},
    this.forgottenHiddenSlugs = const {},
    this.selectedModel,
  });

  /// Custom entries that duplicate a shipped model and are removed.
  final Set<String> removedDuplicates;

  /// Shipped successors hidden because every model they replace was hidden.
  final Set<String> hiddenSuccessors;

  /// Hidden ids of replaced models that are dropped.
  final Set<String> forgottenHiddenSlugs;

  /// Successor to select instead of a replaced model, if any.
  final String? selectedModel;
}

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
  static final Logger _log = getLogger('ModelCatalogMigration');

  /// Plans the migration of one provider from its saved state.
  ///
  /// [selectedModel] is the saved model when this provider is selected.
  /// Custom models with a replaced slug are user-managed and stay as they
  /// are. A successor the user already added as a custom model keeps its
  /// own hidden state.
  static ModelCatalogMigrationPlan plan({
    required List<BuiltInModel> builtIns,
    required Set<String> customSlugs,
    required Set<String> hiddenSlugs,
    String? selectedModel,
  }) {
    final hiddenSuccessors = <String>{};
    final forgotten = <String>{};
    String? successor;
    for (final model in builtIns) {
      final replaced = model.replaces.toSet().difference(customSlugs);
      final hiddenReplaced = replaced.intersection(hiddenSlugs);
      forgotten.addAll(hiddenReplaced);
      if (hiddenReplaced.isNotEmpty &&
          hiddenReplaced.length == replaced.length &&
          !customSlugs.contains(model.slug)) {
        hiddenSuccessors.add(model.slug);
      }
      if (replaced.contains(selectedModel)) successor = model.slug;
    }
    return ModelCatalogMigrationPlan(
      removedDuplicates: customSlugs.intersection(
        builtIns.map((model) => model.slug).toSet(),
      ),
      hiddenSuccessors: hiddenSuccessors,
      forgottenHiddenSlugs: forgotten,
      selectedModel: successor,
    );
  }

  /// Migrates replaced built-ins while preserving user-managed model slugs.
  Future<void> run() async {
    final providers = ModelCatalog.models
        .where((model) => model.replaces.isNotEmpty)
        .map((model) => model.provider)
        .toSet();
    for (final provider in providers) {
      final selectedProvider = await _settings.getProvider();
      final changes = plan(
        builtIns: ModelCatalog.builtInModels(provider),
        customSlugs: (await _catalog.allModels(provider))
            .where((entry) => !entry.isBuiltIn)
            .map((entry) => entry.slug)
            .toSet(),
        hiddenSlugs: await _catalog.hiddenSlugs(provider),
        selectedModel: selectedProvider == provider
            ? await _settings.getModel()
            : null,
      );
      await _apply(provider, changes);
    }
  }

  Future<void> _apply(String provider, ModelCatalogMigrationPlan plan) async {
    if (plan.removedDuplicates.isNotEmpty) {
      await _catalog.removeCustomEntries(
        provider: provider,
        slugs: plan.removedDuplicates,
      );
      _log.info(
        '$provider: removed custom duplicates '
        '${plan.removedDuplicates.join(', ')}',
      );
    }
    for (final slug in plan.hiddenSuccessors) {
      await _hide(provider, slug);
    }
    if (plan.forgottenHiddenSlugs.isNotEmpty) {
      await _catalog.forgetHiddenSlugs(
        provider: provider,
        slugs: plan.forgottenHiddenSlugs,
      );
    }
    final successor = plan.selectedModel;
    if (successor != null) {
      final previous = await _settings.getModel();
      await _settings.setModel(successor);
      _log.info('$provider: selected model $previous -> $successor');
    }
  }

  Future<void> _hide(String provider, String slug) async {
    try {
      await _catalog.setModelHidden(
        provider: provider,
        slug: slug,
        hidden: true,
      );
      _log.info('$provider: hid $slug like the models it replaces');
    } on ModelCatalogValidationException catch (error) {
      if (error.reason != CatalogValidationReason.modelVisibilityRequired) {
        rethrow;
      }
      _log.info('$provider: kept $slug visible, the last visible model');
    }
  }
}
