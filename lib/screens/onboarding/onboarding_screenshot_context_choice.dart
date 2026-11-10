import 'package:flutter/material.dart';
import 'package:make_it_sound_natural/l10n/gen/app_localizations.dart';
import 'package:make_it_sound_natural/models/screen_recording_permission_status.dart';
import 'package:make_it_sound_natural/models/screenshot_context_mode.dart';
import 'package:make_it_sound_natural/theme/app_design_tokens.dart';

/// Saves, checks or requests Screen Recording for a Screenshot context mode.
typedef ScreenshotContextPermissionAction =
    Future<ScreenRecordingPermissionStatus> Function(
      ScreenshotContextMode mode,
    );

/// Screenshot context mode choice with its Screen Recording status and the
/// actions that recover a missing permission.
class OnboardingScreenshotContextChoice extends StatelessWidget {
  /// Creates the Screenshot context choice.
  const OnboardingScreenshotContextChoice({
    required this.selectedMode,
    required this.status,
    required this.onModeChanged,
    required this.onCheckAgain,
    required this.onOpenSettings,
    super.key,
  });

  /// Selected mode.
  final ScreenshotContextMode selectedMode;

  /// Screen Recording status for [selectedMode], or null before Continue.
  final ScreenRecordingPermissionStatus? status;

  /// Called when the user picks another mode.
  final ValueChanged<ScreenshotContextMode> onModeChanged;

  /// Checks Screen Recording again.
  final VoidCallback onCheckAgain;

  /// Opens Screen Recording in System Settings.
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          label: l10n.onboardingScreenshotModeLabel,
          child: SegmentedButton<ScreenshotContextMode>(
            key: const Key('onboarding-screenshot-mode-control'),
            segments: [
              for (final (mode, label, key) in [
                (
                  ScreenshotContextMode.off,
                  l10n.screenshotContextOff,
                  'off',
                ),
                (
                  ScreenshotContextMode.fieldArea,
                  l10n.screenshotContextFieldArea,
                  'field-area',
                ),
                (
                  ScreenshotContextMode.activeApplication,
                  l10n.screenshotContextApplication,
                  'application',
                ),
                (
                  ScreenshotContextMode.fullScreen,
                  l10n.screenshotContextFullScreen,
                  'full-screen',
                ),
              ])
                ButtonSegment<ScreenshotContextMode>(
                  value: mode,
                  label: Text(
                    label,
                    key: Key('onboarding-screenshot-mode-$key'),
                  ),
                ),
            ],
            selected: {selectedMode},
            onSelectionChanged: (selection) => onModeChanged(selection.single),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Semantics(
          liveRegion: true,
          child: Text(
            key: const Key('onboarding-screenshot-status'),
            _statusText(l10n),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        if (status?.isPending ?? false)
          Wrap(
            spacing: AppSpacing.sm,
            children: [
              TextButton(
                key: const Key('onboarding-screenshot-check-again'),
                onPressed: onCheckAgain,
                child: Text(l10n.onboardingCheckAgain),
              ),
              // The helper window would cover the macOS prompt. Only the
              // first request can show it, and that returns
              // promptMayBeVisible, so the helper waits for the next check.
              // A check cannot tell whether the prompt is still up.
              if (status == ScreenRecordingPermissionStatus.manualGrantRequired)
                TextButton(
                  key: const Key('onboarding-screenshot-open-settings'),
                  onPressed: onOpenSettings,
                  child: Text(l10n.onboardingScreenshotOpenSettings),
                ),
            ],
          ),
      ],
    );
  }

  String _statusText(AppLocalizations l10n) => switch (status) {
    ScreenRecordingPermissionStatus.granted =>
      l10n.onboardingScreenshotPermissionGranted,
    ScreenRecordingPermissionStatus.unsupported =>
      l10n.onboardingScreenshotUnsupported,
    ScreenRecordingPermissionStatus.promptMayBeVisible =>
      l10n.onboardingScreenshotPermissionNeeded,
    ScreenRecordingPermissionStatus.manualGrantRequired =>
      l10n.onboardingScreenshotPermissionManual,
    null when selectedMode == ScreenshotContextMode.off =>
      l10n.onboardingScreenshotOffStatus,
    null => l10n.onboardingScreenshotModeSelected,
  };
}
