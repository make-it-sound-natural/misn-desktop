/// Status events emitted by ShortcutService.
///
/// These statuses are used to communicate state changes between the native
/// Swift code and Flutter UI via method channels.
enum ShortcutStatus {
  /// Context was replaced with new content.
  contextReplaced('context_replaced'),

  /// Context was appended with new content.
  contextAppended('context_appended'),

  /// The active window changed during processing.
  windowChanged('window_changed'),

  /// Processing completed successfully.
  success('success'),

  /// An error occurred during processing.
  error('error'),

  /// The target text field is not editable.
  notEditable('not_editable');

  const ShortcutStatus(this.value);

  /// The string value sent over method channels.
  final String value;

  /// Converts a string value to a ShortcutStatus enum.
  ///
  /// Returns null if the value doesn't match any known status.
  static ShortcutStatus? fromString(String value) {
    for (final status in ShortcutStatus.values) {
      if (status.value == value) return status;
    }
    return null;
  }
}
