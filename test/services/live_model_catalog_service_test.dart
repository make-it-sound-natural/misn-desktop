import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:logging/logging.dart';
import 'package:make_it_sound_natural/constants/app_defaults.dart';
import 'package:make_it_sound_natural/constants/method_channel_methods.dart';
import 'package:make_it_sound_natural/services/live_model_catalog_service.dart';
import 'package:make_it_sound_natural/services/model_catalog_cache.dart';
import 'package:make_it_sound_natural/services/provider_models_client.dart';
import 'package:make_it_sound_natural/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const openAi = AppDefaults.openAiProvider;
  const anthropic = AppDefaults.anthropicProvider;
  const channel = MethodChannel(MethodChannelMethods.channelName);
  final now = DateTime.utc(2026, 10, 31, 12);
  final cache = ModelCatalogCache();
  late Set<String> keyedProviders;
  late String storedKey;
  late List<MethodCall> nativeModels;
  late List<http.Request> requests;
  late Future<http.Response> Function(http.Request) respond;
  late LiveModelCatalogService service;

  http.Response response(List<String> ids) => http.Response(
    jsonEncode({
      'data': [
        for (final id in ids) {'id': id},
      ],
      'has_more': false,
    }),
    200,
  );

  Future<void> seedCache({
    String provider = openAi,
    Map<String, String> families = const {'sol': 'gpt-6.1-sol'},
    Duration age = Duration.zero,
  }) async {
    await cache.writeTo(
      await SharedPreferences.getInstance(),
      provider,
      families: families,
      fetchedAt: now.subtract(age),
    );
  }

  Future<void> select(String provider, String model) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(SettingsService.providerKey, provider);
    await prefs.setString(SettingsService.modelKey, model);
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    keyedProviders = {openAi, anthropic};
    storedKey = 'test-key';
    nativeModels = [];
    requests = [];
    respond = (_) async => response(['gpt-6.2-sol']);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          final provider = switch (call.method) {
            MethodChannelMethods.getStoredApiKey => openAi,
            MethodChannelMethods.getStoredAnthropicApiKey => anthropic,
            _ => null,
          };
          if (provider != null) {
            return keyedProviders.contains(provider) ? storedKey : '';
          }
          if (call.method == MethodChannelMethods.setModel) {
            nativeModels.add(call);
          }
          return null;
        });
    service = LiveModelCatalogService(
      now: () => now,
      client: ProviderModelsClient(
        client: MockClient((request) {
          requests.add(request);
          return respond(request);
        }),
      ),
    );
  });

  tearDown(() {
    service.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('skips the fetch while the cache is younger than 24 hours', () async {
    await seedCache(age: const Duration(hours: 23));

    await service.refreshIfStale(openAi);

    expect(requests, isEmpty);
    expect(service.revision.value, 0);
  });

  test('fetches when the cache is older than 24 hours', () async {
    await seedCache(age: const Duration(hours: 25));

    await service.refreshIfStale(openAi);

    expect(requests, hasLength(1));
    expect((await cache.read(openAi))?.families, {'sol': 'gpt-6.2-sol'});
  });

  test('fetches when no cache exists', () async {
    await service.refreshIfStale(openAi);

    expect(requests.single.url.toString(), 'https://api.openai.com/v1/models');
    expect((await cache.read(openAi))?.fetchedAt, now);
  });

  test('refresh fetches even with a fresh cache', () async {
    await seedCache();

    await service.refresh(openAi);

    expect(requests, hasLength(1));
    expect((await cache.read(openAi))?.families, {'sol': 'gpt-6.2-sol'});
  });

  test('replaces the cache on a successful response', () async {
    await seedCache(
      families: {'sol': 'gpt-6.1-sol', 'terra': 'gpt-6.1-terra'},
    );

    await service.refresh(openAi);

    expect((await cache.read(openAi))?.families, {'sol': 'gpt-6.2-sol'});
  });

  test('keeps the cache when the request fails', () async {
    await seedCache(age: const Duration(days: 2));
    await select(openAi, 'gpt-6.1-sol');
    final prefs = await SharedPreferences.getInstance();
    final original = prefs.getString(ModelCatalogCache.storageKey);
    respond = (_) async => http.Response('unauthorized', 401);

    await service.refresh(openAi);
    expect(prefs.getString(ModelCatalogCache.storageKey), original);

    respond = (_) async => throw http.ClientException('offline');
    await service.refresh(openAi);

    expect(prefs.getString(ModelCatalogCache.storageKey), original);
    expect(prefs.getString(SettingsService.modelKey), 'gpt-6.1-sol');
    expect(nativeModels, isEmpty);
    expect(service.revision.value, 0);
  });

  for (final provider in [openAi, anthropic]) {
    test('keeps the cache when the $provider key cannot be read', () async {
      final families = provider == openAi
          ? {'sol': 'gpt-6.1-sol'}
          : {'opus': 'claude-opus-5-5'};
      final model = families.values.single;
      await seedCache(
        provider: provider,
        families: families,
        age: const Duration(days: 2),
      );
      await select(provider, model);
      final prefs = await SharedPreferences.getInstance();
      final original = prefs.getString(ModelCatalogCache.storageKey);
      final records = <LogRecord>[];
      final subscription = Logger(
        'LiveModelCatalogService',
      ).onRecord.listen(records.add);
      addTearDown(subscription.cancel);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            throw PlatformException(
              code: 'KEYCHAIN_ERROR',
              message: 'Private platform error message',
              details: 'Private platform error details',
            );
          });

      await expectLater(service.refresh(provider), completes);
      await expectLater(service.refreshIfStale(provider), completes);

      expect(prefs.getString(ModelCatalogCache.storageKey), original);
      expect(prefs.getString(SettingsService.modelKey), model);
      expect(requests, isEmpty);
      expect(nativeModels, isEmpty);
      expect(service.revision.value, 0);
      expect(records, hasLength(2));
      for (final record in records) {
        expect(record.level, Level.WARNING);
        expect(record.message, contains(provider));
        expect(record.message, isNot(contains('Private platform')));
        expect(record.error, isNull);
      }
    });
  }

  test('does nothing without a stored key', () async {
    keyedProviders.clear();

    await service.refresh(openAi);
    await service.refreshIfStale(anthropic);

    expect(requests, isEmpty);
    expect(await cache.read(openAi), isNull);
    expect(await cache.read(anthropic), isNull);
    expect(service.revision.value, 0);
  });

  test('does nothing for OpenRouter and custom providers', () async {
    for (final provider in [AppDefaults.openRouterProvider, 'custom']) {
      await service.refresh(provider);
      await service.refreshIfStale(provider);
    }

    expect(requests, isEmpty);
    expect(service.revision.value, 0);
  });

  test('shares one fetch between concurrent stale checks', () async {
    final started = Completer<void>();
    final pending = Completer<http.Response>();
    respond = (_) {
      started.complete();
      return pending.future;
    };
    final first = service.refreshIfStale(openAi);
    await started.future;
    final second = service.refreshIfStale(openAi);
    pending.complete(response(['gpt-6.2-sol']));

    await Future.wait([first, second]);

    expect(requests, hasLength(1));
    expect(service.revision.value, 1);
  });

  test(
    'forced refresh after a key change fetches again with the new key',
    () async {
      await seedCache(age: const Duration(days: 2));
      final started = Completer<void>();
      final pending = Completer<http.Response>();
      respond = (_) {
        if (requests.length == 1) {
          started.complete();
          return pending.future;
        }
        return Future.value(response(['gpt-6.2-sol']));
      };
      final staleRefresh = service.refreshIfStale(openAi);
      await started.future;
      expect(requests.single.headers['Authorization'], 'Bearer test-key');

      storedKey = 'replacement-test-key';
      final forcedRefresh = service.refresh(openAi);
      final anotherForcedRefresh = service.refresh(openAi);
      pending.complete(response(['gpt-6.1-sol']));
      await Future.wait([
        staleRefresh,
        forcedRefresh,
        anotherForcedRefresh,
      ]);

      expect(requests, hasLength(2));
      expect(
        requests.last.headers['Authorization'],
        'Bearer replacement-test-key',
      );
      expect((await cache.read(openAi))?.families, {'sol': 'gpt-6.2-sol'});
      expect(service.revision.value, 2);
    },
  );

  test('upgrades the selected model to the newest family version', () async {
    await select(openAi, 'gpt-6.1-sol');

    await service.refresh(openAi);

    expect(await SettingsService().getModel(), 'gpt-6.2-sol');
    expect(nativeModels.single.arguments, 'gpt-6.2-sol');
  });

  test('keeps a selected custom model when a newer version ships', () async {
    await select(openAi, 'gpt-6.1-sol');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('llm_custom_models', [
      jsonEncode({'provider': openAi, 'slug': 'gpt-6.1-sol'}),
    ]);

    await service.refresh(openAi);

    expect(await SettingsService().getModel(), 'gpt-6.1-sol');
    expect(nativeModels, isEmpty);
  });

  test('leaves the selection alone for another provider', () async {
    await select(anthropic, 'claude-opus-5-5');

    await service.refresh(openAi);

    expect(await SettingsService().getProvider(), anthropic);
    expect(await SettingsService().getModel(), 'claude-opus-5-5');
    expect(nativeModels, isEmpty);
  });

  test('clears the selection when its family disappears', () async {
    await select(openAi, 'gpt-6.1-sol');
    respond = (_) async => response(['gpt-6.1-terra']);

    await service.refresh(openAi);

    expect(await SettingsService().getModel(), '');
    expect(nativeModels.single.arguments, '');
  });

  test('refreshes two providers concurrently without losing a write', () async {
    await select(openAi, 'gpt-6.1-sol');
    respond = (request) async => response(
      request.url.host == 'api.openai.com'
          ? ['gpt-6.2-sol']
          : ['claude-opus-5-5'],
    );

    await Future.wait([service.refresh(openAi), service.refresh(anthropic)]);

    expect((await cache.read(openAi))?.families, {'sol': 'gpt-6.2-sol'});
    expect((await cache.read(anthropic))?.families, {
      'opus': 'claude-opus-5-5',
    });
    expect(await SettingsService().getModel(), 'gpt-6.2-sol');
    expect(nativeModels.single.arguments, 'gpt-6.2-sol');
  });

  test('respects a selection made while the fetch was in flight', () async {
    await select(openAi, 'gpt-6.1-sol');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('llm_custom_models', [
      jsonEncode({'provider': openAi, 'slug': 'pinned-model'}),
    ]);
    final started = Completer<void>();
    final pending = Completer<http.Response>();
    respond = (_) {
      started.complete();
      return pending.future;
    };
    final refresh = service.refresh(openAi);
    await started.future;
    await select(openAi, 'pinned-model');
    pending.complete(response(['gpt-6.2-sol']));

    await refresh;

    expect(await SettingsService().getModel(), 'pinned-model');
    expect(nativeModels, isEmpty);
  });

  test('bumps the revision after each cache write', () async {
    final revisions = <int>[];
    service.revision.addListener(() => revisions.add(service.revision.value));

    await service.refresh(openAi);
    await service.refresh(openAi);

    expect(revisions, [1, 2]);
  });

  test('refreshAllIfStale covers OpenAI and Anthropic', () async {
    respond = (request) async => response(
      request.url.host == 'api.openai.com'
          ? ['gpt-6.2-sol']
          : ['claude-opus-5-5'],
    );

    await service.refreshAllIfStale();

    expect(
      requests.map((request) => request.url.host),
      unorderedEquals([
        'api.openai.com',
        'api.anthropic.com',
      ]),
    );
    expect((await cache.read(openAi))?.families, {'sol': 'gpt-6.2-sol'});
    expect((await cache.read(anthropic))?.families, {
      'opus': 'claude-opus-5-5',
    });
  });
}
