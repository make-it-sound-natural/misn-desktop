import 'dart:async';

import 'package:flutter/material.dart';
import 'package:make_it_sound_natural/constants/app_defaults.dart';
import 'package:make_it_sound_natural/constants/model_catalog_defaults.dart';
import 'package:make_it_sound_natural/l10n/gen/app_localizations.dart';
import 'package:make_it_sound_natural/models/llm_model_entry.dart';
import 'package:make_it_sound_natural/models/llm_provider_entry.dart';
import 'package:make_it_sound_natural/models/provider_auth_failure.dart';
import 'package:make_it_sound_natural/services/model_catalog_service.dart';
import 'package:make_it_sound_natural/services/provider_catalog_service.dart';
import 'package:make_it_sound_natural/services/settings_service.dart';
import 'package:make_it_sound_natural/services/shortcut_service.dart';
import 'package:make_it_sound_natural/services/speed_tracking_service.dart';
import 'package:make_it_sound_natural/theme/app_design_tokens.dart';
import 'package:make_it_sound_natural/theme/app_theme.dart';
import 'package:make_it_sound_natural/widgets/app_dialog_escape_dismiss.dart';
import 'package:make_it_sound_natural/widgets/app_settings_section.dart';

const double _wideProviderRowHeight = 76;
const double _mediumProviderRowHeight = 68;

/// Settings section for API provider configuration.
class ApiProviderSection extends StatefulWidget {
  /// Creates the API provider settings section widget.
  const ApiProviderSection({super.key});

  @override
  State<ApiProviderSection> createState() => _ApiProviderSectionState();
}

class _ApiProviderSectionState extends State<ApiProviderSection> {
  final _apiKeyController = TextEditingController();
  final _apiKeyFocusNode = FocusNode();
  final _openRouterApiKeyController = TextEditingController();
  final _openRouterApiKeyFocusNode = FocusNode();
  final _customProviderApiKeyController = TextEditingController();
  final _customProviderApiKeyFocusNode = FocusNode();
  final _settingsService = SettingsService();
  final _shortcutService = ShortcutService();
  final _speedTrackingService = SpeedTrackingService();
  final _modelCatalogService = ModelCatalogService();
  final _providerCatalogService = ProviderCatalogService();

  String _selectedProvider = AppDefaults.apiProvider;
  String _selectedModel = AppDefaults.model;
  Map<String, List<String>> _visibleModelsByProvider = {};
  List<LlmModelEntry> _openRouterCatalog = [];
  List<LlmProviderEntry> _providers = [];
  Map<String, ({double? avg, int count})> _speedStats = {};
  ProviderAuthFailure? _activeAuthFailure;
  String _lastSavedApiKey = '';
  String _lastSavedOpenRouterApiKey = '';
  String _lastSavedCustomProviderApiKey = '';
  bool _isApiKeyVisible = false;

  List<String> get _availableModels =>
      _visibleModelsByProvider[_selectedProvider] ??
      ModelCatalogDefaults.modelsForProvider(_selectedProvider);

  LlmProviderEntry? get _selectedProviderEntry {
    for (final provider in _providers) {
      if (provider.id == _selectedProvider) return provider;
    }
    return null;
  }

  bool get _isCustomProvider => _selectedProviderEntry?.isBuiltIn == false;

