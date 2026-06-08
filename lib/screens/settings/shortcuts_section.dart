import 'dart:async';

import 'package:flutter/material.dart';
import 'package:make_it_sound_natural/constants/app_defaults.dart';
import 'package:make_it_sound_natural/l10n/gen/app_localizations.dart';
import 'package:make_it_sound_natural/services/settings_service.dart';
import 'package:make_it_sound_natural/services/shortcut_service.dart';
import 'package:make_it_sound_natural/theme/app_theme.dart';
import 'package:make_it_sound_natural/utils/shortcut_formatter.dart';
import 'package:make_it_sound_natural/widgets/app_settings_section.dart';
import 'package:make_it_sound_natural/widgets/shortcut_change_dialog.dart';

/// Settings section for global keyboard shortcuts configuration.
class ShortcutsSettingsSection extends StatefulWidget {
  /// Creates the shortcuts settings section widget.
  const ShortcutsSettingsSection({super.key});

  @override
  State<ShortcutsSettingsSection> createState() =>
      _ShortcutsSettingsSectionState();
}

class _ShortcutsSettingsSectionState extends State<ShortcutsSettingsSection> {
  final _settingsService = SettingsService();
  final _shortcutService = ShortcutService();

  String _currentShortcut = AppDefaults.correctionShortcut;
  String _currentReplaceShortcut = AppDefaults.replaceShortcut;
  String _currentAppendShortcut = AppDefaults.appendShortcut;

  @override
  void initState() {
    super.initState();
    unawaited(_loadSettings());
  }

  Future<void> _loadSettings() async {
    final shortcut = await _settingsService.getShortcut();
    final replaceShortcut = await _settingsService.getReplaceShortcut();
    final appendShortcut = await _settingsService.getAppendShortcut();

    if (mounted) {
      setState(() {
        _currentShortcut = shortcut;
        _currentReplaceShortcut = replaceShortcut;
        _currentAppendShortcut = appendShortcut;
      });
    }
  }

  Future<void> _changeShortcut(String type, String currentKey) async {
    final newShortcut = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => ShortcutChangeDialog(
        currentShortcut: currentKey,
      ),
    );

    if (newShortcut != null && mounted) {
      if (type == 'correction') {
        await _settingsService.setShortcut(newShortcut);
        await _shortcutService.updateShortcut(newShortcut);
        setState(() => _currentShortcut = newShortcut);
      } else if (type == 'replace') {
        await _settingsService.setReplaceShortcut(newShortcut);
        await _shortcutService.updateReplaceShortcut(newShortcut);
        setState(() => _currentReplaceShortcut = newShortcut);
      } else if (type == 'append') {
        await _settingsService.setAppendShortcut(newShortcut);
        await _shortcutService.updateAppendShortcut(newShortcut);
        setState(() => _currentAppendShortcut = newShortcut);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.shortcutSaved),
            backgroundColor: AppStatusColors.of(context).success,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _resetShortcutsToDefaults() async {
    await _settingsService.resetShortcutsToDefaults();

    const correction = AppDefaults.correctionShortcut;
    const replace = AppDefaults.replaceShortcut;
    const append = AppDefaults.appendShortcut;

    await _shortcutService.updateShortcut(correction);
    await _shortcutService.updateReplaceShortcut(replace);
    await _shortcutService.updateAppendShortcut(append);

    if (!mounted) return;
    setState(() {
      _currentShortcut = correction;
      _currentReplaceShortcut = replace;
      _currentAppendShortcut = append;
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context)!.shortcutsResetDone),
        backgroundColor: AppStatusColors.of(context).success,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _buildShortcutRow({
    required String title,
    required String shortcut,
    required String type,
  }) {
    return AppSettingsRow(
      leading: const AppSettingsIconTile(
        icon: Icons.keyboard_rounded,
      ),
      title: title,
      subtitle: ShortcutFormatter.formatShortcutDisplay(shortcut),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextButton(
            onPressed: () => _changeShortcut(type, shortcut),
            child: Text(AppLocalizations.of(context)!.changeShortcut),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppSettingsSection(
      title: AppLocalizations.of(context)!.globalShortcut,
      children: [
        _buildShortcutRow(
          title: AppLocalizations.of(context)!.shortcutCorrection,
          shortcut: _currentShortcut,
          type: 'correction',
        ),
        const AppSettingsDivider(),
        _buildShortcutRow(
          title: AppLocalizations.of(context)!.shortcutReplaceContext,
          shortcut: _currentReplaceShortcut,
          type: 'replace',
        ),
        const AppSettingsDivider(),
        _buildShortcutRow(
          title: AppLocalizations.of(context)!.shortcutAppendContext,
          shortcut: _currentAppendShortcut,
          type: 'append',
        ),
        const AppSettingsDivider(),
        AppSettingsRow(
          leading: const AppSettingsIconTile(
            icon: Icons.restart_alt_rounded,
          ),
          title: AppLocalizations.of(context)!.shortcutsReset,
          trailing: FilledButton(
            key: const Key('shortcuts-reset'),
            onPressed: _resetShortcutsToDefaults,
            child: Text(AppLocalizations.of(context)!.shortcutsReset),
          ),
        ),
      ],
    );
  }
}
