/// One model option known by the app for an LLM provider.
class LlmModelEntry {
  /// Creates an LLM model entry.
  const LlmModelEntry({
    required this.provider,
    required this.slug,
    this.isBuiltIn = false,
    this.isHidden = false,
    this.familyId,
  });

  /// Creates an entry from persisted JSON.
  factory LlmModelEntry.fromJson(Map<String, Object?> json) {
    return LlmModelEntry(
      provider: json['provider'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      isBuiltIn: json['isBuiltIn'] as bool? ?? false,
      isHidden: json['isHidden'] as bool? ?? false,
      familyId: json['familyId'] as String?,
    );
  }

  /// Provider id, for example `openrouter`.
  final String provider;

  /// Exact provider model slug.
  final String slug;

  /// Whether the model comes from the provider's model list.
  final bool isBuiltIn;

  /// Stable catalog family, or null for a custom model.
  final String? familyId;

  /// Whether the model is hidden from normal model selection.
  final bool isHidden;

  /// Converts this entry to persisted JSON.
  Map<String, Object?> toJson() {
    return {
      'provider': provider,
      'slug': slug,
      'isBuiltIn': isBuiltIn,
      'isHidden': isHidden,
      if (familyId != null) 'familyId': familyId,
    };
  }

  /// Returns a copy with selected fields changed.
  LlmModelEntry copyWith({
    String? provider,
    String? slug,
    bool? isBuiltIn,
    bool? isHidden,
    String? familyId,
  }) {
    return LlmModelEntry(
      provider: provider ?? this.provider,
      slug: slug ?? this.slug,
      isBuiltIn: isBuiltIn ?? this.isBuiltIn,
      isHidden: isHidden ?? this.isHidden,
      familyId: familyId ?? this.familyId,
    );
  }
}
