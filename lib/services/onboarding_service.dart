import 'package:make_it_sound_natural/constants/app_defaults.dart';
import 'package:make_it_sound_natural/models/onboarding_setup_state.dart';
import 'package:make_it_sound_natural/models/screenshot_context_mode.dart';
import 'package:make_it_sound_natural/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists and evaluates first-run onboarding state.
class OnboardingService {
  /// Creates an onboarding service.
  OnboardingService({SettingsService? settingsService})
    : _settingsService = settingsService ?? SettingsService();

  /// Completion flag key.
  static const String completedKey = 'onboarding_completed';

  static const String _requiredSetupCompletedKey =
      'onboarding_required_setup_completed';
  static const String _screenshotContextSkippedKey =
      'onboarding_screenshot_context_skipped';
  static const String _accessibilitySkippedKey =
      'onboarding_accessibility_skipped';
  static const String _lastStepKey = 'onboarding_last_step';

  final SettingsService _settingsService;

  /// Returns whether onboarding should be shown for this launch.
  Future<bool> shouldShowOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    final completed = prefs.getBool(completedKey);
    if (completed ?? false) return false;
    if (completed != null) return true;

    if (await _hasExistingSetup(prefs)) {
      await markCompleted();
      return false;
    }

    return true;
  }

  /// Loads current onboarding progress.
  Future<OnboardingSetupState> loadState() async {
    final prefs = await SharedPreferences.getInstance();
    final completed = prefs.getBool(completedKey) ?? false;
    if (completed) return const OnboardingSetupState.completed();

    return OnboardingSetupState(
      completed: false,
      requiredSetupCompleted:
          prefs.getBool(_requiredSetupCompletedKey) ?? false,
      screenshotContextSkipped:
          prefs.getBool(_screenshotContextSkippedKey) ?? false,
      accessibilitySkipped: prefs.getBool(_accessibilitySkippedKey) ?? false,
      lastStep: OnboardingStep.fromValue(prefs.getString(_lastStepKey)),
    );
  }

  /// Saves onboarding progress without changing unrelated user settings.
  Future<void> saveState(OnboardingSetupState state) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(completedKey, state.completed);
    await prefs.setBool(
      _requiredSetupCompletedKey,
      state.requiredSetupCompleted,
    );
    await prefs.setBool(
      _screenshotContextSkippedKey,
      state.screenshotContextSkipped,
    );
    await prefs.setBool(
      _accessibilitySkippedKey,
      state.accessibilitySkipped,
    );
    await prefs.setString(_lastStepKey, state.lastStep.value);
  }

  /// Marks onboarding as complete.
  Future<void> markCompleted() {
    return saveState(const OnboardingSetupState.completed());
  }

  Future<bool> _hasExistingSetup(SharedPreferences prefs) async {
    const savedSettingKeys = [
      'api_provider',
      'openai_model',
      'app_shortcut',
      'app_shortcut_replace',
      'app_shortcut_append',
      'default_variant',
    ];

    for (final key in savedSettingKeys) {
      if (prefs.containsKey(key)) return true;
    }

    final screenshotContext = prefs.getString('screenshot_context_mode');
    if (ScreenshotContextMode.fromValue(screenshotContext) !=
        AppDefaults.screenshotContextMode) {
      return true;
    }

    return _settingsService.hasApiKeyForActiveProvider();
  }
}
