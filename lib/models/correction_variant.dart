/// Supported rewrite variant identities.
enum CorrectionVariantKind {
  /// Balanced style variant.
  balanced('Balanced', '✨'),

  /// Casual style variant.
  casual('Casual', '💬'),

  /// Formal style variant.
  formal('Formal', '📧'),

  /// Concise style variant.
  concise('Concise', '✏️');

  const CorrectionVariantKind(this.wireValue, this.emojiIcon);

  /// Stable generated/persisted value used by the Dart and Swift parsers.
  final String wireValue;

  /// Legacy emoji used where older UI still expects an icon string.
  final String emojiIcon;

  /// Parses a persisted or generated variant value.
  static CorrectionVariantKind? tryParseLabel(String label) {
    final normalizedLabel = label.trim().toLowerCase();
    for (final kind in values) {
      if (kind.wireValue.toLowerCase() == normalizedLabel) {
        return kind;
      }
    }
    return null;
  }
}

/// A text correction variant with kind, label, icon, and corrected text.
class CorrectionVariant {
  /// Creates a correction variant.
  ///
  /// [label] is the display name (e.g., "Balanced", "Casual").
  /// [icon] is the legacy emoji icon for this variant.
  /// [text] is the corrected text content.
  CorrectionVariant({
    required this.label,
    required this.icon,
    required this.text,
    CorrectionVariantKind? kind,
  }) : kind = kind ?? CorrectionVariantKind.tryParseLabel(label);

  /// Creates a correction variant from a known variant kind.
  CorrectionVariant.withKind({
    required CorrectionVariantKind variantKind,
    required this.text,
  }) : label = variantKind.wireValue,
       icon = variantKind.emojiIcon,
       kind = variantKind;

  /// Typed identity for known built-in variants.
  final CorrectionVariantKind? kind;

  /// The display label for this variant.
  final String label;

  /// The emoji icon representing this variant.
  final String icon;

  /// The corrected text content.
  final String text;
}
