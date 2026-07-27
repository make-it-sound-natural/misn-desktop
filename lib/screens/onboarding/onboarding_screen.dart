import 'dart:async';

import 'package:flutter/material.dart';
import 'package:make_it_sound_natural/l10n/gen/app_localizations.dart';
import 'package:make_it_sound_natural/models/onboarding_setup_state.dart';
import 'package:make_it_sound_natural/models/screen_recording_permission_status.dart';
import 'package:make_it_sound_natural/models/screenshot_context_mode.dart';
import 'package:make_it_sound_natural/theme/app_design_tokens.dart';
import 'package:make_it_sound_natural/widgets/app_panel.dart';
import 'package:make_it_sound_natural/widgets/app_settings_section.dart';

const double _stepDotSize = 6;
const double _stepDotGap = 6;
const double _onboardingMaxWidth = 640;

/// First-run setup flow shown before the main window.
class OnboardingScreen extends StatefulWidget {
  /// Creates the onboarding shell.
  const OnboardingScreen({
    required this.initialState,
    required this.onStateChanged,
    required this.onCompleted,
    required this.checkAccessibility,
    required this.requestAccessibility,
    required this.onScreenshotContextSelected,
    super.key,
  });

  /// Initial persisted state.
  final OnboardingSetupState initialState;

  /// Called whenever progress changes.
  final ValueChanged<OnboardingSetupState> onStateChanged;

  /// Called when setup is finished.
  final VoidCallback onCompleted;

  /// Checks Accessibility permission without prompting.
  final Future<bool> Function() checkAccessibility;

  /// Requests Accessibility permission after a user action.
  final Future<bool> Function() requestAccessibility;

  /// Requests Screenshot context mode setup after explicit opt-in.
  final Future<ScreenRecordingPermissionStatus> Function(
    ScreenshotContextMode mode,
  )
  onScreenshotContextSelected;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

enum _AccessibilityOnboardingStatus {
  unknown,
  missing,
  requesting,
  granted,
  skipped,
  stillMissing,
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  late OnboardingSetupState _state = widget.initialState;
  _AccessibilityOnboardingStatus _accessibilityStatus =
      _AccessibilityOnboardingStatus.unknown;
  ScreenshotContextMode _selectedScreenshotContextMode =
      ScreenshotContextMode.off;
  ScreenRecordingPermissionStatus? _screenshotPermissionStatus;

  @override
  void initState() {
    super.initState();
    if (_state.lastStep == OnboardingStep.accessibility) {
      unawaited(_refreshAccessibilityStatus());
    }
  }

  Future<void> _continue() async {
    if (_state.lastStep == OnboardingStep.screenshotContext) {
      await _continueScreenshotContext();
      return;
    }

    final next = _state.continueFromCurrentStep();
    _setState(next);
    if (next.lastStep == OnboardingStep.accessibility) {
      unawaited(_refreshAccessibilityStatus());
    }
  }

  Future<void> _continueScreenshotContext() async {
    if (_selectedScreenshotContextMode == ScreenshotContextMode.off) {
      _skipOptional();
      return;
    }

    final status = await widget.onScreenshotContextSelected(
      _selectedScreenshotContextMode,
    );
    if (!mounted) return;
    setState(() => _screenshotPermissionStatus = status);
    if (status == ScreenRecordingPermissionStatus.granted) {
      _setState(_state.continueFromCurrentStep());
    }
  }

  void _skipOptional() {
    _setState(_state.skipOptionalScreenshotContext());
  }

  void _skipAccessibility() {
    _setState(_state.skipAccessibilityPermission());
    setState(() {
      _accessibilityStatus = _AccessibilityOnboardingStatus.skipped;
    });
  }

  Future<void> _refreshAccessibilityStatus() async {
    final granted = await widget.checkAccessibility();
    if (!mounted || _state.lastStep != OnboardingStep.accessibility) return;
    if (granted) {
      setState(() {
        _accessibilityStatus = _AccessibilityOnboardingStatus.granted;
      });
      _setState(
        _state.copyWith(requiredSetupCompleted: true).continueFromCurrentStep(),
      );
      return;
    }
    setState(() {
      _accessibilityStatus = _state.accessibilitySkipped
          ? _AccessibilityOnboardingStatus.skipped
          : _AccessibilityOnboardingStatus.missing;
    });
  }