  List<LlmProviderEntry> get _providerOptions {
    if (_providers.isNotEmpty) return _providers;
    return const [
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
  }

  TextEditingController get _activeApiKeyController {
    if (_selectedProvider == AppDefaults.openRouterProvider) {
      return _openRouterApiKeyController;
    }
    if (_selectedProvider == AppDefaults.openAiProvider) {
      return _apiKeyController;
    }
    return _customProviderApiKeyController;
  }

  FocusNode get _activeApiKeyFocusNode {
    if (_selectedProvider == AppDefaults.openRouterProvider) {
      return _openRouterApiKeyFocusNode;
    }
    if (_selectedProvider == AppDefaults.openAiProvider) {
      return _apiKeyFocusNode;
    }
    return _customProviderApiKeyFocusNode;
  }

  String get _apiKeyHint {
    if (_selectedProvider == AppDefaults.openRouterProvider) return 'sk-or-...';
    if (_selectedProvider == AppDefaults.openAiProvider) return 'sk-...';
    return 'Bearer token';
  }

  String _normalizeProvider(String provider) {
    if (_providers.any((entry) => entry.id == provider)) {
      return provider;
    }
    return AppDefaults.apiProvider;
  }

  String? _resolveModelForProvider(
    String provider,
    String model,
    Map<String, List<String>> visibleModelsByProvider,
  ) {
    final providerModels = visibleModelsByProvider[provider] ?? const [];
    if (providerModels.isEmpty) {
      return null;
    }
    if (providerModels.contains(model)) {
      return model;
    }
    return providerModels.first;
  }

  @override
  void initState() {
    super.initState();
    unawaited(_loadSettings());
    _apiKeyFocusNode.addListener(_onApiKeyFocusChange);
    _openRouterApiKeyFocusNode.addListener(_onOpenRouterApiKeyFocusChange);
    _customProviderApiKeyFocusNode.addListener(
      _onCustomProviderApiKeyFocusChange,
    );
  }

  @override
  void dispose() {
    _apiKeyFocusNode
      ..removeListener(_onApiKeyFocusChange)
      ..dispose();
    _openRouterApiKeyFocusNode
      ..removeListener(_onOpenRouterApiKeyFocusChange)
      ..dispose();
    _customProviderApiKeyFocusNode
      ..removeListener(_onCustomProviderApiKeyFocusChange)
      ..dispose();
    _apiKeyController.dispose();
    _openRouterApiKeyController.dispose();
    _customProviderApiKeyController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final provider = await _settingsService.getProvider();
    final providers = await _providerCatalogService.allProviders();
    final apiKey = await _settingsService.getApiKey();
    final openRouterApiKey = await _settingsService.getOpenRouterApiKey();
    final customProviderApiKey = await _settingsService.getCustomProviderApiKey(
      provider,
    );
    final model = await _settingsService.getModel();
    final speedStats = await _speedTrackingService.getAllStats();
    final visibleModelsByProvider = await _loadVisibleModelsByProvider(
      providers,
    );
    _providers = providers;
    final resolvedProvider = _normalizeProvider(provider);
    final openRouterCatalog = await _modelCatalogService.allModels(
      resolvedProvider,
    );
    final resolvedModel = _resolveModelForProvider(
      resolvedProvider,
      model,
      visibleModelsByProvider,
    );
    final activeAuthFailure = await _settingsService.getProviderAuthFailure(
      resolvedProvider,
    );

    if (mounted) {
      setState(() {
        _selectedProvider = resolvedProvider;
        _activeAuthFailure = activeAuthFailure;
        _visibleModelsByProvider = visibleModelsByProvider;
        _openRouterCatalog = openRouterCatalog;
        _apiKeyController.text = apiKey;
        _lastSavedApiKey = apiKey;
        _openRouterApiKeyController.text = openRouterApiKey;
        _lastSavedOpenRouterApiKey = openRouterApiKey;
        _customProviderApiKeyController.text = customProviderApiKey;
        _lastSavedCustomProviderApiKey = customProviderApiKey;
        _providers = providers;
        _selectedModel = resolvedModel ?? '';
        _speedStats = speedStats;
      });
    }

    if (resolvedProvider != provider) {
      await _settingsService.setProvider(resolvedProvider);
      await _shortcutService.setProvider(resolvedProvider);
    }

    final modelToSync = resolvedModel ?? '';
    if (modelToSync != model) {
      await _settingsService.setModel(modelToSync);
      await _shortcutService.setModel(modelToSync);
    }
    await _syncSelectedCustomProviderConfig();
  }

  Future<Map<String, List<String>>> _loadVisibleModelsByProvider(
    List<LlmProviderEntry> providers,
  ) async {
    final result = <String, List<String>>{};
    for (final provider in providers) {
      result[provider.id] = await _modelCatalogService.visibleModelSlugs(
        provider.id,
      );
    }
    return result;
  }

  Future<void> _reloadModelCatalogAndResolveSelection() async {
    final providers = await _providerCatalogService.allProviders();
    final visibleModelsByProvider = await _loadVisibleModelsByProvider(
      providers,
    );
    final openRouterCatalog = await _modelCatalogService.allModels(
      _selectedProvider,
    );
    final resolvedModel = _resolveModelForProvider(
      _selectedProvider,
      _selectedModel,
      visibleModelsByProvider,
    );

    if (!mounted) return;
    setState(() {
      _visibleModelsByProvider = visibleModelsByProvider;
      _openRouterCatalog = openRouterCatalog;
      _providers = providers;
      _selectedModel = resolvedModel ?? '';
    });

    await _settingsService.setModel(resolvedModel ?? '');
    await _shortcutService.setModel(resolvedModel ?? '');
  }

  Future<void> _setOpenRouterModelHidden(
    LlmModelEntry entry,
    bool hidden,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      await _modelCatalogService.setModelHidden(
        provider: entry.provider,
        slug: entry.slug,
        hidden: hidden,
      );
      await _reloadModelCatalogAndResolveSelection();
    } on ModelCatalogValidationException catch (error) {
      _showModelCatalogError(
        _localizedModelCatalogError(l10n, error.message),
      );
    }
  }

  void _showModelCatalogError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _onApiKeyFocusChange() {
    if (!_apiKeyFocusNode.hasFocus) {
      unawaited(_saveApiKeyIfChanged());
    }
  }

