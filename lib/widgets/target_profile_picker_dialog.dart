import 'dart:async';

import 'package:flutter/material.dart';
import 'package:make_it_sound_natural/l10n/gen/app_localizations.dart';
import 'package:make_it_sound_natural/models/target_profile.dart';
import 'package:make_it_sound_natural/services/target_profile_service.dart';
import 'package:make_it_sound_natural/theme/app_design_tokens.dart';
import 'package:make_it_sound_natural/widgets/app_dialog_shell.dart';
import 'package:make_it_sound_natural/widgets/app_toast.dart';
import 'package:make_it_sound_natural/widgets/target_profile_editor_dialog.dart';

const double _pickerListMaxHeight = 300;

/// Dialog for searching, selecting, creating, and removing target profiles.
class TargetProfilePickerDialog extends StatefulWidget {
  /// Creates a target profile picker dialog.
  const TargetProfilePickerDialog({
    required this.service,
    this.currentProfile,
    this.forceSelection = false,
    super.key,
  });

  /// Target profile service.
  final TargetProfileService service;

  /// Currently selected profile.
  final TargetProfile? currentProfile;

  /// Whether the user must select a profile before closing.
  final bool forceSelection;

  @override
  State<TargetProfilePickerDialog> createState() =>
      _TargetProfilePickerDialogState();
}

class _TargetProfilePickerDialogState extends State<TargetProfilePickerDialog> {
  final _searchController = TextEditingController();

  List<TargetProfile> _profiles = [];
  TargetProfile? _selectedProfile;

  @override
  void initState() {
    super.initState();
    _selectedProfile = widget.currentProfile;
    _searchController.addListener(_loadProfiles);
    unawaited(_loadProfiles());
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_loadProfiles)
      ..dispose();
    super.dispose();
  }

  Future<void> _loadProfiles() async {
    final profiles = await widget.service.searchProfiles(
      _searchController.text,
    );
    if (!mounted) return;
    setState(() => _profiles = profiles);
  }

  Future<void> _addCustomProfile() async {
    final draft = await showDialog<TargetProfileDraft>(
      context: context,
      builder: (context) => const TargetProfileEditorDialog(),
    );
    if (draft == null || !mounted) return;

    try {
      final profile = await widget.service.createCustomProfile(
        name: draft.name,
        instruction: draft.instruction,
      );
      if (!mounted) return;
      Navigator.of(context).pop(profile);
    } on TargetProfileValidationException catch (error) {
      if (!mounted) return;
      showAppToast(context, error.message);
    }
  }

  Future<void> _editCustomProfile(TargetProfile profile) async {
    final draft = await showDialog<TargetProfileDraft>(
      context: context,
      builder: (context) => TargetProfileEditorDialog(
        initialProfile: profile,
      ),
    );
    if (draft == null || !mounted) return;

    try {
      final updatedProfile = await widget.service.updateCustomProfile(
        profile.id,
        name: draft.name,
        instruction: draft.instruction,
      );
      if (!mounted) return;

      if (updatedProfile.id == widget.currentProfile?.id) {
        Navigator.of(context).pop(updatedProfile);
        return;
      }

      await _loadProfiles();
    } on TargetProfileValidationException catch (error) {
      if (!mounted) return;
      showAppToast(context, error.message);
    }
  }

  Future<void> _removeCustomProfile(TargetProfile profile) async {
    final result = await widget.service.removeCustomProfile(profile.id);
    if (!mounted || !result.removed) return;

    if (result.fallbackApplied && result.fallbackProfile != null) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      showAppToast(
        context,
        AppLocalizations.of(context)!.targetProfileResetToDefault,
      );
      Navigator.of(context).pop(result.fallbackProfile);
      return;
    }

    await _loadProfiles();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return PopScope(
      canPop: !widget.forceSelection,
      child: AppDialogShell(
        title: l10n.chooseTargetLanguage,
        // forceSelection is the app-start gate: picking a row is the only
        // way out, so the caller also passes barrierDismissible: false.
        dismissible: !widget.forceSelection,
        subtitle: widget.forceSelection
            ? l10n.chooseTargetForcedSubtitle
            : null,
        compact: false,
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: _pickerListMaxHeight),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                key: const Key('targetProfileSearchField'),
                controller: _searchController,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search_rounded),
                  hintText: l10n.searchTargetProfiles,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Flexible(
                child: _profiles.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.xl,
                        ),
                        child: Center(
                          child: Text(
                            l10n.noMatchingTargetProfiles,
                            style: AppTextStyles.rowSubtitleOf(context),
                          ),
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: _profiles.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: AppSpacing.xs),
                        itemBuilder: (context, index) {
                          final profile = _profiles[index];
                          return _ProfilePickRow(
                            name: profile.name,
                            description: profile.description,
                            selected: profile.id == _selectedProfile?.id,
                            onTap: () => Navigator.of(context).pop(profile),
                            onEdit: profile.isCustom
                                ? () => unawaited(_editCustomProfile(profile))
                                : null,
                            onDelete: profile.isCustom
                                ? () => unawaited(_removeCustomProfile(profile))
                                : null,
                            editTooltip: l10n.editPrompt,
                            deleteTooltip: l10n.deleteTargetProfile,
                          );
                        },
                      ),
              ),
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton.icon(
                key: const Key('addTargetProfileButton'),
                onPressed: _addCustomProfile,
                icon: const Icon(Icons.add_rounded, size: AppSizes.iconMd),
                label: Text(l10n.addCustom),
              ),
            ],
          ),
        ),
        actions: [
          if (!widget.forceSelection)
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.cancel),
            ),
        ],
      ),
    );
  }
}

/// One selectable profile row.
class _ProfilePickRow extends StatelessWidget {
  const _ProfilePickRow({
    required this.name,
    required this.description,
    required this.selected,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    required this.editTooltip,
    required this.deleteTooltip,
  });

  final String name;
  final String? description;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final String editTooltip;
  final String deleteTooltip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: selected ? colorScheme.primaryContainer : null,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: selected ? colorScheme.primary : theme.dividerColor,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (description != null)
                    Text(
                      description!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.rowSubtitleOf(context),
                    ),
                ],
              ),
            ),
            if (onEdit != null)
              IconButton(
                onPressed: onEdit,
                tooltip: editTooltip,
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  Icons.edit_outlined,
                  size: AppSizes.iconLg,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            if (onDelete != null)
              IconButton(
                onPressed: onDelete,
                tooltip: deleteTooltip,
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  Icons.delete_outline_rounded,
                  size: AppSizes.iconLg,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            if (selected)
              Padding(
                padding: const EdgeInsets.only(left: AppSpacing.xxs),
                child: Icon(
                  Icons.check_rounded,
                  size: AppSizes.iconMd,
                  color: colorScheme.primary,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
