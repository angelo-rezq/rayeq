import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rayeq/api.dart';
import 'package:rayeq/localization.dart';
import 'package:rayeq/royal_theme.dart';
import 'package:rayeq/worker_public_profile.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    appLocale.value = const Locale('en');
  });
  test('portrait upload uses PUT, raw bytes, bearer token and the flat profile response', () async {
    final bytes = Uint8List.fromList([255, 216, 255, 0, 1]);
    final api = RayeqApi(
      baseUrl: 'https://example.com/api/v1',
      client: MockClient((r) async {
        expect(r.method, 'PUT');
        expect(r.url.path, '/api/v1/worker/public-profile/portrait');
        expect(r.headers['Authorization'], 'Bearer test-only-token');
        expect(r.headers['Content-Type'], 'image/jpeg');
        expect(r.bodyBytes, bytes);
        return http.Response(
          '{"data":{"portraitUrl":"https://example.com/p.webp?v=2","titleEn":"Barber"}}',
          200,
        );
      }),
    );
    await api.saveSession({'token': 'test-only-token'});
    final result = await api.uploadPublicPortrait(bytes, 'image/jpeg');
    expect(result['titleEn'], 'Barber');
  });
  test('portrait rejects an over-5MiB image before making a request', () async {
    var calls = 0;
    final api = RayeqApi(
      baseUrl: 'https://example.com/api/v1',
      client: MockClient((_) async {
        calls++;
        return http.Response('{}', 500);
      }),
    );
    await expectLater(
      api.uploadPublicPortrait(Uint8List(5 * 1024 * 1024 + 1), 'image/jpeg'),
      throwsA(isA<ApiFailure>()),
    );
    expect(calls, 0);
  });
  Future<void> editor(WidgetTester t, RayeqApi api) async {
    await t.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: const [Locale('en'), Locale('ar', 'EG')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: rayeqTheme(),
        builder: rayeqBackdrop,
        home: WorkerPublicProfileEditor(api: api),
      ),
    );
    await t.pumpAndSettle();
  }

  testWidgets(
    'public profile editor saves only editable public fields in the flat schema',
    (t) async {
      Map<String, dynamic>? payload;
      final api = RayeqApi(
        baseUrl: 'https://example.com/api/v1',
        client: MockClient((r) async {
          expect(r.url.path, '/api/v1/worker/public-profile');
          if (r.method == 'PATCH')
            payload = Map<String, dynamic>.from(jsonDecode(r.body));
          return http.Response(
            jsonEncode({
              'data': {
                'titleEn': 'Barber',
                'specialtiesAr': [],
                'specialtiesEn': ['Haircuts'],
                'yearsExperience': 6,
              },
            }),
            200,
          );
        }),
      );
      await editor(t, api);
      await t.enterText(find.byType(TextFormField).at(3), 'Stylist');
      FocusManager.instance.primaryFocus?.unfocus();
      t.testTextInput.hide();
      await t.pumpAndSettle();
      await t.ensureVisible(
        find.widgetWithText(FilledButton, 'Save public profile'),
      );
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(FilledButton, 'Save public profile'));
      await t.pumpAndSettle();
      expect(payload?['titleEn'], 'Stylist');
      expect(payload?['yearsExperience'], 6);
      expect(payload?.keys.toSet(), {
        'titleAr',
        'titleEn',
        'bioAr',
        'bioEn',
        'specialtiesAr',
        'specialtiesEn',
        'yearsExperience',
      });
      expect(find.text('Public profile saved.'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'public profile editor rejects invalid years before sending PATCH',
    (t) async {
      var patches = 0;
      final api = RayeqApi(
        baseUrl: 'https://example.com/api/v1',
        client: MockClient((r) async {
          if (r.method == 'PATCH') patches++;
          return http.Response(
            '{"data":{"specialtiesAr":[],"specialtiesEn":[]}}',
            200,
          );
        }),
      );
      await editor(t, api);
      await t.enterText(find.byType(TextFormField).at(4), '81');
      FocusManager.instance.primaryFocus?.unfocus();
      t.testTextInput.hide();
      await t.pumpAndSettle();
      await t.ensureVisible(
        find.widgetWithText(FilledButton, 'Save public profile'),
      );
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(FilledButton, 'Save public profile'));
      await t.pumpAndSettle();
      expect(patches, 0);
      expect(find.text('Use a number from 0 to 80.'), findsOneWidget);
    },
  );
}
