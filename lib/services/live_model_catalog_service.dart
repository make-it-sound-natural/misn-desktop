import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:logging/logging.dart';
import 'package:make_it_sound_natural/constants/app_defaults.dart';
import 'package:make_it_sound_natural/constants/model_families.dart';
import 'package:make_it_sound_natural/services/model_catalog_cache.dart';
import 'package:make_it_sound_natural/services/model_catalog_service.dart';
import 'package:make_it_sound_natural/services/model_family_resolver.dart';
import 'package:make_it_sound_natural/services/provider_catalog_service.dart';
import 'package:make_it_sound_natural/services/provider_models_client.dart';
import 'package:make_it_sound_natural/services/settings_service.dart';
import 'package:make_it_sound_natural/services/shortcut_service.dart';
import 'package:make_it_sound_natural/utils/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Refreshes cached provider model families and their selected versions.
class LiveModelCatalogService {
  /// Creates a refresh service with an injectable transport and clock.
  LiveModelCatalogService({
    ProviderModelsClient? client,
    DateTime Function()? now,
  }) : _client = client ?? ProviderModelsClient(),
       _now = now ?? DateTime.now;

  /// App-wide catalog refresh service, replaceable by isolated tests.
  static LiveModelCatalogService shared = LiveModelCatalogService();

  /// How long a successfully fetched provider catalog remains fresh.
  static const Duration cacheTtl = Duration(hours: 24);

  final ProviderModelsClient _client;
  final DateTime Function() _now;
  final _cache = ModelCatalogCache();
  final _settings = SettingsService();
  final _providers = ProviderCatalogService();
  final Logger _log = getLogger('LiveModelCatalogService');
  final _revision = ValueNotifier<int>(0);
  final _inFlight = <String, Future<void>>{};
  final _queuedRefreshes = <String, Future<void>>{};
  bool _disposed = false;

  /// Changes after each successful catalog write and selection sync.
  ValueListenable<int> get revision => _revision;

  /// Releases change notifications owned by this service.
  void dispose() {
    _disposed = true;
    _revision.dispose();
  }

  /// Refreshes a supported provider only when its cache is missing or stale.
  Future<void> refreshIfStale(String provider) async {
    if (_disposed || !ModelFamilies.hasProvider(provider)) return;
    final inFlight = _inFlight[provider];
    if (inFlight != null) {
      await inFlight;
      return;
    }
    final cached = await _cache.read(provider);
    if (cached == null || _now().difference(cached.fetchedAt) > cacheTtl) {
      await _startRefresh(provider);
    }
  }

  /// Refreshes a keyed provider, fetching again after any in-flight request.
  ///
  /// Concurrent forced refreshes share a queued run that reads the latest key.
  Future<void> refresh(String provider) {
    if (_disposed || !ModelFamilies.hasProvider(provider)) {
      return Future.value();
    }
    final inFlight = _inFlight[provider];
    if (inFlight == null) return _startRefresh(provider);
    return _queuedRefreshes[provider] ??= inFlight.whenComplete(() {
      unawaited(_queuedRefreshes.remove(provider));
      return _startRefresh(provider);
    });
  }

  Future<void> _startRefresh(String provider) {
    if (_disposed) return Future.value();
    return _inFlight[provider] ??= _refresh(provider).whenComplete(() {
      unawaited(_inFlight.remove(provider));
    });
  }

  /// Refreshes both providers with live catalogs when their cache is stale.
  Future<void> refreshAllIfStale() async {
    await Future.wait([
      refreshIfStale(AppDefaults.openAiProvider),
      refreshIfStale(AppDefaults.anthropicProvider),
    ]);
  }

  Future<void> _refresh(String provider) async {
    final String key;
    try {
      key = provider == AppDefaults.openAiProvider
          ? await _settings.getApiKey()
          : await _settings.getAnthropicApiKey();
    } on PlatformException {
      _log.warning('Model catalog key read failed for $provider.');
      return;
    }
    if (key.isEmpty) return;
    final entry = await _providers.providerById(provider);
    if (entry == null) return;

    try {
      final ids = await _client.fetchModelIds(
        provider: provider,
        baseUrl: entry.baseUrl,
        apiKey: key,
      );
      final families = resolveFamilies(provider, ids);
      final prefs = await SharedPreferences.getInstance();
      // Read the latest selection and issue both writes without yielding:
      // another provider's refresh must see this merged cache and selection.
      final model = _updatedSelection(prefs, provider, families);
      final writes = [
        _cache.writeTo(prefs, provider, families: families, fetchedAt: _now()),
        if (model != null) prefs.setString(SettingsService.modelKey, model),
      ];
      await Future.wait(writes);
      if (model != null) await ShortcutService().setModel(model);
      if (!_disposed) _revision.value += 1;
    } on ProviderModelsException catch (error) {
      _log.warning(
        'Model catalog refresh failed for $provider '
        '(HTTP ${error.statusCode ?? 'none'}).',
      );
    }
  }

  String? _updatedSelection(
    SharedPreferences prefs,
    String provider,
    Map<String, String> families,
  ) {
    final savedProvider =
        prefs.getString(SettingsService.providerKey) ?? AppDefaults.apiProvider;
    final savedModel =
        prefs.getString(SettingsService.modelKey) ?? AppDefaults.model;
    if (savedProvider != provider ||
        ModelCatalogService.customSlugsIn(
          prefs,
          provider,
        ).contains(savedModel)) {
      return null;
    }
    final family = familyForSlug(provider, savedModel);
    if (family == null) return null;
    final updatedModel = families[family.id] ?? '';
    return updatedModel == savedModel ? null : updatedModel;
  }
}
