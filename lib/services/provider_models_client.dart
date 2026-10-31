import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:make_it_sound_natural/constants/app_defaults.dart';

/// A failed model-list request without sensitive response or transport data.
class ProviderModelsException implements Exception {
  /// Creates a failure with an optional HTTP status code.
  const ProviderModelsException(this.message, {this.statusCode});

  /// A description safe to include in diagnostics.
  final String message;

  /// HTTP status code when the provider returned a non-success response.
  final int? statusCode;

  @override
  String toString() =>
      'ProviderModelsException: $message'
      '${statusCode == null ? '' : ' (HTTP $statusCode)'}';
}

/// Fetches and validates model ids from providers with live catalogs.
class ProviderModelsClient {
  /// Creates a model-list client with an injectable transport and timeout.
  ProviderModelsClient({
    http.Client? client,
    Duration timeout = requestTimeout,
  }) : _client = client ?? http.Client(),
       _timeout = timeout;

  /// Maximum duration of each individual page request.
  static const Duration requestTimeout = Duration(seconds: 15);

  final http.Client _client;
  final Duration _timeout;

  /// Returns all ids, following pagination for the Anthropic Messages API.
  ///
  /// Throws [ProviderModelsException] on failed requests or malformed data,
  /// and [ArgumentError] for providers without a live catalog.
  Future<List<String>> fetchModelIds({
    required String provider,
    required String baseUrl,
    required String apiKey,
  }) async {
    final isAnthropic = provider == AppDefaults.anthropicProvider;
    if (!isAnthropic && provider != AppDefaults.openAiProvider) {
      throw ArgumentError.value(provider, 'provider', 'No live catalog');
    }

    final headers = isAnthropic
        ? {'x-api-key': apiKey, 'anthropic-version': '2023-06-01'}
        : {'Authorization': 'Bearer $apiKey'};
    final endpoint = Uri.parse(
      '${baseUrl.replaceAll(RegExp(r'/+$'), '')}/models',
    );
    final ids = <String>[];
    String? afterId;

    try {
      do {
        final url = isAnthropic
            ? endpoint.replace(
                queryParameters: {
                  'limit': '1000',
                  'after_id': ?afterId,
                },
              )
            : endpoint;
        final response = await _client
            .get(url, headers: headers)
            .timeout(_timeout);
        if (response.statusCode != 200) {
          throw ProviderModelsException(
            'Model list request failed.',
            statusCode: response.statusCode,
          );
        }

        final body = jsonDecode(response.body);
        switch (body) {
          case {'data': final List<dynamic> data}:
            for (final item in data) {
              switch (item) {
                case {'id': final String id}:
                  ids.add(id);
                default:
                  throw const ProviderModelsException(
                    'Model list item has no string id.',
                  );
              }
            }
          default:
            throw const ProviderModelsException(
              'Model list response has no data list.',
            );
        }

        afterId = null;
        if (isAnthropic) {
          switch (body) {
            case {'has_more': true, 'last_id': final String lastId}:
              afterId = lastId;
            case {'has_more': true}:
              throw const ProviderModelsException(
                'Model list pagination has no string last_id.',
              );
          }
        }
      } while (afterId != null);
      return ids;
    } on TimeoutException {
      throw const ProviderModelsException('Model list request timed out.');
    } on IOException {
      throw const ProviderModelsException('Model list connection failed.');
    } on http.ClientException {
      throw const ProviderModelsException('Model list transport failed.');
    } on FormatException {
      throw const ProviderModelsException(
        'Model list response is invalid JSON.',
      );
    }
  }
}