  void _onOpenRouterApiKeyFocusChange() {
    if (!_openRouterApiKeyFocusNode.hasFocus) {
      unawaited(_saveOpenRouterApiKeyIfChanged());
    }
  }

  void _onCustomProviderApiKeyFocusChange() {
    if (!_customProviderApiKeyFocusNode.hasFocus) {
      unawaited(_saveCustomProviderApiKeyIfChanged());
    }
  }

  Future<void> _saveApiKeyIfChanged() async {
    final currentKey = _apiKeyController.text.trim();
    if (_apiKeyController.text != currentKey) {
      _apiKeyController.text = currentKey;
    }
    if (currentKey != _lastSavedApiKey) {
      _lastSavedApiKey = currentKey;
      await _settingsService.setApiKey(currentKey);
      await _shortcutService.setApiKey(currentKey);
      if (mounted && _selectedProvider == AppDefaults.openAiProvider) {
        setState(() => _activeAuthFailure = null);
      }
      if (mounted && currentKey.isNotEmpty) {
        _showSavedSnackBar();
      }
    }
  }

  Future<void> _saveOpenRouterApiKeyIfChanged() async {
    final currentKey = _openRouterApiKeyController.text.trim();
    if (_openRouterApiKeyController.text != currentKey) {
      _openRouterApiKeyController.text = currentKey;
    }
    if (currentKey != _lastSavedOpenRouterApiKey) {
      _lastSavedOpenRouterApiKey = currentKey;
      await _settingsService.setOpenRouterApiKey(currentKey);
      await _shortcutService.setOpenRouterApiKey(currentKey);
      if (mounted && _selectedProvider == AppDefaults.openRouterProvider) {
        setState(() => _activeAuthFailure = null);
      }
      if (mounted && currentKey.isNotEmpty) {
        _showSavedSnackBar();
      }
    }
  }

  Future<void> _saveCustomProviderApiKeyIfChanged() async {
    final currentKey = _customProviderApiKeyController.text.trim();
    if (_customProviderApiKeyController.text != currentKey) {
      _customProviderApiKeyController.text = currentKey;
    }
    if (currentKey != _lastSavedCustomProviderApiKey) {
      _lastSavedCustomProviderApiKey = currentKey;
      await _settingsService.setCustomProviderApiKey(
        _selectedProvider,
        currentKey,
      );
      await _syncSelectedCustomProviderConfig();
      if (mounted && _isCustomProvider) {
        setState(() => _activeAuthFailure = null);
      }
      if (mounted && currentKey.isNotEmpty) {
        _showSavedSnackBar();
      }
    }
  }

  Future<void> _saveActiveApiKeyIfChanged() async {
    if (_selectedProvider == AppDefaults.openRouterProvider) {
      await _saveOpenRouterApiKeyIfChanged();
      return;
    }
    if (_isCustomProvider) {
      await _saveCustomProviderApiKeyIfChanged();
      return;
    }
    await _saveApiKeyIfChanged();
  }

  Future<void> _syncSelectedCustomProviderConfig() async {
    final provider = _selectedProviderEntry;
    if (provider == null || provider.isBuiltIn) return;
    await _shortcutService.setCustomProviderConfig(
      provider: provider.id,
      baseUrl: provider.baseUrl,
      apiKey: _customProviderApiKeyController.text.trim(),
    );
  }

