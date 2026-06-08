import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:make_it_sound_natural/l10n/gen/app_localizations.dart';
import 'package:make_it_sound_natural/services/update_service.dart';
import 'package:make_it_sound_natural/theme/app_design_tokens.dart';
import 'package:make_it_sound_natural/theme/app_theme.dart';
import 'package:make_it_sound_natural/widgets/app_settings_section.dart';

/// Settings section for app updates management.
class UpdatesSettingsSection extends StatefulWidget {
  /// Creates the updates settings section widget.
  const UpdatesSettingsSection({super.key});

  @override
  State<UpdatesSettingsSection> createState() => _UpdatesSettingsSectionState();
}

class _UpdatesSettingsSectionState extends State<UpdatesSettingsSection> {
  final _updateService = UpdateService();

  UpdateCheckState _updateCheckState = UpdateCheckState.idle;
  AppVersion _appVersion = const AppVersion(
    version: 'Unknown',
    build: 'Unknown',
  );
  DateTime? _lastUpdateCheck;
  bool? _automaticUpdateChecks;
  String? _updateCheckError;

  @override
  void initState() {
    super.initState();
    final cachedSnapshot = _updateService.cachedSettingsSnapshot;
    if (cachedSnapshot != null) {
      _applySettingsSnapshot(cachedSnapshot);
    }
    unawaited(_loadSettings());
  }

  Future<void> _loadSettings() async {
    final snapshot = await _updateService.loadSettingsSnapshot();

    if (mounted) {
      setState(() => _applySettingsSnapshot(snapshot));
    }
  }

  void _applySettingsSnapshot(UpdateSettingsSnapshot snapshot) {
    _appVersion = snapshot.appVersion;
    _lastUpdateCheck = snapshot.lastUpdateCheck;
    _automaticUpdateChecks = snapshot.automaticUpdateChecks;
  }

