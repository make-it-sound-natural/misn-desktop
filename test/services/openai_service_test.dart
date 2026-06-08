import 'package:flutter_test/flutter_test.dart';
import 'package:make_it_sound_natural/models/correction_variant.dart';
import 'package:make_it_sound_natural/services/openai_service.dart';

void main() {
  late OpenAIService service;

  setUp(() {
    service = OpenAIService();
  });

  group('parseVariants', () {
    test('parses all four markers correctly', () {
      const content =
          '---BALANCED---\n'
          'This is balanced text.\n'
          '---CASUAL---\n'
          'Hey, casual text here!\n'
          '---FORMAL---\n'
          'Please find the formal text enclosed.\n'
          '---CONCISE---\n'
          'Short.';

      final variants = service.parseVariants(content);

      expect(variants.length, 4);
      expect(variants[0].label, 'Balanced');
      expect(variants[0].icon, '✨');
      expect(variants[0].kind, CorrectionVariantKind.balanced);
      expect(variants[0].text, 'This is balanced text.');
      expect(variants[1].label, 'Casual');
      expect(variants[1].icon, '💬');
      expect(variants[1].kind, CorrectionVariantKind.casual);
      expect(variants[1].text, 'Hey, casual text here!');
      expect(variants[2].label, 'Formal');
      expect(variants[2].icon, '📧');
      expect(variants[2].kind, CorrectionVariantKind.formal);
      expect(variants[2].text, 'Please find the formal text enclosed.');
      expect(variants[3].label, 'Concise');
      expect(variants[3].icon, '✏️');
      expect(variants[3].kind, CorrectionVariantKind.concise);
      expect(variants[3].text, 'Short.');
    });

    test('handles multiline variant text', () {
      const content =
          '---BALANCED---\n'
          'Line one.\n'
          'Line two.\n'
          '---CASUAL---\n'
          'Casual line.\n'
          '---FORMAL---\n'
          'Formal line.\n'
          '---CONCISE---\n'
          'Done.';

      final variants = service.parseVariants(content);

      expect(variants[0].text, 'Line one.\nLine two.');
      expect(variants.length, 4);
    });

    test('handles missing markers gracefully - partial set', () {
      // When intermediate markers (CASUAL, FORMAL) are absent,
      // BALANCED extends to CONCISE since it looks for CASUAL then
      // FORMAL as next boundary. CONCISE always reads to end.
      const content =
          '---BALANCED---\n'
          'Only balanced.\n'
          '---CONCISE---\n'
          'Only concise.';

      final variants = service.parseVariants(content);

      // BALANCED captures everything up to content.length (no next marker)
      // CONCISE captures from its marker to end
      expect(variants.length, 2);
      expect(variants[0].label, 'Balanced');
      expect(variants[1].label, 'Concise');
      expect(variants[1].text, 'Only concise.');
    });

    test('returns fallback when no markers found', () {
      const content = 'Just plain text without any markers.';

      final variants = service.parseVariants(content);

      expect(variants.length, 4);
      expect(variants[0].label, 'Balanced');
      expect(variants[0].text, content);
      expect(variants[1].label, 'Casual');
      expect(variants[1].text, content);
      expect(variants[2].label, 'Formal');
      expect(variants[2].text, content);
      expect(variants[3].label, 'Concise');
      expect(variants[3].text, content);
    });

    test('trims whitespace around variant text', () {
      const content =
          '---BALANCED---\n'
          '  trimmed  \n'
          '---CASUAL---\n'
          '\n  also trimmed  \n\n'
          '---FORMAL---\n'
          'formal\n'
          '---CONCISE---\n'
          '  concise  ';

      final variants = service.parseVariants(content);

      expect(variants[0].text, 'trimmed');
      expect(variants[1].text, 'also trimmed');
      expect(variants[3].text, 'concise');
    });

    test('handles empty content between markers', () {
      const content =
          '---BALANCED---\n'
          '---CASUAL---\n'
          'Has text.\n'
          '---FORMAL---\n'
          '---CONCISE---\n'
          'Also has text.';

      final variants = service.parseVariants(content);

      // Empty balanced and formal should be skipped
      expect(variants.any((v) => v.label == 'Casual'), isTrue);
      expect(variants.any((v) => v.label == 'Concise'), isTrue);
    });

    test('handles content before first marker', () {
      const content =
          'Some preamble text\n\n'
          '---BALANCED---\n'
          'Balanced text.\n'
          '---CASUAL---\n'
          'Casual text.\n'
          '---FORMAL---\n'
          'Formal text.\n'
          '---CONCISE---\n'
          'Concise text.';

      final variants = service.parseVariants(content);

      expect(variants.length, 4);
      expect(variants[0].text, 'Balanced text.');
    });
  });
}
