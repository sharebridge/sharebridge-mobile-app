import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'auth_context.dart';
import 'donor_setup_api_client.dart';
import 'donor_setup_api_exceptions.dart';

/// Retry policy applied to a single API call.
class RetryPolicy {
  const RetryPolicy({
    this.maxAttempts = 3,
    this.initialBackoff = const Duration(milliseconds: 200),
    this.backoffMultiplier = 2.0,
    this.retryOnServerError = true,
  });

  /// Conservative policy used by mutating POSTs: only retry on network-level
  /// failures (the request likely never reached the server). Never retry on
  /// 5xx because the server may have partially processed the write.
  static const RetryPolicy mutating = RetryPolicy(
    maxAttempts: 2,
    retryOnServerError: false,
  );

  final int maxAttempts;
  final Duration initialBackoff;
  final double backoffMultiplier;
  final bool retryOnServerError;

  Duration backoffFor(int attempt) {
    final factor = math.pow(backoffMultiplier, attempt - 1);
    return Duration(
      milliseconds: (initialBackoff.inMilliseconds * factor).round(),
    );
  }
}

class HttpDonorSetupApiClient implements DonorSetupApiClient {
  HttpDonorSetupApiClient({
    required this.baseUrl,
    AuthContext? authContext,
    HttpClient? httpClient,
    this.requestTimeout = const Duration(seconds: 8),
    this.retryPolicy = const RetryPolicy(),
    this.savePresetsRetryPolicy = RetryPolicy.mutating,
  })  : _authContext = authContext ?? AuthContext.fromEnvironment(),
        _httpClient = httpClient ?? HttpClient() {
    _httpClient.connectionTimeout = requestTimeout;
  }

  final String baseUrl;
  final AuthContext _authContext;
  final HttpClient _httpClient;
  final Duration requestTimeout;
  final RetryPolicy retryPolicy;
  final RetryPolicy savePresetsRetryPolicy;

  @override
  Future<Map<String, dynamic>> suggestVendors({
    required String queryText,
    required double? lat,
    required double? lng,
    String? manualArea,
  }) {
    final payload = <String, dynamic>{
      'query_text': queryText,
      'location_precision': lat != null && lng != null ? 'gps' : 'manual_area',
      'client_platform': 'flutter-mobile',
      if (lat != null) 'lat': lat,
      if (lng != null) 'lng': lng,
      if (manualArea != null && manualArea.trim().isNotEmpty)
        'manual_area': manualArea,
    };

    return _runWithRetry(
      policy: retryPolicy,
      operation: () => _sendJson(
        method: 'POST',
        uri: Uri.parse('$baseUrl/v1/donor-setup/suggest-vendors'),
        body: payload,
      ),
    );
  }

  @override
  Future<List<Map<String, dynamic>>> getPresets({required String userId}) {
    return _runWithRetry(
      policy: retryPolicy,
      operation: () async {
        final decoded = await _sendJson(
          method: 'GET',
          uri: Uri.parse(
            '$baseUrl/v1/donor-setup/preferences?user_id=$userId',
          ),
        );
        final presetsRaw = decoded['presets'];
        if (presetsRaw is! List) {
          throw const DonorSetupResponseException(
            'presets must be a list',
          );
        }
        return presetsRaw.cast<Map<String, dynamic>>();
      },
    );
  }

  @override
  Future<void> savePresets({
    required String userId,
    required List<Map<String, dynamic>> payload,
  }) {
    return _runWithRetry<void>(
      policy: savePresetsRetryPolicy,
      operation: () async {
        await _sendJson(
          method: 'POST',
          uri: Uri.parse('$baseUrl/v1/donor-setup/preferences'),
          body: <String, dynamic>{'user_id': userId, 'presets': payload},
        );
      },
    );
  }

  @override
  Future<void> clearPresets({required String userId}) {
    return _runWithRetry<void>(
      policy: savePresetsRetryPolicy,
      operation: () async {
        await _sendJson(
          method: 'DELETE',
          uri: Uri.parse(
            '$baseUrl/v1/donor-setup/preferences?user_id=${Uri.encodeQueryComponent(userId)}',
          ),
        );
      },
    );
  }

  /// Donor–seeker instruction pack (integration-service → ai-orchestration).
  Future<Map<String, dynamic>> requestInstructionPack({
    required Map<String, dynamic> body,
  }) {
    return _runWithRetry(
      policy: retryPolicy,
      operation: () => _sendJson(
        method: 'POST',
        uri: Uri.parse('$baseUrl/v1/donor-seeker/instruction-pack'),
        body: body,
      ),
    );
  }

