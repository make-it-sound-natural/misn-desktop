/// Method channel method names for Flutter-Swift communication.
///
/// These constants define the method names used in platform channel calls
/// between Flutter and native Swift code. Using constants ensures type safety
/// and enables IDE autocomplete.
abstract class MethodChannelMethods {
  MethodChannelMethods._();

  /// The name of the method channel for Flutter-Swift communication.
  static const String channelName = 'com.makeitsoundnatural/shortcut';

  // Outgoing methods (Flutter → Swift)
  /// Registers the global keyboard shortcut with the system.
  static const String registerShortcut = 'registerShortcut';

  /// Checks if accessibility permissions are granted.
  static const String checkAccessibilityPermissions =
      'checkAccessibilityPermissions';

  /// Requests Accessibility permission through the macOS prompt/path.
  static const String requestAccessibilityPermission =
      'requestAccessibilityPermission';

  /// Replaces text in the original application.
  static const String replaceTextInOriginalApp = 'replaceTextInOriginalApp';

  /// Generates text variants using the LLM service.
  static const String generateVariants = 'generateVariants';

  /// Sets the OpenAI API key.
  static const String setApiKey = 'setApiKey';

  /// Stores the OpenAI API key in macOS Keychain.
  static const String storeApiKey = 'storeApiKey';

  /// Reads the OpenAI API key from macOS Keychain.
  static const String getStoredApiKey = 'getStoredApiKey';

  /// Sets the API provider (openai or openrouter).
  static const String setProvider = 'setProvider';

  /// Sets the OpenRouter API key.
  static const String setOpenRouterApiKey = 'setOpenRouterApiKey';

  /// Stores the OpenRouter API key in macOS Keychain.
  static const String storeOpenRouterApiKey = 'storeOpenRouterApiKey';

  /// Reads the OpenRouter API key from macOS Keychain.
  static const String getStoredOpenRouterApiKey = 'getStoredOpenRouterApiKey';

  /// Sets active custom provider config in native code.
  static const String setCustomProviderConfig = 'setCustomProviderConfig';

  /// Stores a custom provider API key in macOS Keychain.
  static const String storeCustomProviderApiKey = 'storeCustomProviderApiKey';

  /// Reads a custom provider API key from macOS Keychain.
  static const String getStoredCustomProviderApiKey =
      'getStoredCustomProviderApiKey';

  /// Deletes a custom provider API key from macOS Keychain.
  static const String deleteStoredCustomProviderApiKey =
      'deleteStoredCustomProviderApiKey';

  /// Sets the user context for text generation.
  static const String setContext = 'setContext';

  /// Sets the LLM model to use.
  static const String setModel = 'setModel';

  /// Sets the default variant to apply automatically.
  static const String setDefaultVariant = 'setDefaultVariant';

  /// Sets a custom prompt template.
  static const String setCustomPrompt = 'setCustomPrompt';

  /// Sets the active target language/dialect profile.
  static const String setTargetProfile = 'setTargetProfile';

  /// Sets screenshot context capture mode for shortcut rewrites.
  static const String setScreenshotContextMode = 'setScreenshotContextMode';

  /// Checks Screen Recording permission without showing a prompt.
  static const String checkScreenRecordingPermission =
      'checkScreenRecordingPermission';

  /// Requests Screen Recording permission for screenshot context.
  static const String requestScreenRecordingPermission =
      'requestScreenRecordingPermission';

  /// Shows the native Screen Recording permission helper.
  static const String presentScreenRecordingPermissionGuide =
      'presentScreenRecordingPermissionGuide';

  /// Gets the default prompt template from native.
  static const String getDefaultPrompt = 'getDefaultPrompt';

  /// Temporarily disables global shortcuts.
  static const String disableShortcuts = 'disableShortcuts';

  /// Re-enables global shortcuts.
  static const String enableShortcuts = 'enableShortcuts';

  /// Updates the correction shortcut.
  static const String updateShortcut = 'updateShortcut';

  /// Updates the replace context shortcut.
  static const String updateReplaceShortcut = 'updateReplaceShortcut';

  /// Updates the append context shortcut.
  static const String updateAppendShortcut = 'updateAppendShortcut';

  /// Validates a shortcut for conflicts.
  static const String validateShortcut = 'validateShortcut';

  /// Brings the app window to foreground.
  static const String bringToForeground = 'bringToForeground';

  // Incoming methods (Swift → Flutter)
  /// Stores context text (replace or append mode).
  static const String storeContext = 'storeContext';

  /// Notifies Flutter of shortcut status changes.
  static const String onStatusChanged = 'onStatusChanged';

  /// Notifies Flutter when text is captured.
  static const String onTextCaptured = 'onTextCaptured';

  /// Notifies Flutter when variants are generated.
  static const String onVariantsGenerated = 'onVariantsGenerated';

  /// Notifies Flutter of a successful operation.
  static const String onSuccess = 'onSuccess';

  /// Notifies Flutter of an error.
  static const String onError = 'onError';

  /// Notifies Flutter that a provider rejected the active API key.
  static const String onProviderAuthFailure = 'onProviderAuthFailure';

  /// Notifies Flutter that text is not editable.
  static const String onNotEditable = 'onNotEditable';

  /// Requests Flutter to open settings screen.
  static const String openSettings = 'openSettings';

  /// Sends timing data for API calls.
  static const String onTimingData = 'onTimingData';
}
