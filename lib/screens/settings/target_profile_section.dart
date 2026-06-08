import 'dart:async';

import 'package:flutter/material.dart';
import 'package:make_it_sound_natural/l10n/gen/app_localizations.dart';
import 'package:make_it_sound_natural/models/target_profile.dart';
import 'package:make_it_sound_natural/services/shortcut_service.dart';
import 'package:make_it_sound_natural/services/target_profile_service.dart';
import 'package:make_it_sound_natural/widgets/app_settings_section.dart';
import 'package:make_it_sound_natural/widgets/target_profile_editor_dialog.dart';
import 'package:make_it_sound_natural/widgets/target_profile_picker_dialog.dart';

/// Settings control for target language or dialect selection.
class TargetProfileSettingsRow extends StatefulWidget {
  /// Creates the target profile settings row.
  const TargetProfileSettingsRow({super.key});

  @override
  State<TargetProfileSettingsRow> createState() =>
      _TargetProfileSettingsRowState();
}

class _TargetProfileSettingsRowState extends State<TargetProfileSettingsRow> {
  final _targetProfileService = TargetProfileService();
  final _shortcutService = ShortcutService();

  TargetProfile? _profile;

  @override
  void initState() {
    super.initState();
    unawaited(_loadProfile());
  }

  Future<void> _loadProfile() async {
    final profile = await _targetProfileService.getSelectedProfile();
    if (!mounted) return;
    setState(() => _profile = profile);
  }

  Future<void> _chooseProfile() async {
    final selected = await showDialog<TargetProfile>(
      context: context,
      builder: (context) => TargetProfilePickerDialog(
        service: _targetProfileService,
        currentProfile: _profile,
      ),
    );
    if (selected == null || !mounted) return;

    final profile = await _targetProfileService.selectProfile(selected.id);
    await _shortcutService.setTargetProfile(
      profile,
      selectionRequired: false,
    );
    if (!mounted) return;

    setState(() => _profile = profile);
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context)!.targetProfileSaved)),
    );
  }

  Future<void> _removeCurrentProfile() async {
    final profile = _profile;
    if (profile == null || !profile.isCustom) return;

    final result = await _targetProfileService.removeCustomProfile(profile.id);
    if (!mounted || !result.fallbackApplied || result.fallbackProfile == null) {
      return;
    }

    await _shortcutService.setTargetProfile(
      result.fallbackProfile,
      selectionRequired: false,
    );
    if (!mounted) return;

    setState(() => _profile = result.fallbackProfile);
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppLocalizations.of(context)!.targetProfileResetToDefault,
        ),
      ),
    );
  }

  Future<void> _editCurrentProfile() async {
    final profile = _profile;
    if (profile == null || !profile.isCustom) return;

    final draft = await showDialog<TargetProfileDraft>(
      context: context,
      builder: (context) => TargetProfileEditorDialog(
        initialProfile: profile,
      ),
    );
    if (draft == null || !mounted) return;

    final TargetProfile updatedProfile;
    try {
      updatedProfile = await _targetProfileService.updateCustomProfile(
        profile.id,
        name: draft.name,
        instruction: draft.instruction,
      );
    } on TargetProfileValidationException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
      return;
    }
    await _shortcutService.setTargetProfile(
      updatedProfile,
      selectionRequired: false,
    );
    if (!mounted) return;

    setState(() => _profile = updatedProfile);
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context)!.targetProfileSaved)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return AppSettingsRow(
      key: const Key('targetProfileSettingsRow'),
      onTap: _chooseProfile,
      leading: const AppSettingsIconTile(
        icon: Icons.language_rounded,
      ),
      title: l10n.targetLanguage,
      subtitle: _profile?.name ?? l10n.chooseTargetLanguage,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_profile?.isCustom ?? false)
            IconButton(
              key: const Key('editSelectedTargetProfileButton'),
              onPressed: () => unawaited(_editCurrentProfile()),
              icon: const Icon(Icons.edit_outlined),
              tooltip: l10n.editPrompt,
            ),
          if (_profile?.isCustom ?? false)
            IconButton(
              onPressed: () => unawaited(_removeCurrentProfile()),
              icon: const Icon(Icons.delete_outline_rounded),
              tooltip: l10n.deleteTargetProfile,
            ),
          OutlinedButton(
            key: const Key('targetProfilePickerButton'),
            onPressed: _chooseProfile,
            child: Text(l10n.chooseTarget),
          ),
        ],
      ),
    );
  }
}
