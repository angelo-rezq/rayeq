import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rayeq/brand.dart';
import 'package:rayeq/localization.dart';
import 'package:rayeq/royal_theme.dart';

import 'forms_review_test.dart' show capture;

void main() {
  testWidgets('brand draw-in and localized wordmarks render at phone size', (
    t,
  ) async {
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
      'BrandArabic',
    )..addFont(rootBundle.load('assets/fonts/BrandArabic.ttf'))).load();
    await (FontLoader(
      'BrandLatin',
    )..addFont(rootBundle.load('assets/fonts/BrandLatin.ttf'))).load();
    for (final language in ['ar', 'en']) {
      appLocale.value = language == 'ar'
          ? const Locale('ar', 'EG')
          : const Locale('en');
      final count = language == 'ar' ? 66 : 1;
      for (var i = 0; i < count; i++) {
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
                body: Center(
                  child: RayeqBrandLockup(
                    progress: count == 1 ? 1 : (i / 55).clamp(0.0, 1.0),
                  ),
                ),
              ),
            ),
          ),
        );
        await t.pump();
        expect(t.takeException(), isNull);
        await capture(
          t,
          boundary,
          language == 'ar'
              ? 'brand-frame-${i.toString().padLeft(3, '0')}'
              : 'brand-final-en',
        );
      }
    }
  });
}
