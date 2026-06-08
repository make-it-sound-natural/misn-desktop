import 'dart:async';

import 'package:flutter/material.dart';
import 'package:make_it_sound_natural/constants/app_defaults.dart';
import 'package:make_it_sound_natural/constants/model_catalog_defaults.dart';
import 'package:make_it_sound_natural/l10n/gen/app_localizations.dart';
import 'package:make_it_sound_natural/models/llm_model_entry.dart';
import 'package:make_it_sound_natural/models/provider_auth_failure.dart';
import 'package:make_it_sound_natural/services/model_catalog_service.dart';
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
  final _settingsService = SettingsService();
  final _shortcutService = ShortcutService();
  final _speedTrackingService = SpeedTrackingService();
  final _modelCatalogService = ModelCatalogService();

  String _selectedProvider = AppDefaults.apiProvider;
  String _selectedModel = AppDefaults.model;
  Map<String, List<String>> _visibleModelsByProvider = {};
  List<LlmModelEntry> _openRouterCatalog = [];
  Map<String, ({double? avg, int count})> _speedStats = {};
  ProviderAuthFailure? _activeAuthFailure;
  String _lastSavedApiKey = '';
  String _lastSavedOpenRouterApiKey = '';
  bool _isApiKeyVisible = false;

  List<String> get _availableModels =>
      _visibleModelsByProvider[_selectedProvider] ??
      ModelCatalogDefaults.modelsForProvider(_selectedProvider);

  TextEditingController get _activeApiKeyController =>
      _selectedProvider == 'openrouter'
      ? _openRouterApiKeyController
      : _apiKeyController;

  FocusNode get _activeApiKeyFocusNode => _selectedProvider == 'openrouter'
      ? _openRouterApiKeyFocusNode
      : _apiKeyFocusNode;

  String get _apiKeyHint =>
      _selectedProvider == 'openrouter' ? 'sk-or-...' : 'sk-...';

  String _normalizeProvider(String provider) {
    if (ModelCatalogDefaults.hasProvider(provider)) {
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
  }

  @override
  void dispose() {
    _apiKeyFocusNode
      ..removeListener(_onApiKeyFocusChange)
      ..dispose();
    _openRouterApiKeyFocusNode
      ..removeListener(_onOpenRouterApiKeyFocusChange)
      ..dispose();
    _apiKeyController.dispose();
    _openRouterApiKeyController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final provider = await _settingsService.getProvider();
    final apiKey = await _settingsService.getApiKey();
    final openRouterApiKey = await _settingsService.getOpenRouterApiKey();
    final model = await _settingsService.getModel();
    final speedStats = await _speedTrackingService.getAllStats();
    final visibleModelsByProvider = await _loadVisibleModelsByProvider();
    final openRouterCatalog = await _modelCatalogService.allModels(
      'openrouter',
    );
    final resolvedProvider = _normalizeProvider(provider);
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
        if (resolvedModel != null) {
          _selectedModel = resolvedModel;
        }
        _speedStats = speedStats;
      });
    }

    if (resolvedProvider != provider) {
      await _settingsService.setProvider(resolvedProvider);
      await _shortcutService.setProvider(resolvedProvider);
    }

    if (resolvedModel != null && resolvedModel != model) {
      await _settingsService.setModel(resolvedModel);
      await _shortcutService.setModel(resolvedModel);
    }
  }

  Future<Map<String, List<String>>> _loadVisibleModelsByProvider() async {
    return {
      'openai': await _modelCatalogService.visibleModelSlugs('openai'),
      'openrouter': await _modelCatalogService.visibleModelSlugs('openrouter'),
    };
  }

  Future<void> _reloadModelCatalogAndResolveSelection() async {
    final visibleModelsByProvider = await _loadVisibleModelsByProvider();
    final openRouterCatalog = await _modelCatalogService.allModels(
      'openrouter',
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
      if (resolvedModel != null) {
        _selectedModel = resolvedModel;
      }
    });

    if (resolvedModel != null) {
      await _settingsService.setModel(resolvedModel);
      await _shortcutService.setModel(resolvedModel);
    }
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

  Future<void> _saveApiKeyIfChanged() async {
    final currentKey = _apiKeyController.text;
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
    final currentKey = _openRouterApiKeyController.text;
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

  Future<void> _saveActiveApiKeyIfChanged() async {
    if (_selectedProvider == 'openrouter') {
      await _saveOpenRouterApiKeyIfChanged();
      return;
    }
    await _saveApiKeyIfChanged();
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
            ),
          ],
        ),
        if (_selectedProvider == 'openrouter') ...[
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
      initialValue: _selectedProvider,
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
      items: const [
        DropdownMenuItem(
          value: 'openrouter',
          child: Text('OpenRouter', overflow: TextOverflow.ellipsis),
        ),
        DropdownMenuItem(
          value: 'openai',
          child: Text('OpenAI', overflow: TextOverflow.ellipsis),
        ),
      ],
      onChanged: (newValue) async {
        if (newValue == null || newValue == _selectedProvider) return;
        final models =
            _visibleModelsByProvider[newValue] ??
            ModelCatalogDefaults.modelsForProvider(newValue);
        final model = models.isNotEmpty ? models.first : _selectedModel;
        final authFailure = await _settingsService.getProviderAuthFailure(
          newValue,
        );
        if (!mounted) return;
        setState(() {
          _selectedProvider = newValue;
          _selectedModel = model;
          _activeAuthFailure = authFailure;
          _isApiKeyVisible = false;
        });
        await _settingsService.setProvider(newValue);
        await _shortcutService.setProvider(newValue);
        await _settingsService.setModel(model);
        await _shortcutService.setModel(model);
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
          provider: 'openrouter',
          slug: controller.text,
        );
      } else {
        final newSlug = controller.text.trim();
        await _modelCatalogService.editCustomModel(
          provider: 'openrouter',
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
      onChanged: (newValue) async {
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
    return AppSettingsSection(
      key: const Key('apiProvider-modelManagementPanel'),
      title: l10n.openRouterModels,
      subtitle: l10n.openRouterModelsDescription,
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
  });

  final Widget providerSelector;
  final Widget apiKeyField;
  final String apiKeySubtitle;
  final Widget modelSelector;

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
          subtitle: l10n.modelUsedForRewrite,
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
