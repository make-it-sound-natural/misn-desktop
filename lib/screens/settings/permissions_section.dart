import 'dart:async';

import 'package:flutter/material.dart';
import 'package:make_it_sound_natural/l10n/gen/app_localizations.dart';
import 'package:make_it_sound_natural/services/shortcut_service.dart';
import 'package:make_it_sound_natural/theme/app_design_tokens.dart';
import 'package:make_it_sound_natural/theme/app_theme.dart';
import 'package:make_it_sound_natural/widgets/app_settings_section.dart';
import 'package:make_it_sound_natural/widgets/app_toast.dart';
import 'package:url_launcher/url_launcher.dart';

/// Settings section for system permissions management.
class PermissionsSettingsSection extends StatefulWidget {
  /// Creates the permissions settings section widget.
  const PermissionsSettingsSection({super.key});

  @override
  State<PermissionsSettingsSection> createState() =>
      _PermissionsSettingsSectionState();
}

class _PermissionsSettingsSectionState
    extends State<PermissionsSettingsSection> {
  final _shortcutService = ShortcutService();
  bool _isAccessibilityTrusted = false;

  @override
  void initState() {
    super.initState();
    unawaited(_checkPermissions());
  }

  Future<void> _checkPermissions() async {
    final isTrusted = await _shortcutService.checkAccessibilityPermissions();
    if (mounted) {
      setState(() => _isAccessibilityTrusted = isTrusted);
    }
  }

  Future<void> _openAccessibilitySettings() async {
    const urlString =
        'x-apple.systempreferences:com.apple.preference.security?'
        'Privacy_Accessibility';
    final url = Uri.parse(urlString);
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      if (mounted) {
        showAppToast(
          context,
          AppLocalizations.of(context)!.openAccessibilitySettings,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColors = AppStatusColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSettingsSection(
          title: l10n.permissions,
          subtitle: l10n.permissionsSectionDescription,
          children: [
            AppSettingsRow(
              leading: AppSettingsRowIcon(
                icon: _isAccessibilityTrusted
                    ? Icons.check_circle_outline_rounded
                    : Icons.warning_amber_rounded,
                color: _isAccessibilityTrusted
                    ? statusColors.success
                    : statusColors.warning,
              ),
              title: _isAccessibilityTrusted
                  ? l10n.accessibilityPermitted
                  : l10n.accessibilityRequired,
              subtitle: _isAccessibilityTrusted
                  ? null
                  : l10n.accessibilityNeededDescription,
              trailing: _isAccessibilityTrusted
                  ? null
                  : TextButton(
                      onPressed: _openAccessibilitySettings,
                      child: Text(l10n.grant),
                    ),
            ),
          ],
        ),
        if (!_isAccessibilityTrusted)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xxs),
            child: TextButton(
              onPressed: _checkPermissions,
              child: Text(l10n.checkAgain),
            ),
          ),
      ],
    );
  }
}
