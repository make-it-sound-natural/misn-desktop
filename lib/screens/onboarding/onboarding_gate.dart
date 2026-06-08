import 'dart:async';

import 'package:flutter/material.dart';
import 'package:make_it_sound_natural/models/onboarding_setup_state.dart';
import 'package:make_it_sound_natural/models/screen_recording_permission_status.dart';
import 'package:make_it_sound_natural/models/screenshot_context_mode.dart';
import 'package:make_it_sound_natural/screens/home_screen.dart';
import 'package:make_it_sound_natural/screens/onboarding/onboarding_screen.dart';
import 'package:make_it_sound_natural/services/onboarding_service.dart';
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
    if (!mounted) return;
    setState(() {
      _showOnboarding = showOnboarding;
      _state = state;
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
      await _settingsService.setScreenshotContextMode(mode);
      await _settingsService.clearPendingScreenshotContextMode();
      await _shortcutService.setScreenshotContextMode(mode);
      return ScreenRecordingPermissionStatus.granted;
    }

    await _settingsService.setPendingScreenshotContextMode(mode);
    final status = await _shortcutService.requestScreenRecordingPermission(
      mode,
    );
    final savedMode = status == ScreenRecordingPermissionStatus.granted
        ? mode
        : ScreenshotContextMode.off;
    await _settingsService.setScreenshotContextMode(savedMode);
    if (status == ScreenRecordingPermissionStatus.granted) {
      await _settingsService.clearPendingScreenshotContextMode();
    }
    await _shortcutService.setScreenshotContextMode(savedMode);
    return status;
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
      onStateChanged: (state) => unawaited(_saveState(state)),
      onCompleted: () => unawaited(_complete()),
      checkAccessibility: _shortcutService.checkAccessibilityPermissions,
      requestAccessibility: _shortcutService.requestAccessibilityPermission,
      onScreenshotContextSelected: _chooseScreenshotContextMode,
    );
  }
}
