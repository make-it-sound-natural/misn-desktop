import 'package:flutter_test/flutter_test.dart';
import 'package:make_it_sound_natural/services/model_catalog_cache.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final fetchedAt = DateTime.utc(2026, 10, 31, 10);

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('returns null for a provider that was never fetched', () async {
    expect(await ModelCatalogCache().read('openai'), isNull);
  });

  test('writes one provider without touching another', () async {
    final cache = ModelCatalogCache();
    final prefs = await SharedPreferences.getInstance();
    await cache.writeTo(
      prefs,
      'anthropic-messages',
      families: {'opus': 'claude-opus-5-5'},
      fetchedAt: fetchedAt,
    );
    await cache.writeTo(
      prefs,
      'openai',
      families: {'sol': 'gpt-6.1-sol'},
      fetchedAt: fetchedAt.add(const Duration(hours: 1)),
    );

    final anthropic = await cache.read('anthropic-messages');
    expect(anthropic?.families, {'opus': 'claude-opus-5-5'});
    expect(anthropic?.fetchedAt, fetchedAt);
  });

  test('two writes issued back to back keep both providers', () async {
    final cache = ModelCatalogCache();
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      cache.writeTo(
        prefs,
        'openai',
        families: {'sol': 'gpt-6.1-sol'},
        fetchedAt: fetchedAt,
      ),
      cache.writeTo(
        prefs,
        'anthropic-messages',
        families: {'opus': 'claude-opus-5-5'},
        fetchedAt: fetchedAt,
      ),
    ]);

    expect((await cache.read('openai'))?.families, {'sol': 'gpt-6.1-sol'});
    expect(
      (await cache.read('anthropic-messages'))?.families,
      {'opus': 'claude-opus-5-5'},
    );
  });

  test('round-trips families and fetchedAt', () async {
    final cache = ModelCatalogCache();
    final prefs = await SharedPreferences.getInstance();
    final localTime = DateTime.parse('2026-10-31T12:00:00+02:00');
    await cache.writeTo(
      prefs,
      'openai',
      families: {'sol': 'gpt-6.1-sol', 'terra': 'gpt-6.1-terra'},
      fetchedAt: localTime,
    );

    final restored = await ModelCatalogCache().read('openai');
    expect(restored?.families, {
      'sol': 'gpt-6.1-sol',
      'terra': 'gpt-6.1-terra',
    });
    expect(restored?.fetchedAt, fetchedAt);
    expect(restored?.fetchedAt.isUtc, isTrue);
  });
}
