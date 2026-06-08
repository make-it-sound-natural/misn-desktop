import 'dart:async';

import 'package:flutter/services.dart';
import 'package:logging/logging.dart';
import 'package:make_it_sound_natural/constants/method_channel_methods.dart';
import 'package:make_it_sound_natural/constants/shortcut_status.dart';
import 'package:make_it_sound_natural/models/screen_recording_permission_status.dart';
import 'package:make_it_sound_natural/models/screenshot_context_mode.dart';
import 'package:make_it_sound_natural/models/target_profile.dart';
import 'package:make_it_sound_natural/services/settings_service.dart';
import 'package:make_it_sound_natural/services/speed_tracking_service.dart';
import 'package:make_it_sound_natural/services/target_profile_service.dart';
import 'package:make_it_sound_natural/utils/logger.dart';

/// Service for managing global keyboard shortcuts and Flutter-Swift
/// communication.
class ShortcutService {
  /// Returns the singleton instance of ShortcutService.
  factory ShortcutService() => _instance;

  ShortcutService._internal() {
    _channel.setMethodCallHandler(_handleMethodCall);
  }
  final Logger _log = getLogger('ShortcutService');
  static const MethodChannel _channel = MethodChannel(
    MethodChannelMethods.channelName,
  );

  final _statusController = StreamController<ShortcutStatus>.broadcast();

  /// Stream of shortcut status changes.
  Stream<ShortcutStatus> get statusStream => _statusController.stream;

  final _textCapturedController = StreamController<String>.broadcast();

  /// Stream of captured text from the active application.
  Stream<String> get textCapturedStream => _textCapturedController.stream;

  final _variantsGeneratedController = StreamController<String>.broadcast();

  /// Stream of generated variant content from the LLM.
  Stream<String> get variantsGeneratedStream =>
      _variantsGeneratedController.stream;

  String? _lastVariants;

  /// The last generated variants content, cached for UI restoration.
  String? get lastVariants => _lastVariants;

  String? _lastCapturedText;

  /// The last captured text, cached for UI restoration.
  String? get lastCapturedText => _lastCapturedText;

  final _errorController = StreamController<String>.broadcast();

  /// Stream of error messages from shortcut operations.
  Stream<String> get errorStream => _errorController.stream;

  final _notEditableController = StreamController<String>.broadcast();

  /// Stream of messages when text cannot be edited.
  Stream<String> get notEditableStream => _notEditableController.stream;

  final _openSettingsController = StreamController<void>.broadcast();

  /// Stream that emits when settings should be opened.
  Stream<void> get openSettingsStream => _openSettingsController.stream;

  // Singleton instance
  static final ShortcutService _instance = ShortcutService._internal();

  /// Initializes the shortcut service and registers global shortcuts.
  Future<void> initialize() async {
    try {
      await _channel.invokeMethod(MethodChannelMethods.registerShortcut);
    } on PlatformException catch (e) {
      _log.warning('Failed to register shortcut: ${e.message}');
      _errorController.add('Failed to register shortcut: ${e.message}');
    } on MissingPluginException catch (e) {
      _log.warning('Shortcut channel not available: $e');
    }
  }

  /// Loads settings from storage and syncs them to the native layer.
  Future<void> loadAndSyncSettings() async {
    final settings = SettingsService();

    // Load and sync provider
    final provider = await settings.getProvider();
    await setProvider(provider);

    // Load and sync API key
    final apiKey = await settings.getApiKey();
    if (apiKey.isNotEmpty) {
      await setApiKey(apiKey);
    }

    // Load and sync OpenRouter API key
    final openRouterApiKey = await settings.getOpenRouterApiKey();
    if (openRouterApiKey.isNotEmpty) {
      await setOpenRouterApiKey(openRouterApiKey);
    }

    // Load and sync context
    final context = await settings.getContext();
    if (context.isNotEmpty) {
      await setContext(context);
    }

    // Load and sync model
    final model = await settings.getModel();
    await setModel(model);

    // Load and sync shortcut
    final shortcut = await settings.getShortcut();
    if (shortcut.isNotEmpty) {
      await updateShortcut(shortcut);
    }

    // Load and sync replace shortcut
    final replaceShortcut = await settings.getReplaceShortcut();
    if (replaceShortcut.isNotEmpty) {
      await updateReplaceShortcut(replaceShortcut);
    }

    // Load and sync append shortcut
    final appendShortcut = await settings.getAppendShortcut();
    if (appendShortcut.isNotEmpty) {
      await updateAppendShortcut(appendShortcut);
    }

    // Load and sync default variant
    final defaultVariant = await settings.getDefaultVariant();
    await setDefaultVariant(defaultVariant);

    // Load, restore, and sync screenshot context mode.
    final screenshotContextMode = await _restoreScreenshotContextMode(settings);
    await setScreenshotContextMode(screenshotContextMode);

    // Load and sync custom prompt
    final customPrompt = await settings.getCustomPrompt();
    if (customPrompt.isNotEmpty) {
      await setCustomPrompt(customPrompt);
    }

    final targetProfileService = TargetProfileService();
    final selectionRequired = await targetProfileService.isSelectionRequired();
    final selectedProfile = await targetProfileService.getSelectedProfile();
    final fallbackProfile = selectionRequired || selectedProfile != null
        ? null
        : await targetProfileService.getProfileById(
            TargetProfileService.defaultProfileId,
          );
    await setTargetProfile(
      selectedProfile ?? fallbackProfile,
      selectionRequired: selectionRequired,
    );
  }

