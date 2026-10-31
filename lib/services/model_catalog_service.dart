import 'dart:convert';

import 'package:make_it_sound_natural/constants/model_families.dart';
import 'package:make_it_sound_natural/models/catalog_validation_reason.dart';
import 'package:make_it_sound_natural/models/llm_model_entry.dart';
import 'package:make_it_sound_natural/services/model_catalog_cache.dart';
import 'package:make_it_sound_natural/services/model_family_resolver.dart';
import 'package:make_it_sound_natural/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Error thrown when a model catalog edit is invalid.
class ModelCatalogValidationException implements Exception {
  /// Creates a validation exception.
  const ModelCatalogValidationException(this.reason, this.message);

  /// Machine-readable cause, which the UI maps onto localized copy.
  final CatalogValidationReason reason;

  /// English sentence, for logs and as a last-resort fallback.
  final String message;

  @override
  String toString() => message;
}

/// Persists and resolves local LLM model catalogs.
class ModelCatalogService {
  /// Creates a catalog backed by the provider cache and local custom models.
  ModelCatalogService({ModelCatalogCache? cache})
    : _cache = cache ?? ModelCatalogCache();

  static const String _customModelsKey = 'llm_custom_models';

  /// SharedPreferences key for hidden catalog families and custom models.
  static const String hiddenModelsKey = 'llm_hidden_models';

  final ModelCatalogCache _cache;

  /// Returns provider catalog models followed by custom models.
  Future<List<LlmModelEntry>> allModels(String provider) async {
    final hidden = await _hiddenModelIds();
    final custom = (await _customModels())
        .where((entry) => entry.provider == provider)
        .map(
          (entry) => entry.copyWith(
            isHidden: hidden.contains(_modelId(provider, entry.slug)),
          ),
        )
        .toList();
    final customSlugs = custom.map((entry) => entry.slug).toSet();
    final cached = await _cache.read(provider);
    final families = <String, String>{...?cached?.families};
    if (cached == null) {
      final settings = SettingsService();
      if (await settings.getProvider() == provider) {
        final slug = await settings.getModel();
        final family = familyForSlug(provider, slug);
        if (family != null) families[family.id] = slug;
      }
    }
    final builtIns = [
      for (final family in ModelFamilies.forProvider(provider))
        if (families[family.id] case final String slug)
          if (!customSlugs.contains(slug))
            LlmModelEntry(
              provider: provider,
              slug: slug,
              isBuiltIn: true,
              familyId: family.id,
              isHidden: hidden.contains(_familyId(provider, family.id)),
            ),
    ];
    return [...builtIns, ...custom];
  }

  /// Returns visible model slugs for active selection.
  Future<List<String>> visibleModelSlugs(String provider) async {
    return (await allModels(provider))
        .where((entry) => !entry.isHidden)
        .map((entry) => entry.slug)
        .toList(growable: false);
  }

  /// Resolves selected model to a visible provider model.
  Future<String?> resolveVisibleModel({
    required String provider,
    required String selectedModel,
  }) async {
    if (selectedModel.isEmpty) return null;
    final visible = await visibleModelSlugs(provider);
    if (visible.contains(selectedModel)) {
      return selectedModel;
    }
    return null;
  }

  /// Adds a user-managed model.
  Future<void> addCustomModel({
    required String provider,
    required String slug,
  }) async {
    final normalized = _normalizeSlug(slug);
    await _validateNewSlug(provider: provider, slug: normalized);
    final custom = await _customModels();
    await _saveCustomModels([
      ...custom,
      LlmModelEntry(provider: provider, slug: normalized),
    ]);
  }

  /// Edits a user-managed model slug.
  Future<void> editCustomModel({
    required String provider,
    required String oldSlug,
    required String newSlug,
  }) async {
    final normalized = _normalizeSlug(newSlug);
    final custom = await _customModels();
    final oldIndex = custom.indexWhere(
      (entry) => entry.provider == provider && entry.slug == oldSlug,
    );
    if (oldIndex == -1) {
      throw const ModelCatalogValidationException(
        CatalogValidationReason.notMutable,
        'Only custom models can be edited.',
      );
    }
    if (normalized != oldSlug) {
      await _validateNewSlug(
        provider: provider,
        slug: normalized,
        allowedExistingSlug: oldSlug,
      );
    }
    final updated = [...custom];
    updated[oldIndex] = updated[oldIndex].copyWith(slug: normalized);
    await _saveCustomModels(updated);
    await _renameHiddenModelId(
      provider: provider,
      oldSlug: oldSlug,
      newSlug: normalized,
    );
  }

