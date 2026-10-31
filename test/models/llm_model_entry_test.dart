import 'package:flutter_test/flutter_test.dart';
import 'package:make_it_sound_natural/models/llm_model_entry.dart';

void main() {
  group('LlmModelEntry', () {
    test('keeps familyId out of custom model JSON', () {
      const entry = LlmModelEntry(provider: 'openai', slug: 'pinned-model');
      final json = entry.toJson();

      expect(json.containsKey('familyId'), isFalse);
      final restored = LlmModelEntry.fromJson(json);
      expect(restored.familyId, isNull);
      expect(restored.toJson(), json);
    });

    test('copyWith keeps and replaces familyId', () {
      const entry = LlmModelEntry(
        provider: 'openai',
        slug: 'gpt-6-sol',
        isBuiltIn: true,
        familyId: 'sol',
      );

      expect(entry.copyWith(isHidden: true).familyId, 'sol');
      expect(entry.copyWith(familyId: 'terra').familyId, 'terra');
      expect(LlmModelEntry.fromJson(entry.toJson()).familyId, 'sol');
    });

    test('serializes custom OpenRouter model to json', () {
      const entry = LlmModelEntry(
        provider: 'openrouter',
        slug: 'anthropic/claude-sonnet-4.6',
        isHidden: true,
      );

      expect(entry.toJson(), {
        'provider': 'openrouter',
        'slug': 'anthropic/claude-sonnet-4.6',
        'isBuiltIn': false,
        'isHidden': true,
      });
    });

    test('reads missing boolean fields with safe defaults', () {
      final entry = LlmModelEntry.fromJson({
        'provider': 'openrouter',
        'slug': 'anthropic/claude-sonnet-4.6',
      });

      expect(entry.provider, 'openrouter');
      expect(entry.slug, 'anthropic/claude-sonnet-4.6');
      expect(entry.isBuiltIn, isFalse);
      expect(entry.isHidden, isFalse);
    });

    test('copyWith changes only supplied fields', () {
      const entry = LlmModelEntry(
        provider: 'openrouter',
        slug: 'anthropic/claude-sonnet-4.6',
      );

      final hidden = entry.copyWith(isHidden: true);

      expect(hidden.provider, 'openrouter');
      expect(hidden.slug, 'anthropic/claude-sonnet-4.6');
      expect(hidden.isBuiltIn, isFalse);
      expect(hidden.isHidden, isTrue);
    });
  });
}
