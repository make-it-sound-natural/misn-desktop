import 'package:flutter_test/flutter_test.dart';
import 'package:make_it_sound_natural/services/target_profile_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('TargetProfileService', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('exposes expected built-in profiles', () {
      const profiles = TargetProfileService.builtInProfiles;

      expect(
        profiles.map((profile) => profile.name),
        containsAll(<String>[
          'American English',
          'British English',
          'Natural in original language',
          'Spanish',
          'French',
          'German',
          'Portuguese',
          'Russian',
          'Arabic',
          'Japanese',
          'Chinese',
        ]),
      );
    });

    test('search is case-insensitive and trims spaces', () async {
      final service = TargetProfileService();

      final results = await service.searchProfiles('  brit  ');

      expect(results.single.name, equals('British English'));
    });

    test('non-English built-in profiles translate every variant', () {
      final profilesById = {
        for (final profile in TargetProfileService.builtInProfiles)
          profile.id: profile,
      };

      for (final entry in {
        'spanish': 'Spanish',
        'french': 'French',
        'german': 'German',
        'portuguese': 'Portuguese',
        'russian': 'Russian',
        'arabic': 'Arabic',
        'japanese': 'Japanese',
        'chinese': 'Chinese',
      }.entries) {
        final instruction = profilesById[entry.key]!.instruction;
        expect(instruction, contains('Translate and rewrite'));
        expect(instruction, contains('Every output variant'));
        expect(instruction, contains('must be ${entry.value}'));
        expect(instruction, contains('Do not leave English text'));
      }
    });

    test('creates, persists, and selects custom profile', () async {
      var nextId = 0;
      final service = TargetProfileService(
        idFactory: () => 'custom_${nextId++}',
      );

      final profile = await service.createCustomProfile(
        name: 'Canadian business English',
        instruction: 'Rewrite in natural Canadian business English.',
      );
      await service.selectProfile(profile.id);

      final restored = TargetProfileService(idFactory: () => 'unused');
      expect((await restored.getCustomProfiles()).single, equals(profile));
      expect((await restored.getSelectedProfile())?.id, equals(profile.id));
    });

    test('rejects duplicate custom profile names ignoring case', () async {
      final service = TargetProfileService(idFactory: () => 'custom_1');
      await service.createCustomProfile(
        name: 'Team English',
        instruction: 'Rewrite for this team.',
      );

      expect(
        () => service.createCustomProfile(
          name: ' team english ',
          instruction: 'Rewrite differently.',
        ),
        throwsA(isA<TargetProfileValidationException>()),
      );
    });

    test('updates custom profile without changing its selection', () async {
      final service = TargetProfileService(idFactory: () => 'custom_1');
      final profile = await service.createCustomProfile(
        name: 'Team English',
        instruction: 'Rewrite for this team.',
      );
      await service.selectProfile(profile.id);

      final updated = await service.updateCustomProfile(
        profile.id,
        name: 'Team Spanish',
        instruction: 'Rewrite in the team Spanish voice.',
      );

      expect(updated.id, profile.id);
      expect(updated.name, 'Team Spanish');
      expect(updated.instruction, 'Rewrite in the team Spanish voice.');
      expect((await service.getSelectedProfile())?.id, profile.id);
      expect(
        (await service.getSelectedProfile())?.instruction,
        'Rewrite in the team Spanish voice.',
      );
    });

    test('rejects edited custom profile duplicate names', () async {
      var nextId = 0;
      final service = TargetProfileService(
        idFactory: () => 'custom_${nextId++}',
      );
      await service.createCustomProfile(
        name: 'Team English',
        instruction: 'Rewrite for this team.',
      );
      final profile = await service.createCustomProfile(
        name: 'Team Spanish',
        instruction: 'Rewrite for this other team.',
      );

      expect(
        () => service.updateCustomProfile(
          profile.id,
          name: ' team english ',
          instruction: 'Rewrite differently.',
        ),
        throwsA(isA<TargetProfileValidationException>()),
      );
    });

    test('removing selected custom profile falls back to default', () async {
      var nextId = 0;
      final service = TargetProfileService(
        idFactory: () => 'custom_${nextId++}',
      );
      final custom = await service.createCustomProfile(
        name: 'Brazilian Portuguese informal',
        instruction: 'Rewrite in informal Brazilian Portuguese.',
      );
      await service.selectProfile(custom.id);

      final result = await service.removeCustomProfile(custom.id);

      expect(result.removed, isTrue);
      expect(result.fallbackApplied, isTrue);
      expect(result.fallbackProfile?.id, TargetProfileService.defaultProfileId);
      expect(
        (await service.getSelectedProfile())?.id,
        TargetProfileService.defaultProfileId,
      );
    });

    test(
      'removed selected custom instruction cannot influence later prompt state',
      () async {
        var nextId = 0;
        final service = TargetProfileService(
          idFactory: () => 'custom_${nextId++}',
        );
        const removedInstruction = 'Rewrite in the retired team voice.';
        final custom = await service.createCustomProfile(
          name: 'Retired team voice',
          instruction: removedInstruction,
        );
        await service.selectProfile(custom.id);

        await service.removeCustomProfile(custom.id);
        final selected = await service.getSelectedProfile();

        expect(selected?.id, TargetProfileService.defaultProfileId);
        expect(selected?.instruction, isNot(removedInstruction));
        expect(selected?.instruction, 'Rewrite in natural American English.');
      },
    );

    test('invalid stored selected profile recovers to default', () async {
      SharedPreferences.setMockInitialValues({
        'target_profile_selected_id': 'missing_profile',
        'target_profile_selection_confirmed': true,
      });
      final service = TargetProfileService();

      final selected = await service.getSelectedProfile();

      expect(selected?.id, TargetProfileService.defaultProfileId);
    });
  });
}
