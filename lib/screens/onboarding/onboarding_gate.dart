import 'dart:async';

import 'package:flutter/material.dart';
import 'package:make_it_sound_natural/l10n/gen/app_localizations.dart';
import 'package:make_it_sound_natural/models/accessibility_context_mode.dart';
import 'package:make_it_sound_natural/models/onboarding_setup_state.dart';
import 'package:make_it_sound_natural/models/screen_recording_permission_status.dart';
import 'package:make_it_sound_natural/models/screenshot_context_mode.dart';
import 'package:make_it_sound_natural/screens/home_screen.dart';
import 'package:make_it_sound_natural/screens/onboarding/onboarding_screen.dart';
import 'package:make_it_sound_natural/services/onboarding_service.dart';
import 'package:make_it_sound_natural/services/screen_recording_permission_guide.dart';
import 'package:make_it_sound_natural/services/settings_service.dart';
import 'package:make_it_sound_natural/services/shortcut_service.dart';

/// Decides whether to show first-run onboarding or the main app.
class OnboardingGate extends StatefulWidget {
  /// Creates an onboarding gate.
  const OnboardingGate({
    super.key,
    OnboardingService? service,
    ShortcutService? shortcutService,
    SettingsService? settingsService,
  }) : _service = service,
       _shortcutService = shortcutService,
       _settingsService = settingsService;

  final OnboardingService? _service;
  final ShortcutService? _shortcutService;
  final SettingsService? _settingsService;

  @override
  State<OnboardingGate> createState() => _OnboardingGateState();
}

class _OnboardingGateState extends State<OnboardingGate> {
  late final OnboardingService _service =
      widget._service ?? OnboardingService();
  late final ShortcutService _shortcutService =
      widget._shortcutService ?? ShortcutService();
  late final SettingsService _settingsService =
      widget._settingsService ?? SettingsService();
  OnboardingSetupState? _state;
  AccessibilityContextMode _accessibilityContextMode =
      AccessibilityContextMode.field;
  ScreenshotContextMode _screenshotContextMode = ScreenshotContextMode.off;
  ScreenRecordingPermissionStatus? _screenshotPermissionStatus;
  var _showOnboarding = false;
  var _loaded = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final showOnboarding = await _service.shouldShowOnboarding();
    final state = showOnboarding
        ? await _service.loadState()
        : const OnboardingSetupState.completed();
    final accessibilityContextMode = showOnboarding
        ? await _settingsService.getAccessibilityContextMode()
        : AccessibilityContextMode.field;
    // A resumed step shows the saved choice with its current permission.
    final screenshotContext = showOnboarding
        ? await _shortcutService.restoreScreenshotContextMode(_settingsService)
        : null;
    if (!mounted) return;
    setState(() {
      _showOnboarding = showOnboarding;
      _state = state;
      _accessibilityContextMode = accessibilityContextMode;
      _screenshotContextMode =
          screenshotContext?.mode ?? ScreenshotContextMode.off;
      _screenshotPermissionStatus = screenshotContext?.status;
      _loaded = true;
    });
  }

  Future<void> _saveState(OnboardingSetupState state) async {
    await _service.saveState(state);
  }

  Future<void> _complete() async {
    await _service.markCompleted();
    if (!mounted) return;
    setState(() {
      _showOnboarding = false;
      _state = const OnboardingSetupState.completed();
    });
  }

  Future<ScreenRecordingPermissionStatus> _chooseScreenshotContextMode(
    ScreenshotContextMode mode,
  ) async {
    if (mode == ScreenshotContextMode.off) {
      await _saveScreenshotContextMode(
        mode,
        ScreenRecordingPermissionStatus.granted,
      );
      return ScreenRecordingPermissionStatus.granted;
    }

    // Saved before the request: macOS may ask to relaunch the app, and the
    // next launch turns the pending mode on once permission is granted.
    await _settingsService.setPendingScreenshotContextMode(mode);
    final status = await _shortcutService.requestScreenRecordingPermission(
      mode,
    );
    await _saveScreenshotContextMode(mode, status);
    return status;
  }

  /// Checks Screen Recording without prompting and turns the pending mode on
  /// once it is granted.
  Future<ScreenRecordingPermissionStatus> _recheckScreenshotContextMode(
    ScreenshotContextMode mode,
  ) async {
    final status = await _shortcutService.checkScreenRecordingPermission(mode);
    await _saveScreenshotContextMode(mode, status);
    return status;
  }

  /// Opens Screen Recording in System Settings with the helper Settings
  /// shows, then checks again.
  Future<ScreenRecordingPermissionStatus> _openScreenRecordingSettings(
    ScreenshotContextMode mode,
  ) async {
    await _shortcutService.showScreenRecordingPermissionGuide(
      AppLocalizations.of(context)!,
    );
    return _recheckScreenshotContextMode(mode);
  }

  Future<void> _saveScreenshotContextMode(
    ScreenshotContextMode mode,
    ScreenRecordingPermissionStatus status,
  ) => _shortcutService.saveScreenshotContextMode(
    _settingsService,
    mode,
    status,
  );

  Future<void> _chooseAccessibilityContextMode(
    AccessibilityContextMode mode,
  ) async {
    await _settingsService.setAccessibilityContextMode(mode);
    await _shortcutService.setAccessibilityContextMode(mode);
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!_showOnboarding) return const HomeScreen();

    return OnboardingScreen(
      initialState: _state ?? const OnboardingSetupState.initial(),
      initialAccessibilityContextMode: _accessibilityContextMode,
      initialScreenshotContextMode: _screenshotContextMode,
      initialScreenshotPermissionStatus: _screenshotPermissionStatus,
      onStateChanged: (state) => unawaited(_saveState(state)),
      onCompleted: () => unawaited(_complete()),
      checkAccessibility: _shortcutService.checkAccessibilityPermissions,
      requestAccessibility: _shortcutService.requestAccessibilityPermission,
      onScreenshotContextSelected: _chooseScreenshotContextMode,
      recheckScreenshotContext: _recheckScreenshotContextMode,
      openScreenRecordingSettings: _openScreenRecordingSettings,
      onAccessibilityContextSelected: _chooseAccessibilityContextMode,
    );
  }
}
