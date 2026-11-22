import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:rayeq/api.dart';
import 'package:rayeq/localization.dart';
import 'package:rayeq/nearby.dart';

import 'booking_submit_test.dart' show prepare, ok;
import 'forms_review_test.dart' show capture, catalog;

void main() {
  testWidgets(
    'direct booking review and confirmation follow returned server status in AR and EN',
    (t) async {
      await (FontLoader('PlexArabic')
            ..addFont(rootBundle.load('assets/fonts/PlexArabic-400.ttf'))
            ..addFont(rootBundle.load('assets/fonts/PlexArabic-600.ttf')))
          .load();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
      for (final language in ['ar', 'en']) {
        appLocale.value = language == 'ar'
            ? const Locale('ar', 'EG')
            : const Locale('en');
        FlutterSecureStorage.setMockInitialValues({});
        var created = false;
        final api = RayeqApi(
          baseUrl: 'https://example.com/api/v1',
          client: MockClient((r) async {
            final path = r.url.path.split('/').last;
            if (path == 'nearby')
              return ok({
                'barbers': [
                  {'id': 'b1', 'availabilityStatus': 'available'},
                ],
              });
            if (path == 'catalog') return ok(catalog);
            if (path == 'quotes')
              return ok({
                'serviceVersion': 1,
                'areaVersion': 1,
                'totalMinor': 20000,
                'serviceNameEn': 'Haircut & styling',
              });
            if (path == 'bookings') {
              created = true;
              return ok({
                'id': 'preview-only',
                'status': 'CONFIRMED',
                'assignmentMode': 'CUSTOMER_SELECTED',
                'requiresAdminApproval': false,
                'assignedWorker': {
                  'id': 'b1',
                  'name': 'أحمد حسن',
                  'nameEn': 'Ahmed Hassan',
                },
                'startAt': '2026-11-23T10:00:00Z',
                'endAt': '2026-11-23T10:45:00Z',
              });
            }
            throw StateError(path);
          }),
        );
        final boundary = await prepare(
          t,
          api,
          const NearbySelection(
            barber: {
              'id': 'b1',
              'nameAr': 'أحمد حسن',
              'nameEn': 'Ahmed Hassan',
            },
            areaId: 'area-1',
          ),
        );
        expect(created, false);
        await capture(t, boundary, 'booking-review-$language');
        await t.tap(find.widgetWithText(FilledButton, tr('إرسال الطلب')));
        await t.pumpAndSettle();
        expect(created, true);
        expect(
          find.text(nearbyText('حجزك اتأكد', 'Booking confirmed')),
          findsOneWidget,
        );
        expect(t.takeException(), isNull);
        await capture(t, boundary, 'booking-confirmed-$language');
        await t.pumpWidget(const SizedBox.shrink());
        await t.pumpAndSettle();
      }
    },
  );
}
