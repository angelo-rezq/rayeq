import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rayeq/api.dart';
import 'package:rayeq/main.dart';
import 'package:rayeq/localization.dart';
import 'package:rayeq/demo_data.dart';

void main() {
  setUp(() {
    appLocale.value = const Locale('ar', 'EG');
    previewDataEnabled = false;
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
  });
  Future<void> openLogin(WidgetTester t, RayeqApi api) async {
    t.view.physicalSize = const Size(390, 1000);
    t.view.devicePixelRatio = 1;
    addTearDown(() {
      t.view.resetPhysicalSize();
      t.view.resetDevicePixelRatio();
    });
    await t.pumpWidget(RayeqApp(api: api));
    await t.pumpAndSettle();
    await t.tap(find.text('تسجيل الدخول'));
    await t.pumpAndSettle();
  }

  RayeqApi offline() => RayeqApi(
    baseUrl: 'https://example.com/api/v1',
    client: MockClient((_) async => throw StateError('No API call expected')),
  );

  testWidgets('Arabic remains default and English changes text and direction', (
    t,
  ) async {
    await openLogin(t, offline());
    expect(
      Directionality.of(t.element(find.text('نورت رايق'))),
      TextDirection.rtl,
    );
    await t.tap(find.byTooltip('تغيير اللغة'));
    await t.pumpAndSettle();
    expect(find.text('Welcome to Rayeq'), findsOneWidget);
    expect(
      Directionality.of(t.element(find.text('Welcome to Rayeq'))),
      TextDirection.ltr,
    );
    final p = await SharedPreferences.getInstance();
    expect(p.getString('app_language'), 'en');
    await t.ensureVisible(find.text('New here? Create an account'));
    await t.tap(find.text('New here? Create an account'));
    await t.pumpAndSettle();
    expect(find.text('Create your account'), findsOneWidget);
    expect(find.text('Customer'), findsOneWidget);
    expect(find.text('Barber'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(3));
    expect(t.takeException(), isNull);
  });
  testWidgets(
    'worker registration submits worker type then waits for email code',
    (t) async {
      Map<String, dynamic>? submitted;
      final api = RayeqApi(
        baseUrl: 'https://example.com/api/v1',
        client: MockClient((r) async {
          expect(r.url.path, '/api/v1/auth/register');
          submitted = jsonDecode(r.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({
              'data': {'next': 'verify'},
            }),
            201,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      await openLogin(t, api);
      await t.tap(find.byTooltip('تغيير اللغة'));
      await t.pumpAndSettle();
      await t.ensureVisible(find.text('New here? Create an account'));
      await t.tap(find.text('New here? Create an account'));
      await t.pumpAndSettle();
      await t.tap(find.text('Barber'));
      await t.pumpAndSettle();
      expect(find.text('Join the Rayeq team'), findsOneWidget);
      await t.enterText(find.byType(TextField).at(0), 'Test Barber');
      await t.enterText(find.byType(TextField).at(1), 'barber@example.com');
      await t.enterText(find.byType(TextField).at(2), 'a' * 10);
      final submit = find.widgetWithText(FilledButton, 'Create barber account');
      await t.ensureVisible(submit);
      await t.tap(submit);
      await t.pumpAndSettle();
      expect(submitted?['accountType'], 'worker');
      expect(submitted?['email'], 'barber@example.com');
      expect(submitted?.containsKey('phone'), false);
      expect(find.text('Verification code'), findsOneWidget);
      expect(
        find.text(
          'After email verification, our team reviews your application before you receive visits.',
        ),
        findsOneWidget,
      );
      expect(t.takeException(), isNull);
    },
  );
  test('known dynamic and API messages have English copy', () {
    appLocale.value = const Locale('en');
    for (final s in [
      'الإيميل أو كلمة المرور مش صحيحة.',
      'تابع زياراتك وحدّث حالتها.',
      'غير مؤكد التحصيل',
      'اختار صورة أصغر من ٢ ميجا.',
      'تعذر تنزيل التحديث أو فتح المثبت. جرّب تاني.',
    ]) {
      expect(RegExp(r'[\u0600-\u06ff]').hasMatch(tr(s)), false, reason: s);
    }
  });
  test(
    'fixture presentation does not alter stored fields or commercial state',
    () {
      final raw = <String, dynamic>{
        'id': 'visit',
        'version': 7,
        'status': 'CONFIRMED',
        'customerName': 'تجربة فقط',
        'price': {'totalMinor': 0},
        'area': {'nameAr': 'منطقة تجريبية'},
        'address': {'street': 'عنوان تجريبي', 'building': '12'},
      };
      final before = jsonEncode(raw);
      final view = bookingForDisplay(raw, preview: true);
      expect(view['customerName'], 'James Parker');
      expect(view['id'], raw['id']);
      expect(view['status'], raw['status']);
      expect(view['version'], 7);
      expect(view['price'], raw['price']);
      expect(jsonEncode(raw), before);
      expect(identical(bookingForDisplay(raw, preview: false), raw), true);
      expect(
        displayProfileName({
          'email': 'customer-test@rayeq.invalid',
          'name': 'Edited Name',
        }),
        'Edited Name',
      );
    },
  );
}
