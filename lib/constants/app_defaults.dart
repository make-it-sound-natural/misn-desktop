import 'package:make_it_sound_natural/models/screenshot_context_mode.dart';

/// Application default values.
///
/// Centralized constants to ensure consistency across the codebase.
class AppDefaults {
  AppDefaults._();

  /// Default keyboard shortcut for text correction (Cmd+Shift+K)
  static const String correctionShortcut = 'cmd+shift+k';

  /// Default keyboard shortcut for context replace (Cmd+Shift+J)
  static const String replaceShortcut = 'cmd+shift+j';

  /// Default keyboard shortcut for context append (Cmd+Shift+L)
  static const String appendShortcut = 'cmd+shift+l';

  /// Provider id for direct OpenAI requests.
  static const String openAiProvider = 'openai';

  /// Provider id for OpenRouter requests.
  static const String openRouterProvider = 'openrouter';

  /// Default API provider used when no provider has been saved.
  static const String apiProvider = openRouterProvider;

  /// Default LLM model used when no model has been saved.
  static const String model = 'google/gemini-3-flash-preview';

  /// Default correction variant used when no variant has been saved.
  static const String variant = 'Balanced';

  /// Default screenshot context mode used when no value has been saved.
  static const ScreenshotContextMode screenshotContextMode =
      ScreenshotContextMode.off;

  /// Version for the local appearance preferences object.
  static const int appearanceSchemaVersion = 1;

  /// SharedPreferences key for the versioned appearance preferences object.
  static const String appearancePreferencesKey = 'appearance_preferences';

  /// Default app appearance theme mode.
  static const String appearanceThemeMode = 'system';

  /// Default base font size for menus, navigation, labels, and buttons.
  static const double menuFontSize = 14;

  /// Minimum base font size for menu/UI text.
  static const double menuFontSizeMin = 12;

  /// Maximum base font size for menu/UI text.
  static const double menuFontSizeMax = 20;

  /// Step used by menu/UI font size controls.
  static const double menuFontSizeStep = 1;

  /// Default base font size for rewrite editor and context input text.
  static const double editorFontSize = 14;

  /// Minimum base font size for editor/context text.
  static const double editorFontSizeMin = 12;

  /// Maximum base font size for editor/context text.
  static const double editorFontSizeMax = 24;

  /// Step used by editor/context font size controls.
  static const double editorFontSizeStep = 1;
}