  Future<void> _requestAccessibility() async {
    setState(() {
      _accessibilityStatus = _AccessibilityOnboardingStatus.requesting;
    });
    final granted = await widget.requestAccessibility();
    if (!mounted) return;
    if (granted) {
      setState(() {
        _accessibilityStatus = _AccessibilityOnboardingStatus.granted;
      });
      _setState(
        _state.copyWith(requiredSetupCompleted: true).continueFromCurrentStep(),
      );
      return;
    }
    setState(() {
      _accessibilityStatus = _AccessibilityOnboardingStatus.stillMissing;
    });
  }

  void _complete() {
    widget.onCompleted();
  }

  void _setState(OnboardingSetupState state) {
    setState(() => _state = state);
    widget.onStateChanged(state);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final step = _currentStep(l10n);

    return Scaffold(
      key: const Key('onboarding-screen'),
      // Scrolls so the panel survives short windows and larger text sizes.
      body: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _onboardingMaxWidth),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xxl),
              child: AppPanel(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.onboardingTitle,
                      style: AppTextStyles.pageTitleOf(context),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppSettingsRowIcon(icon: step.icon),
                        const SizedBox(width: AppSpacing.smPlus),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                step.title,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              Text(
                                step.description,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              if (_state.lastStep ==
                                  OnboardingStep.screenshotContext)
                                _buildScreenshotContextChoices(l10n),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    if (_state.lastStep == OnboardingStep.accessibility) ...[
                      _AccessibilityStatusRow(
                        status: _accessibilityStatus,
                        l10n: l10n,
                      ),
                      const SizedBox(height: AppSpacing.xl),
                    ] else if (_state.accessibilitySkipped &&
                        _state.lastStep != OnboardingStep.done) ...[
                      _WarningText(l10n.onboardingAccessibilitySkipped),
                      const SizedBox(height: AppSpacing.xl),
                    ],
                    _StepDots(current: _state.lastStep.index, total: 4),
                    const SizedBox(height: AppSpacing.xl),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Wrap(
                        spacing: AppSpacing.sm,
                        children: [
                          if (_state.lastStep ==
                              OnboardingStep.accessibility) ...[
                            TextButton(
                              key: const Key(
                                'onboarding-accessibility-check-again',
                              ),
                              onPressed: _refreshAccessibilityStatus,
                              child: Text(
                                l10n.onboardingAccessibilityCheckAgain,
                              ),
                            ),
                            TextButton(
                              key: const Key('onboarding-accessibility-skip'),
                              onPressed: _skipAccessibility,
                              child: Text(l10n.onboardingAccessibilitySkip),
                            ),
                            FilledButton(
                              key: const Key('onboarding-accessibility-grant'),
                              onPressed:
                                  _accessibilityStatus ==
                                      _AccessibilityOnboardingStatus.requesting
                                  ? null
                                  : _requestAccessibility,
                              child: Text(l10n.onboardingAccessibilityGrant),
                            ),
                          ] else if (_state.lastStep ==
                              OnboardingStep.screenshotContext)
                            TextButton(
                              key: const Key('onboarding-skip-optional'),
                              onPressed: _skipOptional,
                              child: Text(l10n.onboardingSkipOptional),
                            ),
                          if (_state.lastStep == OnboardingStep.done)
                            FilledButton(
                              key: const Key('onboarding-complete'),
                              onPressed: _complete,
                              child: Text(l10n.onboardingComplete),
                            )
                          else if (_state.lastStep !=
                              OnboardingStep.accessibility)
                            FilledButton(
                              key: const Key('onboarding-continue'),
                              onPressed: () => unawaited(_continue()),
                              child: Text(l10n.onboardingContinue),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  _OnboardingStepContent _currentStep(AppLocalizations l10n) {
    return switch (_state.lastStep) {
      OnboardingStep.provider => _OnboardingStepContent(
        icon: Icons.auto_awesome_rounded,
        title: l10n.onboardingProviderTitle,
        description: l10n.onboardingProviderDescription,
      ),
      OnboardingStep.accessibility => _OnboardingStepContent(
        icon: Icons.lock_open_rounded,
        title: l10n.onboardingAccessibilityTitle,
        description: l10n.onboardingAccessibilityDescription,
      ),
      OnboardingStep.screenshotContext => _OnboardingStepContent(
        icon: Icons.screenshot_monitor_rounded,
        title: l10n.onboardingScreenshotTitle,
        description: l10n.onboardingScreenshotDescription,
      ),
      OnboardingStep.done => _OnboardingStepContent(
        icon: Icons.check_circle_rounded,
        title: l10n.onboardingDoneTitle,
        description: l10n.onboardingDoneDescription,
      ),
    };
  }

  Widget _buildScreenshotContextChoices(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpacing.md),
        Semantics(
          label: l10n.onboardingScreenshotModeLabel,
          child: SegmentedButton<ScreenshotContextMode>(
            key: const Key('onboarding-screenshot-mode-control'),
            segments: [
              ButtonSegment<ScreenshotContextMode>(
                value: ScreenshotContextMode.off,
                label: Text(
                  l10n.screenshotContextOff,
                  key: const Key('onboarding-screenshot-mode-off'),
                ),
              ),
              ButtonSegment<ScreenshotContextMode>(
                value: ScreenshotContextMode.activeApplication,
                label: Text(
                  l10n.screenshotContextApplication,
                  key: const Key('onboarding-screenshot-mode-application'),
                ),
              ),
              ButtonSegment<ScreenshotContextMode>(
                value: ScreenshotContextMode.fullScreen,
                label: Text(
                  l10n.screenshotContextFullScreen,
                  key: const Key('onboarding-screenshot-mode-full-screen'),
                ),
              ),
            ],
            selected: {_selectedScreenshotContextMode},
            onSelectionChanged: (selection) {
              setState(() {
                _selectedScreenshotContextMode = selection.single;
                _screenshotPermissionStatus = null;
              });
            },
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        _buildScreenshotStatus(l10n),
      ],
    );
  }

  Widget _buildScreenshotStatus(AppLocalizations l10n) {
    final text = switch (_screenshotPermissionStatus) {
      ScreenRecordingPermissionStatus.granted =>
        l10n.onboardingScreenshotPermissionGranted,
      ScreenRecordingPermissionStatus.unsupported =>
        l10n.onboardingScreenshotUnsupported,
      ScreenRecordingPermissionStatus.promptMayBeVisible ||
      ScreenRecordingPermissionStatus.manualGrantRequired =>
        l10n.onboardingScreenshotPermissionNeeded,
      null => l10n.onboardingScreenshotOffStatus,
    };

    return Text(
      key: const Key('onboarding-screenshot-status'),
      text,
      style: Theme.of(context).textTheme.bodySmall,
    );
  }
}

/// Progress dots for the four setup steps.
class _StepDots extends StatelessWidget {
  const _StepDots({required this.current, required this.total});

  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        for (var i = 0; i < total; i++) ...[
          if (i > 0) const SizedBox(width: _stepDotGap),
          Container(
            width: _stepDotSize,
            height: _stepDotSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i == current
                  ? colorScheme.primary
                  : i < current
                  ? colorScheme.onSurfaceVariant
                  : Theme.of(context).dividerColor,
            ),
          ),
        ],
      ],
    );
  }
}

class _AccessibilityStatusRow extends StatelessWidget {
  const _AccessibilityStatusRow({
    required this.status,
    required this.l10n,
  });

