import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sharebridge_mobile_app/features/donor_setup/data/auth_context.dart';
import 'package:sharebridge_mobile_app/features/donor_setup/data/donor_setup_api_exceptions.dart';
import 'package:sharebridge_mobile_app/features/donor_setup/data/http_donor_setup_api_client.dart';

typedef _Handler = FutureOr<void> Function(HttpRequest request);

class _ScriptedServer {
  _ScriptedServer(this._handler);

  final _Handler _handler;
  late final HttpServer _server;
  int requestCount = 0;

  Future<String> start() async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server.listen((HttpRequest request) async {
      requestCount += 1;
      await _handler(request);
    });
    return 'http://${_server.address.host}:${_server.port}';
  }

  Future<void> stop() => _server.close(force: true);
}

void main() {
  test('suggestVendors retries 5xx and ultimately succeeds', () async {
    var attempts = 0;
    final server = _ScriptedServer((HttpRequest request) async {
      attempts += 1;
      if (attempts < 3) {
        request.response.statusCode = 503;
        await request.response.close();
        return;
      }
      request.response
        ..statusCode = 200
        ..headers.contentType = ContentType.json
        ..write(
          jsonEncode(<String, dynamic>{
            'suggestions': <Map<String, dynamic>>[
              <String, dynamic>{
                'restaurant_name': 'A2B',
                'menu_items': <String>['Mini Meals'],
                'order_url': 'https://example.com',
                'app_name': 'Zomato',
                'confidence': 0.9,
              },
            ],
            'generated_at': '2026-05-07T00:00:00Z',
          }),
        );
      await request.response.close();
    });
    final baseUrl = await server.start();
    addTearDown(server.stop);

    final client = HttpDonorSetupApiClient(
      baseUrl: baseUrl,
      retryPolicy: const RetryPolicy(
        maxAttempts: 3,
        initialBackoff: Duration(milliseconds: 1),
      ),
    );

    final response = await client.suggestVendors(
      queryText: 'zomato',
      lat: null,
      lng: null,
      manualArea: 'Chennai',
    );

    expect(attempts, 3);
    expect(response['suggestions'], isA<List<dynamic>>());
  });

  test('suggestVendors maps persistent 5xx to DonorSetupServerException',
      () async {
    final server = _ScriptedServer((HttpRequest request) async {
      request.response.statusCode = 500;
      request.response.write('{"code":"persistence_error","message":"boom"}');
      await request.response.close();
    });
    final baseUrl = await server.start();
    addTearDown(server.stop);

    final client = HttpDonorSetupApiClient(
      baseUrl: baseUrl,
      retryPolicy: const RetryPolicy(
        maxAttempts: 2,
        initialBackoff: Duration(milliseconds: 1),
      ),
    );

    await expectLater(
      client.suggestVendors(
        queryText: 'zomato',
        lat: null,
        lng: null,
        manualArea: 'Chennai',
      ),
      throwsA(
        isA<DonorSetupServerException>().having(
          (DonorSetupServerException e) => e.statusCode,
          'statusCode',
          500,
        ),
      ),
    );
    expect(server.requestCount, 2);
  });

  test('suggestVendors maps 4xx to DonorSetupBadRequestException with code',
      () async {
    final server = _ScriptedServer((HttpRequest request) async {
      request.response.statusCode = 400;
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        '{"code":"invalid_request","message":"query_text is required."}',
      );
      await request.response.close();
    });
    final baseUrl = await server.start();
    addTearDown(server.stop);

    final client = HttpDonorSetupApiClient(
      baseUrl: baseUrl,
      retryPolicy: const RetryPolicy(maxAttempts: 1),
    );

    await expectLater(
      client.suggestVendors(
        queryText: 'x',
        lat: null,
        lng: null,
        manualArea: 'Chennai',
      ),
      throwsA(
        isA<DonorSetupBadRequestException>()
            .having((e) => e.statusCode, 'statusCode', 400)
            .having((e) => e.errorCode, 'errorCode', 'invalid_request'),
      ),
    );
    // 4xx is not retryable.
    expect(server.requestCount, 1);
  });

  test('suggestVendors maps malformed JSON body to DonorSetupResponseException',
      () async {
    final server = _ScriptedServer((HttpRequest request) async {
      request.response.statusCode = 200;
      request.response.headers.contentType = ContentType.json;
      request.response.write('not-json');
      await request.response.close();
    });
    final baseUrl = await server.start();
    addTearDown(server.stop);

    final client = HttpDonorSetupApiClient(
      baseUrl: baseUrl,
      retryPolicy: const RetryPolicy(maxAttempts: 1),
    );

    await expectLater(
      client.suggestVendors(
        queryText: 'zomato',
        lat: null,
        lng: null,
        manualArea: 'Chennai',
      ),
      throwsA(isA<DonorSetupResponseException>()),
    );
  });

  test('client sends Bearer signed-token header', () async {
    final List<String> sawAuthorization = <String>[];
    final server = _ScriptedServer((HttpRequest request) async {
      sawAuthorization
          .add(request.headers.value('authorization') ?? '<missing>');
      request.response
        ..statusCode = 200
        ..headers.contentType = ContentType.json
        ..write(
          jsonEncode(<String, dynamic>{
            'suggestions': <Map<String, dynamic>>[],
            'generated_at': '2026-05-07T00:00:00Z',
          }),
        );
      await request.response.close();
    });
    final baseUrl = await server.start();
    addTearDown(server.stop);

    final client = HttpDonorSetupApiClient(
      baseUrl: baseUrl,
      authContext: const AuthContext(userId: 'alice', authToken: 'jwt-alice'),
      retryPolicy: const RetryPolicy(maxAttempts: 1),
    );

    await client.suggestVendors(
      queryText: 'zomato',
      lat: null,
      lng: null,
      manualArea: 'Chennai',
    );

    expect(sawAuthorization.single, 'Bearer jwt-alice');
  });

  test('savePresets does not retry on 5xx (mutating policy)', () async {
    final server = _ScriptedServer((HttpRequest request) async {
      request.response.statusCode = 500;
      await request.response.close();
    });
    final baseUrl = await server.start();
    addTearDown(server.stop);

    final client = HttpDonorSetupApiClient(
      baseUrl: baseUrl,
      savePresetsRetryPolicy: const RetryPolicy(
        maxAttempts: 3,
        initialBackoff: Duration(milliseconds: 1),
        retryOnServerError: false,
      ),
    );

    await expectLater(
      client.savePresets(
        userId: 'demo-user',
        payload: <Map<String, dynamic>>[
          <String, dynamic>{
            'restaurant_name': 'A2B',
            'order_url': 'https://example.com',
            'menu_items': <String>['Meals'],
            'app_name': 'Zomato',
          },
        ],
      ),
      throwsA(isA<DonorSetupServerException>()),
    );
    expect(server.requestCount, 1);
  });
}
