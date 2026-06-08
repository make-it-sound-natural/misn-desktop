import 'dart:convert';

import 'package:make_it_sound_natural/constants/app_defaults.dart';
import 'package:make_it_sound_natural/models/llm_provider_entry.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Error thrown when provider catalog edits are invalid.
class ProviderCatalogValidationException implements Exception {
  /// Creates a validation exception.
  const ProviderCatalogValidationException(this.message);

  /// User-readable validation reason.
  final String message;

  @override
  String toString() => message;
}

/// Persists custom provider metadata and exposes all providers.
class ProviderCatalogService {
  static const String _customProvidersKey = 'llm_custom_providers';

  static const List<LlmProviderEntry> _builtIns = [
    LlmProviderEntry(
      id: AppDefaults.openRouterProvider,
      displayName: 'OpenRouter',
      baseUrl: 'https://openrouter.ai/api/v1',
      isBuiltIn: true,
    ),
    LlmProviderEntry(
      id: AppDefaults.openAiProvider,
      displayName: 'OpenAI',
      baseUrl: 'https://api.openai.com/v1',
      isBuiltIn: true,
    ),
  ];

  /// Returns built-in providers followed by user-added providers.
  Future<List<LlmProviderEntry>> allProviders() async {
    return [..._builtIns, ...await customProviders()];
  }

  /// Returns only user-added providers.
  Future<List<LlmProviderEntry>> customProviders() async {
    final prefs = await SharedPreferences.getInstance();
    final values = prefs.getStringList(_customProvidersKey) ?? const [];
    return values
        .map((value) {
          try {
            final decoded = jsonDecode(value) as Map<String, dynamic>;
            return LlmProviderEntry.fromJson(decoded);
          } on FormatException {
            return const LlmProviderEntry(
              id: '',
              displayName: '',
              baseUrl: '',
            );
          }
        })
        .where((entry) {
          return entry.id.isNotEmpty &&
              entry.displayName.isNotEmpty &&
              entry.baseUrl.isNotEmpty;
        })
        .toList();
  }

  /// Adds a custom provider and returns the saved entry.
  Future<LlmProviderEntry> addCustomProvider({
    required String displayName,
    required String baseUrl,
  }) async {
    final name = _normalizeRequired(displayName, 'Provider name is required.');
    final url = _normalizeUrl(baseUrl);
    final id = await _generateProviderId(name);
    final provider = LlmProviderEntry(id: id, displayName: name, baseUrl: url);
    await _saveCustomProviders([...await customProviders(), provider]);
    return provider;
  }

  /// Updates editable fields for a custom provider.
  Future<LlmProviderEntry> editCustomProvider({
    required String id,
    required String displayName,
    required String baseUrl,
  }) async {
    final custom = await customProviders();
    final index = custom.indexWhere((entry) => entry.id == id);
    if (index == -1) {
      throw const ProviderCatalogValidationException(
        'Only custom providers can be edited.',
      );
    }
    final updated = custom[index].copyWith(
      displayName: _normalizeRequired(
        displayName,
        'Provider name is required.',
      ),
      baseUrl: _normalizeUrl(baseUrl),
    );
    final next = [...custom];
    next[index] = updated;
    await _saveCustomProviders(next);
    return updated;
  }

  /// Deletes a custom provider.
  Future<void> deleteCustomProvider(String id) async {
    final custom = await customProviders();
    final next = custom.where((entry) => entry.id != id).toList();
    if (next.length == custom.length) {
      throw const ProviderCatalogValidationException(
        'Only custom providers can be deleted.',
      );
    }
    await _saveCustomProviders(next);
  }

  /// Resolves provider id to provider metadata.
  Future<LlmProviderEntry?> providerById(String id) async {
    for (final provider in await allProviders()) {
      if (provider.id == id) return provider;
    }
    return null;
  }

  /// Converts API root or full chat URL into a chat completions URL.
  static String normalizedChatCompletionsUrl(String rawUrl) {
    final trimmed = rawUrl.trim().replaceAll(RegExp(r'/+$'), '');
    if (trimmed.endsWith('/chat/completions')) {
      return trimmed;
    }
    return '$trimmed/chat/completions';
  }

  Future<void> _saveCustomProviders(List<LlmProviderEntry> providers) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _customProvidersKey,
      providers.map((entry) => jsonEncode(entry.toJson())).toList(),
    );
  }

  Future<String> _generateProviderId(String displayName) async {
    final base = _slugify(displayName);
    final existing = (await allProviders()).map((entry) => entry.id).toSet();
    if (!existing.contains(base)) return base;
    var counter = 2;
    while (existing.contains('$base-$counter')) {
      counter += 1;
    }
    return '$base-$counter';
  }

  String _slugify(String displayName) {
    final slug = displayName
        .toLowerCase()
        .replaceAll(RegExp('[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    if (slug.isEmpty) {
      throw const ProviderCatalogValidationException(
        'Provider name must contain letters or numbers.',
      );
    }
    return slug;
  }

  String _normalizeRequired(String value, String message) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      throw ProviderCatalogValidationException(message);
    }
    return trimmed;
  }

  String _normalizeUrl(String value) {
    final trimmed = _normalizeRequired(value, 'Base URL is required.');
    final uri = Uri.tryParse(trimmed);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw const ProviderCatalogValidationException(
        'Base URL must be a valid HTTPS URL.',
      );
    }
    return trimmed.replaceAll(RegExp(r'/+$'), '');
  }
}
