/// Screen Recording permission state returned by the native macOS layer.
enum ScreenRecordingPermissionStatus {
  /// Screen Recording is granted.
  granted('granted'),

  /// macOS may be showing its own permission prompt.
  promptMayBeVisible('promptMayBeVisible'),

  /// The user must grant Screen Recording manually in System Settings.
  manualGrantRequired('manualGrantRequired'),

  /// The current macOS version does not support screenshot context.
  unsupported('unsupported');

  /// Creates a screen recording permission status.
  const ScreenRecordingPermissionStatus(this.value);

  /// Native method-channel value.
  final String value;

  /// Parses a native value, falling back to manual grant required.
  static ScreenRecordingPermissionStatus fromValue(String? value) {
    for (final status in values) {
      if (status.value == value) return status;
    }
    return manualGrantRequired;
  }
}
