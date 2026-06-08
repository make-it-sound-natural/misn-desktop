/// One LLM provider available in local settings.
class LlmProviderEntry {
  /// Creates provider metadata.
  const LlmProviderEntry({
    required this.id,
    required this.displayName,
    required this.baseUrl,
    this.isBuiltIn = false,
  });

  /// Creates provider metadata from persisted JSON.
  factory LlmProviderEntry.fromJson(Map<String, Object?> json) {
    return LlmProviderEntry(
      id: _stringValue(json, 'id'),
      displayName: _stringValue(json, 'displayName'),
      baseUrl: _stringValue(json, 'baseUrl'),
      isBuiltIn: _boolValue(json, 'isBuiltIn'),
    );
  }

  /// Stable app-generated provider id.
  final String id;

  /// User-visible provider name.
  final String displayName;

  /// API root or full chat completions URL.
  final String baseUrl;

  /// Whether provider is shipped by the app.
  final bool isBuiltIn;

  /// Converts this provider to persisted JSON.
  Map<String, Object?> toJson() {
    return {
      'id': id,
      'displayName': displayName,
      'baseUrl': baseUrl,
      'isBuiltIn': isBuiltIn,
    };
  }

  /// Returns a copy with selected fields changed.
  LlmProviderEntry copyWith({
    String? id,
    String? displayName,
    String? baseUrl,
    bool? isBuiltIn,
  }) {
    return LlmProviderEntry(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      baseUrl: baseUrl ?? this.baseUrl,
      isBuiltIn: isBuiltIn ?? this.isBuiltIn,
    );
  }

  static String _stringValue(Map<String, Object?> json, String key) {
    final value = json[key];
    return value is String ? value : '';
  }

  static bool _boolValue(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value is bool) {
      return value;
    }
    return false;
  }
}
