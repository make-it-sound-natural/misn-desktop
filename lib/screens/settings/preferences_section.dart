import 'dart:async';

import 'package:flutter/material.dart';
import 'package:make_it_sound_natural/constants/app_defaults.dart';
import 'package:make_it_sound_natural/l10n/correction_variant_localizations.dart';
import 'package:make_it_sound_natural/l10n/gen/app_localizations.dart';
import 'package:make_it_sound_natural/models/correction_variant.dart';
import 'package:make_it_sound_natural/models/screen_recording_permission_status.dart';
import 'package:make_it_sound_natural/models/screenshot_context_mode.dart';
import 'package:make_it_sound_natural/screens/settings/accessibility_context_row.dart';
import 'package:make_it_sound_natural/services/screen_recording_permission_guide.dart';
import 'package:make_it_sound_natural/services/settings_service.dart';
import 'package:make_it_sound_natural/services/shortcut_service.dart';
import 'package:make_it_sound_natural/theme/app_design_tokens.dart';
import 'package:make_it_sound_natural/widgets/app_dialog_shell.dart';
import 'package:make_it_sound_natural/widgets/app_popup_select.dart';
import 'package:make_it_sound_natural/widgets/app_settings_section.dart';
import 'package:make_it_sound_natural/widgets/app_toast.dart';

/// Settings section for user preferences like default variant.
class PreferencesSettingsSection extends StatefulWidget {
  /// Creates the preferences settings section widget.
  const PreferencesSettingsSection({super.key});

  @override
  State<PreferencesSettingsSection> createState() =>
      _PreferencesSettingsSectionState();
}

