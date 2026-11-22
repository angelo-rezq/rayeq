import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rayeq/api.dart';
import 'package:rayeq/bottom_bar.dart';
import 'package:rayeq/localization.dart';
import 'package:rayeq/main.dart';
import 'package:rayeq/service_details.dart';
import 'package:rayeq/ui_parts.dart';

import 'forms_review_test.dart' show capture;

const service = {
  'id': 'hair',
  'nameAr': 'حلاقة وتصفيف',
  'nameEn': 'Haircut & styling',
  'descriptionAr': 'قصة مرتبة وتصفيف يناسبك، بعناية بكل التفاصيل.',
  'descriptionEn': 'A precise cut and styling, with care in every detail.',
  'category': 'hair',
  'categoryEn': 'Haircut',
  'priceMinor': 20000,
  'durationMinutes': 45,
  'version': 1,
  'englishReady': true,
};
const area = {
  'id': 'central',
  'nameAr': 'وسط البلد',
  'nameEn': 'Central Cairo',
  'englishReady': true,
  'version': 1,
};
const catalog = {
  'intakeEnabled': true,
  'isDemo': true,
  'instapayAvailable': true,
  'services': [
    service,
    {
      'id': 'beard',
      'nameAr': 'العناية بالذقن',
      'nameEn': 'Beard care',
      'descriptionAr': 'تحديد وعناية بالذقن.',
      'descriptionEn': 'Beard shaping and care.',
      'category': 'beard',
      'categoryEn': 'Beard',
      'priceMinor': 12000,
      'durationMinutes': 30,
      'version': 1,
      'englishReady': true,
    },
  ],
  'areas': [area],
};
Map<String, dynamic> booking({bool completed = false}) => {
  'id': 'preview-booking',
  'reference': 'RAY-PREVIEW',
  'status': completed ? 'COMPLETED' : 'CONFIRMED',
  'version': 1,
  'service': service,
  'area': area,
  'requestedAt': '2026-11-23T10:00:00Z',
  'startAt': '2026-11-23T10:00:00Z',
  'endAt': '2026-11-23T10:45:00Z',
  'customerName': appLocale.value.languageCode == 'en'
      ? 'Karim Ahmed'
      : 'كريم أحمد',
  'contactPhone': '+201000000000',
  'locationType': 'home',
  'bookingType': 'scheduled',
  'address': {
    'street': appLocale.value.languageCode == 'en'
        ? 'Museum Street'
        : 'شارع المعرض',
    'building': '12',
    'floor': '2',
    'apartment': '5',
    'directions': appLocale.value.languageCode == 'en'
        ? 'Beside the garden'
        : 'بجوار الحديقة',
  },
  'price': {'serviceMinor': 20000, 'travelMinor': 3000, 'totalMinor': 23000},
  'payment': {'method': 'cash', 'status': 'UNPAID'},
  'assignedWorker': {
    'id': 'worker1',
    'name': 'أحمد حسن',
    'nameEn': 'Ahmed Hassan',
  },
  'history': [
    {'status': 'CONFIRMED', 'at': '2026-11-22T16:00:00Z'},
  ],
  'canReview': completed,
  'review': null,
};
Map<String, dynamic> profile(String role) => {
  'id': 'preview-$role',
  'role': role,
  'name': role == 'worker' ? 'أحمد حسن' : 'كريم أحمد',
  'displayNameEn': role == 'worker' ? 'Ahmed Hassan' : 'Karim Ahmed',
  'email': role == 'worker'
      ? 'worker-test@rayeq.invalid'
      : 'customer-test@rayeq.invalid',
  'phone': '+201000000000',
  'emailVerified': true,
  'hasAvatar': false,
  'workerProfile': {
    'employeeName': 'أحمد حسن',
    'employeeNameEn': 'Ahmed Hassan',
    'monthlySalaryMinor': null,
  },
};
RayeqApi apiFor(String role) => RayeqApi(
  baseUrl: 'https://example.com/api/v1',
  client: MockClient((r) async {
    final p = r.url.path.replaceFirst('/api/v1/', '');
    dynamic data;
    if (p == 'me' || p == 'profile') {
      data = profile(role);
    } else if (p == 'catalog') {
      data = catalog;
    } else if (p == 'bookings' || p == 'worker/bookings') {
      data = {
        'items': [booking()],
        'nextCursor': null,
      };
    } else if (p == 'bookings/preview-booking') {
      data = booking(completed: true);
    } else if (p == 'worker/schedule') {
      data = {
        'items': [
          {
            'serviceNameAr': service['nameAr'],
            'serviceNameEn': service['nameEn'],
            'areaNameAr': area['nameAr'],
            'areaNameEn': area['nameEn'],
            'startAt': '2026-11-23T10:00:00Z',
            'status': 'CONFIRMED',
            'reference': 'RAY-PREVIEW',
          },
        ],
      };
    } else if (p == 'worker/availability') {
      data = {
        'availabilityStatus': 'offline',
        'effectiveAvailabilityStatus': 'offline',
        'isFresh': false,
        'hasCoarseZone': false,
      };
    } else if (p == 'worker/gallery') {
      data = {'items': [], 'maxPhotos': 6};
    } else if (p == 'worker/rating') {
      data = {'ratingAverage': null, 'reviewCount': 0};
    } else if (p == 'auth/login') {
      data = {'token': 'preview-token'};
    } else if (p == 'auth/register') {
      data = {'next': 'verify'};
    } else if (p == 'auth/forgot-password') {
      data = {};
    } else {
      data = {};
    }
    return http.Response(
      jsonEncode({'data': data}),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  }),
);
void main() {
  testWidgets('capture complete current app page families in AR and EN', (
    t,
  ) async {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(() {
      t.view.resetPhysicalSize();
      t.view.resetDevicePixelRatio();
    });
    await (FontLoader('PlexArabic')
          ..addFont(rootBundle.load('assets/fonts/PlexArabic-400.ttf'))
          ..addFont(rootBundle.load('assets/fonts/PlexArabic-500.ttf'))
          ..addFont(rootBundle.load('assets/fonts/PlexArabic-600.ttf')))
        .load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    await t.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    final imageContext = t.element(find.byType(SizedBox).first);
    await t.runAsync(() async {
      for (final asset in [
        'barber-alex',
        'barber-daniel',
        'grooming',
        'service-hair',
        'service-beard',
        'service-ritual',
      ]) {
        await precacheImage(
          AssetImage('assets/images/$asset.webp'),
          imageContext,
        );
      }
    });
    await t.pumpAndSettle();
    Future<void> shot(GlobalKey key, String name) async {
      expect(t.takeException(), isNull, reason: name);
      await capture(t, key, name);
    }

    for (final lang in ['ar', 'en']) {
      appLocale.value = lang == 'ar'
          ? const Locale('ar', 'EG')
          : const Locale('en');
      for (final role in ['customer', 'worker']) {
        FlutterSecureStorage.setMockInitialValues({
          'rayeq_session': 'preview-token',
        });
        SharedPreferences.setMockInitialValues({
          'saved_preview-$role': ['demo-alex'],
        });
        final api = apiFor(role), boundary = GlobalKey();
        await t.pumpWidget(
          RepaintBoundary(
            key: boundary,
            child: RayeqApp(api: api),
          ),
        );
        await t.pumpAndSettle();
        await shot(boundary, '$role-main-$lang');
        final tabs = role == 'customer'
            ? ['الخدمات', 'حجوزاتي', 'المحفوظات', 'حسابي']
            : ['جدولي', 'حسابي'];
        for (final tab in tabs) {
          final nav = find.byType(RoyalNavigationBar);
          await t.tap(find.descendant(of: nav, matching: find.text(tr(tab))));
          await t.pumpAndSettle();
          await shot(boundary, '$role-tab-$tab-$lang');
          await t.drag(find.byType(Scrollable).first, const Offset(0, -580));
          await t.pumpAndSettle();
          await shot(boundary, '$role-tab-$tab-lower-$lang');
          if (tab == 'حسابي') {
            await t.drag(find.byType(Scrollable).first, const Offset(0, -1000));
            await t.pumpAndSettle();
            await shot(boundary, '$role-account-bottom-$lang');
          }
        }
        // Open current widgets through the same navigator, with test-only records.
        final nav = t.state<NavigatorState>(find.byType(Navigator).first);
        nav.push(
          MaterialPageRoute(
            builder: (_) => BookingDetails(
              api: api,
              id: 'preview-booking',
              employee: role == 'worker',
            ),
          ),
        );
        await t.pumpAndSettle();
        await shot(boundary, '$role-visit-details-$lang');
        await t.drag(find.byType(Scrollable).first, const Offset(0, -600));
        await t.pumpAndSettle();
        await shot(boundary, '$role-visit-details-lower-$lang');
        nav.pop();
        await t.pumpAndSettle();
        if (role == 'customer') {
          nav.push(
            MaterialPageRoute(
              builder: (_) => ServiceDetails(
                service: service,
                demo: true,
                onBook: () {},
                onNearby: () {},
              ),
            ),
          );
          await t.pumpAndSettle();
          await shot(boundary, 'customer-service-details-$lang');
          await t.drag(find.byType(Scrollable).first, const Offset(0, -600));
          await t.pumpAndSettle();
          await shot(boundary, 'customer-service-details-lower-$lang');
        }
        await t.pumpWidget(const SizedBox.shrink());
        await t.pumpAndSettle();
      }
      // Shared sign-in and account-creation screens are also current app screens.
      FlutterSecureStorage.setMockInitialValues({});
      SharedPreferences.setMockInitialValues({});
      final boundary = GlobalKey();
      await t.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: RayeqApp(api: apiFor('customer')),
        ),
      );
      await t.pumpAndSettle();
      await shot(boundary, 'shared-intro-$lang');
      await t.tap(find.text(tr('خلّينا نبدأ')));
      await t.pumpAndSettle();
      await shot(boundary, 'shared-onboarding-1-$lang');
      await t.tap(find.text(tr('التالي')));
      await t.pumpAndSettle();
      await shot(boundary, 'shared-onboarding-2-$lang');
      await t.tap(find.text(tr('ابدأ مع رايق')));
      await t.pumpAndSettle();
      await shot(boundary, 'shared-login-$lang');
      await t.ensureVisible(find.text(tr('نسيت كلمة المرور؟')));
      await t.tap(find.text(tr('نسيت كلمة المرور؟')));
      await t.pumpAndSettle();
      await shot(boundary, 'shared-recovery-$lang');
      await t.tap(find.text(tr('إرسال كود الاستعادة')));
      await t.pumpAndSettle();
      await shot(boundary, 'shared-reset-$lang');
      await t.tap(find.text(tr('رجوع للدخول')));
      await t.pumpAndSettle();
      await t.ensureVisible(find.text(tr('أول مرة؟ اعمل حساب')));
      await t.tap(find.text(tr('أول مرة؟ اعمل حساب')));
      await t.pumpAndSettle();
      await shot(boundary, 'shared-register-$lang');
      await t.drag(find.byType(Scrollable).first, const Offset(0, -450));
      await t.pumpAndSettle();
      await shot(boundary, 'shared-register-lower-$lang');
      for (final isWorker in [false, true]) {
        await t.drag(find.byType(Scrollable).first, const Offset(0, 700));
        await t.pumpAndSettle();
        if (isWorker) {
          await t.tap(find.text(tr('حلاق')));
          await t.pumpAndSettle();
          await shot(boundary, 'worker-register-$lang');
        }
        for (var i = 0; i < 3; i++) {
          final field = find.byType(TextField).at(i);
          await t.ensureVisible(field);
          await t.pumpAndSettle();
          await t.enterText(
            field,
            [
              'Preview account',
              'preview@example.invalid',
              'Not-a-real-login-99',
            ][i],
          );
        }
        final submit = find.widgetWithText(
          FilledButton,
          tr(isWorker ? 'إنشاء حساب حلاق' : 'إنشاء حساب عميل'),
        );
        await t.ensureVisible(submit);
        await t.pumpAndSettle();
        await t.tap(submit);
        await t.pumpAndSettle();
        await shot(boundary, '${isWorker ? 'worker' : 'shared'}-verify-$lang');
        if (!isWorker) {
          await t.tap(find.text(tr('رجوع للدخول')));
          await t.pumpAndSettle();
          await t.ensureVisible(find.text(tr('أول مرة؟ اعمل حساب')));
          await t.tap(find.text(tr('أول مرة؟ اعمل حساب')));
          await t.pumpAndSettle();
        }
      }
      await t.pumpWidget(const SizedBox.shrink());
      await t.pumpAndSettle();
    }
  });
}
