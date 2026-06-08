/// Local metadata for a provider authentication failure.
class ProviderAuthFailure {
  /// Creates provider auth-failure metadata.
  const ProviderAuthFailure({
    required this.provider,
    required this.message,
    required this.occurredAt,
  });

  /// Provider id that rejected the active API key.
  final String provider;

  /// User-visible failure message.
  final String message;

  /// Time when the failure was recorded.
  final DateTime occurredAt;

  /// Converts this object to JSON.
  Map<String, Object?> toJson() => {
    'provider': provider,
    'message': message,
    'occurredAt': occurredAt.toUtc().toIso8601String(),
  };

  /// Parses auth-failure metadata from JSON.
  static ProviderAuthFailure? fromJson(Map<String, Object?> json) {
    final provider = json['provider'] as String?;
    final message = json['message'] as String?;
    final occurredAtRaw = json['occurredAt'] as String?;
    final occurredAt = occurredAtRaw == null
        ? null
        : DateTime.tryParse(occurredAtRaw);
    if (provider == null || message == null || occurredAt == null) {
      return null;
    }
    return ProviderAuthFailure(
      provider: provider,
      message: message,
      occurredAt: occurredAt,
    );
  }
}
