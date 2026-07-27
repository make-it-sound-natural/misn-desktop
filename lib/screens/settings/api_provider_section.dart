import 'dart:async';

import 'package:flutter/material.dart';
import 'package:make_it_sound_natural/constants/app_defaults.dart';
import 'package:make_it_sound_natural/l10n/gen/app_localizations.dart';
import 'package:make_it_sound_natural/models/catalog_validation_reason.dart';
import 'package:make_it_sound_natural/models/llm_model_entry.dart';
import 'package:make_it_sound_natural/models/llm_provider_entry.dart';
import 'package:make_it_sound_natural/models/provider_auth_failure.dart';
import 'package:make_it_sound_natural/screens/settings/api_provider_dialogs.dart';
import 'package:make_it_sound_natural/services/model_catalog_service.dart';
import 'package:make_it_sound_natural/services/provider_catalog_service.dart';
import 'package:make_it_sound_natural/services/settings_service.dart';
import 'package:make_it_sound_natural/services/shortcut_service.dart';
import 'package:make_it_sound_natural/services/speed_tracking_service.dart';
import 'package:make_it_sound_natural/theme/app_design_tokens.dart';
import 'package:make_it_sound_natural/theme/app_theme.dart';
import 'package:make_it_sound_natural/widgets/app_dialog_shell.dart';
import 'package:make_it_sound_natural/widgets/app_inline_banner.dart';
import 'package:make_it_sound_natural/widgets/app_panel.dart';
import 'package:make_it_sound_natural/widgets/app_popup_select.dart';
import 'package:make_it_sound_natural/widgets/app_settings_section.dart';
import 'package:make_it_sound_natural/widgets/app_toast.dart';

const double _groupTitleTopSpacing = 24;

/// Width of the two-action slot.
///
/// Two `IconButton`s at `VisualDensity.compact`: the 48pt default minus 8 in
/// each axis, so 40 apiece.
const double _optionalActionsWidth = 80;
const String _modelValueSeparator = '::';

/// Settings section for providers, their API keys, and their models.
///
/// One picker chooses the rewrite model across every provider; picking a
/// model implicitly selects its provider.
class ApiProviderSection extends StatefulWidget {
  /// Creates the AI provider settings section.
  const ApiProviderSection({super.key});

  @override
  State<ApiProviderSection> createState() => _ApiProviderSectionState();
}

class _ApiProviderSectionState extends State<ApiProviderSection> {
  final _settingsService = SettingsService();
  final _shortcutService = ShortcutService();
  final _speedTrackingService = SpeedTrackingService();
  final _modelCatalogService = ModelCatalogService();
  final _providerCatalogService = ProviderCatalogService();

  List<LlmProviderEntry> _providers = [];
  Map<String, List<LlmModelEntry>> _modelsByProvider = {};
  Map<String, bool> _hasKeyByProvider = {};
  Map<String, ({double? avg, int count})> _speedStats = {};
  String _selectedProvider = AppDefaults.apiProvider;
  String _selectedModel = AppDefaults.model;
  ProviderAuthFailure? _activeAuthFailure;

  @override
  void initState() {
    super.initState();
    unawaited(_loadSettings());
  }

  List<LlmModelEntry> get _allModels => [
    for (final provider in _providers) ...?_modelsByProvider[provider.id],
  ];

  int get _visibleModelCount =>
      _allModels.where((model) => !model.isHidden).length;

  Future<void> _loadSettings() async {
    final providers = await _providerCatalogService.allProviders();
    // Each provider's lookups are independent, and `_hasKey` is a method
    // channel round trip into the Keychain — awaiting them one at a time
    // serialised the whole reload behind P of them.
    final models = await Future.wait(
      providers.map((provider) => _modelCatalogService.allModels(provider.id)),
    );
    final keys = await Future.wait(providers.map(_hasKey));
    final modelsByProvider = <String, List<LlmModelEntry>>{
      for (var i = 0; i < providers.length; i++) providers[i].id: models[i],
    };
    final hasKeyByProvider = <String, bool>{
      for (var i = 0; i < providers.length; i++) providers[i].id: keys[i],
    };

    final storedProvider = await _settingsService.getProvider();
    final storedModel = await _settingsService.getModel();
    final resolved = _resolveSelection(
      providers.any((p) => p.id == storedProvider)
          ? storedProvider
          : AppDefaults.apiProvider,
      storedModel,
      modelsByProvider,
    );
    final resolvedProvider = resolved.provider;
    final resolvedModel = resolved.model;
    final authFailure = await _settingsService.getProviderAuthFailure(
      resolvedProvider,
    );
    final speedStats = await _speedTrackingService.getAllStats();
    if (!mounted) return;

    setState(() {
      _providers = providers;
      _modelsByProvider = modelsByProvider;
      _hasKeyByProvider = hasKeyByProvider;
      _speedStats = speedStats;
      _selectedProvider = resolvedProvider;
      _selectedModel = resolvedModel;
      _activeAuthFailure = authFailure;
    });

    if (resolvedProvider != storedProvider || resolvedModel != storedModel) {
      await _persistSelection(resolvedProvider, resolvedModel);
    }
    await _syncSelectedCustomProviderConfig();
  }

