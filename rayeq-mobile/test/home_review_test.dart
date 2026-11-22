import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rayeq/api.dart';
import 'package:rayeq/customer_home.dart';
import 'package:rayeq/localization.dart';
import 'package:rayeq/royal_theme.dart';
import 'package:rayeq/bottom_bar.dart';

import 'forms_review_test.dart' show catalog, capture;

void main() {
  testWidgets(
    'reference home fits AR and EN phones without reading location or searching automatically',
    (t) async {
      t.view.devicePixelRatio = 1;
      addTearDown(() {
        t.view.resetPhysicalSize();
        t.view.resetDevicePixelRatio();
      });
      await (FontLoader('PlexArabic')
            ..addFont(rootBundle.load('assets/fonts/PlexArabic-400.ttf'))
            ..addFont(rootBundle.load('assets/fonts/PlexArabic-600.ttf')))
          .load();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
      var calls = 0, reads = 0;
      final api = RayeqApi(
        baseUrl: 'https://example.com/api/v1',
        client: MockClient((r) async {
          if (r.url.path.endsWith('/barbers/nearby')) calls++;
          return http.Response(
            jsonEncode({
              'data': {'barbers': []},
            }),
            200,
          );
        }),
      );
      for (final language in ['ar', 'en']) {
        appLocale.value = language == 'ar'
            ? const Locale('ar', 'EG')
            : const Locale('en');
        for (final width in [320, 390, 430]) {
          t.view.physicalSize = Size(width.toDouble(), 844);
          final boundary = GlobalKey();
          await t.pumpWidget(
            RepaintBoundary(
              key: boundary,
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                locale: appLocale.value,
                supportedLocales: const [Locale('ar', 'EG'), Locale('en')],
                localizationsDelegates: GlobalMaterialLocalizations.delegates,
                theme: rayeqTheme(),
                builder: rayeqBackdrop,
                home: Scaffold(
                  body: ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      CustomerHome(
                        api: api,
                        user: {
                          'name': language == 'ar'
                              ? 'كريم أحمد'
                              : 'Karim Ahmed',
                        },
                        catalog: {...catalog, 'isDemo': true},
                        savedIds: {},
                        onAccount: () {},
                        onLanguage: () {},
                        onServices: () {},
                        onDemo: (_) {},
                        onSave: (_) {},
                        onBook: (_, __) {},
                        onService: (_) {},
                        locationReader: () async {
                          reads++;
                          return {'latitude': 30.05, 'longitude': 31.24};
                        },
                      ),
                    ],
                  ),
                  bottomNavigationBar: RoyalNavigationBar(
                    selectedIndex: 0,
                    onDestinationSelected: (_) {},
                    destinations: [
                      NavigationDestination(
                        icon: const Icon(Icons.home_outlined),
                        label: language == 'ar' ? 'الرئيسية' : 'Home',
                      ),
                      NavigationDestination(
                        icon: const Icon(Icons.content_cut),
                        label: language == 'ar' ? 'الخدمات' : 'Services',
                      ),
                      NavigationDestination(
                        icon: const Icon(Icons.calendar_month_outlined),
                        label: language == 'ar' ? 'حجوزاتي' : 'Bookings',
                      ),
                      NavigationDestination(
                        icon: const Icon(Icons.favorite_border),
                        label: language == 'ar' ? 'المحفوظات' : 'Saved',
                      ),
                      NavigationDestination(
                        icon: const Icon(Icons.person_outline),
                        label: language == 'ar' ? 'حسابي' : 'Account',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
          await t.pumpAndSettle();
          expect(t.takeException(), isNull, reason: '$language $width');
          await capture(t, boundary, 'home-reference-$language-$width');
          await t.drag(find.byType(Scrollable).first, const Offset(0, -600));
          await t.pumpAndSettle();
          expect(t.takeException(), isNull);
          await capture(t, boundary, 'home-reference-lower-$language-$width');
          await t.pumpWidget(const SizedBox.shrink());
          await t.pumpAndSettle();
        }
      }
      expect(calls, 0);
      expect(reads, 0);
    },
  );
}
