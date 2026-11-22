import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rayeq/barber_profiles.dart';
import 'package:rayeq/localization.dart';
import 'package:rayeq/royal_theme.dart';

import 'forms_review_test.dart' show capture;

void main() {
  testWidgets(
    'review and portfolio UI fit AR and EN without fabricated ratings',
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
      for (final language in ['ar', 'en']) {
        appLocale.value = language == 'ar'
            ? const Locale('ar', 'EG')
            : const Locale('en');
        for (final width in [320, 390, 430]) {
          t.view.physicalSize = Size(width.toDouble(), 844);
          for (final screen in [
            'barber-profile',
            'review-composer',
            'worker-portfolio',
          ]) {
            final boundary = GlobalKey();
            final Widget home = switch (screen) {
              'barber-profile' => BarberPublicProfile(
                name: language == 'ar' ? 'أحمد حسن' : 'Ahmed Hassan',
                rating: const BarberRating(count: 0),
                onBook: () {},
              ),
              'review-composer' => ReviewComposer(
                maxCommentLength: 1000,
                onSubmit: (_, __) async {},
              ),
              _ => Scaffold(
                appBar: AppBar(
                  title: Text(
                    language == 'ar' ? 'معرض الأعمال' : 'Portfolio',
                  ),
                ),
                body: ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    WorkerPortfolioPanel(
                      photos: const [],
                      maxPhotos: 6,
                      maxBytes: 5 * 1024 * 1024,
                      onUpload: (_) async =>
                          throw StateError('No picker call expected'),
                      onDelete: (_) async {},
                    ),
                  ],
                ),
              ),
            };
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
                  home: home,
                ),
              ),
            );
            await t.pumpAndSettle();
            expect(
              t.takeException(),
              isNull,
              reason: '$screen $language $width',
            );
            if (screen == 'review-composer') {
              expect(
                t.widget<FilledButton>(find.byType(FilledButton)).onPressed,
                isNull,
              );
              await t.tap(find.byTooltip('4 / 5'));
              await t.pumpAndSettle();
              expect(
                t.widget<FilledButton>(find.byType(FilledButton)).onPressed,
                isNotNull,
              );
            }
            if (width == 390) await capture(t, boundary, '$screen-$language');
            await t.pumpWidget(const SizedBox.shrink());
            await t.pumpAndSettle();
          }
        }
      }
    },
  );
}
