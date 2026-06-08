import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:make_it_sound_natural/constants/app_defaults.dart';
import 'package:make_it_sound_natural/constants/method_channel_methods.dart';
import 'package:make_it_sound_natural/models/appearance_preferences.dart';
import 'package:make_it_sound_natural/models/provider_auth_failure.dart';
import 'package:make_it_sound_natural/models/screenshot_context_mode.dart';
import 'package:make_it_sound_natural/services/model_catalog_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing application settings persistence.
class SettingsService {
  // Schema version for settings migration
  static const int _currentSchemaVersion = 1;
  static const String _schemaVersionKey = 'settings_schema_version';

  static const String _apiKeyKey = 'openai_api_key';
  static const String _providerKey = 'api_provider';
  static const String _openRouterApiKeyKey = 'openrouter_api_key';
  static const String _customPromptKey = 'custom_prompt';
  static const String _contextKey = 'user_context';
  static const String _modelKey = 'openai_model';
  static const String _shortcutKey = 'app_shortcut';
  static const String _shortcutReplaceKey = 'app_shortcut_replace';
  static const String _shortcutAppendKey = 'app_shortcut_append';
  static const String _defaultVariantKey = 'default_variant';
  static const String _screenshotContextModeKey = 'screenshot_context_mode';
  static const String _pendingScreenshotContextModeKey =
      'pending_screenshot_context_mode';
  static const String _appearancePreferencesKey =
      AppDefaults.appearancePreferencesKey;
  static const String _providerAuthFailurePrefix = 'provider_auth_failure_';

  static const MethodChannel _channel = MethodChannel(
    MethodChannelMethods.channelName,
  );

  /// Migrates settings schema if needed.
  /// Call this on app startup before accessing settings.
  Future<void> migrateIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final storedVersion = prefs.getInt(_schemaVersionKey) ?? 0;