  Future<bool> _hasKey(LlmProviderEntry provider) async {
    final key = switch (provider.id) {
      AppDefaults.openRouterProvider =>
        await _settingsService.getOpenRouterApiKey(),
      AppDefaults.openAiProvider => await _settingsService.getApiKey(),
      _ => await _settingsService.getCustomProviderApiKey(provider.id),
    };
    return key.trim().isNotEmpty;
  }

  /// Keeps the picker pointed at a model that still exists and is visible.
  ///
  /// Returns the owning provider alongside the model. Falling back to another
  /// provider's model while leaving the caller's provider untouched wrote a
  /// mismatched pair to settings and to the native side, so every rewrite went
  /// to one provider carrying a model that only exists on another.
  ({String provider, String model}) _resolveSelection(
    String provider,
    String model,
    Map<String, List<LlmModelEntry>> modelsByProvider,
  ) {
    final visible = (modelsByProvider[provider] ?? const <LlmModelEntry>[])
        .where((entry) => !entry.isHidden)
        .toList();
    if (visible.any((entry) => entry.slug == model)) {
      return (provider: provider, model: model);
    }
    if (visible.isNotEmpty) {
      return (provider: provider, model: visible.first.slug);
    }

    for (final entry in modelsByProvider.entries) {
      final firstVisible = entry.value.where((m) => !m.isHidden).toList();
      if (firstVisible.isNotEmpty) {
        return (provider: entry.key, model: firstVisible.first.slug);
      }
    }
    return (provider: provider, model: '');
  }

  Future<void> _persistSelection(String provider, String model) async {
    await _settingsService.setProvider(provider);
    await _shortcutService.setProvider(provider);
    await _settingsService.setModel(model);
    await _shortcutService.setModel(model);
  }

  Future<void> _syncSelectedCustomProviderConfig() async {
    final provider = _providers
        .where((entry) => entry.id == _selectedProvider)
        .firstOrNull;
    if (provider == null || provider.isBuiltIn) return;
    final apiKey = await _settingsService.getCustomProviderApiKey(provider.id);
    await _shortcutService.setCustomProviderConfig(
      provider: provider.id,
      baseUrl: provider.baseUrl,
      apiKey: apiKey.trim(),
    );
  }

  Future<void> _selectProviderAndModel(String providerId, String slug) async {
    final authFailure = await _settingsService.getProviderAuthFailure(
      providerId,
    );
    if (!mounted) return;
    setState(() {
      _selectedProvider = providerId;
      _selectedModel = slug;
      _activeAuthFailure = authFailure;
    });
    await _persistSelection(providerId, slug);
    await _syncSelectedCustomProviderConfig();
  }

  /// Reloads catalogs after an edit and re-points the picker when the current
  /// selection disappeared.
  Future<void> _reloadAfterCatalogChange() async {
    await _loadSettings();
  }

