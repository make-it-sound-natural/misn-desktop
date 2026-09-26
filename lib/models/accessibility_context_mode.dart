/// Controls how much app text is read through Accessibility and sent with
/// shortcut rewrites.
enum AccessibilityContextMode {
  /// Do not read any app text.
  off('off'),

  /// Read the text around the selection in the field being edited.
  field('field'),

  /// Also read nearby text in the window, such as the message thread above a
  /// composer.
  fieldAndNearby('fieldAndNearby');

  /// Creates an Accessibility context mode.
  const AccessibilityContextMode(this.value);

  /// Persisted and native method-channel value.
  final String value;

  /// Parses a persisted value, falling back to [off].
  static AccessibilityContextMode fromValue(String? value) {
    for (final mode in values) {
      if (mode.value == value) return mode;
    }
    return off;
  }
}
