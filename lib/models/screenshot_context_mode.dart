/// Controls whether visual context is sent with shortcut rewrites.
enum ScreenshotContextMode {
  /// Do not capture or send screenshots.
  off('off'),

  /// Capture the active app/window when possible.
  activeApplication('activeApplication'),

  /// Capture the active display.
  fullScreen('fullScreen');

  /// Creates a screenshot context mode.
  const ScreenshotContextMode(this.value);

  /// Persisted and native method-channel value.
  final String value;

  /// Parses a persisted value, falling back to [off].
  static ScreenshotContextMode fromValue(String? value) {
    for (final mode in values) {
      if (mode.value == value) return mode;
    }
    return off;
  }
}