  /// Maps a catalog rejection onto localized copy.
  ///
  /// The services throw English sentences so failures read well in logs;
  /// showing those verbatim left the other eight locales reading raw English.
  String _localizedCatalogError(
    AppLocalizations l10n,
    CatalogValidationReason reason,
    String fallback,
  ) {
    return switch (reason) {
      CatalogValidationReason.modelSlugRequired => l10n.modelSlugRequired,
      CatalogValidationReason.modelSlugDuplicate => l10n.modelSlugDuplicate,
      CatalogValidationReason.modelVisibilityRequired =>
        l10n.modelVisibilityRequired,
      CatalogValidationReason.providerNameRequired => l10n.providerNameRequired,
      CatalogValidationReason.providerNameInvalid => l10n.providerNameInvalid,
      CatalogValidationReason.providerUrlRequired => l10n.providerUrlRequired,
      CatalogValidationReason.providerUrlInvalid => l10n.providerUrlInvalid,
      // Not reachable from the UI; keep the English sentence rather than
      // inventing user-facing copy for a programmer error.
      CatalogValidationReason.notMutable => fallback,
    };
  }

  Future<void> _openProviderDialog({LlmProviderEntry? entry}) async {
    var errorText = <String?>[null].first;
    ProviderDialogResult? rejected;
    while (true) {
      final result = await showProviderDialog(
        context,
        entry: entry,
        errorText: errorText,
        initial: rejected,
      );
      if (result == null || !mounted) return;

      final l10n = AppLocalizations.of(context)!;
      try {
        final saved = entry == null
            ? await _providerCatalogService.addCustomProvider(
                displayName: result.name,
                baseUrl: result.baseUrl,
              )
            : await _providerCatalogService.editCustomProvider(
                id: entry.id,
                displayName: result.name,
                baseUrl: result.baseUrl,
              );
        if (result.apiKey.isNotEmpty) {
          await _settingsService.setCustomProviderApiKey(
            saved.id,
            result.apiKey,
          );
        }
        await _reloadAfterCatalogChange();
        if (!mounted) return;
        showAppToast(
          context,
          entry == null ? l10n.providerAdded : l10n.providerUpdated,
        );
        return;
      } on ProviderCatalogValidationException catch (e) {
        errorText = _localizedCatalogError(l10n, e.reason, e.message);
        rejected = result;
      }
    }
  }

  Future<void> _openProviderKeyDialog(LlmProviderEntry provider) async {
    final key = await showProviderKeyDialog(context, provider: provider);
    if (key == null || !mounted) return;

    final l10n = AppLocalizations.of(context)!;
    switch (provider.id) {
      case AppDefaults.openRouterProvider:
        await _settingsService.setOpenRouterApiKey(key);
      case AppDefaults.openAiProvider:
        await _settingsService.setApiKey(key);
      default:
        if (key.isEmpty) {
          await _settingsService.deleteCustomProviderApiKey(provider.id);
        } else {
          await _settingsService.setCustomProviderApiKey(provider.id, key);
        }
    }
    await _settingsService.clearProviderAuthFailure(provider.id);
    await _reloadAfterCatalogChange();
    if (!mounted) return;
    showAppToast(context, key.isEmpty ? l10n.apiKeyRemoved : l10n.apiKeySaved);
  }

  Future<void> _confirmDeleteProvider(LlmProviderEntry provider) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showAppConfirmDialog(
      context: context,
      title: l10n.deleteProviderTitle,
      message: Text(l10n.deleteProviderMessage(provider.displayName)),
      confirmLabel: l10n.deleteAction,
      cancelLabel: l10n.cancel,
    );
    if (!confirmed || !mounted) return;