  void _showSavedSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context)!.apiKeySaved),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  String _formatModelDisplay(String model) {
    final stats = _speedStats[model];
    if (stats == null || stats.count == 0) {
      return model;
    }
    final avgStr = stats.avg!.toStringAsFixed(1);
    return '$model (${avgStr}s avg)';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final initialModelValue = _availableModels.contains(_selectedModel)
        ? _selectedModel
        : (_availableModels.isNotEmpty ? _availableModels.first : null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSettingsSection(
          title: l10n.apiProvider,
          subtitle: l10n.aiProviderDescription,
          children: [
            _ProviderSettingsPanel(
              providerSelector: _buildProviderSelector(),
              apiKeyField: _buildApiKeyField(l10n),
              apiKeySubtitle: _activeAuthFailure == null
                  ? l10n.apiKeyStoredLocally
                  : l10n.apiKeyNeedsAttention,
              modelSelector: _buildModelSelector(initialModelValue),
              modelSubtitle: _isCustomProvider && _availableModels.isEmpty
                  ? l10n.customProviderNoModels
                  : l10n.modelUsedForRewrite,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        _buildCustomProviderManagementPanel(),
        const SizedBox(height: AppSpacing.sm),
        _ApiKeySecurityNote(text: l10n.customProviderCompatibilityNote),
        if (_selectedProvider == AppDefaults.openRouterProvider ||
            _isCustomProvider) ...[
          const SizedBox(height: AppSpacing.lg),
          _buildOpenRouterModelManagementPanel(l10n),
        ],
        const SizedBox(height: AppSpacing.lg),
        _ApiKeySecurityNote(text: l10n.apiKeySecurityNote),
      ],
    );
  }

  Widget _buildProviderSelector() {
    final colorScheme = Theme.of(context).colorScheme;
    return DropdownButtonFormField<String>(
      key: const Key('apiProvider-providerSelector'),
      initialValue:
          _providerOptions.any((entry) => entry.id == _selectedProvider)
          ? _selectedProvider
          : null,
      isExpanded: true,
      dropdownColor: _fieldFillColor(),
      iconEnabledColor: colorScheme.onSurfaceVariant,
      iconDisabledColor: colorScheme.onSurfaceVariant.withValues(alpha: 0.38),
      style: AppTextStyles.controlOf(context),
      decoration: _fieldDecoration(
        prefixIcon: Icon(
          Icons.swap_horiz_rounded,
          color: colorScheme.onSurfaceVariant,
        ),
      ),
      icon: const Icon(Icons.keyboard_arrow_down_rounded),
      items: _providerOptions.map((provider) {
        return DropdownMenuItem(
          value: provider.id,
          child: Text(provider.displayName, overflow: TextOverflow.ellipsis),
        );
      }).toList(),
      onChanged: (newValue) async {
        if (newValue == null || newValue == _selectedProvider) return;
        final providers = await _providerCatalogService.allProviders();
        final visibleModelsByProvider = await _loadVisibleModelsByProvider(
          providers,
        );
        final catalog = await _modelCatalogService.allModels(newValue);
        final model =
            _resolveModelForProvider(
              newValue,
              _selectedModel,
              visibleModelsByProvider,
            ) ??
            '';
        final authFailure = await _settingsService.getProviderAuthFailure(
          newValue,
        );
        final providerEntry = providers
            .where((entry) => entry.id == newValue)
            .firstOrNull;
        final customApiKey = providerEntry != null && !providerEntry.isBuiltIn
            ? await _settingsService.getCustomProviderApiKey(newValue)
            : '';
        if (!mounted) return;
        setState(() {
          _selectedProvider = newValue;
          _selectedModel = model;
          _activeAuthFailure = authFailure;
          _visibleModelsByProvider = visibleModelsByProvider;
          _openRouterCatalog = catalog;
          _providers = providers;
          _isApiKeyVisible = false;
          if (providerEntry != null && !providerEntry.isBuiltIn) {
            _customProviderApiKeyController.text = customApiKey;
            _lastSavedCustomProviderApiKey = customApiKey;
          }
        });
        await _settingsService.setProvider(newValue);
        await _shortcutService.setProvider(newValue);
        await _settingsService.setModel(model);
        await _shortcutService.setModel(model);
        await _syncSelectedCustomProviderConfig();
      },
    );
  }

  Future<void> _showModelSlugDialog({LlmModelEntry? entry}) async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController(text: entry?.slug ?? '');
    String? errorText;
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AppDialogEscapeDismiss<bool>(
              result: false,
              child: AlertDialog(
                title: Text(entry == null ? l10n.addModel : l10n.editModel),
                content: TextField(
                  key: const Key('apiProvider-modelSlugField'),
                  controller: controller,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: l10n.modelSlug,
                    errorText: errorText,
                  ),
                  onSubmitted: (_) {
                    unawaited(
                      _saveModelSlugDialog(
                        context: context,
                        controller: controller,
                        entry: entry,
                        setError: (message) {
                          setDialogState(() => errorText = message);
                        },
                      ),
                    );
                  },
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text(l10n.cancel),
                  ),
                  FilledButton(
                    key: const Key('apiProvider-saveModelSlug'),
                    onPressed: () {
                      unawaited(
                        _saveModelSlugDialog(
                          context: context,
                          controller: controller,
                          entry: entry,
                          setError: (message) {
                            setDialogState(() => errorText = message);
                          },
                        ),
                      );
                    },
                    child: Text(l10n.save),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    if (saved ?? false) {
      await _reloadModelCatalogAndResolveSelection();
    }
  }

  Future<void> _saveModelSlugDialog({
    required BuildContext context,
    required TextEditingController controller,
    required LlmModelEntry? entry,
    required ValueChanged<String> setError,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      if (entry == null) {
        await _modelCatalogService.addCustomModel(
          provider: _selectedProvider,
          slug: controller.text,
        );
      } else {
        final newSlug = controller.text.trim();
        await _modelCatalogService.editCustomModel(
          provider: entry.provider,
          oldSlug: entry.slug,
          newSlug: newSlug,
        );
        if (_selectedModel == entry.slug) {
          _selectedModel = newSlug;
          await _settingsService.setModel(newSlug);
          await _shortcutService.setModel(newSlug);
        }
      }
      if (context.mounted) {
        Navigator.of(context).pop(true);
      }
    } on ModelCatalogValidationException catch (error) {
      setError(_localizedModelCatalogError(l10n, error.message));
    }
  }

  String _localizedModelCatalogError(AppLocalizations l10n, String message) {
    return switch (message) {
      'Model slug is required.' => l10n.modelSlugRequired,
      'A model with this slug already exists.' => l10n.modelSlugDuplicate,
      'At least one model must remain visible.' => l10n.modelVisibilityRequired,
      _ => message,
    };
  }

  Future<void> _confirmDeleteCustomModel(LlmModelEntry entry) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AppDialogEscapeDismiss<bool>(
          result: false,
          child: AlertDialog(
            title: Text(l10n.deleteModelTitle),
            content: Text(entry.slug),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                key: const Key('apiProvider-confirmDeleteModel'),
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(l10n.deleteModel),
              ),
            ],
          ),
        );
      },
    );
    if (!(confirmed ?? false)) return;
    try {
      await _modelCatalogService.deleteCustomModel(
        provider: entry.provider,
        slug: entry.slug,
      );
      await _reloadModelCatalogAndResolveSelection();
    } on ModelCatalogValidationException catch (error) {
      _showModelCatalogError(
        _localizedModelCatalogError(l10n, error.message),
      );
    }
  }

  Future<void> _showProviderDialog({LlmProviderEntry? entry}) async {
    final l10n = AppLocalizations.of(context)!;
    final nameController = TextEditingController(
      text: entry?.displayName ?? '',
    );
    final urlController = TextEditingController(text: entry?.baseUrl ?? '');
    String? nameErrorText;
    String? urlErrorText;
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AppDialogEscapeDismiss<bool>(
              result: false,
              child: AlertDialog(
                title: Text(
                  entry == null ? l10n.addProvider : l10n.editProvider,
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      key: const Key('apiProvider-providerNameField'),
                      controller: nameController,
                      autofocus: true,
                      decoration: InputDecoration(
                        labelText: l10n.providerName,
                        errorText: nameErrorText,
                      ),
                      onChanged: (_) {
                        if (nameErrorText == null) return;
                        setDialogState(() => nameErrorText = null);
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextField(
                      key: const Key('apiProvider-providerBaseUrlField'),
                      controller: urlController,
                      decoration: InputDecoration(
                        labelText: l10n.providerBaseUrl,
                        errorText: urlErrorText,
                      ),
                      onChanged: (_) {
                        if (urlErrorText == null) return;
                        setDialogState(() => urlErrorText = null);
                      },
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text(l10n.cancel),
                  ),
                  FilledButton(
                    key: const Key('apiProvider-saveProvider'),
                    onPressed: () {
                      unawaited(
                        _saveProviderDialog(
                          context: context,
                          entry: entry,
                          nameController: nameController,
                          urlController: urlController,
                          setErrors: (errors) {
                            setDialogState(() {
                              nameErrorText = errors.name;
                              urlErrorText = errors.url;
                            });
                          },
                        ),
                      );
                    },
                    child: Text(l10n.save),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    if (saved ?? false) {
      await _loadSettings();
    }
  }

  Future<void> _saveProviderDialog({
    required BuildContext context,
    required LlmProviderEntry? entry,
    required TextEditingController nameController,
    required TextEditingController urlController,
    required ValueChanged<({String? name, String? url})> setErrors,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    setErrors((name: null, url: null));
    try {
      if (entry == null) {
        await _providerCatalogService.addCustomProvider(
          displayName: nameController.text,
          baseUrl: urlController.text,
        );
      } else {
        await _providerCatalogService.editCustomProvider(
          id: entry.id,
          displayName: nameController.text,
          baseUrl: urlController.text,
        );
      }
      if (context.mounted) {
        Navigator.of(context).pop(true);
      }
    } on ProviderCatalogValidationException catch (error) {
      final message = _localizedProviderCatalogError(l10n, error.message);
      switch (error.message) {
        case 'Provider name is required.':
        case 'Provider name must contain letters or numbers.':
          setErrors((name: message, url: null));
          return;
        case 'Base URL is required.':
        case 'Base URL must be a valid HTTPS URL.':
          setErrors((name: null, url: message));
          return;
        default:
          _showModelCatalogError(message);
      }
    }
  }

  String _localizedProviderCatalogError(
    AppLocalizations l10n,
    String message,
  ) {
    return switch (message) {
      'Provider name is required.' => l10n.providerNameRequired,
      'Base URL is required.' => l10n.providerUrlRequired,
      'Base URL must be a valid HTTPS URL.' => l10n.providerUrlInvalid,
      'Provider name must contain letters or numbers.' =>
        l10n.providerNameInvalid,
      _ => message,
    };
  }

  Future<void> _confirmDeleteProvider(LlmProviderEntry entry) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AppDialogEscapeDismiss<bool>(
          result: false,
          child: AlertDialog(
            title: Text(l10n.deleteProviderTitle),
            content: Text(entry.displayName),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                key: const Key('apiProvider-confirmDeleteProvider'),
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(l10n.deleteProvider),
              ),
            ],
          ),
        );
      },
    );
    if (!(confirmed ?? false)) return;
    await _providerCatalogService.deleteCustomProvider(entry.id);
    await _modelCatalogService.deleteProviderModels(entry.id);
    await _settingsService.deleteCustomProviderApiKey(entry.id);
    if (_selectedProvider == entry.id) {
      final fallbackModel = await _modelCatalogService.resolveVisibleModel(
        provider: AppDefaults.apiProvider,
        selectedModel: AppDefaults.model,
      );
      _selectedProvider = AppDefaults.apiProvider;
      _selectedModel = fallbackModel ?? AppDefaults.model;
      await _settingsService.setProvider(_selectedProvider);
      await _settingsService.setModel(_selectedModel);
      await _shortcutService.setProvider(_selectedProvider);
      await _shortcutService.setModel(_selectedModel);
    }
    await _loadSettings();
  }

  Widget _buildCustomProviderManagementPanel() {
    final l10n = AppLocalizations.of(context)!;
    final customProviders = _providerOptions
        .where((entry) => !entry.isBuiltIn)
        .toList(growable: false);
    return AppSettingsSection(
      key: const Key('apiProvider-providerManagementPanel'),
      title: l10n.customProviders,
      subtitle: l10n.customProvidersDescription,
      children: [
        AppSettingsRow(
          leading: const AppSettingsIconTile(icon: Icons.hub_rounded),
          title: l10n.addProvider,
          minHeight: AppSizes.compactRowHeight,
          trailing: OutlinedButton.icon(
            key: const Key('apiProvider-addProvider'),
            onPressed: () => unawaited(_showProviderDialog()),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: Text(l10n.addProvider),
          ),
        ),
        if (customProviders.isNotEmpty) const AppSettingsDivider(),
        for (final (index, provider) in customProviders.indexed) ...[
          _CustomProviderRow(
            provider: provider,
            editTooltip: l10n.editProvider,
            deleteTooltip: l10n.deleteProvider,
            onEdit: () => unawaited(_showProviderDialog(entry: provider)),
            onDelete: () => unawaited(_confirmDeleteProvider(provider)),
          ),
          if (index < customProviders.length - 1) const AppSettingsDivider(),
        ],
      ],
    );
  }

  Widget _buildApiKeyField(AppLocalizations l10n) {
    final label = _isApiKeyVisible ? l10n.hideApiKey : l10n.showApiKey;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final authFailureMessage = _activeAuthFailure?.message.trim();
    final authFailureText = _activeAuthFailure == null
        ? null
        : authFailureMessage == null || authFailureMessage.isEmpty
        ? l10n.apiKeyAuthFailureFallback
        : authFailureMessage;
    final field = TextField(
      key: const Key('apiProvider-apiKeyField'),
      controller: _activeApiKeyController,
      focusNode: _activeApiKeyFocusNode,
      obscureText: !_isApiKeyVisible,
      style: AppTextStyles.controlOf(context),
      decoration: _fieldDecoration(
        hintText: _apiKeyHint,
        errorText: authFailureText,
        suffixIcon: IconButton(
          key: const Key('apiProvider-toggleApiKey'),
          tooltip: label,
          icon: Icon(
            _isApiKeyVisible
                ? Icons.visibility_off_rounded
                : Icons.visibility_rounded,
            color: colorScheme.onSurfaceVariant,
          ),
          onPressed: () {
            setState(() => _isApiKeyVisible = !_isApiKeyVisible);
          },
        ),
      ),
      onSubmitted: (_) => unawaited(_saveActiveApiKeyIfChanged()),
    );
    if (authFailureText == null) return field;
    return KeyedSubtree(
      key: const Key('apiProvider-apiKeyAuthFailure'),
      child: field,
    );
  }

  Widget _buildModelSelector(String? initialModelValue) {
    final colorScheme = Theme.of(context).colorScheme;
    return DropdownButtonFormField<String>(
      key: const Key('apiProvider-modelSelector'),
      initialValue: initialModelValue,
      isExpanded: true,
      dropdownColor: _fieldFillColor(),
      iconEnabledColor: colorScheme.onSurfaceVariant,
      iconDisabledColor: colorScheme.onSurfaceVariant.withValues(alpha: 0.38),
      style: AppTextStyles.controlOf(context),
      decoration: _fieldDecoration(),
      icon: const Icon(Icons.keyboard_arrow_down_rounded),
      items: _availableModels.map((model) {
        return DropdownMenuItem<String>(
          value: model,
          child: Text(
            _formatModelDisplay(model),
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.controlOf(context),
          ),
        );
      }).toList(),
      onChanged: _availableModels.isEmpty
          ? null
          : (newValue) async {
              if (newValue == null) return;
              setState(() {
                _selectedModel = newValue;
              });
              await _settingsService.setModel(newValue);
              await _shortcutService.setModel(newValue);
            },
    );
  }

  Widget _buildOpenRouterModelManagementPanel(AppLocalizations l10n) {
    final title = _selectedProvider == AppDefaults.openRouterProvider
        ? l10n.openRouterModels
        : l10n.customProviderModels(
            _selectedProviderEntry?.displayName ?? l10n.customModel,
          );
    final subtitle = _selectedProvider == AppDefaults.openRouterProvider
        ? l10n.openRouterModelsDescription
        : l10n.customProviderModelsDescription;
    return AppSettingsSection(
      key: const Key('apiProvider-modelManagementPanel'),
      title: title,
      subtitle: subtitle,
      children: [
        AppSettingsRow(
          leading: const AppSettingsIconTile(
            icon: Icons.view_list_rounded,
          ),
          title: l10n.addModel,
          minHeight: AppSizes.compactRowHeight,
          trailing: OutlinedButton.icon(
            key: const Key('apiProvider-addOpenRouterModel'),
            onPressed: () => unawaited(_showModelSlugDialog()),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: Text(l10n.addModel),
          ),
        ),
        if (_openRouterCatalog.isNotEmpty) const AppSettingsDivider(),
        for (final (index, entry) in _openRouterCatalog.indexed) ...[
          _OpenRouterModelRow(
            entry: entry,
            modelTypeLabel: entry.isBuiltIn
                ? l10n.builtInModel
                : l10n.customModel,
            hideTooltip: l10n.hideModel,
            showTooltip: l10n.showModel,
            editTooltip: l10n.editModel,
            deleteTooltip: l10n.deleteModel,
            onToggleVisibility: () => unawaited(
              _setOpenRouterModelHidden(entry, !entry.isHidden),
            ),
            onEdit: entry.isBuiltIn
                ? null
                : () => unawaited(_showModelSlugDialog(entry: entry)),
            onDelete: entry.isBuiltIn
                ? null
                : () => unawaited(_confirmDeleteCustomModel(entry)),
          ),
          if (index < _openRouterCatalog.length - 1) const AppSettingsDivider(),
        ],
      ],
    );
  }

  InputDecoration _fieldDecoration({
    String? hintText,
    String? errorText,
    Widget? prefixIcon,
    Widget? suffixIcon,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return InputDecoration(
      hintText: hintText,
      errorText: errorText,
      errorMaxLines: 2,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: _fieldFillColor(),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: BorderSide(color: theme.dividerColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: BorderSide(color: theme.dividerColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: BorderSide(color: colorScheme.primary, width: 2),
      ),
    );
  }

  Color _fieldFillColor() {
    final theme = Theme.of(context);
    if (theme.brightness == Brightness.dark) {
      return AppColors.darkControlSurface;
    }
    return theme.colorScheme.surfaceContainerHighest;
  }
}

class _CustomProviderRow extends StatelessWidget {
  const _CustomProviderRow({
    required this.provider,
    required this.editTooltip,
    required this.deleteTooltip,
    required this.onEdit,
    required this.onDelete,
  });

  final LlmProviderEntry provider;
  final String editTooltip;
  final String deleteTooltip;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AppSettingsRow(
      leading: AppSettingsIconTile(
        icon: Icons.hub_rounded,
        backgroundColor: colorScheme.surfaceContainerHighest,
        iconColor: colorScheme.onSurfaceVariant,
      ),
      title: provider.displayName,
      subtitle: provider.baseUrl,
      minHeight: AppSizes.compactRowHeight,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            key: Key('apiProvider-editProvider-${provider.id}'),
            tooltip: editTooltip,
            icon: const Icon(Icons.edit_rounded),
            onPressed: onEdit,
          ),
          IconButton(
            key: Key('apiProvider-deleteProvider-${provider.id}'),
            tooltip: deleteTooltip,
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

class _OpenRouterModelRow extends StatelessWidget {
  const _OpenRouterModelRow({
    required this.entry,
    required this.modelTypeLabel,
    required this.hideTooltip,
    required this.showTooltip,
    required this.editTooltip,
    required this.deleteTooltip,
    required this.onToggleVisibility,
    required this.onEdit,
    required this.onDelete,
  });

  final LlmModelEntry entry;
  final String modelTypeLabel;
  final String hideTooltip;
  final String showTooltip;
  final String editTooltip;
  final String deleteTooltip;
  final VoidCallback onToggleVisibility;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AppSettingsRow(
      leading: AppSettingsIconTile(
        icon: entry.isHidden
            ? Icons.visibility_off_rounded
            : Icons.visibility_rounded,
        backgroundColor: colorScheme.surfaceContainerHighest,
        iconColor: colorScheme.onSurfaceVariant,
      ),
      title: entry.slug,
      subtitle: modelTypeLabel,
      minHeight: AppSizes.compactRowHeight,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            key: Key(
              entry.isHidden
                  ? 'apiProvider-showModel-${entry.provider}::${entry.slug}'
                  : 'apiProvider-hideModel-${entry.provider}::${entry.slug}',
            ),
            tooltip: entry.isHidden ? showTooltip : hideTooltip,
            icon: Icon(
              entry.isHidden
                  ? Icons.visibility_rounded
                  : Icons.visibility_off_rounded,
            ),
            onPressed: onToggleVisibility,
          ),
          if (onEdit != null)
            IconButton(
              key: Key(
                'apiProvider-editModel-${entry.provider}::${entry.slug}',
              ),
              tooltip: editTooltip,
              icon: const Icon(Icons.edit_rounded),
              onPressed: onEdit,
            ),
          if (onDelete != null)
            IconButton(
              key: Key(
                'apiProvider-deleteModel-${entry.provider}::${entry.slug}',
              ),
              tooltip: deleteTooltip,
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: onDelete,
            ),
        ],
      ),
    );
  }
}