  final _AccessibilityOnboardingStatus status;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final (icon, text) = switch (status) {
      _AccessibilityOnboardingStatus.unknown => (
        Icons.hourglass_empty_rounded,
        l10n.onboardingAccessibilityMissing,
      ),
      _AccessibilityOnboardingStatus.missing => (
        Icons.warning_amber_rounded,
        l10n.onboardingAccessibilityMissing,
      ),
      _AccessibilityOnboardingStatus.requesting => (
        Icons.open_in_new_rounded,
        l10n.onboardingAccessibilityGrant,
      ),
      _AccessibilityOnboardingStatus.granted => (
        Icons.check_circle_rounded,
        l10n.onboardingAccessibilityGranted,
      ),
      _AccessibilityOnboardingStatus.skipped => (
        Icons.info_outline_rounded,
        l10n.onboardingAccessibilitySkipped,
      ),
      _AccessibilityOnboardingStatus.stillMissing => (
        Icons.error_outline_rounded,
        l10n.onboardingAccessibilityStillMissing,
      ),
    };

    return Semantics(
      key: const Key('onboarding-accessibility-status'),
      liveRegion: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: _WarningText(text)),
        ],
      ),
    );
  }
}

class _WarningText extends StatelessWidget {
  const _WarningText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.bodyMedium,
    );
  }
}

class _OnboardingStepContent {
  const _OnboardingStepContent({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;
}