  Future<ScreenshotContextMode> _restoreScreenshotContextMode(
    SettingsService settings,
  ) async {
    final activeMode = await settings.getScreenshotContextMode();
    final pendingMode = await settings.getPendingScreenshotContextMode();

    if (activeMode != ScreenshotContextMode.off) {
      final status = await checkScreenRecordingPermission(activeMode);
      if (status == ScreenRecordingPermissionStatus.granted) {
        await settings.clearPendingScreenshotContextMode();
        return activeMode;
      }
      await settings.setPendingScreenshotContextMode(activeMode);
      await settings.setScreenshotContextMode(ScreenshotContextMode.off);
      return ScreenshotContextMode.off;
    }

    if (pendingMode == null) return activeMode;

    final status = await checkScreenRecordingPermission(pendingMode);
    if (status == ScreenRecordingPermissionStatus.granted) {
      await settings.setScreenshotContextMode(pendingMode);
      await settings.clearPendingScreenshotContextMode();
      return pendingMode;
    }
    if (status == ScreenRecordingPermissionStatus.unsupported) {
      await settings.clearPendingScreenshotContextMode();
    }
    return ScreenshotContextMode.off;
  }

  /// Checks if accessibility permissions are granted.
  Future<bool> checkAccessibilityPermissions() async {
    try {
      final isTrusted = await _channel.invokeMethod<bool>(
        MethodChannelMethods.checkAccessibilityPermissions,
      );
      return isTrusted ?? false;
    } on PlatformException catch (e) {
      _log.warning('Failed to check permissions: ${e.message}');
      return false;
    } on MissingPluginException catch (e) {
      _log.warning('Accessibility permission channel unavailable: $e');
      return false;
    }
  }

  /// Requests Accessibility permission through the native prompt or settings.
  Future<bool> requestAccessibilityPermission() async {
    try {
      final isTrusted = await _channel.invokeMethod<bool>(
        MethodChannelMethods.requestAccessibilityPermission,
      );
      return isTrusted ?? false;
    } on PlatformException catch (e) {
      _log.warning('Failed to request Accessibility permission: ${e.message}');
      return false;
    } on MissingPluginException catch (e) {
      _log.warning('Accessibility permission channel unavailable: $e');
      return false;
    }
  }

  /// Replaces text in the original application at the cursor position.
  Future<void> replaceTextInOriginalApp(String text) async {
    try {
      await _channel.invokeMethod(
        MethodChannelMethods.replaceTextInOriginalApp,
        text,
      );
    } on PlatformException catch (e) {
      _log.warning('Failed to replace text: ${e.message}');
    }
  }

  /// Generates variants using the native background service.
  ///
  /// Returns the raw content string (which contains the marked variants).
  Future<String> generateVariants(String text) async {
    try {
      final result = await _channel.invokeMethod<String>(
        MethodChannelMethods.generateVariants,
        text,
      );
      await SettingsService().clearAuthFailureForActiveProvider();
      return result ?? '';
    } on PlatformException catch (e) {
      _log.warning('Failed to generate variants: ${e.message}');
      final message = e.message ?? 'Request failed. Try again.';
      _errorController.add(message);
      throw PlatformException(
        code: e.code,
        message: message,
        details: e.details,
      );
    }
  }

  /// Sets the OpenAI API key in the native layer.
  Future<void> setApiKey(String apiKey) async {
    try {
      await _channel.invokeMethod(MethodChannelMethods.setApiKey, apiKey);
    } on PlatformException catch (e) {
      _log.warning('Failed to set API key: ${e.message}');
    }
  }

