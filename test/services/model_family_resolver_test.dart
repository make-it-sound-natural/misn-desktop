import 'package:flutter_test/flutter_test.dart';
import 'package:make_it_sound_natural/constants/app_defaults.dart';
import 'package:make_it_sound_natural/constants/model_families.dart';
import 'package:make_it_sound_natural/models/model_family.dart';
import 'package:make_it_sound_natural/services/model_family_resolver.dart';

void main() {
  const openAi = AppDefaults.openAiProvider;
  const anthropic = AppDefaults.anthropicProvider;

  test('defines four OpenAI and four Anthropic families in display order', () {
    expect(
      ModelFamilies.forProvider(openAi).map((family) => family.id),
      ['luna', 'terra', 'sol', 'astra'],
    );
    expect(
      ModelFamilies.forProvider(anthropic).map((family) => family.id),
      ['opus', 'sonnet', 'haiku', 'fable'],
    );
    expect(ModelFamilies.all, hasLength(8));
    expect(ModelFamilies.hasProvider(openAi), isTrue);
    expect(ModelFamilies.hasProvider(anthropic), isTrue);
    expect(ModelFamilies.hasProvider(AppDefaults.openRouterProvider), isFalse);
  });

  test('only opus supports fast mode', () {
    expect(
      ModelFamilies.all
          .where((family) => family.supportsFast)
          .map((family) => family.id),
      ['opus'],
    );
  });

  test('keeps the newest OpenAI version per tier', () {
    expect(resolveFamilies(openAi, ['gpt-6-sol', 'gpt-6.1-sol']), {
      'sol': 'gpt-6.1-sol',
    });
    expect(
      resolveFamilies(openAi, [
        'gpt-6.9-sol',
        'gpt-6.10-sol',
        'gpt-6-luna',
        'gpt-6.1-terra',
        'gpt-6-astra',
      ]),
      {
        'luna': 'gpt-6-luna',
        'terra': 'gpt-6.1-terra',
        'sol': 'gpt-6.10-sol',
        'astra': 'gpt-6-astra',
      },
    );
  });

  test('keeps the newest Anthropic version per family', () {
    expect(
      resolveFamilies(anthropic, [
        'claude-opus-5-1',
        'claude-opus-5-5',
        'claude-opus-5',
        'claude-sonnet-5-5',
        'claude-haiku-5-5',
        'claude-fable-5-1',
      ]),
      {
        'opus': 'claude-opus-5-5',
        'sonnet': 'claude-sonnet-5-5',
        'haiku': 'claude-haiku-5-5',
        'fable': 'claude-fable-5-1',
      },
    );
  });

  test('ignores dated Anthropic snapshots', () {
    expect(
      resolveFamilies(anthropic, [
        'claude-opus-5-5-20260101',
        'claude-opus-5-20260101',
      ]),
      isEmpty,
    );
  });

  test('ignores ids outside the families', () {
    expect(
      resolveFamilies(openAi, [
        'gpt-5.4-mini',
        'gpt-5.4',
        'text-embedding-3-large',
        'gpt-6.1-sol-2026-10-01',
      ]),
      isEmpty,
    );
  });

  test('resolves only the requested provider', () {
    expect(resolveFamilies(openAi, ['claude-opus-5-5']), isEmpty);
    expect(
      resolveFamilies(AppDefaults.openRouterProvider, ['gpt-6-sol']),
      isEmpty,
    );
  });

  test('finds the family of a slug', () {
    expect(familyForSlug(openAi, 'gpt-6.1-sol')?.id, 'sol');
    expect(familyForSlug(anthropic, 'claude-sonnet-5-5')?.id, 'sonnet');
    expect(familyForSlug(openAi, 'gpt-5.4-mini'), isNull);
    expect(familyForSlug(anthropic, 'gpt-6.1-sol'), isNull);
    expect(familyForSlug(openAi, 'gpt-6.1-sol')?.versionOf('gpt-6-sol'), [6]);
  });

  test('compares version tuples with zero-filled missing parts', () {
    expect(compareModelVersions([6, 1], [6]), greaterThan(0));
    expect(compareModelVersions([6, 10], [6, 9]), greaterThan(0));
    expect(compareModelVersions([5], [5, 0]), 0);
    expect(compareModelVersions([5, 1], [5, 5]), lessThan(0));
  });

  test('breaks equal version ties by slug ordering independently of input', () {
    expect(resolveFamilies(openAi, ['gpt-6.0-sol', 'gpt-6-sol']), {
      'sol': 'gpt-6-sol',
    });
    expect(resolveFamilies(openAi, ['gpt-6-sol', 'gpt-6.0-sol']), {
      'sol': 'gpt-6-sol',
    });
  });
}
