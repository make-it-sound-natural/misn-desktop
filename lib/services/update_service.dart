import 'package:flutter/services.dart';
import 'package:logging/logging.dart';
import 'package:make_it_sound_natural/utils/logger.dart';

/// State of the update check process.
enum UpdateCheckState {
  /// Ready to check for updates.
  idle,

  /// Currently checking for updates.
  checking,

  /// Check completed, app is up to date.
  upToDate,

  /// Check failed with an error.
  error,
}

/// Result of an update check operation.
class UpdateCheckResult {
  /// Creates an update check result.
  ///
  /// [success] indicates whether the update check completed successfully.
  /// [error] contains an error message if the check failed.
  const UpdateCheckResult({required this.success, this.error});

  /// Whether the update check completed successfully.
  final bool success;

  /// Error message if the update check failed, null otherwise.
  final String? error;
}

/// Release channel for the running app.
enum AppReleaseChannel {
  /// Public stable release.
  stable('Stable'),

  /// Beta prerelease.
  beta('Beta'),

  /// Nightly internal test build.
  nightly('Nightly'),

  /// Unknown or unparsable version string.
  unknown('Unknown');

  const AppReleaseChannel(this.label);

  /// User-visible English fallback label.
  final String label;

  /// Parses the native channel identifier.
  static AppReleaseChannel fromId(String? id) {
    return switch (id) {
      'stable' => AppReleaseChannel.stable,
      'beta' => AppReleaseChannel.beta,
      'nightly' => AppReleaseChannel.nightly,
      _ => AppReleaseChannel.unknown,
    };
  }
}

/// App version information.
class AppVersion {
  /// Creates app version information.
  ///
  /// [version] is the semantic version string (e.g., "1.2.3").
  /// [build] is the build number or identifier.
  const AppVersion({
    required this.version,
    required this.build,
    AppReleaseChannel? releaseChannel,
  }) : _releaseChannel = releaseChannel;

  /// The semantic version string.
  final String version;

  /// The build number or identifier.
  final String build;

  final AppReleaseChannel? _releaseChannel;

  /// Formatted display string combining version and build.
  String get displayString => '$version ($build)';

  /// Release channel reported by native code, or inferred from version suffix.
  AppReleaseChannel get releaseChannel {
    if (_releaseChannel != null &&
        _releaseChannel != AppReleaseChannel.unknown) {
      return _releaseChannel;
    }
    if (RegExp(r'^\d+\.\d+\.\d+$').hasMatch(version)) {
      return AppReleaseChannel.stable;
    }
    if (RegExp(r'^\d+\.\d+\.\d+-beta\.\d+$').hasMatch(version)) {
      return AppReleaseChannel.beta;
    }
    if (RegExp(
      r'^\d+\.\d+\.\d+-nightly\.\d{8}\.\d+$',
    ).hasMatch(version)) {
      return AppReleaseChannel.nightly;
    }
    return AppReleaseChannel.unknown;
  }

  /// English fallback channel label for diagnostics and tests.
  String get releaseChannelLabel => releaseChannel.label;

  @override
  String toString() => displayString;
}

/// Cached Updates settings used to render the UI without guessed values.
class UpdateSettingsSnapshot {
  /// Creates a snapshot of update-related settings.
  const UpdateSettingsSnapshot({
    required this.appVersion,
    required this.automaticUpdateChecks,
    required this.lastUpdateCheck,
  });

  /// Current app version.
  final AppVersion appVersion;

  /// Date of the last update check, if any.
  final DateTime? lastUpdateCheck;

  /// Whether Sparkle checks for updates automatically.
  final bool automaticUpdateChecks;

  /// Returns a copy with selected fields replaced.
  UpdateSettingsSnapshot copyWith({
    AppVersion? appVersion,
    DateTime? lastUpdateCheck,
    bool? automaticUpdateChecks,
  }) {
    return UpdateSettingsSnapshot(
      appVersion: appVersion ?? this.appVersion,
      lastUpdateCheck: lastUpdateCheck ?? this.lastUpdateCheck,
      automaticUpdateChecks:
          automaticUpdateChecks ?? this.automaticUpdateChecks,
    );
  }
}

/// Service for managing app updates via Sparkle.
///
/// Provides methods to:
/// - Check for updates manually
/// - Get/set automatic update check preference
/// - Get app version and last update check time
class UpdateService {
  /// Returns the singleton instance of UpdateService.
  factory UpdateService() => _instance;

  UpdateService._internal()
    : _channel = const MethodChannel('com.makeitsoundnatural/shortcut');

