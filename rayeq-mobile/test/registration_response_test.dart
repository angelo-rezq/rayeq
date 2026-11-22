import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rayeq/api.dart';
import 'package:rayeq/live.dart';
import 'package:rayeq/localization.dart';
import 'package:rayeq/bottom_bar.dart';
import 'package:rayeq/royal_theme.dart';

import 'all_pages_review_test.dart' show profile, catalog;
import 'forms_review_test.dart' show capture;

void main() {
  setUpAll(() async {
    await (FontLoader('PlexArabic')
          ..addFont(rootBundle.load('assets/fonts/PlexArabic-400.ttf'))
          ..addFont(rootBundle.load('assets/fonts/PlexArabic-600.ttf')))
        .load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  for (final role in ['customer', 'worker']) {
    for (final response in ['login', 'token', 'session', 'verify', 'legacy']) {
      testWidgets('register $role honors $response response', (t) async {
        t.view.physicalSize = const Size(390, 844);
        t.view.devicePixelRatio = 1;
        addTearDown(() {
          t.view.resetPhysicalSize();
          t.view.resetDevicePixelRatio();
        });
        FlutterSecureStorage.setMockInitialValues({});
        SharedPreferences.setMockInitialValues({});
        appLocale.value = const Locale('en');
        final calls = <String>[];
        final api = RayeqApi(
          baseUrl: 'https://example.com/api/v1',
          client: MockClient((r) async {
            final path = r.url.path.replaceFirst('/api/v1/', '');
            calls.add(path);
            dynamic data;
            if (path == 'auth/register') {
              final submitted = jsonDecode(r.body) as Map;
              expect(submitted['accountType'], role);
              data = switch (response) {
                'login' => {'next': 'login'},
                'token' => {'token': 'fictional-test-session'},
                'session' => {
                  'session': {'token': 'fictional-test-session'},
                },
                'verify' => {'next': 'verify'},
                _ => <String, dynamic>{},
              };
            } else if (path == 'me') {
              data = profile(role);
            } else if (path == 'catalog') {
              data = catalog;
            } else if (path == 'bookings' || path == 'worker/bookings') {
              data = {'items': []};
            } else if (path == 'barbers/featured') {
              data = {'items': []};
            } else {
              data = <String, dynamic>{};
            }
            return http.Response(
              jsonEncode({'data': data}),
              path == 'auth/register' ? 202 : 200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }),
        );
        final boundary = GlobalKey();
        await t.pumpWidget(
          RepaintBoundary(
            key: boundary,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              locale: const Locale('en'),
              supportedLocales: const [Locale('en'), Locale('ar', 'EG')],
              localizationsDelegates: GlobalMaterialLocalizations.delegates,
              theme: rayeqTheme(),
              builder: rayeqBackdrop,
              home: LiveShell(
                api: api,
                initialScreen: 'register',
                initialWorker: role == 'worker',
              ),
            ),
          ),
        );
        await t.pumpAndSettle();
        await t.enterText(find.byType(TextField).at(0), 'Fictional Test');
        await t.enterText(find.byType(TextField).at(1), 'test@example.com');
        await t.enterText(
          find.byType(TextField).at(2),
          'fictional-test-password',
        );
        FocusManager.instance.primaryFocus?.unfocus();
        t.testTextInput.hide();
        await t.pumpAndSettle();
        final submit = find.widgetWithText(
          FilledButton,
          role == 'worker'
              ? 'Create barber account'
              : 'Create customer account',
        );
        await t.ensureVisible(submit);
        await t.tap(submit);
        await t.pumpAndSettle();
        final hasSession = response == 'token' || response == 'session';
        expect(api.signedIn, hasSession);
        expect(calls.contains('me'), hasSession);
        if (hasSession) {
          expect(find.byType(RoyalNavigationBar), findsOneWidget);
          expect(find.text('Verification code'), findsNothing);
        } else if (response == 'login') {
          expect(find.text('Welcome to Rayeq'), findsOneWidget);
          expect(find.text('Verification code'), findsNothing);
          final inputs = t
              .widgetList<TextField>(find.byType(TextField))
              .toList();
          expect(inputs.first.controller!.text, 'test@example.com');
          expect(inputs.last.controller!.text, isEmpty);
          await capture(t, boundary, 'register-no-code-$role-en');
        } else {
          expect(find.text('Verification code'), findsOneWidget);
        }
        expect(t.takeException(), isNull);
      });
    }
  }
}
