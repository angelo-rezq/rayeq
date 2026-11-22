import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rayeq/api.dart';
import 'package:rayeq/barber_profiles.dart';
import 'package:rayeq/localization.dart';
import 'package:rayeq/royal_theme.dart';

const employeeId = 'ee062ce8-cac2-491e-8cf3-2077f3be3815';
const detail = {
  'id': employeeId,
  'nameAr': 'أحمد حسن',
  'nameEn': 'Ahmed Hassan',
  'ratingAverage': 5,
  'reviewCount': 1,
  'gallery': {'items': []},
};
Widget profile(RayeqApi api) => MaterialApp(
  locale: const Locale('en'),
  supportedLocales: const [Locale('en'), Locale('ar', 'EG')],
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  theme: rayeqTheme(),
  builder: rayeqBackdrop,
  home: LiveBarberProfile(
    api: api,
    barber: const {
      'id': employeeId,
      'nameAr': 'أحمد حسن',
      'nameEn': 'Ahmed Hassan',
    },
  ),
);
void main() {
  setUp(() => appLocale.value = const Locale('en'));
  testWidgets(
    'a failed reviews section preserves detail, rating and embedded gallery',
    (t) async {
      final paths = <String>[];
      final api = RayeqApi(
        baseUrl: 'https://example.com/api/v1',
        client: MockClient((r) async {
          paths.add(r.url.path);
          if (r.url.path.endsWith('/reviews'))
            return http.Response('{"error":{"code":"RATE_LIMITED"}}', 429);
          if (r.url.path.endsWith('/gallery'))
            return http.Response('{"error":{"code":"UNAVAILABLE"}}', 503);
          return http.Response(
            jsonEncode({'data': detail}),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      await t.pumpWidget(profile(api));
      await t.pumpAndSettle();
      expect(find.text('Ahmed Hassan'), findsOneWidget);
      expect(find.text('5.0'), findsOneWidget);
      expect(find.textContaining('Reviews:'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
      expect(paths.every((path) => path.contains(employeeId)), isTrue);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets('a failed detail section does not discard successful reviews', (
    t,
  ) async {
    final api = RayeqApi(
      baseUrl: 'https://example.com/api/v1',
      client: MockClient((r) async {
        if (r.url.path.endsWith('/reviews'))
          return http.Response(
            jsonEncode({
              'data': {
                'items': [
                  {
                    'id': 'review',
                    'rating': 5,
                    'text': 'Excellent service',
                    'customerDisplayName': 'Customer',
                  },
                ],
                'ratingAverage': 5,
                'reviewCount': 1,
                'nextCursor': null,
              },
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        if (r.url.path.endsWith('/gallery'))
          return http.Response('{"data":{"items":[]}}', 200);
        return http.Response('{"error":{"code":"UNAVAILABLE"}}', 503);
      }),
    );
    await t.pumpWidget(profile(api));
    await t.pumpAndSettle();
    expect(find.text('Ahmed Hassan'), findsOneWidget);
    await t.drag(find.byType(ListView).first, const Offset(0, -900));
    await t.pumpAndSettle();
    expect(find.text('Excellent service'), findsOneWidget);
    expect(find.text('5.0'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
  testWidgets('profile retry recovers the failed section without navigation', (
    t,
  ) async {
    var failed = true;
    final api = RayeqApi(
      baseUrl: 'https://example.com/api/v1',
      client: MockClient((r) async {
        if (r.url.path.endsWith('/reviews')) {
          if (failed)
            return http.Response('{"error":{"code":"UNAVAILABLE"}}', 503);
          return http.Response('{"data":{"items":[],"reviewCount":0}}', 200);
        }
        if (r.url.path.endsWith('/gallery'))
          return http.Response('{"data":{"items":[]}}', 200);
        return http.Response(
          jsonEncode({'data': detail}),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    await t.pumpWidget(profile(api));
    await t.pumpAndSettle();
    failed = false;
    await t.ensureVisible(find.text('Try again'));
    await t.pumpAndSettle();
    await t.tap(find.text('Try again'));
    await t.pumpAndSettle();
    expect(find.text('Try again'), findsNothing);
    expect(find.text('No reviews yet'), findsOneWidget);
    expect(find.text('Ahmed Hassan'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