    if (storedVersion < _currentSchemaVersion) {
      await _runMigrations(prefs, storedVersion);
      await prefs.setInt(_schemaVersionKey, _currentSchemaVersion);
    }
  }

  /// Run migrations from old version to current version.
  Future<void> _runMigrations(
    SharedPreferences prefs,
    int fromVersion,
  ) async {
    // Migration v0 -> v1: Initial schema (no changes needed)
    // This establishes the baseline for future migrations.

    // Example future migration (v1 -> v2):
    // if (fromVersion < 2) {
    //   // Rename a key
    //   final oldValue = prefs.getString('old_key');
    //   if (oldValue != null) {
    //     await prefs.setString('new_key', oldValue);
    //     await prefs.remove('old_key');
    //   }
    // }

    // Example future migration (v2 -> v3):
    // if (fromVersion < 3) {
    //   // Transform data format
    //   final oldFormat = prefs.getString('some_key');
    //   if (oldFormat != null) {
    //     final newFormat = transformData(oldFormat);
    //     await prefs.setString('some_key', newFormat);
    //   }
    // }
  }

  /// Gets the stored OpenAI API key.
  Future<String> getApiKey() async {
    return _getSecureString(
      getMethod: MethodChannelMethods.getStoredApiKey,
      storeMethod: MethodChannelMethods.storeApiKey,
      legacyKey: _apiKeyKey,
    );
  }

  /// Saves the OpenAI API key.
  Future<void> setApiKey(String apiKey) async {
    await _setSecureString(
      storeMethod: MethodChannelMethods.storeApiKey,
      legacyKey: _apiKeyKey,
      value: apiKey.trim(),
    );
    await clearProviderAuthFailure(AppDefaults.openAiProvider);
  }

  /// Gets the selected API provider.
  Future<String> getProvider() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_providerKey) ?? AppDefaults.apiProvider;
  }

  /// Saves the API provider preference.
  Future<void> setProvider(String provider) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_providerKey, provider);
  }

  /// Gets the stored OpenRouter API key.
  Future<String> getOpenRouterApiKey() async {
    return _getSecureString(
      getMethod: MethodChannelMethods.getStoredOpenRouterApiKey,
      storeMethod: MethodChannelMethods.storeOpenRouterApiKey,
      legacyKey: _openRouterApiKeyKey,
    );
  }

  /// Saves the OpenRouter API key.
  Future<void> setOpenRouterApiKey(String apiKey) async {
    await _setSecureString(
      storeMethod: MethodChannelMethods.storeOpenRouterApiKey,
      legacyKey: _openRouterApiKeyKey,
      value: apiKey.trim(),
    );
    await clearProviderAuthFailure(AppDefaults.openRouterProvider);
  }

  /// Gets a custom provider API key from secure storage.
  Future<String> getCustomProviderApiKey(String provider) async {
    try {
      final apiKey = await _channel.invokeMethod<String>(
        MethodChannelMethods.getStoredCustomProviderApiKey,
        {'provider': provider},
      );
      return apiKey?.trim() ?? '';
    } on MissingPluginException {
      return '';
    }
  }

  /// Saves a custom provider API key in secure storage.
  Future<void> setCustomProviderApiKey(String provider, String apiKey) async {
    try {
      await _channel.invokeMethod<void>(
        MethodChannelMethods.storeCustomProviderApiKey,
        {'provider': provider, 'apiKey': apiKey.trim()},
      );
    } on MissingPluginException {
      return;
    }
    await clearProviderAuthFailure(provider);
  }

  /// Deletes a custom provider API key from secure storage.
  Future<void> deleteCustomProviderApiKey(String provider) async {
    try {
      await _channel.invokeMethod<void>(
        MethodChannelMethods.deleteStoredCustomProviderApiKey,
        {'provider': provider},
      );
    } on MissingPluginException {
      return;
    }
    await clearProviderAuthFailure(provider);
  }

  /// Returns whether the selected provider has a usable API key.
  Future<bool> hasApiKeyForActiveProvider() async {
    final provider = await getProvider();
    final key = switch (provider) {
      AppDefaults.openRouterProvider => await getOpenRouterApiKey(),
      AppDefaults.openAiProvider => await getApiKey(),
      _ => await getCustomProviderApiKey(provider),
    };
    return key.trim().isNotEmpty;
  }

  /// Returns whether the selected provider has key and visible model.
  Future<bool> hasReadyActiveProviderForRewrite() async {
    final provider = await getProvider();
    if (!await hasApiKeyForActiveProvider()) return false;

    final visibleModels = await ModelCatalogService().visibleModelSlugs(
      provider,
    );
    return visibleModels.isNotEmpty;
  }

  /// Records non-secret auth-failure metadata for a provider.
  Future<void> recordProviderAuthFailure({
    required String provider,
    required String message,
  }) async {
    if (!_isSupportedAuthFailureProvider(provider)) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final failure = ProviderAuthFailure(
      provider: provider,
      message: message.trim().isEmpty
          ? 'Invalid API key. Check settings.'
          : message.trim(),
      occurredAt: DateTime.now().toUtc(),
    );
    await prefs.setString(
      _providerAuthFailureKey(provider),
      jsonEncode(failure.toJson()),
    );
  }

  /// Gets recorded auth-failure metadata for [provider], if any.
  Future<ProviderAuthFailure?> getProviderAuthFailure(String provider) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_providerAuthFailureKey(provider));
    if (raw == null || raw.isEmpty) return null;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return ProviderAuthFailure.fromJson(
        Map<String, Object?>.from(decoded),
      );
    } on FormatException {
      return null;
    }
  }

  /// Clears recorded auth-failure metadata for [provider].
  Future<void> clearProviderAuthFailure(String provider) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_providerAuthFailureKey(provider));
  }

  /// Clears recorded auth-failure metadata for the active provider.
  Future<void> clearAuthFailureForActiveProvider() async {
    await clearProviderAuthFailure(await getProvider());
  }

  /// Gets the custom prompt template.
  Future<String> getCustomPrompt() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_customPromptKey) ?? '';
  }

  /// Saves the custom prompt template.
  Future<void> setCustomPrompt(String prompt) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_customPromptKey, prompt);
  }

  /// Gets the stored user context.
  Future<String> getContext() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_contextKey) ?? '';
  }

  /// Saves the user context.
  Future<void> setContext(String context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_contextKey, context);
  }

  /// Gets the selected LLM model.
  Future<String> getModel() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_modelKey) ?? AppDefaults.model;
  }

  /// Saves the LLM model preference.
  Future<void> setModel(String model) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_modelKey, model);
  }

  /// Gets the correction shortcut.
  Future<String> getShortcut() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_shortcutKey) ?? AppDefaults.correctionShortcut;
  }

  /// Saves the correction shortcut.
  Future<void> setShortcut(String shortcut) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_shortcutKey, shortcut);
  }

  /// Gets the replace context shortcut.
  Future<String> getReplaceShortcut() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_shortcutReplaceKey) ?? AppDefaults.replaceShortcut;
  }

  /// Saves the replace context shortcut.
  Future<void> setReplaceShortcut(String shortcut) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_shortcutReplaceKey, shortcut);
  }

  /// Gets the append context shortcut.
  Future<String> getAppendShortcut() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_shortcutAppendKey) ?? AppDefaults.appendShortcut;
  }

  /// Saves the append context shortcut.
  Future<void> setAppendShortcut(String shortcut) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_shortcutAppendKey, shortcut);
  }

  /// Restores all global shortcuts to [AppDefaults].
  Future<void> resetShortcutsToDefaults() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_shortcutKey, AppDefaults.correctionShortcut);
    await prefs.setString(_shortcutReplaceKey, AppDefaults.replaceShortcut);
    await prefs.setString(_shortcutAppendKey, AppDefaults.appendShortcut);
  }

  /// Gets the default variant preference.
  Future<String> getDefaultVariant() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_defaultVariantKey) ?? AppDefaults.variant;
  }

  /// Saves the default variant preference.
  Future<void> setDefaultVariant(String variant) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_defaultVariantKey, variant);
  }

  /// Gets the screenshot context mode.
  Future<ScreenshotContextMode> getScreenshotContextMode() async {
    final prefs = await SharedPreferences.getInstance();
    return ScreenshotContextMode.fromValue(
      prefs.getString(_screenshotContextModeKey),
    );
  }

  /// Saves the screenshot context mode.
  Future<void> setScreenshotContextMode(ScreenshotContextMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_screenshotContextModeKey, mode.value);
  }

  /// Gets the pending screenshot context mode, if non-off intent is saved.
  Future<ScreenshotContextMode?> getPendingScreenshotContextMode() async {
    final prefs = await SharedPreferences.getInstance();
    final mode = ScreenshotContextMode.fromValue(
      prefs.getString(_pendingScreenshotContextModeKey),
    );
    return mode == ScreenshotContextMode.off ? null : mode;
  }

  /// Saves a non-off screenshot context mode as pending user intent.
  Future<void> setPendingScreenshotContextMode(
    ScreenshotContextMode mode,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    if (mode == ScreenshotContextMode.off) {
      await prefs.remove(_pendingScreenshotContextModeKey);
      return;
    }
    await prefs.setString(_pendingScreenshotContextModeKey, mode.value);
  }

  /// Clears pending screenshot context intent.
  Future<void> clearPendingScreenshotContextMode() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingScreenshotContextModeKey);
  }

  /// Gets local appearance preferences.
  Future<AppearancePreferences> getAppearancePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final rawValue = prefs.getString(_appearancePreferencesKey);
    if (rawValue == null || rawValue.isEmpty) {
      return const AppearancePreferences.defaults();
    }

    try {
      final decoded = jsonDecode(rawValue);
      if (decoded is! Map<String, Object?>) {
        return const AppearancePreferences.defaults();
      }
      return AppearancePreferences.fromJson(decoded);
    } on FormatException {
      return const AppearancePreferences.defaults();
    }
  }

  /// Saves local appearance preferences as one versioned object.
  Future<void> setAppearancePreferences(
    AppearancePreferences preferences,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _appearancePreferencesKey,
      jsonEncode(preferences.toJson()),
    );
  }

  /// Restores local appearance preferences to defaults.
  Future<void> resetAppearancePreferences() async {
    await setAppearancePreferences(const AppearancePreferences.defaults());
  }

  Future<String> _getSecureString({
    required String getMethod,
    required String storeMethod,
    required String legacyKey,
  }) async {
    try {
      final stored = await _channel.invokeMethod<String>(getMethod);
      if (stored != null && stored.isNotEmpty) {
        return stored.trim();
      }

      final legacyValue = (await _readLegacyString(legacyKey)).trim();
      if (legacyValue.isEmpty) {
        return '';
      }

      await _channel.invokeMethod<void>(storeMethod, legacyValue);
      await _removeLegacyString(legacyKey);
      return legacyValue;
    } on MissingPluginException {
      return _readLegacyString(legacyKey);
    }
  }

  Future<void> _setSecureString({
    required String storeMethod,
    required String legacyKey,
    required String value,
  }) async {
    final normalized = value.trim();
    try {
      await _channel.invokeMethod<void>(storeMethod, normalized);
      await _removeLegacyString(legacyKey);
    } on MissingPluginException {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(legacyKey, normalized);
    }
  }

  Future<String> _readLegacyString(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(key) ?? '';
  }

  Future<void> _removeLegacyString(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }

  bool _isSupportedAuthFailureProvider(String provider) {
    return provider.trim().isNotEmpty;
  }

  String _providerAuthFailureKey(String provider) {
    return '$_providerAuthFailurePrefix$provider';
  }
}
