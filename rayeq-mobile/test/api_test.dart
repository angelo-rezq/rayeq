import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rayeq/api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  test(
    'unconfigured API fails explicitly instead of pretending success',
    () async {
      final api = RayeqApi();
      await expectLater(
        api.getMap('catalog'),
        throwsA(
          isA<ApiFailure>().having((e) => e.code, 'code', 'NOT_CONFIGURED'),
        ),
      );
    },
  );
  test('only secure deployed endpoints are allowed', () async {
    final api = RayeqApi(baseUrl: 'http://example.com/api/v1');
    await expectLater(
      api.getMap('catalog'),
      throwsA(
        isA<ApiFailure>().having((e) => e.code, 'code', 'INSECURE_ENDPOINT'),
      ),
    );
  });
  test(
    'client preserves prefix, bearer identity, UTF8, and retry key',
    () async {
      final api = RayeqApi(
        baseUrl: 'https://example.com/api/v1',
        client: MockClient((req) async {
          expect(req.url.toString(), 'https://example.com/api/v1/bookings');
          expect(req.headers['Authorization'], 'Bearer test-only-token');
          expect(req.headers['Idempotency-Key'], 'same-retry-key');
          expect(jsonDecode(req.body)['customerName'], 'اسم اختبار');
          return http.Response(
            jsonEncode({
              'data': {'reference': 'TST'},
            }),
            201,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      await api.saveSession({'token': 'test-only-token'});
      final r = await api.post('bookings', {
        'customerName': 'اسم اختبار',
      }, idempotencyKey: 'same-retry-key');
      expect(r['reference'], 'TST');
    },
  );
  test('unauthorized response clears the saved session', () async {
    final api = RayeqApi(
      baseUrl: 'https://example.com/api/v1',
      client: MockClient(
        (_) async => http.Response('{"error":{"code":"AUTH_REQUIRED"}}', 401),
      ),
    );
    await api.saveSession({'token': 'test-only-token'});
    await expectLater(
      api.getMap('me'),
      throwsA(isA<ApiFailure>().having((e) => e.status, 'status', 401)),
    );
    expect(api.signedIn, false);
    await api.restore();
    expect(api.signedIn, false);
  });
  test('provider text and server internals are never exposed', () async {
    final api = RayeqApi(
      baseUrl: 'https://example.com/api/v1',
      client: MockClient(
        (_) async => http.Response(
          '{"error":{"code":"UNKNOWN","message":"private-test-marker"}}',
          500,
        ),
      ),
    );
    await expectLater(
      api.getMap('me'),
      throwsA(
        isA<ApiFailure>().having(
          (e) => e.message.contains('private-test-marker'),
          'leak',
          false,
        ),
      ),
    );
  });
  test('idempotency identifiers are UUIDs and differ', () {
    final ids = List.generate(100, (_) => RayeqApi.idempotencyKey());
    expect(ids.toSet().length, 100);
    for (final id in ids) {
      expect(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ).hasMatch(id),
        true,
      );
    }
  });
}
