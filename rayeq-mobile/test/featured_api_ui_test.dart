import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rayeq/customer_home.dart';
import 'package:rayeq/review_fixtures.dart';
import 'package:rayeq/demo_data.dart';
import 'package:rayeq/localization.dart';
import 'package:rayeq/royal_theme.dart';

import 'forms_review_test.dart' show capture;

class FeaturedReviewApi extends ReviewApi {
  @override
  Future<dynamic> request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? query,
    String? idempotencyKey,
  }) async {
    if (path == 'barbers/featured')
      return {
        'items': [
          {
            ...reviewBarber,
            'nameAr': 'أحمد حسن عبد الرحمن',
            'nameEn': 'Ahmed Hassan Abdel Rahman',
            'demoOnly': true,
          },
        ],
      };
    return super.request(
      method,
      path,
      body: body,
      query: query,
      idempotencyKey: idempotencyKey,
    );
  }
}

void main() {
  testWidgets(
    'API featured profiles fit phone cards with honest empty ratings',
    (t) async {
      previewDataEnabled = true;
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
      for (final en in [false, true])
        for (final width in [320, 390, 430]) {
          appLocale.value = en ? const Locale('en') : const Locale('ar', 'EG');
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
                        api: FeaturedReviewApi(),
                        user: {'name': en ? 'Karim Ahmed' : 'كريم أحمد'},
                        catalog: reviewCatalog,
                        savedIds: {},
                        onAccount: () {},
                        onServices: () {},
                        onDemo: (_) {},
                        onSave: (_) {},
                        onBook: (_, __) {},
                        onService: (_) {},
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
          await t.pumpAndSettle();
          expect(t.takeException(), isNull, reason: '$en $width');
          expect(
            find.text(en ? 'No reviews yet' : 'لسه مفيش تقييمات'),
            findsOneWidget,
          );
          if (width == 390)
            await capture(t, boundary, 'api-featured-${en ? 'en' : 'ar'}');
          await t.pumpWidget(const SizedBox.shrink());
          await t.pumpAndSettle();
        }
    },
  );
}