  /// Deletes a user-managed model.
  Future<void> deleteCustomModel({
    required String provider,
    required String slug,
  }) async {
    final custom = await _customModels();
    final updated = custom
        .where((entry) => entry.provider != provider || entry.slug != slug)
        .toList(growable: false);
    if (updated.length == custom.length) {
      throw const ModelCatalogValidationException(
        CatalogValidationReason.notMutable,
        'Only custom models can be deleted.',
      );
    }
    await _saveCustomModels(updated);
    await _removeHiddenModelId(provider: provider, slug: slug);
  }

  /// Deletes all custom and hidden model state for [provider].
  Future<void> deleteProviderModels(String provider) async {
    final custom = await _customModels();
    await _saveCustomModels(
      custom.where((entry) => entry.provider != provider).toList(),
    );
    final hiddenIds = await _hiddenModelIds();
    hiddenIds.removeWhere((id) => id.startsWith('$provider::'));
    await _saveHiddenModelIds(hiddenIds);
  }

  /// Updates model visibility for built-in or custom models.
  Future<void> setModelHidden({
    required String provider,
    required String slug,
    required bool hidden,
  }) async {
    final models = await allModels(provider);
    final model = models.where((entry) => entry.slug == slug).firstOrNull;
    if (model == null) {
      throw const ModelCatalogValidationException(
        CatalogValidationReason.notMutable,
        'Model does not exist.',
      );
    }
    if (hidden &&
        !models.any((entry) => !entry.isHidden && entry.slug != slug)) {
      throw const ModelCatalogValidationException(
        CatalogValidationReason.modelVisibilityRequired,
        'At least one model must remain visible.',
      );
    }
    final ids = await _hiddenModelIds();
    final id = model.familyId == null
        ? _modelId(provider, slug)
        : _familyId(provider, model.familyId!);
    if (hidden) {
      ids.add(id);
    } else {
      ids.remove(id);
    }
    await _saveHiddenModelIds(ids);
  }

  String _normalizeSlug(String slug) {
    final normalized = slug.trim();
    if (normalized.isEmpty) {
      throw const ModelCatalogValidationException(
        CatalogValidationReason.modelSlugRequired,
        'Model slug is required.',
      );
    }
    return normalized;
  }

  Future<void> _validateNewSlug({
    required String provider,
    required String slug,
    String? allowedExistingSlug,
  }) async {
    final exists = (await allModels(provider)).any((entry) {
      return entry.slug == slug && entry.slug != allowedExistingSlug;
    });
    if (exists) {
      throw const ModelCatalogValidationException(
        CatalogValidationReason.modelSlugDuplicate,
        'A model with this slug already exists.',
      );
    }
  }

  Future<List<LlmModelEntry>> _customModels() async {
    final prefs = await SharedPreferences.getInstance();
    return _customModelsIn(prefs);
  }

  /// Reads user-added slugs for [provider] without yielding between writes.
  static Set<String> customSlugsIn(SharedPreferences prefs, String provider) =>
      {
        for (final entry in _customModelsIn(prefs))
          if (entry.provider == provider) entry.slug,
      };

  static List<LlmModelEntry> _customModelsIn(SharedPreferences prefs) {
    final values = prefs.getStringList(_customModelsKey) ?? const [];
    return values
        .map((value) {
          final decoded = jsonDecode(value) as Map<String, dynamic>;
          return LlmModelEntry.fromJson(decoded);
        })
        .where((entry) => entry.provider.isNotEmpty && entry.slug.isNotEmpty)
        .toList();
  }

  Future<void> _saveCustomModels(List<LlmModelEntry> models) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _customModelsKey,
      models.map((entry) => jsonEncode(entry.toJson())).toList(),
    );
  }

  Future<Set<String>> _hiddenModelIds() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(hiddenModelsKey) ?? const []).toSet();
  }

  Future<void> _saveHiddenModelIds(Set<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(hiddenModelsKey, ids.toList()..sort());
  }

  Future<void> _renameHiddenModelId({
    required String provider,
    required String oldSlug,
    required String newSlug,
  }) async {
    final ids = await _hiddenModelIds();
    final oldId = _modelId(provider, oldSlug);
    if (ids.remove(oldId)) {
      ids.add(_modelId(provider, newSlug));
      await _saveHiddenModelIds(ids);
    }
  }

  Future<void> _removeHiddenModelId({
    required String provider,
    required String slug,
  }) async {
    final ids = await _hiddenModelIds();
    if (ids.remove(_modelId(provider, slug))) {
      await _saveHiddenModelIds(ids);
    }
  }

  String _modelId(String provider, String slug) => '$provider::$slug';

  String _familyId(String provider, String familyId) =>
      '$provider::family:$familyId';
}
