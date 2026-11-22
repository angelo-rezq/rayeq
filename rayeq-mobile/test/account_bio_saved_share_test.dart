import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rayeq/api.dart';
import 'package:rayeq/localization.dart';
import 'package:rayeq/profile.dart';
import 'package:rayeq/royal_theme.dart';
import 'package:rayeq/saved_barbers.dart';

Widget host(Widget child) => MaterialApp(
  locale: const Locale('en'),
  supportedLocales: const [Locale('en'), Locale('ar', 'EG')],
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  theme: rayeqTheme(),
  builder: rayeqBackdrop,
  home: Scaffold(body: SingleChildScrollView(child: child)),
);
void main() {
  setUp(() {
    appLocale.value = const Locale('en');
  });
  testWidgets(
    'optional account bio patches its own profile field and can be cleared',
    (t) async {
      String bio = '';
      final payloads = <Map<String, dynamic>>[];
      final api = RayeqApi(
        baseUrl: 'https://example.com/api/v1',
        client: MockClient((r) async {
          expect(r.url.path, '/api/v1/profile');
          if (r.method == 'PATCH') {
            final body = Map<String, dynamic>.from(jsonDecode(r.body));
            payloads.add(body);
            bio = body['bio'] as String;
          }
          return http.Response(
            jsonEncode({
              'data': {
                'id': 'customer',
                'name': 'Sample customer',
                'role': 'customer',
                'bio': bio,
              },
            }),
            200,
          );
        }),
      );
      await t.pumpWidget(
        host(
          ProfilePanel(
            api: api,
            initialUser: const {'id': 'customer', 'role': 'customer'},
            onPassword: () {},
            onLogout: () {},
            onChanged: (_) {},
          ),
        ),
      );
      await t.pumpAndSettle();
      for (final value in ['A short private bio.', '']) {
        final edit = find.widgetWithText(OutlinedButton, 'Edit bio');
        await t.ensureVisible(edit);
        await t.pumpAndSettle();
        await t.tap(edit);
        await t.pumpAndSettle();
        expect(t.widget<TextField>(find.byType(TextField)).maxLength, 1500);
        await t.enterText(find.byType(TextField), value);
        await t.tap(find.widgetWithText(FilledButton, 'Save'));
        await t.pumpAndSettle();
        expect(payloads.last, {'bio': value});
        await t.pump(const Duration(milliseconds: 400));
      }
      expect(payloads.length, 2);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'saved API barber opens, favorite toggles and native share contains only a public summary',
    (t) async {
      var toggles = 0;
      MethodCall? shared;
      const channel = MethodChannel('rayeq/app_updates');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            shared = call;
            return 'opened';
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      final api = RayeqApi(
        baseUrl: 'https://example.com/api/v1',
        client: MockClient((r) async {
          final data =
              r.url.path.endsWith('/reviews') || r.url.path.endsWith('/gallery')
              ? {'items': []}
              : {
                  'id': 'employee-1',
                  'nameAr': 'نموذج',
                  'nameEn': 'Avery Demo',
                  'titleEn': 'Demo barber',
                  'demoOnly': true,
                };
          return http.Response(
            jsonEncode({'data': data}),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      await t.pumpWidget(
        host(
          SavedPublicBarbers(
            api: api,
            ids: const ['employee-1'],
            onSave: (_) {
              toggles++;
            },
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('Avery Demo'), findsOneWidget);
      await t.tap(find.text('Avery Demo'));
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('Remove from saved'));
      await t.pumpAndSettle();
      expect(toggles, 1);
      expect(find.byTooltip('Save barber'), findsOneWidget);
      await t.tap(find.byTooltip('Share profile'));
      await t.pumpAndSettle();
      expect(shared?.method, 'shareProfile');
      final text = (shared?.arguments as Map)['text'] as String;
      expect(text, contains('Avery Demo'));
      expect(text, contains('Demonstration profile'));
      expect(text, isNot(contains('https://')));
      expect(t.takeException(), isNull);
    },
  );
}