  /// Sets the API provider in the native layer.
  Future<void> setProvider(String provider) async {
    try {
      _log.info('Sending setProvider to native: $provider');
      await _channel.invokeMethod(MethodChannelMethods.setProvider, provider);
    } on PlatformException catch (e) {
      _log.warning('Failed to set provider: ${e.message}');
    }
  }

  /// Sets the OpenRouter API key in the native layer.
  Future<void> setOpenRouterApiKey(String apiKey) async {
    try {
      await _channel.invokeMethod(
        MethodChannelMethods.setOpenRouterApiKey,
        apiKey,
      );
    } on PlatformException catch (e) {
      _log.warning('Failed to set OpenRouter API key: ${e.message}');
    }
  }

  /// Sets the user context in the native layer.
  Future<void> setContext(String context) async {
    try {
      await _channel.invokeMethod(MethodChannelMethods.setContext, context);
    } on PlatformException catch (e) {
      _log.warning('Failed to set context: ${e.message}');
    }
  }

  /// Sets the LLM model in the native layer.
  Future<void> setModel(String model) async {
    try {
      _log.info('Sending setModel to native: $model');
      await _channel.invokeMethod(MethodChannelMethods.setModel, model);
    } on PlatformException catch (e) {
      _log.warning('Failed to set model: ${e.message}');
    }
  }

  /// Sets the default variant in the native layer.
  Future<void> setDefaultVariant(String variant) async {
    try {
      _log.info('Sending setDefaultVariant to native: $variant');
      await _channel.invokeMethod(
        MethodChannelMethods.setDefaultVariant,
        variant,
      );
    } on PlatformException catch (e) {
      _log.warning('Failed to set default variant: ${e.message}');
    }
  }

  /// Sets screenshot context mode in the native layer.
  Future<void> setScreenshotContextMode(ScreenshotContextMode mode) async {
    try {
      _log.info('Sending setScreenshotContextMode to native: ${mode.value}');
      await _channel.invokeMethod(
        MethodChannelMethods.setScreenshotContextMode,
        mode.value,
      );
    } on PlatformException catch (e) {
      _log.warning('Failed to set screenshot context mode: ${e.message}');
    }
  }

  /// Checks Screen Recording permission without showing a prompt.
  Future<ScreenRecordingPermissionStatus> checkScreenRecordingPermission(
    ScreenshotContextMode mode,
  ) async {
    if (mode == ScreenshotContextMode.off) {
      return ScreenRecordingPermissionStatus.granted;
    }

    try {
      final response = await _channel.invokeMapMethod<String, String>(
        MethodChannelMethods.checkScreenRecordingPermission,
        mode.value,
      );
      return ScreenRecordingPermissionStatus.fromValue(response?['status']);
    } on PlatformException catch (e) {
      _log.warning('Failed to check Screen Recording permission: ${e.message}');
      return ScreenRecordingPermissionStatus.manualGrantRequired;
    } on MissingPluginException catch (e) {
      _log.warning('Screen Recording permission check unavailable: $e');
      return ScreenRecordingPermissionStatus.manualGrantRequired;
    }
  }

  /// Requests Screen Recording permission for screenshot context.
  Future<ScreenRecordingPermissionStatus> requestScreenRecordingPermission(
    ScreenshotContextMode mode,
  ) async {
    if (mode == ScreenshotContextMode.off) {
      return ScreenRecordingPermissionStatus.granted;
    }

    try {
      _log.info('Requesting Screen Recording permission: ${mode.value}');
      final response = await _channel.invokeMapMethod<String, String>(
        MethodChannelMethods.requestScreenRecordingPermission,
        mode.value,
      );
      return ScreenRecordingPermissionStatus.fromValue(response?['status']);
    } on PlatformException catch (e) {
      _log.warning(
        'Failed to request Screen Recording permission: ${e.message}',
      );
      return ScreenRecordingPermissionStatus.manualGrantRequired;
    } on MissingPluginException catch (e) {
      _log.warning('Screen Recording permission channel unavailable: $e');
      return ScreenRecordingPermissionStatus.manualGrantRequired;
    }
  }

