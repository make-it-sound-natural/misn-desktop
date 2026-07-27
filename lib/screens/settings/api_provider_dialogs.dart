import 'package:flutter/material.dart';
import 'package:make_it_sound_natural/constants/app_defaults.dart';
import 'package:make_it_sound_natural/l10n/gen/app_localizations.dart';
import 'package:make_it_sound_natural/models/llm_provider_entry.dart';
import 'package:make_it_sound_natural/theme/app_design_tokens.dart';
import 'package:make_it_sound_natural/theme/app_theme.dart';
import 'package:make_it_sound_natural/widgets/app_dialog_shell.dart';
import 'package:make_it_sound_natural/widgets/app_popup_select.dart';

/// Values entered in the add/edit provider dialog.
typedef ProviderDialogResult = ({String name, String baseUrl, String apiKey});

/// Values entered in the add/edit model dialog.
typedef ModelDialogResult = ({String providerId, String slug});

/// Collects a provider name, base URL and key.
///
/// Validation lives in `ProviderCatalogService`, so the caller re-opens this
/// dialog with [errorText] when the service rejects the values.
Future<ProviderDialogResult?> showProviderDialog(
  BuildContext context, {
  LlmProviderEntry? entry,
  String? errorText,
  ProviderDialogResult? initial,
}) {
  final l10n = AppLocalizations.of(context)!;
  // [initial] carries back what the user typed when validation rejected it;
  // reopening from [entry] alone silently discarded their edits.
  final nameController = TextEditingController(
    text: initial?.name ?? entry?.displayName ?? '',
  );
  final urlController = TextEditingController(
    text: initial?.baseUrl ?? entry?.baseUrl ?? '',
  );
  final keyController = TextEditingController(text: initial?.apiKey ?? '');

  return showDialog<ProviderDialogResult>(
    context: context,
    builder: (dialogContext) => AppDialogShell(
      title: entry == null ? l10n.addProvider : l10n.editProvider,
      subtitle: l10n.addProviderDialogSubtitle,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DialogField(
            key: const Key('apiProvider-providerNameField'),
            label: l10n.providerName,
            controller: nameController,
            autofocus: true,
          ),
          const SizedBox(height: AppSpacing.md),
          _DialogField(
            key: const Key('apiProvider-providerBaseUrlField'),
            label: l10n.providerBaseUrl,
            controller: urlController,
            hintText: 'https://api.example.com/v1',
            mono: true,
          ),
          const SizedBox(height: AppSpacing.md),
          _DialogField(
            key: const Key('apiProvider-providerKeyField'),
            label: l10n.apiKey,
            controller: keyController,
            obscured: true,
            mono: true,
          ),
          if (errorText != null) ...[
            const SizedBox(height: AppSpacing.xs),
            _DialogError(
              key: const Key('apiProvider-providerDialogError'),
              message: errorText,
            ),
          ],
        ],
      ),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          key: const Key('apiProvider-saveProvider'),
          onPressed: () => Navigator.of(dialogContext).pop((
            name: nameController.text.trim(),
            baseUrl: urlController.text.trim(),
            apiKey: keyController.text.trim(),
          )),
          child: Text(entry == null ? l10n.addProvider : l10n.save),
        ),
      ],
    ),
  );
}

/// Collects the API key for one provider.
///
/// The field always starts empty: a saved key is never displayed again.
Future<String?> showProviderKeyDialog(
  BuildContext context, {
  required LlmProviderEntry provider,
}) {
  final l10n = AppLocalizations.of(context)!;
  final keyController = TextEditingController();

  return showDialog<String>(
    context: context,
    builder: (dialogContext) => AppDialogShell(
      title: l10n.apiKey,
      subtitle: l10n.providerKeyDialogSubtitle(provider.displayName),
      content: _DialogField(
        key: const Key('apiProvider-keyDialogField'),
        label: l10n.apiKey,
        controller: keyController,
        obscured: true,
        mono: true,
        autofocus: true,
        onSubmitted: () =>
            Navigator.of(dialogContext).pop(keyController.text.trim()),
      ),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          key: const Key('apiProvider-saveKey'),
          onPressed: () =>
              Navigator.of(dialogContext).pop(keyController.text.trim()),
          child: Text(l10n.save),
        ),
      ],
    ),
  );
}

