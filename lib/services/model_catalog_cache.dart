import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// A provider's resolved model families and last successful fetch time.
class CachedModelCatalog {
  /// Creates a cached provider catalog.
  const CachedModelCatalog({
    required this.fetchedAt,
    required this.families,
  });

  /// Time of the last successful model-list request.
  final DateTime fetchedAt;

  /// Concrete model slugs indexed by stable family id.
  final Map<String, String> families;
}

/// Persists resolved provider catalogs in one shared preferences value.
class ModelCatalogCache {
  /// SharedPreferences key for the catalogs and their timestamps.
  static const String storageKey = 'llm_live_model_catalog';

  /// Returns null until [provider] has been successfully fetched.
  Future<CachedModelCatalog?> read(String provider) async {
    final prefs = await SharedPreferences.getInstance();
    final stored = _readCatalogs(prefs)[provider] as Map<String, dynamic>?;
    if (stored == null) return null;
    return CachedModelCatalog(
      fetchedAt: DateTime.parse(stored['fetchedAt'] as String),
      families: (stored['families'] as Map<String, dynamic>)
          .cast<String, String>(),
    );
  }

  /// Merges and issues the write synchronously so provider writes compose.
  Future<bool> writeTo(
    SharedPreferences prefs,
    String provider, {
    required Map<String, String> families,
    required DateTime fetchedAt,
  }) {
    final catalogs = _readCatalogs(prefs);
    catalogs[provider] = {
      'fetchedAt': fetchedAt.toUtc().toIso8601String(),
      'families': families,
    };
    return prefs.setString(storageKey, jsonEncode(catalogs));
  }

  Map<String, dynamic> _readCatalogs(SharedPreferences prefs) {
    final raw = prefs.getString(storageKey);
    return raw == null ? {} : jsonDecode(raw) as Map<String, dynamic>;
  }
}