  /// Shows the native Screen Recording permission helper.
  Future<bool> presentScreenRecordingPermissionGuide({
    required String title,
    required String message,
    required String dragInstruction,
    required String openSettings,
    required String revealInFinder,
    required String checkAgain,
    required String cancel,
    required String stillMissing,
    required String debugHint,
    bool manualAddRequired = true,
    bool openSettingsOnAppear = false,
  }) async {
    try {
      final isGranted = await _channel.invokeMethod<bool>(
        MethodChannelMethods.presentScreenRecordingPermissionGuide,
        {
          'title': title,
          'message': message,
          'dragInstruction': dragInstruction,
          'openSettings': openSettings,
          'revealInFinder': revealInFinder,
          'checkAgain': checkAgain,
          'cancel': cancel,
          'stillMissing': stillMissing,
          'debugHint': debugHint,
          'manualAddRequired': manualAddRequired,
          'openSettingsOnAppear': openSettingsOnAppear,
        },
      );
      return isGranted ?? false;
    } on PlatformException catch (e) {
      _log.warning(
        'Failed to present Screen Recording permission guide: ${e.message}',
      );
      return false;
    } on MissingPluginException catch (e) {
      _log.warning('Screen Recording permission guide unavailable: $e');
      return false;
    }
  }

  /// Sets the custom prompt template in the native layer.
  Future<void> setCustomPrompt(String prompt) async {
    try {
      _log.info('Sending setCustomPrompt to native (length: ${prompt.length})');
      await _channel.invokeMethod(MethodChannelMethods.setCustomPrompt, prompt);
    } on PlatformException catch (e) {
      _log.warning('Failed to set custom prompt: ${e.message}');
    }
  }

  /// Sets the active target profile in the native layer.
  Future<void> setTargetProfile(
    TargetProfile? profile, {
    required bool selectionRequired,
  }) async {
    try {
      final profileLabel = profile == null
          ? 'none'
          : '${profile.name} (${profile.id})';
      _log.info(
        'Sending setTargetProfile to native: $profileLabel, '
        'selectionRequired=$selectionRequired',
      );
      await _channel.invokeMethod(MethodChannelMethods.setTargetProfile, {
        'id': profile?.id,
        'name': profile?.name,
        'instruction': profile?.instruction,
        'selectionRequired': selectionRequired,
      });
    } on PlatformException catch (e) {
      _log.warning('Failed to set target profile: ${e.message}');
    }
  }

  /// Gets the default prompt template from the native layer.
  Future<String> getDefaultPrompt() async {
    try {
      final result = await _channel.invokeMethod<String>(
        MethodChannelMethods.getDefaultPrompt,
      );
      return result ?? '';
    } on PlatformException catch (e) {
      _log.warning('Failed to get default prompt: ${e.message}');
      return '';
    }
  }

  /// Temporarily disables global shortcuts (e.g., during shortcut recording).
  Future<void> disableShortcuts() async {
    try {
      _log.info('Sending disableShortcuts to native');
      await _channel.invokeMethod(MethodChannelMethods.disableShortcuts);
    } on PlatformException catch (e) {
      _log.warning('Failed to disable shortcuts: ${e.message}');
    }
  }

  /// Re-enables global shortcuts.
  Future<void> enableShortcuts() async {
    try {
      _log.info('Sending enableShortcuts to native');
      await _channel.invokeMethod(MethodChannelMethods.enableShortcuts);
    } on PlatformException catch (e) {
      _log.warning('Failed to enable shortcuts: ${e.message}');
    }
  }

  /// Updates the correction shortcut.
  Future<void> updateShortcut(String shortcut) async {
    try {
      _log.info('Sending updateShortcut to native: $shortcut');
      await _channel.invokeMethod(
        MethodChannelMethods.updateShortcut,
        shortcut,
      );
    } on PlatformException catch (e) {
      _log.warning('Failed to update shortcut: ${e.message}');
      _errorController.add('Failed to update shortcut: ${e.message}');
    }
  }

  /// Updates the replace context shortcut.
  Future<void> updateReplaceShortcut(String shortcut) async {
    try {
      _log.info('Sending updateReplaceShortcut to native: $shortcut');
      await _channel.invokeMethod(
        MethodChannelMethods.updateReplaceShortcut,
        shortcut,
      );
    } on PlatformException catch (e) {
      _log.warning('Failed to update replace shortcut: ${e.message}');
    }
  }

  /// Updates the append context shortcut.
  Future<void> updateAppendShortcut(String shortcut) async {
    try {
      _log.info('Sending updateAppendShortcut to native: $shortcut');
      await _channel.invokeMethod(
        MethodChannelMethods.updateAppendShortcut,
        shortcut,
      );
    } on PlatformException catch (e) {
      _log.warning('Failed to update append shortcut: ${e.message}');
    }
  }

