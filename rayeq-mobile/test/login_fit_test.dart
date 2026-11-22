import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rayeq/live.dart';
import 'package:rayeq/localization.dart';
import 'package:rayeq/royal_theme.dart';

import 'all_pages_review_test.dart' show apiFor;

void main() {
  testWidgets(
    'login has zero scroll extent on small and large AR and EN phones',
    (t) async {
      await (FontLoader('PlexArabic')
            ..addFont(rootBundle.load('assets/fonts/PlexArabic-400.ttf'))
            ..addFont(rootBundle.load('assets/fonts/PlexArabic-600.ttf')))
          .load();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
    await t.pumpAndSettle();
    t.view.devicePixelRatio = 1;
      addTearDown(() {
        t.view.resetPhysicalSize();
        t.view.resetDevicePixelRatio();
      });
      for (final lang in ['ar', 'en']) {
        appLocale.value = lang == 'ar'
            ? const Locale('ar', 'EG')
            : const Locale('en');
        for (final size in [
          const Size(320, 568),
          const Size(390, 844),
          const Size(430, 932),
        ]) {
          FlutterSecureStorage.setMockInitialValues({});
          t.view.physicalSize = size;
          await t.pumpWidget(
            MaterialApp(
              locale: appLocale.value,
              supportedLocales: const [Locale('ar', 'EG'), Locale('en')],
              localizationsDelegates: GlobalMaterialLocalizations.delegates,
              theme: rayeqTheme(),
              builder: rayeqBackdrop,
              home: LiveShell(api: apiFor('customer'), initialScreen: 'login'),
            ),
          );
          await t.pumpAndSettle();
          expect(t.takeException(), isNull, reason: '$lang $size');
          final state = t.state<ScrollableState>(find.byType(Scrollable).first);
          expect(state.position.maxScrollExtent, 0, reason: '$lang $size');
          expect(find.text(tr('نسيت كلمة المرور؟')), findsOneWidget);
          await t.pumpWidget(const SizedBox.shrink());
          await t.pumpAndSettle();
        }
      }
    },
  );
}
