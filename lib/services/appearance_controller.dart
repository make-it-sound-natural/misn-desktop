import 'package:flutter/material.dart';
import 'package:make_it_sound_natural/models/appearance_preferences.dart';
import 'package:make_it_sound_natural/services/settings_service.dart';

/// Lifecycle states for the appearance controller state machine.
enum AppearanceControllerState {
  /// Controller has not loaded persisted preferences.
  initial,

  /// Controller is loading persisted preferences.
  loading,

  /// Controller has usable preferences.
  ready,

  /// Controller is saving a user change.
  saving,

  /// Last load or save operation failed.
  failed,
}

/// App-wide controller for appearance preferences.
class AppearanceController extends ChangeNotifier {
  /// Creates an appearance controller.
  AppearanceController({SettingsService? settingsService})
    : _settingsService = settingsService ?? SettingsService();

  final SettingsService _settingsService;

  AppearancePreferences _preferences = const AppearancePreferences.defaults();
  AppearanceControllerState _state = AppearanceControllerState.initial;

  /// Current appearance preferences.
  AppearancePreferences get preferences => _preferences;

  /// Current controller state.
  AppearanceControllerState get state => _state;

  /// Current Material theme mode.
  ThemeMode get themeMode => _preferences.themeMode.materialThemeMode;

  /// Loads saved preferences.
  Future<void> load() async {
    _transition(AppearanceControllerState.loading);
    try {
      _preferences = await _settingsService.getAppearancePreferences();
      _transition(AppearanceControllerState.ready);
    } on Exception {
      _transition(AppearanceControllerState.failed);
    }
  }

  /// Sets theme mode.
  Future<void> setThemeMode(AppearanceThemeMode themeMode) {
    return _save(_preferences.copyWith(themeMode: themeMode));
  }

  /// Sets menu/UI font size.
  Future<void> setMenuFontSize(double fontSize) {
    return _save(_preferences.copyWith(menuFontSize: fontSize));
  }

  /// Sets editor/context text font size.
  Future<void> setEditorFontSize(double fontSize) {
    return _save(_preferences.copyWith(editorFontSize: fontSize));
  }

  /// Restores defaults.
  Future<void> reset() {
    return _save(const AppearancePreferences.defaults());
  }

  Future<void> _save(AppearancePreferences preferences) async {
    _preferences = preferences;
    _transition(AppearanceControllerState.saving);
    try {
      await _settingsService.setAppearancePreferences(preferences);
      _transition(AppearanceControllerState.ready);
    } on Exception {
      _transition(AppearanceControllerState.failed);
    }
  }

  void _transition(AppearanceControllerState state) {
    _state = state;
    notifyListeners();
  }
}

/// Provides appearance preferences to the widget tree.
class AppearanceScope extends InheritedNotifier<AppearanceController> {
  /// Creates an appearance scope.
  const AppearanceScope({
    required AppearanceController controller,
    required super.child,
    super.key,
  }) : super(notifier: controller);

  /// Returns the nearest appearance controller.
  static AppearanceController controllerOf(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppearanceScope>();
    assert(scope != null, 'AppearanceScope not found in widget tree');
    return scope!.notifier!;
  }

  /// Returns current appearance preferences.
  static AppearancePreferences preferencesOf(BuildContext context) {
    return controllerOf(context).preferences;
  }

  /// Returns current preferences or defaults when no scope is installed.
  static AppearancePreferences maybePreferencesOf(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppearanceScope>();
    return scope?.notifier?.preferences ??
        const AppearancePreferences.defaults();
  }
}
