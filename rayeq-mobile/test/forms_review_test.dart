import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rayeq/api.dart';
import 'package:rayeq/live.dart';
import 'package:rayeq/localization.dart';
import 'package:rayeq/royal_theme.dart';

const service = {
  'id': 'service-1',
  'nameAr': 'حلاقة وتصفيف',
  'nameEn': 'Haircut & styling',
  'version': 1,
  'englishReady': true,
};
const area = {
  'id': 'area-1',
  'nameAr': 'وسط البلد',
  'nameEn': 'Central Cairo',
  'version': 1,
  'englishReady': true,
};
const catalog = {
  'intakeEnabled': true,
  'instapayAvailable': true,
  'services': [service],
  'areas': [area],
};
Future<void> capture(WidgetTester t, GlobalKey key, String name) async {
  await t.runAsync(() async {
    final image =
        await (key.currentContext!.findRenderObject()! as RenderRepaintBoundary)
            .toImage(pixelRatio: 1);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final dir = Directory('/tmp/rayeq-visual-review');
    await dir.create(recursive: true);
    await File('${dir.path}/$name.png')
        .writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  testWidgets(
    'booking forms fit small, standard and large phones in AR and EN',
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
      final api = RayeqApi(
        baseUrl: 'https://example.com/api/v1',
        client: MockClient(
          (r) async => http.Response(jsonEncode({'data': catalog}), 200),
        ),
      );
      for (final language in ['ar', 'en']) {
        appLocale.value = language == 'ar'
            ? const Locale('ar', 'EG')
            : const Locale('en');
        for (final width in [320, 390, 430]) {
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
                home: BookingForm(
                  api: api,
                  service: service,
                  catalog: catalog,
                  customerName: language == 'ar'
                      ? 'عميل تجريبي'
                      : 'Pilot customer',
                ),
              ),
            ),
          );
          await t.pumpAndSettle();
          expect(t.takeException(), isNull, reason: 'top $language $width');
          await capture(t, boundary, 'booking-top-$language-$width');
          final scroll = find.byType(Scrollable).first;
          await t.drag(scroll, const Offset(0, -550));
          await t.pumpAndSettle();
          expect(t.takeException(), isNull, reason: 'middle $language $width');
          await capture(t, boundary, 'booking-middle-$language-$width');
          await t.drag(scroll, const Offset(0, -1200));
          await t.pumpAndSettle();
          expect(t.takeException(), isNull, reason: 'bottom $language $width');
          await capture(t, boundary, 'booking-bottom-$language-$width');
          expect(find.byType(CheckboxListTile), findsNothing);
          await t.pumpWidget(const SizedBox.shrink());
          await t.pumpAndSettle();
        }
      }
    },
  );
}
