import 'package:make_it_sound_natural/l10n/gen/app_localizations.dart';
import 'package:make_it_sound_natural/models/correction_variant.dart';

/// Localized labels for built-in correction variants.
extension CorrectionVariantLocalizations on AppLocalizations {
  /// Returns the localized display label for a known variant kind.
  String correctionVariantLabel(CorrectionVariantKind kind) {
    return switch (kind) {
      CorrectionVariantKind.balanced => balanced,
      CorrectionVariantKind.casual => casual,
      CorrectionVariantKind.formal => formal,
      CorrectionVariantKind.concise => concise,
    };
  }

  /// Returns a localized label when possible, otherwise the variant fallback.
  String correctionVariantDisplayLabel(CorrectionVariant variant) {
    final kind = variant.kind;
    if (kind == null) return variant.label;
    return correctionVariantLabel(kind);
  }
}
