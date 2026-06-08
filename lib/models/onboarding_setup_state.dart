import 'package:flutter/foundation.dart';

/// Step shown by the first-run onboarding shell.
enum OnboardingStep {
  /// Provider setup introduction.
  provider('provider'),

  /// Required Accessibility permission explanation.
  accessibility('accessibility'),

  /// Optional Screenshot context discovery.
  screenshotContext('screenshotContext'),

  /// Onboarding has finished.
  done('done');

  /// Creates an onboarding step.
  const OnboardingStep(this.value);

  /// Persisted value.
  final String value;

  /// Parses a persisted value, falling back to [provider].
  static OnboardingStep fromValue(String? value) {
    for (final step in values) {
      if (step.value == value) return step;
    }
    return provider;
  }
}

/// Persisted state for first-run onboarding progress.
@immutable
class OnboardingSetupState {
  /// Creates an onboarding setup state.
  const OnboardingSetupState({
    required this.completed,
    required this.requiredSetupCompleted,
    required this.screenshotContextSkipped,
    required this.accessibilitySkipped,
    required this.lastStep,
  });

  /// Initial clean-install onboarding state.
  const OnboardingSetupState.initial()
    : completed = false,
      requiredSetupCompleted = false,
      screenshotContextSkipped = false,
      accessibilitySkipped = false,
      lastStep = OnboardingStep.provider;

  /// Completed onboarding state.
  const OnboardingSetupState.completed()
    : completed = true,
      requiredSetupCompleted = true,
      screenshotContextSkipped = false,
      accessibilitySkipped = false,
      lastStep = OnboardingStep.done;

  /// Whether onboarding should stop blocking the main app.
  final bool completed;

  /// Whether required setup shell steps were acknowledged.
  final bool requiredSetupCompleted;

  /// Whether optional Screenshot context discovery was skipped.
  final bool screenshotContextSkipped;

  /// Whether the required Accessibility permission was explicitly skipped.
  final bool accessibilitySkipped;

  /// Step to resume from when onboarding is incomplete.
  final OnboardingStep lastStep;

  /// Returns a copy with selected fields changed.
  OnboardingSetupState copyWith({
    bool? completed,
    bool? requiredSetupCompleted,
    bool? screenshotContextSkipped,
    bool? accessibilitySkipped,
    OnboardingStep? lastStep,
  }) {
    return OnboardingSetupState(
      completed: completed ?? this.completed,
      requiredSetupCompleted:
          requiredSetupCompleted ?? this.requiredSetupCompleted,
      screenshotContextSkipped:
          screenshotContextSkipped ?? this.screenshotContextSkipped,
      accessibilitySkipped: accessibilitySkipped ?? this.accessibilitySkipped,
      lastStep: lastStep ?? this.lastStep,
    );
  }

  /// Advances the onboarding state machine for the primary action.
  OnboardingSetupState continueFromCurrentStep() {
    return switch (lastStep) {
      OnboardingStep.provider => copyWith(
        lastStep: OnboardingStep.accessibility,
      ),
      OnboardingStep.accessibility => copyWith(
        requiredSetupCompleted: true,
        lastStep: OnboardingStep.screenshotContext,
      ),
      OnboardingStep.screenshotContext => copyWith(
        lastStep: OnboardingStep.done,
      ),
      OnboardingStep.done => this,
    };
  }

  /// Skips optional Screenshot context discovery.
  OnboardingSetupState skipOptionalScreenshotContext() {
    return copyWith(
      screenshotContextSkipped: true,
      lastStep: OnboardingStep.done,
    );
  }

  /// Skips required Accessibility permission with a persisted warning state.
  OnboardingSetupState skipAccessibilityPermission() {
    return copyWith(
      accessibilitySkipped: true,
      requiredSetupCompleted: true,
      lastStep: OnboardingStep.screenshotContext,
    );
  }

  /// Returns a completed state.
  OnboardingSetupState markCompleted() {
    return const OnboardingSetupState.completed();
  }

  @override
  bool operator ==(Object other) {
    return other is OnboardingSetupState &&
        other.completed == completed &&
        other.requiredSetupCompleted == requiredSetupCompleted &&
        other.screenshotContextSkipped == screenshotContextSkipped &&
        other.accessibilitySkipped == accessibilitySkipped &&
        other.lastStep == lastStep;
  }

  @override
  int get hashCode {
    return Object.hash(
      completed,
      requiredSetupCompleted,
      screenshotContextSkipped,
      accessibilitySkipped,
      lastStep,
    );
  }
}
