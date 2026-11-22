import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rayeq/api.dart';
import 'package:rayeq/live.dart';
import 'package:rayeq/localization.dart';
import 'package:rayeq/nearby.dart';
import 'package:rayeq/royal_theme.dart';

import 'forms_review_test.dart' show catalog, service;

http.Response ok(Map<String, dynamic> data) => http.Response(
  jsonEncode({'data': data}),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);
Future<GlobalKey> prepare(
  WidgetTester t,
  RayeqApi api,
  NearbySelection chosen,
) async {
  t.view.devicePixelRatio = 1;
  t.view.physicalSize = const Size(390, 844);
  addTearDown(() {
    t.view.resetPhysicalSize();
    t.view.resetDevicePixelRatio();
  });
  final boundary = GlobalKey();
  await t.pumpWidget(
    RepaintBoundary(
      key: boundary,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        builder: rayeqBackdrop,
        locale: appLocale.value,
        supportedLocales: const [Locale('ar', 'EG'), Locale('en')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: rayeqTheme(),
        home: BookingForm(
          api: api,
          service: service,
          catalog: catalog,
          customerName: 'Pilot customer',
          preferred: chosen,
        ),
      ),
    ),
  );
  await t.pumpAndSettle();
  for (final entry in {
    'موبايل للتواصل فقط': '+201000000000',
    'الشارع': 'Test street',
    'رقم العمارة': '1',
  }.entries) {
    final field = find.byKey(ValueKey(entry.key));
    await t.scrollUntilVisible(
      field,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await t.enterText(field, entry.value);
  }
  final kind = find.byKey(const ValueKey('booking-kind'));
  await t.scrollUntilVisible(
    kind,
    350,
    scrollable: find.byType(Scrollable).first,
  );
  await t.tap(kind);
  await t.pumpAndSettle();
  await t.tap(
    find.text(nearbyText('أقرب وقت متاح', 'As soon as available')).last,
  );
  await t.pumpAndSettle();
  final button = find.widgetWithText(
    FilledButton,
    nearbyText('مراجعة السعر وحجز الزيارة', 'Review price and book'),
  );
  await t.ensureVisible(button);
  await t.pumpAndSettle();
  await t.tap(button);
  await t.pumpAndSettle();
  return boundary;
}

void main() {
  setUp(() {
    appLocale.value = const Locale('en');
    FlutterSecureStorage.setMockInitialValues({});
  });
  final chosen = NearbySelection(
    barber: const {'id': 'b1', 'nameAr': 'أحمد حسن', 'nameEn': 'Ahmed Hassan'},
    location: const {'latitude': 30.05, 'longitude': 31.24},
    areaId: 'area-1',
  );
  for (final changed in [false, true]) {
    testWidgets(
      changed ? 'changed catalog blocks send after price review' : 'chosen barber and approximate location reach booking only after review',
      (t) async {
        var catalogs = 0;
        final calls = <String>[];
        Map<String, dynamic>? booking;
        final api = RayeqApi(
          baseUrl: 'https://example.com/api/v1',
          client: MockClient((r) async {
            final path = r.url.path.split('/').last;
            calls.add(path);
            if (path == 'nearby')
              return ok({
                'barbers': [
                  {'id': 'b1', 'availabilityStatus': 'available'},
                ],
              });
            if (path == 'catalog') {
              catalogs++;
              return ok({
                ...catalog,
                'services': [
                  {...service, 'version': changed && catalogs > 1 ? 2 : 1},
                ],
              });
            }
            if (path == 'quotes')
              return ok({
                'serviceVersion': 1,
                'areaVersion': 1,
                'totalMinor': 20000,
                'serviceNameEn': 'Haircut & styling',
              });
            if (path == 'bookings') {
              booking = jsonDecode(r.body);
              return ok({'id': 'booking-test'});
            }
            throw StateError(path);
          }),
        );
        await prepare(t, api, chosen);
        expect(find.text(tr('راجع طلب الزيارة')), findsOneWidget);
        expect(booking, isNull);
        await t.tap(find.widgetWithText(FilledButton, tr('إرسال الطلب')));
        await t.pumpAndSettle();
        expect(catalogs, 2);
        if (changed) {
          await t.drag(find.byType(Scrollable).first, const Offset(0, 1800));
          await t.pumpAndSettle();
          expect(booking, isNull);
          expect(
            find.text(tr('السعر اتحدث. راجع السعر الجديد قبل تأكيد الطلب.')),
            findsOneWidget,
          );
        } else {
          expect(booking!['preferredBarberId'], 'b1');
          expect(booking!['customerLocation'], chosen.location);
          expect(booking!['bookingType'], 'immediate');
          expect(booking!['areaVersion'], 1);
          expect(find.text(tr('طلبك اتسجل')), findsOneWidget);
        }
        expect(calls.take(3), ['nearby', 'catalog', 'quotes']);
        await t.pumpWidget(const SizedBox.shrink());
        await t.pumpAndSettle();
      },
    );
  }
  testWidgets(
    'unavailable requested barber is removed without quoting or booking',
    (t) async {
      final calls = <String>[];
      final api = RayeqApi(
        baseUrl: 'https://example.com/api/v1',
        client: MockClient((r) async {
          calls.add(r.url.path);
          return ok({'barbers': []});
        }),
      );
      await prepare(t, api, chosen);
      expect(calls, ['/api/v1/barbers/nearby']);
      expect(find.textContaining('Ahmed Hassan'), findsNothing);
      expect(find.byType(AlertDialog), findsNothing);
      await t.pumpWidget(const SizedBox.shrink());
      await t.pumpAndSettle();
    },
  );
}
