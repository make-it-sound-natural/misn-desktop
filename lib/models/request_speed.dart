/// Requested response speed, ordered from least to most expensive.
enum RequestSpeed {
  /// Use the provider's standard processing tier.
  standard,

  /// Use the faster processing tier where supported.
  fast,

  /// Use the fastest processing tier where supported.
  ultrafast,
}
