import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rayeq/about.dart';
import 'package:rayeq/app_updates.dart';
import 'package:rayeq/localization.dart';
import 'package:rayeq/royal_theme.dart';

void main() {
  testWidgets('phone layouts for About, Privacy and update dialog', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
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
      for (final screen in ['about', 'privacy', 'update']) {
        final boundaryKey = GlobalKey();
        final navigatorKey = GlobalKey<NavigatorState>();
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundaryKey,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              navigatorKey: navigatorKey,
              locale: appLocale.value,
              supportedLocales: const [Locale('ar', 'EG'), Locale('en')],
              localizationsDelegates: GlobalMaterialLocalizations.delegates,
              theme: rayeqTheme(),
              home: const Scaffold(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        if (screen != 'update') {
          unawaited(
            navigatorKey.currentState!.push(
              MaterialPageRoute<void>(
                builder: (_) => screen == 'about'
                    ? const AboutRayeq()
                    : const PrivacyPolicy(),
              ),
            ),
          );
          await tester.pumpAndSettle();
        }
        if (screen == 'update') {
          unawaited(
            showDialog<void>(
              context: navigatorKey.currentContext!,
              builder: (_) => const UpdateDialog(
                info: UpdateInfo(
                  3,
                  1,
                  '1.2.0',
                  '',
                  '',
                  'تحسينات وتحديثات للتطبيق.',
                  'App improvements and updates.',
                ),
                requiredUpdate: false,
              ),
            ),
          );
          await tester.pumpAndSettle();
        }
        expect(tester.takeException(), isNull);
        await tester.runAsync(() async {
          final boundary =
              boundaryKey.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          final image = await boundary.toImage(pixelRatio: 1);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final output = Directory(
            Platform.environment['RAYEQ_VISUAL_OUTPUT'] ??
                '${Directory.systemTemp.path}/rayeq-visual-review',
          );
          await output.create(recursive: true);
          await File('${output.path}/$screen-$language.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
        navigatorKey.currentState!.pop();
        await tester.pumpAndSettle();
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      }
    }
  });
}
