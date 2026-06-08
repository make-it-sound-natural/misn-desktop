import 'dart:async';

import 'package:flutter/material.dart';
import 'package:make_it_sound_natural/l10n/gen/app_localizations.dart';
import 'package:make_it_sound_natural/models/target_profile.dart';
import 'package:make_it_sound_natural/services/target_profile_service.dart';
import 'package:make_it_sound_natural/theme/app_design_tokens.dart';
import 'package:make_it_sound_natural/theme/app_theme.dart';
import 'package:make_it_sound_natural/widgets/app_dialog_escape_dismiss.dart';
import 'package:make_it_sound_natural/widgets/target_profile_editor_dialog.dart';

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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    }
  }

  Future<void> _removeCustomProfile(TargetProfile profile) async {
    final result = await widget.service.removeCustomProfile(profile.id);
    if (!mounted || !result.removed) return;

    if (result.fallbackApplied && result.fallbackProfile != null) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.targetProfileResetToDefault,
          ),
        ),
      );
      Navigator.of(context).pop(result.fallbackProfile);
      return;
    }

    await _loadProfiles();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return AppDialogEscapeDismiss<TargetProfile>(
      enabled: !widget.forceSelection,
      child: PopScope(
        canPop: !widget.forceSelection,
        child: Dialog(
          insetPadding: const EdgeInsets.all(AppSpacing.xl),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.xl),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppSizes.dialogMaxWidth,
              maxHeight: 620,
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.language_rounded,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          l10n.chooseTargetLanguage,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.pageTitleOf(context),
                        ),
                      ),
                      if (!widget.forceSelection)
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close_rounded),
                          tooltip: l10n.cancel,
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    key: const Key('targetProfileSearchField'),
                    controller: _searchController,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search_rounded),
                      hintText: l10n.searchTargetProfiles,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Expanded(
                    child: _profiles.isEmpty
                        ? Center(
                            child: Text(
                              l10n.noMatchingTargetProfiles,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          )
                        : ListView.separated(
                            itemCount: _profiles.length,
                            separatorBuilder: (context, index) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final profile = _profiles[index];
                              final selected =
                                  profile.id == _selectedProfile?.id;
                              return ListTile(
                                title: Text(profile.name),
                                subtitle: profile.description == null
                                    ? null
                                    : Text(profile.description!),
                                leading: Icon(
                                  selected
                                      ? Icons.check_circle_rounded
                                      : Icons.circle_outlined,
                                  color: selected
                                      ? AppColors.primary
                                      : AppColors.textSecondary,
                                ),
                                trailing: profile.isCustom
                                    ? Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            onPressed: () => unawaited(
                                              _editCustomProfile(profile),
                                            ),
                                            icon: const Icon(
                                              Icons.edit_outlined,
                                            ),
                                            tooltip: l10n.editPrompt,
                                          ),
                                          IconButton(
                                            onPressed: () => unawaited(
                                              _removeCustomProfile(profile),
                                            ),
                                            icon: const Icon(
                                              Icons.delete_outline_rounded,
                                            ),
                                            tooltip: l10n.deleteTargetProfile,
                                          ),
                                        ],
                                      )
                                    : null,
                                onTap: () => Navigator.of(context).pop(profile),
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      key: const Key('addTargetProfileButton'),
                      onPressed: _addCustomProfile,
                      icon: const Icon(Icons.add_rounded),
                      label: Text(l10n.addCustom),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
