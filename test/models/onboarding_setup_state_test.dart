import 'package:flutter_test/flutter_test.dart';
import 'package:make_it_sound_natural/models/onboarding_setup_state.dart';

void main() {
  group('OnboardingStep', () {
    test('parses known values and falls back to provider', () {
      expect(
        OnboardingStep.fromValue(OnboardingStep.provider.value),
        OnboardingStep.provider,
      );
      expect(
        OnboardingStep.fromValue(OnboardingStep.accessibility.value),
        OnboardingStep.accessibility,
      );
      expect(
        OnboardingStep.fromValue(OnboardingStep.screenshotContext.value),
        OnboardingStep.screenshotContext,
      );
      expect(
        OnboardingStep.fromValue(OnboardingStep.done.value),
        OnboardingStep.done,
      );
      expect(OnboardingStep.fromValue('future'), OnboardingStep.provider);
      expect(OnboardingStep.fromValue(null), OnboardingStep.provider);
    });
  });

  group('OnboardingSetupState', () {
    test('starts at provider step by default', () {
      const state = OnboardingSetupState.initial();

      expect(state.completed, isFalse);
      expect(state.requiredSetupCompleted, isFalse);
      expect(state.screenshotContextSkipped, isFalse);
      expect(state.accessibilitySkipped, isFalse);
      expect(state.lastStep, OnboardingStep.provider);
    });

    test('completed factory stores done step', () {
      const state = OnboardingSetupState.completed();

      expect(state.completed, isTrue);
      expect(state.requiredSetupCompleted, isTrue);
      expect(state.lastStep, OnboardingStep.done);
    });

    test('copyWith keeps unspecified values', () {
      const state = OnboardingSetupState.initial();
      final updated = state.copyWith(
        screenshotContextSkipped: true,
        lastStep: OnboardingStep.screenshotContext,
      );

      expect(updated.completed, isFalse);
      expect(updated.requiredSetupCompleted, isFalse);
      expect(updated.screenshotContextSkipped, isTrue);
      expect(updated.accessibilitySkipped, isFalse);
      expect(updated.lastStep, OnboardingStep.screenshotContext);
    });

    test('continues through setup steps as a state machine', () {
      const initial = OnboardingSetupState.initial();

      final accessibility = initial.continueFromCurrentStep();
      expect(accessibility.lastStep, OnboardingStep.accessibility);
      expect(accessibility.requiredSetupCompleted, isFalse);

      final screenshot = accessibility.continueFromCurrentStep();
      expect(screenshot.lastStep, OnboardingStep.screenshotContext);
      expect(screenshot.requiredSetupCompleted, isTrue);

      final done = screenshot.continueFromCurrentStep();
      expect(done.lastStep, OnboardingStep.done);
      expect(done.completed, isFalse);
    });

    test('skips optional screenshot context as a state transition', () {
      const state = OnboardingSetupState(
        completed: false,
        requiredSetupCompleted: true,
        screenshotContextSkipped: false,
        accessibilitySkipped: false,
        lastStep: OnboardingStep.screenshotContext,
      );

      final skipped = state.skipOptionalScreenshotContext();

      expect(skipped.screenshotContextSkipped, isTrue);
      expect(skipped.lastStep, OnboardingStep.done);
    });

    test('skips Accessibility with required setup warning state', () {
      const state = OnboardingSetupState(
        completed: false,
        requiredSetupCompleted: false,
        screenshotContextSkipped: false,
        accessibilitySkipped: false,
        lastStep: OnboardingStep.accessibility,
      );

      final skipped = state.skipAccessibilityPermission();

      expect(skipped.accessibilitySkipped, isTrue);
      expect(skipped.requiredSetupCompleted, isTrue);
      expect(skipped.lastStep, OnboardingStep.screenshotContext);
    });

    test('markCompleted normalizes any state to completed done', () {
      const state = OnboardingSetupState(
        completed: false,
        requiredSetupCompleted: false,
        screenshotContextSkipped: true,
        accessibilitySkipped: false,
        lastStep: OnboardingStep.accessibility,
      );

      expect(state.markCompleted(), const OnboardingSetupState.completed());
    });
  });
}
