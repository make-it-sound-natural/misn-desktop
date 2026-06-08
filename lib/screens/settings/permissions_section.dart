import 'dart:async';

import 'package:flutter/material.dart';
import 'package:make_it_sound_natural/l10n/gen/app_localizations.dart';
import 'package:make_it_sound_natural/services/shortcut_service.dart';
import 'package:make_it_sound_natural/theme/app_design_tokens.dart';
import 'package:make_it_sound_natural/theme/app_theme.dart';
import 'package:make_it_sound_natural/widgets/app_settings_section.dart';
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.openAccessibilitySettings,
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColors = AppStatusColors.of(context);
    return AppSettingsSection(
      title: AppLocalizations.of(context)!.permissions,
      children: [
        AppSettingsRow(
          leading: AppSettingsIconTile(
            icon: _isAccessibilityTrusted
                ? Icons.check_circle_rounded
                : Icons.warning_rounded,
            backgroundColor: _isAccessibilityTrusted
                ? statusColors.successContainer
                : statusColors.warningContainer,
            iconColor: _isAccessibilityTrusted
                ? statusColors.success
                : statusColors.warning,
          ),
          title: _isAccessibilityTrusted
              ? AppLocalizations.of(context)!.accessibilityPermitted
              : AppLocalizations.of(context)!.accessibilityRequired,
          subtitle: _isAccessibilityTrusted
              ? null
              : AppLocalizations.of(context)!.accessibilityNeededDescription,
          trailing: _isAccessibilityTrusted
              ? null
              : TextButton(
                  onPressed: _openAccessibilitySettings,
                  child: Text(AppLocalizations.of(context)!.grant),
                ),
        ),
        if (!_isAccessibilityTrusted)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              0,
              AppSpacing.xl,
              AppSpacing.md,
            ),
            child: TextButton(
              onPressed: _checkPermissions,
              child: Text(AppLocalizations.of(context)!.checkAgain),
            ),
          ),
      ],
    );
  }
}
