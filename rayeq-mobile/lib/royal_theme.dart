import 'package:flutter/material.dart';

const royalProfileBlue = Color(0xff4da3ff);
const royalBackground = Color(0xff101014),
    royalSurface = Color(0xff1e1e24),
    royalRaised = Color(0xff29292f),
    royalGold = Color(0xffe7c35b),
    royalText = Color(0xfff6f5f2),
    royalMuted = Color(0xffb8b8bf),
    royalLine = Color(0xff3c3c44);
ThemeData rayeqTheme() => ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  fontFamily: 'PlexArabic',
  scaffoldBackgroundColor: Colors.transparent,
  colorScheme: const ColorScheme.dark(
    primary: royalGold,
    onPrimary: royalBackground,
    secondary: royalGold,
    surface: royalSurface,
    onSurface: royalText,
    outline: royalLine,
    error: Color(0xffffa4a4),
  ),
  textTheme: const TextTheme(
    bodyMedium: TextStyle(fontSize: 15, height: 1.65, color: royalText),
    bodyLarge: TextStyle(fontSize: 16, height: 1.65, color: royalText),
    bodySmall: TextStyle(fontSize: 12, height: 1.6, color: royalMuted),
    titleMedium: TextStyle(
      fontSize: 17,
      height: 1.5,
      fontWeight: FontWeight.w600,
      color: royalText,
    ),
    titleSmall: TextStyle(
      fontSize: 15,
      height: 1.5,
      fontWeight: FontWeight.w600,
      color: royalText,
    ),
    labelLarge: TextStyle(
      fontSize: 14,
      height: 1.5,
      fontWeight: FontWeight.w600,
    ),
    labelMedium: TextStyle(fontSize: 13, height: 1.5),
    labelSmall: TextStyle(fontSize: 12, height: 1.5),
    headlineLarge: TextStyle(
      fontSize: 29,
      height: 1.5,
      fontWeight: FontWeight.w600,
      color: royalText,
    ),
    titleLarge: TextStyle(
      fontSize: 21,
      height: 1.5,
      fontWeight: FontWeight.w600,
      color: royalText,
    ),
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.transparent,
    surfaceTintColor: Colors.transparent,
    foregroundColor: royalText,
    centerTitle: false,
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      minimumSize: const Size(48, 48),
      backgroundColor: royalGold,
      foregroundColor: royalBackground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
      textStyle: const TextStyle(
        fontFamily: 'PlexArabic',
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      minimumSize: const Size(48, 48),
      foregroundColor: royalGold,
      side: const BorderSide(color: royalLine),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
  ),
  segmentedButtonTheme: SegmentedButtonThemeData(
    style: SegmentedButton.styleFrom(minimumSize: const Size(48, 48)),
  ),
  inputDecorationTheme: InputDecorationTheme(
    floatingLabelBehavior: FloatingLabelBehavior.always,
    alignLabelWithHint: true,
    constraints: const BoxConstraints(minHeight: 64),
    filled: true,
    fillColor: royalRaised,
    labelStyle: const TextStyle(color: royalMuted, fontSize: 16),
    floatingLabelStyle: const TextStyle(color: royalMuted, fontSize: 16),
    hintStyle: const TextStyle(color: royalMuted, fontSize: 12),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    border: UnderlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: royalLine),
    ),
    enabledBorder: UnderlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: royalLine),
    ),
    focusedBorder: UnderlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: royalGold),
    ),
  ),
  navigationBarTheme: const NavigationBarThemeData(
    backgroundColor: royalSurface,
    indicatorColor: Color(0xff4b3d27),
    labelTextStyle: WidgetStatePropertyAll(
      TextStyle(fontFamily: 'PlexArabic', fontSize: 12),
    ),
    height: 76,
  ),
  chipTheme: ChipThemeData(
    backgroundColor: royalRaised,
    selectedColor: royalGold,
    labelStyle: const TextStyle(fontFamily: 'PlexArabic', fontSize: 12),
    secondaryLabelStyle: const TextStyle(color: royalBackground),
    side: const BorderSide(color: royalLine),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
  ),
  dividerColor: royalLine,
  dialogTheme: DialogThemeData(
    backgroundColor: royalSurface,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
  ),
);

class RoyalBackdrop extends StatelessWidget {
  final Widget child;
  const RoyalBackdrop({super.key, required this.child});
  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      gradient: RadialGradient(
        center: Alignment.topLeft,
        radius: 1.5,
        colors: [Color(0xff332a18), Color(0xff151415)],
        stops: [0, 0.65],
      ),
    ),
    child: child,
  );
}

Widget rayeqBackdrop(BuildContext context, Widget? child) => DecoratedBox(
  decoration: const BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topRight,
      end: Alignment.bottomLeft,
      colors: [Color(0xff302718), Color(0xff211d16), Color(0xff151416)],
      stops: [0, .48, 1],
    ),
  ),
  child: DecoratedBox(
    decoration: BoxDecoration(
      gradient: RadialGradient(
        center: const Alignment(.9, -.8),
        radius: 1.4,
        colors: [royalGold.withValues(alpha: .09), Colors.transparent],
        stops: const [0, 1],
      ),
    ),
    child: child ?? const SizedBox.expand(),
  ),
);
