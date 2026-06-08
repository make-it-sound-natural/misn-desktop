import 'package:flutter_test/flutter_test.dart';
import 'package:make_it_sound_natural/constants/app_defaults.dart';
import 'package:make_it_sound_natural/services/provider_catalog_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('ProviderCatalogService', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('returns built-in providers first', () async {
      final service = ProviderCatalogService();

      final providers = await service.allProviders();

      expect(providers.map((entry) => entry.id), [
        AppDefaults.openRouterProvider,
        AppDefaults.openAiProvider,
      ]);
      expect(providers.every((entry) => entry.isBuiltIn), isTrue);
    });

    test('adds provider with generated id and zero models', () async {
      final service = ProviderCatalogService();

      final provider = await service.addCustomProvider(
        displayName: '  TokenGuard  ',
        baseUrl: '  https://tokenguard.int.agrd.dev/api/v1  ',
      );

      expect(provider.id, 'tokenguard');
      expect(provider.displayName, 'TokenGuard');
      expect(provider.baseUrl, 'https://tokenguard.int.agrd.dev/api/v1');
      expect((await service.allProviders()).map((entry) => entry.id), [
        AppDefaults.openRouterProvider,
        AppDefaults.openAiProvider,
        'tokenguard',
      ]);
    });

    test('deduplicates generated ids', () async {
      final service = ProviderCatalogService();

      final first = await service.addCustomProvider(
        displayName: 'TokenGuard',
        baseUrl: 'https://one.example/api/v1',
      );
      final second = await service.addCustomProvider(
        displayName: 'TokenGuard',
        baseUrl: 'https://two.example/api/v1',
      );

      expect(first.id, 'tokenguard');
      expect(second.id, 'tokenguard-2');
    });

    test('deduplicates ids after trimming punctuation hyphens', () async {
      final service = ProviderCatalogService();

      final provider = await service.addCustomProvider(
        displayName: 'OpenAI!',
        baseUrl: 'https://openai-proxy.example/api/v1',
      );

      expect(provider.id, 'openai-2');
    });

    test('ignores corrupt custom provider preferences', () async {
      SharedPreferences.setMockInitialValues({
        'llm_custom_providers': [
          '[',
          '[]',
          '42',
          '{"id":1,"displayName":"Bad","baseUrl":"https://bad.test"}',
          '{"id":"ok","displayName":"OK","baseUrl":"https://ok.test"}',
        ],
      });
      final service = ProviderCatalogService();

      final customProviders = await service.customProviders();

      expect(customProviders, hasLength(1));
      expect(customProviders.single.id, 'ok');
    });

    test('rejects provider names without letters or numbers', () async {
      final service = ProviderCatalogService();

      await expectLater(
        service.addCustomProvider(
          displayName: '!!!',
          baseUrl: 'https://a.test',
        ),
        throwsA(isA<ProviderCatalogValidationException>()),
      );
    });

    test('normalizes chat completions endpoint', () {
      expect(
        ProviderCatalogService.normalizedChatCompletionsUrl(
          'https://tokenguard.int.agrd.dev/api/v1',
        ),
        'https://tokenguard.int.agrd.dev/api/v1/chat/completions',
      );
      expect(
        ProviderCatalogService.normalizedChatCompletionsUrl(
          'https://tokenguard.int.agrd.dev/api/v1/chat/completions',
        ),
        'https://tokenguard.int.agrd.dev/api/v1/chat/completions',
      );
    });

    test('rejects empty values and non-https url', () async {
      final service = ProviderCatalogService();

      await expectLater(
        service.addCustomProvider(displayName: ' ', baseUrl: 'https://a.test'),
        throwsA(isA<ProviderCatalogValidationException>()),
      );
      await expectLater(
        service.addCustomProvider(displayName: 'A', baseUrl: 'http://a.test'),
        throwsA(isA<ProviderCatalogValidationException>()),
      );
      await expectLater(
        service.addCustomProvider(
          displayName: 'A',
          baseUrl: 'https://a.test/api/v1?token=ignored',
        ),
        throwsA(isA<ProviderCatalogValidationException>()),
      );
      await expectLater(
        service.addCustomProvider(
          displayName: 'A',
          baseUrl: 'https://a.test/api/v1#chat',
        ),
        throwsA(isA<ProviderCatalogValidationException>()),
      );
    });

    test('edits custom provider without changing id', () async {
      final service = ProviderCatalogService();
      await service.addCustomProvider(
        displayName: 'TokenGuard',
        baseUrl: 'https://one.example/api/v1',
      );

      final edited = await service.editCustomProvider(
        id: 'tokenguard',
        displayName: 'TG',
        baseUrl: 'https://two.example/api/v1',
      );

      expect(edited.id, 'tokenguard');
      expect(edited.displayName, 'TG');
      expect(edited.baseUrl, 'https://two.example/api/v1');
    });
  });
}