class _PreferencesSettingsSectionState
    extends State<PreferencesSettingsSection> {
  final _settingsService = SettingsService();
  final _shortcutService = ShortcutService();

  String _defaultVariant = AppDefaults.variant;
  ScreenshotContextMode _screenshotContextMode =
      AppDefaults.screenshotContextMode;
  ScreenshotContextMode? _pendingScreenshotContextMode;
  var _isChangingScreenshotContextMode = false;

  final List<CorrectionVariantKind> _availableVariants =
      CorrectionVariantKind.values;

  @override
  void initState() {
    super.initState();
    unawaited(_loadSettings());
  }

  Future<void> _loadSettings() async {
    final defaultVariant = await _settingsService.getDefaultVariant();
    final restoredScreenshotContext = await _shortcutService
        .restoreScreenshotContextMode(_settingsService);
    final restoredMode =
        restoredScreenshotContext?.mode ?? ScreenshotContextMode.off;
    final restoredStatus = restoredScreenshotContext?.status;

    // Validate that loaded variant exists in available variants
    final validVariant =
        CorrectionVariantKind.tryParseLabel(defaultVariant)?.wireValue ??
        AppDefaults.variant;

    if (mounted) {
      setState(() {
        _defaultVariant = validVariant;
        _screenshotContextMode =
            restoredStatus == ScreenRecordingPermissionStatus.granted
            ? restoredMode
            : ScreenshotContextMode.off;
        _pendingScreenshotContextMode = restoredStatus?.isPending ?? false
            ? restoredMode
            : null;
      });
    }
  }

  Future<bool> _confirmScreenshotContextEnable() {
    final l10n = AppLocalizations.of(context)!;
    return showAppConsentDialog(
      context: context,
      title: l10n.screenshotContextEnableTitle,
      message: l10n.screenshotContextEnableMessage,
      confirmLabel: l10n.screenshotContextEnableConfirm,
      cancelLabel: l10n.cancel,
    );
  }

  Future<ScreenRecordingPermissionStatus> _requestScreenRecordingPermission(
    ScreenshotContextMode mode,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final status = await _shortcutService.requestScreenRecordingPermission(
      mode,
    );
    if (status == ScreenRecordingPermissionStatus.granted) {
      return ScreenRecordingPermissionStatus.granted;
    }

    if (status == ScreenRecordingPermissionStatus.unsupported) {
      if (!mounted) return ScreenRecordingPermissionStatus.unsupported;
      showAppToast(context, l10n.screenRecordingPermissionUnsupported);
      return ScreenRecordingPermissionStatus.unsupported;
    }

    if (status == ScreenRecordingPermissionStatus.promptMayBeVisible) {
      return ScreenRecordingPermissionStatus.promptMayBeVisible;
    }

    final isGranted = await _shortcutService.showScreenRecordingPermissionGuide(
      l10n,
    );
    return isGranted
        ? ScreenRecordingPermissionStatus.granted
        : ScreenRecordingPermissionStatus.manualGrantRequired;
  }

  Future<void> _handleScreenshotContextModeChanged(
    ScreenshotContextMode? requestedMode,
  ) async {
    if (requestedMode == null || _isChangingScreenshotContextMode) return;

    final previousMode = _screenshotContextMode;
    if (requestedMode == previousMode) return;

    setState(() => _isChangingScreenshotContextMode = true);

    if (requestedMode == ScreenshotContextMode.off) {
      await _shortcutService.saveScreenshotContextMode(
        _settingsService,
        ScreenshotContextMode.off,
        ScreenRecordingPermissionStatus.granted,
      );
      if (!mounted) return;
      setState(() {
        _screenshotContextMode = ScreenshotContextMode.off;
        _pendingScreenshotContextMode = null;
        _isChangingScreenshotContextMode = false;
      });
      return;
    }

    var shouldPersist = true;
    if (previousMode == ScreenshotContextMode.off &&
        requestedMode != ScreenshotContextMode.off) {
      final confirmed = await _confirmScreenshotContextEnable();
      shouldPersist = confirmed;
    }

    if (!shouldPersist) {
      if (!mounted) return;
      setState(() {
        _screenshotContextMode = previousMode;
        _isChangingScreenshotContextMode = false;
      });
      return;
    }

    await _settingsService.setPendingScreenshotContextMode(requestedMode);
    final status = await _requestScreenRecordingPermission(requestedMode);

    await _shortcutService.saveScreenshotContextMode(
      _settingsService,
      requestedMode,
      status,
    );
    final selectedMode = status == ScreenRecordingPermissionStatus.granted
        ? requestedMode
        : ScreenshotContextMode.off;
    final pendingMode = status.isPending ? requestedMode : null;

    if (!mounted) return;
    setState(() {
      _screenshotContextMode = selectedMode;
      _pendingScreenshotContextMode = pendingMode;
      _isChangingScreenshotContextMode = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final screenshotContextSubtitle = _pendingScreenshotContextMode == null
        ? l10n.screenshotContextHelper
        : l10n.screenshotContextPendingPermission(
            _screenshotContextModeLabel(l10n, _pendingScreenshotContextMode!),
          );
    return AppSettingsSection(
      title: l10n.settingsNavWriting,
      subtitle: l10n.writingSectionDescription,
      children: [
        AppSettingsRow(
          leading: const AppSettingsRowIcon(icon: Icons.auto_awesome_rounded),
          title: l10n.defaultVariant,
          subtitle: l10n.defaultVariantHelper,
          trailing: SizedBox(
            width: AppSizes.settingsControlWidth,
            child: AppPopupSelect<String>(
              key: const Key('preferences-defaultVariant'),
              value: _defaultVariant,
              options: [
                for (final variant in _availableVariants)
                  AppPopupOption<String>(
                    value: variant.wireValue,
                    label: l10n.correctionVariantLabel(variant),
                  ),
              ],
              onChanged: (newValue) async {
                setState(() => _defaultVariant = newValue);
                await _settingsService.setDefaultVariant(newValue);
                await _shortcutService.setDefaultVariant(newValue);
              },
            ),
          ),
        ),
        const AppSettingsDivider(),
        AppSettingsRow(
          leading: const AppSettingsRowIcon(
            icon: Icons.screenshot_monitor_rounded,
          ),
          title: l10n.screenshotContext,
          subtitle: screenshotContextSubtitle,
          trailing: SizedBox(
            key: const Key('screenshotContextModeField'),
            width: AppSizes.settingsControlWidth,
            child: AppPopupSelect<ScreenshotContextMode>(
              value: _screenshotContextMode,
              options: [
                for (final mode in ScreenshotContextMode.values)
                  AppPopupOption<ScreenshotContextMode>(
                    value: mode,
                    label: switch (mode) {
                      ScreenshotContextMode.off => l10n.screenshotContextOff,
                      ScreenshotContextMode.fieldArea =>
                        l10n.screenshotContextFieldArea,
                      ScreenshotContextMode.activeApplication =>
                        l10n.screenshotContextApplication,
                      ScreenshotContextMode.fullScreen =>
                        l10n.screenshotContextFullScreen,
                    },
                  ),
              ],
              // Disabled while the permission flow runs, so the menu cannot
              // be opened into a choice that would be discarded.
              enabled: !_isChangingScreenshotContextMode,
              onChanged: (mode) =>
                  unawaited(_handleScreenshotContextModeChanged(mode)),
            ),
          ),
        ),
        const AppSettingsDivider(),
        const AccessibilityContextSettingsRow(),
      ],
    );
  }

  String _screenshotContextModeLabel(
    AppLocalizations l10n,
    ScreenshotContextMode mode,
  ) {
    return switch (mode) {
      ScreenshotContextMode.off => l10n.screenshotContextOff,
      ScreenshotContextMode.fieldArea => l10n.screenshotContextFieldArea,
      ScreenshotContextMode.activeApplication =>
        l10n.screenshotContextApplication,
      ScreenshotContextMode.fullScreen => l10n.screenshotContextFullScreen,
    };
  }
}
