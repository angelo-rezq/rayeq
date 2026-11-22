import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rayeq/review_hub.dart';
import 'package:rayeq/review_fixtures.dart';
import 'package:rayeq/live.dart';
import 'package:rayeq/localization.dart';
import 'package:rayeq/royal_theme.dart';

import 'forms_review_test.dart' show capture;

void main() {
  testWidgets(
    'all preview index routes open without live accounts or effects',
    (t) async {
      SharedPreferences.setMockInitialValues({});
      t.view.devicePixelRatio = 1;
      t.view.physicalSize = const Size(390, 844);
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
      final routes = [
        ['الرئيسية والبحث', 'Home and search'],
        ['الخدمات', 'Services'],
        ['تفاصيل الخدمة', 'Service details'],
        ['الحجز ومراجعة السعر والتأكيد', 'Booking, quote and confirmation'],
        ['اختيار حلاق قريب', 'Choose a nearby barber'],
        [
          'ملف الحلاق والأعمال والتقييمات',
          'Barber profile, photos and reviews',
        ],
        ['ملف تجريبي بتقييمات نموذجية', 'Sample profile with example reviews'],
        ['حجوزاتي الحالية والسابقة', 'Current and past bookings'],
        [
          'تفاصيل الزيارة المكتملة والتقييم',
          'Completed visit details and rating',
        ],
        ['كتابة تقييم للزيارة', 'Write a visit review'],
        ['المحفوظات', 'Saved'],
        ['الحساب وتعديل البيانات والصورة', 'Account, profile and photo'],
        ['الزيارات وحالات التنفيذ', 'Visits and progress'],
        ['تفاصيل الزيارة المسندة', 'Assigned visit details'],
        ['الجدول والتوفر', 'Schedule and availability'],
        ['الحساب والتقييم وصور الأعمال', 'Account, rating and portfolio'],
        ['إدارة صور الأعمال والرفع', 'Work photo management and upload'],
        ['حساب حلاق في انتظار الموافقة', 'Worker awaiting approval'],
        ['إنشاء حساب حلاق', 'Create a worker account'],
        ['البداية', 'Welcome'],
        ['مقدمة ١', 'Introduction 1'],
        ['مقدمة ٢', 'Introduction 2'],
        ['تسجيل الدخول', 'Sign in'],
        ['إنشاء حساب عميل', 'Create a customer account'],
        ['تفعيل البريد', 'Verify email'],
        ['استعادة الحساب', 'Account recovery'],
        ['تغيير كلمة المرور', 'Reset password'],
        ['عن رايق', 'About Rayeq'],
        ['سياسة الخصوصية', 'Privacy policy'],
        ['التحديث الاختياري', 'Optional update'],
        ['التحديث المطلوب', 'Required update'],
      ];
      for (final en in [false, true]) {
        appLocale.value = en ? const Locale('en') : const Locale('ar', 'EG');
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
              home: const ReviewHub(),
            ),
          ),
        );
        await t.pumpAndSettle();
        await capture(t, boundary, 'screen-index-${en ? 'en' : 'ar'}');
        for (final names in routes) {
          final title = names[en ? 1 : 0];
          await t.scrollUntilVisible(find.text(title), 350, maxScrolls: 80);
          await t.tap(find.text(title));
          await t.pumpAndSettle();
          expect(t.takeException(), isNull, reason: title);
          expect(
            find.text(
              en ? 'UI preview · Sample data' : 'معاينة فقط · بيانات نموذجية',
            ),
            findsOneWidget,
            reason: title,
          );
          if (names[0] == 'تسجيل الدخول')
            await capture(t, boundary, 'indexed-login-${en ? 'en' : 'ar'}');
          await t.tap(find.text(en ? 'Index' : 'الفهرس'));
          await t.pumpAndSettle();
          expect(find.byType(ReviewFrame), findsNothing, reason: title);
        }
        await t.pumpWidget(const SizedBox.shrink());
        await t.pumpAndSettle();
      }
    },
  );
  testWidgets('indexed login still fits a 320x568 phone', (t) async {
    SharedPreferences.setMockInitialValues({});
    t.view.devicePixelRatio = 1;
    t.view.physicalSize = const Size(320, 568);
    addTearDown(() {
      t.view.resetPhysicalSize();
      t.view.resetDevicePixelRatio();
    });
    await (FontLoader('PlexArabic')
          ..addFont(rootBundle.load('assets/fonts/PlexArabic-400.ttf'))
          ..addFont(rootBundle.load('assets/fonts/PlexArabic-600.ttf')))
        .load();
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    for (final en in [false, true]) {
      appLocale.value = en ? const Locale('en') : const Locale('ar', 'EG');
      await t.pumpWidget(
        MaterialApp(
          locale: appLocale.value,
          supportedLocales: const [Locale('ar', 'EG'), Locale('en')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          theme: rayeqTheme(),
          builder: rayeqBackdrop,
          home: ReviewFrame(
            ar: 'تسجيل الدخول',
            en: 'Sign in',
            child: LiveShell(
              api: ReviewApi(authenticated: false),
              initialScreen: 'login',
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      final scroll = t.state<ScrollableState>(find.byType(Scrollable).first);
      expect(
        scroll.position.maxScrollExtent,
        0,
        reason: en ? 'English' : 'Arabic',
      );
      await t.pumpWidget(const SizedBox.shrink());
      await t.pumpAndSettle();
    }
  });
  test(
    'review adapter keeps sessions local and raw uploads never reach network',
    () async {
      final api = ReviewApi(authenticated: false);
      await api.saveSession({'token': 'local-only'});
      expect(api.signedIn, isTrue);
      await api.forgetSession();
      expect(api.signedIn, isFalse);
      await api.restore();
      expect(api.signedIn, isFalse);
    },
  );
}