  /// Constructor for testing with a mock channel.
  UpdateService.withChannel(this._channel);
  final Logger _log = getLogger('UpdateService');
  final MethodChannel _channel;
  UpdateSettingsSnapshot? _settingsSnapshot;
  Future<UpdateSettingsSnapshot>? _settingsSnapshotFuture;

  // Singleton instance
  static final UpdateService _instance = UpdateService._internal();

  /// Returns the cached settings snapshot if it has already loaded.
  UpdateSettingsSnapshot? get cachedSettingsSnapshot => _settingsSnapshot;

  /// Starts loading update settings so later UI can render without flicker.
  Future<void> preloadSettingsSnapshot() async {
    await loadSettingsSnapshot();
  }

  /// Loads and caches the update settings snapshot.
  Future<UpdateSettingsSnapshot> loadSettingsSnapshot() {
    final cached = _settingsSnapshot;
    if (cached != null) {
      return Future.value(cached);
    }

    final loading = _settingsSnapshotFuture;
    if (loading != null) {
      return loading;
    }

    final future = _loadSettingsSnapshot();
    _settingsSnapshotFuture = future;
    return future;
  }

  Future<UpdateSettingsSnapshot> _loadSettingsSnapshot() async {
    final appVersion = await getAppVersion();
    final lastUpdateCheck = await getLastUpdateCheck();
    final automaticUpdateChecks = await getAutomaticUpdateChecks();
    final snapshot = UpdateSettingsSnapshot(
      appVersion: appVersion,
      lastUpdateCheck: lastUpdateCheck,
      automaticUpdateChecks: automaticUpdateChecks,
    );
    _settingsSnapshot = snapshot;
    _settingsSnapshotFuture = null;
    return snapshot;
  }

  /// Clears cached update settings. Intended for tests.
  void debugResetSettingsSnapshot() {
    _settingsSnapshot = null;
    _settingsSnapshotFuture = null;
  }

  /// Check for updates manually.
  ///
  /// Returns [UpdateCheckResult] with success status and optional
  /// error message.
  Future<UpdateCheckResult> checkForUpdates() async {
    try {
      _log.info('Checking for updates...');
      final result = await _channel.invokeMethod<Map<Object?, Object?>>(
        'checkForUpdates',
      );

      if (result == null) {
        return const UpdateCheckResult(
          success: false,
          error: 'No response from updater',
        );
      }

      final success = result['success'] as bool? ?? false;
      final error = result['error'] as String?;

      _log.info('Update check result: success=$success, error=$error');
      return UpdateCheckResult(success: success, error: error);
    } on PlatformException catch (e) {
      _log.warning('Failed to check for updates: ${e.message}');
      return UpdateCheckResult(success: false, error: e.message);
    }
  }

  /// Get the current app version.
  Future<AppVersion> getAppVersion() async {
    try {
      final result = await _channel.invokeMethod<Map<Object?, Object?>>(
        'getAppVersion',
      );

      if (result == null) {
        return const AppVersion(version: 'Unknown', build: 'Unknown');
      }

      return AppVersion(
        version: result['version'] as String? ?? 'Unknown',
        build: result['build'] as String? ?? 'Unknown',
        releaseChannel: AppReleaseChannel.fromId(
          result['releaseChannel'] as String?,
        ),
      );
    } on PlatformException catch (e) {
      _log.warning('Failed to get app version: ${e.message}');
      return const AppVersion(version: 'Unknown', build: 'Unknown');
    }
  }

  /// Get the last update check date.
  ///
  /// Returns null if never checked or if the date couldn't be retrieved.
  Future<DateTime?> getLastUpdateCheck() async {
    try {
      final result = await _channel.invokeMethod<String>('getLastUpdateCheck');

      if (result == null) {
        return null;
      }

      return DateTime.tryParse(result);
    } on PlatformException catch (e) {
      _log.warning('Failed to get last update check: ${e.message}');
      return null;
    }
  }

  /// Get whether automatic update checks are enabled.
  Future<bool> getAutomaticUpdateChecks() async {
    try {
      final result = await _channel.invokeMethod<bool>(
        'getAutomaticUpdateChecks',
      );
      return result ?? false;
    } on PlatformException catch (e) {
      _log.warning(
        'Failed to get automatic update checks setting: ${e.message}',
      );
      return false;
    }
  }

  /// Set whether automatic update checks are enabled.
  Future<void> setAutomaticUpdateChecks({required bool enabled}) async {
    try {
      _log.info('Setting automatic update checks: $enabled');
      await _channel.invokeMethod('setAutomaticUpdateChecks', enabled);
      _settingsSnapshot = _settingsSnapshot?.copyWith(
        automaticUpdateChecks: enabled,
      );
    } on PlatformException catch (e) {
      _log.warning('Failed to set automatic update checks: ${e.message}');
    }
  }
}
