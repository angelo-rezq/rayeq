import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'api.dart';
import 'localization.dart';
import 'live.dart';
import 'royal_theme.dart';
import 'app_updates.dart';

SemanticsHandle? accessibilityHandle;
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  accessibilityHandle = SemanticsBinding.instance.ensureSemantics();
  await initLanguage();
  runApp(const RayeqApp());
}

class RayeqApp extends StatelessWidget {
  final RayeqApi? api;
  const RayeqApp({super.key, this.api});
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<Locale>(
    valueListenable: appLocale,
    builder: (context, locale, _) => MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'رايق | حلاقك عندك',
      locale: locale,
      supportedLocales: const [Locale('ar', 'EG'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: rayeqTheme(),
      home: AppUpdateGate(child: LiveShell(api: api)),
    ),
  );
}
