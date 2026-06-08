import 'dart:convert';

import 'package:make_it_sound_natural/constants/model_catalog_defaults.dart';
import 'package:make_it_sound_natural/models/llm_model_entry.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Error thrown when a model catalog edit is invalid.
class ModelCatalogValidationException implements Exception {
  /// Creates a validation exception.
  const ModelCatalogValidationException(this.message);

  /// User-readable validation reason.
  final String message;

  @override
  String toString() => message;
}

/// Persists and resolves local LLM model catalogs.
class ModelCatalogService {
  static const String _customModelsKey = 'llm_custom_models';
  static const String _hiddenModelsKey = 'llm_hidden_models';

  /// Returns all built-in and custom models for a provider.
  Future<List<LlmModelEntry>> allModels(String provider) async {
    final hidden = await _hiddenModelIds();
    final builtIns = ModelCatalogDefaults.modelsForProvider(provider).map(
      (slug) => LlmModelEntry(
        provider: provider,
        slug: slug,
        isBuiltIn: true,
        isHidden: hidden.contains(_modelId(provider, slug)),
      ),
    );
    final custom = (await _customModels())
        .where((entry) => entry.provider == provider)
        .map(
          (entry) => entry.copyWith(
            isHidden: hidden.contains(_modelId(provider, entry.slug)),
          ),
        );
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
    final visible = await visibleModelSlugs(provider);
    if (visible.contains(selectedModel)) {
      return selectedModel;
    }
    return visible.isEmpty ? null : visible.first;
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
        'Only custom models can be deleted.',
      );
    }
    await _saveCustomModels(updated);
    await _removeHiddenModelId(provider: provider, slug: slug);
  }

  /// Updates model visibility for built-in or custom models.
  Future<void> setModelHidden({
    required String provider,
    required String slug,
    required bool hidden,
  }) async {
    final models = await allModels(provider);
    if (!models.any((entry) => entry.slug == slug)) {
      throw const ModelCatalogValidationException('Model does not exist.');
    }
    if (hidden &&
        !models.any((entry) => !entry.isHidden && entry.slug != slug)) {
      throw const ModelCatalogValidationException(
        'At least one model must remain visible.',
      );
    }
    final ids = await _hiddenModelIds();
    final id = _modelId(provider, slug);
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
      throw const ModelCatalogValidationException('Model slug is required.');
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
        'A model with this slug already exists.',
      );
    }
  }

  Future<List<LlmModelEntry>> _customModels() async {
    final prefs = await SharedPreferences.getInstance();
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
    return (prefs.getStringList(_hiddenModelsKey) ?? const []).toSet();
  }

  Future<void> _saveHiddenModelIds(Set<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_hiddenModelsKey, ids.toList()..sort());
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
}
