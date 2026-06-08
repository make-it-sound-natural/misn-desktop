import 'dart:async';

import 'package:flutter/material.dart';
import 'package:make_it_sound_natural/l10n/gen/app_localizations.dart';
import 'package:make_it_sound_natural/services/settings_service.dart';
import 'package:make_it_sound_natural/services/shortcut_service.dart';
import 'package:make_it_sound_natural/theme/app_theme.dart';
import 'package:make_it_sound_natural/widgets/app_settings_section.dart';
import 'package:make_it_sound_natural/widgets/prompt_edit_dialog.dart';

/// Settings section for advanced options like custom prompts.
class AdvancedSettingsSection extends StatefulWidget {
  /// Creates the advanced settings section widget.
  const AdvancedSettingsSection({super.key});

  @override
  State<AdvancedSettingsSection> createState() =>
      _AdvancedSettingsSectionState();
}

class _AdvancedSettingsSectionState extends State<AdvancedSettingsSection> {
  final _settingsService = SettingsService();
  final _shortcutService = ShortcutService();

  String _customPrompt = '';
  String _defaultPrompt = '';

  @override
  void initState() {
    super.initState();
    unawaited(_loadSettings());
  }

  Future<void> _loadSettings() async {
    final customPrompt = await _settingsService.getCustomPrompt();
    final defaultPrompt = await _shortcutService.getDefaultPrompt();

    if (mounted) {
      setState(() {
        _customPrompt = customPrompt;
        _defaultPrompt = defaultPrompt;
      });
    }
  }

  Future<void> _editPrompt() async {
    final l10n = AppLocalizations.of(context)!;
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => PromptEditDialog(
        currentPrompt: _customPrompt,
        defaultPrompt: _defaultPrompt,
      ),
    );

    if (result != null && mounted) {
      // Save the new prompt
      await _settingsService.setCustomPrompt(result);
      await _shortcutService.setCustomPrompt(result);
      setState(() => _customPrompt = result);

      // Show appropriate feedback
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.isEmpty ? l10n.promptReset : l10n.promptSaved,
            ),
            backgroundColor: AppStatusColors.of(context).success,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final hasCustomPrompt = _customPrompt.isNotEmpty;

    return AppSettingsSection(
      title: l10n.advancedSettings,
      children: [
        AppSettingsRow(
          leading: const AppSettingsIconTile(
            icon: Icons.auto_fix_high_rounded,
          ),
          title: l10n.customPrompt,
          subtitle: hasCustomPrompt
              ? l10n.customPromptActive
              : l10n.usingDefault,
          trailing: TextButton(
            onPressed: _editPrompt,
            child: Text(l10n.editPrompt),
          ),
        ),
      ],
    );
  }
}