  /// Validates a shortcut for system conflicts.
  ///
  /// Returns a map with 'isValid' (bool) and optional 'conflictName' (String).
  Future<Map<String, dynamic>> validateShortcut(String shortcut) async {
    try {
      _log.info('Sending validateShortcut with "$shortcut"');
      final result = await _channel.invokeMethod(
        MethodChannelMethods.validateShortcut,
        shortcut,
      );
      _log.info('Received validation result: $result');
      if (result is Map) {
        return Map<String, dynamic>.from(result);
      }
      return {'isValid': false, 'conflictName': 'Unknown error'};
    } on PlatformException catch (e) {
      _log.warning('Failed to validate shortcut: ${e.message}');
      return {'isValid': false, 'conflictName': e.message};
    }
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case MethodChannelMethods.storeContext:
        if (call.arguments is Map) {
          final args = call.arguments as Map;
          final text = args['text'] as String;
          final replace = args['replace'] as bool;
          await _handleStoreContext(text, replace);
        }
      case MethodChannelMethods.onStatusChanged:
        if (call.arguments is String) {
          final status = ShortcutStatus.fromString(call.arguments as String);
          if (status != null) {
            _statusController.add(status);
          }
        }
      case MethodChannelMethods.onTextCaptured:
        if (call.arguments is String) {
          _lastCapturedText = call.arguments as String;
          _textCapturedController.add(_lastCapturedText!);
        }
      case MethodChannelMethods.onVariantsGenerated:
        if (call.arguments is String) {
          _lastVariants = call.arguments as String;
          _variantsGeneratedController.add(_lastVariants!);
        }
      case MethodChannelMethods.onSuccess:
        await SettingsService().clearAuthFailureForActiveProvider();
        _statusController.add(ShortcutStatus.success);
      case MethodChannelMethods.onError:
        if (call.arguments is String) {
          _errorController.add(call.arguments as String);
          _statusController.add(ShortcutStatus.error);
        }
      case MethodChannelMethods.onProviderAuthFailure:
        if (call.arguments is Map) {
          final args = call.arguments as Map;
          final provider = args['provider'] as String?;
          final message = args['message'] as String?;
          if (provider != null && message != null) {
            await SettingsService().recordProviderAuthFailure(
              provider: provider,
              message: message,
            );
            _errorController.add(message);
            _statusController.add(ShortcutStatus.error);
          }
        }
      case MethodChannelMethods.onNotEditable:
        if (call.arguments is String) {
          _notEditableController.add(call.arguments as String);
          _statusController.add(ShortcutStatus.notEditable);
        }
      case MethodChannelMethods.openSettings:
        _log.info('Received openSettings from native!');
        _openSettingsController.add(null);
      case MethodChannelMethods.onTimingData:
        if (call.arguments is Map) {
          final args = call.arguments as Map;
          final model = args['model'] as String?;
          final seconds = args['seconds'] as double?;
          _log.info('Received timing data - model: $model, seconds: $seconds');
          if (model != null && seconds != null) {
            await SpeedTrackingService().recordTime(model, seconds);
            _log.info('Recorded timing for $model');
          }
        }
      default:
        _log.warning('Unknown method ${call.method}');
    }
  }

  Future<void> _handleStoreContext(String text, bool replace) async {
    final settings = SettingsService();
    if (replace) {
      await settings.setContext(text);
      await setContext(text);
      _statusController.add(ShortcutStatus.contextReplaced);
    } else {
      final old = await settings.getContext();
      final newContext = old.isEmpty ? text : '$old\n\n---\n\n$text';
      await settings.setContext(newContext);
      await setContext(newContext);
      _statusController.add(ShortcutStatus.contextAppended);
    }
  }

  /// Brings the app window to foreground.
  Future<void> bringToForeground() async {
    _log.info('Requesting bringToForeground');
    try {
      await _channel.invokeMethod(MethodChannelMethods.bringToForeground);
    } on Exception catch (e) {
      _log.warning('bringToForeground error: $e');
    }
  }

  /// Disposes of all stream controllers and cleans up resources.
  void dispose() {
    unawaited(_statusController.close());
    unawaited(_textCapturedController.close());
    unawaited(_variantsGeneratedController.close());
    unawaited(_errorController.close());
    unawaited(_notEditableController.close());
    unawaited(_openSettingsController.close());
  }
}