class _ProviderSettingsPanel extends StatelessWidget {
  const _ProviderSettingsPanel({
    required this.providerSelector,
    required this.apiKeyField,
    required this.apiKeySubtitle,
    required this.modelSelector,
    required this.modelSubtitle,
  });

  final Widget providerSelector;
  final Widget apiKeyField;
  final String apiKeySubtitle;
  final Widget modelSelector;
  final String modelSubtitle;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final statusColors = AppStatusColors.of(context);
    return Column(
      children: [
        _ProviderConfigRow(
          icon: Icons.cloud_rounded,
          iconBackground: colorScheme.primaryContainer,
          title: l10n.provider,
          subtitle: l10n.chooseProvider,
          trailing: providerSelector,
        ),
        Divider(height: 1, color: Theme.of(context).dividerColor),
        _ProviderConfigRow(
          icon: Icons.vpn_key_rounded,
          iconBackground: statusColors.successContainer,
          title: l10n.apiKey,
          subtitle: apiKeySubtitle,
          trailing: apiKeyField,
        ),
        Divider(height: 1, color: Theme.of(context).dividerColor),
        _ProviderConfigRow(
          icon: Icons.view_in_ar_outlined,
          iconBackground: colorScheme.secondaryContainer,
          title: l10n.model,
          subtitle: modelSubtitle,
          trailing: modelSelector,
        ),
      ],
    );
  }
}

