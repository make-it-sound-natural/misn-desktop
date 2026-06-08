import 'package:flutter_test/flutter_test.dart';

import '../../tool/release_manager/release_version.dart';

void main() {
  group('ReleaseVersion', () {
    test('parses pubspec version', () {
      final version = ReleaseVersion.parsePubspecValue('1.2.3+45');

      expect(version.marketingVersion, '1.2.3');
      expect(version.buildNumber, 45);
      expect(version.pubspecValue, '1.2.3+45');
    });

    test('rejects missing build number', () {
      expect(
        () => ReleaseVersion.parsePubspecValue('1.2.3'),
        throwsA(isA<FormatException>()),
      );
    });

    test('validates stable version pattern', () {
      expect(
        ReleaseVersion.isValidForChannel('stable', '1.2.3'),
        isTrue,
      );
      expect(
        ReleaseVersion.isValidForChannel('stable', '1.2.3-beta.1'),
        isFalse,
      );
    });

    test('validates beta version pattern', () {
      expect(
        ReleaseVersion.isValidForChannel('beta', '1.2.3-beta.1'),
        isTrue,
      );
      expect(
        ReleaseVersion.isValidForChannel('beta', '1.2.3'),
        isFalse,
      );
    });

    test('validates nightly version pattern', () {
      expect(
        ReleaseVersion.isValidForChannel(
          'nightly',
          '1.2.3-nightly.20260503.1',
        ),
        isTrue,
      );
      expect(
        ReleaseVersion.isValidForChannel('nightly', '1.2.3'),
        isFalse,
      );
    });
  });
}
