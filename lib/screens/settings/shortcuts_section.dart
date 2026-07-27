import 'dart:async';

import 'package:flutter/material.dart';
import 'package:make_it_sound_natural/constants/app_defaults.dart';
import 'package:make_it_sound_natural/l10n/gen/app_localizations.dart';
import 'package:make_it_sound_natural/services/settings_service.dart';
import 'package:make_it_sound_natural/services/shortcut_service.dart';
import 'package:make_it_sound_natural/theme/app_design_tokens.dart';
import 'package:make_it_sound_natural/utils/shortcut_formatter.dart';
import 'package:make_it_sound_natural/widgets/app_dialog_shell.dart';
import 'package:make_it_sound_natural/widgets/app_kbd_chip.dart';
import 'package:make_it_sound_natural/widgets/app_settings_section.dart';
import 'package:make_it_sound_natural/widgets/app_toast.dart';
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
        showAppToast(
          context,
          AppLocalizations.of(context)!.shortcutSaved,
          kind: AppToastKind.success,
        );
      }
    }
  }

  Future<void> _confirmResetShortcuts() async {
    final l10n = AppLocalizations.of(context)!;
    // Discarding all three global shortcuts is as irreversible as deleting a
    // model, which already confirms; this used to fire on a single click.
    final confirmed = await showAppConfirmDialog(
      context: context,
      title: l10n.shortcutsReset,
      message: Text(l10n.shortcutsResetConfirm),
      confirmLabel: l10n.shortcutsReset,
      cancelLabel: l10n.cancel,
    );
    if (!confirmed || !mounted) return;
    await _resetShortcutsToDefaults();
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
    showAppToast(
      context,
      AppLocalizations.of(context)!.shortcutsResetDone,
      kind: AppToastKind.success,
    );
  }

  Widget _buildShortcutRow({
    required String title,
    required String shortcut,
    required String type,
  }) {
    return AppSettingsRow(
      leading: const AppSettingsRowIcon(icon: Icons.keyboard_rounded),
      title: title,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppKbdChip(ShortcutFormatter.formatShortcutDisplay(shortcut)),
          const SizedBox(width: AppSpacing.xs),
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
    final section = AppSettingsSection(
      title: AppLocalizations.of(context)!.settingsNavShortcuts,
      subtitle: AppLocalizations.of(context)!.shortcutsSectionDescription,
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
          leading: const AppSettingsRowIcon(icon: Icons.restart_alt_rounded),
          title: AppLocalizations.of(context)!.shortcutsReset,
          trailing: OutlinedButton(
            key: const Key('shortcuts-reset'),
            onPressed: () => unawaited(_confirmResetShortcuts()),
            child: Text(AppLocalizations.of(context)!.shortcutsReset),
          ),
        ),
      ],
    );

    // The Rewrite screen advertises four keys; this is where a user comes to
    // learn the keyboard model, so it must not hide the two fixed ones.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        section,
        const SizedBox(height: AppSpacing.sm),
        Padding(
          padding: const EdgeInsets.only(left: AppSpacing.xxs),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: AppSizes.iconMd,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  AppLocalizations.of(context)!.shortcutsFixedNote,
                  style: AppTextStyles.rowSubtitleOf(context),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
