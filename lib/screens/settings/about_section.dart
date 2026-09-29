import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:make_it_sound_natural/l10n/gen/app_localizations.dart';
import 'package:make_it_sound_natural/services/update_service.dart';
import 'package:make_it_sound_natural/theme/app_design_tokens.dart';
import 'package:make_it_sound_natural/widgets/app_settings_section.dart';
import 'package:make_it_sound_natural/widgets/app_toast.dart';
import 'package:url_launcher/url_launcher.dart';

const _repositoryUrl = 'https://github.com/make-it-sound-natural/misn-desktop';
const _appName = 'Make It Sound Natural';

/// Settings section showing the installed version, build, channel and links.
class AboutSettingsSection extends StatefulWidget {
  /// Creates the about settings section widget.
  const AboutSettingsSection({super.key});

  @override
  State<AboutSettingsSection> createState() => _AboutSettingsSectionState();
}

class _AboutSettingsSectionState extends State<AboutSettingsSection> {
  final _updateService = UpdateService();

  AppVersion _appVersion = const AppVersion(
    version: 'Unknown',
    build: 'Unknown',
  );

  @override
  void initState() {
    super.initState();
    final cachedSnapshot = _updateService.cachedSettingsSnapshot;
    if (cachedSnapshot != null) {
      _appVersion = cachedSnapshot.appVersion;
    }
    unawaited(_loadVersion());
  }

  Future<void> _loadVersion() async {
    final snapshot = await _updateService.loadSettingsSnapshot();
    if (mounted) {
      setState(() => _appVersion = snapshot.appVersion);
    }
  }

  String _releaseChannelLabel(AppLocalizations l10n) {
    return switch (_appVersion.releaseChannel) {
      AppReleaseChannel.stable => l10n.releaseChannelStable,
      AppReleaseChannel.beta => l10n.releaseChannelBeta,
      AppReleaseChannel.nightly => l10n.releaseChannelNightly,
      AppReleaseChannel.unknown => l10n.releaseChannelUnknown,
    };
  }

  String _diagnosticsText(AppLocalizations l10n) {
    return [
      _appName,
      'Version: ${_appVersion.version}',
      'Build: ${_appVersion.build}',
      'Channel: ${_releaseChannelLabel(l10n)}',
    ].join('\n');
  }

  void _copyDiagnostics(AppLocalizations l10n) {
    unawaited(Clipboard.setData(ClipboardData(text: _diagnosticsText(l10n))));
    showAppToast(context, l10n.copiedToClipboard);
  }

  Uri _reportIssueUri(AppLocalizations l10n) {
    return Uri.https(
      'github.com',
      '/make-it-sound-natural/misn-desktop/issues/new',
      {
        'body': _diagnosticsText(l10n),
      },
    );
  }

  Future<void> _open(Uri uri) async {
    final l10n = AppLocalizations.of(context)!;
    final opened = await launchUrl(uri);
    if (!opened && mounted) {
      showAppToast(context, l10n.aboutLinkOpenFailed);
    }
  }

  Widget _linkRow({
    required Key key,
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    String? subtitle,
  }) {
    return AppSettingsRow(
      key: key,
      leading: AppSettingsRowIcon(icon: icon),
      title: title,
      subtitle: subtitle,
      trailing: Icon(
        Icons.open_in_new_rounded,
        size: AppSizes.iconMd,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      onTap: onTap,
    );
  }

  Widget _valueRow({
    required Key key,
    required IconData icon,
    required String title,
    required String value,
  }) {
    return AppSettingsRow(
      key: key,
      leading: AppSettingsRowIcon(icon: icon),
      title: title,
      trailing: Text(value, style: AppTextStyles.rowTitleOf(context)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSettingsSection(
          title: l10n.appInformation,
          subtitle: l10n.aboutSectionDescription,
          children: [
            AppSettingsRow(
              minHeight: AppSizes.settingsRowHeight + AppSpacing.md,
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.xl),
                child: Image.asset(
                  'macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_128.png',
                  key: const Key('about-appIcon'),
                  width: AppSizes.iconTileSmall,
                  height: AppSizes.iconTileSmall,
                  excludeFromSemantics: true,
                ),
              ),
              title: _appName,
              subtitle: l10n.versionLabel(_appVersion.version),
              trailing: IconButton(
                key: const Key('copyAppDiagnostics-button'),
                tooltip: l10n.copyAppDiagnostics,
                onPressed: () => _copyDiagnostics(l10n),
                icon: const Icon(Icons.copy_rounded),
              ),
            ),
            const AppSettingsDivider(),
            _valueRow(
              key: const Key('about-build'),
              icon: Icons.tag_rounded,
              title: l10n.aboutBuildLabel,
              value: _appVersion.build,
            ),
            const AppSettingsDivider(),
            _valueRow(
              key: const Key('about-channel'),
              icon: Icons.new_releases_outlined,
              title: l10n.aboutChannelLabel,
              value: _releaseChannelLabel(l10n),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        AppSettingsSection(
          title: l10n.aboutLinks,
          children: [
            _linkRow(
              key: const Key('about-whatsNew'),
              icon: Icons.campaign_outlined,
              title: l10n.aboutWhatsNew,
              subtitle: l10n.aboutWhatsNewSubtitle,
              onTap: () =>
                  unawaited(_open(Uri.parse('$_repositoryUrl/releases'))),
            ),
            const AppSettingsDivider(),
            _linkRow(
              key: const Key('about-reportIssue'),
              icon: Icons.bug_report_outlined,
              title: l10n.aboutReportIssue,
              subtitle: l10n.aboutReportIssueSubtitle,
              onTap: () => unawaited(_open(_reportIssueUri(l10n))),
            ),
            const AppSettingsDivider(),
            _linkRow(
              key: const Key('about-privacyPolicy'),
              icon: Icons.privacy_tip_outlined,
              title: l10n.aboutPrivacyPolicy,
              onTap: () => unawaited(
                _open(
                  Uri.parse('$_repositoryUrl/blob/master/PRIVACY_POLICY.md'),
                ),
              ),
            ),
            const AppSettingsDivider(),
            _linkRow(
              key: const Key('about-license'),
              icon: Icons.description_outlined,
              title: l10n.aboutLicense,
              onTap: () => unawaited(
                _open(Uri.parse('$_repositoryUrl/blob/master/LICENSE')),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
