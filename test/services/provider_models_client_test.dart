import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:make_it_sound_natural/constants/app_defaults.dart';
import 'package:make_it_sound_natural/services/provider_models_client.dart';

void main() {
  const token = 'test-only-token';
  const openAiUrl = 'https://api.openai.com/v1';
  const anthropicUrl = 'https://api.anthropic.com/v1';

  Future<List<String>> fetch(
    MockClient client, {
    String provider = AppDefaults.openAiProvider,
    Duration timeout = ProviderModelsClient.requestTimeout,
  }) => ProviderModelsClient(client: client, timeout: timeout).fetchModelIds(
    provider: provider,
    baseUrl: provider == AppDefaults.anthropicProvider
        ? anthropicUrl
        : openAiUrl,
    apiKey: token,
  );

  test('requests OpenAI models with a bearer token', () async {
    final result = await fetch(
      MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.toString(), '$openAiUrl/models');
        expect(request.headers['Authorization'], 'Bearer $token');
        return http.Response(
          jsonEncode({
            'data': [
              {'id': 'gpt-6-sol'},
              {'id': 'gpt-6-luna'},
            ],
          }),
          200,
        );
      }),
    );
    expect(result, ['gpt-6-sol', 'gpt-6-luna']);
  });

  test('requests Anthropic models with key and version headers', () async {
    final result = await fetch(
      MockClient((request) async {
        expect(request.url.toString(), '$anthropicUrl/models?limit=1000');
        expect(request.headers['x-api-key'], token);
        expect(request.headers['anthropic-version'], '2023-06-01');
        expect(request.headers.containsKey('Authorization'), isFalse);
        return http.Response(
          '{"data":[{"id":"claude-opus-5-5"}],"has_more":false}',
          200,
        );
      }),
      provider: AppDefaults.anthropicProvider,
    );
    expect(result, ['claude-opus-5-5']);
  });

  test('follows Anthropic pagination', () async {
    var requests = 0;
    final result = await fetch(
      MockClient((request) async {
        requests++;
        expect(request.url.queryParameters['limit'], '1000');
        if (requests == 1) {
          expect(request.url.queryParameters.containsKey('after_id'), isFalse);
          return http.Response(
            '{"data":[{"id":"claude-opus-5-5"}],'
            '"has_more":true,"last_id":"claude-opus-5-5"}',
            200,
          );
        }
        expect(requests, 2);
        expect(request.url.queryParameters['after_id'], 'claude-opus-5-5');
        return http.Response(
          '{"data":[{"id":"claude-sonnet-5-5"}],"has_more":false}',
          200,
        );
      }),
      provider: AppDefaults.anthropicProvider,
    );
    expect(result, ['claude-opus-5-5', 'claude-sonnet-5-5']);
    expect(requests, 2);
  });

  test('throws with the status code on a non-200 response', () async {
    await expectLater(
      fetch(MockClient((_) async => http.Response('unauthorized', 401))),
      throwsA(
        isA<ProviderModelsException>().having(
          (error) => error.statusCode,
          'statusCode',
          401,
        ),
      ),
    );
  });

  test('throws when the request times out', () async {
    final response = Completer<http.Response>();
    await expectLater(
      fetch(
        MockClient((_) => response.future),
        timeout: const Duration(milliseconds: 1),
      ),
      throwsA(isA<ProviderModelsException>()),
    );
    response.complete(http.Response('{"data":[]}', 200));
  });

  test('throws on a transport error', () async {
    await expectLater(
      fetch(MockClient((_) async => throw http.ClientException(token))),
      throwsA(
        isA<ProviderModelsException>().having(
          (error) => error.toString(),
          'safe description',
          isNot(contains(token)),
        ),
      ),
    );
  });

  test('throws on a socket error', () async {
    await expectLater(
      fetch(MockClient((_) async => throw const SocketException(token))),
      throwsA(isA<ProviderModelsException>()),
    );
  });

  test(
    'wraps a TLS handshake error without exposing transport details',
    () async {
      await expectLater(
        fetch(MockClient((_) async => throw const HandshakeException(token))),
        throwsA(
          isA<ProviderModelsException>().having(
            (error) => error.toString(),
            'safe description',
            isNot(contains(token)),
          ),
        ),
      );
    },
  );

  test('throws on a body without a data list', () async {
    for (final body in ['{}', '{"data":{}}', '[]', 'null']) {
      await expectLater(
        fetch(MockClient((_) async => http.Response(body, 200))),
        throwsA(isA<ProviderModelsException>()),
      );
    }
  });

  test('throws on an item without a string id', () async {
    for (final item in <Object?>[
      null,
      'model',
      42,
      {},
      {'id': 42},
    ]) {
      await expectLater(
        fetch(
          MockClient(
            (_) async => http.Response(
              jsonEncode({
                'data': [item],
              }),
              200,
            ),
          ),
        ),
        throwsA(isA<ProviderModelsException>()),
      );
    }
  });

  test('throws on invalid JSON without exposing the body', () async {
    await expectLater(
      fetch(MockClient((_) async => http.Response(token, 200))),
      throwsA(
        isA<ProviderModelsException>().having(
          (error) => error.toString(),
          'safe description',
          isNot(contains(token)),
        ),
      ),
    );
  });

  test('throws when another page has no string last_id', () async {
    for (final lastId in <Object?>[null, 42]) {
      await expectLater(
        fetch(
          MockClient(
            (_) async => http.Response(
              jsonEncode({
                'data': <Object>[],
                'has_more': true,
                'last_id': lastId,
              }),
              200,
            ),
          ),
          provider: AppDefaults.anthropicProvider,
        ),
        throwsA(isA<ProviderModelsException>()),
      );
    }
  });

  test('never puts the key in the URL', () async {
    await fetch(
      MockClient((request) async {
        expect(request.url.toString(), isNot(contains(token)));
        expect(request.url.queryParameters, isEmpty);
        return http.Response('{"data":[]}', 200);
      }),
    );
    await fetch(
      MockClient((request) async {
        expect(request.url.toString(), isNot(contains(token)));
        expect(request.url.queryParameters, {'limit': '1000'});
        return http.Response('{"data":[],"has_more":false}', 200);
      }),
      provider: AppDefaults.anthropicProvider,
    );
  });

  test('rejects unsupported providers before making a request', () async {
    await expectLater(
      fetch(
        MockClient((_) async => fail('Unexpected HTTP request')),
        provider: AppDefaults.openRouterProvider,
      ),
      throwsArgumentError,
    );
  });
}
