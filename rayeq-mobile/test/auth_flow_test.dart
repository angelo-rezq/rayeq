import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rayeq/api.dart';
import 'package:rayeq/main.dart';

Future<void> login(WidgetTester tester, RayeqApi api) async {
  await tester.pumpWidget(RayeqApp(api: api));
  await tester.pumpAndSettle();
  await tester.tap(find.text('خلّينا نبدأ'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField).at(0), 'test@example.com');
  await tester.enterText(find.byType(TextField).at(1), 'Test-only-password-9');
  await tester.tap(find.widgetWithText(FilledButton, 'دخول'));
  await tester.pumpAndSettle();
  await tester.runAsync(() async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
  });
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  testWidgets(
    'unverified login stays at email verification and never fetches bookings',
    (tester) async {
      final paths = <String>[];
      final api = RayeqApi(
        baseUrl: 'https://example.com/api/v1',
        client: MockClient((r) async {
          paths.add(r.url.path);
          return http.Response(
            jsonEncode({
              'error': {'code': 'EMAIL_NOT_VERIFIED'},
            }),
            403,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      await login(tester, api);
      expect(find.text('بص على إيميلك'), findsOneWidget);
      expect(paths, ['/api/v1/auth/login']);
    },
  );
  testWidgets(
    'pending worker sees approval notice without protected-data requests',
    (tester) async {
      final paths = <String>[];
      final api = RayeqApi(
        baseUrl: 'https://example.com/api/v1',
        client: MockClient((r) async {
          paths.add(r.url.path);
          if (r.url.path.endsWith('/auth/login'))
            return http.Response(
              jsonEncode({
                'data': {'token': 'test-token'},
              }),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          if (r.url.path.endsWith('/me'))
            return http.Response(
              jsonEncode({
                'data': {
                  'id': 'test-worker',
                  'role': 'worker_pending',
                  'name': 'اختبار',
                },
              }),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          throw StateError('Pending role attempted protected data');
        }),
      );
      await login(tester, api);
      expect(find.text('طلبك عند الإدارة'), findsOneWidget);
      expect(
        paths.every((p) => p.endsWith('/me') || p.endsWith('/auth/login')),
        true,
      );
    },
  );
  testWidgets(
    'empty live catalog never substitutes sample commercial services',
    (tester) async {
      final api = RayeqApi(
        baseUrl: 'https://example.com/api/v1',
        client: MockClient((r) async {
          final path = r.url.path;
          if (path.endsWith('/auth/login'))
            return http.Response(
              jsonEncode({
                'data': {'token': 'test-token'},
              }),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          if (path.endsWith('/me'))
            return http.Response(
              jsonEncode({
                'data': {
                  'id': 'test-customer',
                  'role': 'customer',
                  'name': 'اختبار',
                },
              }),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          if (path.endsWith('/catalog'))
            return http.Response(
              jsonEncode({
                'data': {'intakeEnabled': false, 'services': [], 'areas': []},
              }),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          if (path.endsWith('/bookings'))
            return http.Response(
              jsonEncode({
                'data': {'items': [], 'nextCursor': null},
              }),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          throw StateError('Unexpected endpoint');
        }),
      );
      await login(tester, api);
      expect(
        find.text('الخدمات هتظهر هنا بعد تجهيزها من الإدارة.'),
        findsOneWidget,
      );
      expect(find.text('قص وتصفيف الشعر'), findsNothing);
      expect(find.text('١٨٠ ج.م'), findsNothing);
    },
  );
}