  @override
  Future<void> removePreset({
    required String userId,
    required String restaurantName,
    required String orderUrl,
  }) {
    return _runWithRetry<void>(
      policy: savePresetsRetryPolicy,
      operation: () async {
        await _sendJson(
          method: 'POST',
          uri: Uri.parse(
            '$baseUrl/v1/donor-setup/preferences/delete-item',
          ),
          body: <String, dynamic>{
            'user_id': userId,
            'restaurant_name': restaurantName,
            'order_url': orderUrl,
          },
        );
      },
    );
  }

  /// Executes a single HTTP call and maps low-level errors to typed
  /// [DonorSetupApiException]s. Does NOT retry; that's [_runWithRetry]'s job.
  Future<Map<String, dynamic>> _sendJson({
    required String method,
    required Uri uri,
    Object? body,
  }) async {
    HttpClientResponse response;
    try {
      final HttpClientRequest request;
      switch (method) {
        case 'GET':
          request = await _httpClient.getUrl(uri);
          break;
        case 'POST':
          request = await _httpClient.postUrl(uri);
          break;
        case 'DELETE':
          request = await _httpClient.deleteUrl(uri);
          break;
        default:
          throw ArgumentError('Unsupported HTTP method: $method');
      }
      _authContext.toHeaders().forEach((name, value) {
        request.headers.set(name, value);
      });
      if (body != null) {
        request.headers.contentType = ContentType.json;
        request.write(jsonEncode(body));
      }
      response = await request.close().timeout(requestTimeout);
    } on TimeoutException catch (error) {
      throw DonorSetupTimeoutException(
        'Request to $uri timed out after ${requestTimeout.inMilliseconds}ms: $error',
      );
    } on SocketException catch (error) {
      throw DonorSetupNetworkException(
        'Network unavailable for $uri: ${error.message}',
      );
    } on HttpException catch (error) {
      throw DonorSetupNetworkException(
        'HTTP transport error for $uri: ${error.message}',
      );
    }

    final responseBody = await utf8
        .decodeStream(response)
        .timeout(requestTimeout, onTimeout: () => '');

    final status = response.statusCode;
    if (status >= 200 && status < 300) {
      if (responseBody.isEmpty) {
        return <String, dynamic>{};
      }
      final dynamic decoded;
      try {
        decoded = jsonDecode(responseBody);
      } on FormatException catch (error) {
        throw DonorSetupResponseException(
          'Response was not valid JSON: ${error.message}',
        );
      }
      if (decoded is! Map<String, dynamic>) {
        throw const DonorSetupResponseException(
          'Response must be a JSON object',
        );
      }
      return decoded;
    }

    final parsed = _safeParseError(responseBody);
    if (status >= 400 && status < 500) {
      throw DonorSetupBadRequestException(
        statusCode: status,
        errorCode: parsed.code,
        message: parsed.message ?? 'HTTP $status',
      );
    }
    throw DonorSetupServerException(
      statusCode: status,
      message: parsed.message ?? 'HTTP $status',
    );
  }

  Future<T> _runWithRetry<T>({
    required RetryPolicy policy,
    required Future<T> Function() operation,
  }) async {
    var attempt = 0;
    while (true) {
      attempt += 1;
      try {
        return await operation();
      } on DonorSetupApiException catch (error) {
        final canRetry = _isRetryable(error, policy) && attempt < policy.maxAttempts;
        if (!canRetry) {
          rethrow;
        }
        await Future<void>.delayed(policy.backoffFor(attempt));
      }
    }
  }

  bool _isRetryable(DonorSetupApiException error, RetryPolicy policy) {
    if (error is DonorSetupNetworkException ||
        error is DonorSetupTimeoutException) {
      return true;
    }
    if (error is DonorSetupServerException) {
      return policy.retryOnServerError;
    }
    return false;
  }

  _ParsedError _safeParseError(String body) {
    if (body.isEmpty) {
      return const _ParsedError();
    }
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        return _ParsedError(
          code: decoded['code']?.toString(),
          message: decoded['message']?.toString(),
        );
      }
    } on FormatException {
      // Fall through to raw body fallback below.
    }
    return _ParsedError(message: body);
  }
}

class _ParsedError {
  const _ParsedError({this.code, this.message});

  final String? code;
  final String? message;
}
