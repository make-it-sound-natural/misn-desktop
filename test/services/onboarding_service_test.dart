import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:make_it_sound_natural/constants/app_defaults.dart';
import 'package:make_it_sound_natural/constants/method_channel_methods.dart';
import 'package:make_it_sound_natural/models/onboarding_setup_state.dart';
import 'package:make_it_sound_natural/models/screenshot_context_mode.dart';
import 'package:make_it_sound_natural/services/onboarding_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel(MethodChannelMethods.channelName);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('shows onboarding on clean install', () async {
    final service = OnboardingService();

    expect(await service.shouldShowOnboarding(), isTrue);
    expect(await service.loadState(), const OnboardingSetupState.initial());
  });

  test('persists completion across launches', () async {
    final service = OnboardingService();

    await service.markCompleted();

    expect(await service.shouldShowOnboarding(), isFalse);
    expect(await service.loadState(), const OnboardingSetupState.completed());
  });

  test('resumes incomplete onboarding from last step', () async {
    final service = OnboardingService();
    const state = OnboardingSetupState(
      completed: false,
      requiredSetupCompleted: true,
      screenshotContextSkipped: false,
      accessibilitySkipped: false,
      lastStep: OnboardingStep.screenshotContext,
    );

    await service.saveState(state);

    expect(await service.shouldShowOnboarding(), isTrue);
    expect(await service.loadState(), state);
  });

  test('preserves skipped optional state', () async {
    final service = OnboardingService();

    await service.saveState(
      const OnboardingSetupState(
        completed: false,
        requiredSetupCompleted: true,
        screenshotContextSkipped: true,
        accessibilitySkipped: false,
        lastStep: OnboardingStep.done,
      ),
    );

    final state = await service.loadState();
    expect(state.screenshotContextSkipped, isTrue);
    expect(state.lastStep, OnboardingStep.done);
  });

  test('persists skipped Accessibility state', () async {
    final service = OnboardingService();
    const state = OnboardingSetupState(
      completed: false,
      requiredSetupCompleted: true,
      screenshotContextSkipped: false,
      accessibilitySkipped: true,
      lastStep: OnboardingStep.screenshotContext,
    );

    await service.saveState(state);

    expect(await service.loadState(), state);
  });

  test(
    'existing saved setup marks onboarding complete without overwrites',
    () async {
      SharedPreferences.setMockInitialValues({
        'api_provider': 'openai',
        'openai_model': 'gpt-5.4-mini',
        'app_shortcut': 'cmd+shift+k',
        'screenshot_context_mode': 'fullScreen',
      });
      final service = OnboardingService();

      expect(await service.shouldShowOnboarding(), isFalse);

      final prefs = await SharedPreferences.getInstance();
      expect(await service.loadState(), const OnboardingSetupState.completed());
      expect(prefs.getString('api_provider'), 'openai');
      expect(prefs.getString('openai_model'), 'gpt-5.4-mini');
      expect(prefs.getString('app_shortcut'), 'cmd+shift+k');
      expect(prefs.getString('screenshot_context_mode'), 'fullScreen');
      expect(prefs.getBool(OnboardingService.completedKey), isTrue);
    },
  );

  test('legacy stored API key counts as existing setup', () async {
    SharedPreferences.setMockInitialValues({
      'api_provider': AppDefaults.openRouterProvider,
      'openrouter_api_key': 'saved-key',
    });
    final service = OnboardingService();

    expect(await service.shouldShowOnboarding(), isFalse);
  });

  test('does not treat default Screenshot context as existing setup', () async {
    SharedPreferences.setMockInitialValues({
      'screenshot_context_mode': ScreenshotContextMode.off.value,
    });
    final service = OnboardingService();

    expect(await service.shouldShowOnboarding(), isTrue);
  });
}