    await _modelCatalogService.deleteProviderModels(provider.id);
    await _providerCatalogService.deleteCustomProvider(provider.id);
    await _settingsService.deleteCustomProviderApiKey(provider.id);
    await _reloadAfterCatalogChange();
    if (!mounted) return;
    showAppToast(context, l10n.providerDeleted);
  }

  Future<void> _openModelDialog({LlmModelEntry? entry}) async {
    var errorText = <String?>[null].first;
    ModelDialogResult? rejected;
    while (true) {
      final result = await showModelDialog(
        context,
        providers: _providers,
        initialProviderId:
            rejected?.providerId ?? entry?.provider ?? _selectedProvider,
        initialSlug: rejected?.slug ?? entry?.slug,
        errorText: errorText,
      );
      if (result == null || !mounted) return;

      final l10n = AppLocalizations.of(context)!;
      if (result.slug.isEmpty) {
        errorText = l10n.modelSlugRequired;
        rejected = result;
        continue;
      }

      try {
        if (entry == null) {
          await _modelCatalogService.addCustomModel(
            provider: result.providerId,
            slug: result.slug,
          );
        } else {
          await _modelCatalogService.editCustomModel(
            provider: entry.provider,
            oldSlug: entry.slug,
            newSlug: result.slug,
          );
        }
        await _reloadAfterCatalogChange();
        if (!mounted) return;
        final providerName = _providerName(result.providerId);
        showAppToast(
          context,
          entry == null ? l10n.modelAddedTo(providerName) : l10n.modelUpdated,
        );
        return;
      } on ModelCatalogValidationException catch (e) {
        errorText = _localizedCatalogError(l10n, e.reason, e.message);
        rejected = result;
      }
    }
  }

  Future<void> _confirmDeleteModel(LlmModelEntry model) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showAppConfirmDialog(
      context: context,
      title: l10n.deleteModelTitle,
      message: Text(
        model.slug,
        style: AppTextStyles.monoOf(context),
      ),
      confirmLabel: l10n.deleteAction,
      cancelLabel: l10n.cancel,
    );
    if (!confirmed || !mounted) return;

    try {
      await _modelCatalogService.deleteCustomModel(
        provider: model.provider,
        slug: model.slug,
      );
    } on ModelCatalogValidationException catch (e) {
      if (!mounted) return;
      showAppToast(context, _localizedCatalogError(l10n, e.reason, e.message));
      return;
    }
    await _reloadAfterCatalogChange();
    if (!mounted) return;
    showAppToast(context, l10n.modelDeleted);
  }

  Future<void> _toggleModelVisibility(LlmModelEntry model) async {
    final l10n = AppLocalizations.of(context)!;
    if (!model.isHidden && _visibleModelCount <= 1) {
      showAppToast(context, l10n.modelVisibilityRequired);
      return;
    }

    try {
      await _modelCatalogService.setModelHidden(
        provider: model.provider,
        slug: model.slug,
        hidden: !model.isHidden,
      );
    } on ModelCatalogValidationException catch (e) {
      if (!mounted) return;
      showAppToast(context, _localizedCatalogError(l10n, e.reason, e.message));
      return;
    }
    await _reloadAfterCatalogChange();
    if (!mounted) return;
    showAppToast(
      context,
      model.isHidden ? l10n.modelShownInPicker : l10n.modelHiddenFromPicker,
    );
  }

  String _providerName(String providerId) {
    return _providers
            .where((entry) => entry.id == providerId)
            .firstOrNull
            ?.displayName ??
        providerId;
  }

  String? _latencyLabel(AppLocalizations l10n, String slug) {
    final stats = _speedStats[slug];
    if (stats == null || stats.count == 0 || stats.avg == null) return null;
    return l10n.latencyAvg(stats.avg!.toStringAsFixed(1));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSettingsSection(
          title: l10n.apiProvider,
          subtitle: l10n.aiProviderSectionDescription,
          children: [_buildModelPickerRow(l10n)],
        ),
        if (_activeAuthFailure != null) _buildAuthFailureNote(l10n),
        _buildProvidersGroup(l10n),
        _buildModelsGroup(l10n),
        const SizedBox(height: AppSpacing.md),
        _SectionNote(
          icon: Icons.info_outline_rounded,
          text: l10n.customProviderCompatibilityNote,
        ),
        const SizedBox(height: AppSpacing.xs),
        _SectionNote(
          icon: Icons.lock_outline_rounded,
          text: l10n.apiKeySecurityNote,
        ),
      ],
    );
  }

  Widget _buildModelPickerRow(AppLocalizations l10n) {
    final options = <AppPopupEntry<String>>[];
    for (final provider in _providers) {
      final visible = (_modelsByProvider[provider.id] ?? const [])
          .where((model) => !model.isHidden)
          .toList();
      if (visible.isEmpty) continue;

      options.add(AppPopupHeader<String>(provider.displayName));
      for (final model in visible) {
        options.add(
          AppPopupOption<String>(
            value: '${provider.id}$_modelValueSeparator${model.slug}',
            label: model.slug,
            detail: _latencyLabel(l10n, model.slug),
          ),
        );
      }
    }

    return AppSettingsRow(
      leading: const AppSettingsRowIcon(icon: Icons.memory_rounded),
      title: l10n.model,
      subtitle: l10n.modelRowDescription,
      trailing: ConstrainedBox(
        constraints: const BoxConstraints(
          minWidth: AppSizes.settingsWideControlWidth,
          maxWidth: AppSizes.settingsWideControlWidth,
        ),
        child: AppPopupSelect<String>(
          key: const Key('apiProvider-modelPicker'),
          value: '$_selectedProvider$_modelValueSeparator$_selectedModel',
          options: options,
          monospaceLabels: true,
          onChanged: (value) {
            final parts = value.split(_modelValueSeparator);
            unawaited(_selectProviderAndModel(parts.first, parts.last));
          },
        ),
      ),
    );
  }

  Widget _buildAuthFailureNote(AppLocalizations l10n) {
    // The same fact renders as a full banner on the Rewrite screen; a bare
    // muted row here made one surface shout and the other whisper. The glyph
    // was also a warning icon tinted with the error token.
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: AppInlineBanner(
        icon: Icons.error_outline_rounded,
        kind: AppInlineBannerKind.error,
        message: l10n.authFailureNote(
          _activeAuthFailure!.message,
          _providerName(_selectedProvider),
        ),
      ),
    );
  }

  Widget _buildProvidersGroup(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _GroupHeader(
          title: l10n.providersGroupTitle,
          actionLabel: l10n.addProvider,
          actionKey: const Key('apiProvider-addProvider'),
          onAction: () => unawaited(_openProviderDialog()),
        ),
        AppPanel(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxsPlus),
          child: Column(
            children: [
              for (var i = 0; i < _providers.length; i++) ...[
                if (i > 0) const AppSettingsDivider(),
                _buildProviderRow(l10n, _providers[i]),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProviderRow(AppLocalizations l10n, LlmProviderEntry provider) {
    final theme = Theme.of(context);
    final statusColors = AppStatusColors.of(context);
    final hasKey = _hasKeyByProvider[provider.id] ?? false;
    final subtitleStyle = AppTextStyles.rowSubtitleOf(context);

    return AppSettingsRow(
      leading: const AppSettingsRowIcon(icon: Icons.cloud_outlined),
      title: provider.displayName,
      subtitleWidget: Text.rich(
        TextSpan(
          children: [
            if (provider.isBuiltIn)
              TextSpan(text: l10n.builtInProvider)
            else
              TextSpan(
                text: provider.baseUrl,
                style: AppTextStyles.monoDetailOf(context),
              ),
            const TextSpan(text: ' · '),
            if (hasKey)
              TextSpan(text: l10n.apiKeySet)
            else
              TextSpan(
                text: l10n.noApiKeyStatus,
                style: subtitleStyle.copyWith(color: statusColors.warning),
              ),
          ],
        ),
        style: subtitleStyle,
        overflow: TextOverflow.ellipsis,
      ),
      // Edit and delete sit in a fixed slot that is simply empty on built-in
      // rows, and the key — the one action every row has — is always last.
      // Otherwise it shifted ~64pt between rows and the single shared control
      // was the one that never lined up down the panel.
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _OptionalRowActions(
            children: provider.isBuiltIn
                ? const []
                : [
                    IconButton(
                      key: Key('apiProvider-editProvider-${provider.id}'),
                      onPressed: () =>
                          unawaited(_openProviderDialog(entry: provider)),
                      tooltip: l10n.editProvider,
                      visualDensity: VisualDensity.compact,
                      icon: Icon(
                        Icons.edit_outlined,
                        size: AppSizes.iconLg,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    IconButton(
                      key: Key('apiProvider-deleteProvider-${provider.id}'),
                      onPressed: () =>
                          unawaited(_confirmDeleteProvider(provider)),
                      tooltip: l10n.deleteProvider,
                      visualDensity: VisualDensity.compact,
                      icon: Icon(
                        Icons.delete_outline_rounded,
                        size: AppSizes.iconLg,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
          ),
          IconButton(
            key: Key('apiProvider-keyButton-${provider.id}'),
            onPressed: () => unawaited(_openProviderKeyDialog(provider)),
            tooltip: hasKey ? l10n.changeApiKeyAction : l10n.setApiKeyAction,
            visualDensity: VisualDensity.compact,
            icon: Icon(
              Icons.key_rounded,
              size: AppSizes.iconLg,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModelsGroup(AppLocalizations l10n) {
    final models = _allModels;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _GroupHeader(
          title: l10n.modelsGroupTitle,
          actionLabel: l10n.addModel,
          actionKey: const Key('apiProvider-addModel'),
          onAction: _providers.isEmpty
              ? null
              : () => unawaited(_openModelDialog()),
        ),
        AppPanel(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxsPlus),
          child: Column(
            children: [
              if (models.isEmpty)
                AppSettingsRow(
                  leading: const AppSettingsRowIcon(
                    icon: Icons.memory_rounded,
                  ),
                  title: l10n.noModelsYet,
                  subtitle: l10n.noModelsYetDescription,
                )
              else
                for (var i = 0; i < models.length; i++) ...[
                  if (i > 0) const AppSettingsDivider(),
                  _buildModelRow(l10n, models[i]),
                ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildModelRow(AppLocalizations l10n, LlmModelEntry model) {
    final theme = Theme.of(context);
    final latency = _latencyLabel(l10n, model.slug);
    final origin = model.isBuiltIn ? l10n.builtInModel : l10n.customModel;
    final isLastVisible = !model.isHidden && _visibleModelCount <= 1;

    return AppSettingsRow(
      leading: const AppSettingsRowIcon(icon: Icons.memory_rounded),
      titleWidget: Row(
        children: [
          Flexible(
            child: Text(
              model.slug,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.monoOf(
                context,
              ).copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          if (latency != null) ...[
            const SizedBox(width: AppSpacing.xs),
            Text(
              latency,
              style: AppTextStyles.monoDetailOf(context),
            ),
          ],
        ],
      ),
      title: model.slug,
      subtitle: '${_providerName(model.provider)} · $origin',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _OptionalRowActions(
            children: model.isBuiltIn
                ? const []
                : [
                    IconButton(
                      key: Key(
                        'apiProvider-editModel-'
                        '${model.provider}-${model.slug}',
                      ),
                      onPressed: () =>
                          unawaited(_openModelDialog(entry: model)),
                      tooltip: l10n.editModel,
                      visualDensity: VisualDensity.compact,
                      icon: Icon(
                        Icons.edit_outlined,
                        size: AppSizes.iconLg,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    IconButton(
                      key: Key(
                        'apiProvider-deleteModel-'
                        '${model.provider}-${model.slug}',
                      ),
                      onPressed: () => unawaited(_confirmDeleteModel(model)),
                      tooltip: l10n.deleteModel,
                      visualDensity: VisualDensity.compact,
                      icon: Icon(
                        Icons.delete_outline_rounded,
                        size: AppSizes.iconLg,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
          ),
          IconButton(
            key: Key('apiProvider-visibility-${model.provider}-${model.slug}'),
            // Disabled rather than live-then-refusing: hiding the last visible
            // model is impossible, and swallowing the click after the fact
            // reads as the app ignoring the user. The tooltip carries the
            // reason, so it is discoverable on hover instead of after a
            // wasted press.
            onPressed: isLastVisible
                ? null
                : () => unawaited(_toggleModelVisibility(model)),
            tooltip: isLastVisible
                ? l10n.modelVisibilityRequired
                : (model.isHidden ? l10n.showModel : l10n.hideModel),
            visualDensity: VisualDensity.compact,
            icon: Icon(
              model.isHidden
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              size: AppSizes.iconLg,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({
    required this.title,
    required this.actionLabel,
    required this.actionKey,
    required this.onAction,
  });

  final String title;
  final String actionLabel;
  final Key actionKey;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xxs,
        _groupTitleTopSpacing,
        0,
        AppSpacing.xs,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(title, style: AppTextStyles.groupTitleOf(context)),
          ),
          OutlinedButton.icon(
            key: actionKey,
            onPressed: onAction,
            icon: const Icon(Icons.add_rounded, size: AppSizes.iconMd),
            label: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}

/// Fixed-width slot for the per-row actions only some rows have.
///
/// Keeps the action every row shares on one column: without it, edit and
/// delete pushed the shared control sideways on custom rows only.
class _OptionalRowActions extends StatelessWidget {
  const _OptionalRowActions({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _optionalActionsWidth,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }
}

class _SectionNote extends StatelessWidget {
  const _SectionNote({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tint = theme.colorScheme.onSurfaceVariant;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: AppSizes.iconMd, color: tint),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(
            text,
            style: AppTextStyles.rowSubtitleOf(context).copyWith(color: tint),
          ),
        ),
      ],
    );
  }
}
