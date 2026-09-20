/// Requested reasoning budget for an LLM rewrite.
enum ReasoningEffort {
  /// Request no reasoning, where supported.
  none,

  /// Favor faster rewrites with a small reasoning budget.
  low,

  /// Use a moderate reasoning budget.
  medium,

  /// Allow more reasoning time for complex input.
  high,
}
