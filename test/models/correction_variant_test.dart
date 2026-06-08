import 'package:flutter_test/flutter_test.dart';
import 'package:make_it_sound_natural/models/correction_variant.dart';

void main() {
  group('CorrectionVariantKind', () {
    test('parses known labels case-insensitively', () {
      expect(
        CorrectionVariantKind.tryParseLabel(' balanced '),
        CorrectionVariantKind.balanced,
      );
      expect(
        CorrectionVariantKind.tryParseLabel('CASUAL'),
        CorrectionVariantKind.casual,
      );
    });

    test('returns null for unknown labels', () {
      expect(CorrectionVariantKind.tryParseLabel('Custom'), isNull);
    });
  });

  group('CorrectionVariant', () {
    test('infers kind from known label', () {
      final variant = CorrectionVariant(
        label: 'Formal',
        icon: '*',
        text: 'Text',
      );

      expect(variant.kind, CorrectionVariantKind.formal);
    });

    test('withKind fills stable label and legacy icon', () {
      final variant = CorrectionVariant.withKind(
        variantKind: CorrectionVariantKind.concise,
        text: 'Short.',
      );

      expect(variant.label, 'Concise');
      expect(variant.icon, '✏️');
      expect(variant.kind, CorrectionVariantKind.concise);
      expect(variant.text, 'Short.');
    });
  });
}
