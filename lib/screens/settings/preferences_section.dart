import 'dart:async';

import 'package:flutter/material.dart';
import 'package:make_it_sound_natural/constants/app_defaults.dart';
import 'package:make_it_sound_natural/l10n/correction_variant_localizations.dart';
import 'package:make_it_sound_natural/l10n/gen/app_localizations.dart';
import 'package:make_it_sound_natural/models/correction_variant.dart';
import 'package:make_it_sound_natural/models/screen_recording_permission_status.dart';
import 'package:make_it_sound_natural/models/screenshot_context_mode.dart';
import 'package:make_it_sound_natural/services/settings_service.dart';
import 'package:make_it_sound_natural/services/shortcut_service.dart';
import 'package:make_it_sound_natural/theme/app_design_tokens.dart';
import 'package:make_it_sound_natural/theme/app_theme.dart';
import 'package:make_it_sound_natural/widgets/app_dialog_escape_dismiss.dart';
import 'package:make_it_sound_natural/widgets/app_settings_section.dart';

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
  var _screenshotContextFieldVersion = 0;
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
    final screenshotContextMode = await _settingsService
        .getScreenshotContextMode();
    final pendingScreenshotContextMode = await _settingsService
        .getPendingScreenshotContextMode();
    final resolvedScreenshotContext = await _resolveScreenshotContextModeOnLoad(
      activeMode: screenshotContextMode,
      pendingMode: pendingScreenshotContextMode,
    );

    // Validate that loaded variant exists in available variants
    final validVariant =
        CorrectionVariantKind.tryParseLabel(defaultVariant)?.wireValue ??
        AppDefaults.variant;

    if (mounted) {
      setState(() {
        _defaultVariant = validVariant;
        _screenshotContextMode = resolvedScreenshotContext.activeMode;
        _pendingScreenshotContextMode = resolvedScreenshotContext.pendingMode;
      });
    }
  }

  Future<
    ({ScreenshotContextMode activeMode, ScreenshotContextMode? pendingMode})
  >
  _resolveScreenshotContextModeOnLoad({
    required ScreenshotContextMode activeMode,
    required ScreenshotContextMode? pendingMode,
  }) async {
    if (activeMode != ScreenshotContextMode.off) {
      final status = await _shortcutService.checkScreenRecordingPermission(
        activeMode,
      );
      if (status == ScreenRecordingPermissionStatus.granted) {
        await _settingsService.clearPendingScreenshotContextMode();
        return (activeMode: activeMode, pendingMode: null);
      }
      await _settingsService.setPendingScreenshotContextMode(activeMode);
      await _settingsService.setScreenshotContextMode(
        ScreenshotContextMode.off,
      );
      await _shortcutService.setScreenshotContextMode(
        ScreenshotContextMode.off,
      );
      return (
        activeMode: ScreenshotContextMode.off,
        pendingMode: activeMode,
      );
    }

    if (pendingMode == null) {
      return (activeMode: activeMode, pendingMode: null);
    }

    final status = await _shortcutService.checkScreenRecordingPermission(
      pendingMode,
    );
    if (status == ScreenRecordingPermissionStatus.granted) {
      await _settingsService.setScreenshotContextMode(pendingMode);
      await _settingsService.clearPendingScreenshotContextMode();
      await _shortcutService.setScreenshotContextMode(pendingMode);
      return (activeMode: pendingMode, pendingMode: null);
    }
    if (status == ScreenRecordingPermissionStatus.unsupported) {
      await _settingsService.clearPendingScreenshotContextMode();
      return (activeMode: ScreenshotContextMode.off, pendingMode: null);
    }
    return (
      activeMode: ScreenshotContextMode.off,
      pendingMode: pendingMode,
    );
  }

  Future<bool> _confirmScreenshotContextEnable() async {
    final l10n = AppLocalizations.of(context)!;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AppDialogEscapeDismiss<bool>(
        result: false,
        child: AlertDialog(
          title: Text(l10n.screenshotContextEnableTitle),
          content: Text(l10n.screenshotContextEnableMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l10n.screenshotContextEnableConfirm),
            ),
          ],
        ),
      ),
    );
    return result ?? false;
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.screenRecordingPermissionUnsupported)),
      );
      return ScreenRecordingPermissionStatus.unsupported;
    }

    if (status == ScreenRecordingPermissionStatus.promptMayBeVisible) {
      return ScreenRecordingPermissionStatus.promptMayBeVisible;
    }

    final isGranted = await _shortcutService
        .presentScreenRecordingPermissionGuide(
          title: l10n.screenRecordingPermissionGuideTitle,
          message: l10n.screenRecordingPermissionGuideMessage,
          dragInstruction: l10n.screenRecordingPermissionDragInstruction,
          openSettings: l10n.openSystemSettings,
          revealInFinder: l10n.revealInFinder,
          checkAgain: l10n.checkAgain,
          cancel: l10n.cancel,
          stillMissing: l10n.screenRecordingPermissionStillMissing,
          debugHint: l10n.screenRecordingPermissionDebugHint,
          manualAddRequired: false,
          openSettingsOnAppear: true,
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

    // DropdownButtonFormField updates its own visible value before async
    // permission checks finish, so remount it with the last saved value first.
    setState(() {
      _isChangingScreenshotContextMode = true;
      _screenshotContextFieldVersion++;
    });

    if (requestedMode == ScreenshotContextMode.off) {
      await _settingsService.setScreenshotContextMode(
        ScreenshotContextMode.off,
      );
      await _settingsService.clearPendingScreenshotContextMode();
      await _shortcutService.setScreenshotContextMode(
        ScreenshotContextMode.off,
      );
      if (!mounted) return;
      setState(() {
        _screenshotContextMode = ScreenshotContextMode.off;
        _pendingScreenshotContextMode = null;
        _isChangingScreenshotContextMode = false;
        _screenshotContextFieldVersion++;
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
        _screenshotContextFieldVersion++;
      });
      return;
    }

    await _settingsService.setPendingScreenshotContextMode(requestedMode);
    final status = await _requestScreenRecordingPermission(requestedMode);

    final selectedMode = status == ScreenRecordingPermissionStatus.granted
        ? requestedMode
        : ScreenshotContextMode.off;
    final pendingMode = switch (status) {
      ScreenRecordingPermissionStatus.granted ||
      ScreenRecordingPermissionStatus.unsupported => null,
      ScreenRecordingPermissionStatus.promptMayBeVisible ||
      ScreenRecordingPermissionStatus.manualGrantRequired => requestedMode,
    };

    if (selectedMode == ScreenshotContextMode.off) {
      await _settingsService.setScreenshotContextMode(
        ScreenshotContextMode.off,
      );
      await _shortcutService.setScreenshotContextMode(
        ScreenshotContextMode.off,
      );
    } else {
      await _settingsService.setScreenshotContextMode(selectedMode);
      await _shortcutService.setScreenshotContextMode(selectedMode);
    }
    if (pendingMode == null) {
      await _settingsService.clearPendingScreenshotContextMode();
    } else {
      await _settingsService.setPendingScreenshotContextMode(pendingMode);
    }

    if (!mounted) return;
    setState(() {
      _screenshotContextMode = selectedMode;
      _pendingScreenshotContextMode = pendingMode;
      _isChangingScreenshotContextMode = false;
      _screenshotContextFieldVersion++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final screenshotContextSubtitle = _pendingScreenshotContextMode == null
        ? l10n.screenshotContextHelper
        : l10n.screenshotContextPendingPermission(
            _screenshotContextModeLabel(l10n, _pendingScreenshotContextMode!),
          );
    return AppSettingsSection(
      title: l10n.preferences,
      children: [
        AppSettingsRow(
          leading: const AppSettingsIconTile(
            icon: Icons.auto_awesome_rounded,
          ),
          title: l10n.defaultVariant,
          subtitle: l10n.defaultVariantHelper,
          trailing: SizedBox(
            width: AppSizes.settingsControlWidth,
            child: DropdownButtonFormField<String>(
              key: ValueKey(_defaultVariant),
              decoration: _fieldDecoration(context),
              dropdownColor: _fieldFillColor(context),
              iconEnabledColor: colorScheme.onSurfaceVariant,
              iconDisabledColor: colorScheme.onSurfaceVariant.withValues(
                alpha: 0.38,
              ),
              initialValue: _defaultVariant,
              isExpanded: true,
              style: AppTextStyles.controlOf(context),
              items: _availableVariants.map((variant) {
                return DropdownMenuItem<String>(
                  value: variant.wireValue,
                  child: Text(
                    '${variant.emojiIcon} '
                    '${l10n.correctionVariantLabel(variant)}',
                    style: AppTextStyles.controlOf(context),
                  ),
                );
              }).toList(),
              onChanged: (newValue) async {
                if (newValue != null) {
                  setState(() => _defaultVariant = newValue);
                  await _settingsService.setDefaultVariant(newValue);
                  await _shortcutService.setDefaultVariant(newValue);
                }
              },
            ),
          ),
        ),
        const AppSettingsDivider(),
        AppSettingsRow(
          leading: const AppSettingsIconTile(
            icon: Icons.screenshot_monitor_rounded,
          ),
          title: l10n.screenshotContext,
          subtitle: screenshotContextSubtitle,
          trailing: SizedBox(
            key: const Key('screenshotContextModeField'),
            width: AppSizes.settingsControlWidth,
            child: DropdownButtonFormField<ScreenshotContextMode>(
              key: ValueKey(
                'screenshotContextMode-'
                '${_screenshotContextMode.value}-'
                '$_screenshotContextFieldVersion',
              ),
              decoration: _fieldDecoration(context),
              dropdownColor: _fieldFillColor(context),
              iconEnabledColor: colorScheme.onSurfaceVariant,
              iconDisabledColor: colorScheme.onSurfaceVariant.withValues(
                alpha: 0.38,
              ),
              initialValue: _screenshotContextMode,
              isExpanded: true,
              style: AppTextStyles.controlOf(context),
              items: ScreenshotContextMode.values.map((mode) {
                final label = switch (mode) {
                  ScreenshotContextMode.off => l10n.screenshotContextOff,
                  ScreenshotContextMode.activeApplication =>
                    l10n.screenshotContextApplication,
                  ScreenshotContextMode.fullScreen =>
                    l10n.screenshotContextFullScreen,
                };
                return DropdownMenuItem<ScreenshotContextMode>(
                  value: mode,
                  child: Text(label, style: AppTextStyles.controlOf(context)),
                );
              }).toList(),
              onChanged: _isChangingScreenshotContextMode
                  ? null
                  : _handleScreenshotContextModeChanged,
            ),
          ),
        ),
      ],
    );
  }

  InputDecoration _fieldDecoration(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return InputDecoration(
      isDense: true,
      filled: true,
      fillColor: _fieldFillColor(context),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.sm,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: BorderSide(color: theme.dividerColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: BorderSide(color: theme.dividerColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: BorderSide(color: colorScheme.primary, width: 2),
      ),
    );
  }

  Color _fieldFillColor(BuildContext context) {
    final theme = Theme.of(context);
    if (theme.brightness == Brightness.dark) {
      return AppColors.darkControlSurface;
    }
    return theme.colorScheme.surfaceContainerHighest;
  }

  String _screenshotContextModeLabel(
    AppLocalizations l10n,
    ScreenshotContextMode mode,
  ) {
    return switch (mode) {
      ScreenshotContextMode.off => l10n.screenshotContextOff,
      ScreenshotContextMode.activeApplication =>
        l10n.screenshotContextApplication,
      ScreenshotContextMode.fullScreen => l10n.screenshotContextFullScreen,
    };
  }
}
