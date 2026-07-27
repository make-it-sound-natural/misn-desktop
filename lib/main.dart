import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:logging/logging.dart';
import 'package:macos_window_utils/macos_window_utils.dart';
import 'package:make_it_sound_natural/constants/app_metadata.dart';
import 'package:make_it_sound_natural/l10n/gen/app_localizations.dart';
import 'package:make_it_sound_natural/screens/onboarding/onboarding_gate.dart';
import 'package:make_it_sound_natural/services/appearance_controller.dart';
import 'package:make_it_sound_natural/services/settings_service.dart';
import 'package:make_it_sound_natural/services/shortcut_service.dart';
import 'package:make_it_sound_natural/theme/app_theme.dart';
import 'package:make_it_sound_natural/utils/logger.dart';

final Logger _log = getLogger('main');

/// Application entry point.
///
/// Initializes logging, migrates settings, configures macOS window styling,
/// and sets up the shortcut service before launching the app.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize logging
  setupLogging();

  // Migrate settings schema if needed
  final settingsService = SettingsService();
  await settingsService.migrateIfNeeded();

  // Initialize macOS window styling for translucency
  if (Platform.isMacOS) {
    await WindowManipulator.initialize();
    await WindowManipulator.hideTitle();
    await WindowManipulator.makeTitlebarTransparent();
    await WindowManipulator.enableFullSizeContentView();
    await WindowManipulator.addVisualEffectSubview(
      VisualEffectSubviewProperties(
        material: NSVisualEffectViewMaterial.underWindowBackground,
        state: NSVisualEffectViewState.followsWindowActiveState,
      ),
    );
  }

  // Initialize shortcut service and load saved settings
  final shortcutService = ShortcutService();
  await shortcutService.initialize();

  // Load and sync settings; may fail during startup race with native layer
  try {
    await shortcutService.loadAndSyncSettings();
  } on Exception catch (e) {
    _log.warning('Failed to sync settings on startup: $e');
  }

  runApp(const MyApp());
}

/// Root application widget.
class MyApp extends StatefulWidget {
  /// Creates the root application widget.
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final AppearanceController _appearanceController;

  @override
  void initState() {
    super.initState();
    _appearanceController = AppearanceController();
    unawaited(_appearanceController.load());
  }

  @override
  void dispose() {
    _appearanceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _appearanceController,
      builder: (context, _) {
        final preferences = _appearanceController.preferences;
        return AppearanceScope(
          controller: _appearanceController,
          child: MaterialApp(
            title: AppMetadata.title,
            debugShowCheckedModeBanner: false,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            theme: AppTheme.light(
              menuFontSize: preferences.menuFontSize,
            ),
            darkTheme: AppTheme.dark(
              menuFontSize: preferences.menuFontSize,
            ),
            themeMode: _appearanceController.themeMode,
            home: const OnboardingGate(),
          ),
        );
      },
    );
  }
}
