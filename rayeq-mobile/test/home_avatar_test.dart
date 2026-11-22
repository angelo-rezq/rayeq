import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rayeq/live.dart';
import 'package:rayeq/localization.dart';
import 'package:rayeq/review_fixtures.dart';
import 'package:rayeq/royal_theme.dart';

class AvatarApi extends ReviewApi {
  final bool hasAvatar, fail;
  final Uint8List? photo;
  int calls = 0;
  AvatarApi({required this.hasAvatar, this.photo, this.fail = false});
  @override
  Map<String, dynamic> get user => {...super.user, 'hasAvatar': hasAvatar};
  @override
  Future<Uint8List?> getAvatar() async {
    calls++;
    if (fail) throw StateError('unavailable');
    return photo;
  }
}

void main() {
  setUpAll(() async {
    await (FontLoader('PlexArabic')
          ..addFont(rootBundle.load('assets/fonts/PlexArabic-400.ttf'))
          ..addFont(rootBundle.load('assets/fonts/PlexArabic-600.ttf')))
        .load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  for (final mode in ['photo', 'no-photo', 'unavailable']) {
    testWidgets('Home account control displays avatar or initial, $mode', (
      t,
    ) async {
      t.view.devicePixelRatio = 1;
      t.view.physicalSize = const Size(390, 844);
      addTearDown(() {
        t.view.resetPhysicalSize();
        t.view.resetDevicePixelRatio();
      });
      appLocale.value = const Locale('en');
      SharedPreferences.setMockInitialValues({});
      final image = (Directory(
        'test/fixtures/media',
      ).listSync().whereType<File>().first).readAsBytesSync();
      final api = AvatarApi(
        hasAvatar: mode != 'no-photo',
        photo: mode == 'photo' ? image : null,
        fail: mode == 'unavailable',
      );
      await t.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          supportedLocales: const [Locale('en'), Locale('ar', 'EG')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          theme: rayeqTheme(),
          builder: rayeqBackdrop,
          home: LiveShell(api: api),
        ),
      );
      await t.pumpAndSettle();
      await t.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 80));
      });
      await t.pumpAndSettle();
      final control = find.byTooltip('My account');
      expect(control, findsOneWidget);
      expect(
        find.descendant(of: control, matching: find.byType(Image)),
        mode == 'photo' ? findsOneWidget : findsNothing,
      );
      if (mode != 'photo')
        expect(
          find.descendant(of: control, matching: find.text('K')),
          findsOneWidget,
        );
      expect(api.calls, mode == 'no-photo' ? 0 : 1);
      expect(t.takeException(), isNull);
    });
  }
}
