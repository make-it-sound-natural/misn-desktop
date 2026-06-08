import 'package:flutter_test/flutter_test.dart';
import 'package:make_it_sound_natural/models/target_profile.dart';

void main() {
  group('TargetProfile', () {
    test('round-trips custom profile through JSON', () {
      const profile = TargetProfile(
        id: 'custom_1',
        name: 'Canadian business English',
        instruction: 'Rewrite in natural Canadian business English.',
        source: TargetProfileSource.custom,
        description: 'Company-specific language preference',
      );

      expect(TargetProfile.fromJson(profile.toJson()), equals(profile));
    });

    test('reports built-in source correctly', () {
      const profile = TargetProfile(
        id: 'americanEnglish',
        name: 'American English',
        instruction: 'Rewrite in natural American English.',
        source: TargetProfileSource.builtIn,
      );

      expect(profile.isBuiltIn, isTrue);
      expect(profile.isCustom, isFalse);
    });

    test('throws FormatException for invalid JSON', () {
      expect(
        () => TargetProfile.fromJson(const {'id': '', 'name': 'Name'}),
        throwsFormatException,
      );
    });
  });
}
