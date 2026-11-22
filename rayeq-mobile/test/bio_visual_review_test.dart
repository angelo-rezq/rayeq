import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rayeq/api.dart';
import 'package:rayeq/localization.dart';
import 'package:rayeq/profile.dart';
import 'package:rayeq/royal_theme.dart';
import 'package:rayeq/worker_public_profile.dart';

import 'forms_review_test.dart' show capture;

void main() {
  testWidgets(
    'account and public worker biography editing fits phone in both locales',
    (t) async {
      t.view.devicePixelRatio = 1;
      t.view.physicalSize = const Size(390, 844);
      addTearDown(() {
        t.view.resetPhysicalSize();
        t.view.resetDevicePixelRatio();
      });
      for (final entry in {
        'PlexArabic': ['PlexArabic-400.ttf', 'PlexArabic-600.ttf'],
        'MaterialIcons': ['material'],
      }.entries) {
        final f = FontLoader(entry.key);
        for (final name in entry.value) {
          f.addFont(
            rootBundle.load(
              name == 'material'
                  ? 'fonts/MaterialIcons-Regular.otf'
                  : 'assets/fonts/$name',
            ),
          );
        }
        await f.load();
      }
      final api = RayeqApi(
        baseUrl: 'https://example.com/api/v1',
        client: MockClient(
          (r) async => http.Response(
            jsonEncode({
              'data': r.url.path.endsWith('worker/public-profile')
                  ? {
                      'titleAr': 'حلاق تجريبي',
                      'titleEn': 'Demo barber',
                      'bioAr': 'نبذة تجريبية للمعاينة. هنا يقدر الحلاق يعرّف العملاء بخبرته وطريقته في الشغل.',
                      'bioEn': 'Demonstration bio. A worker can introduce their experience and approach here.',
                      'specialtiesAr': [],
                      'specialtiesEn': [],
                      'yearsExperience': 6,
                    }
                  : {
                      'id': 'sample',
                      'name': 'Sample account',
                      'role': 'customer',
                      'bio': '',
                    },
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          ),
        ),
      );
      for (final lang in ['ar', 'en']) {
        appLocale.value = lang == 'ar'
            ? const Locale('ar', 'EG')
            : const Locale('en');
        for (final mode in ['worker', 'account']) {
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
                home: mode == 'worker'
                    ? WorkerPublicProfileEditor(api: api)
                    : Scaffold(
                        body: SingleChildScrollView(
                          padding: const EdgeInsets.all(20),
                          child: ProfilePanel(
                            api: api,
                            initialUser: const {
                              'id': 'sample',
                              'role': 'customer',
                            },
                            onPassword: () {},
                            onLogout: () {},
                            onChanged: (_) {},
                          ),
                        ),
                      ),
              ),
            ),
          );
          await t.pumpAndSettle();
          if (mode == 'worker') {
            await Scrollable.ensureVisible(
              t.element(
                find.text(
                  lang == 'ar'
                      ? 'عرّف العملاء بنفسك'
                      : 'Tell customers about yourself',
                ),
              ),
              alignment: .02,
            );
            await t.pumpAndSettle();
          } else {
            final edit = find.widgetWithText(
              OutlinedButton,
              lang == 'ar' ? 'تعديل النبذة' : 'Edit bio',
            );
            await t.ensureVisible(edit);
            await t.pumpAndSettle();
            await t.tap(edit);
            await t.pumpAndSettle();
          }
          expect(t.takeException(), isNull);
          await capture(t, boundary, 'build3-bio-$mode-$lang');
          await t.pumpWidget(const SizedBox.shrink());
          await t.pumpAndSettle();
        }
      }
    },
  );
}