class _ApiKeySecurityNote extends StatelessWidget {
  const _ApiKeySecurityNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).textTheme.bodySmall?.color;
    return Row(
      children: [
        Icon(
          Icons.lock_rounded,
          color: color,
          size: 18,
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            text,
            style: AppTextStyles.rowSubtitleOf(context),
          ),
        ),
      ],
    );
  }
}

class _ProviderConfigRow extends StatelessWidget {
  const _ProviderConfigRow({
    required this.icon,
    required this.iconBackground,
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  final IconData icon;
  final Color iconBackground;
  final String title;
  final String subtitle;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 700) {
          return Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    _ProviderIconTile(
                      icon: icon,
                      backgroundColor: iconBackground,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(child: _ProviderRowText(title, subtitle)),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                trailing,
              ],
            ),
          );
        }

        final compact = constraints.maxWidth < 980;
        final trailingWidth = constraints.maxWidth >= AppSizes.contentMaxWidth
            ? AppSizes.controlMaxWidth
            : constraints.maxWidth * (compact ? 0.43 : 0.46);
        return ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: compact
                ? _mediumProviderRowHeight
                : _wideProviderRowHeight,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Row(
              children: [
                _ProviderIconTile(
                  icon: icon,
                  backgroundColor: iconBackground,
                  compact: compact,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: _ProviderRowText(title, subtitle)),
                const SizedBox(width: AppSpacing.md),
                SizedBox(width: trailingWidth, child: trailing),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ProviderIconTile extends StatelessWidget {
  const _ProviderIconTile({
    required this.icon,
    required this.backgroundColor,
    this.compact = false,
  });

  final IconData icon;
  final Color backgroundColor;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: compact ? AppSizes.iconTileSmall : AppSizes.iconTile,
      height: compact ? AppSizes.iconTileSmall : AppSizes.iconTile,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Icon(
        icon,
        color: Theme.of(context).colorScheme.onSurface,
        size: compact ? 21 : 23,
      ),
    );
  }
}

class _ProviderRowText extends StatelessWidget {
  const _ProviderRowText(this.title, this.subtitle);

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.rowTitleOf(context),
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          subtitle,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.rowSubtitleOf(context),
        ),
      ],
    );
  }
}