/// Picks the owning provider and the model slug.
///
/// One dialog serves every provider, so a duplicate slug is only a conflict
/// within the chosen provider.
Future<ModelDialogResult?> showModelDialog(
  BuildContext context, {
  required List<LlmProviderEntry> providers,
  required String initialProviderId,
  String? initialSlug,
  String? errorText,
}) {
  final l10n = AppLocalizations.of(context)!;
  final slugController = TextEditingController(text: initialSlug ?? '');
  var providerId = providers.any((entry) => entry.id == initialProviderId)
      ? initialProviderId
      : providers.first.id;

  return showDialog<ModelDialogResult>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setDialogState) => AppDialogShell(
        title: initialSlug == null ? l10n.addModel : l10n.editModel,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DialogLabel(text: l10n.provider),
            const SizedBox(height: AppSpacing.xxsPlus),
            AppPopupSelect<String>(
              key: const Key('apiProvider-modelDialogProvider'),
              value: providerId,
              options: [
                for (final entry in providers)
                  AppPopupOption<String>(
                    value: entry.id,
                    label: entry.displayName,
                  ),
              ],
              onChanged: (value) => setDialogState(() => providerId = value),
            ),
            const SizedBox(height: AppSpacing.md),
            _DialogField(
              key: const Key('apiProvider-modelDialogSlug'),
              label: l10n.modelSlug,
              controller: slugController,
              // The vendor-prefixed form is OpenRouter's addressing scheme,
              // not a general rule: everywhere else the slug is sent verbatim
              // as the request's `model`, so `openai/gpt-...` would reach the
              // API as-is and come back "model not found".
              hintText: providerId == AppDefaults.openRouterProvider
                  ? 'provider/model-id'
                  : 'model-id',
              mono: true,
              autofocus: true,
              onSubmitted: () => Navigator.of(dialogContext).pop((
                providerId: providerId,
                slug: slugController.text.trim(),
              )),
            ),
            if (errorText != null) ...[
              const SizedBox(height: AppSpacing.xs),
              _DialogError(
                key: const Key('apiProvider-modelDialogError'),
                message: errorText,
              ),
            ],
          ],
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            key: const Key('apiProvider-saveModel'),
            onPressed: () => Navigator.of(dialogContext).pop((
              providerId: providerId,
              slug: slugController.text.trim(),
            )),
            child: Text(l10n.save),
          ),
        ],
      ),
    ),
  );
}

class _DialogLabel extends StatelessWidget {
  const _DialogLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTextStyles.groupTitleOf(context),
    );
  }
}

class _DialogError extends StatelessWidget {
  const _DialogError({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Text(
      message,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: AppStatusColors.of(context).error,
      ),
    );
  }
}

class _DialogField extends StatelessWidget {
  const _DialogField({
    required this.label,
    required this.controller,
    super.key,
    this.hintText,
    this.obscured = false,
    this.mono = false,
    this.autofocus = false,
    this.onSubmitted,
  });

  final String label;
  final TextEditingController controller;
  final String? hintText;
  final bool obscured;
  final bool mono;
  final bool autofocus;
  final VoidCallback? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DialogLabel(text: label),
        const SizedBox(height: AppSpacing.xxsPlus),
        TextField(
          controller: controller,
          autofocus: autofocus,
          obscureText: obscured,
          onSubmitted: onSubmitted == null ? null : (_) => onSubmitted!(),
          style: mono ? AppTextStyles.monoOf(context) : null,
          decoration: InputDecoration(hintText: hintText),
        ),
      ],
    );
  }
}
