import 'package:flutter_test/flutter_test.dart';
import 'package:make_it_sound_natural/utils/shortcut_formatter.dart';

void main() {
  group('validateShortcutStructure', () {
    test('accepts a command modifier plus a key', () {
      expect(
        ShortcutFormatter.validateShortcutStructure('cmd+shift+k'),
        isTrue,
      );
      expect(ShortcutFormatter.validateShortcutStructure('ctrl+j'), isTrue);
    });

    test('rejects modifier-only chords', () {
      // Regression: a substring test used to accept these, so the recorder
      // turned green and enabled Save for a chord no key press completes.
      expect(
        ShortcutFormatter.validateShortcutStructure('cmd+ctrl+shift'),
        isFalse,
      );
      expect(ShortcutFormatter.validateShortcutStructure('cmd'), isFalse);
      expect(
        ShortcutFormatter.validateShortcutStructure('cmd+alt+shift'),
        isFalse,
      );
    });

    test('rejects a key with no command modifier', () {
      expect(ShortcutFormatter.validateShortcutStructure('shift+k'), isFalse);
      expect(ShortcutFormatter.validateShortcutStructure('k'), isFalse);
    });
  });
}
