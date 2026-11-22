import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rayeq/main.dart';
import 'package:rayeq/localization.dart';

import 'all_pages_review_test.dart' show apiFor;
import 'forms_review_test.dart' show capture;

void main() {
  testWidgets(
    'current app startup, start and login render AR EN phone screens',
    (t) async {
      t.view.devicePixelRatio = 1;
      t.view.physicalSize = const Size(390, 844);
      addTearDown(() {
        t.view.resetPhysicalSize();
        t.view.resetDevicePixelRatio();
      });
      for (final entry in {
        'PlexArabic': ['PlexArabic-400.ttf', 'PlexArabic-600.ttf'],
        'BrandArabic': ['BrandArabic.ttf'],
        'BrandLatin': ['BrandLatin.ttf'],
        'MaterialIcons': ['material'],
      }.entries) {
        final loader = FontLoader(entry.key);
        for (final f in entry.value) {
          loader.addFont(
            rootBundle.load(
              f == 'material'
                  ? 'fonts/MaterialIcons-Regular.otf'
                  : 'assets/fonts/$f',
            ),
          );
        }
        await loader.load();
      }
      for (final lang in ['ar', 'en']) {
        appLocale.value = lang == 'ar'
            ? const Locale('ar', 'EG')
            : const Locale('en');
        FlutterSecureStorage.setMockInitialValues({});
        SharedPreferences.setMockInitialValues({});
        final boundary = GlobalKey();
        await t.pumpWidget(
          RepaintBoundary(
            key: boundary,
            child: RayeqApp(api: apiFor('customer')),
          ),
        );
        await t.pump(const Duration(milliseconds: 2650));
        expect(t.takeException(), isNull);
        await capture(t, boundary, 'build3-splash-$lang');
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        await capture(t, boundary, 'build3-start-$lang');
        await t.tap(find.text(tr('تسجيل الدخول')));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        await capture(t, boundary, 'build3-login-$lang');
        await t.pumpWidget(const SizedBox.shrink());
        await t.pumpAndSettle();
      }
    },
  );
}
