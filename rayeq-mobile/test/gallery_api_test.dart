import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rayeq/api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  test(
    'gallery uses raw bytes, bearer identity and 201 photo envelope',
    () async {
      final bytes = Uint8List.fromList([255, 216, 255, 0, 1, 2]);
      final api = RayeqApi(
        baseUrl: 'https://example.com/api/v1',
        client: MockClient((r) async {
          expect(r.method, 'POST');
          expect(r.url.path, '/api/v1/worker/gallery');
          expect(r.headers['Authorization'], 'Bearer test-only-token');
          expect(r.headers['Content-Type'], 'image/jpeg');
          expect(r.bodyBytes, bytes);
          return http.Response(
            jsonEncode({
              'data': {
                'id': 'photo1',
                'url': 'https://example.com/photo.webp',
                'byteSize': 6,
              },
            }),
            201,
          );
        }),
      );
      await api.saveSession({'token': 'test-only-token'});
      final photo = await api.uploadWorkPhoto(bytes, 'image/jpeg');
      expect(photo['id'], 'photo1');
    },
  );
  test('gallery rejects over-5MiB files before transport', () async {
    var calls = 0;
    final api = RayeqApi(
      baseUrl: 'https://example.com/api/v1',
      client: MockClient((_) async {
        calls++;
        return http.Response('{}', 500);
      }),
    );
    await expectLater(
      api.uploadWorkPhoto(Uint8List(5 * 1024 * 1024 + 1), 'image/jpeg'),
      throwsA(
        isA<ApiFailure>().having((e) => e.code, 'code', 'PHOTO_TOO_LARGE'),
      ),
    );
    expect(calls, 0);
  });
  test(
    'gallery delete accepts 204, review conflicts retain server codes',
    () async {
      final api = RayeqApi(
        baseUrl: 'https://example.com/api/v1',
        client: MockClient((r) async {
          if (r.method == 'DELETE') return http.Response('', 204);
          expect(r.url.path, '/api/v1/bookings/booking1/review');
          expect(jsonDecode(r.body), {'rating': 5, 'text': 'Good visit'});
          return http.Response(
            jsonEncode({
              'error': {
                'code': 'REVIEW_ALREADY_EXISTS',
                'message': 'provider details',
              },
            }),
            409,
          );
        }),
      );
      expect(await api.request('DELETE', 'worker/gallery/photo1'), isNull);
      await expectLater(
        api.post('bookings/booking1/review', {
          'rating': 5,
          'text': 'Good visit',
        }),
        throwsA(
          isA<ApiFailure>()
              .having((e) => e.code, 'code', 'REVIEW_ALREADY_EXISTS')
              .having((e) => e.status, 'status', 409),
        ),
      );
    },
  );
}
