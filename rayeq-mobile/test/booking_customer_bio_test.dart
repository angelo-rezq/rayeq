import 'forms_review_test.dart' show capture;

import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rayeq/live.dart';
import 'package:rayeq/localization.dart';
import 'package:rayeq/review_fixtures.dart';
import 'package:rayeq/royal_theme.dart';

String fixtureText(String ar, String en) =>
    appLocale.value.languageCode == 'en' ? en : ar;

class BioBookingApi extends ReviewApi {
  BioBookingApi(String role) : super(role: role);
  @override
  Future<dynamic> request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? query,
    String? idempotencyKey,
  }) async {
    final data = await super.request(
      method,
      path,
      body: body,
      query: query,
      idempotencyKey: idempotencyKey,
    );
    if (path.startsWith('bookings/') || path.startsWith('worker/bookings/'))
      return {
        ...data as Map<String, dynamic>,
        'customerProfile': {
          'name': fixtureText('اسم صاحب الحساب', 'Booking account name'),
          'bio': fixtureText(
            'نبذة ظاهرة للحلاق في الحجز',
            'Visible booking bio',
          ),
        },
      };
    if (path == 'bookings' || path == 'worker/bookings')
      return {
        ...data as Map<String, dynamic>,
        'items': [
          {
            ...reviewBooking(),
            'customerProfile': {
              'name': fixtureText('اسم صاحب الحساب', 'Booking account name'),
              'bio': fixtureText(
                'نبذة ظاهرة للحلاق في الحجز',
                'Visible booking bio',
              ),
            },
          },
        ],
      };
    return data;
  }
}

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
  for (final lang in ['ar', 'en']) {
    for (final role in ['worker', 'customer']) {
      testWidgets(
        'booking customer bio uses authorized worker view, role $role $lang',
        (t) async {
          t.view.devicePixelRatio = 1;
          t.view.physicalSize = const Size(390, 844);
          addTearDown(() {
            t.view.resetDevicePixelRatio();
            t.view.resetPhysicalSize();
          });
          final boundary = GlobalKey();
          appLocale.value = Locale(lang);
          SharedPreferences.setMockInitialValues({});
          await t.pumpWidget(
            RepaintBoundary(
              key: boundary,
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                locale: Locale(lang),
                supportedLocales: const [Locale('en'), Locale('ar', 'EG')],
                localizationsDelegates: GlobalMaterialLocalizations.delegates,
                theme: rayeqTheme(),
                builder: rayeqBackdrop,
                home: LiveShell(api: BioBookingApi(role)),
              ),
            ),
          );
          await t.pumpAndSettle();
          if (role == 'customer') {
            await t.tap(find.text(fixtureText('حجوزاتي', 'Bookings')).last);
            await t.pumpAndSettle();
          }
          expect(
            find.text(
              fixtureText('نبذة ظاهرة للحلاق في الحجز', 'Visible booking bio'),
            ),
            role == 'worker' ? findsOneWidget : findsNothing,
          );
          if (role == 'worker')
            expect(
              find.textContaining(
                fixtureText('اسم صاحب الحساب', 'Booking account name'),
              ),
              findsOneWidget,
            );
          if (role == 'worker') {
            await Scrollable.ensureVisible(
              t.element(
                find.text(
                  fixtureText(
                    'نبذة ظاهرة للحلاق في الحجز',
                    'Visible booking bio',
                  ),
                ),
              ),
              alignment: .45,
            );
            await t.pumpAndSettle();
            await capture(
              t,
              boundary,
              'build3-worker-booking-customer-bio-$lang',
            );
          }
          final details = find.widgetWithText(
            OutlinedButton,
            fixtureText('تفاصيل الزيارة', 'Visit details'),
          );
          await t.ensureVisible(details);
          await t.pumpAndSettle();
          await t.tap(details);
          await t.pumpAndSettle();
          expect(
            find.text(
              fixtureText('نبذة ظاهرة للحلاق في الحجز', 'Visible booking bio'),
            ),
            role == 'worker' ? findsOneWidget : findsNothing,
          );
          if (role == 'worker') {
            await Scrollable.ensureVisible(
              t.element(
                find.text(
                  fixtureText(
                    'نبذة ظاهرة للحلاق في الحجز',
                    'Visible booking bio',
                  ),
                ),
              ),
              alignment: .45,
            );
            await t.pumpAndSettle();
            await capture(
              t,
              boundary,
              'build3-worker-details-customer-bio-$lang',
            );
          }
          expect(t.takeException(), isNull);
        },
      );
    }
  }
}
