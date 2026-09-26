import 'dart:async';

import 'package:flutter/material.dart';
import 'package:make_it_sound_natural/constants/app_defaults.dart';
import 'package:make_it_sound_natural/l10n/gen/app_localizations.dart';
import 'package:make_it_sound_natural/models/accessibility_context_mode.dart';
import 'package:make_it_sound_natural/services/settings_service.dart';
import 'package:make_it_sound_natural/services/shortcut_service.dart';
import 'package:make_it_sound_natural/theme/app_design_tokens.dart';
import 'package:make_it_sound_natural/widgets/app_dialog_shell.dart';
import 'package:make_it_sound_natural/widgets/app_popup_select.dart';
import 'package:make_it_sound_natural/widgets/app_settings_section.dart';

/// Settings row for the App context mode: text read from the active app
/// through Accessibility and sent with shortcut rewrites.
class AccessibilityContextSettingsRow extends StatefulWidget {
  /// Creates the App context row.
  const AccessibilityContextSettingsRow({super.key});

  @override
  State<AccessibilityContextSettingsRow> createState() =>
      _AccessibilityContextSettingsRowState();
}

class _AccessibilityContextSettingsRowState
    extends State<AccessibilityContextSettingsRow> {
  final _settingsService = SettingsService();
  final _shortcutService = ShortcutService();

  AccessibilityContextMode _mode = AppDefaults.accessibilityContextMode;
  var _isChanging = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadMode());
  }

  Future<void> _loadMode() async {
    final mode = await _settingsService.getAccessibilityContextMode();
    if (mounted) setState(() => _mode = mode);
  }

  Future<bool> _confirmNearbyEnable() async {
    final l10n = AppLocalizations.of(context)!;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AppDialogShell(
        title: l10n.accessibilityContextEnableTitle,
        content: Text(
          l10n.accessibilityContextEnableMessage,
          style: AppTextStyles.rowSubtitleOf(context),
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.accessibilityContextEnableConfirm),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _handleModeChanged(
    AccessibilityContextMode? requestedMode,
  ) async {
    if (requestedMode == null || _isChanging || requestedMode == _mode) return;

    setState(() => _isChanging = true);

    // Nearby text can hold other people's messages, so it needs an explicit
    // opt-in. Field text is what the user is already editing.
    if (requestedMode == AccessibilityContextMode.fieldAndNearby &&
        !await _confirmNearbyEnable()) {
      if (mounted) setState(() => _isChanging = false);
      return;
    }

    await _settingsService.setAccessibilityContextMode(requestedMode);
    await _shortcutService.setAccessibilityContextMode(requestedMode);

    if (!mounted) return;
    setState(() {
      _mode = requestedMode;
      _isChanging = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AppSettingsRow(
      leading: const AppSettingsRowIcon(icon: Icons.subject_rounded),
      title: l10n.accessibilityContext,
      subtitle: l10n.accessibilityContextHelper,
      trailing: SizedBox(
        key: const Key('accessibilityContextModeField'),
        width: AppSizes.settingsControlWidth,
        child: AppPopupSelect<AccessibilityContextMode>(
          value: _mode,
          options: [
            for (final mode in AccessibilityContextMode.values)
              AppPopupOption<AccessibilityContextMode>(
                value: mode,
                label: switch (mode) {
                  AccessibilityContextMode.off => l10n.accessibilityContextOff,
                  AccessibilityContextMode.field =>
                    l10n.accessibilityContextField,
                  AccessibilityContextMode.fieldAndNearby =>
                    l10n.accessibilityContextFieldAndNearby,
                },
              ),
          ],
          enabled: !_isChanging,
          onChanged: (mode) => unawaited(_handleModeChanged(mode)),
        ),
      ),
    );
  }
}