  Future<void> _checkForUpdates() async {
    if (_updateCheckState == UpdateCheckState.checking) {
      return; // Prevent double-clicks
    }

    setState(() {
      _updateCheckState = UpdateCheckState.checking;
      _updateCheckError = null;
    });

    final result = await _updateService.checkForUpdates();

    if (!mounted) return;

    setState(() {
      if (result.success) {
        _updateCheckState = UpdateCheckState.upToDate;
        _lastUpdateCheck = DateTime.now();
      } else {
        _updateCheckState = UpdateCheckState.error;
        _updateCheckError = result.error ?? 'Unknown error';
      }
    });

    // Auto-reset to idle after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _updateCheckState = UpdateCheckState.idle;
        });
      }
    });
  }

  Future<void> _onAutomaticUpdateChecksChanged(bool value) async {
    setState(() => _automaticUpdateChecks = value);
    await _updateService.setAutomaticUpdateChecks(enabled: value);
  }

  Widget _buildAutomaticChecksTrailing() {
    final automaticUpdateChecks = _automaticUpdateChecks;
    if (automaticUpdateChecks == null) {
      return const SizedBox(
        key: Key('automaticUpdateChecks-placeholder'),
        width: 52,
        height: AppSizes.compactRowHeight,
      );
    }

    return Switch(
      key: const Key('automaticUpdateChecks-switch'),
      value: automaticUpdateChecks,
      onChanged: _onAutomaticUpdateChecksChanged,
    );
  }

  Widget _buildUpdateCheckIcon() {
    final statusColors = AppStatusColors.of(context);
    switch (_updateCheckState) {
      case UpdateCheckState.idle:
        return const AppSettingsIconTile(
          icon: Icons.refresh_rounded,
        );
      case UpdateCheckState.checking:
        return const AppSettingsIconTile(
          icon: Icons.hourglass_top_rounded,
          iconColor: AppColors.secondary,
        );
      case UpdateCheckState.upToDate:
        return AppSettingsIconTile(
          icon: Icons.check_circle_rounded,
          backgroundColor: statusColors.successContainer,
          iconColor: statusColors.success,
        );
      case UpdateCheckState.error:
        return AppSettingsIconTile(
          icon: Icons.warning_rounded,
          backgroundColor: statusColors.warningContainer,
          iconColor: statusColors.warning,
        );
    }
  }

  String _getUpdateCheckButtonText(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    switch (_updateCheckState) {
      case UpdateCheckState.idle:
        return l10n.checkForUpdates;
      case UpdateCheckState.checking:
        return l10n.checkingUpdates;
      case UpdateCheckState.upToDate:
        return l10n.upToDate;
      case UpdateCheckState.error:
        return l10n.checkFailed;
    }
  }

  String _getLastCheckText(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (_updateCheckState == UpdateCheckState.error &&
        _updateCheckError != null) {
      return _updateCheckError!;
    }
    if (_lastUpdateCheck == null) {
      return l10n.lastCheckedNever;
    }
    final now = DateTime.now();
    final diff = now.difference(_lastUpdateCheck!);
    if (diff.inMinutes < 1) {
      return l10n.lastCheckedJustNow;
    } else if (diff.inHours < 1) {
      return l10n.lastCheckedMinutesAgo(diff.inMinutes);
    } else if (diff.inDays < 1) {
      return l10n.lastCheckedHoursAgo(diff.inHours);
    } else {
      return l10n.lastCheckedDaysAgo(diff.inDays);
    }
  }

  Widget? _buildUpdateCheckButton(BuildContext context) {
    if (_updateCheckState == UpdateCheckState.checking) {
      return null; // No button while checking
    }
    return TextButton(
      onPressed: _checkForUpdates,
      child: Text(AppLocalizations.of(context)!.checkButton),
    );
  }

  String _releaseChannelLabel(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return switch (_appVersion.releaseChannel) {
      AppReleaseChannel.stable => l10n.releaseChannelStable,
      AppReleaseChannel.beta => l10n.releaseChannelBeta,
      AppReleaseChannel.nightly => l10n.releaseChannelNightly,
      AppReleaseChannel.unknown => l10n.releaseChannelUnknown,
    };
  }

  String _appDiagnosticsText(BuildContext context) {
    return [
      'Make It Sound Natural',
      'Version: ${_appVersion.version}',
      'Build: ${_appVersion.build}',
      'Channel: ${_releaseChannelLabel(context)}',
    ].join('\n');
  }

  void _copyAppDiagnostics(BuildContext context) {
    unawaited(
      Clipboard.setData(
        ClipboardData(text: _appDiagnosticsText(context)),
      ),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context)!.copiedToClipboard)),
    );
  }

  Widget _buildAppInformationSection(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final channelLabel = _releaseChannelLabel(context);

    return AppSettingsSection(
      title: l10n.appInformation,
      children: [
        AppSettingsRow(
          leading: const AppSettingsIconTile(
            icon: Icons.info_outline_rounded,
          ),
          title: l10n.versionLabel(_appVersion.version),
          subtitle: channelLabel,
          trailing: IconButton(
            key: const Key('copyAppDiagnostics-button'),
            tooltip: l10n.copyAppDiagnostics,
            onPressed: () => _copyAppDiagnostics(context),
            icon: const Icon(Icons.copy_rounded),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildAppInformationSection(context),
        const SizedBox(height: AppSpacing.lg),
        AppSettingsSection(
          title: l10n.updates,
          children: [
            AppSettingsRow(
              leading: _buildUpdateCheckIcon(),
              title: _getUpdateCheckButtonText(context),
              subtitle: _getLastCheckText(context),
              trailing: _buildUpdateCheckButton(context),
            ),
            const AppSettingsDivider(),
            AppSettingsRow(
              leading: const AppSettingsIconTile(
                icon: Icons.autorenew_rounded,
              ),
              title: l10n.automaticChecks,
              subtitle: l10n.automaticChecksSubtitle,
              trailing: _buildAutomaticChecksTrailing(),
            ),
          ],
        ),
      ],
    );
  }
}
