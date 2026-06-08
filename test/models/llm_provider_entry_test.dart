import 'package:flutter_test/flutter_test.dart';
import 'package:make_it_sound_natural/models/llm_provider_entry.dart';

void main() {
  group('LlmProviderEntry', () {
    test('serializes custom provider metadata without secrets', () {
      const entry = LlmProviderEntry(
        id: 'tokenguard',
        displayName: 'TokenGuard',
        baseUrl: 'https://tokenguard.int.agrd.dev/api/v1',
      );

      expect(entry.toJson(), {
        'id': 'tokenguard',
        'displayName': 'TokenGuard',
        'baseUrl': 'https://tokenguard.int.agrd.dev/api/v1',
        'isBuiltIn': false,
      });
    });

    test('reads missing built-in flag as false', () {
      final entry = LlmProviderEntry.fromJson({
        'id': 'tokenguard',
        'displayName': 'TokenGuard',
        'baseUrl': 'https://tokenguard.int.agrd.dev/api/v1',
      });

      expect(entry.isBuiltIn, isFalse);
    });

    test('ignores malformed persisted field values', () {
      final entry = LlmProviderEntry.fromJson(const {
        'id': 1,
        'displayName': false,
        'baseUrl': ['https://bad.test'],
        'isBuiltIn': 'yes',
      });

      expect(entry.id, isEmpty);
      expect(entry.displayName, isEmpty);
      expect(entry.baseUrl, isEmpty);
      expect(entry.isBuiltIn, isFalse);
    });

    test('copyWith preserves generated id by default', () {
      const entry = LlmProviderEntry(
        id: 'tokenguard',
        displayName: 'TokenGuard',
        baseUrl: 'https://tokenguard.int.agrd.dev/api/v1',
      );

      final renamed = entry.copyWith(displayName: 'TG');

      expect(renamed.id, 'tokenguard');
      expect(renamed.displayName, 'TG');
    });
  });
}
